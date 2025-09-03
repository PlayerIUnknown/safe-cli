from flask import Flask, request, jsonify, render_template_string, session, redirect, url_for, send_from_directory
import time
import uuid
import socket
import platform
import bcrypt
from datetime import datetime, timezone
from supabase import create_client, Client
from config import Config

# Initialize the Flask application
app = Flask(__name__)
app.config.from_object(Config)
app.secret_key = Config.SECRET_KEY

# Configure session to work properly
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
app.config['PERMANENT_SESSION_LIFETIME'] = 86400  # 24 hours

# --- Supabase Client ---
def get_supabase_client() -> Client:
    """Get Supabase client"""
    if not Config.SUPABASE_URL or not Config.SUPABASE_KEY:
        print(f"ERROR: Supabase configuration missing!")
        print(f"SUPABASE_URL: {'SET' if Config.SUPABASE_URL else 'MISSING'}")
        print(f"SUPABASE_KEY: {'SET' if Config.SUPABASE_KEY else 'MISSING'}")
        print("Please create a .env file with your Supabase credentials")
        raise Exception("Supabase URL and Key must be set in environment variables")
    
    try:
        # Clear any proxy environment variables that might cause issues
        Config.clear_proxy_env()
        
        # Create client with explicit parameters to avoid proxy issues
        client = create_client(
            supabase_url=Config.SUPABASE_URL,
            supabase_key=Config.SUPABASE_KEY
        )
        return client
    except Exception as e:
        print(f"ERROR: Failed to create Supabase client: {str(e)}")
        raise Exception(f"Failed to initialize Supabase client: {str(e)}")

# --- Authentication Helpers ---
def hash_password(password):
    """Hash a password using bcrypt"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password, hashed):
    """Verify a password against its hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def require_auth(f):
    """Decorator to require authentication"""
    def decorated_function(*args, **kwargs):
        print(f"DEBUG: require_auth called for {f.__name__}, session: {dict(session)}")
        if 'user_id' not in session:
            print("DEBUG: No user_id in session, redirecting to login")
            return redirect(url_for('login'))
        print(f"DEBUG: User authenticated: {session['user_id']}")
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

# Frontend files are now in the frontend/ directory

# --- Authentication Routes ---
@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login')
def login():
    return send_from_directory('frontend', 'login.html')

@app.route('/register')
def register():
    return send_from_directory('frontend', 'register.html')

@app.route('/api/auth/login', methods=['POST'])
def api_login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    try:
        print(f"DEBUG: Login attempt for username: {username}")
        supabase = get_supabase_client()
        response = supabase.table('root_users').select('*').eq('username', username).eq('is_active', True).execute()
        
        print(f"DEBUG: Database response: {response.data}")
        
        if response.data:
            user_data = response.data[0]
            print(f"DEBUG: Found user: {user_data['username']}, checking password...")
            
            if verify_password(password, user_data['password_hash']):
                print(f"DEBUG: Password verified successfully")
                session['user_id'] = user_data['id']
                session['username'] = user_data['username']
                session.permanent = True
                return jsonify({
                    "success": True, 
                    "message": "Login successful",
                    "user_id": user_data['id'],
                    "username": user_data['username']
                })
            else:
                print(f"DEBUG: Password verification failed")
                return jsonify({"error": "Invalid password"}), 401
        else:
            print(f"DEBUG: No user found with username: {username}")
            return jsonify({"error": "User not found"}), 401
    except Exception as e:
        print(f"DEBUG: Login exception: {str(e)}")
        return jsonify({"error": f"Login failed: {str(e)}"}), 500

@app.route('/api/auth/register', methods=['POST'])
def api_register():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    
    try:
        supabase = get_supabase_client()
        
        # Check if user already exists
        existing = supabase.table('root_users').select('id').or_(f'username.eq.{username},email.eq.{email}').execute()
        if existing.data:
            return jsonify({"error": "Username or email already exists"}), 400
        
        # Create new user
        password_hash = hash_password(password)
        response = supabase.table('root_users').insert({
            'username': username,
            'email': email,
            'password_hash': password_hash
        }).execute()
        
        if response.data:
            # Add default blacklist for new user
            default_commands = ['rm', 'sudo', 'fdisk', 'mkfs']
            blacklist_data = [{'root_user_id': response.data[0]['id'], 'command': cmd} for cmd in default_commands]
            supabase.table('blacklist').insert(blacklist_data).execute()
            
            return jsonify({"success": True, "message": "Registration successful"})
        else:
            return jsonify({"error": "Registration failed. Please try again."}), 500
    except Exception as e:
        return jsonify({"error": "Registration failed. Please try again."}), 500

@app.route('/logout', methods=['POST'])
def logout():
    session.clear()
    return redirect(url_for('login'))

# --- Frontend Routes ---
@app.route('/dashboard')
@require_auth
def dashboard():
    print("DEBUG: Serving dashboard HTML")
    return send_from_directory('frontend', 'index.html')

@app.route('/styles.css')
def serve_css():
    print("DEBUG: Serving CSS file")
    return send_from_directory('frontend', 'styles.css')

@app.route('/app.js')
def serve_js():
    print("DEBUG: Serving JS file")
    return send_from_directory('frontend', 'app.js')

@app.route('/safe-cli-installer.sh')
def serve_installer():
    print("DEBUG: Serving installer script")
    return send_from_directory('.', 'safe-cli-installer.sh')

@app.route('/fix-endpoint-issue.sh')
def serve_fix_script():
    print("DEBUG: Serving endpoint fix script")
    return send_from_directory('.', 'fix-endpoint-issue.sh')

# --- API Endpoints ---
@app.route('/api/auth/check', methods=['GET'])
@require_auth
def check_auth():
    """Check if user is authenticated and return user info"""
    return jsonify({
        'user_id': session['user_id'],
        'username': session['username']
    })

@app.route('/api/blacklist', methods=['GET'])
@require_auth
def get_blacklist():
    try:
        supabase = get_supabase_client()
        response = supabase.table('blacklist').select('command').eq('root_user_id', session['user_id']).order('command').execute()
        blacklist_commands = [row['command'] for row in response.data]
        return jsonify(blacklist_commands)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/agent/blacklist', methods=['GET'])
def get_agent_blacklist():
    """Get blacklist for agent without authentication - uses root_user_id from query param"""
    try:
        root_user_id = request.args.get('root_user_id')
        if not root_user_id:
            return jsonify({"error": "root_user_id parameter required"}), 400
            
        supabase = get_supabase_client()
        response = supabase.table('blacklist').select('command').eq('root_user_id', root_user_id).order('command').execute()
        blacklist_commands = [row['command'] for row in response.data]
        return jsonify(blacklist_commands)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/agent/check_command', methods=['POST'])
def check_command():
    """Check if command should be blocked or allowed (no authentication required)"""
    try:
        data = request.json
        print(f"DEBUG: check_command called with data: {data}")
        if not all(key in data for key in ['command', 'root_user_id', 'endpoint_id']):
            print(f"DEBUG: Missing required fields. Got: {list(data.keys()) if data else 'None'}")
            return jsonify({"error": "Missing required fields"}), 400
        
        command = data['command']
        root_user_id = data['root_user_id']
        endpoint_id = data['endpoint_id']
        
        supabase = get_supabase_client()
        
        # Check if command is in blacklist
        print(f"DEBUG: Checking blacklist for command '{command}' and user '{root_user_id}'")
        blacklist_response = supabase.table('blacklist').select('command').eq('root_user_id', root_user_id).eq('command', command).execute()
        print(f"DEBUG: Blacklist response: {blacklist_response.data}")
        
        # Also check all blacklist entries for this user
        all_blacklist = supabase.table('blacklist').select('command').eq('root_user_id', root_user_id).execute()
        print(f"DEBUG: All blacklist entries for user: {all_blacklist.data}")
        
        # Check if endpoint exists
        endpoint_check = supabase.table('endpoints').select('id, name, user_name').eq('id', endpoint_id).execute()
        print(f"DEBUG: Endpoint check: {endpoint_check.data}")
        
        if blacklist_response.data:
            # Command is blacklisted, create approval request
            print(f"DEBUG: Command '{command}' IS in blacklist, creating approval request")
            # Get endpoint info to get user_name
            endpoint_response = supabase.table('endpoints').select('user_name').eq('id', endpoint_id).execute()
            user_name = endpoint_response.data[0]['user_name'] if endpoint_response.data else 'unknown'
            print(f"DEBUG: Endpoint user_name: {user_name}")
            
            approval_data = {
                'endpoint_id': endpoint_id,
                'user_name': user_name,
                'command': command,
                'status': 'pending',
                'created_at': datetime.now(timezone.utc).isoformat()
            }
            print(f"DEBUG: Creating approval request with data: {approval_data}")
            
            approval_response = supabase.table('approval_requests').insert(approval_data).execute()
            print(f"DEBUG: Approval response: {approval_response.data}")
            
            if approval_response.data:
                print(f"DEBUG: Successfully created approval request: {approval_response.data[0]['id']}")
                return jsonify({
                    "blocked": True,
                    "request_id": approval_response.data[0]['id'],
                    "message": "Command blocked - approval required"
                })
            else:
                print(f"DEBUG: Failed to create approval request")
                return jsonify({"error": "Failed to create approval request"}), 500
        else:
            # Command is not blacklisted, allow it
            print(f"DEBUG: Command '{command}' is NOT in blacklist, allowing it")
            return jsonify({
                "blocked": False,
                "message": "Command allowed"
            })
            
    except Exception as e:
        print(f"DEBUG: Error in check_command: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/api/blacklist', methods=['POST'])
def update_blacklist():
    # Get user_id from query parameter or session
    user_id = request.args.get('user_id') or session.get('user_id')
    if not user_id:
        return jsonify({"error": "User ID required"}), 400
        
    data = request.json
    if 'blacklist' not in data or not isinstance(data['blacklist'], list):
        return jsonify({"error": "Invalid format"}), 400

    try:
        supabase = get_supabase_client()
        
        # Clear existing blacklist for current user
        supabase.table('blacklist').delete().eq('root_user_id', user_id).execute()
        
        # Insert new blacklist commands
        if data['blacklist']:
            commands_data = [{'root_user_id': user_id, 'command': cmd.strip()} for cmd in data['blacklist'] if cmd.strip()]
            if commands_data:
                supabase.table('blacklist').insert(commands_data).execute()
        
        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/register_endpoint', methods=['POST'])
def register_endpoint():
    data = request.json
    if not all(key in data for key in ['root_user_id', 'name', 'hostname', 'user_name']):
        return jsonify({"error": "Missing required fields: root_user_id, name, hostname, user_name"}), 400
    
    try:
        supabase = get_supabase_client()
        
        # Verify root user exists
        user_check = supabase.table('root_users').select('id').eq('id', data['root_user_id']).eq('is_active', True).execute()
        if not user_check.data:
            return jsonify({"error": "Invalid root user"}), 400
        
        # Get client IP address
        client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', ''))
        
        # Check if endpoint already exists
        existing = supabase.table('endpoints').select('id').eq('hostname', data['hostname']).eq('user_name', data['user_name']).eq('root_user_id', data['root_user_id']).execute()
        
        if existing.data:
            # Update existing endpoint
            response = supabase.table('endpoints').update({
                'name': data['name'],
                'ip_address': client_ip,
                'os_info': data.get('os_info', ''),
                'last_seen': datetime.now(timezone.utc).isoformat(),
                'is_active': True,
                'updated_at': datetime.now(timezone.utc).isoformat()
            }).eq('id', existing.data[0]['id']).execute()
            
            endpoint_id = existing.data[0]['id']
        else:
            # Create new endpoint
            response = supabase.table('endpoints').insert({
                'root_user_id': data['root_user_id'],
                'name': data['name'],
                'hostname': data['hostname'],
                'ip_address': client_ip,
                'user_name': data['user_name'],
                'os_info': data.get('os_info', ''),
                'last_seen': datetime.now(timezone.utc).isoformat(),
                'is_active': True
            }).execute()
            
            endpoint_id = response.data[0]['id']
        
        return jsonify({"endpoint_id": str(endpoint_id), "status": "registered"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/request_approval', methods=['POST'])
def request_approval():
    data = request.json
    if not all(key in data for key in ['endpoint_id', 'user', 'command']):
        return jsonify({"error": "Missing required fields: endpoint_id, user, command"}), 400
    
    try:
        supabase = get_supabase_client()
        
        # Verify endpoint exists and is active
        endpoint_check = supabase.table('endpoints').select('id,is_active').eq('id', data['endpoint_id']).execute()
        if not endpoint_check.data or not endpoint_check.data[0]['is_active']:
            return jsonify({"error": "Invalid or inactive endpoint"}), 400
        
        # Insert approval request
        response = supabase.table('approval_requests').insert({
            'endpoint_id': data['endpoint_id'],
            'user_name': data['user'],
            'command': data['command'],
            'status': 'pending'
        }).execute()
        
        req_id = response.data[0]['id']
        return jsonify({"request_id": str(req_id)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/endpoints', methods=['GET'])
@require_auth
def get_endpoints():
    try:
        user_id = session.get('user_id')
        if not user_id:
            return jsonify([])
        supabase = get_supabase_client()
        
        # Get all endpoints for current user (both active and inactive)
        response = supabase.table('endpoints').select('*').eq('root_user_id', user_id).order('last_seen', desc=True).execute()
        
        print(f"DEBUG: Supabase response: {response}")
        print(f"DEBUG: Found {len(response.data)} endpoints for user {user_id}")
        for endpoint in response.data:
            print(f"DEBUG: Endpoint {endpoint['id']} - {endpoint['name']} - Active: {endpoint['is_active']}")
        
        return jsonify(response.data)
    except Exception as e:
        print(f"DEBUG: Error in get_endpoints: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/api/endpoints/<endpoint_id>/deactivate', methods=['POST'])
def deactivate_endpoint(endpoint_id):
    """Deactivate endpoint (soft delete - keeps in database but marks as inactive)"""
    try:
        # Get user_id from query parameter or session
        user_id = request.args.get('user_id') or session.get('user_id')
        if not user_id:
            return jsonify({"error": "User ID required"}), 400
            
        supabase = get_supabase_client()
        
        # Verify endpoint belongs to current user
        endpoint_check = supabase.table('endpoints').select('id, root_user_id').eq('id', endpoint_id).execute()
        
        if not endpoint_check.data:
            return jsonify({"error": "Endpoint not found"}), 404
        
        if endpoint_check.data[0]['root_user_id'] != user_id:
            return jsonify({"error": "Access denied"}), 403
        
        # Mark endpoint as inactive
        response = supabase.table('endpoints').update({
            'is_active': False,
            'updated_at': datetime.now(timezone.utc).isoformat()
        }).eq('id', endpoint_id).execute()
        
        if response.data:
            return jsonify({"status": "deactivated"})
        else:
            return jsonify({"error": "Failed to deactivate endpoint"}), 500
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/endpoints/<endpoint_id>/activate', methods=['POST'])
def activate_endpoint(endpoint_id):
    """Activate endpoint (mark as active)"""
    try:
        user_id = session.get('user_id')
        if not user_id:
            return jsonify({"error": "User ID required"}), 400
            
        supabase = get_supabase_client()
        
        # Verify endpoint belongs to current user
        endpoint_check = supabase.table('endpoints').select('id, root_user_id').eq('id', endpoint_id).execute()
        
        if not endpoint_check.data:
            return jsonify({"error": "Endpoint not found"}), 404
        
        if endpoint_check.data[0]['root_user_id'] != user_id:
            return jsonify({"error": "Access denied"}), 403
        
        # Mark endpoint as active
        response = supabase.table('endpoints').update({
            'is_active': True,
            'updated_at': datetime.now(timezone.utc).isoformat()
        }).eq('id', endpoint_id).execute()
        
        if response.data:
            return jsonify({"status": "activated"})
        else:
            return jsonify({"error": "Failed to activate endpoint"}), 500
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/endpoints/<endpoint_id>', methods=['DELETE'])
def delete_endpoint(endpoint_id):
    """Permanently delete endpoint"""
    try:
        user_id = session.get('user_id')
        if not user_id:
            return jsonify({"error": "User ID required"}), 400
            
        supabase = get_supabase_client()
        
        # Verify endpoint belongs to current user
        endpoint_check = supabase.table('endpoints').select('id, root_user_id').eq('id', endpoint_id).execute()
        
        if not endpoint_check.data:
            return jsonify({"error": "Endpoint not found"}), 404
        
        if endpoint_check.data[0]['root_user_id'] != user_id:
            return jsonify({"error": "Access denied"}), 403
        
        # Delete endpoint permanently
        response = supabase.table('endpoints').delete().eq('id', endpoint_id).execute()
        
        if response.data:
            return jsonify({"status": "deleted"})
        else:
            return jsonify({"error": "Failed to delete endpoint"}), 500
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/endpoints/<endpoint_id>/uninstall', methods=['POST'])
def uninstall_endpoint(endpoint_id):
    """Trigger uninstall on endpoint and then delete it"""
    try:
        user_id = session.get('user_id')
        if not user_id:
            return jsonify({"error": "User ID required"}), 400
            
        supabase = get_supabase_client()
        
        # Verify endpoint belongs to current user
        endpoint_check = supabase.table('endpoints').select('id, root_user_id, endpoint_name').eq('id', endpoint_id).execute()
        
        if not endpoint_check.data:
            return jsonify({"error": "Endpoint not found"}), 404
        
        if endpoint_check.data[0]['root_user_id'] != user_id:
            return jsonify({"error": "Access denied"}), 403
        
        endpoint_name = endpoint_check.data[0]['endpoint_name']
        
        # Mark endpoint as uninstalling
        supabase.table('endpoints').update({
            'is_active': False,
            'status': 'uninstalling'
        }).eq('id', endpoint_id).execute()
        
        # Delete endpoint permanently
        response = supabase.table('endpoints').delete().eq('id', endpoint_id).execute()
        
        if response.data:
            return jsonify({
                "status": "uninstalled", 
                "message": f"Endpoint '{endpoint_name}' has been marked for uninstall. The agent will clean up automatically on the next command attempt."
            })
        else:
            return jsonify({"error": "Failed to uninstall endpoint"}), 500
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/agent/deregister', methods=['POST'])
def agent_deregister():
    """Allow agent to deregister itself without authentication"""
    try:
        data = request.json
        if not all(key in data for key in ['endpoint_id', 'root_user_id']):
            return jsonify({"error": "Missing required fields: endpoint_id, root_user_id"}), 400
            
        supabase = get_supabase_client()
        
        # Verify endpoint exists and belongs to the specified user
        endpoint_check = supabase.table('endpoints').select('id, root_user_id').eq('id', data['endpoint_id']).eq('root_user_id', data['root_user_id']).execute()
        
        if not endpoint_check.data:
            return jsonify({"error": "Endpoint not found or access denied"}), 404
        
        # Mark endpoint as inactive
        response = supabase.table('endpoints').update({
            'is_active': False,
            'updated_at': datetime.now(timezone.utc).isoformat()
        }).eq('id', data['endpoint_id']).execute()
        
        if response.data:
            return jsonify({"status": "deregistered"})
        else:
            return jsonify({"error": "Failed to deregister endpoint"}), 500
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/requests', methods=['GET'])
def get_requests():
    try:
        # Get user_id from query parameter or session
        user_id = request.args.get('user_id') or session.get('user_id')
        print(f"DEBUG: get_requests called, user_id from args: {request.args.get('user_id')}, from session: {session.get('user_id')}, final: {user_id}")
        if not user_id:
            # If no user_id provided, return empty requests (not an error)
            print("DEBUG: No user_id provided, returning empty requests")
            return jsonify([])
            
        supabase = get_supabase_client()
        
        # First get all pending requests
        response = supabase.table('approval_requests').select('id, user_name, command, created_at, endpoint_id').eq('status', 'pending').order('created_at', desc=True).execute()
        
        # Get all endpoints for current user
        endpoints_response = supabase.table('endpoints').select('id, name, hostname, user_name, root_user_id').eq('root_user_id', user_id).execute()
        
        # Create a lookup dictionary for endpoints
        endpoints_lookup = {ep['id']: ep for ep in endpoints_response.data}
        
        # Check for expired requests and mark them as rejected
        current_time = datetime.now(timezone.utc)
        expired_request_ids = []
        
        for req in response.data:
            try:
                # Parse the timestamp
                if 'T' in req['created_at'] or 'Z' in req['created_at']:
                    request_time = datetime.fromisoformat(req['created_at'].replace('Z', '+00:00'))
                else:
                    request_time = datetime.fromtimestamp(float(req['created_at']), tz=timezone.utc)
                
                # Check if request is older than 30 seconds
                if (current_time - request_time).total_seconds() > 30:
                    expired_request_ids.append(req['id'])
                    print(f"DEBUG: Request {req['id']} is expired, marking as rejected")
            except Exception as e:
                print(f"DEBUG: Error parsing timestamp for request {req['id']}: {e}")
                # If we can't parse the timestamp, consider it expired
                expired_request_ids.append(req['id'])
        
        # Mark expired requests as rejected in the database
        if expired_request_ids:
            supabase.table('approval_requests').update({
                'status': 'rejected',
                'updated_at': current_time.isoformat()
            }).in_('id', expired_request_ids).execute()
            print(f"DEBUG: Marked {len(expired_request_ids)} requests as rejected")
            
            # Remove expired requests from our response data
            response.data = [req for req in response.data if req['id'] not in expired_request_ids]
        
        print(f"DEBUG: Supabase response: {response}")
        print(f"DEBUG: Response data: {response.data}")
        
        # Filter requests for current user and convert to expected format
        pending = {}
        print(f"DEBUG: Found {len(response.data)} total requests")
        print(f"DEBUG: Found {len(endpoints_lookup)} endpoints for user")
        
        for req in response.data:
            print(f"DEBUG: Processing request {req['id']}")
            print(f"DEBUG: Request endpoint_id: {req['endpoint_id']}")
            
            # Check if this request belongs to current user by looking up the endpoint
            endpoint = endpoints_lookup.get(req['endpoint_id'])
            if endpoint:
                print(f"DEBUG: Request {req['id']} belongs to current user")
                req_id = str(req['id'])
                pending[req_id] = {
                    'user': req['user_name'],
                    'command': req['command'],
                    'timestamp': req['created_at'],
                    'endpoint_name': endpoint.get('name', 'Unknown'),
                    'endpoint_hostname': endpoint.get('hostname', 'Unknown'),
                    'endpoint_user': endpoint.get('user_name', 'Unknown')
                }
            else:
                print(f"DEBUG: Request {req['id']} does not belong to current user")
        
        print(f"DEBUG: Returning {len(pending)} pending requests")
        
        return jsonify(pending)
    except Exception as e:
        print(f"DEBUG: Error in get_requests: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/api/approve/<req_id>', methods=['POST'])
def approve_request(req_id):
    try:
        # Get user_id from query parameter or session
        user_id = request.args.get('user_id') or session.get('user_id')
        if not user_id:
            return jsonify({"error": "User ID required"}), 400
            
        supabase = get_supabase_client()
        
        # Verify request exists and belongs to current user
        request_check = supabase.table('approval_requests').select('id, endpoint_id').eq('id', req_id).execute()
        
        if not request_check.data:
            return jsonify({"error": "Request not found"}), 404
        
        req_data = request_check.data[0]
        endpoint_id = req_data['endpoint_id']
        
        # Check if endpoint belongs to current user
        endpoint_check = supabase.table('endpoints').select('id, root_user_id').eq('id', endpoint_id).eq('root_user_id', user_id).execute()
        
        if not endpoint_check.data:
            return jsonify({"error": "Access denied"}), 403
        
        response = supabase.table('approval_requests').update({
            'status': 'approved',
            'updated_at': datetime.now(timezone.utc).isoformat()
        }).eq('id', req_id).eq('status', 'pending').execute()
        
        if not response.data:
            return jsonify({"error": "Request not found or already processed"}), 404
        
        return jsonify({"status": "approved"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/deny/<req_id>', methods=['POST'])
def deny_request(req_id):
    try:
        # Get user_id from query parameter or session
        user_id = request.args.get('user_id') or session.get('user_id')
        if not user_id:
            return jsonify({"error": "User ID required"}), 400
            
        supabase = get_supabase_client()
        
        # Verify request exists and belongs to current user
        request_check = supabase.table('approval_requests').select('id, endpoint_id').eq('id', req_id).execute()
        
        if not request_check.data:
            return jsonify({"error": "Request not found"}), 404

        req_data = request_check.data[0]
        endpoint_id = req_data['endpoint_id']
        
        # Check if endpoint belongs to current user
        endpoint_check = supabase.table('endpoints').select('id, root_user_id').eq('id', endpoint_id).eq('root_user_id', user_id).execute()
        
        if not endpoint_check.data:
            return jsonify({"error": "Access denied"}), 403
        
        response = supabase.table('approval_requests').update({
            'status': 'denied',
            'updated_at': datetime.now(timezone.utc).isoformat()
        }).eq('id', req_id).eq('status', 'pending').execute()
        
        if not response.data:
            return jsonify({"error": "Request not found or already processed"}), 404
        
        return jsonify({"status": "denied"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/check_approval/<req_id>', methods=['GET'])
def check_approval(req_id):
    try:
        supabase = get_supabase_client()
        
        # Get the request status
        response = supabase.table('approval_requests').select('status, created_at').eq('id', req_id).execute()
        
        if not response.data:
            return jsonify({"status": "expired"})
        
        request_data = response.data[0]
        status = request_data['status']
        created_at = request_data['created_at']
        
        # Check if request is older than 30 seconds (expired)
        from datetime import datetime, timezone, timedelta
        try:
            print(f"DEBUG: Checking expiration for request {req_id}")
            print(f"DEBUG: created_at: {created_at}")
            print(f"DEBUG: current status: {status}")
            
            # Parse the timestamp - handle both ISO format and Unix timestamp
            if 'T' in created_at or 'Z' in created_at:
                # ISO format
                request_time = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            else:
                # Unix timestamp
                request_time = datetime.fromtimestamp(float(created_at), tz=timezone.utc)
            
            current_time = datetime.now(timezone.utc)
            time_diff = current_time - request_time
            
            print(f"DEBUG: request_time: {request_time}")
            print(f"DEBUG: current_time: {current_time}")
            print(f"DEBUG: time_diff: {time_diff}")
            print(f"DEBUG: time_diff seconds: {time_diff.total_seconds()}")
            
            if time_diff > timedelta(seconds=30):
                print(f"DEBUG: Request expired, marking as rejected...")
                # Mark expired request as rejected instead of deleting
                supabase.table('approval_requests').update({
                    'status': 'rejected',
                    'updated_at': current_time.isoformat()
                }).eq('id', req_id).execute()
                return jsonify({"status": "expired"})
            else:
                print(f"DEBUG: Request still valid, time remaining: {30 - time_diff.total_seconds()} seconds")
        except Exception as e:
            print(f"Timestamp parsing error: {e}")
            pass  # If timestamp parsing fails, continue with normal flow
        
        # If approved, the request is already marked as approved in the database
        # No need to delete it, just return the status
        
        return jsonify({"status": status})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/test/session', methods=['GET'])
def test_session():
    """Test endpoint to check session data"""
    return jsonify({
        "session": dict(session),
        "user_id": session.get('user_id'),
        "username": session.get('username')
    })

@app.route('/test/register_endpoint', methods=['POST'])
def test_register_endpoint():
    """Test endpoint to manually register an endpoint"""
    try:
        data = request.json
        endpoint_data = {
            'name': data.get('name', 'test-endpoint'),
            'root_user_id': data.get('root_user_id', 'd9c4b7ec-c252-4a45-b1b0-f6098e0a6737'),
            'hostname': data.get('hostname', 'test-machine'),
            'user_name': data.get('user_name', 'testuser'),
            'ip_address': data.get('ip_address', '127.0.0.1'),
            'os_info': data.get('os_info', 'Linux'),
            'is_active': True,
            'created_at': datetime.now(timezone.utc).isoformat(),
            'last_seen': datetime.now(timezone.utc).isoformat()
        }
        
        supabase = get_supabase_client()
        response = supabase.table('endpoints').insert(endpoint_data).execute()
        
        if response.data:
            return jsonify({
                "status": "success",
                "endpoint_id": response.data[0]['id'],
                "message": "Endpoint registered successfully"
            })
        else:
            return jsonify({"error": "Failed to register endpoint"}), 500
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- Run the application ---
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)