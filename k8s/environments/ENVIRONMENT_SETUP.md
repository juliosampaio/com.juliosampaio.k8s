# Multi-Environment Kubernetes Setup

This document explains how to set up and use multiple environments in your Kubernetes cluster using subdomain-based routing.

## Overview

Your cluster is configured to handle multiple environments through subdomain routing:

```
juliosampaio.com → production namespace
stage.juliosampaio.com → stage namespace
app.juliosampaio.com → production namespace (app service)
app.stage.juliosampaio.com → stage namespace (app service)
```

## Architecture

### Components

1. **Namespaces**: Separate namespaces for each environment

   - `production`: Production applications and services
   - `stage`: Staging applications and services

2. **Ingress Controllers**: Traefik handles routing based on hostnames

   - Automatic HTTP to HTTPS redirects
   - Environment-specific rate limiting
   - SSL certificate management

3. **SSL Certificates**: cert-manager automatically creates and renews certificates

   - Production domains: `juliosampaio.com`, `app.juliosampaio.com`
   - Stage domains: `stage.juliosampaio.com`, `app.stage.juliosampaio.com`

4. **Helm Charts**: Template-based deployment for consistent application deployment

## Quick Setup

### 1. Deploy Environments

```bash
# Run the environment setup script
./k8s/environments/deploy-environments.sh
```

This script will:

- Create production and stage namespaces
- Deploy ingress configurations for both environments
- Set up automatic SSL certificate generation

### 2. Configure DNS

Point your domains to your cluster IP address:

```
juliosampaio.com → [Your Cluster IP]
stage.juliosampaio.com → [Your Cluster IP]
app.juliosampaio.com → [Your Cluster IP]
app.stage.juliosampaio.com → [Your Cluster IP]
```

### 3. Deploy Applications

#### Using Helm Chart (Recommended)

```bash
# Deploy to production
./k8s/environments/helm-charts/deploy-app.sh my-app production

# Deploy to stage
./k8s/environments/helm-charts/deploy-app.sh my-app stage
```

#### Using Kubernetes Manifests

```bash
# Deploy to production
kubectl apply -f your-app-deployment.yaml -n production

# Deploy to stage
kubectl apply -f your-app-deployment.yaml -n stage
```

## Environment-Specific Configurations

### Production Environment

- **Rate Limiting**: 100 requests per second
- **Replicas**: 3+ for high availability
- **Resources**: Higher limits for production workloads
- **Domains**: `juliosampaio.com`, `app.juliosampaio.com`

### Stage Environment

- **Rate Limiting**: 50 requests per second
- **Replicas**: 1-2 for cost optimization
- **Resources**: Lower limits for testing
- **Domains**: `stage.juliosampaio.com`, `app.stage.juliosampaio.com`

## Application Deployment Examples

### Example 1: Simple Web Application

```yaml
# my-app-deployment.yaml
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
          image: nginx:alpine
          ports:
            - containerPort: 80
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
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: production # or stage
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  tls:
    - hosts:
        - app.juliosampaio.com # or app.stage.juliosampaio.com
      secretName: my-app-tls
  rules:
    - host: app.juliosampaio.com # or app.stage.juliosampaio.com
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

### Example 2: Using Helm Chart

```bash
# Deploy with custom values
helm upgrade --install my-app k8s/environments/helm-charts/app-template \
  --namespace production \
  --set app.name=my-app \
  --set app.image=my-registry/my-app \
  --set deployment.replicas=3 \
  --set ingress.hosts[0].host=app.juliosampaio.com
```

## Monitoring and Troubleshooting

### Check Environment Status

```bash
# View all namespaces
kubectl get namespaces

# Check ingress configurations
kubectl get ingress --all-namespaces

# Check SSL certificates
kubectl get certificates --all-namespaces

# Check application pods
kubectl get pods -n production
kubectl get pods -n stage
```

### View Logs

```bash
# Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Application logs
kubectl logs -n production -l app=my-app
```

### Common Issues

#### SSL Certificate Issues

```bash
# Check certificate status
kubectl describe certificate -n production

# Check cert-manager pods
kubectl get pods -n cert-manager
```

#### Routing Issues

```bash
# Check ingress status
kubectl describe ingress -n production

# Check Traefik configuration
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

#### Application Issues

```bash
# Check pod status
kubectl get pods -n production

# Check service endpoints
kubectl get endpoints -n production

# Check application logs
kubectl logs -f deployment/my-app -n production
```

## Security Considerations

### Network Policies

Consider implementing network policies to restrict inter-namespace communication:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### RBAC

Use role-based access control to limit access to different environments:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: app-developer
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
```

### Secrets Management

Use Kubernetes secrets or external secret managers for sensitive data:

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

## Backup and Recovery

### Backup Configurations

```bash
# Backup ingress configurations
kubectl get ingress -n production -o yaml > production-ingress-backup.yaml
kubectl get ingress -n stage -o yaml > stage-ingress-backup.yaml

# Backup application deployments
kubectl get deployment -n production -o yaml > production-deployments-backup.yaml
kubectl get deployment -n stage -o yaml > stage-deployments-backup.yaml
```

### Restore Configurations

```bash
# Restore from backup
kubectl apply -f production-ingress-backup.yaml
kubectl apply -f stage-ingress-backup.yaml
```

## Scaling and Performance

### Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
```

## Best Practices

1. **Environment Isolation**: Keep production and stage environments completely separate
2. **Configuration Management**: Use ConfigMaps and Secrets for environment-specific configuration
3. **Monitoring**: Implement comprehensive monitoring for both environments
4. **Backup Strategy**: Regular backups of configurations and data
5. **Security**: Implement network policies and RBAC
6. **Testing**: Always test changes in stage before deploying to production
7. **Documentation**: Keep deployment procedures and configurations documented

## Next Steps

1. **Set up monitoring**: Deploy Prometheus and Grafana for comprehensive monitoring
2. **Implement CI/CD**: Set up automated deployment pipelines
3. **Add more environments**: Create development or testing environments as needed
4. **Implement backup solutions**: Set up automated backup and disaster recovery
5. **Security hardening**: Implement additional security measures like network policies
