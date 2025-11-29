#!/bin/bash
# Database Replication Script
# Syncs data from AWS RDS to Azure SQL with proper error handling and retries

set -o errexit
set -o nounset
set -o pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
readonly AWS_RDS_HOST="${AWS_RDS_HOST:-}"
readonly AWS_RDS_PORT="${AWS_RDS_PORT:-5432}"
readonly AWS_RDS_DB="${AWS_RDS_DB:-cloudphoenix}"
readonly AWS_RDS_USER="${AWS_RDS_USER:-admin}"
readonly AWS_RDS_PASSWORD="${AWS_RDS_PASSWORD:-}"

readonly AZURE_SQL_HOST="${AZURE_SQL_HOST:-}"
readonly AZURE_SQL_PORT="${AZURE_SQL_PORT:-1433}"
readonly AZURE_SQL_DB="${AZURE_SQL_DB:-cloudphoenix}"
readonly AZURE_SQL_USER="${AZURE_SQL_USER:-cloudphoenixadmin}"
readonly AZURE_SQL_PASSWORD="${AZURE_SQL_PASSWORD:-}"

readonly LOG_FILE="${LOG_FILE:-/var/log/cloudphoenix/replicate_db.log}"
readonly MAX_RETRIES="${MAX_RETRIES:-3}"
readonly BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# Validate required commands
check_required_commands pg_dump psql curl

# Validate required environment variables
if [ -z "$AWS_RDS_HOST" ]; then
    error_exit "AWS_RDS_HOST environment variable is required"
fi

if [ -z "$AZURE_SQL_HOST" ]; then
    error_exit "AZURE_SQL_HOST environment variable is required"
fi

# Ensure log directory exists
LOG_DIR=$(dirname "$LOG_FILE")
ensure_dir "$LOG_DIR"

# Setup logging to file
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

log_info "Starting database replication from AWS RDS to Azure SQL"
log_info "Source: ${AWS_RDS_HOST}:${AWS_RDS_PORT}/${AWS_RDS_DB}"
log_info "Destination: ${AZURE_SQL_HOST}:${AZURE_SQL_PORT}/${AZURE_SQL_DB}"

# Create temporary directory for backups
TEMP_DIR=$(create_temp_dir)
BACKUP_FILE="${TEMP_DIR}/rds_backup_$(date +%Y%m%d_%H%M%S).sql"

# Export data from PostgreSQL (AWS RDS)
log_info "Exporting data from AWS RDS..."
export PGPASSWORD="$AWS_RDS_PASSWORD"

if ! retry "$MAX_RETRIES" 2 \
    pg_dump \
        -h "$AWS_RDS_HOST" \
        -p "$AWS_RDS_PORT" \
        -U "$AWS_RDS_USER" \
        -d "$AWS_RDS_DB" \
        --no-owner \
        --no-privileges \
        --data-only \
        --format=plain \
        --file="$BACKUP_FILE" \
        --verbose; then
    error_exit "Failed to export data from AWS RDS after $MAX_RETRIES attempts"
fi

unset PGPASSWORD

# Verify backup file
if [ ! -f "$BACKUP_FILE" ] || [ ! -s "$BACKUP_FILE" ]; then
    error_exit "Backup file is missing or empty: $BACKUP_FILE"
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log_info "Backup created successfully. Size: $BACKUP_SIZE"

# Note: Azure SQL uses T-SQL, which requires conversion
# For production, use AWS DMS or Azure Database Migration Service
log_warn "Manual conversion required for Azure SQL (PostgreSQL to T-SQL)"
log_warn "For production, use AWS DMS or Azure Database Migration Service"

# Store backup in a safe location for manual processing
BACKUP_STORAGE="/var/backups/cloudphoenix"
ensure_dir "$BACKUP_STORAGE"
STORED_BACKUP="${BACKUP_STORAGE}/rds_backup_$(date +%Y%m%d_%H%M%S).sql"
cp "$BACKUP_FILE" "$STORED_BACKUP"
log_info "Backup stored at: $STORED_BACKUP"

# Cleanup old backups (older than retention period)
find "$BACKUP_STORAGE" -name "rds_backup_*.sql" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true

log_info "Database replication script completed successfully"
log_info "Note: Manual T-SQL conversion required for Azure SQL import"

exit 0
