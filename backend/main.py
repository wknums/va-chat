"""
Public Sector AI Chatbot - FastAPI Backend
Provides chat and search endpoints for the government chatbot widget
"""
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Literal
from azure.ai.agents.aio import AgentsClient
from azure.identity.aio import DefaultAzureCredential
from azure.ai.agents.models import ListSortOrder
from dotenv import load_dotenv
import os
import csv
import logging
from pathlib import Path

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Government Chatbot API",
    description="AI-powered chat and search for government services",
    version="1.0.0"
)

# Configure CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Azure AI Foundry client configuration
project_endpoint = os.getenv("AZURE_FOUNDRY_PROJECT_ENDPOINT")
primary_agent_id = os.getenv("AZURE_FOUNDRY_AGENT_ID")  # AI Search agent
fallback_agent_id = os.getenv("AZURE_FOUNDRY_FALLBACK_AGENT_ID")  # Bing agent (optional)

if not project_endpoint or not primary_agent_id:
    raise ValueError("Missing required environment variables: AZURE_FOUNDRY_PROJECT_ENDPOINT, AZURE_FOUNDRY_AGENT_ID")

logger.info(f"Configured for endpoint: {project_endpoint}")
logger.info(f"Using primary agent ID: {primary_agent_id}")
if fallback_agent_id:
    logger.info(f"Using fallback agent ID: {fallback_agent_id}")
else:
    logger.warning("No fallback agent configured - will not use Bing search")

# Load URL mapping for document IDs
url_mapping = {}
try:
    mapping_file = os.path.join(os.path.dirname(__file__), '..', 'utilities', 'mapping.csv')
    with open(mapping_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) >= 2:
                # Map filename to URL
                filename = row[0]
                url = row[1]
                url_mapping[filename] = url
                # Also map without extension for flexibility
                base_name = os.path.splitext(filename)[0]
                url_mapping[base_name] = url
    logger.info(f"Loaded {len(url_mapping)} URL mappings")
except Exception as e:
    logger.warning(f"Could not load URL mapping: {e}")
    url_mapping = {}


# Request/Response Models
class ChatMessage(BaseModel):
    role: Literal["user", "assistant"] = Field(description="Message role")
    content: str = Field(description="Message content")


class ChatRequest(BaseModel):
    message: str = Field(description="User message")
    thread_id: Optional[str] = Field(None, description="Optional thread ID for conversation continuity")
    mode: Literal["chat", "search"] = Field(default="chat", description="Response mode: chat or search")


class SearchResult(BaseModel):
    title: str
    url: str
    snippet: str


class ChatResponse(BaseModel):
    message: str = Field(description="Assistant response")
    thread_id: str = Field(description="Thread ID for conversation continuity")
    mode: str = Field(description="Response mode used")
    citations: Optional[List[dict]] = Field(None, description="Source citations if available")
    search_results: Optional[List[SearchResult]] = Field(None, description="Search results if mode=search")


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


# Helper Functions
def map_document_id_to_url(doc_id: str) -> str:
    """Map document ID to actual URL using the CSV mapping"""
    # If it's already a URL, return as-is
    if doc_id.startswith('http'):
        return doc_id
    
    # Try direct lookup
    if doc_id in url_mapping:
        return url_mapping[doc_id]
    
    # Try with .pdf extension
    if f"{doc_id}.pdf" in url_mapping:
        return url_mapping[f"{doc_id}.pdf"]
    
    # Try with .docx extension
    if f"{doc_id}.docx" in url_mapping:
        return url_mapping[f"{doc_id}.docx"]
    
    # If no mapping found, return original
    logger.warning(f"No URL mapping found for document ID: {doc_id}")
    return doc_id


def format_as_search_results(agent_response: str, citations: Optional[List] = None, is_search_mode: bool = True) -> List[SearchResult]:
    """Convert agent response and citations into search result format"""
    import re
    results = []
    
    logger.info(f"format_as_search_results called with {len(citations) if citations else 0} citations, is_search_mode={is_search_mode}")
    
    # If we have citations, convert them to search results
    if citations and len(citations) > 0:
        logger.info(f"Processing {len(citations)} total citations")
        for i, citation in enumerate(citations[:20]):  # Increased limit to 20 results
            title = citation.get('title', f'Result {i+1}')
            url = citation.get('url', '#')
            snippet = citation.get('snippet', '')
            source = citation.get('source', 'Unknown')
            
            logger.info(f"Processing citation {i}: title={title[:50] if title else 'None'}, url={url[:50] if url else 'None'}, source={source}")
            
            # Map document ID to actual URL if needed (only for AI Search results)
            if source == 'AI Search':
                mapped_url = map_document_id_to_url(url) if url != '#' else '#'
            else:
                # For Bing results, use URL as-is
                mapped_url = url
            
            # Use mapped URL for title if original title is generic
            if title.startswith('doc_') and mapped_url != url:
                # Extract filename from URL for better title
                import urllib.parse
                parsed_url = urllib.parse.urlparse(mapped_url)
                if 'file=' in parsed_url.query:
                    # Extract filename from query parameter
                    query_params = urllib.parse.parse_qs(parsed_url.query)
                    file_param = query_params.get('file', [''])[0]
                    if file_param:
                        filename = os.path.basename(file_param)
                        if filename:
                            title = os.path.splitext(filename)[0].replace('-', ' ').replace('_', ' ').title()
                elif mapped_url.endswith('.pdf') or mapped_url.endswith('.docx'):
                    filename = os.path.basename(mapped_url)
                    title = os.path.splitext(filename)[0].replace('-', ' ').replace('_', ' ').title()
            
            # Include all citations with valid URLs
            if mapped_url and mapped_url != '#':
                results.append(SearchResult(
                    title=title,
                    url=mapped_url,
                    snippet=snippet if snippet else agent_response[:250]
                ))
                logger.info(f"Added result {i} ({source}): {title[:30]} -> {mapped_url[:50]}")
            else:
                logger.warning(f"Skipped citation {i} ({source}): no valid URL")
    
    logger.info(f"Returning {len(results)} search results")
    
    # If no valid citations and in search mode, try to parse the response text for structured results
    if not results and agent_response and is_search_mode:
        logger.warning("No citations found in search mode, attempting to parse response text")
        
        # Try to split by numbered list items (1., 2., etc.) or double newlines
        # Pattern matches: "1. Title - URL" or "1. **Title** - URL" or similar
        paragraphs = re.split(r'\n\n+', agent_response.strip())
        
        for para in paragraphs:
            if not para.strip():
                continue
                
            # Try to extract URL from markdown links first [title](url)
            markdown_match = re.search(r'\[([^\]]+)\]\(([^)]+)\)', para)
            if markdown_match:
                title = markdown_match.group(1).strip()
                url = markdown_match.group(2).strip()
                # Remove leading numbers like "1. " or "**1.**" from title
                title = re.sub(r'^\*{0,2}\d+\.\s*\*{0,2}\s*', '', title)
            else:
                # Fallback to looking for bare URLs
                url_match = re.search(r'https?://[^\s\)]+', para)
                url = url_match.group(0) if url_match else '#'
                
                # Try to extract title (text before URL or before dash)
                lines = para.split('\n')
                title = lines[0].strip()
                # Remove leading numbers like "1. " or "**1.**"
                title = re.sub(r'^\*{0,2}\d+\.\s*\*{0,2}\s*', '', title)
                # Remove URL from title if present
                title = re.sub(r'https?://[^\s]+', '', title).strip()
                # Remove trailing dashes
                title = re.sub(r'\s*-\s*$', '', title).strip()
            
            # Use remaining text as snippet
            snippet = '\n'.join(para.split('\n')[1:]).strip() if '\n' in para else para
            
            if title and url != '#':
                results.append(SearchResult(
                    title=title[:200] if len(title) > 200 else title,
                    url=url,
                    snippet=snippet[:500] if len(snippet) > 500 else snippet
                ))
                logger.info(f"Parsed result from text: title={title[:50]}, url={url[:50]}")
        
        logger.info(f"Parsed {len(results)} results from text")
    
    # If still no results, create a single fallback result
    if not results:
        logger.warning("No structured results found, creating fallback result")
        results.append(SearchResult(
            title="Search Results from VA Assistant",
            url="#",
            snippet=agent_response
        ))
    
    return results


async def chat_with_agent(message: str, thread_id: Optional[str] = None, mode: str = "chat") -> tuple[str, str, Optional[List], Optional[str]]:
    """
    Chat with the Azure AI Foundry agents with different logic based on mode:
    - chat mode: Try primary agent first, fallback to Bing if no results
    - search mode: Run both agents and combine results
    Returns: (response_text, thread_id, citations, raw_responses_for_parsing)
    """
    try:
        # Create async credential and agents client
        async with DefaultAzureCredential() as credential:
            async with AgentsClient(endpoint=project_endpoint, credential=credential) as agents_client:
                # Get or create thread
                if thread_id:
                    logger.info(f"Using existing thread: {thread_id}")
                else:
                    thread = await agents_client.threads.create()
                    thread_id = thread.id
                    logger.info(f"Created new thread: {thread_id}")
                
                # Create user message
                await agents_client.messages.create(
                    thread_id=thread_id,
                    role="user",
                    content=message
                )
                
                # STEP 1: Try PRIMARY agent (AI Search) first
                logger.info(f"Calling primary agent (AI Search): {primary_agent_id}")
                run = await agents_client.runs.create_and_process(
                    thread_id=thread_id,
                    agent_id=primary_agent_id
                )
        
                if run.status == "failed":
                    logger.error(f"Primary agent run failed: {run.last_error}")
                    if mode != "search":
                        raise HTTPException(status_code=500, detail=f"Primary agent run failed: {run.last_error}")
                
                # Extract primary agent response
                primary_response_text = ""
                primary_citations = []
                use_fallback = False
                
                async for msg in agents_client.messages.list(thread_id=thread_id, order=ListSortOrder.DESCENDING, limit=1):
                    if msg.role == "assistant" and msg.text_messages:
                        text_msg = msg.text_messages[0]
                        primary_response_text = text_msg.text.value
                        
                        logger.info(f"Primary agent response: {primary_response_text[:200]}...")
                        logger.info(f"Response contains search references: {'search' in primary_response_text.lower() or 'found' in primary_response_text.lower()}")
                        
                        # Check for annotations
                        if hasattr(text_msg.text, 'annotations'):
                            if text_msg.text.annotations:
                                logger.info(f"Found {len(text_msg.text.annotations)} annotations for processing")
                            else:
                                logger.warning("Text message has annotations attribute but it's None or empty")
                                logger.info(f"Annotations value: {text_msg.text.annotations}")
                        else:
                            logger.warning("Text message has no annotations attribute")
                            logger.info(f"Text message attributes: {[attr for attr in dir(text_msg.text) if not attr.startswith('_')]}")
                        
                        # For chat mode, check if primary agent found no results
                        if mode == "chat":
                            no_results_indicators = [
                                "NO_RESULTS_FOUND",
                                "no results",
                                "couldn't find",
                                "no information",
                                "not found",
                                "no relevant"
                            ]
                            
                            has_no_results = any(indicator.lower() in primary_response_text.lower() for indicator in no_results_indicators)
                            
                            if has_no_results:
                                logger.info("Primary agent found no results, will try fallback")
                                use_fallback = True
                        elif mode == "search":
                            # In search mode, always try to get Bing results too
                            use_fallback = True
                            logger.info("Search mode: will run both agents to combine results")
                        
                        # Extract citations from annotations
                        if hasattr(text_msg.text, 'annotations') and text_msg.text.annotations:
                            logger.info(f"Processing {len(text_msg.text.annotations)} annotations")
                            for idx, ann in enumerate(text_msg.text.annotations):
                                # Handle different annotation types
                                citation = None
                                
                                # Handle URL citations (most common for search results)
                                if hasattr(ann, 'url_citation') and ann.url_citation:
                                    url_cit = ann.url_citation
                                    
                                    # Extract title and URL
                                    raw_title = getattr(url_cit, 'title', f'Search Result {idx+1}')
                                    citation_url = getattr(url_cit, 'url', '#')
                                    
                                    # Improve title if it's generic (like doc_0, doc_1, etc.)
                                    if raw_title.startswith('doc_') and citation_url != '#':
                                        # Extract filename from URL for better title
                                        import urllib.parse
                                        parsed_url = urllib.parse.urlparse(citation_url)
                                        if 'file=' in parsed_url.query:
                                            query_params = urllib.parse.parse_qs(parsed_url.query)
                                            file_param = query_params.get('file', [''])[0]
                                            if file_param:
                                                # Extract just the filename without path and decode URL encoding
                                                filename = urllib.parse.unquote(file_param.split('/')[-1])
                                                if filename.endswith('.pdf') or filename.endswith('.docx'):
                                                    # Create a readable title from filename
                                                    title = filename.replace('%20', ' ').replace('_', ' ').replace('-', ' ')
                                                    title = title.rsplit('.', 1)[0]  # Remove extension
                                                    raw_title = title.title()
                                    
                                    citation = {
                                        'title': raw_title,
                                        'url': citation_url,
                                        'snippet': getattr(url_cit, 'snippet', ''),
                                        'source': 'AI Search'
                                    }
                                    logger.info(f"URL citation: {citation}")
                                # Handle file citations from AI Search
                                elif hasattr(ann, 'file_citation') and ann.file_citation:
                                    file_cit = ann.file_citation
                                    
                                    # Extract file_id which should contain the actual filename
                                    file_id = getattr(file_cit, 'file_id', '')
                                    quote = getattr(file_cit, 'quote', '')
                                    
                                    # Check for URL in file_citation - with updated AI Search config, this should be the originalSourceURL
                                    citation_url = getattr(file_cit, 'url', None)
                                    
                                    # If no direct URL, try file_id (might be the URL now)
                                    if not citation_url or citation_url.startswith('doc_'):
                                        potential_url = getattr(file_cit, 'file_id', '')
                                        if potential_url and potential_url.startswith('http'):
                                            citation_url = potential_url
                                        else:
                                            citation_url = file_id
                                    
                                    logger.info(f"File citation - file_id: {file_id}, extracted_url: {citation_url}")
                                    
                                    citation = {
                                        'title': file_id if file_id and not file_id.startswith('doc_') else f'Document {idx+1}',
                                        'url': citation_url,  # Use the URL if available, otherwise file_id
                                        'snippet': quote,
                                        'source': 'AI Search'
                                    }
                                    logger.info(f"File citation extracted: {citation}")
                                # Handle direct URL property
                                elif hasattr(ann, 'url'):
                                    citation = {
                                        'title': getattr(ann, 'title', f'Source {idx+1}'),
                                        'url': ann.url,
                                        'snippet': getattr(ann, 'text', getattr(ann, 'snippet', '')),
                                        'source': 'AI Search'
                                    }
                                    logger.info(f"Direct URL citation: {citation}")
                                # Handle text annotations that might contain URLs
                                elif hasattr(ann, 'text'):
                                    import re
                                    # Look for URLs in the text
                                    url_match = re.search(r'https?://[^\s\)]+', ann.text)
                                    if url_match:
                                        citation = {
                                            'title': f'Reference {idx+1}',
                                            'url': url_match.group(0),
                                            'snippet': ann.text,
                                            'source': 'AI Search'
                                        }
                                        logger.info(f"Text-based URL citation: {citation}")
                                
                                # Add citation if we extracted one
                                if citation:
                                    # Map document ID to actual URL if needed
                                    original_url = citation['url']
                                    mapped_url = map_document_id_to_url(original_url) if original_url != '#' else '#'
                                    
                                    if mapped_url != original_url:
                                        citation['url'] = mapped_url
                                        logger.info(f"Mapped URL from {original_url} to {mapped_url}")
                                        
                                        # Improve title if it was generic and we have a mapped URL
                                        if citation['title'].startswith('Document ') or citation['title'].startswith('Search Result '):
                                            # Extract filename from URL for better title
                                            import urllib.parse
                                            parsed_url = urllib.parse.urlparse(mapped_url)
                                            if 'file=' in parsed_url.query:
                                                # Extract filename from query parameter
                                                query_params = urllib.parse.parse_qs(parsed_url.query)
                                                file_param = query_params.get('file', [''])[0]
                                                if file_param:
                                                    filename = os.path.basename(file_param)
                                                    if filename:
                                                        citation['title'] = os.path.splitext(filename)[0].replace('-', ' ').replace('_', ' ').title()
                                            elif mapped_url.endswith('.pdf') or mapped_url.endswith('.docx'):
                                                filename = os.path.basename(mapped_url)
                                                citation['title'] = os.path.splitext(filename)[0].replace('-', ' ').replace('_', ' ').title()
                                    
                                    primary_citations.append(citation)
                                else:
                                    logger.warning(f"Could not extract citation from annotation {idx}: {dir(ann)}")
                        
                        logger.info(f"Primary agent citations: {len(primary_citations)}")
                        
                        # If no citations found and response is short/vague in chat mode, try fallback
                        if mode == "chat" and not primary_citations and len(primary_response_text.strip()) < 200:
                            logger.info("Primary agent returned short response with no citations, will try fallback")
                            use_fallback = True
                        
                        break
                
                # STEP 2: Run FALLBACK agent (Bing) if needed
                fallback_response_text = ""
                fallback_citations = []
                
                if use_fallback and fallback_agent_id:
                    agent_name = "Bing (fallback)" if mode == "chat" else "Bing (additional)"
                    logger.info(f"Calling {agent_name} agent: {fallback_agent_id}")
                    
                    # Run fallback agent on same thread
                    fallback_run = await agents_client.runs.create_and_process(
                        thread_id=thread_id,
                        agent_id=fallback_agent_id
                    )
                    
                    if fallback_run.status == "failed":
                        logger.error(f"Fallback agent run failed: {fallback_run.last_error}")
                        if mode == "chat":
                            # Return primary response even if fallback fails in chat mode
                            return primary_response_text, thread_id, primary_citations if primary_citations else None
                    else:
                        # Extract fallback response
                        async for msg in agents_client.messages.list(thread_id=thread_id, order=ListSortOrder.DESCENDING, limit=1):
                            if msg.role == "assistant" and msg.text_messages:
                                text_msg = msg.text_messages[0]
                                fallback_response_text = text_msg.text.value
                                
                                logger.info(f"Fallback agent response: {fallback_response_text[:200]}...")
                                
                                # Extract citations from fallback (Bing results)
                                if hasattr(text_msg.text, 'annotations') and text_msg.text.annotations:
                                    logger.info(f"Found {len(text_msg.text.annotations)} annotations from Bing")
                                    for idx, ann in enumerate(text_msg.text.annotations):
                                        # Handle different annotation types
                                        citation = None
                                        
                                        # Handle URL citations (most common for Bing results)
                                        if hasattr(ann, 'url_citation') and ann.url_citation:
                                            url_cit = ann.url_citation
                                            citation = {
                                                'title': getattr(url_cit, 'title', f'Web Result {idx+1}'),
                                                'url': getattr(url_cit, 'url', '#'),
                                                'snippet': getattr(url_cit, 'snippet', ''),
                                                'source': 'Bing Search'
                                            }
                                        elif hasattr(ann, 'file_citation') and ann.file_citation:
                                            file_cit = ann.file_citation
                                            citation = {
                                                'title': getattr(file_cit, 'title', f'Source {idx+1}'),
                                                'url': getattr(file_cit, 'url', '#'),
                                                'snippet': getattr(file_cit, 'snippet', ''),
                                                'source': 'Bing Search'
                                            }
                                        elif hasattr(ann, 'url'):
                                            citation = {
                                                'title': getattr(ann, 'title', f'Web Source {idx+1}'),
                                                'url': ann.url,
                                                'snippet': getattr(ann, 'text', getattr(ann, 'snippet', '')),
                                                'source': 'Bing Search'
                                            }
                                        elif hasattr(ann, 'text'):
                                            import re
                                            # Look for URLs in the text
                                            url_match = re.search(r'https?://[^\s\)]+', ann.text)
                                            if url_match:
                                                citation = {
                                                    'title': f'Web Reference {idx+1}',
                                                    'url': url_match.group(0),
                                                    'snippet': ann.text,
                                                    'source': 'Bing Search'
                                                }
                                        
                                        if citation:
                                            fallback_citations.append(citation)
                                            logger.info(f"Fallback citation {idx}: {citation['title']} -> {citation['url']}")
                                
                                logger.info(f"Fallback agent citations: {len(fallback_citations)}")
                                break
                
                # STEP 3: Combine results based on mode
                if mode == "search":
                    # In search mode, combine both responses and citations
                    combined_response = ""
                    raw_responses = ""
                    
                    # Only include primary response if it has actual results (not NO_RESULTS_FOUND)
                    if (primary_response_text and run.status != "failed" and 
                        "NO_RESULTS_FOUND" not in primary_response_text):
                        combined_response += f"## Knowledge Base Results\n\n{primary_response_text}\n\n"
                        raw_responses += primary_response_text + "\n\n"
                    
                    # Only include fallback response if it has actual results (not NO_RESULTS_FOUND)
                    if (fallback_response_text and 
                        "NO_RESULTS_FOUND" not in fallback_response_text):
                        combined_response += f"## Web Search Results\n\n{fallback_response_text}"
                        raw_responses += fallback_response_text
                    
                    # If no primary response due to failure, just use Bing
                    if not combined_response.strip():
                        combined_response = fallback_response_text
                        raw_responses = fallback_response_text
                    
                    # Combine citations from both sources
                    all_citations = primary_citations + fallback_citations
                    
                    logger.info(f"Combined search results: {len(primary_citations)} from AI Search, {len(fallback_citations)} from Bing")
                    return combined_response, thread_id, all_citations if all_citations else None, raw_responses.strip()
                else:
                    # In chat mode, return fallback if primary failed, otherwise primary
                    if fallback_response_text and (not primary_response_text or use_fallback):
                        logger.info(f"Chat mode: using fallback response")
                        return fallback_response_text, thread_id, fallback_citations if fallback_citations else None, None
                    else:
                        logger.info(f"Chat mode: using primary response")
                        return primary_response_text, thread_id, primary_citations if primary_citations else None, None
        
    except Exception as e:
        logger.error(f"Error in chat_with_agent: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# API Endpoints
@app.get("/", response_model=dict)
async def root():
    """Root endpoint"""
    return {
        "service": "VA Chatbot API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "/api/health",
            "chat": "/api/chat",
            "search": "/api/search"
        }
    }


@app.get("/api/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        service="VA Chatbot API",
        version="1.0.0"
    )


@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, http_request: Request = None):
    """
    Chat endpoint - conversational interface with citations
    """
    client_ip = http_request.client.host if http_request and http_request.client else "unknown"
    logger.info(f"Chat request from {client_ip}: {request.message[:50]}... (mode: {request.mode})")
    logger.info(f"Chat request: {request.message[:50]}... (mode: {request.mode})")
    
    try:
        # Modify message for search mode or add formatting instructions for chat mode
        message = request.message
        if request.mode == "search":
            message = f"{request.message} - is the user's search question. - provide a traditional bing search response - i.e. a comprehensive list of all web pages with clickable urls that contain the search term provided - sorted by decreasing relevance"
        else:
            # For chat mode, ensure readable formatting
            message = f"{request.message}\n\nIMPORTANT: Format your response to be clear and readable. Use proper line breaks, bullet points, and paragraph spacing as appropriate for the content."
        
        # Get response from agent
        response_text, thread_id, citations, raw_responses = await chat_with_agent(
            message,
            request.thread_id,
            request.mode
        )
        
        # Format response based on mode
        if request.mode == "search":
            # Use raw responses (without headers) for search result parsing
            search_text = raw_responses if raw_responses else response_text
            search_results = format_as_search_results(search_text, citations, is_search_mode=True)
            return ChatResponse(
                message=response_text,
                thread_id=thread_id,
                mode=request.mode,
                citations=citations,
                search_results=search_results
            )
        else:
            return ChatResponse(
                message=response_text,
                thread_id=thread_id,
                mode=request.mode,
                citations=citations
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/search", response_model=ChatResponse)
async def search(request: ChatRequest):
    """
    Search endpoint - returns results in search list format
    Alias for /api/chat with mode=search
    """
    request.mode = "search"
    return await chat(request)


# Run the application
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info"
    )
