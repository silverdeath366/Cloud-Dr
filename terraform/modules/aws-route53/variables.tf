variable "domain_name" {
  description = "Domain name for Route53 hosted zone"
  type        = string
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  type        = string
}

variable "azure_traffic_manager_domain" {
  description = "Azure Traffic Manager domain (for DR)"
  type        = string
  default     = ""
}

variable "enable_dr_record" {
  description = "Enable DR record for Azure Traffic Manager"
  type        = bool
  default     = true
}

variable "primary_weight" {
  description = "Weight for primary AWS route"
  type        = number
  default     = 100
}

