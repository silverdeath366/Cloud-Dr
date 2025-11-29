# Azure SQL Module

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}-kv-${substr(md5(var.resource_group_name), 0, 8)}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
  }

  tags = var.tags
}

# Random password
resource "random_password" "sql_password" {
  length  = 32
  special = true
}

# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = "${var.project_name}-sql-${substr(md5(var.resource_group_name), 0, 8)}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = var.server_version
  administrator_login          = "cloudphoenixadmin"
  administrator_login_password = random_password.sql_password.result
  minimum_tls_version          = "1.2"

  tags = var.tags
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name           = "cloudphoenix"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = var.database_sku
  zone_redundant = false

  tags = var.tags
}

# Firewall Rule - Allow Azure Services
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall Rule - Allow VNET
resource "azurerm_mssql_virtual_network_rule" "vnet" {
  name      = "${var.project_name}-vnet-rule"
  server_id = azurerm_mssql_server.main.id
  subnet_id = var.vnet_subnet_id
}

# Store password in Key Vault
resource "azurerm_key_vault_secret" "sql_password" {
  name         = "${var.project_name}-sql-password"
  value        = random_password.sql_password.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault.main]
}
