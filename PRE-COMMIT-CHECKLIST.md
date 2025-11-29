# Pre-Commit Security & Quality Checklist

## ✅ Before Committing Code

Use this checklist before every commit to ensure security and code quality:

---

## 🔒 Security Checks

- [ ] **No hardcoded secrets**
  - No passwords, API keys, tokens in code
  - All secrets use environment variables
  - No secrets in comments

- [ ] **No secrets in files**
  - `.env` files excluded from git
  - `*.tfvars` files excluded (except examples)
  - No credentials in config files

- [ ] **Input validation**
  - All user inputs validated
  - SQL queries use parameterized statements
  - Input length limits enforced

- [ ] **Error handling**
  - Generic error messages (no internals exposed)
  - Stack traces only in debug mode
  - No sensitive data in logs

- [ ] **Security headers**
  - Security headers configured
  - CSP headers appropriate
  - HTTPS enforced where applicable

---

## 📝 Code Quality Checks

- [ ] **Code follows style guide**
  - Consistent formatting
  - Meaningful variable names
  - Clear comments where needed

- [ ] **Error handling**
  - Proper exception handling
  - Retry logic where appropriate
  - Cleanup on errors

- [ ] **Documentation**
  - Functions documented
  - Complex logic explained
  - README updated if needed

- [ ] **No debug code**
  - No `console.log` in production code
  - No commented-out code
  - No `TODO` or `FIXME` without context

---

## 🧪 Testing Checks

- [ ] **Code tested**
  - Critical paths tested
  - Error cases handled
  - Edge cases considered

- [ ] **No breaking changes**
  - API contracts maintained
  - Backward compatibility preserved
  - Migration paths documented

---

## 📦 Dependency Checks

- [ ] **Dependencies secure**
  - No known vulnerabilities
  - Versions pinned
  - Regular updates applied

- [ ] **No unused dependencies**
  - Only required packages
  - No duplicate dependencies
  - Requirements.txt updated

---

## 🔍 Git Checks

- [ ] **No sensitive files**
  - `.gitignore` configured
  - No secrets in commit history
  - No large files committed

- [ ] **Clean commit**
  - Logical commit messages
  - Single-purpose commits
  - Files staged correctly

---

## 🚨 Common Mistakes to Avoid

### ❌ Don't:
- Commit `.env` files
- Hardcode API keys
- Commit `terraform.tfstate`
- Leave `TODO` comments without explanation
- Expose stack traces in production
- Use `eval()` or `innerHTML` with user data
- Commit credentials in any form

### ✅ Do:
- Use environment variables
- Validate all inputs
- Use parameterized SQL queries
- Follow security best practices
- Document complex logic
- Test before committing

---

## 🔧 Quick Verification Commands

```bash
# Check for secrets in code
grep -r "password\|secret\|api_key\|token" --exclude-dir=.git --exclude="*.md" .

# Check for hardcoded credentials
grep -r "=\s*['\"]" --include="*.py" --include="*.js" --exclude-dir=.git .

# Verify .gitignore excludes secrets
git status --ignored | grep -E "\.env|\.tfvars|secrets|\.key|\.pem"

# Check for SQL injection risks
grep -r "execute.*\+" --include="*.py" --exclude-dir=.git .

# Check for XSS risks
grep -r "innerHTML.*\$" --include="*.js" --exclude-dir=.git .
```

---

## 📋 Git Hooks Setup (Optional)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Pre-commit hook to check for common issues

echo "Running pre-commit checks..."

# Check for secrets
if git diff --cached --name-only | xargs grep -l "password\|secret\|api_key" 2>/dev/null; then
    echo "ERROR: Potential secrets found in staged files!"
    exit 1
fi

# Check for large files
if git diff --cached --name-only | xargs find . -type f -size +5M 2>/dev/null; then
    echo "ERROR: Large files detected!"
    exit 1
fi

# Check Python syntax
for file in $(git diff --cached --name-only --diff-filter=ACM | grep "\.py$"); do
    python3 -m py_compile "$file" || exit 1
done

echo "Pre-commit checks passed!"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## ✅ Quick Checklist (Copy Before Each Commit)

```
Security:
[ ] No secrets in code
[ ] Input validation present
[ ] Error handling secure

Quality:
[ ] Code tested
[ ] Documentation updated
[ ] Follows style guide

Git:
[ ] .gitignore configured
[ ] Clean commit message
[ ] No sensitive files staged
```

---

**Use this checklist before every commit to maintain code quality and security!** 🔒

