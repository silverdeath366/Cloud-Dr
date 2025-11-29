# AWS Terraform Backend Configuration
# Store state in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "cloudphoenix-terraform-state"
    key            = "aws/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

