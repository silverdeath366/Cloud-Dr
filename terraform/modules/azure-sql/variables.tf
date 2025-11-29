variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "vnet_subnet_id" {
  description = "VNET subnet ID"
  type        = string
}

variable "server_version" {
  description = "SQL Server version"
  type        = string
}

variable "database_sku" {
  description = "Database SKU"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

