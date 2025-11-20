# VA Chat - Deployment Guide

This guide walks you through deploying the VA Chat backend to Azure Container Apps using Terraform.

## Prerequisites

Before you begin, ensure you have:

- ✅ Azure CLI installed and authenticated (`az login`)
- ✅ Terraform installed (>= 1.0) - Install with: `winget install Hashicorp.Terraform`
- ✅ Docker installed and running
- ✅ Existing Azure resources:
  - Resource Group (`va-chat-rg`)
  - Azure AI Foundry Project with Agent

## Step-by-Step Deployment

### Step 1: Verify Azure Authentication

```powershell
# Login to Azure
az login

# Verify your subscription
az account show

# Set the correct subscription if needed
az account set --subscription <subscription-id>
```

### Step 2: Configure Terraform Variables

**🚀 Automated Method (Recommended):**

Use the automated scripts to read your `.env` file and detect existing Azure resources:

```powershell
# Navigate to terraform directory
cd terraform

# Generate terraform.tfvars from your .env file
.\parse-env.ps1

# Auto-detect existing Azure resources and update creation flags
.\detect-resources.ps1

# Review the generated configuration
notepad terraform.tfvars
```

The scripts will:
- ✅ Read all settings from your `.env` file
- ✅ Query Azure to find existing Container Registry, Log Analytics, and Container App Environments
- ✅ Automatically set `create_*` flags to avoid recreating existing resources
- ✅ Extract resource names from your existing infrastructure

**📝 Manual Method (Alternative):**

```powershell
# Navigate to terraform directory
cd terraform

# Copy the example configuration file
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit the file with your specific values
notepad terraform.tfvars
```

**Key configurations to verify in `terraform.tfvars`:**

```hcl
# Must match your .env file
va_resource_group = "va-chat-rg"

# Container Registry - Terraform will create a new ACR
create_container_registry = true
container_registry_name   = "vachatacr"  # Must be globally unique

# If Container Registry should be in a different resource group/location
# container_registry_resource_group = "acr-rg-name"
# container_registry_location = "eastus"

# Azure AI Foundry settings (from your .env)
azure_foundry_project_endpoint = "https://wk-aiservcs-eastus2.services.ai.azure.com/api/projects/wk-aiservcs-eastus2-project"
azure_foundry_agent_id         = "asst_fBEQHC9OTLQb8UgW4uLAx8TK"

# RBAC Configuration - Set this for automatic permission grants
ai_foundry_project_scope = ""  # Extract from your PROJECT_ENDPOINT
```

**Important - RBAC Configuration for Azure AI Foundry Projects:**

The new Azure AI Foundry uses **Projects** (not the old Hub/Workspace model). To enable automatic permission grants:

**Extract Project Resource ID from your endpoint:**

Your `.env` has:
```
AZURE_FOUNDRY_PROJECT_ENDPOINT=https://wk-aiservcs-eastus2.services.ai.azure.com/api/projects/wk-aiservcs-eastus2-project
```

**Important:** New Azure AI Foundry uses `Microsoft.CognitiveServices/accounts` (NOT the old `Microsoft.MachineLearningServices/workspaces`).

The account resource ID format is:
```
/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.CognitiveServices/accounts/{account-name}
```

Where `{account-name}` = `wk-aiservcs-eastus2` (the subdomain from your endpoint URL before `.services.ai.azure.com`)

**Find your project resource ID:**

```powershell
# Option 1: From Azure Portal
# Navigate to your AI Foundry account → Properties → Resource ID

# Option 2: Using Azure CLI (list all NEW AI Foundry accounts)
# For NEW Azure AI Foundry (Microsoft.CognitiveServices)
az cognitiveservices account list --query "[?kind=='AIServices'].{name:name, id:id, rg:resourceGroup}" --output table

# Option 3: Get specific account ID (extract account name from your endpoint)
# From: https://wk-aiservcs-eastus2.services.ai.azure.com/...
# Account name: wk-aiservcs-eastus2 (subdomain before .services.ai.azure.com)
az cognitiveservices account show --name wk-aiservcs-eastus2 --resource-group <your-rg> --query id -o tsv

# For OLD hub-based projects (DEPRECATED - not applicable to new Foundry)
# az resource list --resource-type "Microsoft.MachineLearningServices/workspaces" --query "[?tags.azureml.kind=='project'].{name:name, id:id, rg:resourceGroup}" --output table
```

Then add it to `terraform.tfvars`:
```hcl
ai_foundry_project_scope = "/subscriptions/abc-123.../resourceGroups/your-rg/providers/Microsoft.MachineLearningServices/workspaces/wk-aiservcs-eastus2-project"
ai_foundry_role = "Azure AI Developer"
```

**Recommended Role:** `Azure AI Developer` (grants development permissions for building agents, running evaluations)

**Note:** Azure Container Registry names must be globally unique. If `vachatacr` is taken, append random characters (e.g., `vachatacr123`).

### Step 3: Build and Push Docker Image

Use the automated build script (recommended):

```powershell
# Navigate to project root
cd ..

# Run the automated build and push script
.\scripts\build-and-push.ps1
```

The script will:
- Automatically detect ACR name from Terraform configuration
- Build the Docker image
- Login to Azure and ACR
- Tag and push the image to ACR
- Verify the image was pushed successfully

**Expected output:**
```
=== VA Chat - Docker Build and Push Script ===
Project Root: C:\Users\...
Found ACR from Terraform: vachatacr

Configuration:
  ACR Name:       vachatacr
  Image Name:     va-chat-backend
  Image Tag:      latest
  Local Tag:      va-chat-backend:latest
  ACR Tag:        vachatacr.azurecr.io/va-chat-backend:latest

=== Building Docker Image ===
[+] Building 45.2s (12/12) FINISHED
...
✓ Docker build completed successfully

=== Pushing to Azure Container Registry ===
✓ Logged in as: user@example.com
✓ ACR login successful
✓ Image tagged
Pushing image to ACR...
latest: digest: sha256:abc123... size: 2415
✓ Image pushed successfully

=== Deployment Complete ===
Image Location: vachatacr.azurecr.io/va-chat-backend:latest
✓ Image verified in ACR repository
Script completed successfully! 🎉
```

**Manual Build (Alternative):**

If you prefer manual control:

```powershell
# Build the Docker image
docker build -t va-chat-backend:latest .

# Set your ACR name
$acrName = "vachatacr"

# Login to ACR
az acr login --name $acrName

# Tag the image for ACR
docker tag va-chat-backend:latest "$acrName.azurecr.io/va-chat-backend:latest"

# Push the image
docker push "$acrName.azurecr.io/va-chat-backend:latest"
```

**Advanced Script Options:**

```powershell
# Build and push with custom tag
.\scripts\build-and-push.ps1 -ImageTag "v1.0.0"

# Push existing image without rebuilding
.\scripts\build-and-push.ps1 -SkipBuild

# Only build, don't push
.\scripts\build-and-push.ps1 -SkipPush

# Specify ACR name explicitly
.\scripts\build-and-push.ps1 -AcrName "myacr" -ImageTag "v1.0.0"
```

### Step 4: Initialize Terraform

```powershell
# Navigate back to terraform directory
cd terraform

# Initialize Terraform (downloads required providers)
terraform init
```

**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.0"...
- Installing hashicorp/azurerm v3.x.x...

Terraform has been successfully initialized!
```

### Step 5: Validate Configuration

```powershell
# Validate Terraform syntax
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### Step 6: Review Deployment Plan

```powershell
# Generate and review the execution plan
terraform plan
```

**⚠️ IMPORTANT**: Carefully review the plan output:

✅ **Look for these lines** (existing resources are safe):
```
data.azurerm_resource_group.va: Reading...
data.azurerm_container_registry.existing_acr: Reading...
```

✅ **Resources that will be created:**
```
# azurerm_container_app.va_chat will be created
# azurerm_user_assigned_identity.container_app will be created
# azurerm_container_app_environment.env will be created
# azurerm_log_analytics_workspace.logs will be created
```

❌ **STOP if you see**:
```
# azurerm_resource_group.va will be destroyed
# azurerm_container_registry.existing will be destroyed
```

### Step 7: Deploy Infrastructure

```powershell
# Apply the Terraform configuration
terraform apply
```

Review the plan one more time, then type `yes` when prompted.

**Expected output:**
```
Plan: 4 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

azurerm_user_assigned_identity.container_app: Creating...
azurerm_log_analytics_workspace.logs: Creating...
...
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

container_app_url = "https://va-chat-backend.xyz123.eastus2.azurecontainerapps.io"
azure_portal_link = "https://portal.azure.com/#resource/subscriptions/.../va-chat-backend"
managed_identity_principal_id = "12345678-1234-1234-1234-123456789012"
```

### Step 8: Verify RBAC Configuration

Check if RBAC was configured automatically:

```powershell
# Check RBAC status
terraform output rbac_configured
terraform output ai_foundry_role_assigned
```

**If RBAC was configured automatically:**
- ✅ Managed Identity has access to AI Foundry
- ✅ ACR Pull permissions granted (if ACR was created)
- ✅ Any additional role assignments applied

**If AI Foundry role shows "Manual configuration required":**

You need to configure the AI Foundry workspace ID in `terraform.tfvars`:

```hcl
# Get your AI Foundry workspace resource ID
ai_foundry_workspace_id = "/subscriptions/<subscription-id>/resourceGroups/<ai-foundry-rg>/providers/Microsoft.MachineLearningServices/workspaces/<workspace-name>"
```

Then run `terraform apply` again to grant permissions.

**Manual RBAC Configuration (if needed):**

If you prefer manual configuration or need additional permissions:

```powershell
# Get the managed identity principal ID
$principalId = terraform output -raw managed_identity_principal_id

# Grant AI Foundry permissions
az role assignment create `
  --assignee $principalId `
  --role "Cognitive Services OpenAI User" `
  --scope "/subscriptions/$subscription/resourceGroups/$aiFoundryRg/providers/Microsoft.MachineLearningServices/workspaces/$aiFoundryWorkspace"
```

**Available roles:**
- `Cognitive Services OpenAI User` (recommended for AI Foundry)
- `Cognitive Services User`
- `Azure AI Developer`

### Step 9: Verify Deployment

```powershell
# Get the application URL
$appUrl = terraform output -raw container_app_url

# Test the health endpoint
Invoke-WebRequest -Uri "$appUrl/api/health" | Select-Object -ExpandProperty Content
```

**Expected response:**
```json
{
  "status": "healthy",
  "service": "VA Chatbot API",
  "version": "1.0.0"
}
```

### Step 10: View in Azure Portal

```powershell
# Get the Azure Portal link
terraform output azure_portal_link

# Or open directly
$portalLink = terraform output -raw azure_portal_link
Start-Process $portalLink
```

## Viewing Application Logs

### Using Azure CLI

```powershell
# Stream logs from the container app
az containerapp logs show `
  --name va-chat-backend `
  --resource-group va-chat-rg `
  --follow
```

### Using Azure Portal

1. Navigate to your Container App in the portal
2. Click **Log stream** in the left menu
3. Select **Console logs**

## Updating the Deployment

### Update Application Code

```powershell
# 1. Build new image with version tag
docker build -t va-chat-backend:v1.1 .

# 2. Push to ACR
docker tag va-chat-backend:v1.1 $acrName.azurecr.io/va-chat-backend:v1.1
docker push $acrName.azurecr.io/va-chat-backend:v1.1

# 3. Update terraform.tfvars
# Change: container_image_tag = "v1.1"
notepad terraform\terraform.tfvars

# 4. Apply changes
cd terraform
terraform apply
```

### Update Environment Variables

```powershell
# 1. Edit terraform.tfvars
notepad terraform.tfvars

# 2. Apply changes
terraform apply
```

## Common Issues and Solutions

### Issue: "Error: Container Registry not found"

**Solution:**
```powershell
# Verify ACR exists and you have access
az acr show --name $acrName

# Check if it's in a different resource group
az acr list --output table
```

### Issue: "Error: Image pull authentication failed"

**Solution:**
```powershell
# Verify ACR admin is enabled
az acr update --name $acrName --admin-enabled true

# Or grant Managed Identity ACR Pull role
az role assignment create `
  --assignee $principalId `
  --role "AcrPull" `
  --scope "/subscriptions/$subscription/resourceGroups/$acrRg/providers/Microsoft.ContainerRegistry/registries/$acrName"
```

### Issue: "Container app fails to start"

**Solution:**
```powershell
# Check container app logs
az containerapp logs show `
  --name va-chat-backend `
  --resource-group va-chat-rg `
  --tail 50

# Check revision status
az containerapp revision list `
  --name va-chat-backend `
  --resource-group va-chat-rg `
  --output table
```

### Issue: "Authentication errors in application"

**Solution:**
```powershell
# Verify Managed Identity has correct permissions
az role assignment list --assignee $principalId --all --output table

# Test Managed Identity locally
az login --identity --username $principalId
```

## Cleaning Up Resources

⚠️ **Warning**: This will delete the Container App and associated resources created by Terraform.

```powershell
cd terraform
terraform destroy
```

**This will destroy:**
- Container App
- Managed Identity  
- Container App Environment (if created by Terraform)
- Log Analytics Workspace (if created by Terraform)

**This will NOT destroy:**
- Resource Groups
- Container Registry
- Azure AI Foundry resources
- Container images in ACR

## Production Considerations

### 1. Use Remote State

Store Terraform state in Azure Storage:

```hcl
# Add to main.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate12345"
    container_name       = "tfstate"
    key                  = "va-chat.tfstate"
  }
}
```

### 2. Use Semantic Versioning

Don't use `latest` tag in production:

```hcl
# terraform.tfvars
container_image_tag = "1.0.0"
```

### 3. Configure Custom Domain

```powershell
az containerapp hostname add `
  --hostname chat.yourdomain.com `
  --name va-chat-backend `
  --resource-group va-chat-rg
```

### 4. Enable Monitoring and Alerts

```powershell
# Create alert for failed requests
az monitor metrics alert create `
  --name "High Error Rate" `
  --resource-group va-chat-rg `
  --scopes $(terraform output -raw container_app_id) `
  --condition "avg Requests > 10" `
  --window-size 5m
```

### 5. Implement CI/CD

Consider setting up automated deployments using:
- Azure DevOps Pipelines
- GitHub Actions
- GitLab CI/CD

## Next Steps

1. ✅ Configure custom domain and SSL certificate
2. ✅ Set up Azure Front Door for global distribution
3. ✅ Configure autoscaling rules based on load
4. ✅ Implement monitoring dashboards in Azure Monitor
5. ✅ Set up backup and disaster recovery procedures
6. ✅ Configure Azure Key Vault for secrets management
7. ✅ Implement blue-green deployment strategy

## Support Resources

- [Terraform README](./terraform/README.md) - Detailed configuration reference
- [Azure Container Apps Docs](https://learn.microsoft.com/azure/container-apps/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Summary

You've successfully deployed the VA Chat backend to Azure Container Apps! Your application is now running at the URL provided in the Terraform outputs.

**Quick verification checklist:**
- ✅ Health endpoint returns 200 OK
- ✅ Managed Identity has AI Foundry permissions
- ✅ Container App logs show successful startup
- ✅ Test chat endpoint with sample request
- ✅ Monitor logs for any errors

Your deployment is complete! 🎉

