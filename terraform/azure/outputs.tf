output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.cluster_name
}

output "aks_fqdn" {
  description = "AKS FQDN"
  value       = module.aks.fqdn
}

output "aks_kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.cluster_name}"
}

output "sql_server_fqdn" {
  description = "SQL Server FQDN"
  value       = module.sql.server_fqdn
  sensitive   = true
}

output "storage_account_name" {
  description = "Storage account name"
  value       = module.storage.account_name
}

output "traffic_manager_fqdn" {
  description = "Traffic Manager FQDN"
  value       = module.traffic_manager.fqdn
}

output "acr_login_server" {
  description = "ACR login server"
  value       = module.acr.login_server
}

output "managed_identity_id" {
  description = "Managed Identity ID"
  value       = azurerm_user_assigned_identity.aks.id
}
