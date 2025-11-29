# Dependency Update Guide

## 📋 Quick Reference

After the security fixes, use this guide to update your dependencies.

---

## 🔄 Update Process

### Step 1: Update Requirements Files

The requirements files have been updated. To apply:

```bash
# Service A
cd services/service-a
pip install -r requirements.txt --upgrade

# Service B
cd services/service-b
pip install -r requirements.txt --upgrade
```

### Step 2: Verify Versions

```bash
# Check installed versions
pip list | grep -E "gunicorn|requests|urllib3|zipp"

# Expected:
# gunicorn          23.0.0
# requests          2.32.4
# urllib3           2.5.0 (or higher)
# zipp              3.19.1 (or higher)
```

### Step 3: Test Application

```bash
# Test Service A
cd services/service-a
python app.py  # Should start without errors

# Test Service B
cd ../service-b
python app.py  # Should start without errors
```

### Step 4: Rebuild Docker Images

```bash
# Rebuild Service A
cd services/service-a
docker build -t cloudphoenix/service-a:latest .

# Rebuild Service B
cd ../service-b
docker build -t cloudphoenix/service-b:latest .
```

### Step 5: Test in Docker

```bash
# Run Service A container
docker run -p 8080:8080 cloudphoenix/service-a:latest

# In another terminal, test
curl http://localhost:8080/health
```

---

## 🔍 Continuous Security Monitoring

### Enable Automated Scanning

1. **GitHub Dependabot** (Recommended):
   - Go to GitHub repository settings
   - Security → Dependabot alerts → Enable
   - Automatically creates PRs for security updates

2. **Snyk** (Alternative):
   - Install Snyk CLI: `npm install -g snyk`
   - Run: `snyk test`
   - Monitor: `snyk monitor`

3. **pip-audit**:
   ```bash
   pip install pip-audit
   pip-audit -r requirements.txt
   ```

### Manual Security Checks

```bash
# Check for outdated packages
pip list --outdated

# Check for security vulnerabilities
pip-audit -r services/service-a/requirements.txt
pip-audit -r services/service-b/requirements.txt
```

---

## 📊 Updated Dependency Versions

### Service A & B (Shared)

```
flask==3.0.0                    # Latest stable
psycopg2-binary==2.9.9          # Latest stable
boto3==1.34.0                   # Latest stable
requests==2.32.4                # ✅ Fixed security issues
gunicorn==23.0.0                # ✅ Fixed HTTP smuggling
prometheus-client==0.19.0       # Latest stable
urllib3>=2.5.0                  # ✅ Fixed vulnerabilities
zipp>=3.19.1                    # ✅ Fixed infinite loop
```

---

## ⚠️ Breaking Changes Check

### Gunicorn 21.2.0 → 23.0.0

**Compatibility**: ✅ Fully compatible
- No breaking changes affecting Flask applications
- Same configuration format
- Same command-line options

### Requests 2.31.0 → 2.32.4

**Compatibility**: ✅ Fully compatible
- Same API
- No breaking changes
- Backward compatible

### Urllib3 2.0.7 → 2.5.0

**Compatibility**: ✅ Compatible
- Requests handles urllib3 internally
- No code changes needed

---

## 🧪 Testing Checklist

After updating dependencies:

- [ ] Service A starts without errors
- [ ] Service B starts without errors
- [ ] Health endpoints work (`/health`, `/ready`, `/live`)
- [ ] API endpoints work (`/api/data`, `/api/cloud-status`)
- [ ] Database connections work
- [ ] S3 connections work (if configured)
- [ ] Docker images build successfully
- [ ] Containers run without errors
- [ ] No dependency conflicts

---

## 🔄 Future Updates

### Recommended Update Schedule

- **Security patches**: Immediately
- **Minor updates**: Monthly
- **Major updates**: Quarterly (with testing)

### Update Process

1. Check for updates: `pip list --outdated`
2. Review changelog for breaking changes
3. Update requirements.txt
4. Test locally
5. Test in Docker
6. Deploy to staging
7. Monitor for issues
8. Deploy to production

---

## 📝 Changelog

### 2024 - Security Fixes

- ✅ Updated gunicorn: 21.2.0 → 23.0.0 (Fixes HTTP Request Smuggling)
- ✅ Updated requests: 2.31.0 → 2.32.4 (Fixes certificate bypass & credential leak)
- ✅ Updated urllib3: 2.0.7 → 2.5.0 (Fixes header leakage & redirect issues)
- ✅ Updated zipp: 3.15.0 → 3.19.1 (Fixes infinite loop)

---

**All dependencies are now secure and up-to-date!** 🔒✅

