#!/bin/bash
# Secret Rotation Script
# Rotates secrets in AWS Secrets Manager and Azure Key Vault

set -e

SECRET_TYPE="${1:-all}"  # 'aws', 'azure', or 'all'
ROTATION_INTERVAL="${ROTATION_INTERVAL:-90}"  # days

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

rotate_aws_secrets() {
    log "Rotating AWS secrets..."
    
    # Rotate RDS password
    SECRET_ARN=$(aws secretsmanager list-secrets \
        --filters Key=name,Values=cloudphoenix-rds-password \
        --query 'SecretList[0].ARN' \
        --output text)
    
    if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
        log "Rotating RDS password..."
        aws secretsmanager rotate-secret \
            --secret-id "$SECRET_ARN" \
            --rotation-lambda-arn arn:aws:lambda:REGION:ACCOUNT:function:rotate-rds-password || true
    fi
    
    # Rotate other secrets as needed
    log "AWS secret rotation completed"
}

rotate_azure_secrets() {
    log "Rotating Azure secrets..."
    
    # Rotate SQL password
    KEY_VAULT_NAME="${AZURE_KEY_VAULT_NAME:-cloudphoenix-kv}"
    SECRET_NAME="cloudphoenix-sql-password"
    
    # Generate new password
    NEW_PASSWORD=$(openssl rand -base64 32)
    
    # Update in Key Vault
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "$SECRET_NAME" \
        --value "$NEW_PASSWORD" || true
    
    # Update in Azure SQL
    # Note: This requires additional Azure CLI commands
    
    log "Azure secret rotation completed"
}

main() {
    case "$SECRET_TYPE" in
        aws)
            rotate_aws_secrets
            ;;
        azure)
            rotate_azure_secrets
            ;;
        all)
            rotate_aws_secrets
            rotate_azure_secrets
            ;;
        *)
            echo "Usage: $0 [aws|azure|all]"
            exit 1
            ;;
    esac
}

main

