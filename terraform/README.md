# VA Chat - Terraform Deployment Guide

This directory contains Terraform configuration for deploying the VA Chat backend as an Azure Container App.

## Overview

The Terraform configuration deploys:
- **Azure Container App** - Runs the FastAPI backend
- **User-Assigned Managed Identity** - For secure authentication
- **Container App Environment** (optional) - Hosting environment for the container app
- **Log Analytics Workspace** (optional) - For monitoring and logs
- **Container Registry** (optional) - Can reference existing or create new

## Key Features

✅ **Protects Existing Resources** - Uses data sources to reference existing Azure resources without destroying them  
✅ **Multi-Location Support** - Resources can exist in different Azure regions  
✅ **Multi-Resource Group Support** - Resources can exist in different resource groups  
✅ **Flexible Configuration** - Choose to create new resources or use existing ones  
✅ **Secure by Default** - Uses Managed Identity for authentication  

## Prerequisites

1. **Terraform** installed (>= 1.0)
   ```powershell
   winget install Hashicorp.Terraform
   ```

2. **Azure CLI** installed and authenticated
   ```powershell
   az login
   az account set --subscription <subscription-id>
   ```

3. **Docker** installed (for building the container image)

4. **Existing Azure Resources** (referenced, not created):
   - Resource Group (specified in .env as VA_RESOURCE_GROUP)
   - Azure AI Foundry Project with Agent
   - Container Registry (if not creating new one)

## Quick Start (Automated)

### Option A: Automated Configuration from .env

The easiest way to configure Terraform is to use the automated scripts that read your `.env` file and detect existing Azure resources:

```powershell
cd terraform

# Step 1: Generate terraform.tfvars from your .env file
.\parse-env.ps1

# Step 2: Auto-detect existing Azure resources and update flags
.\detect-resources.ps1

# Step 3: Review the generated configuration
notepad terraform.tfvars

# Step 4: Initialize and deploy
terraform init
terraform plan
terraform apply
```

**What these scripts do:**
- `parse-env.ps1` - Reads your `.env` file and generates `terraform.tfvars` with all your settings
- `detect-resources.ps1` - Queries Azure to find existing ACR, Log Analytics, and Container App Environments, then updates the creation flags automatically

**Dry run mode** (preview without making changes):
```powershell
.\detect-resources.ps1 -DryRun
```

### Option B: Manual Configuration

Copy the example file and customize it:

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

Edit `terraform.tfvars` and configure:

- **Resource Groups**: Set `va_resource_group` to match your .env file
- **Container Registry**: Set `create_container_registry = false` if using existing ACR
- **Locations**: Specify different locations if resources span multiple regions
- **Azure AI Foundry**: Verify endpoint, region, deployment, and agent ID match your .env

### 2. Build and Push Container Image

Build the Docker image:

```powershell
# From project root
docker build -t va-chat-backend:latest .
```

Push to Azure Container Registry:

```powershell
# Login to ACR
az acr login --name <your-acr-name>

# Tag image
docker tag va-chat-backend:latest <your-acr-name>.azurecr.io/va-chat-backend:latest

# Push image
docker push <your-acr-name>.azurecr.io/va-chat-backend:latest
```

### 3. Initialize Terraform

```powershell
cd terraform
terraform init
```

### 4. Review Deployment Plan

```powershell
terraform plan
```

**Important**: Review the plan carefully to ensure:
- ✅ No existing resources are being destroyed
- ✅ Only new resources are being created
- ✅ Data sources correctly reference existing resources

### 5. Deploy

```powershell
# Validate configuration
terraform validate

# Apply changes
terraform apply
```

Review the changes and type `yes` to confirm.

### 6. Configure Managed Identity Permissions

After deployment, grant the Managed Identity permissions to access Azure AI Foundry:

```powershell
# Get the managed identity principal ID from Terraform output
$principalId = terraform output -raw managed_identity_principal_id

# Grant Azure AI Foundry permissions
az role assignment create `
  --assignee $principalId `
  --role "Azure AI Foundry User" `
  --scope "/subscriptions/<subscription-id>/resourceGroups/<ai-foundry-rg>/providers/Microsoft.MachineLearningServices/workspaces/<ai-foundry-project>"
```

## Terraform Outputs

After successful deployment, Terraform provides:

- `container_app_url` - HTTPS URL to access your application
- `container_app_fqdn` - Fully qualified domain name
- `managed_identity_client_id` - For configuring authentication
- `azure_portal_link` - Direct link to Container App in Azure Portal

View outputs:

```powershell
terraform output
```

## Configuration Variables

### Required Variables

| Variable | Description | Source |
|----------|-------------|--------|
| `va_resource_group` | Existing resource group name | .env file |
| `azure_foundry_project_endpoint` | AI Foundry endpoint | .env file |
| `azure_foundry_agent_id` | Agent ID | .env file |
| `azure_tenant_id` | Azure tenant ID | .env file |
| `container_registry_name` | ACR name | Your Azure environment |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `container_app_resource_group` | Different RG for Container App | Uses `va_resource_group` |
| `container_app_location` | Azure region for Container App | Uses RG location |
| `create_container_registry` | Create new ACR | `false` |
| `create_log_analytics` | Create new Log Analytics | `true` |
| `container_cpu` | CPU allocation | `0.5` |
| `container_memory` | Memory allocation | `1Gi` |
| `min_replicas` | Minimum replicas | `1` |
| `max_replicas` | Maximum replicas | `3` |

See `variables.tf` for complete list.

## Multi-Region Deployment

If your resources span multiple regions:

```hcl
# terraform.tfvars
container_app_location = "eastus2"
container_registry_location = "eastus"
```

Terraform will correctly reference resources regardless of location.

## Multi-Resource Group Deployment

If your resources span multiple resource groups:

```hcl
# terraform.tfvars
va_resource_group = "va-chat-rg"
container_app_resource_group = "va-containers-rg"
container_registry_resource_group = "shared-acr-rg"
```

## Updating the Deployment

### Update Container Image

1. Build and push new image with new tag:
   ```powershell
   docker build -t va-chat-backend:v1.1 .
   docker tag va-chat-backend:v1.1 <acr>.azurecr.io/va-chat-backend:v1.1
   docker push <acr>.azurecr.io/va-chat-backend:v1.1
   ```

2. Update `terraform.tfvars`:
   ```hcl
   container_image_tag = "v1.1"
   ```

3. Apply changes:
   ```powershell
   terraform apply
   ```

### Update Environment Variables

Edit `terraform.tfvars` and run:

```powershell
terraform apply
```

## Destroying Resources

**⚠️ WARNING**: Only destroys resources created by Terraform, not existing resources.

```powershell
terraform destroy
```

This will destroy:
- Container App
- Managed Identity
- Container App Environment (if created)
- Log Analytics Workspace (if created)

This will NOT destroy:
- Resource Groups
- Container Registry (if existing)
- Azure AI Foundry resources

## Troubleshooting

### Authentication Errors

Ensure you're logged in to Azure:

```powershell
az login
az account show
```

### Container App Fails to Start

Check logs:

```powershell
az containerapp logs show `
  --name va-chat-backend `
  --resource-group <rg-name> `
  --follow
```

### Managed Identity Permissions

Verify the identity has proper role assignments:

```powershell
$principalId = terraform output -raw managed_identity_principal_id
az role assignment list --assignee $principalId --all
```

### Image Pull Errors

Verify ACR credentials and image exists:

```powershell
az acr repository list --name <acr-name>
az acr repository show-tags --name <acr-name> --repository va-chat-backend
```

## Best Practices

1. **Version Control** - Commit Terraform files but NOT `terraform.tfvars` (contains secrets)
2. **State Management** - Consider using Azure Storage for remote state in production
3. **Environment Separation** - Use workspaces or separate state files for dev/staging/prod
4. **Secrets Management** - Use Azure Key Vault for sensitive configuration
5. **Image Tags** - Use semantic versioning, not `latest` in production
6. **Monitoring** - Configure alerts in Azure Monitor for the Container App

## Resources Created

| Resource Type | Configurable | Default Behavior |
|---------------|--------------|------------------|
| Container App | ✅ Always created | Named `va-chat-backend` |
| Managed Identity | ✅ Always created | Named `va-chat-identity` |
| Container App Environment | ⚙️ Optional | Created by default |
| Log Analytics Workspace | ⚙️ Optional | Created by default |
| Container Registry | ⚙️ Optional | Uses existing by default |

## Next Steps

1. Configure custom domain for the Container App
2. Set up Azure Front Door for global load balancing
3. Configure monitoring and alerts
4. Set up CI/CD pipeline for automated deployments
5. Implement blue-green or canary deployment strategies

## Support

For issues or questions:
- Review Terraform plan output carefully
- Check Azure Portal for resource status
- Review Container App logs
- Verify Managed Identity has proper permissions

## References

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure AI Foundry Documentation](https://learn.microsoft.com/azure/ai-foundry/)

