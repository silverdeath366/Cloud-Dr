#!/bin/bash
# Test script for n8n Intelligent DR Decision Workflow
# Simulates webhook triggers with different scenarios

set -e

N8N_WEBHOOK_URL="${N8N_WEBHOOK_URL:-http://localhost:5678/webhook/intelligent-dr-check}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

test_scenario() {
    local scenario_name="$1"
    local health_score="$2"
    local description="$3"
    
    log "Testing scenario: $scenario_name"
    log "Description: $description"
    log "Health Score: $health_score"
    
    curl -X POST "$N8N_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"health_score\": $health_score,
            \"alert_name\": \"HighHealthScore\",
            \"severity\": \"critical\",
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"test_scenario\": \"$scenario_name\",
            \"description\": \"$description\"
        }"
    
    echo ""
    log "Response received. Check n8n workflow execution."
    echo ""
    sleep 2
}

main() {
    log "Starting n8n Intelligent DR Workflow Tests"
    log "Webhook URL: $N8N_WEBHOOK_URL"
    echo ""
    
    # Test 1: High health score (should analyze, likely NOT trigger DR if no external issues)
    test_scenario \
        "high_health_score_no_external_issues" \
        12 \
        "High health score with no external infrastructure issues"
    
    # Test 2: Critical health score (should analyze)
    test_scenario \
        "critical_health_score" \
        15 \
        "Critical health score requiring analysis"
    
    # Test 3: Moderate health score (should analyze but likely monitor)
    test_scenario \
        "moderate_health_score" \
        8 \
        "Moderate health score requiring investigation"
    
    log "All test scenarios sent. Check n8n workflow executions."
}

if [ -z "$N8N_WEBHOOK_URL" ]; then
    log "ERROR: N8N_WEBHOOK_URL not set"
    log "Usage: N8N_WEBHOOK_URL=http://your-n8n:port/webhook/intelligent-dr-check ./test-webhook.sh"
    exit 1
fi

main

