# Agent Fallback Implementation

## Overview
This implementation ensures **Azure AI Search is always tried first** before falling back to Bing Custom Search. This is a **code-enforced** solution that doesn't rely on LLM instructions.

## Architecture

### Two Separate Agents
1. **Primary Agent** (`wcg-aisearch-agent`)
   - Only has Azure AI Search tool
   - Returns `NO_RESULTS_FOUND` if information not found
   
2. **Fallback Agent** (`wcg-bing-fallback-agent`)
   - Only has Bing Custom Search tool
   - Used when primary agent finds no results

### Execution Flow

```
User Query
    ↓
[1] Call Primary Agent (AI Search)
    ↓
Has Results? ──YES──> Return AI Search Response + Citations
    │
    NO
    ↓
[2] Call Fallback Agent (Bing)
    ↓
Return Bing Response + Citations
```

## Implementation Details

### Step 1: Deploy Two Agents
Run the deployment script to create both agents:

```bash
python .deploy_agent.py
```

This creates:
- Primary agent with AI Search only
- Fallback agent with Bing only

**Important**: Save the agent IDs output to your `.env` file:
```env
AZURE_FOUNDRY_AGENT_ID=<primary-agent-id>
AZURE_FOUNDRY_FALLBACK_AGENT_ID=<fallback-agent-id>
```

### Step 2: Backend Logic (main.py)
The backend implements the fallback logic:

1. **Try Primary Agent First**
   - Call primary agent with user message
   - Check response for `NO_RESULTS_FOUND` sentinel
   
2. **Automatic Fallback**
   - If `NO_RESULTS_FOUND` detected, automatically call fallback agent
   - Uses same thread for conversation continuity
   
3. **Return Results**
   - Returns whichever agent provided results
   - Includes proper citations from the agent that responded

## Key Benefits

✅ **Guaranteed Execution Order**: Primary always runs first
✅ **Code-Enforced**: Not dependent on LLM following instructions
✅ **Transparent**: Backend logs show which agent was used
✅ **Efficient**: Only calls fallback when needed
✅ **Thread Continuity**: Both agents share same conversation thread

## Configuration

### Environment Variables
```env
# Required
AZURE_FOUNDRY_PROJECT_ENDPOINT=<your-endpoint>
AZURE_FOUNDRY_AGENT_ID=<primary-agent-id>

# Optional (if not set, no fallback available)
AZURE_FOUNDRY_FALLBACK_AGENT_ID=<fallback-agent-id>
```

### Primary Agent Instructions
```
Only answer if you find relevant information in the search results. 
If you cannot find sufficient information in the search index, 
respond with exactly: "NO_RESULTS_FOUND"
```

### Fallback Agent Instructions
```
Answer questions using Bing Custom Search when the primary 
knowledge base doesn't have the answer.
```

## Testing

### Test Primary Agent Only
```bash
# Query that should be in AI Search index
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What services does WCG provide?", "mode": "chat"}'
```

### Test Fallback Trigger
```bash
# Query not in AI Search index (triggers Bing)
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the weather in Cape Town today?", "mode": "chat"}'
```

## Logging
Backend logs show which agent was used:

```
INFO:main:Calling primary agent (AI Search): asst_xxx
INFO:main:Primary agent response: <response>...
INFO:main:Primary agent citations: 3

# If fallback triggered:
INFO:main:Primary agent found no results, will try fallback
INFO:main:Calling fallback agent (Bing): asst_yyy
INFO:main:Fallback agent response: <response>...
INFO:main:Fallback agent citations: 5
```

## Deployment Steps

1. **Deploy Both Agents**
   ```bash
   python .deploy_agent.py
   ```

2. **Update .env File**
   Add both agent IDs to your `.env` file

3. **Restart Backend**
   ```bash
   cd backend
   python main.py
   ```

4. **Test the Flow**
   - Test queries that should hit AI Search
   - Test queries that should fallback to Bing
   - Verify logs show correct agent usage

## Alternative Approaches (Not Implemented)

### Option A: Single Agent with tool_choice
- **Issue**: Requires exact tool type names
- **Problem**: Tool type identifiers may change
- **Risk**: Fails if tool names don't match exactly

### Option B: Prompt-Based Priority
- **Issue**: Relies on LLM following instructions
- **Problem**: LLM may choose wrong tool
- **Risk**: No guaranteed execution order

### Option C: Custom Tool (Complex)
- **Issue**: Requires custom function calling
- **Complexity**: Much more code to maintain
- **Overhead**: Additional API calls

## Current Solution (Implemented)
✅ **Two separate agents** with enforced fallback logic in backend code
- Simplest reliable solution
- Clear separation of concerns
- Easy to debug and monitor
- Guaranteed execution order

## Troubleshooting

### Fallback Not Triggering
- Check primary agent instructions include `NO_RESULTS_FOUND` sentinel
- Verify `AZURE_FOUNDRY_FALLBACK_AGENT_ID` is set in `.env`
- Check backend logs for primary agent response

### Both Agents Failing
- Verify both agent IDs are correct
- Check Azure AI Foundry connections are active
- Review agent logs in Azure portal

### Wrong Agent Used
- This shouldn't happen with this implementation
- Check logs to verify execution flow
- Ensure you're using the correct agent IDs

## Future Enhancements

1. **Smart Fallback Detection**
   - Use citation count instead of sentinel value
   - If primary has < 2 citations, try fallback

2. **Hybrid Results**
   - Combine results from both agents
   - Merge citations from both sources

3. **Confidence Scoring**
   - Primary agent returns confidence score
   - Only fallback if confidence < threshold

4. **Caching**
   - Cache AI Search results
   - Reduce duplicate calls

## Summary

This implementation provides **guaranteed execution order** through:
- Separate agents with distinct tools
- Backend-enforced fallback logic
- Clear sentinel value detection
- Transparent logging

No reliance on LLM instructions means **reliable, predictable behavior**.
