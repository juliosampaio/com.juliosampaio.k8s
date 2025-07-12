#!/bin/bash
set -euo pipefail

# PostgreSQL deployment script for both environments
# This script deploys shared PostgreSQL instances to production and stage

echo "=== Deploying PostgreSQL to both environments ==="

# Generate secure password for PostgreSQL
POSTGRES_PASSWORD=$(openssl rand -base64 32)
POSTGRES_PASSWORD_B64=$(echo -n "$POSTGRES_PASSWORD" | base64)
echo "Generated secure PostgreSQL password"

# Function to deploy PostgreSQL to an environment
deploy_postgres() {
    local environment=$1
    echo ""
    echo "Deploying PostgreSQL to $environment environment..."
    
    # Create environment-specific deployment files
    PROD_FILE="/tmp/postgres-${environment}.yaml"
    
    # Copy the template and replace namespace and password
    sed "s/namespace: production/namespace: $environment/g" k8s/environments/database/postgres-deployment.yaml | \
    sed "s/PLACEHOLDER_PASSWORD_WILL_BE_REPLACED/$POSTGRES_PASSWORD_B64/g" > "$PROD_FILE"
    
    # Apply the deployment
    kubectl apply -f "$PROD_FILE"
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to be ready in $environment..."
    kubectl wait --for=condition=available deployment/postgres -n $environment --timeout=300s
    
    # Verify the deployment
    echo "Verifying PostgreSQL deployment in $environment..."
    kubectl get pods -n $environment -l app=postgres
    kubectl get services -n $environment -l app=postgres
    
    # Test database connection
    echo "Testing database connection in $environment..."
    kubectl exec -n $environment deployment/postgres -- pg_isready -U postgres
    
    # Clean up temporary file
    rm -f "$PROD_FILE"
    
    echo "PostgreSQL deployment completed for $environment"
}

# Deploy to production
deploy_postgres "production"

# Deploy to stage
deploy_postgres "stage"

echo ""
echo "=== PostgreSQL deployment completed successfully ==="
echo ""
echo "Database connection details:"
echo ""
echo "Production:"
echo "  Host: postgres-service.production.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: shared_db"
echo "  Username: postgres"
echo ""
echo "Stage:"
echo "  Host: postgres-service.stage.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: shared_db"
echo "  Username: postgres"
echo ""
echo "To create databases for applications, use:"
echo "  ./k8s/environments/database/create-app-database.sh <app-name> <environment>"
echo ""
echo "Examples:"
echo "  ./k8s/environments/database/create-app-database.sh myapp production"
echo "  ./k8s/environments/database/create-app-database.sh myapp stage" 