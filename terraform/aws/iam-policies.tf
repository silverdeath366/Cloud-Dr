# IAM Policies for CloudPhoenix

# Policy for EKS nodes to access S3
resource "aws_iam_role_policy" "eks_node_s3_access" {
  name = "${var.project_name}-eks-node-s3-access"
  role = module.eks.node_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${module.s3.bucket_arn}",
          "${module.s3.bucket_arn}/*"
        ]
      }
    ]
  })
}

# Policy for services to access Secrets Manager
resource "aws_iam_role_policy" "eks_service_secrets_access" {
  name = "${var.project_name}-eks-service-secrets-access"
  role = module.eks.cluster_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          module.rds.secret_arn
        ]
      }
    ]
  })
}

# Policy for cross-region access (for failover)
resource "aws_iam_role_policy" "cross_region_access" {
  name = "${var.project_name}-cross-region-access"
  role = module.eks.cluster_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions",
          "ec2:DescribeInstances",
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

