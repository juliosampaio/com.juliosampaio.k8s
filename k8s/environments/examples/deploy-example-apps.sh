#!/bin/bash
set -euo pipefail

# Example deployment script for the specific use case:
# - juliosampaio.com -> production website
# - stage.juliosampaio.com -> stage website

echo "=== Deploying Example Applications ==="
echo "This script demonstrates how to deploy applications with different subdomain patterns"
echo ""

# First, ensure environments are set up
echo "1. Setting up environments..."
./k8s/environments/deploy-environments.sh

echo ""
echo "2. Deploying main website to production..."
# Deploy main website to production (juliosampaio.com)
./k8s/environments/helm-charts/deploy-app.sh main-website production "" production

echo ""
echo "3. Deploying main website to stage..."
# Deploy main website to stage (stage.juliosampaio.com)
./k8s/environments/helm-charts/deploy-app.sh main-website stage "" stage

echo ""
echo "4. Example: Deploying an application to production..."
echo "   (Uncomment and modify the following lines for your actual applications)"
# Deploy app1 to production (app1.juliosampaio.com)
# ./k8s/environments/helm-charts/deploy-app.sh app1 production app1 production

echo ""
echo "5. Example: Deploying an application to stage..."
echo "   (Uncomment and modify the following lines for your actual applications)"
# Deploy app1 to stage (app1.stage.juliosampaio.com)
# ./k8s/environments/helm-charts/deploy-app.sh app1 stage app1 stage

echo ""
echo "=== Deployment Summary ==="
echo "Production URLs:"
echo "  - Main website: https://juliosampaio.com"
echo ""
echo "Stage URLs:"
echo "  - Main website: https://stage.juliosampaio.com"
echo ""
echo "To add more applications, use:"
echo "  ./k8s/environments/helm-charts/deploy-app.sh <app-name> <environment> <subdomain>"
echo ""
echo "Examples:"
echo "  ./k8s/environments/helm-charts/deploy-app.sh app1 production app1"
echo "  ./k8s/environments/helm-charts/deploy-app.sh api production api"
echo "  ./k8s/environments/helm-charts/deploy-app.sh dashboard stage dashboard" 