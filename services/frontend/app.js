// CloudPhoenix Frontend - Status Dashboard
// Displays current cloud provider, health status, and system data

const API_BASE_URL = window.location.origin;
const REFRESH_INTERVAL = 5000; // Refresh every 5 seconds
let refreshTimer = null;

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    loadData();
    startAutoRefresh();
});

// Load all data from backend
async function loadData() {
    try {
        // Get cloud status (which cloud we're on)
        const cloudStatus = await fetch(`${API_BASE_URL}/api/cloud-status`);
        const cloudData = await cloudStatus.json();

        // Get health status
        const healthStatus = await fetch(`${API_BASE_URL}/api/health`);
        const healthData = await healthStatus.json();

        // Get data from backend
        const dataResponse = await fetch(`${API_BASE_URL}/api/data`);
        const systemData = await dataResponse.json().catch(() => ({ items: [] }));

        // Update UI
        updateCloudStatus(cloudData);
        updateHealthStatus(healthData);
        updateSystemData(systemData);
        updateTimestamp();

        // Hide loading, show content
        document.getElementById('loading').style.display = 'none';
        document.getElementById('content').style.display = 'block';

    } catch (error) {
        console.error('Error loading data:', error);
        const loadingEl = document.getElementById('loading');
        loadingEl.innerHTML = ''; // Clear first
        const errorDiv = document.createElement('div');
        errorDiv.style.color = 'red';
        errorDiv.textContent = 'Error loading data. Please check backend services.';
        loadingEl.appendChild(errorDiv);
    }
}

// Update cloud provider status
function updateCloudStatus(data) {
    const cloudProvider = data.provider || 'unknown';
    const isHealthy = data.status === 'healthy' || data.status === 'operational';
    
    const badge = document.getElementById('cloud-badge');
    badge.textContent = cloudProvider.toUpperCase();
    badge.className = `cloud-badge ${cloudProvider.toLowerCase()}`;

    const indicator = document.getElementById('cloud-status-indicator');
    const text = document.getElementById('cloud-status-text');
    
    if (isHealthy) {
        indicator.className = 'status-indicator healthy';
        text.textContent = 'Operational';
    } else {
        indicator.className = 'status-indicator degraded';
        text.textContent = 'Degraded';
    }
}

// Update health status
function updateHealthStatus(data) {
    const score = data.score || 0;
    const status = data.status || 'unknown';
    const failoverLevel = data.failover_level || 'no_action';

    // Update health score
    const healthScoreEl = document.getElementById('health-score');
    healthScoreEl.textContent = score;
    
    // Color based on score
    if (score <= 3) {
        healthScoreEl.className = 'health-score low';
    } else if (score <= 10) {
        healthScoreEl.className = 'health-score medium';
    } else {
        healthScoreEl.className = 'health-score high';
    }

    // Update failover level
    const failoverLevelText = {
        'no_action': 'No Action Required',
        'app_self_healing': 'App Self-Healing',
        'region_failover': 'Region Failover',
        'dr_failover': 'DR Failover Required'
    };
    document.getElementById('failover-level').textContent = failoverLevelText[failoverLevel] || failoverLevel;

    // Update DR status
    const drStatusEl = document.getElementById('dr-status');
    if (failoverLevel === 'dr_failover' || score >= 11) {
        drStatusEl.className = 'dr-status active';
        drStatusEl.textContent = '⚠️ DR FAILOVER IN PROGRESS OR REQUIRED';
    } else {
        drStatusEl.className = 'dr-status normal';
        drStatusEl.textContent = '✅ DR Status: Normal Operation';
    }
}

// Update system data
function updateSystemData(data) {
    const dataItemsEl = document.getElementById('data-items');
    
    // Check backend services status
    const backendHealthy = data.items && data.items.length >= 0;
    const backendIndicator = document.getElementById('backend-status-indicator');
    const backendText = document.getElementById('backend-status-text');
    
    if (backendHealthy) {
        backendIndicator.className = 'status-indicator healthy';
        backendText.textContent = 'Operational';
    } else {
        backendIndicator.className = 'status-indicator degraded';
        backendText.textContent = 'Degraded';
    }

    // Display data items (XSS-safe using textContent)
    dataItemsEl.innerHTML = ''; // Clear first
    if (data.items && data.items.length > 0) {
        data.items.forEach(item => {
            const div = document.createElement('div');
            div.className = 'data-item';
            
            const nameSpan = document.createElement('span');
            const strong = document.createElement('strong');
            strong.textContent = item.name || item.id || 'Item';
            nameSpan.appendChild(strong);
            
            const valueSpan = document.createElement('span');
            valueSpan.textContent = item.value || item.status || 'N/A';
            
            div.appendChild(nameSpan);
            div.appendChild(valueSpan);
            dataItemsEl.appendChild(div);
        });
    } else {
        const div = document.createElement('div');
        div.className = 'data-item';
        const span = document.createElement('span');
        span.textContent = 'No data items available';
        div.appendChild(span);
        dataItemsEl.appendChild(div);
    }

    // Update database status
    const dbIndicator = document.getElementById('db-status-indicator');
    const dbText = document.getElementById('db-status-text');
    const dbType = document.getElementById('db-type');
    
    if (data.db_status) {
        if (data.db_status === 'connected' || data.db_status === 'healthy') {
            dbIndicator.className = 'status-indicator healthy';
            dbText.textContent = 'Connected';
            dbType.textContent = data.db_type || 'Database';
        } else {
            dbIndicator.className = 'status-indicator unhealthy';
            dbText.textContent = 'Disconnected';
            dbType.textContent = 'Database Error';
        }
    } else {
        // Try to infer from cloud provider
        const cloudProvider = document.getElementById('cloud-badge').textContent.toLowerCase();
        dbIndicator.className = 'status-indicator healthy';
        dbText.textContent = 'Connected';
        dbType.textContent = cloudProvider === 'aws' ? 'RDS PostgreSQL' : 'Azure SQL';
    }
}

// Update timestamp
function updateTimestamp() {
    const now = new Date();
    document.getElementById('timestamp').textContent = 
        `Last updated: ${now.toLocaleString()}`;
}

// Refresh data
function refreshData() {
    loadData();
}

// Start auto-refresh
function startAutoRefresh() {
    refreshTimer = setInterval(loadData, REFRESH_INTERVAL);
}

// Stop auto-refresh (optional)
function stopAutoRefresh() {
    if (refreshTimer) {
        clearInterval(refreshTimer);
        refreshTimer = null;
    }
}

// Detect if we're in a failover scenario
function detectFailover() {
    const healthScore = parseInt(document.getElementById('health-score').textContent);
    const drStatus = document.getElementById('dr-status');
    
    if (healthScore >= 11 && drStatus.className.includes('active')) {
        // Show notification or alert
        console.log('DR failover detected or required');
    }
}

// Add keyboard shortcuts
document.addEventListener('keydown', function(e) {
    if (e.key === 'r' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        refreshData();
    }
});

