output "server_fqdn" {
  description = "SQL Server FQDN"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
  sensitive   = true
}

output "database_name" {
  description = "Database name"
  value       = azurerm_mssql_database.main.name
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.main.id
}

output "server_id" {
  description = "SQL Server ID"
  value       = azurerm_mssql_server.main.id
}

