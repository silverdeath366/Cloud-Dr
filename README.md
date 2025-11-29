# CloudPhoenix — Self-Healing Multi-Cloud Resilience Platform

A production-grade, cross-cloud disaster recovery and self-healing automation system.

## Overview

CloudPhoenix provides automated multi-cloud resilience where workloads run primarily on AWS, automatically failover to Azure when a region experiences severe degradation. The system supports:

- **Self-healing** at multiple levels
- **Multi-stage failover** (app → region → cross-region → DR)
- **Infrastructure-as-Code** for AWS and Azure
- **Scripted CI/CD** via Jenkins
- **Independent health signal scoring**
- **Observability-driven decisions** (Prometheus + Grafana + Loki)
- **Chaos testing** capabilities

## Architecture

```
AWS (Primary)                    Azure (DR)
├── VPC + EKS                   ├── VNET + AKS
├── RDS (Multi-AZ)              ├── Azure SQL
├── S3                          ├── Blob Storage
├── ALB                         ├── Traffic Manager
└── CloudWatch                  └── Azure Monitor

Observability Stack
├── Prometheus
├── Grafana
└── Loki

Automation
├── Jenkins Scripted Pipelines
├── Terraform (AWS + Azure)
├── Helm Charts
└── Failover Scripts
```

## Quick Start

### Prerequisites

- Terraform >= 1.5
- AWS CLI configured
- Azure CLI configured
- kubectl
- Jenkins
- Docker

### Deployment

1. **Configure Terraform backends:**
   ```bash
   cd terraform/backends
   # Configure S3 backend for AWS
   # Configure Azure Storage backend for Azure
   ```

2. **Deploy AWS infrastructure:**
   ```bash
   cd terraform/aws
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Azure infrastructure:**
   ```bash
   cd terraform/azure
   terraform init
   terraform plan
   terraform apply
   ```

4. **Deploy services:**
   ```bash
   # Configure kubeconfig for EKS
   helm install service-a k8s/helm/service-a
   helm install service-b k8s/helm/service-b
   ```

5. **Deploy observability:**
   ```bash
   kubectl apply -f observability/prometheus/
   kubectl apply -f observability/grafana/
   kubectl apply -f observability/loki/
   ```

## Failover Process

The system uses a multi-signal health scoring system:

- **Score 0-3**: No action
- **Score 4-7**: Application self-healing
- **Score 8-10**: Region-level failover
- **Score 11+**: DR failover to Azure

### Manual DR Trigger

```bash
# Via Jenkins
# Navigate to Jenkins → CloudPhoenix → Build with Parameters → Trigger DR

# Via CLI
./scripts/trigger_dr.sh
```

## Testing

### Chaos Testing

```bash
./cicd/simulate_failure.sh --type pod-crash
./cicd/simulate_failure.sh --type db-slowdown
./cicd/simulate_failure.sh --type az-failure
./cicd/simulate_failure.sh --type region-isolation
```

## Documentation

- [Architecture](./docs/architecture.md)
- [DR Runbook](./docs/dr-runbook.md)
- [Test Drills](./docs/test-drills.md)
- [Postmortem Template](./docs/postmortem-template.md)

## Project Structure

```
cloudphoenix/
├── terraform/          # Infrastructure as Code
├── cicd/              # Jenkins pipelines and scripts
├── services/          # Application services
├── k8s/               # Kubernetes manifests and Helm charts
├── scripts/           # Automation scripts
├── observability/     # Monitoring and logging
├── docs/              # Documentation
└── n8n-workflows/     # Manual n8n workflows (not auto-generated)
```

## Security

- Secrets managed via AWS Secrets Manager and Azure Key Vault
- RBAC configured for Kubernetes
- IAM roles with least privilege
- Encrypted data at rest and in transit

## License

Proprietary - Internal Use Only

