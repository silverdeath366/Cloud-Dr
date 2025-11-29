variable "aws_region" {
  description = "AWS region for primary infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "aws_secondary_region" {
  description = "AWS secondary region for cross-region failover"
  type        = string
  default     = "us-west-2"
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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.28"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "rds_multi_az" {
  description = "Enable RDS Multi-AZ"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for Route53 hosted zone (e.g., demo.cloudphoenix.io). Leave empty to skip Route53 setup."
  type        = string
  default     = ""
}

variable "azure_traffic_manager_domain" {
  description = "Azure Traffic Manager domain for DR (e.g., cloudphoenix.trafficmanager.net)"
  type        = string
  default     = ""
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

