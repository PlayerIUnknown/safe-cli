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
