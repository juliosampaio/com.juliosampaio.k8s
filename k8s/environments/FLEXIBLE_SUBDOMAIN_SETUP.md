# Flexible Subdomain Setup for Multi-Environment Deployments

This document explains how to deploy applications with any subdomain pattern in your Kubernetes cluster.

## Overview

The system is designed to be **completely flexible** and support any subdomain pattern you want. You can deploy applications with any subdomain structure:

```
# Production Environment
juliosampaio.com → production website
app1.juliosampaio.com → production app1 (example)
api.juliosampaio.com → production API (example)
dashboard.juliosampaio.com → production dashboard (example)

# Stage Environment
stage.juliosampaio.com → stage website
app1.stage.juliosampaio.com → stage app1 (example)
api.stage.juliosampaio.com → stage API (example)
dashboard.stage.juliosampaio.com → stage dashboard (example)
```

## Quick Start

### 1. Set Up Environments

```bash
# Deploy the base environment infrastructure
./k8s/environments/deploy-environments.sh
```

### 2. Deploy Applications with Any Subdomain

```bash
# Deploy main website (juliosampaio.com)
./k8s/environments/helm-charts/deploy-app.sh main-website production "" production

# Deploy stage website (stage.juliosampaio.com)
./k8s/environments/helm-charts/deploy-app.sh main-website stage "" stage

# Example: Deploy app1 (app1.juliosampaio.com)
# ./k8s/environments/helm-charts/deploy-app.sh app1 production app1 production

# Example: Deploy app1 stage (app1.stage.juliosampaio.com)
# ./k8s/environments/helm-charts/deploy-app.sh app1 stage app1 stage

# Example: Deploy API (api.juliosampaio.com)
# ./k8s/environments/helm-charts/deploy-app.sh api production api production

# Example: Deploy dashboard (dashboard.stage.juliosampaio.com)
# ./k8s/environments/helm-charts/deploy-app.sh dashboard stage dashboard stage
```

### 3. Run the Complete Example

```bash
# Deploy all example applications
./k8s/environments/examples/deploy-example-apps.sh
```

## Deployment Script Usage

The enhanced deployment script supports any subdomain pattern:

```bash
./k8s/environments/helm-charts/deploy-app.sh <app-name> <environment> [subdomain] [namespace]
```

### Parameters

- **`app-name`**: The name of your application (used for Kubernetes resources)
- **`environment`**: `production` or `stage`
- **`subdomain`**: (Optional) The subdomain pattern. If not provided, uses `app-name`
- **`namespace`**: (Optional) The namespace to deploy to. Defaults to `environment`

### Examples

```bash
# Basic deployment (uses app name as subdomain)
./k8s/environments/helm-charts/deploy-app.sh myapp production
# Result: myapp.juliosampaio.com

# Custom subdomain
./k8s/environments/helm-charts/deploy-app.sh myapp production api
# Result: api.juliosampaio.com

# Stage with custom subdomain
./k8s/environments/helm-charts/deploy-app.sh myapp stage dashboard
# Result: dashboard.stage.juliosampaio.com

# Main website (no subdomain)
./k8s/environments/helm-charts/deploy-app.sh main-website production "" production
# Result: juliosampaio.com
```

## Domain Generation Rules

The system automatically generates the correct domain based on the environment:

### Production Environment

- **Pattern**: `{subdomain}.juliosampaio.com`
- **Examples**:
  - `app1` → `app1.juliosampaio.com`
  - `api` → `api.juliosampaio.com`
  - `dashboard` → `dashboard.juliosampaio.com`
  - `""` (empty) → `juliosampaio.com`

### Stage Environment

- **Pattern**: `{subdomain}.stage.juliosampaio.com`
- **Examples**:
  - `app1` → `app1.stage.juliosampaio.com`
  - `api` → `api.stage.juliosampaio.com`
  - `dashboard` → `dashboard.stage.juliosampaio.com`
  - `""` (empty) → `stage.juliosampaio.com`

## Advanced Usage

### 1. Custom Ingress Generation

For more complex scenarios, use the ingress generator:

```bash
# Generate custom ingress configuration
./k8s/environments/scripts/generate-ingress.sh myapp production api

# Apply the generated configuration
kubectl apply -f /tmp/myapp-production-ingress.yaml
```

### 2. Manual Kubernetes Deployment

You can also deploy manually using Kubernetes manifests:

```yaml
# myapp-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: production
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  tls:
    - hosts:
        - api.juliosampaio.com
      secretName: myapp-production-tls
  rules:
    - host: api.juliosampaio.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp-service
                port:
                  number: 80
```

### 3. Helm Chart with Custom Values

```bash
# Deploy with custom Helm values
helm upgrade --install myapp k8s/environments/helm-charts/app-template \
  --namespace production \
  --set app.name=myapp \
  --set app.image=myregistry/myapp \
  --set ingress.subdomain=api \
  --set deployment.replicas=3
```

## DNS Configuration

For each application you deploy, you need to add a DNS record pointing to your cluster IP:

```
# Production applications
juliosampaio.com → [Your Cluster IP]
app1.juliosampaio.com → [Your Cluster IP]
api.juliosampaio.com → [Your Cluster IP]
dashboard.juliosampaio.com → [Your Cluster IP]

# Stage applications
stage.juliosampaio.com → [Your Cluster IP]
app1.stage.juliosampaio.com → [Your Cluster IP]
api.stage.juliosampaio.com → [Your Cluster IP]
dashboard.stage.juliosampaio.com → [Your Cluster IP]
```

## Environment-Specific Configurations

### Production Environment

- **Rate Limiting**: 100 requests per second
- **Replicas**: 3+ for high availability
- **Resources**: Higher limits for production workloads
- **SSL**: Production Let's Encrypt certificates

### Stage Environment

- **Rate Limiting**: 50 requests per second
- **Replicas**: 1-2 for cost optimization
- **Resources**: Lower limits for testing
- **SSL**: Production Let's Encrypt certificates (same as production)

## Monitoring and Management

### Check All Applications

```bash
# View all applications across environments
kubectl get pods --all-namespaces -l app.kubernetes.io/name

# Check specific environment
kubectl get pods -n production
kubectl get pods -n stage

# Check ingress configurations
kubectl get ingress --all-namespaces
```

### Application Logs

```bash
# View application logs
kubectl logs -f deployment/myapp -n production
kubectl logs -f deployment/myapp -n stage

# View Traefik logs (routing)
kubectl logs -f -n kube-system -l app.kubernetes.io/name=traefik
```

### SSL Certificate Status

```bash
# Check certificate status for all applications
kubectl get certificates --all-namespaces

# Check specific application certificate
kubectl describe certificate myapp-production-tls -n production
```

## Common Patterns

### 1. API Applications

```bash
# Deploy API to production
./k8s/environments/helm-charts/deploy-app.sh my-api production api

# Deploy API to stage
./k8s/environments/helm-charts/deploy-app.sh my-api stage api
```

### 2. Dashboard Applications

```bash
# Deploy dashboard to production
./k8s/environments/helm-charts/deploy-app.sh dashboard production dashboard

# Deploy dashboard to stage
./k8s/environments/helm-charts/deploy-app.sh dashboard stage dashboard
```

### 3. Microservices

```bash
# Deploy multiple microservices
./k8s/environments/helm-charts/deploy-app.sh user-service production users
./k8s/environments/helm-charts/deploy-app.sh order-service production orders
./k8s/environments/helm-charts/deploy-app.sh payment-service production payments
```

### 4. Main Website

```bash
# Deploy main website (no subdomain)
./k8s/environments/helm-charts/deploy-app.sh main-website production "" production
./k8s/environments/helm-charts/deploy-app.sh main-website stage "" stage
```

## Troubleshooting

### Application Not Accessible

1. Check if the application is running:

   ```bash
   kubectl get pods -n production -l app=myapp
   ```

2. Check if the service exists:

   ```bash
   kubectl get services -n production
   ```

3. Check if the ingress is configured:

   ```bash
   kubectl get ingress -n production
   ```

4. Check DNS resolution:
   ```bash
   nslookup myapp.juliosampaio.com
   ```

### SSL Certificate Issues

1. Check certificate status:

   ```bash
   kubectl describe certificate myapp-production-tls -n production
   ```

2. Check cert-manager logs:
   ```bash
   kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
   ```

### Routing Issues

1. Check Traefik configuration:

   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
   ```

2. Check ingress status:
   ```bash
   kubectl describe ingress myapp-ingress -n production
   ```

## Best Practices

1. **Naming Convention**: Use consistent naming for applications and subdomains
2. **Environment Separation**: Keep production and stage environments completely separate
3. **Resource Management**: Use appropriate resource limits for each environment
4. **Monitoring**: Implement monitoring for all applications
5. **Backup**: Regular backups of configurations and data
6. **Security**: Implement network policies and RBAC
7. **Documentation**: Keep track of all deployed applications and their domains

## Next Steps

1. **Set up monitoring**: Deploy Prometheus and Grafana
2. **Implement CI/CD**: Automated deployment pipelines
3. **Add more environments**: Development, testing, etc.
4. **Security hardening**: Network policies, RBAC, secrets management
5. **Backup solutions**: Automated backup and disaster recovery
