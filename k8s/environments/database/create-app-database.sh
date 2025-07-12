#!/bin/bash
set -euo pipefail

# Database creation script for shared PostgreSQL instance
# Usage: ./create-app-database.sh <app-name> <environment> [database-name] [username]

APP_NAME="${1:-}"
ENVIRONMENT="${2:-}"
DATABASE_NAME="${3:-${APP_NAME}_db}"
USERNAME="${4:-${APP_NAME}_user}"

if [[ -z "$APP_NAME" || -z "$ENVIRONMENT" ]]; then
    echo "Usage: $0 <app-name> <environment> [database-name] [username]"
    echo "Examples:"
    echo "  $0 myapp production"
    echo "  $0 myapp stage"
    echo "  $0 myapp production myapp_prod myapp_user"
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "stage" ]]; then
    echo "Error: Environment must be 'production' or 'stage'"
    exit 1
fi

echo "=== Creating database for $APP_NAME in $ENVIRONMENT environment ==="
echo "Database: $DATABASE_NAME"
echo "Username: $USERNAME"

# Generate a secure password for the app user
APP_PASSWORD=$(openssl rand -base64 32)
echo "Generated password for $USERNAME: $APP_PASSWORD"

# Create a temporary SQL file
SQL_FILE="/tmp/${APP_NAME}-${ENVIRONMENT}-db-setup.sql"

cat > "$SQL_FILE" <<EOF
-- Database setup for $APP_NAME in $ENVIRONMENT
-- This script creates a database and user for the application

-- Create the database
CREATE DATABASE "$DATABASE_NAME";

-- Create the user
CREATE USER "$USERNAME" WITH PASSWORD '$APP_PASSWORD';

-- Grant privileges to the user
GRANT ALL PRIVILEGES ON DATABASE "$DATABASE_NAME" TO "$USERNAME";

-- Connect to the new database and grant schema privileges
\c "$DATABASE_NAME";
GRANT ALL ON SCHEMA public TO "$USERNAME";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$USERNAME";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$USERNAME";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$USERNAME";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$USERNAME";

-- Create a schema for the app (optional, for better organization)
CREATE SCHEMA IF NOT EXISTS "$APP_NAME";
GRANT ALL ON SCHEMA "$APP_NAME" TO "$USERNAME";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA "$APP_NAME" TO "$USERNAME";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA "$APP_NAME" TO "$USERNAME";
ALTER DEFAULT PRIVILEGES IN SCHEMA "$APP_NAME" GRANT ALL ON TABLES TO "$USERNAME";
ALTER DEFAULT PRIVILEGES IN SCHEMA "$APP_NAME" GRANT ALL ON SEQUENCES TO "$USERNAME";
EOF

echo "Executing database setup..."
kubectl exec -n $ENVIRONMENT deployment/postgres -- psql -U postgres -f /tmp/db-setup.sql < "$SQL_FILE"

# Create Kubernetes secret for the app's database credentials
echo "Creating Kubernetes secret for database credentials..."
kubectl create secret generic "${APP_NAME}-db-secret" \
  --namespace=$ENVIRONMENT \
  --from-literal=DB_HOST=postgres-service \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME="$DATABASE_NAME" \
  --from-literal=DB_USER="$USERNAME" \
  --from-literal=DB_PASSWORD="$APP_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Clean up
rm -f "$SQL_FILE"

echo ""
echo "=== Database setup completed successfully ==="
echo "App: $APP_NAME"
echo "Environment: $ENVIRONMENT"
echo "Database: $DATABASE_NAME"
echo "Username: $USERNAME"
echo "Password: $APP_PASSWORD"
echo ""
echo "Connection details for your application:"
echo "Host: postgres-service.$ENVIRONMENT.svc.cluster.local"
echo "Port: 5432"
echo "Database: $DATABASE_NAME"
echo "Username: $USERNAME"
echo "Password: $APP_PASSWORD"
echo ""
echo "Kubernetes secret created: ${APP_NAME}-db-secret"
echo "Use this secret in your application deployment to access the database." 