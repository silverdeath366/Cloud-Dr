# CloudPhoenix - Complete Testing Checklist

## 🎯 Testing Phases

This checklist ensures everything works before your LinkedIn post. Work through it systematically.

---

## 📋 Phase 1: Infrastructure Testing

### AWS Infrastructure
- [ ] **Terraform Plan** runs without errors
- [ ] **Terraform Apply** completes successfully
- [ ] **VPC** created with correct CIDR
- [ ] **EKS Cluster** is accessible via kubectl
- [ ] **RDS** is accessible and healthy
- [ ] **S3 Bucket** is accessible and can store/retrieve files
- [ ] **ALB** is accessible and shows healthy targets
- [ ] **Route53** hosted zone created (if using domain)
- [ ] **Security Groups** allow necessary traffic
- [ ] **IAM Roles** have correct permissions

### Azure Infrastructure
- [ ] **Terraform Plan** runs without errors
- [ ] **Terraform Apply** completes successfully
- [ ] **VNET** created with correct address space
- [ ] **AKS Cluster** is accessible via kubectl
- [ ] **Azure SQL** is accessible and healthy
- [ ] **Blob Storage** is accessible and can store/retrieve files
- [ ] **Traffic Manager** is configured
- [ ] **Container Registry** can push/pull images
- [ ] **Key Vault** stores secrets correctly
- [ ] **Network Security Groups** allow necessary traffic

### Infrastructure Verification Commands
```bash
# AWS
terraform plan -out=tfplan
terraform apply tfplan
aws eks list-clusters
aws rds describe-db-instances
kubectl get nodes --context aws

# Azure
terraform plan -out=tfplan
terraform apply tfplan
az aks list
az sql server list
kubectl get nodes --context azure
```

---

## 📋 Phase 2: Service Deployment Testing

### Build Images
- [ ] **Frontend Docker image** builds successfully
- [ ] **Service A Docker image** builds successfully
- [ ] **Service B Docker image** builds successfully
- [ ] Images can be pushed to registry (ECR/ACR)
- [ ] Images pull correctly in Kubernetes

### Deploy to AWS (EKS)
- [ ] **Namespace** created: `kubectl create namespace cloudphoenix`
- [ ] **Frontend** deploys: `helm install frontend k8s/helm/frontend`
- [ ] **Service A** deploys: `helm install service-a k8s/helm/service-a`
- [ ] **Service B** deploys: `helm install service-b k8s/helm/service-b`
- [ ] All pods are running: `kubectl get pods -n cloudphoenix`
- [ ] All pods show `READY 1/1`
- [ ] Services are accessible: `kubectl get svc -n cloudphoenix`

### Deploy to Azure (AKS)
- [ ] **Namespace** created: `kubectl create namespace cloudphoenix`
- [ ] **Frontend** deploys: `helm install frontend k8s/helm/frontend`
- [ ] **Service A** deploys: `helm install service-a k8s/helm/service-a`
- [ ] **Service B** deploys: `helm install service-b k8s/helm/service-b`
- [ ] All pods are running: `kubectl get pods -n cloudphoenix`
- [ ] All pods show `READY 1/1`
- [ ] Services are accessible: `kubectl get svc -n cloudphoenix`

### Service Verification
```bash
# Check pod status
kubectl get pods -n cloudphoenix

# Check service endpoints
kubectl get endpoints -n cloudphoenix

# Check logs
kubectl logs -n cloudphoenix -l app.kubernetes.io/name=frontend
kubectl logs -n cloudphoenix -l app.kubernetes.io/name=service-a
```

---

## 📋 Phase 3: Health Check System Testing

### Health Check Script
- [ ] Script runs: `python3 scripts/healthcheck.py`
- [ ] Returns valid JSON
- [ ] Health score calculated correctly
- [ ] All signals collected:
  - [ ] Internal service health
  - [ ] External uptime monitors
  - [ ] Cross-cloud probes
  - [ ] Database replication lag
  - [ ] EKS node states
- [ ] Failover level determined correctly

### Test Scenarios
- [ ] **Healthy system**: Score 0-3 → No action
- [ ] **Minor issues**: Score 4-7 → App self-healing
- [ ] **Moderate issues**: Score 8-10 → Region failover
- [ ] **Critical issues**: Score 11+ → DR failover

### Context Gathering Script
- [ ] Script runs: `python3 scripts/gather_incident_context.py`
- [ ] AWS status checked
- [ ] Cloudflare status checked
- [ ] Prometheus metrics gathered
- [ ] Loki logs gathered
- [ ] Health check results included
- [ ] LLM prompt formatted correctly: `--llm-prompt` flag

---

## 📋 Phase 4: Frontend Testing

### Frontend Accessibility
- [ ] Frontend accessible via ALB DNS
- [ ] Frontend loads without errors
- [ ] UI displays correctly
- [ ] All status cards show data
- [ ] Auto-refresh works (updates every 5 seconds)

### Frontend Functionality
- [ ] **Cloud provider badge** shows correctly (AWS/Azure)
- [ ] **Health score** displays and updates
- [ ] **Database status** shows connected/disconnected
- [ ] **Backend services** status displays
- [ ] **System data** loads from API
- [ ] **DR status indicator** shows correctly
- [ ] **Manual refresh button** works

### API Endpoints (via Frontend)
- [ ] `/api/cloud-status` returns valid JSON
- [ ] `/api/health` returns valid JSON
- [ ] `/api/data` returns valid JSON
- [ ] API errors handled gracefully
- [ ] CORS configured (if needed)

### Test with Different Scenarios
- [ ] **Healthy system**: Shows green indicators
- [ ] **Degraded system**: Shows yellow indicators
- [ ] **Unhealthy system**: Shows red indicators
- [ ] **After DR failover**: Shows Azure badge

---

## 📋 Phase 5: Observability Testing

### Prometheus
- [ ] Prometheus is running
- [ ] Metrics endpoint accessible: `http://prometheus:9090/api/v1/targets`
- [ ] Services are discovered: `http://prometheus:9090/api/v1/targets`
- [ ] Metrics being collected
- [ ] Queries work: `http://prometheus:9090/api/v1/query?query=up`

### Grafana
- [ ] Grafana is accessible
- [ ] Prometheus datasource configured
- [ ] Loki datasource configured
- [ ] Dashboards load correctly
- [ ] Health score displayed on dashboard

### Loki
- [ ] Loki is running
- [ ] Logs being collected: `http://loki:3100/ready`
- [ ] Log queries work: `http://loki:3100/loki/api/v1/query?query={job="service-a"}`
- [ ] Error logs visible in queries

---

## 📋 Phase 6: DR Failover Testing

### Database Replication
- [ ] **RDS backup** created successfully
- [ ] **Data export** completes: `./scripts/replicate_db.sh`
- [ ] **Azure SQL import** completes
- [ ] **Data verification** passes (row counts match)
- [ ] **Replication time** acceptable (<5 minutes)

### Storage Sync
- [ ] **S3 sync** completes: `./scripts/sync_s3.sh`
- [ ] **All files** copied to Azure Blob
- [ ] **File integrity** verified
- [ ] **Sync time** acceptable

### Infrastructure Provisioning
- [ ] **Azure Terraform** applies without errors
- [ ] **AKS cluster** ready
- [ ] **Azure SQL** ready
- [ ] **Blob Storage** ready
- [ ] **Traffic Manager** configured

### Service Deployment on Azure
- [ ] **Services deploy** to AKS without errors
- [ ] **Pods running** on Azure
- [ ] **Services accessible** internally
- [ ] **Health checks pass** on Azure

### DNS Switchover
- [ ] **Route53 record** updates: `./scripts/switch_dns.sh azure`
- [ ] **DNS propagation** occurs (60-300 seconds)
- [ ] **Domain resolves** to Azure Traffic Manager
- [ ] **Frontend accessible** via domain on Azure

### Post-Failover Verification
- [ ] **Frontend shows Azure badge**
- [ ] **Data accessible** from Azure SQL
- [ ] **Services healthy** on Azure
- [ ] **No data loss** verified
- [ ] **Performance acceptable** on Azure

### Rollback Testing
- [ ] **DNS switches back**: `./scripts/switch_dns.sh aws`
- [ ] **Domain resolves** to AWS ALB
- [ ] **Frontend shows AWS badge**
- [ ] **Services working** on AWS

---

## 📋 Phase 7: Jenkins Pipeline Testing

### Pipeline Execution
- [ ] **Health check stage** runs successfully
- [ ] **Health score** calculated correctly
- [ ] **Failover decision** works correctly
- [ ] **DR pipeline** can be triggered manually
- [ ] **All stages** execute without errors

### DR Failover Pipeline
- [ ] **Data replication** stage completes
- [ ] **Azure provisioning** stage completes
- [ ] **Service deployment** stage completes
- [ ] **DNS switchover** stage completes
- [ ] **Verification** stage passes
- [ ] **Webhook notification** sent (if configured)

### Dry Run Testing
- [ ] **DRY_RUN=true** mode works
- [ ] **No actual changes** made in dry run
- [ ] **Logs show** what would happen
- [ ] **Can verify** actions before execution

---

## 📋 Phase 8: Chaos Testing

### Test Scenarios
- [ ] **Pod crash simulation**: `./cicd/simulate_failure.sh pod-crash`
  - Pods restart automatically
  - Health score increases temporarily
  - System recovers

- [ ] **Database slowdown**: `./cicd/simulate_failure.sh db-slowdown`
  - Database lag detected
  - Health score increases
  - Alert triggered

- [ ] **AZ failure simulation**: `./cicd/simulate_failure.sh az-failure`
  - Services in AZ become unavailable
  - Health score increases significantly
  - Region failover triggered (if configured)

- [ ] **Region isolation**: `./cicd/simulate_failure.sh region-isolation`
  - AWS region appears unavailable
  - Health score > 11
  - DR failover should trigger

### Recovery Verification
- [ ] **System recovers** from simulated failures
- [ ] **Health score** returns to normal
- [ ] **Services** become healthy again
- [ ] **No data loss** occurred
- [ ] **Monitoring** shows recovery in logs

---

## 📋 Phase 9: Security Testing

### Access Control
- [ ] **IAM roles** follow least privilege
- [ ] **RBAC** configured correctly
- [ ] **Security groups** allow only necessary ports
- [ ] **Secrets** stored in Secrets Manager/Key Vault
- [ ] **No hardcoded credentials** in code

### Network Security
- [ ] **Private subnets** used for databases
- [ ] **Public subnets** only for load balancers
- [ ] **VPC peering/connectivity** works (if needed)
- [ ] **Encryption** enabled (at rest and in transit)

### Secret Management
- [ ] **Database passwords** in Secrets Manager/Key Vault
- [ ] **API keys** not in code
- [ ] **Secrets rotation** script works: `./scripts/rotate_secrets.sh`

---

## 📋 Phase 10: Performance Testing

### Load Testing
- [ ] **Frontend handles** concurrent requests
- [ ] **Backend APIs** handle load
- [ ] **Database connections** pooled correctly
- [ ] **Response times** acceptable (<500ms for APIs)
- [ ] **No memory leaks** observed

### Failover Performance
- [ ] **RTO** achieved (<15 minutes)
- [ ] **RPO** achieved (<5 minutes)
- [ ] **DNS propagation** acceptable (<5 minutes)
- [ ] **Service startup** time acceptable

### Resource Usage
- [ ] **CPU usage** within limits
- [ ] **Memory usage** within limits
- [ ] **Database** not overwhelmed
- [ ] **Storage** usage acceptable

---

## 📋 Phase 11: End-to-End Integration Testing

### Complete DR Scenario
1. [ ] **System healthy** on AWS
2. [ ] **Frontend accessible** via domain
3. [ ] **Data exists** in database
4. [ ] **Simulate failure** (or trigger DR manually)
5. [ ] **Health score** > 11 detected
6. [ ] **Context gathered** successfully
7. [ ] **LLM analysis** (if n8n ready) or manual decision
8. [ ] **DR triggered** via Jenkins
9. [ ] **Database replicated** to Azure
10. [ ] **Storage synced** to Azure
11. [ ] **Azure infrastructure** provisioned
12. [ ] **Services deployed** to Azure
13. [ ] **DNS switched** to Azure
14. [ ] **Frontend accessible** on Azure
15. [ ] **Frontend shows Azure badge**
16. [ ] **Data accessible** on Azure
17. [ ] **Services healthy** on Azure
18. [ ] **No data loss** verified

### User Experience Test
- [ ] **User visits domain** before failover → Sees AWS
- [ ] **User visits domain** after failover → Sees Azure
- [ ] **Same URL** works in both cases
- [ ] **Same data** accessible
- [ ] **No downtime** visible to user (or minimal)

---

## 📋 Phase 12: Documentation Verification

### Documentation Completeness
- [ ] **README.md** clear and complete
- [ ] **Architecture diagram** accurate
- [ ] **Setup instructions** work
- [ ] **Troubleshooting** section helpful
- [ ] **API documentation** clear

### Code Comments
- [ ] **Key functions** documented
- [ ] **Complex logic** explained
- [ ] **Configuration** documented
- [ ] **Environment variables** documented

---

## 📋 Phase 13: n8n Workflow Testing (When Built)

### Workflow Execution
- [ ] **Webhook trigger** receives alerts
- [ ] **Context gathering** node works
- [ ] **Cloudflare status** check works
- [ ] **AWS status** check works
- [ ] **Prometheus queries** work
- [ ] **Loki queries** work
- [ ] **Data aggregation** works
- [ ] **LLM prompt** constructed correctly
- [ ] **LLM API call** succeeds
- [ ] **Response parsed** correctly
- [ ] **Decision logic** works
- [ ] **Jenkins trigger** works (if YES branch)
- [ ] **Logging** works (if NO branch)

### LLM Decision Testing
- [ ] **AWS issue scenario**: LLM recommends trigger_dr
- [ ] **Cloudflare issue scenario**: LLM recommends trigger_dr
- [ ] **Internal bug scenario**: LLM recommends investigate
- [ ] **Ambiguous scenario**: LLM recommends monitor
- [ ] **Confidence levels** appropriate
- [ ] **False positives** prevented

---

## 📋 Phase 14: Final Verification

### Before LinkedIn Post
- [ ] **All infrastructure** deployed and working
- [ ] **All services** running on both clouds
- [ ] **Frontend** accessible and functional
- [ ] **Health checks** working correctly
- [ ] **DR failover** tested end-to-end
- [ ] **Rollback** tested and works
- [ ] **Chaos tests** pass
- [ ] **Performance** acceptable
- [ ] **Security** verified
- [ ] **Documentation** complete
- [ ] **n8n workflow** built and tested (if doing before post)
- [ ] **Screenshots/videos** taken for LinkedIn

### Demo Preparation
- [ ] **Demo script** prepared
- [ ] **Screenshots** captured:
  - [ ] Architecture diagram
  - [ ] Frontend dashboard (AWS)
  - [ ] Frontend dashboard (Azure)
  - [ ] Health score visualization
  - [ ] DR failover in progress
- [ ] **Video demo** recorded (optional)
- [ ] **GitHub repository** ready (if making public)

---

## 🎯 Testing Priority Order

1. **Infrastructure** (Phase 1) - Foundation
2. **Services** (Phase 2) - Core functionality
3. **Health Checks** (Phase 3) - Monitoring
4. **Frontend** (Phase 4) - User-facing
5. **Observability** (Phase 5) - Monitoring
6. **DR Failover** (Phase 6) - Main feature
7. **Jenkins** (Phase 7) - Automation
8. **Chaos** (Phase 8) - Resilience
9. **Security** (Phase 9) - Safety
10. **Performance** (Phase 10) - Efficiency
11. **Integration** (Phase 11) - End-to-end
12. **Documentation** (Phase 12) - Clarity
13. **n8n Workflow** (Phase 13) - AI integration
14. **Final Verification** (Phase 14) - Ready to post

---

## 🚨 Critical Path Items (Must Work)

These MUST work before posting:
1. ✅ Infrastructure deploys successfully
2. ✅ Services run on both clouds
3. ✅ Frontend accessible and shows correct cloud
4. ✅ DR failover works (AWS → Azure)
5. ✅ DNS switchover works
6. ✅ Data accessible after failover
7. ✅ Health checks work correctly

---

## ✅ Ready for LinkedIn When

- [ ] All Phase 1-6 tests pass (Infrastructure + DR)
- [ ] Frontend demo works (users can see it)
- [ ] At least one successful DR failover completed
- [ ] Screenshots/videos captured
- [ ] Documentation complete

**n8n workflow** can be added later as an update post!

---

**Work through this checklist systematically, and you'll have a fully tested, production-ready project!** 🚀

