#!/bin/bash
# DNS Switchover Script
# Switches DNS from AWS ALB to Azure Traffic Manager or vice versa
# Production-ready with proper error handling and validation

set -o errexit
set -o nounset
set -o pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
readonly DNS_ZONE="${DNS_ZONE:-}"
readonly RECORD_NAME="${RECORD_NAME:-app}"
readonly AWS_ALB_DNS="${AWS_ALB_DNS:-}"
readonly AZURE_TM_DNS="${AZURE_TM_DNS:-}"
readonly TARGET="${1:-}"

readonly LOG_FILE="${LOG_FILE:-/var/log/cloudphoenix/switch_dns.log}"
readonly DNS_TTL="${DNS_TTL:-60}"
readonly PROPAGATION_WAIT="${PROPAGATION_WAIT:-120}"

# Validate required commands
check_required_commands aws dig

# Validate inputs
if [ -z "$DNS_ZONE" ]; then
    error_exit "DNS_ZONE environment variable is required"
fi

if [ -z "$TARGET" ]; then
    error_exit "Usage: $0 <aws|azure>"
fi

if [ "$TARGET" != "aws" ] && [ "$TARGET" != "azure" ]; then
    error_exit "Invalid target. Must be 'aws' or 'azure'"
fi

# Determine target DNS
if [ "$TARGET" = "azure" ]; then
    TARGET_DNS="${AZURE_TM_DNS}"
    if [ -z "$TARGET_DNS" ]; then
        error_exit "AZURE_TM_DNS environment variable is required for Azure target"
    fi
    log_info "Switching to Azure Traffic Manager: $TARGET_DNS"
elif [ "$TARGET" = "aws" ]; then
    TARGET_DNS="${AWS_ALB_DNS}"
    if [ -z "$TARGET_DNS" ]; then
        error_exit "AWS_ALB_DNS environment variable is required for AWS target"
    fi
    log_info "Switching to AWS ALB: $TARGET_DNS"
fi

# Ensure log directory exists
LOG_DIR=$(dirname "$LOG_FILE")
ensure_dir "$LOG_DIR"

# Setup logging
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

log_info "Starting DNS switchover to: $TARGET"
log_info "DNS Zone: $DNS_ZONE"
log_info "Record Name: ${RECORD_NAME}.${DNS_ZONE}"
log_info "Target DNS: $TARGET_DNS"

# Get hosted zone ID
log_info "Looking up Route53 hosted zone..."
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "$DNS_ZONE" \
    --query "HostedZones[0].Id" \
    --output text 2>/dev/null | sed 's|/hostedzone/||' || true)

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "None" ]; then
    error_exit "Could not find hosted zone for $DNS_ZONE"
fi

log_info "Found hosted zone ID: $ZONE_ID"

# Get current record value
CURRENT_RECORD=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --query "ResourceRecordSets[?Name=='${RECORD_NAME}.${DNS_ZONE}.']" \
    --output json 2>/dev/null || echo "[]")

# Determine record type based on target
if [ "$TARGET" = "aws" ]; then
    # AWS ALB uses A record with alias
    RECORD_TYPE="A"
    CHANGE_BATCH=$(cat <<EOF
{
    "Comment": "CloudPhoenix DNS switchover to AWS",
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "${RECORD_NAME}.${DNS_ZONE}",
            "Type": "A",
            "AliasTarget": {
                "DNSName": "${TARGET_DNS}",
                "EvaluateTargetHealth": true,
                "HostedZoneId": "${AWS_ALB_ZONE_ID:-Z35SXDOTRQ7X7K}"
            }
        }
    }]
}
EOF
)
else
    # Azure Traffic Manager uses CNAME
    RECORD_TYPE="CNAME"
    CHANGE_BATCH=$(cat <<EOF
{
    "Comment": "CloudPhoenix DNS switchover to Azure DR",
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "${RECORD_NAME}.${DNS_ZONE}",
            "Type": "CNAME",
            "TTL": $DNS_TTL,
            "ResourceRecords": [{"Value": "${TARGET_DNS}"}]
        }
    }]
}
EOF
)
fi

# Submit DNS change
log_info "Submitting DNS change to Route53..."
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "$CHANGE_BATCH" \
    --query "ChangeInfo.Id" \
    --output text 2>/dev/null | sed 's|/change/||' || true)

if [ -z "$CHANGE_ID" ]; then
    error_exit "Failed to submit DNS change"
fi

log_info "DNS change submitted. Change ID: $CHANGE_ID"

# Wait for change to be synced
log_info "Waiting for Route53 change to sync..."
if ! aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"; then
    log_warn "Route53 wait timed out, but change may still be processing"
fi

# Wait for DNS propagation
log_info "Waiting for DNS propagation (up to ${PROPAGATION_WAIT}s)..."
FULL_RECORD_NAME="${RECORD_NAME}.${DNS_ZONE}"

if wait_for "dig +short $FULL_RECORD_NAME | grep -q $TARGET_DNS" "$PROPAGATION_WAIT" 5; then
    log_info "DNS propagation confirmed"
else
    log_warn "DNS propagation check timed out, but change may still be propagating"
fi

# Verify DNS resolution
RESOLVED_IP=$(dig +short "$FULL_RECORD_NAME" | head -1 || true)
if [ -n "$RESOLVED_IP" ]; then
    log_info "DNS resolves to: $RESOLVED_IP"
else
    log_warn "Could not resolve DNS record (may still be propagating)"
fi

log_info "DNS switchover completed successfully"
log_info "Record: ${FULL_RECORD_NAME} -> ${TARGET_DNS}"

exit 0
