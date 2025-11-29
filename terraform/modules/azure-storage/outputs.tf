output "account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.main.name
}

output "primary_access_key" {
  description = "Primary access key"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "account_id" {
  description = "Storage account ID"
  value       = azurerm_storage_account.main.id
}

