terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

provider "azuread" {
}

# Data sources for existing resources
data "azurerm_resource_group" "va" {
  name = var.va_resource_group
}

data "azurerm_resource_group" "container_app" {
  count = var.container_app_resource_group != "" && var.container_app_resource_group != var.va_resource_group ? 1 : 0
  name  = var.container_app_resource_group != "" ? var.container_app_resource_group : var.va_resource_group
}

# Container Registry (if it doesn't exist)
resource "azurerm_container_registry" "acr" {
  count               = var.create_container_registry ? 1 : 0
  name                = var.container_registry_name
  resource_group_name = var.container_registry_resource_group != "" ? var.container_registry_resource_group : data.azurerm_resource_group.va.name
  location            = var.container_registry_location != "" ? var.container_registry_location : data.azurerm_resource_group.va.location
  sku                 = "Standard"
  admin_enabled       = true

  tags = var.tags
}

# Reference existing Container Registry if not creating new one
data "azurerm_container_registry" "existing_acr" {
  count               = var.create_container_registry ? 0 : 1
  name                = var.container_registry_name
  resource_group_name = var.container_registry_resource_group != "" ? var.container_registry_resource_group : data.azurerm_resource_group.va.name
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "logs" {
  count               = var.create_log_analytics ? 1 : 0
  name                = var.log_analytics_workspace_name
  location            = var.container_app_location != "" ? var.container_app_location : data.azurerm_resource_group.va.location
  resource_group_name = length(data.azurerm_resource_group.container_app) > 0 ? data.azurerm_resource_group.container_app[0].name : data.azurerm_resource_group.va.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Reference existing Log Analytics Workspace if not creating new one
data "azurerm_log_analytics_workspace" "existing_logs" {
  count               = var.create_log_analytics ? 0 : 1
  name                = var.log_analytics_workspace_name
  resource_group_name = length(data.azurerm_resource_group.container_app) > 0 ? data.azurerm_resource_group.container_app[0].name : data.azurerm_resource_group.va.name
}

locals {
  log_analytics_workspace_id     = var.create_log_analytics ? azurerm_log_analytics_workspace.logs[0].id : data.azurerm_log_analytics_workspace.existing_logs[0].id
  log_analytics_workspace_key    = var.create_log_analytics ? azurerm_log_analytics_workspace.logs[0].primary_shared_key : data.azurerm_log_analytics_workspace.existing_logs[0].primary_shared_key
  container_registry_server      = var.create_container_registry ? azurerm_container_registry.acr[0].login_server : data.azurerm_container_registry.existing_acr[0].login_server
  container_registry_username    = var.create_container_registry ? azurerm_container_registry.acr[0].admin_username : data.azurerm_container_registry.existing_acr[0].admin_username
  container_registry_password    = var.create_container_registry ? azurerm_container_registry.acr[0].admin_password : data.azurerm_container_registry.existing_acr[0].admin_password
  container_app_resource_group   = length(data.azurerm_resource_group.container_app) > 0 ? data.azurerm_resource_group.container_app[0].name : data.azurerm_resource_group.va.name
}

# Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  count                          = var.create_container_app_environment ? 1 : 0
  name                           = var.container_app_environment_name
  location                       = var.container_app_location != "" ? var.container_app_location : data.azurerm_resource_group.va.location
  resource_group_name            = local.container_app_resource_group
  log_analytics_workspace_id     = local.log_analytics_workspace_id
  
  tags = var.tags
}

# Reference existing Container App Environment if not creating new one
data "azurerm_container_app_environment" "existing_env" {
  count               = var.create_container_app_environment ? 0 : 1
  name                = var.container_app_environment_name
  resource_group_name = local.container_app_resource_group
}

locals {
  container_app_environment_id = var.create_container_app_environment ? azurerm_container_app_environment.env[0].id : data.azurerm_container_app_environment.existing_env[0].id
}

# User-Assigned Managed Identity for Container App
resource "azurerm_user_assigned_identity" "container_app" {
  name                = var.managed_identity_name
  location            = var.container_app_location != "" ? var.container_app_location : data.azurerm_resource_group.va.location
  resource_group_name = local.container_app_resource_group

  tags = var.tags
}

# RBAC: Azure AI Foundry Project Access
resource "azurerm_role_assignment" "ai_foundry_project" {
  count                = var.configure_rbac && var.ai_foundry_project_scope != "" ? 1 : 0
  scope                = var.ai_foundry_project_scope
  role_definition_name = var.ai_foundry_role
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
  
  skip_service_principal_aad_check = true
}

# RBAC: ACR Pull Permission (if using created ACR)
resource "azurerm_role_assignment" "acr_pull" {
  count                = var.create_container_registry ? 1 : 0
  scope                = azurerm_container_registry.acr[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
  
  skip_service_principal_aad_check = true
}

# RBAC: Additional Role Assignments
resource "azurerm_role_assignment" "additional" {
  count                = var.configure_rbac ? length(var.additional_role_assignments) : 0
  scope                = var.additional_role_assignments[count.index].scope
  role_definition_name = var.additional_role_assignments[count.index].role_definition_name
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
  
  skip_service_principal_aad_check = true
}

# Container App
resource "azurerm_container_app" "va_chat" {
  name                         = var.container_app_name
  container_app_environment_id = local.container_app_environment_id
  resource_group_name          = local.container_app_resource_group
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server               = local.container_registry_server
    username             = local.container_registry_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.container_registry_password
  }

  template {
    container {
      name   = "va-chat-backend"
      image  = "${local.container_registry_server}/${var.container_image_name}:${var.container_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "AZURE_FOUNDRY_PROJECT_ENDPOINT"
        value = var.azure_foundry_project_endpoint
      }

      env {
        name  = "AZURE_FOUNDRY_REGION"
        value = var.azure_foundry_region
      }

      env {
        name  = "AZURE_FOUNDRY_DEPLOYMENT_NAME"
        value = var.azure_foundry_deployment_name
      }

      env {
        name  = "AZURE_DEPLOYMENT_VERSION"
        value = var.azure_deployment_version
      }

      env {
        name  = "AZURE_FOUNDRY_AGENT_ID"
        value = var.azure_foundry_agent_id
      }

      env {
        name  = "AZURE_TENANT_ID"
        value = var.azure_tenant_id
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.container_app.client_id
      }

      env {
        name  = "MANAGED_IDENTITY_CLIENT_ID"
        value = azurerm_user_assigned_identity.container_app.client_id
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }

      env {
        name  = "PORT"
        value = "8080"
      }

      dynamic "env" {
        for_each = var.azure_search_endpoint != "" ? [1] : []
        content {
          name  = "AZURE_SEARCH_ENDPOINT"
          value = var.azure_search_endpoint
        }
      }

      dynamic "env" {
        for_each = var.azure_search_index_name != "" ? [1] : []
        content {
          name  = "AZURE_SEARCH_INDEX_NAME"
          value = var.azure_search_index_name
        }
      }

      dynamic "env" {
        for_each = var.azure_bot_id != "" ? [1] : []
        content {
          name  = "AZURE_BOT_ID"
          value = var.azure_bot_id
        }
      }

      dynamic "env" {
        for_each = var.azure_bot_endpoint != "" ? [1] : []
        content {
          name  = "AZURE_BOT_ENDPOINT"
          value = var.azure_bot_endpoint
        }
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags
}

