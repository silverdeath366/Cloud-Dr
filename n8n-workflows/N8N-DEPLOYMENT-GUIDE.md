# n8n Deployment Guide - CloudPhoenix

## 🎯 Recommendation: Self-Hosted on Ubuntu

For CloudPhoenix, **self-hosted on Ubuntu is recommended** because:
- ✅ Access to local scripts (`gather_incident_context.py`)
- ✅ Direct access to Prometheus/Loki (no network restrictions)
- ✅ Full control over security
- ✅ No API rate limits
- ✅ Can run Execute Command nodes
- ✅ Free (no subscription costs)
- ✅ Better for production use

---

## 📦 Option 1: Self-Hosted on Ubuntu (RECOMMENDED)

### Installation Methods

#### Method A: Docker (Easiest - Recommended)

**Prerequisites**:
```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
```

**Quick Start**:
```bash
# Create directory
mkdir -p ~/n8n
cd ~/n8n

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=YOUR_SECURE_PASSWORD
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=UTC
      - EXECUTIONS_PROCESS=main
    volumes:
      - n8n_data:/home/node/.n8n
      - /home/silver/cloudphoenix:/data/cloudphoenix:ro  # Mount project directory (read-only)
    networks:
      - n8n_network

volumes:
  n8n_data:

networks:
  n8n_network:
    driver: bridge
EOF

# Start n8n
docker-compose up -d

# Check logs
docker-compose logs -f n8n
```

**Access**: `http://your-ubuntu-ip:5678` or `http://localhost:5678`

**Benefits**:
- ✅ Isolated container
- ✅ Easy updates (`docker-compose pull && docker-compose up -d`)
- ✅ Easy backup (volume)
- ✅ Can mount cloudphoenix directory for script access

#### Method B: npm (Native Install)

**Prerequisites**:
```bash
# Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify
node --version  # Should be 18+
npm --version
```

**Installation**:
```bash
# Install n8n globally
sudo npm install n8n -g

# OR install as user (recommended)
npm install n8n -g --prefix ~/.local

# Add to PATH if needed
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc
```

**Run n8n**:
```bash
# Simple start
n8n start

# Or with environment variables
N8N_BASIC_AUTH_ACTIVE=true \
N8N_BASIC_AUTH_USER=admin \
N8N_BASIC_AUTH_PASSWORD=YOUR_PASSWORD \
N8N_HOST=0.0.0.0 \
N8N_PORT=5678 \
n8n start
```

**Create Systemd Service** (for auto-start):
```bash
sudo nano /etc/systemd/system/n8n.service
```

Add:
```ini
[Unit]
Description=n8n workflow automation
After=network.target

[Service]
Type=simple
User=silver
WorkingDirectory=/home/silver
Environment="N8N_BASIC_AUTH_ACTIVE=true"
Environment="N8N_BASIC_AUTH_USER=admin"
Environment="N8N_BASIC_AUTH_PASSWORD=YOUR_SECURE_PASSWORD"
Environment="N8N_HOST=0.0.0.0"
Environment="N8N_PORT=5678"
Environment="PATH=/usr/bin:/usr/local/bin:/home/silver/.local/bin"
ExecStart=/home/silver/.local/bin/n8n start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable n8n
sudo systemctl start n8n
sudo systemctl status n8n
```

#### Method C: Using PM2 (Process Manager - Recommended for Production)

**Install PM2**:
```bash
npm install -g pm2
```

**Create n8n startup script**:
```bash
cat > ~/start-n8n.sh << 'EOF'
#!/bin/bash
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER=admin
export N8N_BASIC_AUTH_PASSWORD=YOUR_SECURE_PASSWORD
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_PROTOCOL=http
n8n start
EOF

chmod +x ~/start-n8n.sh
```

**Start with PM2**:
```bash
pm2 start ~/start-n8n.sh --name n8n
pm2 save
pm2 startup  # Follow instructions to enable on boot
```

**PM2 Commands**:
```bash
pm2 status
pm2 logs n8n
pm2 restart n8n
pm2 stop n8n
```

---

## ☁️ Option 2: n8n Cloud (n8n.io)

**Pros**:
- ✅ No setup required
- ✅ Managed by n8n team
- ✅ Auto-updates
- ✅ Built-in monitoring

**Cons**:
- ❌ Can't access local scripts easily
- ❌ Need to expose Prometheus/Loki externally
- ❌ Paid plans for production use
- ❌ Network restrictions
- ❌ Can't use Execute Command nodes

**If using Cloud**:
1. Sign up at https://n8n.io
2. Create workflows in web interface
3. For local scripts, you'd need to:
   - Expose `gather_incident_context.py` as HTTP API
   - Use HTTP Request nodes instead of Execute Command
   - Make Prometheus/Loki accessible (VPN or auth gateway)

---

## 🔒 Security Configuration

### For Self-Hosted (Important!)

**1. Set up Basic Auth**:
```bash
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER=admin
export N8N_BASIC_AUTH_PASSWORD=STRONG_PASSWORD_HERE
```

**2. Use HTTPS** (For Production):
- Use reverse proxy (nginx) with SSL certificate
- Or use n8n with self-signed cert

**3. Firewall Rules**:
```bash
# Allow n8n port (5678)
sudo ufw allow 5678/tcp

# Or restrict to specific IPs
sudo ufw allow from YOUR_IP_ADDRESS to any port 5678
```

**4. Reverse Proxy with Nginx** (Recommended for Production):

Install nginx:
```bash
sudo apt install nginx
sudo apt install certbot python3-certbot-nginx
```

Create nginx config:
```bash
sudo nano /etc/nginx/sites-available/n8n
```

Add:
```nginx
server {
    listen 80;
    server_name n8n.yourdomain.com;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable:
```bash
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificate
sudo certbot --nginx -d n8n.yourdomain.com
```

---

## 📝 Accessing Local Scripts from n8n

### Method 1: Execute Command Node (Self-Hosted Only)

If n8n is on same server:
1. In Execute Command node, run:
   ```bash
   python3 /data/cloudphoenix/scripts/gather_incident_context.py --llm-prompt
   ```
2. Or if mounted: `/data/cloudphoenix/scripts/gather_incident_context.py`

### Method 2: HTTP API Wrapper (Works for Cloud or Self-Hosted)

Create simple Flask API:
```python
# ~/cloudphoenix/scripts/api_wrapper.py
from flask import Flask, request, jsonify
import subprocess
import sys
import os

app = Flask(__name__)

@app.route('/gather-context', methods=['POST'])
def gather_context():
    script_path = os.path.join(
        os.path.dirname(__file__),
        'gather_incident_context.py'
    )
    result = subprocess.run(
        [sys.executable, script_path, '--llm-prompt'],
        capture_output=True,
        text=True,
        timeout=60
    )
    
    if result.returncode == 0:
        return jsonify({'status': 'success', 'output': result.stdout})
    else:
        return jsonify({'status': 'error', 'error': result.stderr}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

Run it:
```bash
cd ~/cloudphoenix/scripts
python3 -m pip install flask
python3 api_wrapper.py
```

Then in n8n, use HTTP Request node:
- URL: `http://localhost:5000/gather-context` (or your server IP)

---

## 🚀 Recommended Setup for CloudPhoenix

### Quick Start (Docker - Recommended)

```bash
# 1. Create n8n directory
mkdir -p ~/n8n && cd ~/n8n

# 2. Create docker-compose.yml (see Method A above)

# 3. Update password in docker-compose.yml
# Replace YOUR_SECURE_PASSWORD with strong password

# 4. Start n8n
docker-compose up -d

# 5. Check it's running
curl http://localhost:5678
# Or open browser: http://your-ubuntu-ip:5678

# 6. Login with:
# Username: admin
# Password: YOUR_SECURE_PASSWORD
```

### Production Setup (With PM2 + Nginx)

```bash
# 1. Install n8n via npm
npm install n8n -g --prefix ~/.local

# 2. Create PM2 startup script (see Method C above)

# 3. Start with PM2
pm2 start ~/start-n8n.sh --name n8n
pm2 save
pm2 startup

# 4. Set up nginx reverse proxy (see security section)

# 5. Access via: https://n8n.yourdomain.com
```

---

## 🔍 Troubleshooting

### n8n not accessible
```bash
# Check if running
docker ps | grep n8n
# OR
pm2 status

# Check logs
docker logs n8n
# OR
pm2 logs n8n

# Check port
sudo netstat -tlnp | grep 5678
```

### Can't access local scripts
- Verify path is correct
- Check file permissions: `chmod +x scripts/gather_incident_context.py`
- Use full path: `/home/silver/cloudphoenix/scripts/gather_incident_context.py`

### Permission denied
```bash
# Make sure user has permissions
sudo chown -R $USER:$USER ~/.n8n
```

---

## 📊 Version Recommendation

**Use Latest Stable**:
- Docker: `n8nio/n8n:latest` (auto-updates)
- npm: `npm install n8n@latest -g`

**For Stability** (pin version):
- Docker: `n8nio/n8n:1.20.0` (or latest stable)
- npm: `npm install n8n@1.20.0 -g`

**Check version**:
```bash
n8n --version
```

---

## ✅ Final Recommendation

**For CloudPhoenix**: Use **Docker method on Ubuntu**

**Why**:
1. ✅ Easy setup and updates
2. ✅ Can mount cloudphoenix directory
3. ✅ Can use Execute Command nodes
4. ✅ Direct access to local services
5. ✅ Free and full control
6. ✅ Easy to backup (volume)

**Steps**:
1. Install Docker on Ubuntu
2. Use docker-compose.yml from above
3. Mount cloudphoenix directory
4. Access at `http://localhost:5678`
5. Start building workflows!

---

**You're ready to deploy n8n!** 🚀

