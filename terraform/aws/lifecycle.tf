# Lifecycle and backup configurations

# Enable deletion protection for critical resources
resource "aws_db_instance" "main" {
  # This would be in the RDS module, but showing lifecycle rules here
  deletion_protection = var.environment == "production" ? true : false
  skip_final_snapshot = var.environment == "production" ? false : true
  
  lifecycle {
    prevent_destroy = var.environment == "production"
    create_before_destroy = true
  }
}

# S3 lifecycle policies (in S3 module)
# Backup retention policies
# Automated snapshot management

