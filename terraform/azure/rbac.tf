# RBAC and Managed Identity for Azure

# Role assignment for AKS to access Key Vault
resource "azurerm_role_assignment" "aks_key_vault" {
  scope                = module.sql.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Role assignment for AKS to access Storage
resource "azurerm_role_assignment" "aks_storage" {
  scope                = module.storage.account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Role assignment for AKS to access SQL
resource "azurerm_role_assignment" "aks_sql" {
  scope                = module.sql.server_id
  role_definition_name = "SQL Server Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

