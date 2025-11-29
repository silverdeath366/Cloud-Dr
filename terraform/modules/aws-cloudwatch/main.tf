# CloudWatch Alarms Module

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  count = var.enable_alarms ? 1 : 0
  name  = "${var.project_name}-alarms"

  tags = var.tags
}

# EKS Cluster Health Alarm
resource "aws_cloudwatch_metric_alarm" "eks_cluster_unhealthy" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-eks-cluster-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ClusterFailedNodeCount"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "EKS cluster has unhealthy nodes"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]

  dimensions = {
    ClusterName = var.eks_cluster_name
  }

  tags = var.tags
}

# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is high"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}

# RDS Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS database connections are high"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}

# ALB Target Health Alarm
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ALB has unhealthy targets"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]

  dimensions = {
    LoadBalancer = var.alb_arn
  }

  tags = var.tags
}

