output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.rds.instance_id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3.bucket_name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

# Route53 Outputs
output "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.domain_name != "" ? module.route53[0].hosted_zone_id : null
}

output "route53_name_servers" {
  description = "Route53 name servers (configure these in your domain registrar)"
  value       = var.domain_name != "" ? module.route53[0].name_servers : null
}

output "route53_domain_name" {
  description = "Route53 domain name"
  value       = var.domain_name != "" ? module.route53[0].domain_name : null
}

# ALB Outputs
output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

