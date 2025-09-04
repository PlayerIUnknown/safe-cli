// Global variables
let currentUser = null;
let currentTab = 'endpoints';
let refreshIntervals = {};

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
    setupTwitterLikeInteractions();
});

// Ultra-modern interactions
function setupTwitterLikeInteractions() {
    // Enhanced hover effects with smooth transitions
    document.addEventListener('mouseover', function(e) {
        const card = e.target.closest('.endpoint-card, .request-card');
        if (card) {
            card.style.transform = 'translateY(-4px) scale(1.02)';
            card.style.boxShadow = '0 12px 40px rgba(0, 0, 0, 0.4)';
        }
    });
    
    document.addEventListener('mouseout', function(e) {
        const card = e.target.closest('.endpoint-card, .request-card');
        if (card) {
            card.style.transform = 'translateY(0) scale(1)';
            card.style.boxShadow = 'none';
        }
    });
    
    // Enhanced button click animations
    document.addEventListener('click', function(e) {
        if (e.target.closest('.btn')) {
            const btn = e.target.closest('.btn');
            btn.style.transform = 'scale(0.95)';
            btn.style.filter = 'brightness(0.9)';
            setTimeout(() => {
                btn.style.transform = 'scale(1)';
                btn.style.filter = 'brightness(1)';
            }, 150);
        }
    });
    
    // Add ripple effect to buttons
    document.addEventListener('click', function(e) {
        if (e.target.closest('.btn')) {
            createRippleEffect(e, e.target.closest('.btn'));
        }
    });
    
    // Enhanced keyboard navigation
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeModal();
        }
        if (e.key === 'Enter' && e.target.closest('.nav-item')) {
            e.target.closest('.nav-item').click();
        }
    });
    
    // Add smooth scroll behavior
    document.documentElement.style.scrollBehavior = 'smooth';
    
    // Add loading animations
    setupLoadingAnimations();
}

// Create ripple effect for buttons
function createRippleEffect(event, button) {
    const ripple = document.createElement('span');
    const rect = button.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height);
    const x = event.clientX - rect.left - size / 2;
    const y = event.clientY - rect.top - size / 2;
    
    ripple.style.width = ripple.style.height = size + 'px';
    ripple.style.left = x + 'px';
    ripple.style.top = y + 'px';
    ripple.classList.add('ripple');
    
    button.appendChild(ripple);
    
    setTimeout(() => {
        ripple.remove();
    }, 600);
}

// Setup loading animations
function setupLoadingAnimations() {
    // Add staggered animation to cards
    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                setTimeout(() => {
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                }, index * 100);
            }
        });
    });
    
    // Observe all cards
    document.querySelectorAll('.endpoint-card, .request-card').forEach(card => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        card.style.transition = 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
        observer.observe(card);
    });
}

async function initializeApp() {
    try {
        // Check authentication
        await checkAuth();
        
        // Load initial data
        await loadInitialData();
        
        // Set up navigation
        setupNavigation();
        
        // Set up auto-refresh
        setupAutoRefresh();
        
    } catch (error) {
        console.error('Failed to initialize app:', error);
        showToast('Failed to initialize application', 'error');
    }
}

async function checkAuth() {
    try {
        const response = await fetch('/api/auth/check', {
            credentials: 'same-origin'
        });
        
        if (response.ok) {
            const user = await response.json();
            currentUser = user;
            document.getElementById('userName').textContent = user.username || 'User';
        } else {
            // Redirect to login if not authenticated
            window.location.href = '/login';
        }
    } catch (error) {
        console.error('Auth check failed:', error);
        window.location.href = '/login';
    }
}

async function loadInitialData() {
    if (currentUser) {
        await Promise.all([
            loadEndpoints(),
            loadBlacklist(),
            loadRequests()
        ]);
    }
}

function setupNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    const tabContents = document.querySelectorAll('.tab-content');
    
    navItems.forEach(item => {
        item.addEventListener('click', () => {
            const tabName = item.dataset.tab;
            switchTab(tabName);
        });
    });
}

function switchTab(tabName) {
    // Update navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
    
    // Update content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById(`${tabName}-tab`).classList.add('active');
    
    currentTab = tabName;
    
    // Load data for the active tab
    switch (tabName) {
        case 'endpoints':
            loadEndpoints();
            break;
        case 'blacklist':
            loadBlacklist();
            break;
        case 'requests':
            loadRequests();
            break;
    }
}

function setupAutoRefresh() {
    // Refresh endpoints every 30 seconds
    refreshIntervals.endpoints = setInterval(loadEndpoints, 30000);
    
    // Refresh requests every 5 seconds
    refreshIntervals.requests = setInterval(loadRequests, 5000);
}

// Endpoints functions
async function loadEndpoints() {
    try {
        const response = await fetch('/api/endpoints', {
            credentials: 'same-origin'
        });
        
        if (response.ok) {
            const endpoints = await response.json();
            displayEndpoints(endpoints);
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('Failed to load endpoints:', error);
        showEndpointsError();
    }
}

function displayEndpoints(endpoints) {
    const grid = document.getElementById('endpointsGrid');
    
    if (!endpoints || endpoints.length === 0) {
        grid.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-desktop"></i>
                <p>No endpoints registered</p>
            </div>
        `;
        return;
    }
    
    grid.innerHTML = endpoints.map(endpoint => `
        <div class="endpoint-card">
            <div class="endpoint-header">
                <div class="endpoint-name">${escapeHtml(endpoint.name)}</div>
                <div class="endpoint-status ${endpoint.is_active ? 'active' : 'inactive'}">
                    ${endpoint.is_active ? 'Active' : 'Inactive'}
                </div>
            </div>
            <div class="endpoint-details">
                <div class="endpoint-detail">
                    <span class="endpoint-detail-label">Hostname:</span>
                    <span class="endpoint-detail-value">${escapeHtml(endpoint.hostname)}</span>
                </div>
                <div class="endpoint-detail">
                    <span class="endpoint-detail-label">User:</span>
                    <span class="endpoint-detail-value">${escapeHtml(endpoint.user_name)}</span>
                </div>
                <div class="endpoint-detail">
                    <span class="endpoint-detail-label">IP Address:</span>
                    <span class="endpoint-detail-value">${escapeHtml(endpoint.ip_address || 'Unknown')}</span>
                </div>
                <div class="endpoint-detail">
                    <span class="endpoint-detail-label">Last Seen:</span>
                    <span class="endpoint-detail-value">${formatDate(endpoint.last_seen)}</span>
                </div>
            </div>
            <div class="endpoint-actions">
                ${endpoint.is_active ? `
                    <button class="btn btn-warning" onclick="deactivateEndpoint('${endpoint.id}')">
                        <i class="fas fa-pause"></i>
                        Deactivate
                    </button>
                ` : `
                    <button class="btn btn-primary" onclick="activateEndpoint('${endpoint.id}')">
                        <i class="fas fa-play"></i>
                        Activate
                    </button>
                `}
                <button class="btn btn-warning" onclick="uninstallEndpoint('${endpoint.id}')">
                    <i class="fas fa-uninstall"></i>
                    Uninstall
                </button>
                <button class="btn btn-danger" onclick="deleteEndpoint('${endpoint.id}')">
                    <i class="fas fa-trash"></i>
                    Delete
                </button>
            </div>
        </div>
    `).join('');
}

function showEndpointsError() {
    const grid = document.getElementById('endpointsGrid');
    grid.innerHTML = `
        <div class="empty-state">
            <i class="fas fa-exclamation-triangle"></i>
            <p>Failed to load endpoints</p>
        </div>
    `;
}

async function deactivateEndpoint(endpointId) {
    showConfirmModal(
        'Deactivate Endpoint',
        'Are you sure you want to deactivate this endpoint? It will no longer be able to connect.',
        async () => {
            try {
                const response = await fetch(`/api/endpoints/${endpointId}/deactivate`, {
                    method: 'POST',
                    credentials: 'same-origin'
                });
                
                if (response.ok) {
                    showToast('Endpoint deactivated successfully', 'success');
                    loadEndpoints();
                } else {
                    throw new Error(`HTTP ${response.status}`);
                }
            } catch (error) {
                console.error('Failed to deactivate endpoint:', error);
                showToast('Failed to deactivate endpoint', 'error');
            }
        }
    );
}

async function activateEndpoint(endpointId) {
    try {
        const response = await fetch(`/api/endpoints/${endpointId}/activate`, {
            method: 'POST',
            credentials: 'same-origin'
        });
        
        if (response.ok) {
            showToast('Endpoint activated successfully', 'success');
            loadEndpoints();
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('Failed to activate endpoint:', error);
        showToast('Failed to activate endpoint', 'error');
    }
}

async function deleteEndpoint(endpointId) {
    showConfirmModal(
        'Delete Endpoint',
        'Are you sure you want to permanently delete this endpoint? This action cannot be undone.',
        async () => {
            try {
                const response = await fetch(`/api/endpoints/${endpointId}`, {
                    method: 'DELETE',
                    credentials: 'same-origin'
                });
                
                if (response.ok) {
                    showToast('Endpoint deleted successfully', 'success');
                    loadEndpoints();
                } else {
                    throw new Error(`HTTP ${response.status}`);
                }
            } catch (error) {
                console.error('Failed to delete endpoint:', error);
                showToast('Failed to delete endpoint', 'error');
            }
        }
    );
}

async function uninstallEndpoint(endpointId) {
    showConfirmModal(
        'Uninstall Endpoint',
        'This will trigger the uninstall script on the endpoint to clean up all Safe CLI components, then remove it from the dashboard. The agent will automatically clean up on the next command attempt. Continue?',
        async () => {
            try {
                const response = await fetch(`/api/endpoints/${endpointId}/uninstall`, {
                    method: 'POST',
                    credentials: 'same-origin'
                });
                
                if (response.ok) {
                    const result = await response.json();
                    showToast(result.message || 'Endpoint uninstalled successfully', 'success');
                    loadEndpoints();
                } else {
                    const error = await response.json();
                    throw new Error(error.error || `HTTP ${response.status}`);
                }
            } catch (error) {
                console.error('Failed to uninstall endpoint:', error);
                showToast('Failed to uninstall endpoint', 'error');
            }
        }
    );
}

function refreshEndpoints() {
    loadEndpoints();
    showToast('Endpoints refreshed', 'success');
}

// Blacklist functions
async function loadBlacklist() {
    try {
        const response = await fetch('/api/blacklist', {
            credentials: 'same-origin'
        });
        
        if (response.ok) {
            const blacklist = await response.json();
            displayBlacklist(blacklist);
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('Failed to load blacklist:', error);
        showToast('Failed to load blacklist', 'error');
    }
}

function displayBlacklist(blacklist) {
    const textarea = document.getElementById('blacklistTextarea');
    textarea.value = blacklist.join('\n');
}

async function saveBlacklist() {
    const textarea = document.getElementById('blacklistTextarea');
    const commands = textarea.value.split('\n').filter(cmd => cmd.trim() !== '');
    
    try {
        const response = await fetch('/api/blacklist', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            credentials: 'same-origin',
            body: JSON.stringify({ blacklist: commands })
        });
        
        if (response.ok) {
            showToast('Blacklist updated successfully', 'success');
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('Failed to save blacklist:', error);
        showToast('Failed to save blacklist', 'error');
    }
}

// Requests functions
async function loadRequests() {
    try {
        console.log('DEBUG: Loading requests...');
        const response = await fetch('/api/requests', {
            credentials: 'same-origin'
        });
        
        console.log('DEBUG: Requests response status:', response.status);
        
        if (response.ok) {
            const requests = await response.json();
            console.log('DEBUG: Requests data:', requests);
            displayRequests(requests);
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('Failed to load requests:', error);
        showRequestsError();
    }
}

function displayRequests(requests) {
    console.log('DEBUG: displayRequests called with:', requests);
    const list = document.getElementById('requestsList');
    
    if (!requests || Object.keys(requests).length === 0) {
        console.log('DEBUG: No requests to display');
        list.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-clock"></i>
                <p>No pending requests</p>
            </div>
        `;
        return;
    }
    
    // Filter out expired requests on the frontend
    const currentTime = Date.now();
    const validRequests = {};
    Object.entries(requests).forEach(([reqId, req]) => {
        const requestTime = new Date(req.timestamp).getTime();
        const elapsedSeconds = Math.floor((currentTime - requestTime) / 1000);
        if (elapsedSeconds < 30) {
            validRequests[reqId] = req;
        }
    });
    
    if (Object.keys(validRequests).length === 0) {
        list.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-clock"></i>
                <p>No pending requests</p>
            </div>
        `;
        return;
    }
    
    console.log('DEBUG: Displaying', Object.keys(validRequests).length, 'valid requests');
    
    list.innerHTML = Object.entries(validRequests).map(([reqId, req]) => {
        const requestTime = new Date(req.timestamp).getTime();
        const currentTime = Date.now();
        const elapsedSeconds = Math.floor((currentTime - requestTime) / 1000);
        const timeLeft = Math.max(0, 30 - elapsedSeconds);
        const timeClass = timeLeft < 10 ? 'warning' : 'ok';
        
        return `
            <div class="request-card">
                <div class="request-header">
                    <div class="request-endpoint">${escapeHtml(req.endpoint_name)} (${escapeHtml(req.endpoint_hostname)})</div>
                    <div class="request-timer ${timeClass}">${timeLeft}s</div>
                </div>
                <div class="request-details">
                    <div class="request-detail">
                        <span class="request-detail-label">User:</span>
                        <span class="request-detail-value">${escapeHtml(req.user)}</span>
                    </div>
                    <div class="request-detail">
                        <span class="request-detail-label">Command:</span>
                        <span class="request-detail-value">${escapeHtml(req.command)}</span>
                    </div>
                </div>
                <div class="request-actions">
                    <button class="btn btn-primary" onclick="approveRequest('${reqId}')">
                        <i class="fas fa-check"></i>
                        Approve
                    </button>
                    <button class="btn btn-danger" onclick="denyRequest('${reqId}')">
                        <i class="fas fa-times"></i>
                        Deny
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

function showRequestsError() {
    const list = document.getElementById('requestsList');
    list.innerHTML = `
        <div class="empty-state">
            <i class="fas fa-exclamation-triangle"></i>
            <p>Failed to load requests</p>
        </div>
    `;
}

async function approveRequest(reqId) {
    try {
        const response = await fetch(`/api/approve/${reqId}`, {
            method: 'POST',
            credentials: 'same-origin'
        });
        
        if (response.ok) {
            showToast('Request approved successfully', 'success');
            loadRequests();
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('Failed to approve request:', error);
        showToast('Failed to approve request', 'error');
    }
}

async function denyRequest(reqId) {
    showConfirmModal(
        'Deny Request',
        'Are you sure you want to deny this command request?',
        async () => {
            try {
                const response = await fetch(`/api/deny/${reqId}`, {
                    method: 'POST',
                    credentials: 'same-origin'
                });
                
                if (response.ok) {
                    showToast('Request denied successfully', 'success');
                    loadRequests();
                } else {
                    throw new Error(`HTTP ${response.status}`);
                }
            } catch (error) {
                console.error('Failed to deny request:', error);
                showToast('Failed to deny request', 'error');
            }
        }
    );
}

function refreshRequests() {
    loadRequests();
    showToast('Requests refreshed', 'success');
}

// Utility functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(dateString) {
    if (!dateString) return 'Unknown';
    const date = new Date(dateString);
    return date.toLocaleString();
}

function showToast(message, type = 'success') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <div style="display: flex; align-items: center; gap: 0.5rem;">
            <i class="fas fa-${type === 'success' ? 'check-circle' : type === 'error' ? 'exclamation-circle' : 'info-circle'}"></i>
            <span>${message}</span>
        </div>
    `;
    
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 5000);
}

// Modal functions
let pendingAction = null;

function showConfirmModal(title, message, action) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalMessage').textContent = message;
    document.getElementById('confirmModal').classList.add('show');
    pendingAction = action;
}

function closeModal() {
    document.getElementById('confirmModal').classList.remove('show');
    pendingAction = null;
}

function confirmAction() {
    if (pendingAction) {
        pendingAction();
    }
    closeModal();
}

// Logout function
async function logout() {
    try {
        const response = await fetch('/logout', {
            method: 'POST',
            credentials: 'same-origin'
        });
        
        if (response.ok) {
            window.location.href = '/login';
        } else {
            throw new Error(`HTTP ${response.status}`);
        }
    } catch (error) {
        console.error('Logout failed:', error);
        showToast('Logout failed', 'error');
    }
}

// Clean up intervals when page unloads
window.addEventListener('beforeunload', () => {
    Object.values(refreshIntervals).forEach(interval => {
        clearInterval(interval);
    });
});

// Installation functions
function downloadInstaller() {
    // Create a download link for the installer script
    const link = document.createElement('a');
    link.href = '/safe-cli-installer.sh';
    link.download = 'safe-cli-installer.sh';
    link.style.display = 'none';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    showToast('Installer download started', 'success');
}

function copyToClipboard(text) {
    if (navigator.clipboard && window.isSecureContext) {
        // Use the modern clipboard API
        navigator.clipboard.writeText(text).then(() => {
            showToast('Copied to clipboard', 'success');
        }).catch(err => {
            console.error('Failed to copy: ', err);
            fallbackCopyToClipboard(text);
        });
    } else {
        // Fallback for older browsers
        fallbackCopyToClipboard(text);
    }
}

function fallbackCopyToClipboard(text) {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    
    try {
        document.execCommand('copy');
        showToast('Copied to clipboard', 'success');
    } catch (err) {
        console.error('Failed to copy: ', err);
        showToast('Failed to copy to clipboard', 'error');
    }
    
    document.body.removeChild(textArea);
}
