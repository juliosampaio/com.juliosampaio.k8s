# External Application Deployment Guide

This guide explains how external repositories can deploy applications to the Kubernetes cluster managed by this repository.

## Overview

This repository provides the **infrastructure layer** (cluster, ingress, SSL certificates, environments). External repositories handle the **application layer** (deployments, services, application-specific configurations).

## Prerequisites

### 1. Cluster Access

Your CI/CD pipeline needs access to the cluster. You can achieve this by:

- **SSH Access**: SSH to the cluster and use kubectl locally
- **Kubeconfig**: Copy the kubeconfig file to your CI/CD environment
- **Service Account**: Create a Kubernetes service account with appropriate permissions

### 2. Required Tools

- `kubectl` (compatible with k3s version)
- `helm` (optional, for Helm-based deployments)

## Deployment Methods

### Method 1: Direct Kubernetes Manifests

Create your application deployment files and apply them directly:

```yaml
# app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production # or stage
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-registry/my-app:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  namespace: production # or stage
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 80
```

Deploy using:

```bash
kubectl apply -f app-deployment.yaml
```

### Method 2: Helm Chart (Recommended)

Use the provided Helm chart template:

```bash
# Deploy to production
helm upgrade --install my-app k8s/environments/helm-charts/app-template \
  --namespace production \
  --set app.name=my-app \
  --set app.image=my-registry/my-app \
  --set app.tag=latest \
  --set ingress.subdomain=myapp \
  --set deployment.replicas=2

# Deploy to stage
helm upgrade --install my-app k8s/environments/helm-charts/app-template \
  --namespace stage \
  --set app.name=my-app \
  --set app.image=my-registry/my-app \
  --set app.tag=latest \
  --set ingress.subdomain=myapp \
  --set deployment.replicas=1
```

### Method 3: Using the Deployment Script

If you have access to the cluster repository scripts:

```bash
# Deploy to production
./k8s/environments/helm-charts/deploy-app.sh my-app production myapp

# Deploy to stage
./k8s/environments/helm-charts/deploy-app.sh my-app stage myapp
```

## Environment-Specific Configurations

### Production Environment

- **Namespace**: `production`
- **Domain Pattern**: `{subdomain}.juliosampaio.com`
- **Rate Limiting**: 100 requests per second
- **Resources**: Higher limits recommended
- **Replicas**: 2+ for high availability

### Stage Environment

- **Namespace**: `stage`
- **Domain Pattern**: `{subdomain}.stage.juliosampaio.com`
- **Rate Limiting**: 50 requests per second
- **Resources**: Lower limits for cost optimization
- **Replicas**: 1-2 for testing

## Adding New Subdomains

### Option 1: Update Ingress Configuration

If you have access to the cluster repository, you can update the ingress configurations:

```bash
# Add new subdomain to production
./k8s/environments/ingress-templates/dynamic-ingress-setup.sh production myapp myapp-service

# Add new subdomain to stage
./k8s/environments/ingress-templates/dynamic-ingress-setup.sh stage myapp myapp-service
```

### Option 2: Create Separate Ingress

Create your own ingress resource for your application:

```yaml
# my-app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: production # or stage
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  tls:
    - hosts:
        - myapp.juliosampaio.com # or myapp.stage.juliosampaio.com
      secretName: my-app-tls
  rules:
    - host: myapp.juliosampaio.com # or myapp.stage.juliosampaio.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

## CI/CD Integration Examples

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: "latest"

      - name: Configure kubectl
        run: |
          # Copy kubeconfig from cluster or use service account
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config
          chmod 600 ~/.kube/config

      - name: Deploy to stage
        run: |
          kubectl apply -f k8s/deployment.yaml -n stage
          kubectl apply -f k8s/service.yaml -n stage
          kubectl apply -f k8s/ingress.yaml -n stage

      - name: Wait for deployment
        run: |
          kubectl wait --for=condition=available deployment/my-app -n stage --timeout=300s
```

### GitLab CI Example

```yaml
# .gitlab-ci.yml
stages:
  - deploy

deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl apply -f k8s/deployment.yaml -n production
    - kubectl apply -f k8s/service.yaml -n production
    - kubectl apply -f k8s/ingress.yaml -n production
    - kubectl wait --for=condition=available deployment/my-app -n production --timeout=300s
  only:
    - main
```

## DNS Configuration

For each application you deploy, add DNS records pointing to the cluster IP:

```
# Production applications
myapp.juliosampaio.com → [Cluster IP]
api.juliosampaio.com → [Cluster IP]
dashboard.juliosampaio.com → [Cluster IP]

# Stage applications
myapp.stage.juliosampaio.com → [Cluster IP]
api.stage.juliosampaio.com → [Cluster IP]
dashboard.stage.juliosampaio.com → [Cluster IP]
```

## Security Considerations

### 1. Service Account Permissions

Create a service account with minimal required permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-deployer
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-deployer
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-deployer-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: external-deployer
    namespace: production
roleRef:
  kind: Role
  name: app-deployer
  apiGroup: rbac.authorization.k8s.io
```

### 2. Secrets Management

Use Kubernetes secrets for sensitive data:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
data:
  database-url: <base64-encoded-value>
  api-key: <base64-encoded-value>
```

### 3. Network Policies

Consider implementing network policies to restrict communication:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: production
      ports:
        - protocol: TCP
          port: 80
```

## Monitoring and Troubleshooting

### Check Application Status

```bash
# Check deployment status
kubectl get deployments -n production
kubectl get deployments -n stage

# Check pod status
kubectl get pods -n production -l app=my-app
kubectl get pods -n stage -l app=my-app

# Check service status
kubectl get services -n production
kubectl get services -n stage

# Check ingress status
kubectl get ingress -n production
kubectl get ingress -n stage
```

### View Application Logs

```bash
# View application logs
kubectl logs -f deployment/my-app -n production
kubectl logs -f deployment/my-app -n stage

# View logs from specific pod
kubectl logs -f pod/my-app-xyz123 -n production
```

### Check SSL Certificates

```bash
# Check certificate status
kubectl get certificates -n production
kubectl get certificates -n stage

# Check certificate details
kubectl describe certificate my-app-tls -n production
```

### Common Issues

1. **Application not accessible**:

   - Check if pods are running: `kubectl get pods -n production`
   - Check if service exists: `kubectl get services -n production`
   - Check if ingress is configured: `kubectl get ingress -n production`
   - Check DNS resolution: `nslookup myapp.juliosampaio.com`

2. **SSL certificate issues**:

   - Check certificate status: `kubectl describe certificate -n production`
   - Check cert-manager logs: `kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager`

3. **Routing issues**:
   - Check Traefik logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=traefik`
   - Check ingress status: `kubectl describe ingress -n production`

## Best Practices

1. **Environment Separation**: Keep production and stage deployments completely separate
2. **Resource Management**: Use appropriate resource limits for each environment
3. **Health Checks**: Implement liveness and readiness probes
4. **Rolling Updates**: Use rolling update strategy for zero-downtime deployments
5. **Monitoring**: Implement application monitoring and alerting
6. **Backup**: Regular backups of application data and configurations
7. **Security**: Use secrets for sensitive data, implement RBAC
8. **Documentation**: Keep deployment procedures documented

## Support

For issues related to:

- **Cluster infrastructure**: Contact the cluster repository maintainers
- **Application deployment**: Check this guide and Kubernetes documentation
- **SSL certificates**: Check cert-manager documentation
- **Ingress routing**: Check Traefik documentation
