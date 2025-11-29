# n8n Intelligent DR Workflow - Advanced Setup Guide for GPT

## 🎯 Goal

Build an n8n workflow that intelligently determines when to trigger DR by:
1. **Accurately gathering** comprehensive incident context
2. **Precisely analyzing** if issues are external infrastructure (AWS/Cloudflare) vs internal bugs
3. **Only triggering DR** when high confidence it's an external infrastructure issue
4. **Preventing false positives** (90%+ accuracy target)

---

## 📋 Prerequisites

Before building, ensure:
- ✅ n8n installed (cloud or self-hosted)
- ✅ OpenAI or Anthropic API key
- ✅ AWS credentials configured (for Health API)
- ✅ Prometheus accessible at `http://prometheus:9090`
- ✅ Loki accessible at `http://loki:3100`
- ✅ Jenkins API token for DR triggering
- ✅ `scripts/gather_incident_context.py` available and executable

---

## 🏗️ Workflow Architecture

```
Webhook (Health Alert)
  ↓
HTTP Request → gather_incident_context.py script
  ↓
HTTP Request → Cloudflare Status API
  ↓
HTTP Request → Cloudflare Incidents API
  ↓
HTTP Request → AWS Status Page (scraping fallback)
  ↓
HTTP Request → Prometheus Metrics
  ↓
HTTP Request → Loki Logs
  ↓
Code Node → Aggregate & Enrich Data
  ↓
Code Node → Build Advanced LLM Prompt
  ↓
OpenAI/Claude Node → LLM Analysis
  ↓
Code Node → Parse & Validate LLM Response
  ↓
IF Node → Decision Logic (with confidence checks)
  ↓
YES → HTTP Request → Trigger Jenkins DR
NO  → HTTP Request → Log Decision (with reasoning)
```

---

## 📝 Step-by-Step Implementation

### STEP 1: Webhook Trigger Node

**Purpose**: Receive health alerts when score > 11

**Configuration**:
1. Add **Webhook** node
2. Set HTTP Method: `POST`
3. Set Path: `/intelligent-dr-check`
4. Response Mode: "Using 'Respond to Webhook' Node"
5. Execute node to get webhook URL

**Expected Input**:
```json
{
  "health_score": 12,
  "alert_name": "HighHealthScore",
  "severity": "critical",
  "timestamp": "2024-01-01T12:00:00Z",
  "signals": {
    "internal_service_a": {"status": "unhealthy", "weight": 5},
    "internal_service_b": {"status": "degraded", "weight": 2}
  }
}
```

**n8n Configuration**:
- Method: POST
- Path: intelligent-dr-check
- Response: Last Node
- Options: Raw Body (JSON)

---

### STEP 2: Context Gathering - Python Script Execution

**Purpose**: Run `gather_incident_context.py` to collect comprehensive context

**Option A: Execute Command Node** (If script on same server)

**Configuration**:
1. Add **Execute Command** node
2. Command: `python3`
3. Arguments: `/path/to/cloudphoenix/scripts/gather_incident_context.py`
4. Additional Arguments: `--llm-prompt`

**Option B: HTTP Request** (If script exposed as API)

Create a simple Flask API wrapper:

```python
# api_wrapper.py
from flask import Flask, request, jsonify
import subprocess
import sys
import os

app = Flask(__name__)

@app.route('/gather-context', methods=['POST'])
def gather_context():
    script_path = os.path.join(os.path.dirname(__file__), 
                               'scripts/gather_incident_context.py')
    result = subprocess.run(
        [sys.executable, script_path, '--llm-prompt'],
        capture_output=True,
        text=True,
        timeout=60
    )
    
    if result.returncode == 0:
        return jsonify({'status': 'success', 'output': result.stdout})
    else:
        return jsonify({'status': 'error', 'error': result.stderr}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

Then use HTTP Request node:
- Method: POST
- URL: `http://your-api:5000/gather-context`
- Body: JSON with health_score from webhook

**Option C: Code Node** (Inline execution)

Use n8n Code node with JavaScript to call the script or use Python execution if available.

**Expected Output**:
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "aws_status": {
    "has_open_issues": true,
    "open_event_count": 2,
    "recent_events": [...],
    "region_health": {...}
  },
  "cloudflare_status": {...},
  "health_check_results": {...},
  "internal_metrics": {...},
  "recent_logs": [...],
  "error_patterns": [...]
}
```

---

### STEP 3: Cloudflare Status Check

**Purpose**: Check Cloudflare service health via public API

**HTTP Request Node Configuration**:

**Node 3a: Cloudflare Overall Status**
- Method: GET
- URL: `https://www.cloudflarestatus.com/api/v2/status.json`
- Authentication: None
- Options:
  - Timeout: 10000ms
  - Response Format: JSON

**Expected Response**:
```json
{
  "status": {
    "indicator": "operational" | "major_outage" | "partial_outage",
    "description": "..."
  }
}
```

**Node 3b: Cloudflare Active Incidents**
- Method: GET
- URL: `https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json`
- Authentication: None
- Options:
  - Timeout: 10000ms
  - Response Format: JSON

**Expected Response**:
```json
{
  "incidents": [
    {
      "id": "...",
      "name": "Cloudflare Incident",
      "status": "investigating" | "identified" | "monitoring",
      "impact": "minor" | "major" | "critical",
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z"
    }
  ]
}
```

**Node 3c: Cloudflare Components** (Optional but recommended)
- Method: GET
- URL: `https://www.cloudflarestatus.com/api/v2/components.json`
- Filter for non-operational components in Code node

---

### STEP 4: AWS Status Check (Enhanced)

**Purpose**: Check AWS service health with multiple fallback methods

**Method 1: AWS Health API** (If you have AWS Support access)

**HTTP Request Node** (via AWS Signature):
- Method: POST
- URL: `https://health.us-east-1.amazonaws.com/`
- Authentication: AWS Signature V4
- Body: JSON
```json
{
  "filter": {
    "startTimes": [
      {
        "from": "2024-01-01T10:00:00Z",
        "to": "2024-01-01T12:00:00Z"
      }
    ]
  },
  "maxResults": 10
}
```

**Method 2: AWS Status Page Scraping** (Fallback)

**Code Node** to scrape AWS status page:

```javascript
// Scrape AWS status page for service issues
const axios = require('axios');
const cheerio = require('cheerio');

const awsStatusUrls = [
  'https://status.aws.amazon.com/',
  'https://health.aws.amazon.com/health/status'
];

let awsIssues = [];

for (const url of awsStatusUrls) {
  try {
    const response = await axios.get(url, { timeout: 10000 });
    const $ = cheerio.load(response.data);
    
    // Parse status page (adjust selectors based on AWS HTML structure)
    $('.status-item').each((i, elem) => {
      const service = $(elem).find('.service-name').text();
      const status = $(elem).find('.status').text();
      const region = $(elem).find('.region').text();
      
      if (status.toLowerCase().includes('issue') || 
          status.toLowerCase().includes('degraded') ||
          status.toLowerCase().includes('down')) {
        awsIssues.push({
          service: service.trim(),
          status: status.trim(),
          region: region.trim(),
          source: 'status_page',
          timestamp: new Date().toISOString()
        });
      }
    });
  } catch (error) {
    console.error(`Failed to scrape ${url}:`, error.message);
  }
}

return {
  json: {
    aws_status_page_issues: awsIssues,
    has_issues: awsIssues.length > 0,
    sources_checked: awsStatusUrls.length
  }
};
```

**Method 3: AWS Service Health via boto3** (If script has access)

The `gather_incident_context.py` script already does this, but you can enhance it.

---

### STEP 5: Prometheus Metrics Query

**Purpose**: Gather real-time metrics for LLM analysis

**HTTP Request Node Configuration**:

**Node 5a: Error Rate**
- Method: GET
- URL: `http://prometheus:9090/api/v1/query`
- Query Parameters:
  - `query`: `rate(http_requests_total{status=~"5.."}[5m])`
  - `time`: Current timestamp (optional)
- Options:
  - Timeout: 5000ms
  - Response Format: JSON

**Node 5b: Latency (P95)**
- Method: GET
- URL: `http://prometheus:9090/api/v1/query`
- Query Parameters:
  - `query`: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`

**Node 5c: Service Availability**
- Method: GET
- URL: `http://prometheus:9090/api/v1/query`
- Query Parameters:
  - `query`: `avg_over_time(up{job=~"service-.*"}[5m])`

**Node 5d: Health Score Metric** (If exposed)
- Method: GET
- URL: `http://prometheus:9090/api/v1/query`
- Query Parameters:
  - `query`: `cloudphoenix_health_score`

**Expected Response Format**:
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {"job": "service-a"},
        "value": [1704110400, "0.05"]
      }
    ]
  }
}
```

**Code Node to Parse Prometheus Response**:
```javascript
const prometheusData = $input.all();

const metrics = {
  error_rate: null,
  latency_p95: null,
  availability: null,
  health_score: null
};

prometheusData.forEach(node => {
  const data = node.json;
  if (data.status === 'success' && data.data?.result?.length > 0) {
    const query = node.headers?.query || '';
    const value = parseFloat(data.data.result[0].value[1]);
    
    if (query.includes('error')) {
      metrics.error_rate = value;
    } else if (query.includes('latency') || query.includes('duration')) {
      metrics.latency_p95 = value;
    } else if (query.includes('availability') || query.includes('up')) {
      metrics.availability = value;
    } else if (query.includes('health_score')) {
      metrics.health_score = value;
    }
  }
});

return { json: { prometheus_metrics: metrics } };
```

---

### STEP 6: Loki Logs Query

**Purpose**: Gather recent error logs for pattern analysis

**HTTP Request Node Configuration**:

**Node 6a: Recent Error Logs**
- Method: GET
- URL: `http://loki:3100/loki/api/v1/query_range`
- Query Parameters:
  - `query`: `{job=~".+"} |= "error" |= "ERROR" |= "exception" |= "timeout"`
  - `start`: `(Current timestamp - 1 hour) * 1e9` (nanoseconds)
  - `end`: `Current timestamp * 1e9`
  - `limit`: `100`
- Options:
  - Timeout: 10000ms
  - Response Format: JSON

**Node 6b: AWS-Related Errors** (Pattern matching)
- Method: GET
- URL: `http://loki:3100/loki/api/v1/query_range`
- Query Parameters:
  - `query`: `{job=~".+"} |~ "aws|ec2|rds|s3|cloudformation" |= "error"`
  - `start`: `(Current timestamp - 1 hour) * 1e9`
  - `end`: `Current timestamp * 1e9`
  - `limit`: `50`

**Node 6c: Cloudflare-Related Errors**
- Method: GET
- URL: `http://loki:3100/loki/api/v1/query_range`
- Query Parameters:
  - `query`: `{job=~".+"} |~ "cloudflare|cdn|ddos" |= "error"`

**Expected Response Format**:
```json
{
  "status": "success",
  "data": {
    "resultType": "streams",
    "result": [
      {
        "stream": {"job": "service-a"},
        "values": [
          ["1704110400000000000", "ERROR: Connection timeout to RDS"],
          ["1704110460000000000", "ERROR: EC2 instance unreachable"]
        ]
      }
    ]
  }
}
```

**Code Node to Parse Loki Response**:
```javascript
const lokiData = $input.all();
const errorLogs = [];

lokiData.forEach(node => {
  const data = node.json;
  if (data.status === 'success' && data.data?.result) {
    data.data.result.forEach(stream => {
      stream.values.forEach(([timestamp, message]) => {
        errorLogs.push({
          timestamp: new Date(parseInt(timestamp) / 1000000).toISOString(),
          message: message.substring(0, 500), // Truncate long messages
          source: stream.stream.job || 'unknown'
        });
      });
    });
  }
});

// Analyze error patterns
const awsErrorCount = errorLogs.filter(log => 
  /aws|ec2|rds|s3|cloudformation/i.test(log.message)
).length;

const cloudflareErrorCount = errorLogs.filter(log => 
  /cloudflare|cdn|ddos/i.test(log.message)
).length;

const timeoutErrorCount = errorLogs.filter(log => 
  /timeout|timed out|connection/i.test(log.message)
).length;

return {
  json: {
    error_logs: errorLogs.slice(0, 20), // Limit for LLM prompt
    error_analysis: {
      total_errors: errorLogs.length,
      aws_related: awsErrorCount,
      cloudflare_related: cloudflareErrorCount,
      timeout_errors: timeoutErrorCount,
      error_rate_per_minute: errorLogs.length / 60
    }
  }
};
```

---

### STEP 7: Data Aggregation & Enrichment

**Purpose**: Combine all data sources and enrich with analysis

**Code Node - Advanced Aggregation**:

```javascript
// Get all inputs
const webhookData = $input.item(0).json; // From webhook
const contextData = $input.item(1).json; // From gather_incident_context.py
const cloudflareStatus = $input.item(2).json; // From Cloudflare status API
const cloudflareIncidents = $input.item(3).json; // From Cloudflare incidents API
const cloudflareComponents = $input.item(4).json; // From Cloudflare components API
const awsStatus = $input.item(5).json; // From AWS status check
const prometheusMetrics = $input.item(6).json; // From Prometheus queries
const lokiLogs = $input.item(7).json; // From Loki queries

// Enrich data with correlation analysis
const now = new Date();

// Correlate AWS Health API events with error logs
const awsEvents = contextData.aws_status?.recent_events || [];
const awsRelatedErrors = lokiLogs.error_analysis?.aws_related || 0;
const awsEventsCorrelation = awsEvents.length > 0 && awsRelatedErrors > 0;

// Correlate Cloudflare incidents with timeout errors
const cloudflareActiveIncidents = cloudflareIncidents.incidents?.filter(
  inc => inc.status !== 'resolved'
) || [];
const timeoutErrors = lokiLogs.error_analysis?.timeout_errors || 0;
const cloudflareCorrelation = cloudflareActiveIncidents.length > 0 && timeoutErrors > 0;

// Analyze health score trend (if we have historical data)
const healthScore = webhookData.health_score;
const prometheusHealthScore = prometheusMetrics.prometheus_metrics?.health_score;

// Calculate severity indicators
const severityIndicators = {
  aws_infrastructure: {
    weight: 0,
    evidence: []
  },
  cloudflare_infrastructure: {
    weight: 0,
    evidence: []
  },
  internal_bug: {
    weight: 0,
    evidence: []
  },
  network: {
    weight: 0,
    evidence: []
  }
};

// AWS Infrastructure Evidence
if (contextData.aws_status?.has_open_issues) {
  severityIndicators.aws_infrastructure.weight += 10;
  severityIndicators.aws_infrastructure.evidence.push(
    `AWS Health API shows ${contextData.aws_status.open_event_count} open events`
  );
}
if (awsEventsCorrelation) {
  severityIndicators.aws_infrastructure.weight += 5;
  severityIndicators.aws_infrastructure.evidence.push(
    `AWS events correlate with ${awsRelatedErrors} AWS-related error logs`
  );
}
if (awsStatus?.aws_status_page_issues?.length > 0) {
  severityIndicators.aws_infrastructure.weight += 5;
  severityIndicators.aws_infrastructure.evidence.push(
    `AWS status page shows ${awsStatus.aws_status_page_issues.length} service issues`
  );
}

// Cloudflare Infrastructure Evidence
if (cloudflareStatus?.status?.indicator !== 'operational') {
  severityIndicators.cloudflare_infrastructure.weight += 10;
  severityIndicators.cloudflare_infrastructure.evidence.push(
    `Cloudflare status: ${cloudflareStatus.status.indicator}`
  );
}
if (cloudflareActiveIncidents.length > 0) {
  severityIndicators.cloudflare_infrastructure.weight += 8;
  severityIndicators.cloudflare_infrastructure.evidence.push(
    `${cloudflareActiveIncidents.length} active Cloudflare incidents`
  );
}
if (cloudflareCorrelation) {
  severityIndicators.cloudflare_infrastructure.weight += 5;
  severityIndicators.cloudflare_infrastructure.evidence.push(
    `Cloudflare incidents correlate with ${timeoutErrors} timeout errors`
  );
}

// Internal Bug Evidence (negative indicators)
if (!contextData.aws_status?.has_open_issues && 
    cloudflareStatus?.status?.indicator === 'operational' &&
    cloudflareActiveIncidents.length === 0) {
  severityIndicators.internal_bug.weight += 15;
  severityIndicators.internal_bug.evidence.push(
    'No external infrastructure issues detected, but health score is high'
  );
}
if (prometheusMetrics.prometheus_metrics?.error_rate > 0.1) {
  severityIndicators.internal_bug.weight += 5;
  severityIndicators.internal_bug.evidence.push(
    `High error rate (${prometheusMetrics.prometheus_metrics.error_rate}) without external issues`
  );
}

// Network Evidence
if (timeoutErrors > 10 && !awsEventsCorrelation && !cloudflareCorrelation) {
  severityIndicators.network.weight += 8;
  severityIndicators.network.evidence.push(
    `${timeoutErrors} timeout errors without AWS/Cloudflare correlation`
  );
}

// Determine primary root cause category
const rootCauseWeights = Object.entries(severityIndicators).map(([category, data]) => ({
  category,
  weight: data.weight,
  evidence: data.evidence
})).sort((a, b) => b.weight - a.weight);

const primaryRootCause = rootCauseWeights[0];

// Build comprehensive context for LLM
const enrichedContext = {
  timestamp: new Date().toISOString(),
  health_score: healthScore,
  health_score_source: webhookData.signals || {},
  
  external_status: {
    aws: {
      has_open_issues: contextData.aws_status?.has_open_issues || false,
      open_event_count: contextData.aws_status?.open_event_count || 0,
      events: awsEvents,
      status_page_issues: awsStatus?.aws_status_page_issues || [],
      region_health: contextData.aws_status?.region_health || {}
    },
    cloudflare: {
      overall_status: cloudflareStatus?.status?.indicator || 'unknown',
      active_incidents: cloudflareActiveIncidents,
      non_operational_components: cloudflareComponents?.components?.filter(
        c => c.status !== 'operational'
      ) || []
    }
  },
  
  internal_metrics: {
    error_rate: prometheusMetrics.prometheus_metrics?.error_rate,
    latency_p95: prometheusMetrics.prometheus_metrics?.latency_p95,
    availability: prometheusMetrics.prometheus_metrics?.availability,
    health_score_from_prometheus: prometheusHealthScore
  },
  
  error_logs: {
    recent_errors: lokiLogs.error_logs?.slice(0, 15) || [],
    analysis: lokiLogs.error_analysis || {}
  },
  
  correlation_analysis: {
    aws_events_with_errors: awsEventsCorrelation,
    cloudflare_incidents_with_timeouts: cloudflareCorrelation,
    aws_related_error_count: awsRelatedErrors,
    cloudflare_timeout_count: timeoutErrors
  },
  
  severity_indicators: severityIndicators,
  primary_root_cause_suggestion: primaryRootCause,
  
  health_check_details: contextData.health_check_results || {}
};

return {
  json: enrichedContext
};
```

---

### STEP 8: Advanced LLM Prompt Construction

**Purpose**: Build a highly accurate prompt for LLM analysis

**Code Node - Prompt Builder**:

```javascript
const enrichedContext = $input.item().json;

// Build sophisticated prompt with structured reasoning
const prompt = `# Critical Infrastructure Incident Analysis

## Incident Overview
- **Timestamp**: ${enrichedContext.timestamp}
- **Health Score**: ${enrichedContext.health_score} (threshold: 11+)
- **Primary Root Cause Suggestion** (from automated analysis): ${enrichedContext.primary_root_cause_suggestion.category} (confidence weight: ${enrichedContext.primary_root_cause_suggestion.weight})

## External Infrastructure Status

### AWS Infrastructure
- **Health API Status**: ${enrichedContext.external_status.aws.has_open_issues ? '⚠️ OPEN ISSUES DETECTED' : '✅ No open issues'}
- **Open Event Count**: ${enrichedContext.external_status.aws.open_event_count}
- **Recent Events**: ${JSON.stringify(enrichedContext.external_status.aws.events.slice(0, 5), null, 2)}
- **Status Page Issues**: ${enrichedContext.external_status.aws.status_page_issues.length} issues found
- **Region Health**: ${JSON.stringify(enrichedContext.external_status.aws.region_health, null, 2)}

### Cloudflare Infrastructure
- **Overall Status**: ${enrichedContext.external_status.cloudflare.overall_status.toUpperCase()}
- **Active Incidents**: ${enrichedContext.external_status.cloudflare.active_incidents.length}
${enrichedContext.external_status.cloudflare.active_incidents.length > 0 ? 
  `- **Incident Details**: ${JSON.stringify(enrichedContext.external_status.cloudflare.active_incidents, null, 2)}` 
  : ''}
- **Non-Operational Components**: ${enrichedContext.external_status.cloudflare.non_operational_components.length}

## Internal System Metrics

### Error Metrics (Last 5 minutes)
- **Error Rate**: ${enrichedContext.internal_metrics.error_rate || 'N/A'} errors/second
- **P95 Latency**: ${enrichedContext.internal_metrics.latency_p95 || 'N/A'} seconds
- **Service Availability**: ${enrichedContext.internal_metrics.availability || 'N/A'}%

### Recent Error Logs (Sample)
${JSON.stringify(enrichedContext.error_logs.recent_errors.slice(0, 10), null, 2)}

### Error Pattern Analysis
- **Total Errors** (last hour): ${enrichedContext.error_logs.analysis.total_errors || 0}
- **AWS-Related Errors**: ${enrichedContext.error_logs.analysis.aws_related || 0}
- **Cloudflare-Related Errors**: ${enrichedContext.error_logs.analysis.cloudflare_related || 0}
- **Timeout Errors**: ${enrichedContext.error_logs.analysis.timeout_errors || 0}

## Correlation Analysis

### Key Correlations
- **AWS Events + AWS Errors**: ${enrichedContext.correlation_analysis.aws_events_with_errors ? '✅ CORRELATED' : '❌ Not correlated'}
  - AWS-related error count: ${enrichedContext.correlation_analysis.aws_related_error_count}
- **Cloudflare Incidents + Timeouts**: ${enrichedContext.correlation_analysis.cloudflare_incidents_with_timeouts ? '✅ CORRELATED' : '❌ Not correlated'}
  - Timeout error count: ${enrichedContext.correlation_analysis.cloudflare_timeout_count}

### Severity Indicators (Automated Weight Analysis)

#### AWS Infrastructure Issues
**Weight**: ${enrichedContext.severity_indicators.aws_infrastructure.weight}
**Evidence**:
${enrichedContext.severity_indicators.aws_infrastructure.evidence.map(e => `- ${e}`).join('\n') || '- None'}

#### Cloudflare Infrastructure Issues
**Weight**: ${enrichedContext.severity_indicators.cloudflare_infrastructure.weight}
**Evidence**:
${enrichedContext.severity_indicators.cloudflare_infrastructure.evidence.map(e => `- ${e}`).join('\n') || '- None'}

#### Internal Bug Indicators
**Weight**: ${enrichedContext.severity_indicators.internal_bug.weight}
**Evidence**:
${enrichedContext.severity_indicators.internal_bug.evidence.map(e => `- ${e}`).join('\n') || '- None'}

#### Network Issues
**Weight**: ${enrichedContext.severity_indicators.network.weight}
**Evidence**:
${enrichedContext.severity_indicators.network.evidence.map(e => `- ${e}`).join('\n') || '- None'}

## Health Check Signal Details
${JSON.stringify(enrichedContext.health_check_details, null, 2)}

---

## Your Analysis Task

You are an expert infrastructure analyst with deep knowledge of AWS, Cloudflare, and distributed systems. Your task is to analyze this incident and determine the root cause with HIGH accuracy.

### Critical Decision Rules

1. **DR Trigger Criteria** (ALL must be true):
   - Root cause is "aws_infrastructure" OR "cloudflare_infrastructure"
   - Confidence is "high"
   - External infrastructure issues are confirmed (via APIs or status pages)
   - Health score degradation correlates with external issues

2. **DO NOT Trigger DR If**:
   - No AWS Health API events AND no Cloudflare incidents
   - Error logs show application-level bugs without external correlation
   - Primary root cause suggestion is "internal_bug" with high weight
   - Low confidence due to ambiguous signals

3. **Evidence Quality Requirements**:
   - High confidence requires: API confirmation (AWS Health/Cloudflare) OR strong correlation (external events + matching error patterns)
   - Medium confidence: Some external indicators but not fully confirmed
   - Low confidence: Ambiguous or conflicting signals

### Analysis Steps

1. **Review External Infrastructure Status**:
   - AWS: Are there open Health API events? Status page issues? Which services/regions?
   - Cloudflare: Are there active incidents? Non-operational components?
   - Do these correlate with the health score degradation timing?

2. **Review Internal Metrics & Logs**:
   - What types of errors are occurring? (AWS-related, Cloudflare-related, application-level)
   - Do error patterns match external issues?
   - Is error rate spike correlated with external events?

3. **Cross-Correlate Signals**:
   - If AWS events exist, do AWS-related errors in logs increase?
   - If Cloudflare incidents exist, do timeout errors increase?
   - If no external issues, but high error rate → likely internal bug

4. **Make Decision**:
   - Determine root cause category with confidence
   - Recommend action based on decision rules above
   - Provide clear reasoning

### Response Format

Respond with ONLY valid JSON (no markdown, no explanation outside JSON):

{
  "root_cause_category": "aws_infrastructure" | "cloudflare_infrastructure" | "internal_bug" | "network" | "unknown",
  "confidence": "high" | "medium" | "low",
  "evidence": "Brief summary of key evidence (2-3 sentences)",
  "recommended_action": "trigger_dr" | "investigate" | "monitor" | "wait",
  "reasoning": "Detailed explanation (3-4 sentences) of how you reached this conclusion, including correlation analysis",
  "key_indicators": {
    "aws_events_confirmed": boolean,
    "cloudflare_incidents_confirmed": boolean,
    "correlation_with_errors": boolean,
    "external_issues_confirmed": boolean
  },
  "risk_assessment": {
    "false_positive_risk": "low" | "medium" | "high",
    "impact_if_wrong": "low" | "medium" | "high"
  }
}`;

return {
  json: {
    prompt: prompt,
    enriched_context: enrichedContext
  }
};
```

---

### STEP 9: LLM API Call

**Purpose**: Send prompt to LLM for analysis

**Option A: OpenAI Node** (if available)

**Configuration**:
- Operation: Chat
- Model: `gpt-4` or `gpt-4-turbo-preview` (use best available)
- Messages:
  - System: 
```text
You are an expert infrastructure analyst specializing in AWS, Cloudflare, and distributed systems. You analyze incidents to determine root causes with high accuracy. You are conservative - only recommend DR triggers when you have HIGH confidence based on external infrastructure confirmation. You distinguish between external infrastructure failures and internal application bugs.
```
  - User: `{{ $json.prompt }}`
- Temperature: `0.1` (very low for deterministic responses)
- Max Tokens: `1500`
- Response Format: JSON Object (if supported)

**Option B: HTTP Request to OpenAI**

**Configuration**:
- Method: POST
- URL: `https://api.openai.com/v1/chat/completions`
- Authentication: Header Auth
  - Name: `Authorization`
  - Value: `Bearer YOUR_OPENAI_API_KEY`
- Headers:
  - `Content-Type`: `application/json`
- Body (JSON):
```json
{
  "model": "gpt-4",
  "temperature": 0.1,
  "max_tokens": 1500,
  "response_format": { "type": "json_object" },
  "messages": [
    {
      "role": "system",
      "content": "You are an expert infrastructure analyst..."
    },
    {
      "role": "user",
      "content": "{{ $json.prompt }}"
    }
  ]
}
```

**Option C: Anthropic Claude**

**Configuration**:
- Method: POST
- URL: `https://api.anthropic.com/v1/messages`
- Authentication: Header Auth
  - Name: `x-api-key`
  - Value: `YOUR_ANTHROPIC_API_KEY`
- Headers:
  - `anthropic-version`: `2023-06-01`
  - `Content-Type`: `application/json`
- Body (JSON):
```json
{
  "model": "claude-3-opus-20240229",
  "max_tokens": 1500,
  "temperature": 0.1,
  "system": "You are an expert infrastructure analyst...",
  "messages": [
    {
      "role": "user",
      "content": "{{ $json.prompt }}"
    }
  ]
}
```

---

### STEP 10: Parse & Validate LLM Response

**Purpose**: Extract and validate LLM response

**Code Node - Advanced Parsing**:

```javascript
const llmResponse = $input.item().json;
const enrichedContext = $('Prompt Builder').item().json.enriched_context;

// Extract content based on API format
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

// Clean and parse JSON
let jsonStr = content.trim();

// Remove markdown code blocks
jsonStr = jsonStr.replace(/```json\n?/g, '').replace(/```\n?/g, '');

// Try to extract JSON if wrapped in text
const jsonMatch = jsonStr.match(/\{[\s\S]*\}/);
if (jsonMatch) {
  jsonStr = jsonMatch[0];
}

let analysis;
try {
  analysis = JSON.parse(jsonStr);
} catch (error) {
  // Fallback: return error with raw content
  return {
    json: {
      parse_error: true,
      error_message: error.message,
      raw_response: content.substring(0, 500),
      root_cause_category: 'unknown',
      confidence: 'low',
      evidence: 'Failed to parse LLM response',
      recommended_action: 'investigate',
      reasoning: `LLM response parsing failed: ${error.message}`,
      key_indicators: {},
      risk_assessment: {
        false_positive_risk: 'high',
        impact_if_wrong: 'high'
      }
    }
  };
}

// Validate required fields
const requiredFields = ['root_cause_category', 'confidence', 'evidence', 'recommended_action', 'reasoning'];
const missingFields = requiredFields.filter(field => !analysis[field]);

if (missingFields.length > 0) {
  analysis.parse_warning = `Missing fields: ${missingFields.join(', ')}`;
}

// Validate values
const validCategories = ['aws_infrastructure', 'cloudflare_infrastructure', 'internal_bug', 'network', 'unknown'];
const validConfidence = ['high', 'medium', 'low'];
const validActions = ['trigger_dr', 'investigate', 'monitor', 'wait'];

if (!validCategories.includes(analysis.root_cause_category)) {
  analysis.root_cause_category = 'unknown';
  analysis.validation_warning = 'Invalid root_cause_category';
}

if (!validConfidence.includes(analysis.confidence)) {
  analysis.confidence = 'low';
  analysis.validation_warning = 'Invalid confidence level';
}

if (!validActions.includes(analysis.recommended_action)) {
  analysis.recommended_action = 'investigate';
  analysis.validation_warning = 'Invalid recommended_action';
}

// Add metadata
analysis.timestamp = new Date().toISOString();
analysis.enriched_context_summary = {
  health_score: enrichedContext.health_score,
  aws_has_issues: enrichedContext.external_status.aws.has_open_issues,
  cloudflare_has_incidents: enrichedContext.external_status.cloudflare.active_incidents.length > 0,
  primary_suggestion: enrichedContext.primary_root_cause_suggestion.category
};

// Calculate decision confidence score (0-100)
let decisionScore = 0;
if (analysis.confidence === 'high') decisionScore += 50;
if (analysis.confidence === 'medium') decisionScore += 30;
if (analysis.confidence === 'low') decisionScore += 10;

if (analysis.key_indicators?.external_issues_confirmed) decisionScore += 20;
if (analysis.key_indicators?.correlation_with_errors) decisionScore += 20;
if (analysis.root_cause_category === enrichedContext.primary_root_cause_suggestion.category) decisionScore += 10;

analysis.decision_confidence_score = Math.min(decisionScore, 100);

return {
  json: analysis
};
```

---

### STEP 11: Decision Logic with Advanced Checks

**Purpose**: Make final decision with multiple validation layers

**IF Node Configuration**:

**Condition 1**: Recommended Action Check
```
{{ $json.recommended_action }} equals trigger_dr
```

**Condition 2**: Confidence Check (AND)
```
{{ $json.confidence }} equals high
```

**Condition 3**: Root Cause Check (AND)
```
{{ $json.root_cause_category }} is one of: aws_infrastructure, cloudflare_infrastructure
```

**Condition 4**: Key Indicators Check (AND)
```
{{ $json.key_indicators.external_issues_confirmed }} equals true
```

**Condition 5**: Decision Score Check (AND)
```
{{ $json.decision_confidence_score }} is greater than 70
```

**All conditions must be true to trigger DR**

---

### STEP 12: Trigger DR (YES Branch)

**Purpose**: Trigger Jenkins DR pipeline

**HTTP Request Node**:

**Configuration**:
- Method: POST
- URL: `http://jenkins:8080/job/CloudPhoenix/buildWithParameters`
- Authentication: Basic Auth
  - User: `YOUR_JENKINS_USERNAME`
  - Password: `YOUR_JENKINS_API_TOKEN`
- Query Parameters:
  - `ACTION`: `dr_failover`
  - `DRY_RUN`: `false` (or `true` for testing)
- Body (JSON):
```json
{
  "triggered_by": "n8n_intelligent_workflow",
  "trigger_timestamp": "{{ $json.timestamp }}",
  "health_score": "{{ $('Webhook').item.json.health_score }}",
  "llm_analysis": {
    "root_cause": "{{ $json.root_cause_category }}",
    "confidence": "{{ $json.confidence }}",
    "evidence": "{{ $json.evidence }}",
    "reasoning": "{{ $json.reasoning }}",
    "decision_score": "{{ $json.decision_confidence_score }}"
  },
  "context_summary": {
    "aws_has_issues": "{{ $json.enriched_context_summary.aws_has_issues }}",
    "cloudflare_has_incidents": "{{ $json.enriched_context_summary.cloudflare_has_incidents }}"
  }
}
```

**Options**:
- Timeout: 30000ms
- Retry: 2 times
- Response Format: JSON

---

### STEP 13: Log Decision (NO Branch)

**Purpose**: Log decision for audit trail

**HTTP Request Node** (to logging endpoint) or **Code Node** (to save locally):

**Option A: HTTP to Logging Service**
- Method: POST
- URL: Your logging endpoint
- Body: Full analysis data

**Option B: Code Node to Save File**
```javascript
const fs = require('fs');
const analysis = $input.item().json;
const timestamp = new Date().toISOString().replace(/:/g, '-');

const logEntry = {
  timestamp: new Date().toISOString(),
  decision: analysis.recommended_action,
  root_cause: analysis.root_cause_category,
  confidence: analysis.confidence,
  decision_score: analysis.decision_confidence_score,
  reasoning: analysis.reasoning,
  full_analysis: analysis
};

// Save to file (adjust path as needed)
const logPath = `/tmp/dr-decisions/${timestamp}.json`;
fs.mkdirSync('/tmp/dr-decisions', { recursive: true });
fs.writeFileSync(logPath, JSON.stringify(logEntry, null, 2));

return { json: { logged: true, path: logPath } };
```

---

### STEP 14: Notification (Optional)

**Purpose**: Notify team of decision

**Slack Node** or **Email Node**:

**Slack Configuration**:
- Channel: `#incidents` or `#dr-alerts`
- Text: 
```
🚨 DR Decision: {{ $json.recommended_action === 'trigger_dr' ? 'TRIGGERED' : 'NOT TRIGGERED' }}

Root Cause: {{ $json.root_cause_category }}
Confidence: {{ $json.confidence }} (Score: {{ $json.decision_confidence_score }})
Health Score: {{ $('Webhook').item.json.health_score }}

Evidence: {{ $json.evidence }}

Reasoning: {{ $json.reasoning }}
```

---

### STEP 15: Respond to Webhook

**Purpose**: Return response to caller

**Respond to Webhook Node**:

**Configuration**:
- Response Body (JSON):
```json
{
  "status": "processed",
  "timestamp": "{{ $json.timestamp }}",
  "decision": {
    "action": "{{ $json.recommended_action }}",
    "root_cause": "{{ $json.root_cause_category }}",
    "confidence": "{{ $json.confidence }}",
    "decision_score": {{ $json.decision_confidence_score }},
    "dr_triggered": {{ $json.recommended_action === 'trigger_dr' && $json.confidence === 'high' ? 'true' : 'false' }}
  },
  "summary": {
    "evidence": "{{ $json.evidence }}",
    "key_indicators": {{ JSON.stringify($json.key_indicators) }}
  }
}
```

---

## 🎯 Accuracy Improvements

### 1. Multi-Source Verification
- ✅ AWS Health API (primary)
- ✅ AWS Status Page scraping (fallback)
- ✅ Cloudflare Status API
- ✅ Cloudflare Components API
- ✅ Prometheus metrics
- ✅ Loki logs

### 2. Correlation Analysis
- ✅ AWS events + AWS-related errors
- ✅ Cloudflare incidents + timeout errors
- ✅ Timing correlation (events vs. health score)

### 3. Weighted Evidence System
- ✅ Automated severity indicators
- ✅ Evidence accumulation
- ✅ Primary root cause suggestion

### 4. Multi-Layer Decision Logic
- ✅ LLM analysis
- ✅ Automated correlation checks
- ✅ Decision confidence scoring
- ✅ Multiple IF conditions

### 5. Conservative Approach
- ✅ Requires high confidence
- ✅ Requires external issue confirmation
- ✅ Requires correlation with errors
- ✅ High decision score threshold (70+)

---

## 🧪 Testing the Workflow

### Test Case 1: AWS Infrastructure Issue
**Mock Data**:
- Health score: 12
- AWS Health API: 2 open events
- AWS-related errors in logs: 15
- Cloudflare: operational

**Expected**: Trigger DR with high confidence

### Test Case 2: Internal Bug
**Mock Data**:
- Health score: 12
- AWS Health API: no events
- Cloudflare: operational
- Application errors in logs: 20 (no AWS/CF correlation)

**Expected**: Don't trigger DR, recommend investigate

### Test Case 3: Cloudflare Issue
**Mock Data**:
- Health score: 11
- Cloudflare: 1 active incident
- Timeout errors: 12
- AWS: no issues

**Expected**: Trigger DR with high confidence

### Test Case 4: Ambiguous (Low Confidence)
**Mock Data**:
- Health score: 11
- AWS: 1 event (minor)
- Cloudflare: operational
- Error pattern: mixed

**Expected**: Don't trigger DR, recommend monitor

---

## 📊 Monitoring & Metrics

Track these metrics:
- Decision accuracy (over time)
- False positive rate
- False negative rate
- LLM response time
- Decision confidence scores distribution
- Root cause category distribution

---

## 🚀 Production Deployment Checklist

- [ ] Test all 4 test cases above
- [ ] Verify all API endpoints accessible
- [ ] Set up error handling for API failures
- [ ] Configure timeouts appropriately
- [ ] Set up monitoring/alerting
- [ ] Document webhook URL for health checks
- [ ] Review LLM prompt for accuracy
- [ ] Set up audit logging
- [ ] Test with DRY_RUN=true first
- [ ] Review security (API keys, credentials)

---

## 💡 Pro Tips for GPT

When building this with GPT:
1. Start with one node at a time
2. Test each node independently
3. Use Execute Node to verify outputs
4. Add error handling gradually
5. Test with mock data first
6. Validate LLM responses before production
7. Monitor decision accuracy and adjust prompts

---

**This guide provides everything needed to build an accurate, impressive n8n workflow!** 🚀

