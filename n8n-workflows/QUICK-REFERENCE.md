# n8n Intelligent DR Workflow - Quick Reference

Quick cheat sheet for building the workflow.

## 📋 Required Nodes Sequence

1. **Webhook** (Trigger) → Receives health score alerts
2. **HTTP Request** → Call `gather_incident_context.py` script
3. **HTTP Request** → Cloudflare Status API
4. **HTTP Request** → Cloudflare Incidents API
5. **HTTP Request** → Prometheus Metrics (optional)
6. **HTTP Request** → Loki Logs (optional)
7. **Code** → Aggregate all data into LLM prompt
8. **OpenAI/Claude** → Send prompt, get analysis
9. **Code** → Parse LLM JSON response
10. **IF** → Check if `recommended_action == "trigger_dr"`
11. **HTTP Request** (YES) → Trigger Jenkins DR
12. **HTTP Request** (NO) → Log decision

## 🔑 Key Endpoints

| Service | Endpoint | Auth |
|---------|----------|------|
| Cloudflare Status | `https://www.cloudflarestatus.com/api/v2/status.json` | None |
| Cloudflare Incidents | `https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json` | None |
| Prometheus Query | `http://prometheus:9090/api/v1/query?query=<promql>` | None |
| Loki Query | `http://loki:3100/loki/api/v1/query_range?query=<logql>` | None |
| Jenkins Trigger | `POST /job/CloudPhoenix/buildWithParameters?ACTION=dr_failover` | Basic Auth |
| Context Script | `python3 scripts/gather_incident_context.py --llm-prompt` | N/A |

## 💡 LLM Prompt Template

```
You are an expert infrastructure analyst. Analyze this incident:

[Insert context data here]

Determine:
1. Root Cause: aws_infrastructure | cloudflare_infrastructure | internal_bug | network | unknown
2. Confidence: high | medium | low
3. Recommended Action: trigger_dr | investigate | monitor | wait

CRITICAL: Only recommend "trigger_dr" if it's AWS or Cloudflare infrastructure issue with HIGH confidence.

Respond in JSON:
{
  "root_cause_category": "...",
  "confidence": "...",
  "evidence": "...",
  "recommended_action": "...",
  "reasoning": "..."
}
```

## ✅ Decision Logic

```
IF recommended_action == "trigger_dr" AND confidence == "high":
    → Trigger Jenkins DR
ELSE:
    → Log decision, notify team
```

## 🧪 Test Scenarios

1. **AWS Issue**: Mock AWS Health API with open events → Should trigger DR
2. **Cloudflare Issue**: Mock Cloudflare with active incidents → Should trigger DR
3. **Internal Bug**: No external issues → Should NOT trigger DR, recommend investigate
4. **Uncertain**: Mixed signals → Should recommend monitor/investigate

## 🔧 Common Issues

- **LLM non-JSON response**: Improve prompt, add JSON extraction
- **Script execution fails**: Check Python path, permissions
- **API timeouts**: Add timeout handling, fallbacks
- **Jenkins trigger fails**: Check credentials, job name

For full guide, see: `INTELLIGENT-DR-SETUP-GUIDE.md`

