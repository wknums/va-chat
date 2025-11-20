"""
Helper script to discover Azure AI Foundry project connections and configurations
"""
import asyncio
import os
from azure.ai.projects.aio import AIProjectClient
from azure.identity.aio import DefaultAzureCredential
from dotenv import load_dotenv

async def discover_connections():
    """List all connections and their details in the Azure AI Foundry project"""
    load_dotenv()
    
    PROJECT_ENDPOINT = os.getenv("AZURE_FOUNDRY_PROJECT_ENDPOINT")

    
    if not PROJECT_ENDPOINT:
        print("Error: AZURE_FOUNDRY_PROJECT_ENDPOINT not set in .env file")
        return
    
    print(f"Connecting to: {PROJECT_ENDPOINT}\n")
    
    async with DefaultAzureCredential() as credential:
        async with AIProjectClient(
            endpoint=PROJECT_ENDPOINT,
            credential=credential
        ) as project_client:
            
            print("=" * 80)
            print("DISCOVERING PROJECT CONNECTIONS")
            print("=" * 80)
            
            try:
                connections_pager = project_client.connections.list()
                
                ai_search_connections = []
                bing_connections = []
                other_connections = []
                connection_count = 0
                
                # Iterate through the async pager
                async for connection in connections_pager:
                    connection_count += 1
                    
                    # Get connection type - it might be in different attributes
                    conn_type = getattr(connection, 'connection_type', None) or \
                                getattr(connection, 'type', None) or \
                                getattr(connection, 'properties', {}).get('category', 'Unknown')
                    
                    conn_info = {
                        'name': connection.name,
                        'type': conn_type,
                        'id': connection.id
                    }
                    
                    # Categorize connections
                    conn_type_lower = str(conn_type).lower()
                    if 'search' in conn_type_lower and 'bing' not in conn_type_lower:
                        ai_search_connections.append(conn_info)
                    elif 'bing' in conn_type_lower:
                        bing_connections.append(conn_info)
                    else:
                        other_connections.append(conn_info)
                
                # Display Azure AI Search connections
                if ai_search_connections:
                    print("\n📊 AZURE AI SEARCH CONNECTIONS:")
                    print("-" * 80)
                    for conn in ai_search_connections:
                        print(f"  Name: {conn['name']}")
                        print(f"  Type: {conn['type']}")
                        print(f"  ID: {conn['id']}")
                        print()
                        print(f"  💡 To use this connection, set in your .env:")
                        print(f"     AZURE_AI_SEARCH_SERVICE_NAME={conn['name']}")
                        print()
                        print(f"  ⚠️  You also need to specify the INDEX NAME:")
                        print(f"     AZURE_AI_SEARCH_INDEX_NAME=your-index-name")
                        print("-" * 80)
                
                # Display Bing connections
                if bing_connections:
                    print("\n🔍 BING CUSTOM SEARCH CONNECTIONS:")
                    print("-" * 80)
                    for conn in bing_connections:
                        print(f"  Name: {conn['name']}")
                        print(f"  Type: {conn['type']}")
                        print(f"  ID: {conn['id']}")
                        print()
                        print(f"  💡 To use this connection, set in your .env:")
                        print(f"     BING_CUSTOM_CONNECTION_NAME={conn['name']}")
                        print()
                        print(f"  ⚠️  You also need to specify the INSTANCE/CONFIGURATION NAME:")
                        print(f"     BING_CUSTOM_INSTANCE_NAME=your-custom-config-name")
                        print()
                        print(f"  📝 To find your Bing Custom instance name:")
                        print(f"     1. Go to Azure Portal → Your Bing Custom Search resource")
                        print(f"     2. Click 'Configuration' to see your custom search instances")
                        print(f"     3. Copy the instance name (e.g., 'WCG-Sites', 'MyCustomConfig')")
                        print("-" * 80)
                
                # Display other connections
                if other_connections:
                    print("\n🔧 OTHER CONNECTIONS:")
                    print("-" * 80)
                    for conn in other_connections:
                        print(f"  Name: {conn['name']}")
                        print(f"  Type: {conn['type']}")
                        print(f"  ID: {conn['id']}")
                        print("-" * 80)
                
                if not (ai_search_connections or bing_connections or other_connections):
                    print("\n⚠️  No connections found in this project.")
                    print("   Please add connections in Azure AI Foundry portal first.")
                
                print("\n" + "=" * 80)
                print("SUMMARY")
                print("=" * 80)
                print(f"Total connections found: {connection_count}")
                print(f"  - Azure AI Search: {len(ai_search_connections)}")
                print(f"  - Bing Custom Search: {len(bing_connections)}")
                print(f"  - Other: {len(other_connections)}")
                print()
                
            except Exception as e:
                print(f"❌ Error listing connections: {e}")
                print("\nTroubleshooting:")
                print("1. Make sure you're logged in: az login")
                print("2. Check your project endpoint is correct")
                print("3. Verify you have permissions to access the project")

if __name__ == "__main__":
    asyncio.run(discover_connections())
