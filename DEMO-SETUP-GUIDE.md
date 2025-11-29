# CloudPhoenix - Complete DR Demo Setup Guide

## 🎯 Goal

Set up a complete, visible DR demonstration with:
- ✅ Route53 domain (demo.cloudphoenix.io)
- ✅ Frontend UI users can see
- ✅ Backend API connected to database
- ✅ Full infrastructure on both clouds
- ✅ Visible DR failover (AWS → Azure)

---

## 📋 What You Now Have

### ✅ Frontend Service
- **Location**: `services/frontend/`
- **Files**: `index.html`, `app.js`, `Dockerfile`, `nginx.conf`
- **Features**: 
  - Shows current cloud provider (AWS/Azure badge)
  - Displays health score
  - Shows database status
  - Real-time status updates
  - Beautiful UI

### ✅ Backend API Endpoint
- **Location**: `services/service-a/app.py`
- **Endpoint**: `/api/cloud-status`
- **Returns**: Current cloud provider, database status, region

### ✅ Route53 Module
- **Location**: `terraform/modules/aws-route53/`
- **Features**: Hosted zone, DNS records, health checks

### ✅ Updated ALB
- **Location**: `terraform/modules/aws-alb/`
- **Features**: Frontend target group, backend target group, routing rules

### ✅ Frontend Helm Chart
- **Location**: `k8s/helm/frontend/`
- **Ready to deploy** to Kubernetes

### ✅ Updated DNS Switch Script
- **Location**: `scripts/switch_dns.sh`
- **Features**: Supports Route53 A records (AWS) and CNAME (Azure)

---

## 🚀 Complete Deployment Steps

### Step 1: Get a Domain (Optional but Recommended)

**Option A: Use Your Own Domain**
- Register a domain (e.g., from Route53, Namecheap, GoDaddy)
- Example: `cloudphoenix.io` or `yourname.dev`

**Option B: Use Subdomain**
- Use a subdomain of a domain you own
- Example: `demo.yourdomain.com`

**Option C: Test Without Domain**
- Use ALB DNS name directly for testing
- Less impressive but works for demo

### Step 2: Update Terraform Variables

Edit `terraform/aws/terraform.tfvars`:

```hcl
aws_region = "us-east-1"
project_name = "cloudphoenix"
environment = "production"

# Add domain name for Route53
domain_name = "demo.cloudphoenix.io"  # Or your domain

# Azure Traffic Manager domain (get this after deploying Azure)
azure_traffic_manager_domain = "cloudphoenix-dr.trafficmanager.net"
```

### Step 3: Deploy AWS Infrastructure (With Route53)

```bash
cd terraform/aws

# Initialize
terraform init

# Plan (review changes)
terraform plan

# Apply
terraform apply
```

**After deployment, note:**
- ALB DNS name
- Route53 hosted zone ID
- Name servers (you'll need these!)

### Step 4: Configure Domain Name Servers

If you used Route53:
1. Copy the name servers from Terraform output:
   ```bash
   terraform output route53_name_servers
   ```
2. Update your domain registrar with these name servers
3. Wait for DNS propagation (5-60 minutes)

### Step 5: Build and Push Frontend Image

**For AWS (EKS)**:
```bash
# Build frontend image
cd services/frontend
docker build -t cloudphoenix/frontend:latest .

# Tag for ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_URL
docker tag cloudphoenix/frontend:latest YOUR_ECR_URL/frontend:latest

# Push to ECR
docker push YOUR_ECR_URL/frontend:latest
```

**For Azure (AKS)**:
```bash
# Build and tag
docker build -t cloudphoenix/frontend:latest .
docker tag cloudphoenix/frontend:latest YOUR_ACR_URL/frontend:latest

# Push to Azure Container Registry
az acr login --name YOUR_ACR_NAME
docker push YOUR_ACR_URL/frontend:latest
```

### Step 6: Deploy Frontend to EKS

```bash
# Configure kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cloudphoenix-eks

# Update Helm values
cd k8s/helm/frontend
nano values.yaml  # Update image.repository with your ECR URL

# Deploy
helm install frontend . --namespace cloudphoenix --create-namespace

# Or upgrade if already deployed
helm upgrade frontend . --namespace cloudphoenix
```

### Step 7: Update ALB Target Group

The frontend service needs to be registered with ALB:

```bash
# Get frontend pod IPs
kubectl get pods -n cloudphoenix -l app.kubernetes.io/name=frontend -o wide

# Register with ALB target group (via AWS Console or CLI)
aws elbv2 register-targets \
    --target-group-arn YOUR_FRONTEND_TARGET_GROUP_ARN \
    --targets Id=POD_IP_1 Id=POD_IP_2
```

Or use AWS Load Balancer Controller (recommended):
```bash
# Install AWS Load Balancer Controller
# This automatically registers pods with ALB
kubectl apply -k "https://github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cloudphoenix-eks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 8: Verify Frontend is Accessible

```bash
# Get ALB DNS name
terraform output -json | jq -r '.alb_dns_name.value'

# Or if using Route53
curl http://demo.cloudphoenix.io
# Or open in browser: http://demo.cloudphoenix.io
```

You should see:
- CloudPhoenix dashboard
- AWS badge
- Health score
- Database status

### Step 9: Deploy Backend Services

```bash
# Deploy Service A
cd k8s/helm/service-a
helm install service-a . --namespace cloudphoenix

# Deploy Service B
cd ../service-b
helm install service-b . --namespace cloudphoenix

# Update service-a to include cloud-status endpoint (already done in code)
```

### Step 10: Test Complete Stack

1. **Visit Frontend**: `http://demo.cloudphoenix.io` (or ALB DNS)
2. **Verify it shows**:
   - Current cloud: AWS
   - Health score
   - Database connected
   - Backend services healthy
3. **Test API**: `http://demo.cloudphoenix.io/api/cloud-status`
   - Should return: `{"provider": "aws", "status": "operational", ...}`

### Step 11: Deploy Azure DR Infrastructure

```bash
cd terraform/azure

# Deploy Azure infrastructure
terraform init
terraform plan
terraform apply

# Note Azure Traffic Manager endpoint
terraform output traffic_manager_endpoint
```

### Step 12: Deploy Frontend to Azure AKS

```bash
# Configure Azure kubeconfig
az aks get-credentials --resource-group cloudphoenix-dr-rg --name cloudphoenix-dr-aks

# Deploy frontend
cd k8s/helm/frontend
helm install frontend . \
  --namespace cloudphoenix \
  --create-namespace \
  --set image.repository=YOUR_ACR_URL/frontend
```

### Step 13: Test DR Failover

**Manual DR Trigger**:
```bash
# Update switch_dns.sh environment variables
export DNS_ZONE="cloudphoenix.io"
export RECORD_NAME="demo"
export AZURE_TM_DNS="your-azure-tm.trafficmanager.net"
export AWS_ALB_DNS="your-alb.region.elb.amazonaws.com"
export AWS_ALB_ZONE_ID="Z35SXDOTRQ7X7K"  # Get from Terraform output

# Trigger DR failover
./scripts/switch_dns.sh azure
```

**Or via Jenkins**:
1. Go to Jenkins → CloudPhoenix Pipeline
2. Build with Parameters:
   - ACTION: `dr_failover`
   - DRY_RUN: `false`

### Step 14: Verify DR Failover

1. **Wait for DNS propagation** (60 seconds to a few minutes)
2. **Visit**: `http://demo.cloudphoenix.io`
3. **Should now show**:
   - Azure badge (blue) instead of AWS (orange)
   - Same data (from Azure SQL)
   - Services running on Azure
4. **Verify**: Frontend updated automatically

---

## 🎬 Demo Flow

### Before Failover:
```
User → demo.cloudphoenix.io → Route53 → AWS ALB → EKS → Frontend + Backend → RDS
```
**Frontend shows**: 🟠 AWS badge, data from RDS

### During Failover:
1. Health score > 11 detected
2. LLM analyzes: AWS infrastructure issue confirmed
3. DR triggered
4. Database replication (RDS → Azure SQL)
5. Storage sync (S3 → Blob)
6. Services deployed to Azure
7. DNS switched (Route53 → Azure TM)

### After Failover:
```
User → demo.cloudphoenix.io → Route53 → Azure Traffic Manager → AKS → Frontend + Backend → Azure SQL
```
**Frontend shows**: 🔵 Azure badge, same data (from Azure SQL)

**Key Point**: Same URL, same data, different cloud!

---

## 📊 What Users See

### Frontend Dashboard Shows:
1. **Current Cloud Provider**: 
   - 🟠 AWS (before failover)
   - 🔵 Azure (after failover)

2. **Health Score**: 
   - Visual indicator (green/yellow/red)
   - Failover level

3. **Database Status**:
   - Connected/Disconnected
   - RDS PostgreSQL (AWS) or Azure SQL (Azure)

4. **Backend Services**:
   - Service A & B status
   - Health indicators

5. **System Data**:
   - Data from database
   - Updated in real-time

6. **DR Status**:
   - Normal (green)
   - DR Active (yellow/orange during failover)

---

## 🧪 Testing Scenarios

### Test 1: Normal Operation
1. Visit `demo.cloudphoenix.io`
2. Should see AWS badge
3. Health score low (0-3)
4. All services healthy

### Test 2: Simulate Failure
```bash
# Simulate AWS failure
./cicd/simulate_failure.sh region-isolation

# Or manually trigger DR
./scripts/trigger_dr.sh
```

### Test 3: Observe Failover
1. Watch health score increase
2. LLM analyzes issue
3. DR triggered
4. DNS switches
5. Frontend updates to show Azure

### Test 4: Verify After Failover
1. Visit same URL: `demo.cloudphoenix.io`
2. Should see Azure badge
3. Same data accessible
4. Services running on Azure

### Test 5: Rollback
```bash
# Switch back to AWS
./scripts/switch_dns.sh aws
```

---

## 🔧 Configuration Files to Update

1. **`terraform/aws/terraform.tfvars`**:
   - Add `domain_name`
   - Add `azure_traffic_manager_domain`

2. **`scripts/switch_dns.sh`** (environment variables):
   ```bash
   export DNS_ZONE="cloudphoenix.io"
   export RECORD_NAME="demo"
   export AWS_ALB_DNS="your-alb.region.elb.amazonaws.com"
   export AWS_ALB_ZONE_ID="Z35SXDOTRQ7X7K"
   export AZURE_TM_DNS="your-azure-tm.trafficmanager.net"
   ```

3. **`k8s/helm/frontend/values.yaml`**:
   - Update `image.repository` with your container registry URL

4. **`k8s/helm/service-a/values.yaml`**:
   - Update `env.DB_HOST` with RDS endpoint
   - Update `env.CLOUD_PROVIDER` (optional)

---

## 🎯 Key Endpoints for Demo

- **Frontend**: `http://demo.cloudphoenix.io` (or ALB DNS)
- **API Cloud Status**: `http://demo.cloudphoenix.io/api/cloud-status`
- **API Health**: `http://demo.cloudphoenix.io/api/health`
- **API Data**: `http://demo.cloudphoenix.io/api/data`

---

## ✅ Checklist for Complete Demo

- [ ] Domain configured (Route53 or subdomain)
- [ ] AWS infrastructure deployed (including Route53)
- [ ] Azure infrastructure deployed (including Traffic Manager)
- [ ] Frontend image built and pushed (both clouds)
- [ ] Frontend deployed to EKS
- [ ] Frontend deployed to AKS
- [ ] Backend services deployed (both clouds)
- [ ] ALB target groups configured
- [ ] Database populated with test data
- [ ] DNS working (domain resolves to AWS)
- [ ] Frontend accessible and shows AWS
- [ ] DR failover tested (AWS → Azure)
- [ ] Frontend updates to show Azure
- [ ] Data accessible on both clouds

---

## 🚨 Troubleshooting

**Frontend not loading**:
- Check ALB target group has frontend pods registered
- Verify frontend service is running: `kubectl get pods -n cloudphoenix`
- Check ALB security groups allow port 80

**DNS not resolving**:
- Verify name servers configured in domain registrar
- Check Route53 hosted zone is active
- Wait for DNS propagation (can take up to 48 hours, usually 5-60 minutes)

**Frontend shows wrong cloud**:
- Check `/api/cloud-status` endpoint
- Verify environment variables in service-a
- Check database connection (should detect from DB host)

**DR failover not working**:
- Verify `switch_dns.sh` has correct environment variables
- Check Azure Traffic Manager is configured
- Verify services are running on Azure AKS

---

## 📝 What's Left (For You)

✅ **Everything is ready except:**
- **n8n workflow** - You'll build this manually (see `n8n-workflows/ADVANCED-SETUP-GUIDE.md`)

The n8n workflow will:
1. Receive health alerts
2. Gather context
3. Send to LLM for analysis
4. Trigger DR if needed

**Everything else is complete!** 🎉

---

## 🎉 You Now Have

1. ✅ **Frontend UI** - Users can see the system
2. ✅ **Route53 domain** - Professional URL
3. ✅ **Complete infrastructure** - AWS + Azure
4. ✅ **Database connections** - RDS + Azure SQL
5. ✅ **DNS switching** - Automated failover
6. ✅ **Visible demo** - Impressive demonstration

**Just add n8n workflow and you're done!** 🚀

