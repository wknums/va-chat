# Parse .env file and generate Terraform variables
# This script reads your .env file and creates terraform.tfvars automatically

$ErrorActionPreference = "Stop"

$EnvFile = Join-Path $PSScriptRoot ".." ".env"
$OutputFile = Join-Path $PSScriptRoot "terraform.tfvars"

if (-not (Test-Path $EnvFile)) {
    Write-Error ".env file not found at $EnvFile"
    exit 1
}

Write-Host "=== Parsing .env file to generate terraform.tfvars ===" -ForegroundColor Cyan
Write-Host ""

# Parse .env file
$envVars = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            $envVars[$key] = $value
        }
    }
}

# Start building terraform.tfvars
$content = @"
# Auto-generated from .env file
# Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Resource Groups
va_resource_group = "$($envVars['VA_RESOURCE_GROUP'])"
"@

# Add container app resource group if specified
if ($envVars['CONTAINER_APP_RESOURCE_GROUP']) {
    $content += "`ncontainer_app_resource_group = `"$($envVars['CONTAINER_APP_RESOURCE_GROUP'])`""
}

# Azure AI Foundry settings
$content += @"

# Azure AI Foundry Configuration
azure_foundry_project_endpoint  = "$($envVars['AZURE_FOUNDRY_PROJECT_ENDPOINT'])"
azure_foundry_region            = "$($envVars['AZURE_FOUNDRY_REGION'])"
azure_foundry_deployment_name   = "$($envVars['AZURE_FOUNDRY_DEPLOYMENT_NAME'])"
azure_deployment_version        = "$($envVars['AZURE_DEPLOYMENT_VERSION'])"
azure_foundry_agent_id          = "$($envVars['AZURE_FOUNDRY_AGENT_ID'])"

# Azure Entra ID
azure_tenant_id = "$($envVars['AZURE_TENANT_ID'])"
"@

# Add optional services if they exist
if ($envVars['AZURE_SEARCH_ENDPOINT']) {
    $content += "`nazure_search_endpoint = `"$($envVars['AZURE_SEARCH_ENDPOINT'])`""
}

if ($envVars['AZURE_SEARCH_INDEX_NAME']) {
    $content += "`nazure_search_index_name = `"$($envVars['AZURE_SEARCH_INDEX_NAME'])`""
}

if ($envVars['AZURE_BOT_ID']) {
    $content += "`nazure_bot_id = `"$($envVars['AZURE_BOT_ID'])`""
}

if ($envVars['AZURE_BOT_ENDPOINT']) {
    $content += "`nazure_bot_endpoint = `"$($envVars['AZURE_BOT_ENDPOINT'])`""
}

# Add container app name if specified
if ($envVars['CONTAINER_APP_NAME']) {
    $content += @"

# Container App Configuration
container_app_name = "$($envVars['CONTAINER_APP_NAME'])"
"@
}

# Add environment and logging
$content += @"

# Application Settings
environment = "$($envVars['ENVIRONMENT'])"
log_level   = "$($envVars['LOG_LEVEL'])"

# Resource Creation Flags
# Set these based on whether resources already exist
create_container_registry        = false  # Set to true if you want to create a new ACR
create_log_analytics             = true   # Set to false if you have existing Log Analytics
create_container_app_environment = true   # Set to false if you have existing Container App Environment

# Container Registry Configuration
# If using existing ACR, specify its name:
container_registry_name = "vachatacr"  # Change this to your ACR name

# RBAC Configuration
configure_rbac = true

# Extract AI Foundry account resource ID with:
# az cognitiveservices account show --name wk-aiservcs-eastus2 --resource-group $($envVars['VA_RESOURCE_GROUP']) --query id -o tsv
ai_foundry_project_scope = ""  # Paste the resource ID here for automatic RBAC
ai_foundry_role          = "Azure AI Developer"

# Tags
tags = {
  Project     = "va-chat"
  ManagedBy   = "Terraform"
  Environment = "$($envVars['ENVIRONMENT'])"
}
"@

# Write to file
$content | Out-File -FilePath $OutputFile -Encoding utf8 -NoNewline

Write-Host "✓ Generated $OutputFile" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Edit $OutputFile and verify/adjust the resource creation flags"
Write-Host "2. Check if resources exist:"
Write-Host "   - ACR: az acr list --resource-group $($envVars['VA_RESOURCE_GROUP']) --query '[].name' -o tsv" -ForegroundColor Gray
Write-Host "   - Log Analytics: az monitor log-analytics workspace list --resource-group $($envVars['VA_RESOURCE_GROUP']) --query '[].name' -o tsv" -ForegroundColor Gray
Write-Host "   - Container App Env: az containerapp env list --resource-group $($envVars['VA_RESOURCE_GROUP']) --query '[].name' -o tsv" -ForegroundColor Gray
Write-Host "3. Add your AI Foundry account resource ID for RBAC"
Write-Host "4. Run: terraform init" -ForegroundColor Cyan
Write-Host "5. Run: terraform plan" -ForegroundColor Cyan

