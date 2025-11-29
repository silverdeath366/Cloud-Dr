# CloudPhoenix - How It Works (Technical Deep Dive)

## 🎯 Overview

This document explains **HOW** CloudPhoenix works at a technical level - the algorithms, data flows, and mechanics behind each component.

---

## 1. Health Scoring System - How It Works

### The Algorithm

The health scoring system uses a **weighted composite scoring** approach:

```python
# Simplified version of the actual algorithm
class HealthChecker:
    def calculate_score(self):
        total_score = 0
        
        # Each signal has a weight based on severity
        for signal_name, signal_data in self.signals.items():
            weight = signal_data.get('weight', 0)
            total_score += weight
        
        return total_score
```

### Signal Collection Process

**Step 1: Internal Service Health Checks**
```python
# Checks Flask services via HTTP
GET http://service-a:8080/health
GET http://service-b:8080/health

# Response format:
{
    "status": "healthy" | "degraded" | "unhealthy",
    "checks": {
        "database": "ok",
        "storage": "ok"
    }
}

# Weight assignment:
- "healthy" → weight: 0 (no penalty)
- "degraded" → weight: 2 (minor issue)
- "unhealthy" → weight: 5 (major issue)
```

**Step 2: External Uptime Monitors**
```python
# Checks external endpoints
GET https://httpbin.org/status/200

# Weight assignment:
- 200 OK → weight: 0
- Error/timeout → weight: 3
```

**Step 3: Cross-Cloud Probe (Azure)**
```python
# Checks if Azure DR site is reachable
GET https://azure-probe-url/health

# Weight assignment:
- OK → weight: 0
- Error → weight: 4 (DR site unreachable is serious)
```

**Step 4: Database Replication Lag**
```python
# PostgreSQL query to check replication lag
SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds

# Weight assignment:
- lag < 5 seconds → weight: 0
- lag 5-30 seconds → weight: 1
- lag > 30 seconds → weight: 3
```

**Step 5: EKS Node States**
```python
# Uses boto3 to check EKS cluster
eks_client = boto3.client('eks')
node_groups = eks_client.list_nodegroups(clusterName='cloudphoenix-eks')

# Checks each node group status
# Weight assignment:
- All ACTIVE → weight: 0
- 1 node group unhealthy → weight: 2
- 2+ node groups unhealthy → weight: 4
```

**Step 6: AWS Cross-Region Check**
```python
# Checks if AWS services in another region are accessible
ec2_client = boto3.client('ec2', region_name='us-west-2')
ec2_client.describe_regions()  # Tests API connectivity

# Weight assignment:
- Accessible → weight: 0
- Degraded → weight: 2
- Unreachable → weight: 3
```

### Score Calculation Example

**Scenario: Multiple Issues Detected**

```
Signal                    Status        Weight    Contribution
─────────────────────────────────────────────────────────────
internal_service_a        unhealthy     5        +5
internal_service_b        degraded      2        +2
external_uptime           ok            0        +0
azure_probe               error         4        +4
rds_lag                   ok            0        +0
eks_nodes                 degraded      2        +2
aws_cross_region          ok            0        +0
─────────────────────────────────────────────────────────────
TOTAL SCORE:                                   13
```

**Result**: Score 13 → **Level 3 (DR Failover)** triggered

### Failover Level Decision Logic

```python
def get_failover_level(score):
    if score <= 3:
        return "no_action"      # Everything fine
    elif score <= 7:
        return "app_self_healing"  # Minor issues, restart pods
    elif score <= 10:
        return "region_failover"   # Regional issues, failover within AWS
    else:
        return "dr_failover"       # Critical, failover to Azure
```

---

## 2. LLM Integration - How It Works

### The Complete Flow

**Step 1: Health Score Threshold Triggered**
```
Health Check Script → Score: 12 → Threshold: 11+ → ALERT
```

**Step 2: Context Gathering (Python Script)**

The `gather_incident_context.py` script collects data from multiple sources:

```python
# 1. Check AWS Health API
health_client = boto3.client('health', region_name='us-east-1')
events = health_client.describe_events(
    filter={'startTimes': [{'from': start_time, 'to': end_time}]}
)
# Returns: List of AWS service events affecting your account

# 2. Check Cloudflare Status API (Public, no auth)
response = requests.get("https://www.cloudflarestatus.com/api/v2/status.json")
# Returns: Overall Cloudflare status

incidents = requests.get("https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json")
# Returns: Active Cloudflare incidents

# 3. Query Prometheus Metrics
prometheus_url = "http://prometheus:9090/api/v1/query"
error_rate = requests.get(prometheus_url, params={
    'query': 'rate(http_requests_total{status=~"5.."}[5m])'
})
# Returns: Error rate over last 5 minutes

# 4. Query Loki Logs
loki_url = "http://loki:3100/loki/api/v1/query_range"
logs = requests.get(loki_url, params={
    'query': '{job=~".+"} |= "error"',
    'start': start_time_nanoseconds,
    'end': end_time_nanoseconds,
    'limit': 50
})
# Returns: Recent error logs

# 5. Run Health Check Again
health_result = subprocess.run(['python3', 'scripts/healthcheck.py'])
# Returns: Current health score and all signals
```

**Step 3: Data Aggregation**

All data is combined into a structured format:

```python
context = {
    'timestamp': '2024-01-01T12:00:00Z',
    'health_score': 12,
    'aws_status': {
        'has_open_issues': True,
        'open_event_count': 2,
        'recent_events': [
            {
                'service': 'EC2',
                'eventTypeCode': 'AWS_EC2_INSTANCE_STOP_SCHEDULED',
                'statusCode': 'open',
                'startTime': '2024-01-01T11:45:00Z'
            }
        ]
    },
    'cloudflare_status': {
        'api_status': 'operational',
        'has_active_incidents': False,
        'incidents': []
    },
    'internal_metrics': {
        'error_rate': 0.05,  # 5% error rate
        'latency_p95': 1.2    # 1.2 seconds
    },
    'recent_logs': [
        {'timestamp': '...', 'message': 'Connection timeout to RDS'},
        {'timestamp': '...', 'message': 'EC2 instance unreachable'}
    ],
    'health_check_results': {
        'score': 12,
        'signals': {...}
    }
}
```

**Step 4: LLM Prompt Construction**

The context is formatted into a prompt for the LLM:

```python
prompt = f"""
# Incident Analysis Request

## Timestamp
{context['timestamp']}

## Health Score Alert
Health Score: {context['health_score']}
Alert: HighHealthScore
Severity: critical

## AWS Infrastructure Status
{json.dumps(context['aws_status'], indent=2)}

## Cloudflare Infrastructure Status
{json.dumps(context['cloudflare_status'], indent=2)}

## Internal Health Check Results
{json.dumps(context['health_check_results'], indent=2)}

## Internal Metrics (Prometheus)
{json.dumps(context['internal_metrics'], indent=2)}

## Recent Error Logs (Sample)
{json.dumps(context['recent_logs'][:10], indent=2)}

---

## Your Task

Analyze this incident and determine:

1. Root Cause Category:
   - "aws_infrastructure" - Problem is with AWS services
   - "cloudflare_infrastructure" - Problem is with Cloudflare
   - "internal_bug" - Problem is with our application code
   - "network" - Network connectivity issue
   - "unknown" - Cannot determine

2. Confidence Level: high, medium, or low

3. Evidence: Brief explanation

4. Recommended Action:
   - "trigger_dr" - ONLY if it's AWS/Cloudflare infrastructure issue
   - "investigate" - If it's likely an internal bug
   - "monitor" - If unclear or minor issue
   - "wait" - If external service shows resolution in progress

5. Reasoning: Detailed explanation

Respond in JSON format:
{{
  "root_cause_category": "...",
  "confidence": "...",
  "evidence": "...",
  "recommended_action": "...",
  "reasoning": "..."
}}
"""
```

**Step 5: LLM API Call**

```python
# OpenAI API call
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {
            "role": "system",
            "content": "You are an expert infrastructure analyst..."
        },
        {
            "role": "user",
            "content": prompt
        }
    ],
    temperature=0.1,  # Low temperature for deterministic responses
    max_tokens=1000
)

# Response format:
{
    "choices": [{
        "message": {
            "content": '{\n  "root_cause_category": "aws_infrastructure",\n  "confidence": "high",\n  "evidence": "AWS Health API shows open EC2 events in us-east-1 region",\n  "recommended_action": "trigger_dr",\n  "reasoning": "The health score of 12 combined with AWS Health API showing open EC2 events indicates a real AWS infrastructure issue. The error logs showing connection timeouts to RDS and EC2 instances being unreachable correlate with the AWS events. This is not an internal bug but an external infrastructure failure."\n}'
        }
    }]
}
```

**Step 6: Response Parsing**

```python
# Extract JSON from LLM response
llm_response = response.choices[0].message.content

# Remove markdown code blocks if present
json_str = llm_response.replace('```json\n', '').replace('```', '')

# Parse JSON
analysis = json.loads(json_str)

# Result:
{
    "root_cause_category": "aws_infrastructure",
    "confidence": "high",
    "evidence": "AWS Health API shows open EC2 events",
    "recommended_action": "trigger_dr",
    "reasoning": "Health score 12 + AWS events = external issue"
}
```

**Step 7: Decision Logic**

```python
if analysis['recommended_action'] == 'trigger_dr' and analysis['confidence'] == 'high':
    # Trigger Jenkins DR pipeline
    trigger_jenkins_dr()
else:
    # Log decision, don't trigger DR
    log_decision(analysis)
```

---

## 3. Failover Process - How It Works

### Complete DR Failover Flow

**Step 1: Jenkins Pipeline Triggered**

```groovy
// Jenkins receives trigger (manual or automated)
pipeline {
    parameters {
        choice(name: 'ACTION', choices: ['dr_failover'])
    }
    
    stages {
        stage('Health Check') {
            // Run health check to confirm issue still exists
            sh 'python3 scripts/healthcheck.py'
        }
        
        stage('DR: Sync Data') {
            // Step 2: Database Replication
            sh './scripts/replicate_db.sh'
            
            // Step 3: Storage Sync
            sh './scripts/sync_s3.sh'
        }
        
        stage('DR: Provision Azure') {
            // Step 4: Infrastructure Provisioning
            dir('terraform/azure') {
                sh 'terraform init'
                sh 'terraform plan'
                sh 'terraform apply -auto-approve'
            }
        }
        
        stage('DR: Deploy Services') {
            // Step 5: Service Deployment
            sh 'helm install service-a k8s/helm/service-a --kubeconfig azure-kubeconfig'
            sh 'helm install service-b k8s/helm/service-b --kubeconfig azure-kubeconfig'
        }
        
        stage('DR: Switch DNS') {
            // Step 6: DNS Switchover
            sh './scripts/switch_dns.sh --target azure'
        }
        
        stage('DR: Verify') {
            // Step 7: Service Verification
            sh './scripts/verify_services.sh'
        }
    }
}
```

**Step 2: Database Replication (Detailed)**

```bash
# replicate_db.sh script flow:

# 1. Export data from AWS RDS
pg_dump -h $AWS_RDS_HOST \
        -U $DB_USER \
        -d $DB_NAME \
        --format=custom \
        --file=/tmp/db_backup.dump

# 2. Upload to S3 (temporary storage)
aws s3 cp /tmp/db_backup.dump s3://$BACKUP_BUCKET/db_backup.dump

# 3. Download from S3 to Azure environment
az storage blob download \
    --account-name $AZURE_STORAGE_ACCOUNT \
    --container-name backups \
    --name db_backup.dump \
    --file /tmp/db_backup.dump

# 4. Import to Azure SQL
pg_restore -h $AZURE_SQL_HOST \
           -U $AZURE_DB_USER \
           -d $AZURE_DB_NAME \
           --clean \
           --if-exists \
           /tmp/db_backup.dump

# 5. Verify replication
psql -h $AZURE_SQL_HOST -U $AZURE_DB_USER -d $AZURE_DB_NAME -c "SELECT COUNT(*) FROM users;"
```

**Step 3: Storage Sync (Detailed)**

```bash
# sync_s3.sh script flow:

# 1. List all objects in S3
aws s3 ls s3://$S3_BUCKET --recursive > /tmp/s3_objects.txt

# 2. Sync to Azure Blob Storage
# Uses Azure CLI to copy each object
while read -r line; do
    object_path=$(echo $line | awk '{print $4}')
    
    # Download from S3
    aws s3 cp s3://$S3_BUCKET/$object_path /tmp/$object_path
    
    # Upload to Azure Blob
    az storage blob upload \
        --account-name $AZURE_STORAGE_ACCOUNT \
        --container-name $BLOB_CONTAINER \
        --name $object_path \
        --file /tmp/$object_path \
        --overwrite
    
    # Cleanup
    rm /tmp/$object_path
done < /tmp/s3_objects.txt

# 3. Verify sync
az storage blob list \
    --account-name $AZURE_STORAGE_ACCOUNT \
    --container-name $BLOB_CONTAINER \
    --output table
```

**Step 4: Infrastructure Provisioning (Detailed)**

```hcl
# terraform/azure/main.tf

# 1. Create Resource Group
resource "azurerm_resource_group" "dr" {
  name     = "cloudphoenix-dr"
  location = "eastus"
}

# 2. Create VNET
resource "azurerm_virtual_network" "dr" {
  name                = "cloudphoenix-dr-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
}

# 3. Create AKS Cluster
resource "azurerm_kubernetes_cluster" "dr" {
  name                = "cloudphoenix-dr-aks"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  dns_prefix          = "cloudphoenix-dr"
  
  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2s_v3"
  }
  
  identity {
    type = "SystemAssigned"
  }
}

# 4. Create Azure SQL Database
resource "azurerm_sql_server" "dr" {
  name                         = "cloudphoenix-dr-sql"
  resource_group_name          = azurerm_resource_group.dr.name
  location                     = azurerm_resource_group.dr.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

# Terraform applies these resources in dependency order
```

**Step 5: Service Deployment (Detailed)**

```bash
# Helm deployment process:

# 1. Get Azure kubeconfig
az aks get-credentials \
    --resource-group cloudphoenix-dr \
    --name cloudphoenix-dr-aks

# 2. Create namespace
kubectl create namespace cloudphoenix

# 3. Create secrets
kubectl create secret generic db-credentials \
    --from-literal=username=$AZURE_DB_USER \
    --from-literal=password=$AZURE_DB_PASSWORD \
    -n cloudphoenix

# 4. Deploy Service A
helm install service-a k8s/helm/service-a \
    --namespace cloudphoenix \
    --set image.repository=$ACR_URL/service-a \
    --set database.host=$AZURE_SQL_HOST \
    --set storage.account=$AZURE_STORAGE_ACCOUNT

# 5. Deploy Service B
helm install service-b k8s/helm/service-b \
    --namespace cloudphoenix \
    --set image.repository=$ACR_URL/service-b

# 6. Wait for pods to be ready
kubectl wait --for=condition=ready pod \
    -l app=service-a \
    -n cloudphoenix \
    --timeout=300s
```

**Step 6: DNS Switchover (Detailed)**

```bash
# switch_dns.sh script flow:

# 1. Get current DNS records
current_record=$(aws route53 list-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query "ResourceRecordSets[?Name=='app.example.com.']" \
    --output json)

# 2. Get Azure Traffic Manager endpoint IP
azure_endpoint=$(az network traffic-manager endpoint show \
    --name azure-primary \
    --profile-name cloudphoenix \
    --resource-group cloudphoenix-dr \
    --query "target" \
    --output tsv)

# 3. Update Route53 record to point to Azure
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "app.example.com",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [{"Value": "'$azure_endpoint'"}]
            }
        }]
    }'

# 4. Wait for DNS propagation
sleep 60

# 5. Verify DNS resolution
nslookup app.example.com
```

**Step 7: Service Verification (Detailed)**

```bash
# verify_services.sh script flow:

# 1. Check Service A health
response=$(curl -s -o /dev/null -w "%{http_code}" \
    https://app.example.com/service-a/health)

if [ "$response" != "200" ]; then
    echo "ERROR: Service A health check failed"
    exit 1
fi

# 2. Check Service B health
response=$(curl -s -o /dev/null -w "%{http_code}" \
    https://app.example.com/service-b/health)

if [ "$response" != "200" ]; then
    echo "ERROR: Service B health check failed"
    exit 1
fi

# 3. Check database connectivity
psql -h $AZURE_SQL_HOST -U $AZURE_DB_USER -d $AZURE_DB_NAME \
    -c "SELECT 1;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Database connectivity check failed"
    exit 1
fi

# 4. Check storage access
az storage blob list \
    --account-name $AZURE_STORAGE_ACCOUNT \
    --container-name $BLOB_CONTAINER \
    --query "[0].name" \
    --output tsv > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Storage access check failed"
    exit 1
fi

echo "SUCCESS: All services verified"
```

---

## 4. Data Flow - Complete System

### Normal Operation Flow

```
┌─────────┐
│  User   │
└────┬────┘
     │ HTTP Request
     ▼
┌─────────────────┐
│  AWS ALB        │ (Application Load Balancer)
│  (DNS: app.com) │
└────┬────────────┘
     │ Routes to target group
     ▼
┌─────────────────┐
│  EKS Cluster    │
│  ┌───────────┐  │
│  │ Service A │  │ (Flask app in pod)
│  └─────┬─────┘  │
│        │        │
│  ┌─────▼─────┐  │
│  │ Service B │  │ (Flask app in pod)
│  └─────┬─────┘  │
└────────┼────────┘
         │
         ├─────────────────┐
         │                 │
         ▼                 ▼
┌─────────────┐   ┌─────────────┐
│  RDS (AWS)  │   │  S3 (AWS)   │
│  PostgreSQL │   │  Storage    │
└─────────────┘   └─────────────┘

Parallel Monitoring:
┌─────────────┐
│ Prometheus │ ← Scrapes metrics from services
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Grafana    │ ← Visualizes metrics
└─────────────┘

┌─────────────┐
│    Loki     │ ← Aggregates logs from services
└─────────────┘

┌──────────────────┐
│ Health Check     │ ← Runs every 30 seconds
│ (healthcheck.py) │
└──────────────────┘
```

### Failover Flow (When Score > 11)

```
1. Health Check Detects Issue
   └─> Score: 12 (threshold: 11+)
       └─> Alert triggered

2. n8n Workflow Activated (Webhook)
   └─> gather_incident_context.py runs
       ├─> Checks AWS Health API
       ├─> Checks Cloudflare Status
       ├─> Queries Prometheus
       ├─> Queries Loki
       └─> Aggregates all data

3. LLM Analysis
   └─> Prompt sent to GPT-4/Claude
       └─> Response: {
             "root_cause_category": "aws_infrastructure",
             "confidence": "high",
             "recommended_action": "trigger_dr"
           }

4. Decision Made
   └─> IF recommended_action == "trigger_dr" AND confidence == "high"
       └─> Trigger Jenkins Pipeline

5. Jenkins Pipeline Executes
   ├─> Stage 1: Health Check (confirm issue)
   ├─> Stage 2: Database Replication
   │   └─> RDS → S3 → Azure SQL
   ├─> Stage 3: Storage Sync
   │   └─> S3 → Azure Blob
   ├─> Stage 4: Provision Azure
   │   └─> Terraform apply (AKS, SQL, Storage)
   ├─> Stage 5: Deploy Services
   │   └─> Helm install to AKS
   ├─> Stage 6: DNS Switchover
   │   └─> Route53 → Azure Traffic Manager
   └─> Stage 7: Verify Services
       └─> Health checks on Azure services

6. Traffic Now Flows to Azure
   └─> User → Azure Traffic Manager → AKS → Azure SQL/Blob
```

---

## 5. Component Interactions

### How Components Communicate

**Health Check → Prometheus:**
```python
# Services expose metrics endpoint
GET /metrics

# Prometheus scrapes every 30 seconds
# Prometheus config:
scrape_configs:
  - job_name: 'service-a'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        regex: service-a
        action: keep
```

**Health Check → Jenkins:**
```bash
# Health check script can trigger Jenkins via API
curl -X POST \
    "http://jenkins:8080/job/CloudPhoenix/buildWithParameters" \
    --user "admin:token" \
    --data "ACTION=dr_failover" \
    --data "DRY_RUN=false"
```

**Jenkins → Terraform:**
```groovy
// Jenkins executes Terraform
sh '''
    cd terraform/azure
    terraform init
    terraform apply -auto-approve
'''
```

**Jenkins → Kubernetes:**
```groovy
// Jenkins uses kubectl/helm
sh '''
    kubectl apply -f k8s/manifests/
    helm install service-a k8s/helm/service-a
'''
```

**n8n → LLM:**
```javascript
// n8n HTTP Request node
const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({
        model: 'gpt-4',
        messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt }
        ]
    })
});
```

---

## 6. Error Handling & Resilience

### Retry Logic

```python
# Example from healthcheck.py
@retry(max_attempts=3, backoff_factor=2)
def check_internal_service_health(self, service_url):
    response = requests.get(f"{service_url}/health", timeout=5)
    # If fails, retry with exponential backoff: 1s, 2s, 4s
```

### Timeout Handling

```python
# All HTTP requests have timeouts
requests.get(url, timeout=10)  # 10 second timeout

# Database connections have timeouts
psycopg2.connect(..., connect_timeout=5)
```

### Graceful Degradation

```python
# If one signal fails, others still work
try:
    aws_status = check_aws_status()
except Exception as e:
    logger.warning(f"AWS check failed: {e}")
    aws_status = {'error': str(e)}  # Continue with other checks
```

---

## 7. Security Mechanisms

### Secrets Management

```python
# AWS Secrets Manager
import boto3
secrets_client = boto3.client('secretsmanager')
db_password = secrets_client.get_secret_value(
    SecretId='cloudphoenix/db/password'
)['SecretString']

# Azure Key Vault
from azure.keyvault.secrets import SecretClient
secret_client = SecretClient(vault_url, credential)
db_password = secret_client.get_secret('db-password').value
```

### IAM Roles

```python
# Services use IAM roles, not credentials
# EKS pods use service accounts with IAM roles
# No hardcoded credentials
```

### Network Security

```hcl
# Security groups restrict access
resource "aws_security_group" "eks" {
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]  # Only internal traffic
    }
}
```

---

## Summary: The Complete Picture

1. **Health Scoring**: Collects 6+ signals, calculates weighted score (0-15+)
2. **Threshold Detection**: Score > 11 triggers alert
3. **Context Gathering**: Python script collects AWS, Cloudflare, metrics, logs
4. **LLM Analysis**: GPT-4/Claude analyzes context, returns decision
5. **Decision Logic**: Only trigger DR if LLM confirms external issue with high confidence
6. **DR Orchestration**: Jenkins pipeline executes 7 stages (data sync → provision → deploy → DNS → verify)
7. **Verification**: Health checks confirm services are running on Azure
8. **Traffic Switch**: DNS points to Azure, users now hit DR site

**Total Time**: <15 minutes from detection to full failover

---

This is HOW it works at a technical level! 🚀

