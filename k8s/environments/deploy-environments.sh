#!/bin/bash
set -euo pipefail

# Environment deployment script
# This script sets up the production and stage environments

echo "=== Deploying Kubernetes Environments ==="

# Create namespaces
echo "Creating namespaces..."
kubectl apply -f k8s/environments/namespaces.yaml

# Wait for namespaces to be ready
echo "Waiting for namespaces to be ready..."
kubectl wait --for=condition=active namespace/production --timeout=30s
kubectl wait --for=condition=active namespace/stage --timeout=30s

# Deploy ingress configurations
echo "Deploying ingress configurations..."
kubectl apply -f k8s/environments/ingress-templates/production-ingress.yaml
kubectl apply -f k8s/environments/ingress-templates/stage-ingress.yaml

# Verify ingress deployments
echo "Verifying ingress deployments..."
kubectl get ingress -n production
kubectl get ingress -n stage

echo "=== Environment deployment completed ==="
echo ""
echo "Next steps:"
echo "1. Point your domains to your cluster IP:"
echo "   - juliosampaio.com -> $(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')"
echo "   - stage.juliosampaio.com -> $(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')"
echo "   - app.juliosampaio.com -> $(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')"
echo "   - app.stage.juliosampaio.com -> $(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')"
echo ""
echo "2. Deploy your applications:"
echo "   kubectl apply -f your-app-deployment.yaml -n production"
echo "   kubectl apply -f your-app-deployment.yaml -n stage"
echo ""
echo "3. Check certificate status:"
echo "   kubectl get certificates -n production"
echo "   kubectl get certificates -n stage" 