output "container_app_name" {
  description = "Name of the Container App"
  value       = azurerm_container_app.va_chat.name
}

output "container_app_fqdn" {
  description = "Fully Qualified Domain Name of the Container App"
  value       = azurerm_container_app.va_chat.ingress[0].fqdn
}

output "container_app_url" {
  description = "URL to access the Container App"
  value       = "https://${azurerm_container_app.va_chat.ingress[0].fqdn}"
}

output "container_app_id" {
  description = "Resource ID of the Container App"
  value       = azurerm_container_app.va_chat.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.container_app.principal_id
}

output "managed_identity_client_id" {
  description = "Client ID of the User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.container_app.client_id
}

output "managed_identity_id" {
  description = "Resource ID of the User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.container_app.id
}

output "container_registry_login_server" {
  description = "Login server URL for the Container Registry"
  value       = local.container_registry_server
}

output "container_app_environment_id" {
  description = "Resource ID of the Container App Environment"
  value       = local.container_app_environment_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace"
  value       = local.log_analytics_workspace_id
}

output "resource_group_name" {
  description = "Name of the resource group containing the Container App"
  value       = local.container_app_resource_group
}

output "azure_portal_link" {
  description = "Direct link to the Container App in Azure Portal"
  value       = "https://portal.azure.com/#resource${azurerm_container_app.va_chat.id}"
}

output "rbac_configured" {
  description = "Whether RBAC role assignments were configured"
  value       = var.configure_rbac
}

output "ai_foundry_role_assigned" {
  description = "Whether AI Foundry project role was assigned"
  value       = var.configure_rbac && var.ai_foundry_project_scope != "" ? "Yes - ${var.ai_foundry_role} on project" : "No - Manual configuration required"
}
