#!/bin/bash
# DR Trigger Script
# One-command manual DR trigger

set -e

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_JOB="${JENKINS_JOB:-CloudPhoenix}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_TOKEN="${JENKINS_TOKEN:-}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

if [ -z "$JENKINS_TOKEN" ]; then
    log "ERROR: JENKINS_TOKEN not set"
    exit 1
fi

log "Triggering DR failover via Jenkins..."

# Trigger Jenkins build with parameters
curl -X POST \
    "${JENKINS_URL}/job/${JENKINS_JOB}/buildWithParameters" \
    --user "${JENKINS_USER}:${JENKINS_TOKEN}" \
    --data "ACTION=dr_failover" \
    --data "DRY_RUN=false"

if [ $? -eq 0 ]; then
    log "DR failover triggered successfully"
    log "Monitor progress at: ${JENKINS_URL}/job/${JENKINS_JOB}"
else
    log "ERROR: Failed to trigger DR failover"
    exit 1
fi

