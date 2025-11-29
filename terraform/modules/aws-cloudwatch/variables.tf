variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "enable_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance ID"
  type        = string
}

variable "alb_arn" {
  description = "ALB ARN"
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

