output "resource_group_name" {
  description = "Resource group name. Useful for referencing in other modules or outputs."
  value       = azurerm_resource_group.rg.name
}

output "aks_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "acr_login_server" {
  description = "ACR login server URL."
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username. Only use for automation if admin_enabled is true (not recommended for production)."
  value       = azurerm_container_registry.acr.admin_username
}

output "acr_admin_password" {
  description = "ACR admin password. Sensitive output. Only use for automation if admin_enabled is true (not recommended for production)."
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}
