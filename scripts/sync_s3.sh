#!/bin/bash
# S3 to Azure Blob Storage Sync Script

set -e

# Configuration
AWS_S3_BUCKET="${AWS_S3_BUCKET:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-}"
AZURE_STORAGE_KEY="${AZURE_STORAGE_KEY:-}"
AZURE_CONTAINER="${AZURE_CONTAINER:-data}"

LOG_FILE="${LOG_FILE:-/var/log/cloudphoenix/sync_s3.log}"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting S3 to Azure Blob Storage sync"

# Check required variables
if [ -z "$AWS_S3_BUCKET" ] || [ -z "$AZURE_STORAGE_ACCOUNT" ]; then
    log "ERROR: Required storage configuration not set"
    exit 1
fi

# Install azcopy if not available
if ! command -v azcopy &> /dev/null; then
    log "Installing azcopy..."
    wget -O azcopy.tar.gz https://aka.ms/downloadazcopy-v10-linux
    tar -xzf azcopy.tar.gz --strip-components=1
    chmod +x azcopy
    sudo mv azcopy /usr/local/bin/
    rm -f azcopy.tar.gz
fi

# Sync using AWS CLI and azcopy
log "Syncing S3 bucket: $AWS_S3_BUCKET to Azure container: $AZURE_CONTAINER"

# Download from S3 to temp directory
TEMP_DIR="/tmp/s3_sync_$(date +%s)"
mkdir -p "$TEMP_DIR"

log "Downloading from S3..."
aws s3 sync "s3://$AWS_S3_BUCKET" "$TEMP_DIR" --region "$AWS_REGION"

if [ $? -ne 0 ]; then
    log "ERROR: Failed to download from S3"
    exit 1
fi

# Upload to Azure Blob Storage
log "Uploading to Azure Blob Storage..."
azcopy copy "$TEMP_DIR" "https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_CONTAINER}?${AZURE_STORAGE_KEY}" --recursive

if [ $? -ne 0 ]; then
    log "ERROR: Failed to upload to Azure Blob Storage"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"

log "S3 to Azure Blob Storage sync completed successfully"

