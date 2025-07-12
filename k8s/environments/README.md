# Kubernetes Environment Setup

This directory contains the configuration for managing multiple environments in your Kubernetes cluster using subdomain-based routing.

## Environment Structure

```
juliosampaio.com -> production namespace
stage.juliosampaio.com -> stage namespace
app.juliosampaio.com -> production namespace (app service)
app.stage.juliosampaio.com -> stage namespace (app service)
```

## Quick Start

1. **Deploy the environments:**

   ```bash
   ./k8s/environments/deploy-environments.sh
   ```

2. **Point your domains to your cluster IP:**

   - `juliosampaio.com` → Your cluster IP
   - `stage.juliosampaio.com` → Your cluster IP
   - `app.juliosampaio.com` → Your cluster IP
   - `app.stage.juliosampaio.com` → Your cluster IP

3. **Deploy your applications:**

   ```bash
   # Production
   kubectl apply -f your-app-deployment.yaml -n production

   # Stage
   kubectl apply -f your-app-deployment.yaml -n stage
   ```

## Architecture

### Namespaces

- **`production`**: Contains production applications and services
- **`stage`**: Contains staging applications and services

### Ingress Configuration

Each environment has its own ingress configuration that:

- Automatically generates SSL certificates via Let's Encrypt
- Routes traffic based on hostnames
- Applies environment-specific rate limiting
- Uses Traefik as the ingress controller

### Automatic SSL Certificates

cert-manager automatically creates and renews SSL certificates for:

- `juliosampaio.com` and `app.juliosampaio.com` (production)
- `stage.juliosampaio.com` and `app.stage.juliosampaio.com` (stage)

## Application Deployment

### Template Structure

Use the sample template in `app-templates/sample-app-deployment.yaml` as a starting point:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app
  namespace: production # or stage
spec:
  # ... deployment spec
---
apiVersion: v1
kind: Service
metadata:
  name: your-app-service
  namespace: production # or stage
spec:
  # ... service spec
```

### Deployment Commands

```bash
# Deploy to production
kubectl apply -f your-app.yaml -n production

# Deploy to stage
kubectl apply -f your-app.yaml -n stage

# Check deployment status
kubectl get pods -n production
kubectl get pods -n stage
```

## Monitoring and Troubleshooting

### Check Ingress Status

```bash
# View all ingress resources
kubectl get ingress --all-namespaces

# Check specific environment
kubectl get ingress -n production
kubectl get ingress -n stage
```

### Check SSL Certificates

```bash
# View certificate status
kubectl get certificates --all-namespaces

# Check certificate details
kubectl describe certificate production-tls -n production
kubectl describe certificate stage-tls -n stage
```

### Check Traefik Logs

```bash
# View Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Follow logs in real-time
kubectl logs -f -n kube-system -l app.kubernetes.io/name=traefik
```

### Check cert-manager Logs

```bash
# View cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

## Environment-Specific Configuration

### Production Environment

- **Rate Limiting**: 100 requests per second
- **Replicas**: Typically 2+ for high availability
- **Resource Limits**: Higher limits for production workloads

### Stage Environment

- **Rate Limiting**: 50 requests per second
- **Replicas**: Typically 1-2 for cost optimization
- **Resource Limits**: Lower limits for testing

## Customization

### Adding New Environments

1. Create a new namespace in `namespaces.yaml`
2. Create a new ingress template in `ingress-templates/`
3. Update the deployment script if needed

### Adding New Subdomains

1. Update the appropriate ingress template
2. Add the new hostname to the TLS configuration
3. Add routing rules for the new subdomain

### Environment Variables

You can use ConfigMaps and Secrets to manage environment-specific configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  DATABASE_URL: "production-db-url"
  API_KEY: "production-api-key"
```

## Security Considerations

1. **Network Policies**: Consider implementing network policies to restrict inter-namespace communication
2. **RBAC**: Use role-based access control to limit access to different environments
3. **Secrets Management**: Use Kubernetes secrets or external secret managers for sensitive data
4. **Rate Limiting**: Already configured in ingress templates

## Backup and Recovery

### Backup Ingress Configurations

```bash
kubectl get ingress -n production -o yaml > production-ingress-backup.yaml
kubectl get ingress -n stage -o yaml > stage-ingress-backup.yaml
```

### Restore Configurations

```bash
kubectl apply -f production-ingress-backup.yaml
kubectl apply -f stage-ingress-backup.yaml
```

## Troubleshooting Common Issues

### Certificate Issues

- Check if DNS is properly configured
- Verify cert-manager is running: `kubectl get pods -n cert-manager`
- Check certificate events: `kubectl describe certificate -n production`

### Routing Issues

- Verify Traefik is running: `kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik`
- Check ingress status: `kubectl describe ingress -n production`
- Verify DNS resolution to your cluster IP

### Application Issues

- Check pod status: `kubectl get pods -n production`
- View application logs: `kubectl logs -f deployment/your-app -n production`
- Check service endpoints: `kubectl get endpoints -n production`
