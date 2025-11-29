# CloudPhoenix Quick Start Guide

## Prerequisites

Before starting, ensure you have:

- [ ] Terraform >= 1.5 installed
- [ ] AWS CLI configured with appropriate credentials
- [ ] Azure CLI configured with appropriate credentials
- [ ] kubectl installed
- [ ] Helm 3.x installed
- [ ] Jenkins installed and configured
- [ ] Docker installed
- [ ] Python 3.11+ installed

## Initial Setup

### 1. Clone and Configure

```bash
cd cloudphoenix
```

### 2. Configure Terraform Variables

Create `terraform/aws/terraform.tfvars`:
```hcl
aws_region = "us-east-1"
project_name = "cloudphoenix"
environment = "production"
```

Create `terraform/azure/terraform.tfvars`:
```hcl
azure_location = "eastus"
project_name = "cloudphoenix"
resource_group_name = "cloudphoenix-dr-rg"
```

### 3. Configure Terraform Backends

**AWS Backend:**
- Create S3 bucket for state: `cloudphoenix-terraform-state`
- Create DynamoDB table: `terraform-state-lock`

**Azure Backend:**
- Create storage account: `cloudphoenixtfstate`
- Create container: `terraform-state`

### 4. Deploy AWS Infrastructure

```bash
cd terraform/aws
terraform init
terraform plan
terraform apply
```

**Note**: Save the outputs for later use:
- EKS cluster name
- RDS endpoint
- S3 bucket name
- ALB DNS name

### 5. Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name cloudphoenix-eks
```

### 6. Deploy Kubernetes Resources

```bash
# Create namespace
kubectl apply -f k8s/manifests/namespace.yaml

# Create RBAC
kubectl apply -f k8s/manifests/rbac.yaml

# Create ConfigMap
kubectl apply -f k8s/manifests/configmap.yaml
```

### 7. Deploy Services

```bash
# Update values.yaml with your configuration
# Then deploy:
helm install service-a k8s/helm/service-a
helm install service-b k8s/helm/service-b
```

### 8. Deploy Observability Stack

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus
kubectl apply -f observability/prometheus/

# Deploy Grafana
kubectl apply -f observability/grafana/

# Deploy Loki
kubectl apply -f observability/loki/
```

### 9. Configure Jenkins Pipeline

1. Create new pipeline job in Jenkins
2. Point to `cicd/Jenkinsfile`
3. Configure credentials:
   - `aws-kubeconfig`
   - `azure-kubeconfig`
   - `n8n-webhook-url`

### 10. Set Up Health Checks

Create `/etc/cloudphoenix/health_config.json`:
```json
{
  "internal_services": [
    {"name": "service-a", "url": "http://service-a:8080"},
    {"name": "service-b", "url": "http://service-b:8080"}
  ],
  "external_monitors": [
    {"name": "uptime", "url": "https://httpbin.org/status/200"}
  ],
  "rds": {
    "host": "YOUR_RDS_ENDPOINT",
    "port": "5432",
    "database": "cloudphoenix",
    "user": "admin",
    "password": "FROM_SECRETS_MANAGER"
  },
  "eks": {
    "cluster_name": "cloudphoenix-eks",
    "region": "us-east-1"
  }
}
```

### 11. Make Scripts Executable

```bash
chmod +x scripts/*.sh
chmod +x cicd/*.sh
```

## Testing

### Test Health Checks

```bash
python3 scripts/healthcheck.py
```

### Test Chaos Scenarios

```bash
# Pod crash simulation
./cicd/simulate_failure.sh pod-crash

# AZ failure simulation
./cicd/simulate_failure.sh az-failure
```

### Test DR Failover (Dry Run)

1. Go to Jenkins → CloudPhoenix Pipeline
2. Build with Parameters:
   - ACTION: `dr_failover`
   - DRY_RUN: `true`

## Next Steps

1. **Configure n8n workflows** (manual setup)
2. **Set up monitoring dashboards** in Grafana
3. **Configure alerting** in Prometheus
4. **Schedule DR drills** (see `docs/test-drills.md`)
5. **Review security settings** (see `SECURITY.md`)

## Troubleshooting

### Common Issues

**Terraform errors:**
- Verify credentials are configured
- Check backend configuration
- Ensure required APIs are enabled

**Kubernetes deployment failures:**
- Check pod logs: `kubectl logs -n cloudphoenix <pod-name>`
- Verify image pull secrets
- Check resource limits

**Health check failures:**
- Verify service endpoints are accessible
- Check network policies
- Review health check configuration

## Support

For issues or questions:
- Review documentation in `docs/`
- Check runbooks in `docs/dr-runbook.md`
- Review architecture in `docs/architecture.md`

