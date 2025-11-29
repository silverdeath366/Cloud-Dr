# Testing Priority Guide - What to Test First

## 🎯 Quick Reference: Testing Order

Test in this order to verify everything works efficiently:

---

## ⚡ Phase 1: Critical Path (Must Work) - 2-3 hours

### 1. Infrastructure Deployment
```bash
# Test AWS
cd terraform/aws
terraform init
terraform plan  # Check for errors

# Test Azure
cd ../azure
terraform init
terraform plan  # Check for errors
```

**Success**: Plans complete without errors

---

### 2. Service Builds
```bash
# Build frontend
cd services/frontend
docker build -t cloudphoenix/frontend:test .

# Build backend
cd ../service-a
docker build -t cloudphoenix/service-a:test .
```

**Success**: Images build successfully

---

### 3. Health Check Script
```bash
python3 scripts/healthcheck.py
# Should output JSON with score
```

**Success**: Returns valid JSON with health score

---

### 4. Frontend (Local Test)
```bash
cd services/frontend
docker run -p 8080:80 cloudphoenix/frontend:test
# Visit http://localhost:8080
```

**Success**: Frontend loads and displays

---

**After Phase 1**: You know the basics work!

---

## 🔧 Phase 2: Core Functionality - 4-6 hours

### 5. Deploy to AWS
- [ ] Deploy infrastructure
- [ ] Deploy services to EKS
- [ ] Verify pods running
- [ ] Access frontend via ALB

### 6. Database Connection
- [ ] RDS accessible
- [ ] Services can connect
- [ ] Data can be read/written

### 7. Deploy to Azure
- [ ] Deploy infrastructure
- [ ] Deploy services to AKS
- [ ] Verify pods running

### 8. DNS Setup (If Using Domain)
- [ ] Route53 configured
- [ ] Domain resolves
- [ ] Frontend accessible via domain

**After Phase 2**: Core system works on both clouds!

---

## 🎬 Phase 3: DR Demo - 2-3 hours

### 9. DR Failover (Dry Run)
- [ ] Test scripts in dry-run mode
- [ ] Verify no errors

### 10. DR Failover (Actual)
- [ ] Trigger DR
- [ ] Monitor progress
- [ ] Verify completion
- [ ] Verify frontend shows Azure

### 11. Rollback
- [ ] Switch back to AWS
- [ ] Verify frontend shows AWS

**After Phase 3**: DR works end-to-end!

---

## 🎯 Phase 4: Polish & Demo - 1-2 hours

### 12. Capture Screenshots
- [ ] Architecture diagram
- [ ] Frontend (AWS)
- [ ] Frontend (Azure)
- [ ] Health dashboard
- [ ] DR in progress

### 13. Final Verification
- [ ] Everything works
- [ ] Can demonstrate
- [ ] Ready for LinkedIn

**After Phase 4**: Ready to post!

---

## ⏱️ Time Estimate

- **Quick Test** (Phase 1): 2-3 hours
- **Full Test** (Phases 1-3): 8-12 hours
- **Complete with Polish** (All phases): 1-2 days

---

## 🎯 Minimum for LinkedIn Post

**Must work**:
- [ ] Infrastructure deploys
- [ ] Services run on both clouds
- [ ] Frontend accessible
- [ ] DR failover works once
- [ ] Screenshots captured

**Nice to have**:
- [ ] n8n workflow built
- [ ] Performance tested
- [ ] Security audited

---

## ✅ Quick Win Testing Order

**Day 1** (4-6 hours):
1. Infrastructure plans
2. Service builds
3. Health checks
4. Deploy to AWS
5. Frontend accessible

**Day 2** (4-6 hours):
1. Deploy to Azure
2. Database connections
3. DR failover test
4. Screenshots

**Day 3** (Optional - 2-4 hours):
1. Polish
2. n8n workflow
3. Final touches

---

**Start with Phase 1, then work your way through!** 🚀

