output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = var.enable_alarms ? aws_sns_topic.alarms[0].arn : null
}

