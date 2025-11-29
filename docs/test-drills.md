# CloudPhoenix Test Drills

## Overview

Regular disaster recovery drills are essential to ensure the CloudPhoenix platform can successfully recover from failures. This document outlines test procedures for various failure scenarios.

## Drill Schedule

- **Monthly**: Application-level failures
- **Quarterly**: Region-level failures
- **Semi-Annually**: Full DR failover
- **Annually**: Multi-region disaster simulation

## Pre-Drill Checklist

- [ ] Notify stakeholders
- [ ] Schedule maintenance window (if needed)
- [ ] Backup current state
- [ ] Verify monitoring is active
- [ ] Prepare rollback plan
- [ ] Document baseline metrics

## Drill Types

### 1. Pod Crash Simulation

**Objective**: Test application self-healing

**Procedure**:
```bash
./cicd/simulate_failure.sh pod-crash
```

**Expected Results**:
- Pods automatically restart
- Services remain available
- Health score remains < 4
- No manual intervention required

**Verification**:
- Check pod status: `kubectl get pods -n cloudphoenix`
- Verify service health: `curl http://service-a/health`
- Review Prometheus metrics

### 2. Database Slowdown Simulation

**Objective**: Test database performance degradation handling

**Procedure**:
```bash
./cicd/simulate_failure.sh db-slowdown
```

**Expected Results**:
- Health score increases to 4-7
- Application self-healing triggered
- Connection pool adjustments
- Alert notifications sent

**Verification**:
- Monitor database metrics
- Check application logs
- Review health score
- Verify alerts received

### 3. Availability Zone Failure

**Objective**: Test AZ-level failure recovery

**Procedure**:
```bash
./cicd/simulate_failure.sh az-failure
```

**Expected Results**:
- Nodes in AZ cordoned
- Pods rescheduled to other AZs
- Services remain available
- Health score may increase to 8-10

**Verification**:
- Check node status
- Verify pod distribution
- Monitor service availability
- Review resource utilization

### 4. Region Isolation Simulation

**Objective**: Test full DR failover

**Procedure**:
```bash
./cicd/simulate_failure.sh region-isolation
```

**Expected Results**:
- Health score exceeds 11
- DR failover triggered
- Data replicated to Azure
- DNS switched to Azure
- Services available in DR region

**Verification**:
- Verify Azure infrastructure
- Check service deployment
- Test DNS resolution
- Verify data integrity
- Monitor service health

### 5. Manual DR Failover Drill

**Objective**: Test complete DR procedure

**Procedure**:
1. Trigger via Jenkins:
   - Action: `dr_failover`
   - Dry Run: `false`

2. Monitor pipeline execution

3. Verify each phase:
   - Data replication
   - Infrastructure provisioning
   - Service deployment
   - DNS switchover
   - Service verification

**Expected Results**:
- All phases complete successfully
- RTO < 15 minutes
- Services operational in DR
- Data integrity maintained

**Verification**:
- Check pipeline logs
- Verify service endpoints
- Test application functionality
- Review metrics and logs

## Drill Execution Steps

### Preparation

1. **Schedule Drill**
   - Choose date/time
   - Notify team
   - Set maintenance window

2. **Baseline Metrics**
   ```bash
   # Capture current state
   kubectl get all -n cloudphoenix > baseline-state.yaml
   python3 scripts/healthcheck.py > baseline-health.json
   ```

3. **Backup Configuration**
   - Export Terraform state
   - Backup Kubernetes manifests
   - Document current DNS records

### Execution

1. **Run Simulation**
   - Execute chosen drill type
   - Monitor automation
   - Document observations

2. **Manual Verification**
   - Test service endpoints
   - Verify data integrity
   - Check monitoring dashboards

3. **Timing**
   - Record start time
   - Track each phase duration
   - Document total RTO

### Post-Drill

1. **Rollback** (if needed)
   ```bash
   ./cicd/rollback.sh
   ```

2. **Data Collection**
   - Gather logs
   - Export metrics
   - Document issues

3. **Analysis**
   - Review timeline
   - Identify bottlenecks
   - Calculate actual RTO/RPO

4. **Reporting**
   - Write drill report
   - Document findings
   - Create improvement tickets

## Success Criteria

### Application Self-Healing
- ✅ Pods recover within 2 minutes
- ✅ No service interruption
- ✅ Health score returns to normal

### Region Failover
- ✅ Services available in secondary region
- ✅ Data integrity maintained
- ✅ RTO < 10 minutes

### DR Failover
- ✅ Complete failover in < 15 minutes
- ✅ All services operational
- ✅ Data synchronized
- ✅ DNS propagated
- ✅ Zero data loss

## Common Issues & Solutions

### Issue: Health Check Timeout
**Solution**: Increase timeout values, check network connectivity

### Issue: Data Sync Slow
**Solution**: Optimize sync scripts, use parallel transfers

### Issue: DNS Not Propagating
**Solution**: Reduce TTL, use multiple DNS providers

### Issue: Service Deployment Fails
**Solution**: Check resource limits, verify image availability

## Drill Report Template

```markdown
# DR Drill Report - [Date]

## Drill Type
[Type of drill executed]

## Timeline
- Start: [Time]
- Detection: [Time]
- Failover Start: [Time]
- Completion: [Time]
- Total Duration: [Duration]

## Results
- Success: [Yes/No]
- RTO: [Time]
- RPO: [Time]
- Issues Encountered: [List]

## Findings
[Key findings and observations]

## Improvements
[Recommended improvements]

## Next Steps
[Action items]
```

## Continuous Improvement

After each drill:

1. Update runbooks based on findings
2. Fix identified issues
3. Improve automation
4. Update documentation
5. Schedule next drill

