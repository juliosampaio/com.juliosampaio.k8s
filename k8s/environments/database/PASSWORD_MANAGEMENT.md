# Database Password Management

This guide explains how to manage and access PostgreSQL passwords in your shared database setup.

## 🔐 **Password Generation Strategy**

### **How Passwords Work**

- **Dynamic Generation**: Passwords are generated using OpenSSL during deployment
- **Unique per Environment**: Production and stage have different passwords
- **Secure Storage**: Passwords are stored in Kubernetes secrets
- **No Repository Storage**: Passwords are never committed to the repository

### **Password Lifecycle**

1. **First Deployment**: Password generated during GitHub Actions workflow
2. **Storage**: Password stored in Kubernetes secret
3. **Access**: Applications use the secret for database connections
4. **Subsequent Deployments**: Existing password is preserved (idempotent)
5. **Manual Rotation**: New password generated only when explicitly requested

## 🔍 **How to Access Passwords**

### **Method 1: Using the Password Retrieval Script (Recommended)**

```bash
# Run the password retrieval script
./k8s/environments/database/get-db-passwords.sh
```

This script will:

- ✅ Check if PostgreSQL is deployed in both environments
- ✅ Retrieve passwords from Kubernetes secrets
- ✅ Display connection details
- ✅ Show usage examples

### **Method 2: Manual kubectl Commands**

```bash
# Get production password
kubectl get secret postgres-secret -n production -o jsonpath='{.data.postgres-password}' | base64 -d

# Get stage password
kubectl get secret postgres-secret -n stage -o jsonpath='{.data.postgres-password}' | base64 -d
```

### **Method 3: GitHub Actions Logs**

During deployment, the GitHub Actions workflow will log the password:

```
Generated secure PostgreSQL password
PostgreSQL Password: [actual-password-here]
⚠️  Save this password securely - it won't be shown again!
```

**Note**: This is only visible during the deployment run and won't be stored permanently.

## 🛠️ **Password Management Commands**

### **Check if PostgreSQL is Deployed**

```bash
# Check production
kubectl get pods -n production -l app=postgres

# Check stage
kubectl get pods -n stage -l app=postgres
```

### **Verify Secrets Exist**

```bash
# Check production secret
kubectl get secret postgres-secret -n production

# Check stage secret
kubectl get secret postgres-secret -n stage
```

### **Connect to Databases**

```bash
# Connect to production
kubectl exec -it deployment/postgres -n production -- psql -U postgres

# Connect to stage
kubectl exec -it deployment/postgres -n stage -- psql -U postgres
```

### **List Databases**

```bash
# List production databases
kubectl exec deployment/postgres -n production -- psql -U postgres -c '\l'

# List stage databases
kubectl exec deployment/postgres -n stage -- psql -U postgres -c '\l'
```

## 🔄 **Password Rotation**

### **Automatic Rotation**

Passwords are **preserved** on subsequent deployments:

- **First deployment** = New password generated
- **Subsequent deployments** = Existing password preserved
- **Applications** maintain their database connections
- **Manual rotation** required for password changes

### **Manual Password Rotation**

If you need to rotate passwords manually:

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)
NEW_PASSWORD_B64=$(echo -n "$NEW_PASSWORD" | base64)

# Update production secret
kubectl patch secret postgres-secret -n production -p="{\"data\":{\"postgres-password\":\"$NEW_PASSWORD_B64\"}}"

# Update stage secret
kubectl patch secret postgres-secret -n stage -p="{\"data\":{\"postgres-password\":\"$NEW_PASSWORD_B64\"}}"

# Restart PostgreSQL to pick up new password
kubectl rollout restart deployment/postgres -n production
kubectl rollout restart deployment/postgres -n stage
```

## 🚨 **Important Security Notes**

### **Password Security**

- ✅ **Never commit passwords** to the repository
- ✅ **Use Kubernetes secrets** for storage
- ✅ **Rotate passwords regularly**
- ✅ **Limit access** to password retrieval scripts
- ✅ **Monitor access** to database secrets

### **Access Control**

- 🔒 **Only authorized users** should access passwords
- 🔒 **Use RBAC** to control access to secrets
- 🔒 **Monitor secret access** with audit logs
- 🔒 **Consider external secret management** for production

## 📋 **Best Practices**

### **For Development**

1. **Use the password retrieval script** to get current passwords
2. **Save passwords securely** in a password manager
3. **Rotate passwords** after team member changes
4. **Use different passwords** for different environments

### **For Production**

1. **Use external secret management** (HashiCorp Vault, AWS Secrets Manager)
2. **Implement password rotation** policies
3. **Monitor secret access** and changes
4. **Use service accounts** with minimal permissions
5. **Regular security audits** of database access

### **For Applications**

1. **Use Kubernetes secrets** for database credentials
2. **Implement connection pooling** to manage connections
3. **Handle password changes** gracefully in applications
4. **Use health checks** to detect connection issues

## 🔧 **Troubleshooting**

### **Password Not Found**

```bash
# Check if secret exists
kubectl get secrets -n production | grep postgres

# Check if PostgreSQL is running
kubectl get pods -n production -l app=postgres

# Recreate secret if needed
kubectl delete secret postgres-secret -n production
kubectl create secret generic postgres-secret -n production --from-literal=postgres-password=$(openssl rand -base64 32)
```

### **Connection Issues**

```bash
# Test database connection
kubectl exec deployment/postgres -n production -- pg_isready -U postgres

# Check PostgreSQL logs
kubectl logs -f deployment/postgres -n production

# Verify service is running
kubectl get service postgres-service -n production
```

### **Application Connection Issues**

```bash
# Check if application secret exists
kubectl get secret myapp-db-secret -n production

# Verify application can access database
kubectl exec deployment/myapp -n production -- env | grep DATABASE
```

## 📞 **Support**

If you have issues with password management:

1. **Check the troubleshooting section** above
2. **Run the password retrieval script** to verify current passwords
3. **Check GitHub Actions logs** for deployment issues
4. **Verify Kubernetes secrets** are properly configured
5. **Contact your system administrator** for access issues

---

**Remember**: Database passwords are sensitive information. Always handle them securely and never expose them in logs, documentation, or public repositories.
