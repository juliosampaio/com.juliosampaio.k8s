#!/bin/bash

# PostgreSQL Backup Script for n8n
# This script can be executed by n8n to backup PostgreSQL databases

set -e

# Configuration
ENVIRONMENT=${1:-production}
BACKUP_DIR=${2:-/tmp/backups}
RETENTION_DAYS=${3:-7}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(production|stage)$ ]]; then
    error "Invalid environment: $ENVIRONMENT. Must be 'production' or 'stage'"
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Get database password from Kubernetes secret
log "Retrieving database password for $ENVIRONMENT environment..."
PASSWORD=$(kubectl get secret postgres-secret -n "$ENVIRONMENT" -o jsonpath='{.data.postgres-password}' | base64 -d)

if [ -z "$PASSWORD" ]; then
    error "Failed to retrieve database password"
fi

# Set PostgreSQL connection details
PGHOST="postgres-backup-service.$ENVIRONMENT.svc.cluster.local"
PGPORT="5432"
PGUSER="postgres"
PGPASSWORD="$PASSWORD"
PGDATABASE="shared_db"

# Export for pg_dump
export PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE

# Test connection
log "Testing database connection..."
if ! kubectl exec deployment/postgres -n "$ENVIRONMENT" -- pg_isready -U postgres >/dev/null 2>&1; then
    error "Cannot connect to PostgreSQL database"
fi

# Get list of databases to backup
log "Getting list of databases..."
DATABASES=$(kubectl exec deployment/postgres -n "$ENVIRONMENT" -- psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres');")

if [ -z "$DATABASES" ]; then
    warn "No user databases found to backup"
    exit 0
fi

# Create timestamp for backup files
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
BACKUP_COUNT=0
SUCCESS_COUNT=0

# Backup each database
for DB in $DATABASES; do
    DB=$(echo "$DB" | xargs)  # Remove whitespace
    if [ -n "$DB" ]; then
        BACKUP_FILE="$BACKUP_DIR/backup_${DB}_${ENVIRONMENT}_${TIMESTAMP}.sql.gz"
        log "Backing up database: $DB"
        
        if kubectl exec deployment/postgres -n "$ENVIRONMENT" -- pg_dump -U postgres -d "$DB" | gzip > "$BACKUP_FILE"; then
            log "✓ Successfully backed up $DB to $BACKUP_FILE"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            error "Failed to backup database: $DB"
        fi
        
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
    fi
done

# Clean up old backups
log "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "backup_*_${ENVIRONMENT}_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Summary
log "Backup completed successfully!"
log "Environment: $ENVIRONMENT"
log "Databases processed: $BACKUP_COUNT"
log "Successful backups: $SUCCESS_COUNT"
log "Backup directory: $BACKUP_DIR"
log "Retention: $RETENTION_DAYS days"

# List current backups
log "Current backups:"
ls -lh "$BACKUP_DIR"/backup_*_${ENVIRONMENT}_*.sql.gz 2>/dev/null || warn "No backup files found"

# Return success
exit 0 