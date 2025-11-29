#!/bin/bash
# Chaos Testing Script
# Simulates various failure scenarios

set -e

FAILURE_TYPE="${1:-}"
NAMESPACE="${NAMESPACE:-default}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

usage() {
    echo "Usage: $0 <failure_type>"
    echo "Failure types:"
    echo "  pod-crash      - Crash random pods"
    echo "  db-slowdown    - Simulate database slowdown"
    echo "  az-failure     - Simulate availability zone failure"
    echo "  region-isolation - Simulate region isolation"
    exit 1
}

simulate_pod_crash() {
    log "Simulating pod crashes..."
    
    # Get random pods
    PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | shuf | head -2)
    
    for pod in $PODS; do
        log "Crashing pod: $pod"
        kubectl delete pod "$pod" -n "$NAMESPACE" --force --grace-period=0 || true
    done
    
    log "Pod crash simulation complete"
}

simulate_db_slowdown() {
    log "Simulating database slowdown..."
    
    # This would typically involve:
    # 1. Adding latency to database connections
    # 2. Reducing database resources
    # 3. Adding connection pool exhaustion
    
    log "WARNING: Database slowdown simulation requires manual intervention"
    log "Consider:"
    log "  - Reducing RDS instance size"
    log "  - Adding network latency"
    log "  - Exhausting connection pool"
}

simulate_az_failure() {
    log "Simulating availability zone failure..."
    
    # Drain nodes in a specific AZ
    AZ="${AZ:-us-east-1a}"
    log "Draining nodes in AZ: $AZ"
    
    NODES=$(kubectl get nodes -l topology.kubernetes.io/zone="$AZ" -o jsonpath='{.items[*].metadata.name}')
    
    for node in $NODES; do
        log "Cordoning node: $node"
        kubectl cordon "$node" || true
        log "Draining node: $node"
        kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --grace-period=60 || true
    done
    
    log "AZ failure simulation complete"
}

simulate_region_isolation() {
    log "Simulating region isolation..."
    
    # This would involve:
    # 1. Blocking network traffic to/from region
    # 2. Simulating DNS failures
    # 3. Blocking API access
    
    log "WARNING: Region isolation simulation requires network-level changes"
    log "Consider using:"
    log "  - AWS VPC route table modifications"
    log "  - Security group rule changes"
    log "  - DNS record removal"
}

main() {
    case "$FAILURE_TYPE" in
        pod-crash)
            simulate_pod_crash
            ;;
        db-slowdown)
            simulate_db_slowdown
            ;;
        az-failure)
            simulate_az_failure
            ;;
        region-isolation)
            simulate_region_isolation
            ;;
        *)
            usage
            ;;
    esac
}

main

