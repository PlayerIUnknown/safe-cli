#!/bin/bash

# Safe CLI Comprehensive Installer
# This script handles everything: authentication, registration, installation, and error handling
#
# IMPORTANT: To activate aliases in the current shell, SOURCE this script:
#   source ./safe-cli-installer.sh
# 
# If you run it with ./safe-cli-installer.sh, aliases won't be active in your shell

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SAFE_CLI_SERVER=""
SAFE_CLI_ROOT_USER_ID=""
SAFE_CLI_ENDPOINT_ID=""
SAFE_CLI_ENDPOINT_NAME=""
INSTALLATION_TYPE=""

# Function to print colored output
print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  Safe CLI Comprehensive Installer${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
    echo -e "${WHITE}Usage:${NC}"
    echo "  source ./safe-cli-installer.sh   # Install Safe CLI (RECOMMENDED - aliases will be active)"
    echo "  ./safe-cli-installer.sh          # Install Safe CLI (aliases won't be active in current shell)"
    echo "  ./safe-cli-installer.sh --uninstall  # Uninstall Safe CLI"
    echo ""
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install them using:"
        echo "  Ubuntu/Debian: sudo apt-get install curl jq"
        echo "  CentOS/RHEL:   sudo yum install curl jq"
        echo "  macOS:         brew install curl jq"
        echo ""
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Function to clear existing Safe CLI configuration
clear_existing_config() {
    print_status "Clearing existing Safe CLI configuration..."
    
    # Clear environment variables
    unset SAFE_CLI_SERVER
    unset SAFE_CLI_ROOT_USER_ID
    unset SAFE_CLI_ENDPOINT_ID
    unset SAFE_CLI_ENDPOINT_NAME
    
    # Remove configuration file
    if [ -f "$HOME/.safe-cli-config" ]; then
        rm "$HOME/.safe-cli-config"
        print_success "Removed existing configuration file"
    fi
    
    # Remove agent script
    if [ -f "$HOME/.safe-cli-agent.sh" ]; then
        rm "$HOME/.safe-cli-agent.sh"
        print_success "Removed existing agent script"
    fi
    
    # Remove from shell configuration files
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc")
    for shell_config in "${shell_configs[@]}"; do
        if [ -f "$shell_config" ]; then
            # Remove Safe CLI lines
            sed -i '/# Safe CLI Configuration/d' "$shell_config"
            sed -i '/source ~\/.safe-cli-config/d' "$shell_config"
            sed -i '/source ~\/.safe-cli-agent.sh/d' "$shell_config"
            sed -i '/export SAFE_CLI_/d' "$shell_config"
            print_success "Cleared Safe CLI from $shell_config"
        fi
    done
    
    print_success "Existing configuration cleared"
}

# Function to completely uninstall Safe CLI
uninstall_safe_cli() {
    print_header
    print_status "Uninstalling Safe CLI..."
    
    # Kill any running Safe CLI processes
    print_status "Stopping Safe CLI processes..."
    pkill -f "periodic_endpoint_check" 2>/dev/null || true
    pkill -f "safe_execute" 2>/dev/null || true
    # Don't kill the installer script itself
    pkill -f "safe-cli-agent" 2>/dev/null || true
    print_success "Stopped Safe CLI processes"
    
    # Clear environment variables
    print_status "Clearing environment variables..."
    unset SAFE_CLI_SERVER
    unset SAFE_CLI_ROOT_USER_ID
    unset SAFE_CLI_ENDPOINT_ID
    unset SAFE_CLI_ENDPOINT_NAME
    unset SAFE_CLI_INSTALLATION_TYPE
    print_success "Cleared environment variables"
    
    # Remove aliases from current session
    print_status "Removing command aliases from current session..."
    local commands=("rm" "sudo" "fdisk" "mkfs" "dd" "mkfs.ext4" "mkfs.xfs" "mkfs.btrfs")
    for cmd in "${commands[@]}"; do
        unalias "$cmd" 2>/dev/null || true
    done
    
    # Also remove any aliases that might be defined with safe_execute
    local safe_aliases=$(alias | grep "safe_execute" | cut -d'=' -f1 | sed "s/alias //" | sed "s/'//g")
    for alias_name in $safe_aliases; do
        unalias "$alias_name" 2>/dev/null || true
    done
    
    print_success "Removed command aliases from current session"
    
    # Remove configuration files
    print_status "Removing configuration files..."
    if [ -f "$HOME/.safe-cli-config" ]; then
        rm "$HOME/.safe-cli-config"
        print_success "Removed ~/.safe-cli-config"
    fi
    
    if [ -f "$HOME/.safe-cli-agent.sh" ]; then
        rm "$HOME/.safe-cli-agent.sh"
        print_success "Removed ~/.safe-cli-agent.sh"
    fi
    
    if [ -f "safe-cli-agent.sh" ]; then
        rm "safe-cli-agent.sh"
        print_success "Removed local safe-cli-agent.sh"
    fi
    
    # Remove from shell configuration files
    print_status "Cleaning shell configuration files..."
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    for shell_config in "${shell_configs[@]}"; do
        if [ -f "$shell_config" ]; then
            # Create backup
            cp "$shell_config" "${shell_config}.safe-cli-backup" 2>/dev/null || true
            
            # Remove Safe CLI lines
            sed -i '/# Safe CLI Configuration/d' "$shell_config"
            sed -i '/source ~\/.safe-cli-config/d' "$shell_config"
            sed -i '/source ~\/.safe-cli-agent.sh/d' "$shell_config"
            sed -i '/export SAFE_CLI_/d' "$shell_config"
            print_success "Cleaned $shell_config"
        fi
    done
    
    # Reload shell configuration to apply changes
    print_status "Reloading shell configuration..."
    source ~/.bashrc 2>/dev/null || true
    print_success "Shell configuration reloaded"
    
    # Force remove any remaining aliases after reload
    print_status "Force removing any remaining aliases..."
    local commands=("rm" "sudo" "fdisk" "mkfs" "dd" "mkfs.ext4" "mkfs.xfs" "mkfs.btrfs")
    for cmd in "${commands[@]}"; do
        unalias "$cmd" 2>/dev/null || true
    done
    
    # Remove any aliases that contain safe_execute
    local safe_aliases=$(alias | grep "safe_execute" | cut -d'=' -f1 | sed "s/alias //" | sed "s/'//g")
    for alias_name in $safe_aliases; do
        unalias "$alias_name" 2>/dev/null || true
    done
    print_success "Force removed remaining aliases"
    
    # Final verification
    print_status "Verifying uninstall..."
    print_status "Debug: Checking for safe_execute aliases..."
    
    # Check for specific Safe CLI aliases that we know should be removed
    # We need to check in the current shell context, not a subshell
    local found_aliases=""
    local commands=("rm" "sudo" "fdisk" "mkfs" "dd" "mkfs.ext4" "mkfs.xfs" "mkfs.btrfs")
    
    # Use a different approach - check if the alias command exists and contains safe_execute
    for cmd in "${commands[@]}"; do
        local alias_output=$(alias "$cmd" 2>/dev/null)
        if echo "$alias_output" | grep -q "safe_execute"; then
            found_aliases="$found_aliases\n$alias_output"
        fi
    done
    
    if [ -n "$found_aliases" ]; then
        print_warning "Found remaining aliases:"
        echo -e "$found_aliases"
        print_warning "Some aliases may still be active in current session"
        print_warning "Shell will be restarted automatically"
    else
        print_success "No Safe CLI aliases remaining"
    fi
    
    print_success "Safe CLI has been completely uninstalled!"
    echo ""
    echo -e "${WHITE}What was removed:${NC}"
    echo "  ✅ Safe CLI processes stopped"
    echo "  ✅ Environment variables cleared"
    echo "  ✅ Command aliases removed from current session"
    echo "  ✅ Configuration files deleted"
    echo "  ✅ Shell configuration cleaned and reloaded"
    echo ""
    echo -e "${YELLOW}Note: Shell configuration backups were created as .safe-cli-backup files${NC}"
    echo ""
    
    # Always restart shell to ensure clean state
    echo -e "${YELLOW}⚠️  Restarting shell session to ensure complete cleanup...${NC}"
    echo -e "${CYAN}This ensures all aliases are removed from the current session.${NC}"
    echo ""
    
    # Start a new shell session
    exec bash
}

# Function to get server URL
get_server_url() {
    while true; do
        echo -n "Enter Safe CLI server URL (default: https://your-app.vercel.app): "
        read -r input
        SAFE_CLI_SERVER="${input:-https://your-app.vercel.app}"
        
        # Test connection
        print_status "Testing connection to $SAFE_CLI_SERVER..."
        if curl -s --connect-timeout 5 "$SAFE_CLI_SERVER" > /dev/null; then
            print_success "Connection successful"
            break
        else
            print_error "Cannot connect to $SAFE_CLI_SERVER"
            echo "Please check the URL and ensure the server is running"
            echo ""
        fi
    done
}

# Function to authenticate user
authenticate_user() {
    print_status "Authenticating with Safe CLI server..."
    echo ""
    
    while true; do
        echo -n "Enter username: "
        read -r username
        
        echo -n "Enter password: "
        read -s password
        echo ""
        
        print_status "Authenticating..."
        
        local auth_response=$(curl -s -X POST "$SAFE_CLI_SERVER/api/auth/login" \
            -H "Content-Type: application/json" \
            -d "{\"username\": \"$username\", \"password\": \"$password\"}")
        
        local user_id=$(echo "$auth_response" | jq -r '.user_id // empty' 2>/dev/null)
        local error=$(echo "$auth_response" | jq -r '.error // empty' 2>/dev/null)
        
        if [ -n "$user_id" ] && [ "$user_id" != "null" ]; then
            SAFE_CLI_ROOT_USER_ID="$user_id"
            print_success "Authentication successful"
            print_status "User ID: $SAFE_CLI_ROOT_USER_ID"
            break
        else
            print_error "Authentication failed: ${error:-'Unknown error'}"
            echo ""
            echo "Please check your credentials and try again"
            echo ""
        fi
    done
}

# Function to register endpoint
register_endpoint() {
    print_status "Registering endpoint with server..."
    
    local hostname=$(hostname)
    local os_info=$(uname -a)
    local endpoint_name="${SAFE_CLI_ENDPOINT_NAME:-$hostname}"
    
    local register_response=$(curl -s -X POST "$SAFE_CLI_SERVER/api/register_endpoint" \
        -H "Content-Type: application/json" \
        -d "{
            \"root_user_id\": \"$SAFE_CLI_ROOT_USER_ID\",
            \"name\": \"$endpoint_name\",
            \"hostname\": \"$hostname\",
            \"user_name\": \"$USER\",
            \"os_info\": \"$os_info\"
        }")
    
    local endpoint_id=$(echo "$register_response" | jq -r '.endpoint_id // empty' 2>/dev/null)
    local error=$(echo "$register_response" | jq -r '.error // empty' 2>/dev/null)
    
    if [ -n "$endpoint_id" ] && [ "$endpoint_id" != "null" ]; then
        SAFE_CLI_ENDPOINT_ID="$endpoint_id"
        print_success "Endpoint registered successfully"
        print_status "Endpoint ID: $SAFE_CLI_ENDPOINT_ID"
        return 0
    else
        print_error "Failed to register endpoint: ${error:-'Unknown error'}"
        return 1
    fi
}

# Function to select installation type
select_installation_type() {
    print_status "Select installation type:"
    echo ""
    echo "1) Global Installation (Recommended)"
    echo "   - Works across ALL terminals automatically"
    echo "   - No need to run agent script in each terminal"
    echo "   - Requires shell configuration changes"
    echo ""
    echo "2) Single Terminal Installation"
    echo "   - Only works in current terminal"
    echo "   - Need to run agent script in each new terminal"
    echo "   - No shell configuration changes"
    echo ""
    
    while true; do
        echo -n "Enter your choice (1 or 2): "
        read -r choice
        
        case $choice in
            1)
                INSTALLATION_TYPE="global"
                print_success "Selected: Global Installation"
                break
                ;;
            2)
                INSTALLATION_TYPE="single"
                print_success "Selected: Single Terminal Installation"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2"
                ;;
        esac
    done
}

# Function to create the agent script
create_agent_script() {
    print_status "Creating Safe CLI agent script..."
    
    # Get the directory where the installer is located
    local installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cat > "$installer_dir/safe-cli-agent.sh" << 'EOF'
#!/bin/bash

# Safe CLI Agent - Comprehensive Version
# Handles command blocking, approval requests, and endpoint management

# Configuration
SAFE_CLI_SERVER="${SAFE_CLI_SERVER:-http://localhost:5000}"
SAFE_CLI_ROOT_USER_ID="${SAFE_CLI_ROOT_USER_ID}"

# Load endpoint ID from configuration file if it exists
if [ -f "$HOME/.safe-cli-config" ]; then
    source "$HOME/.safe-cli-config"
fi

SAFE_CLI_ENDPOINT_NAME="${SAFE_CLI_ENDPOINT_NAME:-$(hostname)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to check if endpoint is still valid
function check_endpoint_validity() {
    if [ -z "$SAFE_CLI_ENDPOINT_ID" ]; then
        return 1
    fi
    
    local response=$(curl -s "${SAFE_CLI_SERVER}/api/endpoints")
    if [ -z "$response" ]; then
        # If we can't get a response, assume endpoint is still valid to avoid unnecessary re-registration
        return 0
    fi
    
    # Check if the endpoint exists and is active
    if echo "$response" | jq -e ".[] | select(.id == \"$SAFE_CLI_ENDPOINT_ID\" and .is_active == true)" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to register endpoint with server
function register_endpoint() {
    if [ -n "$SAFE_CLI_ENDPOINT_ID" ]; then
        if check_endpoint_validity; then
            return 0
        else
            echo -e "${YELLOW}⚠️ Stored endpoint ID is no longer valid. Re-registering...${NC}"
            SAFE_CLI_ENDPOINT_ID=""
            clear_endpoint_id_from_config
        fi
    fi
    
    if [ -z "$SAFE_CLI_ROOT_USER_ID" ]; then
        echo -e "${RED}Error: SAFE_CLI_ROOT_USER_ID is required${NC}"
        return 1
    fi
    
    local hostname=$(hostname)
    local os_info=$(uname -a)
    local endpoint_name="${SAFE_CLI_ENDPOINT_NAME:-$hostname}"
    
    local register_response=$(curl -s -X POST "${SAFE_CLI_SERVER}/api/register_endpoint" \
        -H "Content-Type: application/json" \
        -d "{
            \"root_user_id\": \"$SAFE_CLI_ROOT_USER_ID\",
            \"name\": \"$endpoint_name\",
            \"hostname\": \"$hostname\",
            \"user_name\": \"$USER\",
            \"os_info\": \"$os_info\"
        }")
    
    local endpoint_id=$(echo "$register_response" | jq -r '.endpoint_id // empty' 2>/dev/null)
    
    if [ -n "$endpoint_id" ] && [ "$endpoint_id" != "null" ]; then
        SAFE_CLI_ENDPOINT_ID="$endpoint_id"
        echo -e "${GREEN}✅ Endpoint registered successfully${NC}"
        
        # Update configuration files with new endpoint ID
        update_endpoint_id_in_config
        
        return 0
    else
        echo -e "${RED}❌ Failed to register endpoint${NC}"
        return 1
    fi
}

# Function to handle blocked commands
function handle_blocked_command() {
    local full_command="$1"
    local request_id="$2"
    
    echo -e "${RED}Command blocked:${NC} '$full_command'. Requesting one-time approval from admin..."
    
    if [ -z "$request_id" ] || [ "$request_id" == "null" ]; then
        echo "Error: Could not get request ID from server."
        return 1
    fi
    
    echo -e "${YELLOW}Waiting for approval...${NC}"
    local start_time=$(date +%s)
    local timeout=30
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local remaining=$((timeout - elapsed))
        
        if [ $remaining -le 0 ]; then
            echo -e "\n${RED}⏰ Approval timed out.${NC} Command blocked."
            return 1
        fi
        
        local status_response=$(curl -s "${SAFE_CLI_SERVER}/api/check_approval/${request_id}")
        local status=$(echo "$status_response" | jq -r '.status // empty' 2>/dev/null || echo "")
        
        if [ "$status" == "approved" ]; then
            echo -e "\n${GREEN}✅ Request Approved!${NC} Executing command..."
            return 0
        elif [ "$status" == "denied" ]; then
            echo -e "\n${RED}❌ Request Denied!${NC} Command blocked by administrator."
            return 1
        elif [ "$status" == "expired" ]; then
            echo -e "\n${RED}⏰ Request Expired!${NC} Command blocked due to timeout."
            return 1
        fi
        
        printf "\r${YELLOW}Waiting for approval... %ds remaining${NC}" "$remaining"
        sleep 1
    done
}

# Function to setup blacklist aliases
function setup_blacklist_aliases() {
    local response=$(curl -s "${SAFE_CLI_SERVER}/api/agent/blacklist?root_user_id=${SAFE_CLI_ROOT_USER_ID}")
    if [ -z "$response" ]; then
        echo -e "${YELLOW}Warning: Could not fetch blacklist from server${NC}"
        return 1
    fi
    
    local commands=$(echo "$response" | jq -r '.[]' 2>/dev/null)
    if [ -z "$commands" ]; then
        echo -e "${CYAN}No blocked commands found${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Setting up command aliases...${NC}"
    while IFS= read -r command; do
        if [ -n "$command" ]; then
            eval "alias $command='safe_execute $command'"
            echo -e "${GREEN}✅ Aliased: $command${NC}"
        fi
    done <<< "$commands"
}

# Function to update endpoint ID in configuration files
function update_endpoint_id_in_config() {
    echo -e "${CYAN}Updating endpoint ID in configuration files...${NC}"
    
    # Update configuration file if it exists
    local config_file="$HOME/.safe-cli-config"
    if [ -f "$config_file" ]; then
        # Remove the old endpoint ID line and add new one
        sed -i '/^export SAFE_CLI_ENDPOINT_ID=/d' "$config_file"
        echo "export SAFE_CLI_ENDPOINT_ID=\"$SAFE_CLI_ENDPOINT_ID\"" >> "$config_file"
        echo -e "${GREEN}✅ Updated endpoint ID in $config_file${NC}"
    fi
    
    # Update shell configuration files
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc")
    for shell_config in "${shell_configs[@]}"; do
        if [ -f "$shell_config" ]; then
            # Remove any existing SAFE_CLI_ENDPOINT_ID exports and add new one
            sed -i '/^export SAFE_CLI_ENDPOINT_ID=/d' "$shell_config"
            echo "export SAFE_CLI_ENDPOINT_ID=\"$SAFE_CLI_ENDPOINT_ID\"" >> "$shell_config"
            echo -e "${GREEN}✅ Updated endpoint ID in $shell_config${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Endpoint ID updated in all configuration files${NC}"
}

# Function to clear endpoint ID from configuration files
function clear_endpoint_id_from_config() {
    echo -e "${CYAN}Clearing endpoint ID from configuration files...${NC}"
    
    # Clear from environment variable
    export SAFE_CLI_ENDPOINT_ID=""
    
    # Clear from configuration file if it exists
    local config_file="$HOME/.safe-cli-config"
    if [ -f "$config_file" ]; then
        # Remove the endpoint ID line and add empty one
        sed -i '/^export SAFE_CLI_ENDPOINT_ID=/d' "$config_file"
        echo "export SAFE_CLI_ENDPOINT_ID=\"\"" >> "$config_file"
        echo -e "${GREEN}✅ Cleared endpoint ID from $config_file${NC}"
    fi
    
    # Clear from shell configuration files
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc")
    for shell_config in "${shell_configs[@]}"; do
        if [ -f "$shell_config" ]; then
            # Remove any existing SAFE_CLI_ENDPOINT_ID exports
            sed -i '/^export SAFE_CLI_ENDPOINT_ID=/d' "$shell_config"
            echo -e "${GREEN}✅ Cleared endpoint ID from $shell_config${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Endpoint ID cleared from all configuration files${NC}"
}

# Main command execution function
function safe_execute() {
    local COMMAND_NAME="$1"
    shift
    local ARGS="$*"
    local USER_COMMAND="$COMMAND_NAME $ARGS"
    
    # Don't check root user or empty commands
    if [[ $EUID -eq 0 || -z "$COMMAND_NAME" ]]; then
        command "$COMMAND_NAME" $ARGS
        return $?
    fi
    
    # Check with server if command should be blocked
    local response=$(curl -s -X POST "${SAFE_CLI_SERVER}/api/agent/check_command" \
        -H "Content-Type: application/json" \
        -d "{\"command\": \"$COMMAND_NAME\", \"root_user_id\": \"$SAFE_CLI_ROOT_USER_ID\", \"endpoint_id\": \"$SAFE_CLI_ENDPOINT_ID\"}")
    
    # Check if server is responding
    if [ -z "$response" ]; then
        echo -e "${YELLOW}Warning: Server not responding. Allowing command.${NC}" >&2
        command "$COMMAND_NAME" $ARGS
        return $?
    fi
    
    # Check if endpoint was deleted (foreign key constraint error)
    local error_msg=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)
    if [[ "$error_msg" == *"foreign key constraint"* ]] || [[ "$error_msg" == *"endpoint_id_fkey"* ]]; then
        echo -e "${RED}❌ Endpoint was deleted from dashboard by administrator.${NC}"
        echo -e "${YELLOW}Triggering automatic uninstall cleanup...${NC}"
        
        # Run the uninstall script to clean up everything
        if [ -f "./safe-cli-installer.sh" ]; then
            echo -e "${CYAN}Running uninstall script to clean up Safe CLI...${NC}"
            ./safe-cli-installer.sh --uninstall
        else
            echo -e "${YELLOW}Uninstall script not found. Manual cleanup required.${NC}"
            echo -e "${YELLOW}Safe CLI is now inactive. Please contact your administrator.${NC}"
            
            # Clear endpoint ID and deactivate
            SAFE_CLI_ENDPOINT_ID=""
            clear_endpoint_id_from_config
            
            # Remove all aliases to stop command blocking
            local commands=("rm" "sudo" "fdisk" "mkfs" "dd" "mkfs.ext4" "mkfs.xfs" "mkfs.btrfs")
            for cmd in "${commands[@]}"; do
                unalias "$cmd" 2>/dev/null || true
            done
            
            echo -e "${CYAN}Command aliases removed. Commands will now execute normally.${NC}"
            echo -e "${YELLOW}To reactivate Safe CLI, run: ./safe-cli-installer.sh${NC}"
        fi
        
        # Allow the command to execute normally
        command "$COMMAND_NAME" $ARGS
        return $?
    fi
    
    # Parse response
    local blocked=$(echo "$response" | jq -r '.blocked // false' 2>/dev/null)
    local request_id=$(echo "$response" | jq -r '.request_id // empty' 2>/dev/null)
    local message=$(echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null)
    
    if [ "$blocked" = "true" ]; then
        echo -e "${RED}🚫 Command '$USER_COMMAND' is blocked by safe-cli${NC}"
        if [ -n "$request_id" ]; then
            handle_blocked_command "$USER_COMMAND" "$request_id"
            if [ $? -eq 0 ]; then
                command "$COMMAND_NAME" $ARGS
                local exit_code=$?
                if [ $exit_code -eq 0 ]; then
                    echo -e "${GREEN}✅ Command executed successfully${NC}"
                else
                    echo -e "${YELLOW}⚠️ Command executed but returned exit code: $exit_code${NC}"
                fi
                return $exit_code
            else
                echo -e "${RED}❌ Command blocked by administrator${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ Command blocked but no request ID received${NC}"
            return 1
        fi
    else
        # Command is allowed
        command "$COMMAND_NAME" $ARGS
        return $?
    fi
}

# Function to periodically check endpoint validity
function periodic_endpoint_check() {
    while true; do
        sleep 1800  # Wait 30 minutes instead of 5 minutes
        echo -e "${CYAN}🔍 Checking endpoint validity...${NC}"
        if ! check_endpoint_validity; then
            echo -e "${RED}❌ Endpoint no longer valid. Safe CLI is now inactive.${NC}"
            echo -e "${YELLOW}Please contact your administrator or reinstall Safe CLI.${NC}"
            
            # Clear endpoint ID and deactivate
            SAFE_CLI_ENDPOINT_ID=""
            clear_endpoint_id_from_config
            
            # Remove all aliases to stop command blocking
            local commands=("rm" "sudo" "fdisk" "mkfs" "dd" "mkfs.ext4" "mkfs.xfs" "mkfs.btrfs")
            for cmd in "${commands[@]}"; do
                unalias "$cmd" 2>/dev/null || true
            done
            
            echo -e "${CYAN}Command aliases removed. Commands will now execute normally.${NC}"
            echo -e "${YELLOW}To reactivate Safe CLI, run: ./safe-cli-installer.sh${NC}"
            
            # Exit the periodic check
            break
        else
            echo -e "${GREEN}✅ Endpoint is still valid${NC}"
        fi
    done
}

# Initialize
echo -e "${CYAN}Safe CLI Agent starting...${NC}"

# Register endpoint on startup
register_endpoint

# Setup initial blacklist aliases
setup_blacklist_aliases

# Start periodic endpoint check in background only if not in single terminal mode
if [ "${SAFE_CLI_INSTALLATION_TYPE:-global}" != "single" ]; then
    periodic_endpoint_check &
    echo -e "${GREEN}Safe CLI agent activated with periodic monitoring.${NC}"
else
    echo -e "${GREEN}Safe CLI agent activated (single terminal mode).${NC}"
fi

echo -e "${CYAN}Protected commands will be blocked and require approval.${NC}"
EOF

    chmod +x safe-cli-agent.sh
    print_success "Agent script created successfully"
}

# Function to install globally
install_globally() {
    print_status "Installing Safe CLI globally..."
    
    # Create configuration file
    local config_file="$HOME/.safe-cli-config"
    cat > "$config_file" << EOF
# Safe CLI Configuration
export SAFE_CLI_SERVER="$SAFE_CLI_SERVER"
export SAFE_CLI_ROOT_USER_ID="$SAFE_CLI_ROOT_USER_ID"
export SAFE_CLI_ENDPOINT_ID="$SAFE_CLI_ENDPOINT_ID"
export SAFE_CLI_ENDPOINT_NAME="$SAFE_CLI_ENDPOINT_NAME"
export SAFE_CLI_INSTALLATION_TYPE="global"
EOF
    
    print_success "Created configuration file: $config_file"
    
    # Copy agent script to home directory
    cp safe-cli-agent.sh "$HOME/.safe-cli-agent.sh"
    
    # Add to shell configuration
    local shell_config=""
    if [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.bashrc"
    fi
    
    # Get the directory where the installer is located
    local installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local agent_script="$installer_dir/safe-cli-agent.sh"
    
    # Check if already configured
    if ! grep -q "Safe CLI" "$shell_config" 2>/dev/null; then
        echo "" >> "$shell_config"
        echo "# Safe CLI Configuration" >> "$shell_config"
        echo "source ~/.safe-cli-config" >> "$shell_config"
        echo "source $agent_script" >> "$shell_config"
        print_success "Added Safe CLI to $shell_config"
    else
        print_warning "Safe CLI already configured in $shell_config"
    fi
    
    print_success "Global installation completed"
    echo ""
    echo "Safe CLI will be active in all new terminal sessions."
    echo "To activate in current session, run: source ~/.bashrc"
}

# Function to install for single terminal
install_single_terminal() {
    print_status "Installing Safe CLI for current terminal..."
    
    # Create configuration file for single terminal installation
    local config_file="$HOME/.safe-cli-config"
    cat > "$config_file" << EOF
# Safe CLI Configuration
export SAFE_CLI_SERVER="$SAFE_CLI_SERVER"
export SAFE_CLI_ROOT_USER_ID="$SAFE_CLI_ROOT_USER_ID"
export SAFE_CLI_ENDPOINT_ID="$SAFE_CLI_ENDPOINT_ID"
export SAFE_CLI_ENDPOINT_NAME="$SAFE_CLI_ENDPOINT_NAME"
export SAFE_CLI_INSTALLATION_TYPE="single"
EOF
    
    print_success "Created configuration file: $config_file"
    
    # Export variables to current shell
    export SAFE_CLI_SERVER="$SAFE_CLI_SERVER"
    export SAFE_CLI_ROOT_USER_ID="$SAFE_CLI_ROOT_USER_ID"
    export SAFE_CLI_ENDPOINT_ID="$SAFE_CLI_ENDPOINT_ID"
    export SAFE_CLI_ENDPOINT_NAME="$SAFE_CLI_ENDPOINT_NAME"
    
    # Note: Aliases will be set up directly below
    
    # Source the agent script automatically
    local installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local agent_script="$installer_dir/safe-cli-agent.sh"
    
    # Wait a moment for the file to be fully written
    sleep 1
    
    if [ -f "$agent_script" ]; then
        print_status "Activating Safe CLI agent..."
        print_status "Agent script location: $agent_script"
        
        # Make sure the script is executable
        chmod +x "$agent_script"
        
        # Source the agent script properly to get both functions and aliases
        print_status "Activating Safe CLI agent..."
        print_status "Sourcing agent script: $agent_script"
        
        # Source the agent script in the current shell context
        if source "$agent_script"; then
            print_success "Agent script sourced successfully"
        else
            print_error "Failed to source agent script"
            return 1
        fi
        
        print_success "Safe CLI agent activated successfully"
    else
        print_error "Agent script not found at $agent_script. Please run the installer again."
        return 1
    fi
    
    print_success "Single terminal installation completed"
    echo ""
    echo "Safe CLI is now active in this terminal only."
    echo "To activate in other terminals, run: source $agent_script"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: If you see old endpoint IDs in debug output,${NC}"
    echo -e "${YELLOW}   please run: source ~/.safe-cli-config && source $agent_script${NC}"
}

# Function to test installation
test_installation() {
    print_status "Testing installation..."
    
    # Test endpoint registration
    if [ -z "$SAFE_CLI_ENDPOINT_ID" ]; then
        print_error "Endpoint ID not set"
        return 1
    fi
    
    # Test server connection
    local test_response=$(curl -s "${SAFE_CLI_SERVER}/api/endpoints")
    if [ -z "$test_response" ]; then
        print_error "Cannot connect to server"
        return 1
    fi
    
    print_success "Installation test passed"
    return 0
}

# Function to show final instructions
show_final_instructions() {
    echo ""
    print_success "Safe CLI installation completed successfully!"
    echo ""
    echo -e "${WHITE}Configuration Summary:${NC}"
    echo "  Server URL: $SAFE_CLI_SERVER"
    echo "  User ID: $SAFE_CLI_ROOT_USER_ID"
    echo "  Endpoint ID: $SAFE_CLI_ENDPOINT_ID"
    echo "  Installation Type: $INSTALLATION_TYPE"
    echo ""
    
    if [ "$INSTALLATION_TYPE" = "global" ]; then
        echo -e "${WHITE}Global Installation:${NC}"
        echo "  ✅ Safe CLI is now active in all terminals"
        echo "  ✅ Commands will be blocked automatically"
        echo "  ✅ Approval requests will be sent to dashboard"
        echo "  ✅ Automatic endpoint recovery and configuration updates"
        echo ""
        echo "To activate in current terminal: source ~/.bashrc"
    else
        echo -e "${WHITE}Single Terminal Installation:${NC}"
        echo "  ✅ Safe CLI is active in current terminal"
        echo "  ✅ Commands will be blocked automatically"
        echo "  ✅ Approval requests will be sent to dashboard"
        echo "  ✅ Automatic endpoint recovery and configuration updates"
        echo ""
        echo "To activate in other terminals: source safe-cli-agent.sh"
        echo ""
        echo -e "${YELLOW}⚠️  TROUBLESHOOTING:${NC}"
        echo "  If you see old endpoint IDs in debug output, run:"
        echo "  source ~/.safe-cli-config && source safe-cli-agent.sh"
    fi
    
    echo ""
    echo -e "${WHITE}Dashboard Access:${NC}"
    echo "  Open: $SAFE_CLI_SERVER"
    echo "  Login with your credentials to manage endpoints and blacklist"
    echo ""
    echo -e "${WHITE}Error Handling:${NC}"
    echo "  ✅ Endpoint deletion issues are handled automatically"
    echo "  ✅ Configuration files are updated automatically"
    echo "  ✅ Connection issues are handled gracefully"
    echo ""
}

# Main installation process
main() {
    # Check for uninstall option
    if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
        uninstall_safe_cli
        exit 0
    fi
    
    print_header
    
    # Check dependencies
    check_dependencies
    
    # Clear existing configuration
    clear_existing_config
    
    # Get server URL
    get_server_url
    
    # Authenticate user
    authenticate_user
    
    # Register endpoint
    if ! register_endpoint; then
        print_error "Failed to register endpoint. Exiting."
        exit 1
    fi
    
    # Select installation type
    select_installation_type
    
    # Create agent script (after endpoint registration so it has the correct endpoint ID)
    create_agent_script
    
    # Install based on type
    if [ "$INSTALLATION_TYPE" = "global" ]; then
        install_globally
    else
        install_single_terminal
    fi
    
    # Test installation
    if test_installation; then
        show_final_instructions
    else
        print_error "Installation test failed. Please check your configuration."
        exit 1
    fi
}

# Run main function
main "$@"