# Resource Group Variables
variable "va_resource_group" {
  description = "Name of the existing VA resource group"
  type        = string
}

variable "container_app_resource_group" {
  description = "Name of the resource group for Container App (can be different from va_resource_group). Leave empty to use va_resource_group"
  type        = string
  default     = ""
}

# Location Variables
variable "container_app_location" {
  description = "Azure location for Container App resources. Leave empty to use resource group location"
  type        = string
  default     = ""
}

variable "container_registry_location" {
  description = "Azure location for Container Registry. Leave empty to use resource group location"
  type        = string
  default     = ""
}

# Container Registry Variables
variable "create_container_registry" {
  description = "Whether to create a new Container Registry (true) or use existing one (false)"
  type        = bool
  default     = false
}

variable "container_registry_name" {
  description = "Name of the Container Registry"
  type        = string
}

variable "container_registry_resource_group" {
  description = "Resource group for Container Registry. Leave empty to use va_resource_group"
  type        = string
  default     = ""
}

# Log Analytics Variables
variable "create_log_analytics" {
  description = "Whether to create a new Log Analytics Workspace (true) or use existing one (false)"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
  default     = "va-chat-logs"
}

# Container App Environment Variables
variable "create_container_app_environment" {
  description = "Whether to create a new Container App Environment (true) or use existing one (false)"
  type        = bool
  default     = true
}

variable "container_app_environment_name" {
  description = "Name of the Container App Environment"
  type        = string
  default     = "va-chat-env"
}

# Container App Variables
variable "container_app_name" {
  description = "Name of the Container App"
  type        = string
  default     = "va-chat-backend"
}

variable "managed_identity_name" {
  description = "Name of the User-Assigned Managed Identity"
  type        = string
  default     = "va-chat-identity"
}

variable "container_image_name" {
  description = "Name of the container image"
  type        = string
  default     = "va-chat-backend"
}

variable "container_image_tag" {
  description = "Tag of the container image"
  type        = string
  default     = "latest"
}

variable "container_cpu" {
  description = "CPU allocation for the container (e.g., 0.25, 0.5, 1.0)"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocation for the container (e.g., '0.5Gi', '1Gi')"
  type        = string
  default     = "1Gi"
}

variable "min_replicas" {
  description = "Minimum number of container replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of container replicas"
  type        = number
  default     = 3
}

# Azure AI Foundry Variables
variable "azure_foundry_project_endpoint" {
  description = "Azure AI Foundry project endpoint"
  type        = string
}

variable "azure_foundry_region" {
  description = "Azure AI Foundry region"
  type        = string
}

variable "azure_foundry_deployment_name" {
  description = "Azure AI Foundry deployment name"
  type        = string
}

variable "azure_deployment_version" {
  description = "Azure deployment version"
  type        = string
}

variable "azure_foundry_agent_id" {
  description = "Azure AI Foundry agent ID"
  type        = string
  sensitive   = true
}

# Azure Entra ID Variables
variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

# Optional Azure Services Variables
variable "azure_search_endpoint" {
  description = "Azure AI Search endpoint (optional)"
  type        = string
  default     = ""
}

variable "azure_search_index_name" {
  description = "Azure AI Search index name (optional)"
  type        = string
  default     = ""
}

variable "azure_bot_id" {
  description = "Azure Bot Framework ID (optional)"
  type        = string
  default     = ""
}

variable "azure_bot_endpoint" {
  description = "Azure Bot Framework endpoint (optional)"
  type        = string
  default     = ""
}

# Application Variables
variable "environment" {
  description = "Application environment (development, staging, production)"
  type        = string
  default     = "production"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
}

# RBAC Configuration Variables
variable "configure_rbac" {
  description = "Whether to configure RBAC role assignments for the Managed Identity"
  type        = bool
  default     = true
}

variable "ai_foundry_project_scope" {
  description = "Resource ID of the Azure AI Foundry project for RBAC assignment. Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.MachineLearningServices/workspaces/{project-name}. Leave empty to skip AI Foundry RBAC."
  type        = string
  default     = ""
}

variable "ai_foundry_role" {
  description = "Role to assign for Azure AI Foundry project access"
  type        = string
  default     = "Azure AI Developer"
}

variable "additional_role_assignments" {
  description = "Additional role assignments for the Managed Identity"
  type = list(object({
    role_definition_name = string
    scope                = string
  }))
  default = []
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "va-chat"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

