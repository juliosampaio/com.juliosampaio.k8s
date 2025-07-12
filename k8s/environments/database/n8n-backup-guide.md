# n8n Database Backup Guide

This guide explains how to set up n8n workflows to backup your PostgreSQL databases in the Kubernetes cluster.

## 🔗 **Connection Details**

### **Production Database**

```
Host: postgres-backup-service.production.svc.cluster.local
Port: 5432
Database: shared_db
Username: postgres
Password: [retrieve using get-db-passwords.sh]
```

### **Stage Database**

```
Host: postgres-backup-service.stage.svc.cluster.local
Port: 5432
Database: shared_db
Username: postgres
Password: [retrieve using get-db-passwords.sh]
```

## 🛠️ **n8n Workflow Setup**

### **Step 1: Get Database Passwords**

First, retrieve the current database passwords:

```bash
# Run the password retrieval script
./k8s/environments/database/get-db-passwords.sh
```

### **Step 2: Create n8n Workflow**

#### **Basic Backup Workflow**

1. **HTTP Request Node** (to get password from Kubernetes)
2. **PostgreSQL Node** (to create backup)
3. **File Operations Node** (to save backup)
4. **Schedule Trigger** (for automated backups)

#### **Advanced Backup Workflow**

1. **Cron Trigger** (daily at 2 AM)
2. **HTTP Request Node** (get password)
3. **PostgreSQL Node** (backup all databases)
4. **Compression Node** (gzip the backup)
5. **Cloud Storage Node** (upload to S3/Google Drive/etc.)
6. **Email Node** (notify on success/failure)
7. **Cleanup Node** (remove old backups)

## 📋 **n8n Node Configurations**

### **PostgreSQL Node Configuration**

```json
{
  "host": "postgres-backup-service.production.svc.cluster.local",
  "port": 5432,
  "database": "shared_db",
  "user": "postgres",
  "password": "{{ $json.password }}",
  "operation": "executeQuery",
  "query": "SELECT current_database(), current_user, version();"
}
```

### **Backup Query Example**

```sql
-- Backup all databases
SELECT
  'pg_dump -h localhost -U postgres -d ' || datname || ' > /tmp/backup_' || datname || '_' || to_char(now(), 'YYYYMMDD_HH24MI') || '.sql'
FROM pg_database
WHERE datname NOT IN ('template0', 'template1', 'postgres');
```

## 🔄 **Automated Backup Workflow**

### **Workflow JSON Example**

```json
{
  "name": "Database Backup Workflow",
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 2 * * *"
            }
          ]
        }
      },
      "id": "cron-trigger",
      "name": "Daily Backup Trigger",
      "type": "n8n-nodes-base.cron",
      "typeVersion": 1,
      "position": [240, 300]
    },
    {
      "parameters": {
        "url": "https://your-k8s-cluster/api/v1/namespaces/production/secrets/postgres-secret",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendHeaders": true,
        "headerParameters": {
          "parameters": [
            {
              "name": "Authorization",
              "value": "Bearer {{ $env.K8S_TOKEN }}"
            }
          ]
        }
      },
      "id": "get-password",
      "name": "Get Database Password",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.1,
      "position": [460, 300]
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres')",
        "options": {}
      },
      "id": "list-databases",
      "name": "List Databases",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.4,
      "position": [680, 300]
    }
  ]
}
```

## 📅 **Backup Schedule Recommendations**

### **Development/Stage Environment**

- **Frequency**: Daily
- **Time**: 2:00 AM
- **Retention**: 7 days
- **Compression**: Yes

### **Production Environment**

- **Frequency**: Daily + Weekly full backup
- **Time**: 1:00 AM (daily), Sunday 2:00 AM (weekly)
- **Retention**: 30 days (daily), 12 weeks (weekly)
- **Compression**: Yes
- **Encryption**: Recommended

## 🗂️ **Backup Storage Options**

### **Local Storage (Temporary)**

```bash
# Backup to local file system
pg_dump -h postgres-service.production.svc.cluster.local -U postgres -d shared_db > backup.sql
```

### **Cloud Storage (Recommended)**

- **AWS S3**: Reliable, cost-effective
- **Google Cloud Storage**: Good integration
- **Azure Blob Storage**: Enterprise features
- **Backblaze B2**: Cost-effective alternative

### **Backup File Naming Convention**

```
backup_shared_db_20241201_020000.sql.gz
backup_myapp_db_20241201_020000.sql.gz
```

## 🔐 **Security Considerations**

### **Password Management**

- ✅ Use Kubernetes secrets for passwords
- ✅ Rotate passwords regularly
- ✅ Use service accounts with minimal permissions
- ✅ Encrypt backup files

### **Access Control**

- 🔒 Limit n8n access to backup services only
- 🔒 Use network policies to restrict access
- 🔒 Monitor backup access logs
- 🔒 Implement backup verification

## 🧪 **Testing Your Backup Workflow**

### **Manual Test**

```bash
# Test connection
kubectl exec deployment/postgres -n production -- pg_isready -U postgres

# Test backup
kubectl exec deployment/postgres -n production -- pg_dump -U postgres -d shared_db > test_backup.sql

# Verify backup
kubectl exec deployment/postgres -n production -- psql -U postgres -d shared_db -c "SELECT COUNT(*) FROM information_schema.tables;"
```

### **Restore Test**

```bash
# Create test database
kubectl exec deployment/postgres -n production -- createdb -U postgres test_restore

# Restore backup
kubectl exec -i deployment/postgres -n production -- psql -U postgres -d test_restore < test_backup.sql

# Verify restore
kubectl exec deployment/postgres -n production -- psql -U postgres -d test_restore -c "SELECT COUNT(*) FROM information_schema.tables;"
```

## 📊 **Monitoring and Alerting**

### **Backup Health Checks**

- ✅ Backup file size monitoring
- ✅ Backup completion time tracking
- ✅ Restore test automation
- ✅ Storage space monitoring

### **Alerting**

- 🚨 Backup failure notifications
- 🚨 Storage space warnings
- 🚨 Restore test failures
- 🚨 Unusual backup patterns

## 🔧 **Troubleshooting**

### **Common Issues**

#### **Connection Refused**

```bash
# Check if PostgreSQL is running
kubectl get pods -n production -l app=postgres

# Check service
kubectl get service postgres-backup-service -n production

# Test connection
kubectl exec deployment/postgres -n production -- pg_isready -U postgres
```

#### **Authentication Failed**

```bash
# Get current password
./k8s/environments/database/get-db-passwords.sh

# Test with password
kubectl exec deployment/postgres -n production -- psql -U postgres -d shared_db -c "SELECT 1;"
```

#### **Permission Denied**

```bash
# Check PostgreSQL logs
kubectl logs deployment/postgres -n production

# Check if user exists
kubectl exec deployment/postgres -n production -- psql -U postgres -c "\du"
```

## 📈 **Performance Optimization**

### **Backup Optimization**

- Use `--compress=9` for maximum compression
- Use `--jobs=4` for parallel backup (if multiple databases)
- Use `--exclude-table-data` for large log tables
- Schedule backups during low-traffic periods

### **Storage Optimization**

- Implement backup rotation
- Use incremental backups where possible
- Compress backup files
- Use deduplication for similar backups

## 🎯 **Next Steps**

1. **Set up n8n** in your environment
2. **Create backup workflow** using the examples above
3. **Test backup and restore** procedures
4. **Implement monitoring** and alerting
5. **Document recovery procedures** for your team
6. **Regular backup testing** to ensure reliability

---

**Remember**: A backup is only as good as your ability to restore from it. Always test your restore procedures regularly!
