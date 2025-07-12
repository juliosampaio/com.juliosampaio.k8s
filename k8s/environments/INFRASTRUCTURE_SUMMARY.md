# Infrastructure Summary

This document provides an overview of the complete infrastructure setup and how it supports external application deployments.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                      │
│  (This Repository - com.juliosampaio.k8s)                   │
├─────────────────────────────────────────────────────────────┤
│ • Kubernetes Cluster (k3s)                                   │
│ • Traefik Ingress Controller                                 │
│ • cert-manager (SSL Certificates)                           │
│ • Production & Stage Namespaces                              │
│ • Base Ingress Configurations                                │
│ • Environment-Specific Settings                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  (External Repositories - app1, app2, etc.)                 │
├─────────────────────────────────────────────────────────────┤
│ • Application Deployments                                    │
│ • Application Services                                       │
│ • Application-Specific Ingress                               │
│ • Application Configurations                                 │
└─────────────────────────────────────────────────────────────┘
```

## What This Repository Provides

### 1. **Kubernetes Cluster Infrastructure**

- **k3s**: Lightweight, production-ready Kubernetes distribution
- **Control Plane**: Single master node with etcd
- **Worker Nodes**: Scalable worker nodes
- **Nix-built**: Reproducible and reliable system components

### 2. **Ingress & HTTPS Infrastructure**

- **Traefik**: Modern ingress controller with automatic HTTP→HTTPS redirects
- **cert-manager**: Automatic SSL certificate management via Let's Encrypt
- **Hybrid approach**: Nix for k3s, official binaries for Helm

### 3. **Multi-Environment Support**

- **Production Namespace**: `production`
- **Stage Namespace**: `stage`
- **Automatic SSL**: Certificates for all subdomains
- **Environment-Specific Configurations**: Rate limiting, resources, etc.

### 4. **Base Ingress Configurations**

- **Production**: `juliosampaio.com`, `app1.juliosampaio.com`
- **Stage**: `stage.juliosampaio.com`, `app1.stage.juliosampaio.com`
- **Extensible**: Easy to add new subdomains

## What External Repositories Handle

### 1. **Application Deployments**

- Application containers and images
- Deployment configurations
- Service definitions
- Application-specific ingress rules

### 2. **Application Configuration**

- Environment variables
- Secrets management
- Application-specific settings
- Health checks and monitoring

### 3. **CI/CD Pipelines**

- Build and test processes
- Image building and pushing
- Deployment automation
- Rollback procedures

## Idempotent Infrastructure Setup

The infrastructure is set up **automatically and idempotently** through GitHub Actions:

### 1. **Cluster Deployment** (`deploy` job)

- Installs Nix on all nodes
- Builds and deploys k3s binaries
- Configures cluster networking
- Sets up control plane and worker nodes

### 2. **Ingress & Environment Setup** (`deploy-ingress` job)

- Installs Traefik ingress controller
- Installs cert-manager for SSL certificates
- Creates production and stage namespaces
- Deploys base ingress configurations
- Sets up Let's Encrypt ClusterIssuer

### 3. **Idempotent Operations**

- **Safe to re-run**: All operations are idempotent
- **No manual intervention**: Fully automated
- **Consistent state**: Always converges to desired state
- **Error recovery**: Handles failures gracefully

## Environment Configuration

### Production Environment

```yaml
Namespace: production
Domain Pattern: {subdomain}.juliosampaio.com
Rate Limiting: 100 requests/second
Resources: Higher limits
Replicas: 3+ recommended
SSL: Production Let's Encrypt certificates
```

### Stage Environment

```yaml
Namespace: stage
Domain Pattern: {subdomain}.stage.juliosampaio.com
Rate Limiting: 50 requests/second
Resources: Lower limits for cost optimization
Replicas: 1-2 for testing
SSL: Production Let's Encrypt certificates
```

## External Deployment Workflow

### 1. **Infrastructure Ready**

- Cluster is running and healthy
- Traefik is handling ingress traffic
- cert-manager is managing SSL certificates
- Production and stage namespaces exist
- Base ingress configurations are deployed

### 2. **External Repository Deployment**

```bash
# External repository deploys application
kubectl apply -f app-deployment.yaml -n production
kubectl apply -f app-service.yaml -n production
kubectl apply -f app-ingress.yaml -n production
```

### 3. **Automatic Integration**

- Traefik automatically routes traffic to the new service
- cert-manager automatically creates SSL certificate
- Application is accessible via configured subdomain
- Health checks and monitoring work automatically

## Benefits of This Architecture

### 1. **Separation of Concerns**

- **Infrastructure**: Managed centrally in this repository
- **Applications**: Managed by individual application repositories
- **Clear boundaries**: No overlap in responsibilities

### 2. **Scalability**

- **Add applications**: External repositories can deploy independently
- **Add environments**: Easy to add new environments (dev, testing, etc.)
- **Add nodes**: Scale cluster horizontally as needed

### 3. **Reliability**

- **Idempotent**: Safe to re-run infrastructure setup
- **Automated**: No manual intervention required
- **Consistent**: Same state every time

### 4. **Security**

- **SSL certificates**: Automatic and secure
- **Namespace isolation**: Applications are isolated by environment
- **RBAC**: Can implement role-based access control
- **Network policies**: Can restrict inter-namespace communication

### 5. **Developer Experience**

- **Simple deployment**: External repositories have clear deployment paths
- **Flexible subdomains**: Any subdomain pattern supported
- **Automatic HTTPS**: No manual certificate management
- **Environment parity**: Production and stage are identical

## Monitoring and Observability

### 1. **Infrastructure Monitoring**

- **Cluster health**: Node status, pod status
- **Ingress traffic**: Traefik metrics and logs
- **SSL certificates**: Certificate status and renewal
- **Resource usage**: CPU, memory, disk usage

### 2. **Application Monitoring**

- **Application health**: Pod status, service endpoints
- **Application logs**: Container logs and error tracking
- **Application metrics**: Custom application metrics
- **Traffic patterns**: Request patterns and performance

## Troubleshooting

### 1. **Infrastructure Issues**

- Check cluster status: `kubectl get nodes`
- Check Traefik: `kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik`
- Check cert-manager: `kubectl get pods -n cert-manager`
- Check namespaces: `kubectl get namespaces`

### 2. **Application Issues**

- Check application pods: `kubectl get pods -n production`
- Check application services: `kubectl get services -n production`
- Check application ingress: `kubectl get ingress -n production`
- Check application logs: `kubectl logs -f deployment/app-name -n production`

## Future Enhancements

### 1. **Additional Environments**

- Development environment
- Testing environment
- Staging environment
- Canary deployments

### 2. **Advanced Features**

- Service mesh (Istio, Linkerd)
- Advanced monitoring (Prometheus, Grafana)
- Backup and disaster recovery
- Multi-cluster support

### 3. **Security Enhancements**

- Network policies
- Pod security policies
- Admission controllers
- Secrets management

## Conclusion

This infrastructure setup provides a **robust, scalable, and maintainable** foundation for running multiple applications across different environments. The separation between infrastructure and application layers ensures clear responsibilities, while the automated setup process ensures consistency and reliability.

External repositories can focus on their applications while leveraging the shared infrastructure for ingress, SSL certificates, and environment management. The system is designed to be **self-service** for application teams while maintaining **centralized control** over the infrastructure layer.
