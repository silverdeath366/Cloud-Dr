terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "../modules/aws-vpc"

  project_name      = var.project_name
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  environment       = var.environment
  tags              = var.tags
}

# EKS Module
module "eks" {
  source = "../modules/aws-eks"

  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  public_subnet_ids      = module.vpc.public_subnet_ids
  cluster_version        = var.eks_cluster_version
  node_instance_types    = var.eks_node_instance_types
  environment            = var.environment
  tags                   = var.tags
}

# RDS Module
module "rds" {
  source = "../modules/aws-rds"

  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids   = [module.eks.cluster_security_group_id]
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  multi_az             = var.rds_multi_az
  environment          = var.environment
  tags                 = var.tags
}

# S3 Module
module "s3" {
  source = "../modules/aws-s3"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

# ALB Module
module "alb" {
  source = "../modules/aws-alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_ids = [module.eks.cluster_security_group_id]
  environment       = var.environment
  tags              = var.tags
}

# CloudWatch Alarms
module "cloudwatch" {
  source = "../modules/aws-cloudwatch"

  project_name           = var.project_name
  enable_alarms          = var.enable_cloudwatch_alarms
  eks_cluster_name       = module.eks.cluster_name
  rds_instance_id        = module.rds.instance_id
  alb_arn                = module.alb.alb_arn
  environment            = var.environment
  tags                   = var.tags
}

# Route53 Module (optional - only if domain_name is provided)
module "route53" {
  count = var.domain_name != "" ? 1 : 0
  source = "../modules/aws-route53"

  domain_name                 = var.domain_name
  project_name                = var.project_name
  environment                 = var.environment
  alb_dns_name                = module.alb.alb_dns_name
  alb_zone_id                 = module.alb.alb_zone_id
  azure_traffic_manager_domain = var.azure_traffic_manager_domain
  enable_dr_record            = true
  primary_weight              = 100
}

