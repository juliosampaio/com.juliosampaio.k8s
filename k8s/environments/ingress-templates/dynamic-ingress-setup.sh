#!/bin/bash
set -euo pipefail

# Dynamic ingress setup script for external application deployments
# This script can be called by external repositories to add new subdomains

# Usage: ./dynamic-ingress-setup.sh <environment> <subdomain> <service-name> [service-port]

ENVIRONMENT="${1:-}"
SUBDOMAIN="${2:-}"
SERVICE_NAME="${3:-}"
SERVICE_PORT="${4:-80}"

if [[ -z "$ENVIRONMENT" || -z "$SUBDOMAIN" || -z "$SERVICE_NAME" ]]; then
    echo "Usage: $0 <environment> <subdomain> <service-name> [service-port]"
    echo "Examples:"
    echo "  $0 production app1 app1-service"
    echo "  $0 stage api api-service 8080"
    echo "  $0 production dashboard dashboard-service"
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "stage" ]]; then
    echo "Error: Environment must be 'production' or 'stage'"
    exit 1
fi

# Generate domain based on environment and subdomain
if [[ "$ENVIRONMENT" == "production" ]]; then
    DOMAIN="${SUBDOMAIN}.juliosampaio.com"
else
    DOMAIN="${SUBDOMAIN}.stage.juliosampaio.com"
fi

echo "Adding subdomain $DOMAIN to $ENVIRONMENT environment..."

# Create a patch for the ingress to add the new subdomain
PATCH_FILE="/tmp/${SUBDOMAIN}-${ENVIRONMENT}-ingress-patch.yaml"

cat > "$PATCH_FILE" <<EOF
spec:
  tls:
  - hosts:
    - $DOMAIN
    secretName: ${ENVIRONMENT}-tls
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $SERVICE_NAME
            port:
              number: $SERVICE_PORT
EOF

# Apply the patch to the existing ingress
echo "Patching ingress configuration..."
kubectl patch ingress ${ENVIRONMENT}-ingress -n $ENVIRONMENT --patch-file "$PATCH_FILE" --type merge

# Clean up
rm -f "$PATCH_FILE"

echo "Successfully added $DOMAIN to $ENVIRONMENT environment"
echo "Service: $SERVICE_NAME"
echo "Port: $SERVICE_PORT"
echo ""
echo "Make sure to:"
echo "1. Point $DOMAIN to your cluster IP in DNS"
echo "2. Deploy your application with service name: $SERVICE_NAME" 