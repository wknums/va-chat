#!/bin/bash
# Parse .env file and generate Terraform variables
# This script reads your .env file and creates terraform.tfvars automatically

set -e

ENV_FILE="../.env"
OUTPUT_FILE="terraform.tfvars"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

echo "=== Parsing .env file to generate terraform.tfvars ==="
echo ""

# Source the .env file
set -a
source "$ENV_FILE"
set +a

# Start building terraform.tfvars
cat > "$OUTPUT_FILE" << 'EOF'
# Auto-generated from .env file
# Generated at: $(date)

# Resource Groups
wcg_resource_group = "${WCG_RESOURCE_GROUP}"
EOF

# Add container app resource group if specified
if [ -n "$CONTAINER_APP_RESOURCE_GROUP" ]; then
    echo "container_app_resource_group = \"$CONTAINER_APP_RESOURCE_GROUP\"" >> "$OUTPUT_FILE"
fi

# Azure AI Foundry settings
cat >> "$OUTPUT_FILE" << EOF

# Azure AI Foundry Configuration
azure_foundry_project_endpoint  = "$AZURE_FOUNDRY_PROJECT_ENDPOINT"
azure_foundry_region            = "$AZURE_FOUNDRY_REGION"
azure_foundry_deployment_name   = "$AZURE_FOUNDRY_DEPLOYMENT_NAME"
azure_deployment_version        = "$AZURE_DEPLOYMENT_VERSION"
azure_foundry_agent_id          = "$AZURE_FOUNDRY_AGENT_ID"

# Azure Entra ID
azure_tenant_id = "$AZURE_TENANT_ID"
EOF

# Add optional services if they exist
if [ -n "$AZURE_SEARCH_ENDPOINT" ]; then
    echo "azure_search_endpoint = \"$AZURE_SEARCH_ENDPOINT\"" >> "$OUTPUT_FILE"
fi

if [ -n "$AZURE_SEARCH_INDEX_NAME" ]; then
    echo "azure_search_index_name = \"$AZURE_SEARCH_INDEX_NAME\"" >> "$OUTPUT_FILE"
fi

if [ -n "$AZURE_BOT_ID" ]; then
    echo "azure_bot_id = \"$AZURE_BOT_ID\"" >> "$OUTPUT_FILE"
fi

if [ -n "$AZURE_BOT_ENDPOINT" ]; then
    echo "azure_bot_endpoint = \"$AZURE_BOT_ENDPOINT\"" >> "$OUTPUT_FILE"
fi

# Add container app name if specified
if [ -n "$CONTAINER_APP_NAME" ]; then
    cat >> "$OUTPUT_FILE" << EOF

# Container App Configuration
container_app_name = "$CONTAINER_APP_NAME"
EOF
fi

# Add environment and logging
cat >> "$OUTPUT_FILE" << EOF

# Application Settings
environment = "$ENVIRONMENT"
log_level   = "$LOG_LEVEL"

# Resource Creation Flags
# Set these based on whether resources already exist
# Check with: az containerapp env list --resource-group $WCG_RESOURCE_GROUP
create_container_registry        = false  # Set to true if you want to create a new ACR
create_log_analytics             = true   # Set to false if you have existing Log Analytics
create_container_app_environment = true   # Set to false if you have existing Container App Environment

# Container Registry Configuration
# If using existing ACR, specify its name:
container_registry_name = "vachatacr"  # Change this to your ACR name

# RBAC Configuration
configure_rbac = true

# Extract AI Foundry account resource ID with:
# az cognitiveservices account show --name wk-aiservcs-eastus2 --resource-group $WCG_RESOURCE_GROUP --query id -o tsv
ai_foundry_project_scope = ""  # Paste the resource ID here for automatic RBAC
ai_foundry_role          = "Azure AI Developer"
EOF

echo "✓ Generated $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Edit $OUTPUT_FILE and set the resource creation flags"
echo "2. Add your AI Foundry project scope for RBAC"
echo "3. Run: terraform init"
echo "4. Run: terraform plan"

