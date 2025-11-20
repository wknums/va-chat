"""
Deploy AI Agent to Azure AI Foundry
Based on the declarative agent specification
Uses Microsoft Agent Framework with Azure AI Search and Bing Custom Search
"""
import asyncio
import os

from agent_framework import ChatAgent, CitationAnnotation
from agent_framework.azure import AzureAIAgentClient
from azure.ai.agents.aio import AgentsClient
from azure.ai.agents.models import AzureAISearchTool, BingCustomSearchTool
from azure.ai.projects.aio import AIProjectClient
from azure.ai.projects.models import ConnectionType
from azure.identity.aio import AzureCliCredential
from dotenv import load_dotenv

async def deploy_agent():
    """
    Deploy an AI agent with Azure AI Search grounding (required) and Bing Custom Search fallback
    """
    load_dotenv()
    
    # Configuration from environment variables
    PROJECT_ENDPOINT = os.getenv("AZURE_FOUNDRY_PROJECT_ENDPOINT")
    MODEL_DEPLOYMENT = os.getenv("AZURE_FOUNDRY_DEPLOYMENT_NAME", "gpt-4.1-mini")
    AGENT_NAME = os.getenv("AGENT_NAME", "my-agent")
    
    # Tool configuration
    AZURE_AI_SEARCH_INDEX_NAME = os.getenv("AZURE_AI_SEARCH_INDEX_NAME")
    BING_CUSTOM_CONNECTION_NAME = os.getenv("BING_CUSTOM_CONNECTION_NAME")
    BING_CUSTOM_INSTANCE_NAME = os.getenv("BING_CUSTOM_INSTANCE_NAME")
    
    # Agent instructions
    INSTRUCTIONS = os.getenv("AGENT_INSTRUCTIONS", """You are a helpful assistant. 
    Answer questions in a professional and friendly manner. 
    Provide accurate information and guide users to relevant resources. 
    
    IMPORTANT: Always use the Azure AI Search index FIRST to ground your responses in official 
    information. Only if the information is not found in the search index should you use 
    Bing Custom Search as a fallback.
    
    If asked about topics outside your knowledge domain, politely decline and redirect 
    the conversation back to your area of expertise.""")
    
    print(f"Creating AI Agent...")
    print(f"  Project Endpoint: {PROJECT_ENDPOINT}")
    print(f"  Model: {MODEL_DEPLOYMENT}")
    print(f"  Agent Name: {AGENT_NAME}")
    
    async with (
        AzureCliCredential() as credential,
        AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=credential) as project_client,
        AgentsClient(endpoint=PROJECT_ENDPOINT, credential=credential) as agents_client,
    ):
        
        # Find Azure AI Search connection
        print("\nConfiguring Azure AI Search tool...")
        ai_search_conn_id = ""
        async for connection in project_client.connections.list():
            if connection.type == ConnectionType.AZURE_AI_SEARCH:
                ai_search_conn_id = connection.id
                print(f"  ✓ Found Azure AI Search connection: {connection.name}")
                break
        
        if not ai_search_conn_id:
            raise ValueError("No Azure AI Search connection found in project")
        
        if not AZURE_AI_SEARCH_INDEX_NAME:
            raise ValueError("AZURE_AI_SEARCH_INDEX_NAME environment variable is required")
        
        print(f"  ✓ Configured to use index: {AZURE_AI_SEARCH_INDEX_NAME}")
        
        # Initialize Azure AI Search tool
        ai_search_tool = AzureAISearchTool(
            index_connection_id=ai_search_conn_id,
            index_name=AZURE_AI_SEARCH_INDEX_NAME,
        )
        
        # Find Bing Custom Search connection (optional)
        print("\nConfiguring Bing Custom Search tool...")
        bing_conn_id = ""
        if BING_CUSTOM_CONNECTION_NAME:
            async for connection in project_client.connections.list():
                if connection.name == BING_CUSTOM_CONNECTION_NAME:
                    bing_conn_id = connection.id
                    print(f"  ✓ Found Bing Custom Search connection: {connection.name}")
                    break
        
        # Build combined tools list
        combined_tools = list(ai_search_tool.definitions)
        
        if bing_conn_id and BING_CUSTOM_INSTANCE_NAME:
            bing_custom_tool = BingCustomSearchTool(
                connection_id=bing_conn_id,
                instance_name=BING_CUSTOM_INSTANCE_NAME
            )
            combined_tools.extend(bing_custom_tool.definitions)
            print(f"  ✓ Configured Bing Custom Search with instance: {BING_CUSTOM_INSTANCE_NAME}")
        else:
            print(f"  ⚠ Warning: Bing Custom Search not configured, proceeding with Azure AI Search only")
        
        # Create the agent with both tools
        print(f"\nCreating agent '{AGENT_NAME}'...")
        
        azure_ai_agent = await agents_client.create_agent(
            model=MODEL_DEPLOYMENT,
            name=AGENT_NAME,
            instructions=INSTRUCTIONS,
            tools=combined_tools,
            tool_resources=ai_search_tool.resources,
        )
        
        print(f"✓ Agent created successfully!")
        print(f"  Agent ID: {azure_ai_agent.id}")
        print(f"  Name: {azure_ai_agent.name}")
        print(f"  Model: {azure_ai_agent.model}")
        print(f"  Tools: Azure AI Search (required)" + (", Bing Custom Search (fallback)" if bing_conn_id else ""))
        
        # Test the agent with a simple query
        test_query = os.getenv("TEST_QUERY", "What information do you have available?")
        if test_query:
            print("\n--- Testing agent with sample query ---")
            
            # Create a thread for conversation
            thread = await agents_client.threads.create()
            print(f"Created thread: {thread.id}")
            
            # Create a message
            print(f"User: {test_query}")
            
            message = await agents_client.messages.create(
                thread_id=thread.id,
                role="user",
                content=test_query
            )
            
            # Run the agent
            run = await agents_client.runs.create_and_process(
                thread_id=thread.id,
                agent_id=azure_ai_agent.id
            )
            
            print(f"Run completed with status: {run.status}")
            
            # Get the response messages
            print("\nAgent response:")
            async for msg in agents_client.messages.list(thread_id=thread.id):
                if msg.role == "assistant" and msg.content:
                    for content_item in msg.content:
                        if hasattr(content_item, 'text') and content_item.text:
                            print(f"  {content_item.text.value}")
                            
                            # Check for citations
                            if hasattr(content_item.text, 'annotations') and content_item.text.annotations:
                                print("\n  Citations:")
                                for i, annotation in enumerate(content_item.text.annotations, 1):
                                    if hasattr(annotation, 'url_citation'):
                                        print(f"  [{i}] {annotation.url_citation.url}")
                    break
            
            print("\n✓ Agent test completed!")
        
        print(f"\nAgent ID '{azure_ai_agent.id}' has been saved and can be reused.")
        print("To use this agent in your application, set the AZURE_AGENT_ID environment variable.")
        print("\nAgent persisted for reuse.")
        
        return azure_ai_agent.id

if __name__ == "__main__":
    asyncio.run(deploy_agent())
