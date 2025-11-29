# Variable validation rules

variable "aws_region" {
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid region identifier."
  }
}

variable "vpc_cidr" {
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "eks_cluster_version" {
  validation {
    condition     = can(regex("^1\\.(2[0-8]|1[0-9])$", var.eks_cluster_version))
    error_message = "EKS cluster version must be between 1.10 and 1.28."
  }
}

variable "rds_allocated_storage" {
  validation {
    condition     = var.rds_allocated_storage >= 20 && var.rds_allocated_storage <= 16384
    error_message = "RDS allocated storage must be between 20 and 16384 GB."
  }
}

variable "environment" {
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

