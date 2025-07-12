#!/bin/bash
set -euo pipefail

# Enhanced Helm chart deployment script for multi-environment applications
# Usage: ./deploy-app.sh <app-name> <environment> [subdomain] [namespace]

APP_NAME="${1:-}"
ENVIRONMENT="${2:-}"
SUBDOMAIN="${3:-$APP_NAME}"
NAMESPACE="${4:-$ENVIRONMENT}"

if [[ -z "$APP_NAME" || -z "$ENVIRONMENT" ]]; then
    echo "Usage: $0 <app-name> <environment> [subdomain] [namespace]"
    echo "Examples:"
    echo "  $0 my-app production"
    echo "  $0 my-app stage"
    echo "  $0 my-api production api"
    echo "  $0 my-api stage api"
    echo "  $0 my-app production myapp"
    echo "  $0 my-app stage myapp"
    exit 1
fi

CHART_DIR="k8s/environments/helm-charts/app-template"

echo "=== Deploying $APP_NAME to $ENVIRONMENT environment ==="
echo "Subdomain: $SUBDOMAIN"
echo "Namespace: $NAMESPACE"

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "stage" ]]; then
    echo "Error: Environment must be 'production' or 'stage'"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Error: Namespace '$NAMESPACE' does not exist. Please run deploy-environments.sh first."
    exit 1
fi

# Generate domain based on environment and subdomain
if [[ "$ENVIRONMENT" == "production" ]]; then
    DOMAIN="${SUBDOMAIN}.juliosampaio.com"
else
    DOMAIN="${SUBDOMAIN}.stage.juliosampaio.com"
fi

# Create environment-specific values file
VALUES_FILE="/tmp/${APP_NAME}-${ENVIRONMENT}-values.yaml"

cat > "$VALUES_FILE" <<EOF
# Environment-specific values for $APP_NAME in $ENVIRONMENT
app:
  name: "$APP_NAME"

# Override with environment-specific settings
deployment:
  replicas: $([[ "$ENVIRONMENT" == "production" ]] && echo "3" || echo "1")
  resources:
    requests:
      memory: $([[ "$ENVIRONMENT" == "production" ]] && echo "128Mi" || echo "32Mi")
      cpu: $([[ "$ENVIRONMENT" == "production" ]] && echo "100m" || echo "25m")
    limits:
      memory: $([[ "$ENVIRONMENT" == "production" ]] && echo "256Mi" || echo "64Mi")
      cpu: $([[ "$ENVIRONMENT" == "production" ]] && echo "200m" || echo "50m")

ingress:
  enabled: true
  subdomain: "$SUBDOMAIN"
  hosts:
    - host: "$DOMAIN"
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: "${APP_NAME}-${ENVIRONMENT}-tls"
      hosts:
        - "$DOMAIN"
EOF

echo "Deploying with values:"
cat "$VALUES_FILE"
echo ""

# Deploy using Helm
echo "Deploying $APP_NAME to $NAMESPACE namespace..."
echo "Domain: $DOMAIN"
helm upgrade --install "$APP_NAME" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    --wait \
    --timeout 5m

# Clean up temporary values file
rm -f "$VALUES_FILE"

echo ""
echo "=== Deployment completed ==="
echo "Application: $APP_NAME"
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Domain: $DOMAIN"
echo "URL: https://$DOMAIN"
echo ""
echo "Check deployment status:"
echo "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME"
echo "kubectl get ingress -n $NAMESPACE"
echo "kubectl get certificates -n $NAMESPACE"
echo ""
echo "To add this domain to your DNS, point $DOMAIN to your cluster IP" 