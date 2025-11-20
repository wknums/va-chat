"""
Test script to create a new agent in Azure AI Foundry and use it with Agent Framework.
This demonstrates the full lifecycle: create agent -> use with Agent Framework -> cleanup.
Based on the working pattern from .deploy_agent.py
"""
import os
import asyncio
from dotenv import load_dotenv
from azure.identity.aio import AzureCliCredential
from azure.ai.agents.aio import AgentsClient
from agent_framework import ChatAgent
from agent_framework.azure import AzureAIAgentClient

async def main():
    """Main function to run the agent demo"""
    # Load environment variables from .env file
    load_dotenv()
    
    # Get Azure AI Foundry project configuration
    project_endpoint = os.getenv("AZURE_FOUNDRY_PROJECT_ENDPOINT")
    deployment_name = os.getenv("AZURE_FOUNDRY_DEPLOYMENT_NAME")
    
    if not project_endpoint or not deployment_name:
        raise ValueError("Missing required environment variables: AZURE_FOUNDRY_PROJECT_ENDPOINT, AZURE_FOUNDRY_DEPLOYMENT_NAME")
    
    print(f"Connecting to Azure AI Foundry Project: {project_endpoint}")
    print(f"Using model deployment: {deployment_name}\n")
    
    created_agent = None
    
    # Use async pattern throughout, matching .deploy_agent.py
    async with (
        AzureCliCredential() as credential,
        AgentsClient(endpoint=project_endpoint, credential=credential) as agents_client,
    ):
        try:
            # Create a new agent using AgentsClient (not AIProjectClient)
            print("Creating agent in Azure AI Foundry...")
            created_agent = await agents_client.create_agent(
                model=deployment_name,
                name="maf-agent-demo",
                instructions="You are a helpful assistant that answers questions clearly and concisely."
            )
            print(f"Agent created: {created_agent.name} (ID: {created_agent.id})\n")
            
            # Test the agent with a simple query (like .deploy_agent.py does)
            print("--- Testing agent with sample query ---")
            
            # Create a thread for conversation
            thread = await agents_client.threads.create()
            print(f"Created thread: {thread.id}")
            
            # Get user query or use default
            query = input("\nEnter your question (or press Enter for default): ").strip()
            if not query:
                query = "Write a haiku about Agent Framework."
            
            print(f"\nUser: {query}")
            print("Agent is thinking...\n")
            
            # Create a message
            message = await agents_client.messages.create(
                thread_id=thread.id,
                role="user",
                content=query
            )
            
            # Run the agent
            run = await agents_client.runs.create_and_process(
                thread_id=thread.id,
                agent_id=created_agent.id
            )
            
            print(f"Run completed with status: {run.status}")
            
            # Get the response messages
            print("\nAgent response:")
            async for msg in agents_client.messages.list(thread_id=thread.id):
                if msg.role == "assistant" and msg.content:
                    for content_item in msg.content:
                        if hasattr(content_item, 'text') and content_item.text:
                            print(f"  {content_item.text.value}\n")
                    break
                
        finally:
            # Clean up the agent
            if created_agent:
                print("Cleaning up...")
                await agents_client.delete_agent(created_agent.id)
                print(f"Deleted agent: {created_agent.id}")

if __name__ == "__main__":
    asyncio.run(main())