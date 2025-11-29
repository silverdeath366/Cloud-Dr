# CloudPhoenix - Complete Testing Guide

## 🎯 Goal

This guide helps you systematically test every component of CloudPhoenix to ensure it's production-ready and LinkedIn-worthy.

---

## 📊 Testing Strategy

### Quick Tests (1-2 hours)
Focus on core functionality to verify basic operation

### Comprehensive Tests (1-2 days)
Full end-to-end testing of all components

### Production Readiness Tests (2-3 days)
Performance, security, chaos testing, and edge cases

---

## 🚀 Quick Start Testing (Minimum Viable)

### Step 1: Infrastructure Smoke Tests (30 min)

```bash
# AWS Infrastructure
cd terraform/aws
terraform init
terraform plan  # Should show no errors
# Note: Don't apply yet if you want to test first

# Azure Infrastructure
cd terraform/azure
terraform init
terraform plan  # Should show no errors
```

**Success Criteria**: Plans complete without errors

---

### Step 2: Build and Test Services Locally (30 min)

```bash
# Build frontend
cd services/frontend
docker build -t cloudphoenix/frontend:test .
docker run -p 8080:80 cloudphoenix/frontend:test
# Visit http://localhost:8080 - should show dashboard

# Build backend
cd ../service-a
docker build -t cloudphoenix/service-a:test .
# Test health endpoint (if you have DB connection)
```

**Success Criteria**: Images build, containers run, services respond

---

### Step 3: Health Check Script Test (15 min)

```bash
# Run health check
python3 scripts/healthcheck.py

# Should output JSON with:
# - score
# - signals
# - failover_level
```

**Success Criteria**: Script runs, returns valid JSON

---

### Step 4: Context Gathering Script Test (15 min)

```bash
# Run context gathering
python3 scripts/gather_incident_context.py

# Should output JSON with:
# - aws_status
# - cloudflare_status
# - health_check_results
# - internal_metrics
# - recent_logs

# Test LLM prompt format
python3 scripts/gather_incident_context.py --llm-prompt

# Should output formatted prompt
```

**Success Criteria**: Script runs, gathers data, formats prompt correctly

---

## 🔬 Comprehensive Testing

### Test 1: Infrastructure Deployment

**Objective**: Verify all infrastructure deploys correctly

```bash
# Deploy AWS
cd terraform/aws
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Verify outputs
terraform output

# Deploy Azure
cd ../azure
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Verify outputs
terraform output
```

**Verify**:
- [ ] All resources created
- [ ] EKS cluster accessible
- [ ] AKS cluster accessible
- [ ] RDS endpoint available
- [ ] Azure SQL endpoint available
- [ ] ALB DNS name available

---

### Test 2: Service Deployment

**Objective**: Deploy all services to Kubernetes

```bash
# Configure kubectl for AWS
aws eks update-kubeconfig --region us-east-1 --name cloudphoenix-eks

# Create namespace
kubectl create namespace cloudphoenix

# Deploy services
helm install frontend k8s/helm/frontend --namespace cloudphoenix
helm install service-a k8s/helm/service-a --namespace cloudphoenix
helm install service-b k8s/helm/service-b --namespace cloudphoenix

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=frontend -n cloudphoenix --timeout=300s

# Check status
kubectl get pods -n cloudphoenix
kubectl get svc -n cloudphoenix
```

**Verify**:
- [ ] All pods running
- [ ] Services have endpoints
- [ ] No crash loops

**Test Access**:
```bash
# Port forward to test
kubectl port-forward -n cloudphoenix svc/frontend 8080:80

# Visit http://localhost:8080
# Should see frontend dashboard
```

---

### Test 3: ALB Integration

**Objective**: Verify frontend accessible via ALB

```bash
# Get ALB DNS name
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `cloudphoenix`)].DNSName' --output text

# Register pods with target group
# (Manual or via AWS Load Balancer Controller)

# Test access
curl http://YOUR_ALB_DNS
```

**Verify**:
- [ ] Frontend accessible via ALB
- [ ] API endpoints work: `/api/cloud-status`, `/api/health`
- [ ] Health checks passing

---

### Test 4: Route53 DNS (If Using Domain)

**Objective**: Verify domain resolves correctly

```bash
# Get Route53 hosted zone
aws route53 list-hosted-zones --query 'HostedZones[?Name==`demo.cloudphoenix.io.`]'

# Check DNS resolution
dig demo.cloudphoenix.io
nslookup demo.cloudphoenix.io

# Test access
curl http://demo.cloudphoenix.io
```

**Verify**:
- [ ] Domain resolves to ALB
- [ ] Frontend accessible via domain
- [ ] SSL certificate valid (if using HTTPS)

---

### Test 5: Database Connectivity

**Objective**: Verify database connections work

```bash
# Test RDS connection
psql -h YOUR_RDS_ENDPOINT -U admin -d cloudphoenix -c "SELECT 1;"

# Test Azure SQL connection
sqlcmd -S YOUR_AZURE_SQL_SERVER -U admin -d cloudphoenix -Q "SELECT 1;"

# Test from pods
kubectl exec -n cloudphoenix deployment/service-a -- python3 -c "
import psycopg2
conn = psycopg2.connect(host='RDS_ENDPOINT', user='admin', password='PASS', database='cloudphoenix')
cursor = conn.cursor()
cursor.execute('SELECT 1')
print('Connected!')
"
```

**Verify**:
- [ ] Database accessible
- [ ] Services can connect
- [ ] Data can be read/written

---

### Test 6: Health Scoring System

**Objective**: Verify health scoring works correctly

```bash
# Test with healthy system
python3 scripts/healthcheck.py
# Expected: score 0-3, failover_level: no_action

# Test with simulated failure
# (Stop a service or introduce delay)
python3 scripts/healthcheck.py
# Expected: score increases, appropriate failover_level
```

**Test Different Scenarios**:

1. **All Healthy**: Score should be 0-3
2. **One Service Down**: Score should increase
3. **Database Slow**: Score should increase
4. **Multiple Issues**: Score should be 11+

---

### Test 7: DR Failover (Dry Run)

**Objective**: Test DR failover without actual execution

```bash
# Test via Jenkins (dry run)
# Jenkins → Build with Parameters:
#   ACTION: dr_failover
#   DRY_RUN: true

# Or manually test scripts
export DRY_RUN=true
./scripts/replicate_db.sh
./scripts/sync_s3.sh
```

**Verify**:
- [ ] Scripts show what they would do
- [ ] No actual changes made
- [ ] Logs show correct actions

---

### Test 8: DR Failover (Actual)

**Objective**: Execute complete DR failover

**Prerequisites**:
- AWS infrastructure running
- Azure infrastructure ready
- Services deployed on both
- Test data in database

**Steps**:
```bash
# 1. Verify AWS is primary
curl http://demo.cloudphoenix.io/api/cloud-status
# Should show: {"provider": "aws", ...}

# 2. Trigger DR
./scripts/trigger_dr.sh
# Or via Jenkins

# 3. Monitor progress
# Watch Jenkins logs or script output

# 4. Wait for completion (should be <15 minutes)

# 5. Verify DNS switched
dig demo.cloudphoenix.io
# Should resolve to Azure Traffic Manager

# 6. Verify Azure is now primary
curl http://demo.cloudphoenix.io/api/cloud-status
# Should show: {"provider": "azure", ...}

# 7. Verify data accessible
curl http://demo.cloudphoenix.io/api/data
# Should show same data from Azure SQL
```

**Verify**:
- [ ] Database replicated
- [ ] Storage synced
- [ ] Services running on Azure
- [ ] DNS switched
- [ ] Frontend shows Azure badge
- [ ] Data accessible
- [ ] No data loss

---

### Test 9: Rollback

**Objective**: Test switching back to AWS

```bash
# Switch DNS back to AWS
./scripts/switch_dns.sh aws

# Wait for propagation
sleep 120

# Verify AWS is primary again
curl http://demo.cloudphoenix.io/api/cloud-status
# Should show: {"provider": "aws", ...}
```

**Verify**:
- [ ] DNS switches back
- [ ] Frontend shows AWS badge
- [ ] Services working on AWS

---

### Test 10: Chaos Testing

**Objective**: Verify system handles failures gracefully

```bash
# Pod crash simulation
./cicd/simulate_failure.sh pod-crash

# Verify:
# - Pods restart automatically
# - Health score recovers
# - No data loss

# Database slowdown
./cicd/simulate_failure.sh db-slowdown

# Verify:
# - Health score increases
# - Alerts triggered
# - System detects issue

# Region isolation (full DR test)
./cicd/simulate_failure.sh region-isolation

# Verify:
# - Health score > 11
# - DR triggered (if LLM confirms)
# - Failover completes
```

---

## 🎬 Demo Testing (For LinkedIn)

### Prepare Demo Scenario

1. **Set up test data**:
   ```bash
   # Insert test data into database
   psql -h RDS_ENDPOINT -U admin -d cloudphoenix -c "
   INSERT INTO app_data (data) VALUES 
   ('Test Item 1'),
   ('Test Item 2'),
   ('Test Item 3');
   "
   ```

2. **Verify frontend shows data**:
   - Visit: `http://demo.cloudphoenix.io`
   - Should see test items in "System Data" section

3. **Record before state**:
   - Screenshot: Frontend showing AWS badge
   - Screenshot: Health score low (0-3)
   - Screenshot: Data visible

4. **Trigger DR**:
   - Simulate failure or trigger manually
   - Watch failover process

5. **Record during failover**:
   - Screenshot: Health score increasing
   - Screenshot: DR status "Active"
   - Video: DNS switching

6. **Record after state**:
   - Screenshot: Frontend showing Azure badge
   - Screenshot: Same data visible
   - Screenshot: Health score normal again

---

## 🐛 Common Issues & Fixes

### Issue: Pods not starting
**Fix**: Check logs, verify image registry access, check resource limits

### Issue: Database connection fails
**Fix**: Verify security groups, check credentials, verify endpoint

### Issue: Health check fails
**Fix**: Verify service endpoints, check timeout settings, verify network

### Issue: DNS not resolving
**Fix**: Check name servers, wait for propagation, verify Route53 configuration

### Issue: DR failover fails
**Fix**: Check scripts, verify credentials, check network connectivity

---

## ✅ Testing Checklist Summary

**Minimum for Demo**:
- [ ] Infrastructure deploys
- [ ] Services run on both clouds
- [ ] Frontend accessible
- [ ] DR failover works once
- [ ] Data accessible after failover

**Complete Testing**:
- [ ] All phases tested (1-14)
- [ ] All scenarios pass
- [ ] Performance verified
- [ ] Security verified
- [ ] Documentation complete

---

## 📝 Test Results Log

Create a file to track your testing:

```markdown
# Test Results Log

## Date: [Date]

### Infrastructure Tests
- [ ] AWS deployed: ✅ / ❌
- [ ] Azure deployed: ✅ / ❌
- Notes: ...

### Service Tests
- [ ] Frontend deployed: ✅ / ❌
- [ ] Backend deployed: ✅ / ❌
- Notes: ...

### DR Failover Tests
- [ ] Dry run: ✅ / ❌
- [ ] Actual failover: ✅ / ❌
- RTO achieved: ___ minutes
- Notes: ...

### Issues Found
1. ...
2. ...

### Fixes Applied
1. ...
2. ...
```

---

## 🎯 Success Criteria for LinkedIn Post

**Ready to post when**:
1. ✅ Infrastructure deploys successfully
2. ✅ Services run on both clouds
3. ✅ Frontend accessible and functional
4. ✅ At least one successful DR failover
5. ✅ Screenshots/videos captured
6. ✅ Documentation complete

**n8n workflow** can be added as an update post later!

---

**Work through these tests systematically, and you'll have confidence in your project before posting!** 🚀

