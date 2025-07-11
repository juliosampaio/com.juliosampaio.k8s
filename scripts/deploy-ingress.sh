#!/usr/bin/env bash
# idempotently deploy/upgrade Traefik + cert-manager and create ClusterIssuer
set -euo pipefail

# Download official Helm if not present
if [ ! -x ./helm ]; then
  curl -sSL -o helm.tar.gz https://get.helm.sh/helm-v3.14.4-linux-arm64.tar.gz
  tar -xzf helm.tar.gz linux-arm64/helm
  mv linux-arm64/helm ./helm
  chmod +x ./helm
  rm -rf linux-arm64 helm.tar.gz
fi

HELM=./helm
KUBECTL=kubectl

# Add/refresh repos
$HELM repo add traefik  https://traefik.github.io/charts   || true
$HELM repo add jetstack https://charts.jetstack.io         || true
$HELM repo update

$HELM upgrade --install traefik traefik/traefik \
  --namespace kube-system --create-namespace \
  --set service.type=LoadBalancer \
  --set ports.websecure.port=443

$HELM upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

cat <<YAML | $KUBECTL apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${LE_EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: acme-account-key
    solvers:
    - http01:
        ingress:
          class: traefik
YAML

echo "Ingress stack deployed/updated successfully" 