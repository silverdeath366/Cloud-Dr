#!/bin/bash
# Rollback Script
# Rolls back from DR to primary AWS

set -e

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting rollback to AWS primary"

# Switch DNS back to AWS
log "Switching DNS to AWS ALB..."
./scripts/switch_dns.sh --target aws

# Wait for DNS propagation
log "Waiting for DNS propagation..."
sleep 60

# Verify services on AWS
log "Verifying services on AWS..."
export SERVICE_A_URL="http://aws-alb-dns/service-a"
export SERVICE_B_URL="http://aws-alb-dns/service-b"
./scripts/verify_services.sh

log "Rollback completed successfully"

