#!/bin/bash
set -euo pipefail

# Script to retrieve PostgreSQL passwords from Kubernetes secrets
# This shows you the current passwords for both environments

echo "=== PostgreSQL Password Retrieval ==="
echo ""

# Function to get password for an environment
get_password() {
    local environment=$1
    echo "🔍 Checking $environment environment..."
    
    # Check if secret exists
    if kubectl get secret postgres-secret -n $environment >/dev/null 2>&1; then
        echo "✅ Secret found in $environment namespace"
        
        # Get the password from the secret
        PASSWORD_B64=$(kubectl get secret postgres-secret -n $environment -o jsonpath='{.data.postgres-password}')
        
        if [[ -n "$PASSWORD_B64" ]]; then
            PASSWORD=$(echo "$PASSWORD_B64" | base64 -d)
            echo "📋 PostgreSQL Password for $environment:"
            echo "   $PASSWORD"
            echo ""
        else
            echo "❌ Password not found in secret"
            echo ""
        fi
    else
        echo "❌ Secret 'postgres-secret' not found in $environment namespace"
        echo "   PostgreSQL may not be deployed yet or deployment failed"
        echo ""
    fi
}

# Get passwords for both environments
get_password "production"
get_password "stage"

echo "=== Connection Details ==="
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
echo "=== Usage Examples ==="
echo ""
echo "# Connect to production database:"
echo "kubectl exec -it deployment/postgres -n production -- psql -U postgres"
echo ""
echo "# Connect to stage database:"
echo "kubectl exec -it deployment/postgres -n stage -- psql -U postgres"
echo ""
echo "# List databases in production:"
echo "kubectl exec deployment/postgres -n production -- psql -U postgres -c '\\l'"
echo ""
echo "# List databases in stage:"
echo "kubectl exec deployment/postgres -n stage -- psql -U postgres -c '\\l'" 