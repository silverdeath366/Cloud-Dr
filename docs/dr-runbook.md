# CloudPhoenix Disaster Recovery Runbook

## Overview

This runbook provides step-by-step procedures for executing disaster recovery operations in the CloudPhoenix platform.

## Pre-Flight Checks

Before initiating DR procedures, verify:

- [ ] AWS primary region status
- [ ] Azure DR region availability
- [ ] Network connectivity between regions
- [ ] Credentials and access permissions
- [ ] Recent backups verified

## DR Trigger Conditions

DR failover is automatically triggered when:
- Health score exceeds 11
- Multiple critical services are down
- Region-level failure detected
- Manual trigger via Jenkins

## Manual DR Trigger

### Via Jenkins

1. Navigate to Jenkins → CloudPhoenix Pipeline
2. Click "Build with Parameters"
3. Select `ACTION: dr_failover`
4. Set `DRY_RUN: false` (or `true` for testing)
5. Click "Build"

### Via CLI

```bash
./scripts/trigger_dr.sh
```

## DR Execution Steps

### Phase 1: Detection & Assessment

1. **Health Check**
   ```bash
   python3 scripts/healthcheck.py
   ```
   - Review health score
   - Identify failing components
   - Document current state

2. **Verify Failover Level**
   - Score 0-3: No action needed
   - Score 4-7: App self-healing
   - Score 8-10: Region failover
   - Score 11+: DR failover required

### Phase 2: Data Replication

1. **Database Replication**
   ```bash
   ./scripts/replicate_db.sh
   ```
   - Exports data from AWS RDS
   - Prepares for Azure SQL import
   - Verify export completion

2. **Storage Sync**
   ```bash
   ./scripts/sync_s3.sh
   ```
   - Syncs S3 to Azure Blob Storage
   - Verifies sync completion
   - Checks data integrity

### Phase 3: Infrastructure Provisioning

1. **Azure Infrastructure**
   ```bash
   cd terraform/azure
   terraform init
   terraform plan
   terraform apply
   ```
   - Provisions AKS cluster
   - Creates Azure SQL database
   - Sets up storage accounts
   - Configures Traffic Manager

2. **Verify Infrastructure**
   - Check AKS cluster status
   - Verify Azure SQL connectivity
   - Confirm storage accounts accessible

### Phase 4: Service Deployment

1. **Configure kubeconfig**
   ```bash
   az aks get-credentials --resource-group cloudphoenix-dr-rg --name cloudphoenix-aks
   ```

2. **Deploy Services**
   ```bash
   helm upgrade --install service-a k8s/helm/service-a
   helm upgrade --install service-b k8s/helm/service-b
   ```

3. **Verify Deployments**
   ```bash
   kubectl get pods -n cloudphoenix
   kubectl get svc -n cloudphoenix
   ```

### Phase 5: DNS Switchover

1. **Switch DNS to Azure**
   ```bash
   ./scripts/switch_dns.sh --target azure
   ```

2. **Wait for Propagation**
   - DNS TTL: 60 seconds
   - Wait 2-3 minutes for full propagation
   - Verify with `dig` or `nslookup`

### Phase 6: Verification

1. **Service Health Checks**
   ```bash
   ./scripts/verify_services.sh
   ```

2. **Manual Verification**
   - Test service endpoints
   - Verify database connectivity
   - Check storage access
   - Monitor logs

3. **Traffic Verification**
   - Confirm traffic routing to Azure
   - Check response times
   - Verify error rates

### Phase 7: Post-Failover

1. **Notification**
   - n8n webhook automatically triggered
   - Notify stakeholders
   - Update status page

2. **Monitoring**
   - Monitor service health
   - Check resource utilization
   - Review logs for errors

3. **Documentation**
   - Document failover time
   - Record issues encountered
   - Update incident log

## Rollback Procedure

### Rollback to AWS Primary

1. **Verify AWS Status**
   - Check AWS region health
   - Verify services operational
   - Confirm data integrity

2. **Switch DNS Back**
   ```bash
   ./scripts/switch_dns.sh --target aws
   ```

3. **Verify Services**
   ```bash
   export SERVICE_A_URL="http://aws-alb-dns/service-a"
   export SERVICE_B_URL="http://aws-alb-dns/service-b"
   ./scripts/verify_services.sh
   ```

4. **Monitor**
   - Watch for issues
   - Verify traffic flow
   - Check service health

## Troubleshooting

### Common Issues

#### DNS Not Propagating
- Check Route53 hosted zone
- Verify CNAME record
- Wait for TTL expiration
- Use `dig` to verify

#### Services Not Starting
- Check pod logs: `kubectl logs -n cloudphoenix <pod-name>`
- Verify resource limits
- Check image pull secrets
- Review deployment status

#### Database Connection Failures
- Verify network connectivity
- Check firewall rules
- Confirm credentials
- Test connection manually

#### Storage Sync Failures
- Check AWS/Azure credentials
- Verify network connectivity
- Review sync logs
- Retry sync operation

## Emergency Contacts

- **On-Call Engineer**: [Contact Info]
- **DevOps Lead**: [Contact Info]
- **Cloud Provider Support**: 
  - AWS: [Support Plan]
  - Azure: [Support Plan]

## Post-Incident

After DR execution:

1. **Postmortem Meeting**
   - Schedule within 24 hours
   - Review timeline
   - Identify root cause
   - Document lessons learned

2. **Improvements**
   - Update runbook
   - Fix identified issues
   - Improve automation
   - Update documentation

3. **Testing**
   - Schedule DR drill
   - Test improvements
   - Verify procedures

