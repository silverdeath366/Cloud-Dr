# Route53 Hosted Zone and DNS Records for CloudPhoenix

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-route53-zone"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Primary DNS Record pointing to AWS ALB
resource "aws_route53_record" "app_primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  set_identifier = "aws-primary"
  
  # Use weighted routing for failover
  weighted_routing_policy {
    weight = var.primary_weight
  }

  tags = {
    Name        = "${var.project_name}-app-primary"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Secondary DNS Record for Azure Traffic Manager (configured manually during DR)
resource "aws_route53_record" "app_secondary" {
  count   = var.enable_dr_record ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 60

  records = [var.azure_traffic_manager_domain]

  set_identifier = "azure-dr"
  
  weighted_routing_policy {
    weight = 0  # Initially disabled, will be enabled during DR
  }

  tags = {
    Name        = "${var.project_name}-app-dr"
    Environment = var.environment
    Project     = var.project_name
    DR          = "true"
  }
}

# Health check for ALB
resource "aws_route53_health_check" "alb" {
  fqdn              = var.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name        = "${var.project_name}-alb-health-check"
    Environment = var.environment
    Project     = var.project_name
  }
}

