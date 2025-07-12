# Kubernetes Infrastructure with Shared Database

This repository manages a Kubernetes cluster configured with k3s, Traefik ingress controller, cert-manager for automatic SSL certificates, and shared PostgreSQL databases for small applications.

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (k3s)                 │
├─────────────────────────────────────────────────────────────┤
│ • Traefik Ingress Controller                                │
│ • cert-manager (Let's Encrypt SSL)                          │
│ • Multi-environment support (production/stage)              │
│ • Shared PostgreSQL databases per environment               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Environments                             │
├─────────────────────────────────────────────────────────────┤
│ Production: juliosampaio.com                                │
│ • Namespace: production                                      │
│ • PostgreSQL: postgres-service.production.svc.cluster.local │
│ • Apps: app1.juliosampaio.com, app2.juliosampaio.com, etc.  │
│                                                                 │
│ Stage: stage.juliosampaio.com                                │
│ • Namespace: stage                                           │
│ • PostgreSQL: postgres-service.stage.svc.cluster.local      │
│ • Apps: app1.stage.juliosampaio.com, etc.                   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Quick Start**

### **1. Deploy Infrastructure**

The GitHub Actions workflow automatically deploys:

- k3s cluster with Traefik and cert-manager
- Production and stage namespaces
- Shared PostgreSQL databases in both environments
- Base ingress configurations

### **2. Deploy Your Application**

```bash
# Create database for your app
./k8s/environments/database/create-app-database.sh myapp production

# Deploy your application
kubectl apply -f your-app-deployment.yaml -n production
```

### **3. Access Your Application**

- **Production**: `https://myapp.juliosampaio.com`
- **Stage**: `https://myapp.stage.juliosampaio.com`

## 🗄️ **Shared Database Approach**

### **Why Shared PostgreSQL?**

- ✅ **Resource Efficiency**: One database server instead of multiple
- ✅ **Simpler Management**: Single backup, monitoring, and maintenance
- ✅ **Cost Effective**: Lower resource usage for small applications
- ✅ **Easier Networking**: Single endpoint for all apps
- ✅ **Consistent Environment**: Same database version across all apps

### **Perfect For Small Applications**

- Applications with low database usage
- Development and staging environments
- Teams that want simplicity over complexity
- Resource-constrained environments

### **Database Management**

```bash
# Create database for a new app
./k8s/environments/database/create-app-database.sh myapp production

# This creates:
# • Database: myapp_db
# • User: myapp_user
# • Secret: myapp-db-secret (with connection details)
# • Schema: myapp (for organization)
```

### **Connection Details**

**Production:**

```
Host: postgres-service.production.svc.cluster.local
Port: 5432
Database: myapp_db
Username: myapp_user
Password: [from Kubernetes secret]
```

**Stage:**

```
Host: postgres-service.stage.svc.cluster.local
Port: 5432
Database: myapp_db
Username: myapp_user
Password: [from Kubernetes secret]
```

## 📁 **Repository Structure**

```
com.juliosampaio.k8s/
├── .github/workflows/
│   └── ConfigureVPS.yaml          # Automated deployment workflow
├── k8s/environments/
│   ├── database/
│   │   ├── postgres-deployment.yaml    # PostgreSQL deployment template
│   │   ├── create-app-database.sh      # Database creation script
│   │   ├── deploy-postgres.sh          # PostgreSQL deployment script
│   │   ├── example-app-with-db.yaml    # Example app using shared DB
│   │   ├── backup-endpoints.yaml       # Backup service endpoints for n8n
│   │   ├── backup-script.sh            # Automated backup script
│   │   ├── get-db-passwords.sh         # Password retrieval script
│   │   ├── SHARED_DATABASE_GUIDE.md    # Comprehensive database guide
│   │   ├── PASSWORD_MANAGEMENT.md      # Password management guide
│   │   └── n8n-backup-guide.md         # n8n backup workflow guide
│   ├── helm-charts/
│   │   └── app-template/               # Helm chart for app deployment
│   └── ingress-templates/              # Ingress configuration templates
├── hosts/
│   ├── k8s-cluster-main.nix           # Main cluster node configuration
│   └── k8s-cluster-node-1.nix         # Worker node configuration
├── flake.nix                          # Nix flake configuration
└── README.md                          # This file
```

## 🔧 **Configuration**

### **Environment Variables**

The following secrets are required in GitHub:

- `K8S_CLUSTER_MAIN_IP`: Main cluster node IP
- `K8S_CLUSTER_MAIN_USER`: Main cluster node username
- `K8S_CLUSTER_MAIN_PASSWORD`: Main cluster node password
- `K8S_CLUSTER_NODE1_IP`: Worker node IP
- `K8S_CLUSTER_NODE1_USER`: Worker node username
- `K8S_CLUSTER_NODE1_PASSWORD`: Worker node password
- `K3S_CLUSTER_TOKEN`: k3s cluster token
- `LETSENCRYPT_EMAIL`: Email for Let's Encrypt certificates
- `SSH_PRIVATE_KEY`: SSH key for secure deployment

### **Domain Configuration**

- **Production**: `juliosampaio.com`
- **Stage**: `stage.juliosampaio.com`
- **App subdomains**: `app1.juliosampaio.com`, `app2.juliosampaio.com`, etc.

## 📚 **Documentation**

- **[Shared Database Guide](k8s/environments/database/SHARED_DATABASE_GUIDE.md)**: Comprehensive guide for the shared database approach
- **[Password Management](k8s/environments/database/PASSWORD_MANAGEMENT.md)**: Secure password handling and retrieval
- **[n8n Backup Guide](k8s/environments/database/n8n-backup-guide.md)**: Automated backup workflows with n8n
- **[Architecture Documentation](docs/architecture.md)**: Detailed architecture overview
- **[GitHub Actions Documentation](docs/github-actions.md)**: Workflow and automation details

## 🔄 **Workflow**

### **Automated Deployment**

1. **Push to main branch** triggers GitHub Actions
2. **Deploy k3s cluster** with Traefik and cert-manager
3. **Create environments** (production/stage namespaces)
4. **Deploy PostgreSQL** to both environments
5. **Set up ingress** configurations
6. **Ready for applications** to be deployed

### **Application Deployment**

1. **Create database** for your application
2. **Deploy application** using kubectl or Helm
3. **Configure ingress** for external access
4. **Access via HTTPS** with automatic SSL certificates

## 🛠️ **Management Commands**

### **Database Operations**

```bash
# Get database passwords
./k8s/environments/database/get-db-passwords.sh

# Check PostgreSQL status
kubectl get pods -n production -l app=postgres
kubectl get pods -n stage -l app=postgres

# Connect to PostgreSQL
kubectl exec -it deployment/postgres -n production -- psql -U postgres

# List databases
kubectl exec -it deployment/postgres -n production -- psql -U postgres -c "\l"

# Manual backup
kubectl exec deployment/postgres -n production -- pg_dump -U postgres myapp_db > backup.sql

# Automated backup (for n8n)
./k8s/environments/database/backup-script.sh production /tmp/backups 7
```

### **Application Management**

```bash
# Deploy application
kubectl apply -f app-deployment.yaml -n production

# Check application status
kubectl get pods -n production -l app=myapp

# View application logs
kubectl logs -f deployment/myapp -n production

# Access application shell
kubectl exec -it deployment/myapp -n production -- /bin/bash
```

## ⚠️ **Limitations and Considerations**

### **Shared Database Limitations**

- **Single point of failure**: If PostgreSQL goes down, all apps are affected
- **Resource contention**: Apps might compete for database resources
- **Scaling limitations**: Harder to scale individual apps independently
- **Security considerations**: All apps share the same PostgreSQL instance
- **Secure password generation**: PostgreSQL passwords are generated using OpenSSL
- **Idempotent password management**: Passwords are preserved across deployments
- **No hardcoded passwords**: All passwords are generated dynamically and stored securely

### **When to Consider Dedicated Databases**

- High-traffic applications
- Applications requiring extreme isolation
- Compliance requirements for data separation
- Performance-critical applications

## 🤝 **Contributing**

This infrastructure is designed to be **external application friendly**. External repositories can:

1. **Deploy applications** without modifying this infrastructure repo
2. **Use shared databases** by creating app-specific databases
3. **Configure ingress** for their applications
4. **Manage their own deployments** independently

## 📞 **Support**

For questions about:

- **Infrastructure setup**: Check the documentation in `docs/`
- **Database usage**: See `k8s/environments/database/SHARED_DATABASE_GUIDE.md`
- **Application deployment**: Use the provided templates and scripts
- **Troubleshooting**: Check the troubleshooting sections in the guides

---

**Note**: This infrastructure is designed for small applications. For larger applications or production workloads, consider dedicated database instances or managed database services.
