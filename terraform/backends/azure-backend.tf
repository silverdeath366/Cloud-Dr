# Azure Terraform Backend Configuration
# Store state in Azure Storage

terraform {
  backend "azurerm" {
    resource_group_name  = "cloudphoenix-terraform-rg"
    storage_account_name = "cloudphoenixtfstate"
    container_name       = "terraform-state"
    key                  = "azure/terraform.tfstate"
  }
}

