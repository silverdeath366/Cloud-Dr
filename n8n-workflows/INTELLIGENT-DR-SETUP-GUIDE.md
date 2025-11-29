# n8n Intelligent DR Decision Workflow - Complete Setup Guide

This guide walks you through building an n8n workflow that uses LLM (GPT/Claude) to intelligently determine if a problem is with AWS/Cloudflare infrastructure vs. an internal bug, and only triggers DR when appropriate.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Available Data Sources & Endpoints](#available-data-sources--endpoints)
4. [n8n Workflow Architecture](#n8n-workflow-architecture)
5. [Step-by-Step Workflow Building](#step-by-step-workflow-building)
6. [LLM Prompt Engineering](#llm-prompt-engineering)
7. [Testing Guide](#testing-guide)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

**Goal**: Build an n8n workflow that:
1. Receives alerts when health score exceeds threshold (11+)
2. Gathers context from AWS, Cloudflare, internal metrics, and logs
3. Uses LLM to analyze if it's AWS/Cloudflare issue vs. internal bug
4. Only triggers DR if it's an external infrastructure problem
5. Logs the decision and reasoning

**Workflow Trigger**: 
- Webhook from Prometheus alert OR
- Webhook from health check script when score > 11
- Scheduled check (every 1-5 minutes)

---

## ✅ Prerequisites

### Required Software
- **n8n** installed and running (cloud or self-hosted)
- **LLM API access**: OpenAI API or Anthropic Claude API
- **Python 3.8+** (for context gathering script)

### Required Credentials/API Keys
1. **LLM API Key**:
   - OpenAI: Get from https://platform.openai.com/api-keys
   - OR Anthropic: Get from https://console.anthropic.com/

2. **AWS Credentials** (for AWS Health API - optional):
   - AWS Access Key ID
   - AWS Secret Access Key
   - AWS Region (default: us-east-1)

3. **Prometheus URL** (if using Prometheus):
   - Default: `http://prometheus:9090`
   - Or: `http://your-prometheus-instance:9090`

4. **Loki URL** (if using Loki for logs):
   - Default: `http://loki:3100`
   - Or: `http://your-loki-instance:3100`

5. **Jenkins API** (for triggering DR):
   - Jenkins URL: `http://your-jenkins:8080`
   - Jenkins Username
   - Jenkins API Token

6. **Webhook URLs**:
   - Your n8n webhook URL (auto-generated when you create webhook node)

### Required Scripts Available in Project
- ✅ `scripts/gather_incident_context.py` - Gathers all context data
- ✅ `scripts/healthcheck.py` - Health check script
- ✅ `scripts/trigger_dr.sh` - DR trigger script

---

## 🔌 Available Data Sources & Endpoints

### 1. Health Check Script
**Location**: `scripts/healthcheck.py`  
**Command**: `python3 scripts/healthcheck.py`  
**Output**: JSON with health score, signals, failover_level

```json
{
  "score": 12,
  "signals": {...},
  "failover_level": "dr_failover",
  "timestamp": 1234567890
}
```

### 2. Incident Context Gatherer
**Location**: `scripts/gather_incident_context.py`  
**Command**: `python3 scripts/gather_incident_context.py --llm-prompt`  
**Output**: Comprehensive context including:
- AWS status (via AWS Health API)
- Cloudflare status (via public API)
- Internal health check results
- Prometheus metrics
- Loki logs
- Error patterns

### 3. Prometheus API
**Base URL**: `http://prometheus:9090`  
**Endpoints**:
- Query: `GET /api/v1/query?query=<promql>`
- Query Range: `GET /api/v1/query_range?query=<promql>&start=<time>&end=<time>`

**Example Queries**:
```promql
# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Latency (if you have this metric)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Health score
cloudphoenix_health_score
```

### 4. Loki API
**Base URL**: `http://loki:3100`  
**Endpoints**:
- Query Range: `GET /loki/api/v1/query_range?query=<logql>&start=<time>&end=<time>&limit=100`

**Example LogQL**:
```
{job=~".+"} |= "error" |= "ERROR" |= "exception"
{job="service-a"} | json | status="error"
```

### 5. AWS Health API
**Requires**: AWS credentials with Health API access  
**Endpoints** (via boto3 in Python script):
- `describe_events()` - Get recent events affecting account
- `describe_event_details()` - Get detailed event info

**Public Status Page**: `https://status.aws.amazon.com/` (can scrape or check manually)

### 6. Cloudflare Status API (Public - No Auth)
**Base URL**: `https://www.cloudflarestatus.com/api/v2/`  
**Endpoints**:
- Status: `GET /status.json`
- Components: `GET /components.json`
- Incidents: `GET /incidents/unresolved.json`

### 7. Jenkins API (Trigger DR)
**Base URL**: `http://your-jenkins:8080`  
**Endpoint**: `POST /job/CloudPhoenix/buildWithParameters`  
**Auth**: Basic Auth (username:token)  
**Parameters**:
- `ACTION=dr_failover`
- `DRY_RUN=false`

### 8. DR Trigger Script
**Location**: `scripts/trigger_dr.sh`  
**Usage**: Can be called from n8n using HTTP Request or Execute Command node

---

## 🏗️ n8n Workflow Architecture

```
┌─────────────────┐
│  Webhook Node   │ ← Trigger from Prometheus/Health Check
│  (Trigger)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   HTTP Request  │ ← Call gather_incident_context.py script
│  (Get Context)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   HTTP Request  │ ← Check Cloudflare Status API
│ (Cloudflare API)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   HTTP Request  │ ← Check AWS Status (or use Python script)
│   (AWS Status)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   HTTP Request  │ ← Query Prometheus for metrics
│  (Prometheus)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   HTTP Request  │ ← Query Loki for recent error logs
│    (Loki)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Code Node    │ ← Aggregate all data into LLM prompt
│  (Aggregate)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   OpenAI/Claude │ ← Send prompt to LLM for analysis
│     Node        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Code Node    │ ← Parse LLM JSON response
│  (Parse LLM)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│      IF Node    │ ← Check if recommended_action == "trigger_dr"
│   (Decision)    │
└────┬─────────┬──┘
     │ YES     │ NO
     ▼         ▼
┌──────────┐ ┌──────────────┐
│ HTTP Req │ │  HTTP Req    │
│ (Trigger │ │  (Log Only)  │
│   DR)    │ │              │
└──────────┘ └──────────────┘
```

---

## 📝 Step-by-Step Workflow Building

### Step 1: Create New Workflow in n8n

1. Open n8n interface
2. Click **"New Workflow"**
3. Name it: **"Intelligent DR Decision Workflow"**

### Step 2: Add Webhook Trigger Node

1. Click **"+"** to add node
2. Search for **"Webhook"** node
3. Select **"Webhook"** (not "Webhook Response")
4. Configure:
   - **HTTP Method**: POST
   - **Path**: `/intelligent-dr-check` (or your choice)
   - **Response Mode**: "Using 'Respond to Webhook' Node"
5. Click **"Execute Node"** to get webhook URL
6. Copy the webhook URL (you'll need this for Prometheus alert)

**Expected Input** (from health check or Prometheus):
```json
{
  "health_score": 12,
  "alert_name": "HighHealthScore",
  "severity": "critical",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Step 3: Add HTTP Request - Gather Context (Python Script)

This calls your `gather_incident_context.py` script.

**Option A: If script runs on same server as n8n** (Use Execute Command node):
1. Add **"Execute Command"** node
2. Configure:
   - **Command**: `python3`
   - **Arguments**: `/path/to/cloudphoenix/scripts/gather_incident_context.py --llm-prompt`
3. Connect from Webhook node

**Option B: If script is API endpoint** (Use HTTP Request):
1. Add **"HTTP Request"** node
2. Configure:
   - **Method**: POST
   - **URL**: `http://your-api-server:port/gather-context`
   - **Body**: JSON with health_score from webhook
3. Connect from Webhook node

**Option C: Call script directly in n8n** (Use Code node):
1. Add **"Code"** node
2. Write Python code to call the script functions (see Step 6 for example)

### Step 4: Add HTTP Request - Cloudflare Status

1. Add **"HTTP Request"** node
2. Configure:
   - **Method**: GET
   - **URL**: `https://www.cloudflarestatus.com/api/v2/status.json`
   - **Authentication**: None (public API)
3. Connect from context gatherer node

Add another HTTP Request node for incidents:
- **URL**: `https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json`

### Step 5: Add HTTP Request - Prometheus Metrics (Optional)

1. Add **"HTTP Request"** node
2. Configure:
   - **Method**: GET
   - **URL**: `http://prometheus:9090/api/v1/query`
   - **Query Parameters**:
     - `query`: `rate(http_requests_total{status=~"5.."}[5m])`
3. Connect from context node

### Step 6: Add Code Node - Aggregate Data for LLM

1. Add **"Code"** node
2. Select **"JavaScript"** (or "Python" if available)
3. Write code to combine all data into LLM prompt:

```javascript
// Get data from previous nodes
const webhookData = $input.item.json;
const contextData = $input.all()[1].json; // Adjust index based on your flow
const cloudflareStatus = $input.all()[2].json;
const cloudflareIncidents = $input.all()[3].json;

// Build LLM prompt
const prompt = `# Incident Analysis Request

## Timestamp
${new Date().toISOString()}

## Health Score Alert
Health Score: ${webhookData.health_score}
Alert: ${webhookData.alert_name}
Severity: ${webhookData.severity}

## AWS Infrastructure Status
${JSON.stringify(contextData.aws_status || {}, null, 2)}

## Cloudflare Infrastructure Status
Status: ${cloudflareStatus.status?.indicator || 'unknown'}
Description: ${cloudflareStatus.status?.description || 'N/A'}
Active Incidents: ${cloudflareIncidents.incidents?.length || 0}
${JSON.stringify(cloudflareIncidents.incidents || [], null, 2)}

## Internal Health Check Results
${JSON.stringify(contextData.health_check_results || {}, null, 2)}

## Internal Metrics
${JSON.stringify(contextData.internal_metrics || {}, null, 2)}

## Recent Error Logs (Sample)
${JSON.stringify(contextData.recent_logs?.slice(0, 10) || [], null, 2)}

## Detected Patterns
${JSON.stringify(contextData.error_patterns || [], null, 2)}

---

## Your Task

Analyze this incident and determine:

1. **Root Cause Category:**
   - "aws_infrastructure" - Problem is with AWS services (EKS, RDS, S3, etc.)
   - "cloudflare_infrastructure" - Problem is with Cloudflare services
   - "internal_bug" - Problem is with our application/infrastructure code
   - "network" - Network connectivity issue
   - "unknown" - Cannot determine with available data

2. **Confidence Level:** high, medium, or low

3. **Evidence:** Brief explanation of why you reached this conclusion

4. **Recommended Action:**
   - "trigger_dr" - ONLY if it's AWS or Cloudflare infrastructure issue affecting service availability
   - "investigate" - If it's likely an internal bug
   - "monitor" - If unclear or minor issue
   - "wait" - If external service shows resolution in progress

5. **Reasoning:** Detailed explanation (2-3 sentences)

**CRITICAL**: Only recommend "trigger_dr" if:
- AWS Health API shows open issues in your region/service
- Cloudflare has active incidents affecting your services
- You have HIGH confidence it's an external infrastructure issue

Respond in JSON format ONLY:
{
  "root_cause_category": "...",
  "confidence": "...",
  "evidence": "...",
  "recommended_action": "...",
  "reasoning": "..."
}`;

return {
  json: {
    prompt: prompt,
    raw_data: {
      webhook: webhookData,
      context: contextData,
      cloudflare_status: cloudflareStatus,
      cloudflare_incidents: cloudflareIncidents
    }
  }
};
```

### Step 7: Add OpenAI/Claude Node - LLM Analysis

**For OpenAI:**
1. Add **"OpenAI"** node (install from community nodes if needed)
2. Configure:
   - **Operation**: "Chat"
   - **Model**: `gpt-4` or `gpt-3.5-turbo` (gpt-4 recommended for accuracy)
   - **Messages**: 
     - Role: `system`
     - Content: `You are an expert infrastructure analyst. Analyze incidents and determine if they're caused by external infrastructure (AWS/Cloudflare) or internal bugs. Only recommend DR trigger for external infrastructure issues with high confidence.`
     - Role: `user`
     - Content: `{{ $json.prompt }}` (from previous node)
   - **Temperature**: `0.1` (lower = more deterministic)
   - **Max Tokens**: `1000`

**For Anthropic Claude:**
1. Add **"HTTP Request"** node
2. Configure:
   - **Method**: POST
   - **URL**: `https://api.anthropic.com/v1/messages`
   - **Headers**:
     - `anthropic-version`: `2023-06-01`
     - `x-api-key`: `your-claude-api-key` (store as credential)
     - `content-type`: `application/json`
   - **Body**:
```json
{
  "model": "claude-3-opus-20240229",
  "max_tokens": 1000,
  "system": "You are an expert infrastructure analyst. Analyze incidents and determine if they're caused by external infrastructure (AWS/Cloudflare) or internal bugs. Only recommend DR trigger for external infrastructure issues with high confidence.",
  "messages": [
    {
      "role": "user",
      "content": "{{ $json.prompt }}"
    }
  ]
}
```

3. Connect from aggregate node

### Step 8: Add Code Node - Parse LLM Response

1. Add **"Code"** node
2. Configure JavaScript:

```javascript
// Get LLM response
const llmResponse = $input.item.json;

// Extract content (format varies by LLM)
let content = '';
if (llmResponse.choices && llmResponse.choices[0]) {
  // OpenAI format
  content = llmResponse.choices[0].message.content;
} else if (llmResponse.content && llmResponse.content[0]) {
  // Claude format
  content = llmResponse.content[0].text;
} else {
  content = llmResponse.content || llmResponse.message || JSON.stringify(llmResponse);
}

// Parse JSON from response (LLM may return markdown code blocks)
let jsonStr = content.trim();

// Remove markdown code blocks if present
if (jsonStr.startsWith('```json')) {
  jsonStr = jsonStr.replace(/```json\n?/g, '').replace(/```\n?/g, '');
} else if (jsonStr.startsWith('```')) {
  jsonStr = jsonStr.replace(/```\n?/g, '');
}

try {
  const analysis = JSON.parse(jsonStr);
  
  return {
    json: {
      root_cause_category: analysis.root_cause_category || 'unknown',
      confidence: analysis.confidence || 'low',
      evidence: analysis.evidence || '',
      recommended_action: analysis.recommended_action || 'investigate',
      reasoning: analysis.reasoning || '',
      raw_llm_response: content,
      timestamp: new Date().toISOString()
    }
  };
} catch (error) {
  // Fallback if JSON parsing fails
  return {
    json: {
      root_cause_category: 'unknown',
      confidence: 'low',
      evidence: 'Failed to parse LLM response',
      recommended_action: 'investigate',
      reasoning: `LLM response parsing error: ${error.message}. Raw: ${content.substring(0, 200)}`,
      raw_llm_response: content,
      parse_error: true,
      timestamp: new Date().toISOString()
    }
  };
}
```

### Step 9: Add IF Node - Decision Logic

1. Add **"IF"** node
2. Configure:
   - **Condition**: `recommended_action` equals `trigger_dr`
   - AND `confidence` equals `high` (or `high` OR `medium`)
3. Connect from parse node

### Step 10: Add HTTP Request - Trigger DR (YES Branch)

1. Add **"HTTP Request"** node (YES branch from IF)
2. Configure:
   - **Method**: POST
   - **URL**: `http://your-jenkins:8080/job/CloudPhoenix/buildWithParameters`
   - **Authentication**: Basic Auth
     - **User**: Your Jenkins username
     - **Password**: Your Jenkins API token (store as credential)
   - **Query Parameters**:
     - `ACTION`: `dr_failover`
     - `DRY_RUN`: `false` (or `true` for testing)
   - **Body**: (optional)
```json
{
  "triggered_by": "n8n_intelligent_workflow",
  "health_score": "{{ $('Webhook').item.json.health_score }}",
  "root_cause": "{{ $json.root_cause_category }}",
  "confidence": "{{ $json.confidence }}",
  "reasoning": "{{ $json.reasoning }}"
}
```

### Step 11: Add HTTP Request - Log Decision (NO Branch)

1. Add **"HTTP Request"** node (NO branch from IF)
2. Configure:
   - **Method**: POST
   - **URL**: Your logging endpoint (or Slack webhook, or database)
   - **Body**: Full analysis data
3. This logs decisions for audit trail

### Step 12: Add Notification Node (Optional)

Add Slack/Email notification:
1. Add **"Slack"** or **"Email"** node
2. Send decision and reasoning to team

### Step 13: Add Respond to Webhook Node

1. Add **"Respond to Webhook"** node
2. Connect from both IF branches
3. Configure response:
```json
{
  "status": "processed",
  "decision": "{{ $json.recommended_action }}",
  "root_cause": "{{ $json.root_cause_category }}",
  "confidence": "{{ $json.confidence }}"
}
```

---

## 🧠 LLM Prompt Engineering Tips

### System Prompt (Recommended)
```
You are an expert infrastructure analyst for a multi-cloud system. Your role is to analyze incidents and determine if they're caused by external infrastructure issues (AWS or Cloudflare) versus internal application bugs.

CRITICAL RULES:
1. Only recommend "trigger_dr" if you have HIGH confidence it's an AWS or Cloudflare infrastructure issue
2. Evidence required for DR trigger:
   - AWS Health API shows open events in the affected region/service
   - Cloudflare Status API shows active incidents
   - Service degradation correlates with external service issues
3. Do NOT recommend DR for:
   - Internal application errors without external service issues
   - Performance degradation without external service confirmation
   - Network issues that could be internal routing problems
4. If uncertain, recommend "investigate" or "monitor"

Your analysis should be thorough but decisive.
```

### User Prompt Structure
Include:
1. **Context**: Health score, alert details
2. **AWS Status**: Events, region health
3. **Cloudflare Status**: Incidents, component status
4. **Internal Data**: Metrics, logs, health checks
5. **Clear Instructions**: What to analyze and format to return

### JSON Response Format
Always request JSON with these fields:
- `root_cause_category`: aws_infrastructure | cloudflare_infrastructure | internal_bug | network | unknown
- `confidence`: high | medium | low
- `evidence`: Brief explanation
- `recommended_action`: trigger_dr | investigate | monitor | wait
- `reasoning`: Detailed explanation

---

## 🧪 Testing Guide

### Test 1: Simulate High Health Score (No External Issues)
1. Manually trigger webhook with:
```json
{
  "health_score": 12,
  "alert_name": "HighHealthScore",
  "severity": "critical"
}
```
2. Mock Cloudflare/AWS responses to show no issues
3. Expected: LLM should recommend "investigate", NOT "trigger_dr"

### Test 2: Simulate AWS Issue
1. Trigger webhook with high health score
2. Mock AWS Health API response with open events
3. Mock Cloudflare with no incidents
4. Expected: LLM should recommend "trigger_dr" with high confidence

### Test 3: Simulate Cloudflare Issue
1. Trigger webhook with high health score
2. Mock Cloudflare incidents API with active incidents
3. Mock AWS with no events
4. Expected: LLM should recommend "trigger_dr" with high confidence

### Test 4: Dry Run DR Trigger
1. Set DRY_RUN=true in Jenkins trigger node
2. Trigger with AWS/Cloudflare issue scenario
3. Verify Jenkins job triggered with correct parameters
4. Verify DR was NOT actually executed

### Test 5: Full End-to-End
1. Use real health check script with actual issues
2. Let workflow gather real context
3. Monitor LLM decision
4. Verify correct action taken

---

## 🔧 Troubleshooting

### LLM Returns Non-JSON Response
- **Fix**: Improve prompt to emphasize "JSON format ONLY"
- **Workaround**: Add JSON extraction logic in parse node

### Script Execution Fails
- **Check**: Python path, script permissions, dependencies
- **Alternative**: Make script an API endpoint using Flask/FastAPI

### Cloudflare/AWS API Timeout
- **Fix**: Add timeout handling in HTTP Request nodes
- **Alternative**: Use fallback to status page scraping

### Jenkins Trigger Fails
- **Check**: Jenkins URL, credentials, job name
- **Verify**: Jenkins API token has build permissions

### Prometheus/Loki Unreachable
- **Check**: Network connectivity, firewall rules
- **Alternative**: Make these optional and use script results only

---

## 📊 Monitoring & Logging

### What to Log
1. Every webhook trigger
2. LLM analysis results
3. Decision made (trigger_dr or not)
4. Confidence level
5. Reasoning

### Where to Log
- **n8n Execution Logs**: Built-in
- **External Logging**: HTTP Request to logging service
- **Database**: Store in PostgreSQL/MongoDB
- **Slack**: Notify team of decisions

---

## 🚀 Production Deployment Checklist

- [ ] Test all scenarios (AWS issue, Cloudflare issue, internal bug)
- [ ] Set up monitoring/alerting for workflow failures
- [ ] Configure proper error handling and retries
- [ ] Set up audit logging
- [ ] Review LLM prompt for accuracy
- [ ] Test DR trigger in dry-run mode
- [ ] Document webhook URL for Prometheus alerts
- [ ] Set up Slack/email notifications
- [ ] Review security (API keys, credentials)
- [ ] Test with real infrastructure issues (staged)

---

## 📚 Additional Resources

- **n8n Documentation**: https://docs.n8n.io/
- **OpenAI API Docs**: https://platform.openai.com/docs
- **Anthropic API Docs**: https://docs.anthropic.com/
- **AWS Health API**: https://docs.aws.amazon.com/health/
- **Cloudflare Status API**: https://www.cloudflarestatus.com/api

---

## 🎓 Learning Path for Building with GPT

When working with GPT to build this:

1. **Start with**: "I need to build an n8n workflow that receives webhooks, gathers data from multiple APIs, sends it to an LLM for analysis, and triggers actions based on the response."

2. **Then specify**: 
   - "Use OpenAI GPT-4 node for LLM analysis"
   - "The workflow should only trigger DR if LLM determines it's an AWS or Cloudflare issue"
   - "Parse JSON response from LLM and make decisions based on recommended_action field"

3. **Iterate**: Test each node individually, then connect them

4. **Refine**: Improve prompts based on test results

---

**Good luck building your intelligent DR decision workflow! 🚀**

