variable "azure_location" {
  description = "Azure region for DR infrastructure"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "cloudphoenix"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  default     = "cloudphoenix-dr-rg"
}

variable "vnet_address_space" {
  description = "Address space for VNET"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "aks_node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 2
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28"
}

variable "sql_server_version" {
  description = "Azure SQL Server version"
  type        = string
  default     = "12.0"
}

variable "sql_database_sku" {
  description = "Azure SQL Database SKU"
  type        = string
  default     = "S2"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "CloudPhoenix"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

