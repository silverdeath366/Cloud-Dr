# CloudPhoenix Architecture

## Overview

CloudPhoenix is a self-healing multi-cloud resilience platform designed to provide automated disaster recovery and failover capabilities across AWS and Azure cloud environments.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudPhoenix Platform                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │   AWS (Primary)  │         │  Azure (DR)      │         │
│  ├──────────────────┤         ├──────────────────┤         │
│  │ • EKS Cluster    │         │ • AKS Cluster    │         │
│  │ • RDS (Multi-AZ) │         │ • Azure SQL      │         │
│  │ • S3 Storage     │         │ • Blob Storage   │         │
│  │ • ALB           │         │ • Traffic Manager│         │
│  └──────────────────┘         └──────────────────┘         │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Observability Stack                           │  │
│  │  • Prometheus  • Grafana  • Loki                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Automation Layer                               │  │
│  │  • Jenkins Pipelines  • Terraform  • Helm Charts      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Health & Failover Logic                       │  │
│  │  • Multi-Signal Scoring  • Automated Failover        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. AWS Infrastructure (Primary)

#### VPC
- Multi-AZ deployment across 3 availability zones
- Public and private subnets
- NAT Gateways for outbound connectivity
- Internet Gateway for public access

#### EKS Cluster
- Kubernetes 1.28+
- Managed node groups with auto-scaling
- Private endpoint with public access
- CloudWatch logging enabled

#### RDS
- PostgreSQL 15.4
- Multi-AZ deployment
- Automated backups (7-day retention)
- Performance Insights enabled
- Encrypted at rest

#### S3
- Versioning enabled
- Lifecycle policies (IA → Glacier)
- Server-side encryption
- Private access only

#### Application Load Balancer
- Internet-facing
- Health checks on /health endpoint
- Target groups for services

### 2. Azure Infrastructure (DR)

#### VNET
- Address space: 10.1.0.0/16
- Subnets for AKS, private, and public resources
- Network Security Groups

#### AKS Cluster
- Kubernetes 1.28+
- System-assigned managed identity
- Azure CNI networking
- Standard load balancer

#### Azure SQL
- SQL Server 12.0
- Basic tier (configurable)
- VNET integration
- Key Vault for secrets

#### Blob Storage
- LRS replication
- Versioning enabled
- HTTPS only
- Private access

#### Traffic Manager
- Priority-based routing
- Health monitoring
- HTTPS probes

### 3. Application Services

#### Service A
- Flask-based Python application
- Health endpoints: /health, /ready, /live
- Database connectivity
- S3 integration

#### Service B
- Flask-based Python application
- Health endpoints: /health, /ready, /live
- Data processing capabilities

### 4. Observability Stack

#### Prometheus
- Metrics collection
- Service discovery for Kubernetes
- Alert rules for health scoring
- 30-day retention

#### Grafana
- Dashboards for visualization
- Prometheus and Loki datasources
- Alert notifications

#### Loki
- Log aggregation
- Promtail for log collection
- 30-day retention

### 5. Automation & Orchestration

#### Jenkins Pipeline
- Scripted pipeline for DR orchestration
- Multi-stage failover process
- Integration with n8n webhooks

#### Terraform
- Modular infrastructure code
- Separate modules for AWS and Azure
- State management via backends

#### Helm Charts
- Service deployment templates
- Configurable values
- Health probes and resource limits

### 6. Health & Failover System

#### Multi-Signal Health Scoring
- Internal service health checks
- External uptime monitors
- Cross-cloud probes
- Database replication lag
- EKS node states
- Composite scoring (0-15+)

#### Failover Levels
1. **Level 0 (Score 0-3)**: No action
2. **Level 1 (Score 4-7)**: Application self-healing
3. **Level 2 (Score 8-10)**: Region-level failover
4. **Level 3 (Score 11+)**: DR failover to Azure

## Data Flow

### Normal Operation
1. Traffic → AWS ALB → EKS Services → RDS/S3
2. Health checks run every 30 seconds
3. Metrics collected by Prometheus
4. Logs aggregated by Loki

### Failover Process
1. Health scoring detects degradation
2. Score exceeds threshold (11+)
3. Jenkins pipeline triggered
4. Data replication (RDS → Azure SQL, S3 → Blob)
5. Azure infrastructure provisioned (if needed)
6. Services deployed to AKS
7. DNS switched to Azure Traffic Manager
8. Services verified
9. n8n webhook notified

## Security

- Secrets managed via AWS Secrets Manager / Azure Key Vault
- RBAC for Kubernetes
- IAM roles with least privilege
- Encrypted data at rest and in transit
- Network security groups/firewalls
- Private endpoints where possible

## Disaster Recovery RTO/RPO

- **RTO (Recovery Time Objective)**: < 15 minutes
- **RPO (Recovery Point Objective)**: < 5 minutes (via continuous replication)

## Monitoring & Alerting

- Prometheus alerts for critical conditions
- Health score monitoring
- Service availability tracking
- Resource utilization alerts
- Automated failover triggers

