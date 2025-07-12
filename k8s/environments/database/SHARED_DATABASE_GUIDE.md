# Shared Database Guide

This guide explains the shared PostgreSQL database approach for small applications in your Kubernetes cluster.

## 🎯 **Why Shared Database?**

### **Benefits for Small Applications**

- ✅ **Resource Efficiency**: One database server instead of multiple
- ✅ **Simpler Management**: Single backup, monitoring, and maintenance
- ✅ **Cost Effective**: Lower resource usage and licensing costs
- ✅ **Easier Networking**: Single endpoint for all apps
- ✅ **Consistent Environment**: Same database version across all apps

### **Perfect For**

- Small applications with low database usage
- Development and staging environments
- Applications that don't require extreme isolation
- Teams that want simplicity over complexity

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    Shared PostgreSQL                        │
│  (One instance per environment)                             │
├─────────────────────────────────────────────────────────────┤
│ • Production: postgres-service.production.svc.cluster.local │
│ • Stage: postgres-service.stage.svc.cluster.local          │
│ • Multiple databases per instance                           │
│ • Separate users per application                            │
│ • Kubernetes secrets for credentials                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Applications                             │
│  (Multiple apps sharing the same PostgreSQL instance)       │
├─────────────────────────────────────────────────────────────┤
│ • App1: example_app_db, example_app_user                   │
│ • App2: another_app_db, another_app_user                   │
│ • App3: third_app_db, third_app_user                       │
│ • Each app has its own database and user                   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Quick Start**

### 1. **Deploy PostgreSQL to Both Environments**

```bash
# Deploy PostgreSQL to production and stage
./k8s/environments/database/deploy-postgres.sh
```

### 2. **Create Database for Your Application**

```bash
# Create database for your app in production
./k8s/environments/database/create-app-database.sh myapp production

# Create database for your app in stage
./k8s/environments/database/create-app-database.sh myapp stage
```

### 3. **Deploy Your Application**

```bash
# Deploy your app (it will use the database credentials from the secret)
kubectl apply -f your-app-deployment.yaml -n production
```

## 📊 **Database Configuration**

### **PostgreSQL Instance Settings**

- **Image**: `postgres:15-alpine`
- **Resources**: 256Mi-512Mi RAM, 250m-500m CPU
- **Storage**: 10Gi persistent volume
- **Connections**: Up to 100 concurrent connections
- **Performance**: Optimized for small applications

### **Security Features**

- **Separate users** for each application
- **Database isolation** per application
- **Kubernetes secrets** for credential management
- **Network isolation** within cluster
- **Secure password generation** using OpenSSL
- **No hardcoded passwords** in configuration files

## 🔧 **Database Management**

### **Creating a New Database for an App**

```bash
# Basic usage
./k8s/environments/database/create-app-database.sh myapp production

# Custom database name and username
./k8s/environments/database/create-app-database.sh myapp production myapp_prod_db myapp_prod_user
```

### **What the Script Does**

1. **Creates a new database** for your application
2. **Creates a dedicated user** with secure password
3. **Grants appropriate permissions** to the user
4. **Creates a Kubernetes secret** with connection details
5. **Provides connection information** for your application

### **Generated Resources**

- **Database**: `myapp_db` (or custom name)
- **User**: `myapp_user` (or custom name)
- **Secret**: `myapp-db-secret` with connection details
- **Schema**: `myapp` for better organization

## 🔗 **Connecting Your Application**

### **Using Kubernetes Secrets**

Your application deployment should reference the database secret:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  template:
    spec:
      containers:
        - name: myapp
          image: myapp:latest
          env:
            - name: DATABASE_HOST
              valueFrom:
                secretKeyRef:
                  name: myapp-db-secret
                  key: DB_HOST
            - name: DATABASE_PORT
              valueFrom:
                secretKeyRef:
                  name: myapp-db-secret
                  key: DB_PORT
            - name: DATABASE_NAME
              valueFrom:
                secretKeyRef:
                  name: myapp-db-secret
                  key: DB_NAME
            - name: DATABASE_USER
              valueFrom:
                secretKeyRef:
                  name: myapp-db-secret
                  key: DB_USER
            - name: DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: myapp-db-secret
                  key: DB_PASSWORD
```

### **Connection Details**

**Production:**

```
Host: postgres-service.production.svc.cluster.local
Port: 5432
Database: myapp_db
Username: myapp_user
Password: [from secret]
```

**Stage:**

```
Host: postgres-service.stage.svc.cluster.local
Port: 5432
Database: myapp_db
Username: myapp_user
Password: [from secret]
```

## 📋 **Example Workflow**

### **Complete Application Deployment**

```bash
# 1. Deploy PostgreSQL (if not already done)
./k8s/environments/database/deploy-postgres.sh

# 2. Create database for your app
./k8s/environments/database/create-app-database.sh myapp production

# 3. Deploy your application
kubectl apply -f myapp-deployment.yaml -n production

# 4. Verify everything is working
kubectl get pods -n production -l app=myapp
kubectl logs -f deployment/myapp -n production
```

## 🔍 **Monitoring and Management**

### **Check Database Status**

```bash
# Check PostgreSQL pods
kubectl get pods -n production -l app=postgres
kubectl get pods -n stage -l app=postgres

# Check database services
kubectl get services -n production -l app=postgres
kubectl get services -n stage -l app=postgres

# Check persistent volumes
kubectl get pvc -n production
kubectl get pvc -n stage
```

### **Database Operations**

```bash
# Connect to PostgreSQL
kubectl exec -it deployment/postgres -n production -- psql -U postgres

# List databases
kubectl exec -it deployment/postgres -n production -- psql -U postgres -c "\l"

# List users
kubectl exec -it deployment/postgres -n production -- psql -U postgres -c "\du"
```

### **Backup and Restore**

```bash
# Backup a database
kubectl exec deployment/postgres -n production -- pg_dump -U postgres myapp_db > myapp_backup.sql

# Restore a database
kubectl exec -i deployment/postgres -n production -- psql -U postgres myapp_db < myapp_backup.sql
```

## ⚠️ **Limitations and Considerations**

### **Single Point of Failure**

- If PostgreSQL goes down, all apps are affected
- Consider monitoring and alerting
- Plan for backup and recovery

### **Resource Contention**

- Apps might compete for database resources
- Monitor performance and adjust resources if needed
- Consider connection pooling in your applications

### **Scaling Limitations**

- Harder to scale individual apps independently
- Consider this approach for small to medium workloads
- For high-traffic apps, consider dedicated databases

### **Security Considerations**

- All apps share the same PostgreSQL instance
- Ensure proper user permissions and database isolation
- Use Kubernetes secrets for credential management
- Consider network policies for additional isolation

## 🔄 **Migration Strategy**

### **From Individual Databases**

If you currently have individual databases per app:

1. **Deploy shared PostgreSQL**
2. **Create new databases** for each app
3. **Migrate data** from old to new databases
4. **Update application configurations**
5. **Test thoroughly** before switching
6. **Remove old databases**

### **To Dedicated Databases**

If you need to move to dedicated databases later:

1. **Deploy new PostgreSQL instances**
2. **Migrate data** to new instances
3. **Update application configurations**
4. **Remove from shared instance**

## 🛠️ **Troubleshooting**

### **Common Issues**

**Database Connection Failed**

```bash
# Check if PostgreSQL is running
kubectl get pods -n production -l app=postgres

# Check PostgreSQL logs
kubectl logs -f deployment/postgres -n production

# Test connection
kubectl exec deployment/postgres -n production -- pg_isready -U postgres
```

**Secret Not Found**

```bash
# Check if secret exists
kubectl get secrets -n production | grep db-secret

# Recreate the secret if needed
./k8s/environments/database/create-app-database.sh myapp production
```

**Permission Denied**

```bash
# Check user permissions
kubectl exec deployment/postgres -n production -- psql -U postgres -c "\du"

# Recreate database with proper permissions
./k8s/environments/database/create-app-database.sh myapp production
```

## 📚 **Best Practices**

### **Application Design**

1. **Use connection pooling** to manage database connections
2. **Implement proper error handling** for database failures
3. **Use transactions** for data consistency
4. **Monitor database performance** in your application

### **Security**

1. **Never hardcode credentials** in your application
2. **Use Kubernetes secrets** for all sensitive data
3. **Implement proper user permissions** in your database
4. **Regularly rotate passwords** for database users
5. **Secure password generation** - PostgreSQL passwords are generated using OpenSSL
6. **No hardcoded passwords** - All passwords are generated dynamically
7. **Environment isolation** - Production and stage use separate database instances

### **Monitoring**

1. **Monitor database performance** and resource usage
2. **Set up alerts** for database failures
3. **Regular backups** of your databases
4. **Monitor application database connections**

## 🎯 **Conclusion**

The shared database approach is **perfect for small applications** that need simplicity and resource efficiency. It provides:

- ✅ **Easy setup** and management
- ✅ **Resource efficiency** for small workloads
- ✅ **Consistent environment** across applications
- ✅ **Simple backup** and recovery procedures

For your use case with small applications, this approach will save resources, simplify management, and provide a solid foundation for your applications to grow.

Remember to monitor performance and be ready to scale to dedicated databases if your applications grow beyond the capacity of the shared instance.
