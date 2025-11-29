terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.azure_location

  tags = var.tags
}

# VNET Module
module "vnet" {
  source = "../modules/azure-vnet"

  project_name       = var.project_name
  resource_group_name = azurerm_resource_group.main.name
  location           = var.azure_location
  address_space      = var.vnet_address_space
  environment        = var.environment
  tags               = var.tags
}

# AKS Module
module "aks" {
  source = "../modules/azure-aks"

  project_name       = var.project_name
  resource_group_name = azurerm_resource_group.main.name
  location           = var.azure_location
  vnet_subnet_id     = module.vnet.aks_subnet_id
  node_count         = var.aks_node_count
  vm_size            = var.aks_vm_size
  kubernetes_version = var.aks_kubernetes_version
  environment        = var.environment
  tags               = var.tags
}

# Azure SQL Module
module "sql" {
  source = "../modules/azure-sql"

  project_name       = var.project_name
  resource_group_name = azurerm_resource_group.main.name
  location           = var.azure_location
  vnet_subnet_id     = module.vnet.private_subnet_id
  server_version     = var.sql_server_version
  database_sku       = var.sql_database_sku
  environment        = var.environment
  tags               = var.tags
}

# Storage Account Module
module "storage" {
  source = "../modules/azure-storage"

  project_name       = var.project_name
  resource_group_name = azurerm_resource_group.main.name
  location           = var.azure_location
  environment        = var.environment
  tags               = var.tags
}

# Traffic Manager Module
module "traffic_manager" {
  source = "../modules/azure-traffic-manager"

  project_name       = var.project_name
  resource_group_name = azurerm_resource_group.main.name
  location           = var.azure_location
  environment        = var.environment
  tags               = var.tags
}

# Container Registry Module
module "acr" {
  source = "../modules/azure-acr"

  project_name       = var.project_name
  resource_group_name = azurerm_resource_group.main.name
  location           = var.azure_location
  environment        = var.environment
  tags               = var.tags
}

# RBAC and Managed Identity
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.project_name}-aks-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.azure_location

  tags = var.tags
}

