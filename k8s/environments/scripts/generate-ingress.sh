#!/bin/bash
set -euo pipefail

# Dynamic ingress generator for multi-environment subdomain routing
# Usage: ./generate-ingress.sh <app-name> <environment> [subdomain-pattern]

APP_NAME="${1:-}"
ENVIRONMENT="${2:-}"
SUBDOMAIN_PATTERN="${3:-}"

if [[ -z "$APP_NAME" || -z "$ENVIRONMENT" ]]; then
    echo "Usage: $0 <app-name> <environment> [subdomain-pattern]"
    echo "Examples:"
    echo "  $0 app1 production"
    echo "  $0 app1 stage"
    echo "  $0 my-api production api"
    echo "  $0 my-api stage api"
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "stage" ]]; then
    echo "Error: Environment must be 'production' or 'stage'"
    exit 1
fi

# Generate subdomain based on pattern
if [[ -n "$SUBDOMAIN_PATTERN" ]]; then
    if [[ "$ENVIRONMENT" == "production" ]]; then
        SUBDOMAIN="${SUBDOMAIN_PATTERN}.juliosampaio.com"
    else
        SUBDOMAIN="${SUBDOMAIN_PATTERN}.stage.juliosampaio.com"
    fi
else
    if [[ "$ENVIRONMENT" == "production" ]]; then
        SUBDOMAIN="${APP_NAME}.juliosampaio.com"
    else
        SUBDOMAIN="${APP_NAME}.stage.juliosampaio.com"
    fi
fi

# Create the ingress configuration
INGRESS_FILE="/tmp/${APP_NAME}-${ENVIRONMENT}-ingress.yaml"

cat > "$INGRESS_FILE" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}-ingress
  namespace: ${ENVIRONMENT}
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/rate-limit: "$([[ "$ENVIRONMENT" == "production" ]] && echo "100" || echo "50")"
spec:
  tls:
    - hosts:
        - ${SUBDOMAIN}
      secretName: ${APP_NAME}-${ENVIRONMENT}-tls
  rules:
    - host: ${SUBDOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${APP_NAME}-service
                port:
                  number: 80
EOF

echo "Generated ingress configuration for ${APP_NAME} in ${ENVIRONMENT}:"
echo "Domain: ${SUBDOMAIN}"
echo "File: ${INGRESS_FILE}"
echo ""
echo "To apply this configuration:"
echo "kubectl apply -f ${INGRESS_FILE}"
echo ""
echo "To add this to your main ingress configuration, copy the relevant parts to:"
echo "- k8s/environments/ingress-templates/${ENVIRONMENT}-ingress.yaml" 