#!/bin/bash

# DOTFILES SECURITY HARDENING SCRIPT
# Enhances security across all dotfiles configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
DOTFILES_DIR="$HOME/.dotfiles"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
SHELL_DIR="$DOTFILES_DIR/shell"
DRY_RUN=false
VERBOSE=false
FORCE=false

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                DRY_RUN=true
                echo -e "${YELLOW}🔍 DRY RUN MODE: Will simulate actions without making changes${NC}"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                echo -e "${BLUE}📢 VERBOSE MODE: Detailed output enabled${NC}"
                shift
                ;;
            --force|-f)
                FORCE=true
                echo -e "${YELLOW}⚠️ FORCE MODE: Will apply changes without confirmation${NC}"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
🛡️ DOTFILES SECURITY HARDENING SCRIPT
=====================================

DESCRIPTION:
  Enhances security across all dotfiles configurations.
  Implements best practices for shell, scripts, and configuration files.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --dry-run, -n    Simulate actions without making changes
  --verbose, -v    Enable detailed output
  --force, -f      Apply changes without confirmation
  --help, -h       Show this help message

FEATURES:
  🔒 Shell history security enhancements
  🔒 Script permission hardening
  🔒 Sensitive data detection and protection
  🔒 SSH configuration hardening
  🔒 Git security improvements
  🔒 Environment variable security
  🔒 File permission auditing

EXAMPLES:
  $0                    # Run security hardening with confirmation
  $0 --dry-run         # Preview security changes
  $0 --force           # Apply all security changes without prompting
EOF
}

# Logging functions
log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}🔍 $1${NC}"
    fi
}

log_section() {
    echo -e "\n${BLUE}🔷 $1${NC}"
    echo "======================================"
}

# Function to confirm actions
confirm_action() {
    local message="$1"
    
    if [ "$FORCE" = true ]; then
        return 0  # Auto-confirm if force mode is enabled
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would ask for confirmation: $message${NC}"
        return 1  # Don't proceed with action in dry run mode
    fi
    
    read -p "$message [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to enhance shell history security
enhance_shell_history_security() {
    log_section "SHELL HISTORY SECURITY ENHANCEMENTS"
    
    local history_security_file="$SHELL_DIR/history_security.sh"
    
    if [ ! -f "$history_security_file" ]; then
        log_warning "History security file not found: $history_security_file"
        
        if confirm_action "Create new history security file?"; then
            if [ "$DRY_RUN" = false ]; then
                mkdir -p "$SHELL_DIR"
                
                cat > "$history_security_file" << 'EOF'
# Enhanced History Security Settings
# Add this to your .bashrc or .zshrc to prevent sensitive commands from being logged

# Bash history security settings
if [ -n "$BASH_VERSION" ]; then
    # Don't log commands that start with a space
    export HISTCONTROL=ignorespace:ignoredups:erasedups
    
    # Don't log sensitive commands (expanded patterns)
    export HISTIGNORE="*password*:*secret*:*token*:*key*:*credential*:*auth*:*pass*:*login*:mysql*:psql*:*sudo*:ssh*:curl*-u*:*bearer*:*api*key*:*access*token*:*-p*:*--password*"
    
    # Limit history size
    export HISTSIZE=10000
    export HISTFILESIZE=10000
    
    # Enable history timestamps
    export HISTTIMEFORMAT="%F %T "
fi

# Zsh history security settings  
if [ -n "$ZSH_VERSION" ]; then
    # Don't log commands that start with a space
    setopt HIST_IGNORE_SPACE
    setopt HIST_IGNORE_DUPS
    setopt HIST_IGNORE_ALL_DUPS
    setopt HIST_SAVE_NO_DUPS
    
    # Don't share history between sessions immediately (more secure)
    unsetopt SHARE_HISTORY
    setopt INC_APPEND_HISTORY
    
    # Add timestamps to history
    setopt EXTENDED_HISTORY
    
    # Limit history size
    export HISTSIZE=10000
    export SAVEHIST=10000
fi

# Universal security aliases to prevent accidental logging
alias mysql_secure='HISTCONTROL=ignorespace mysql'
alias ssh_secure='HISTCONTROL=ignorespace ssh'
alias curl_secure='HISTCONTROL=ignorespace curl'
alias aws_secure='HISTCONTROL=ignorespace aws'
alias gcloud_secure='HISTCONTROL=ignorespace gcloud'
alias docker_secure='HISTCONTROL=ignorespace docker'

# Function to run sensitive commands without logging
secure_cmd() {
    # Temporarily disable history
    if [ -n "$BASH_VERSION" ]; then
        set +o history
        "$@"
        set -o history
    elif [ -n "$ZSH_VERSION" ]; then
        unsetopt SHARE_HISTORY
        fc -p /dev/null
        "$@"
        fc -P
    fi
}

# Function to securely set environment variables
secure_env() {
    local var_name="$1"
    # Use read -s to avoid showing the value in terminal
    read -s -p "Enter value for $var_name: " var_value
    echo ""  # Add newline after hidden input
    
    # Export the variable without logging
    if [ -n "$BASH_VERSION" ]; then
        set +o history
        export "$var_name"="$var_value"
        set -o history
    elif [ -n "$ZSH_VERSION" ]; then
        unsetopt SHARE_HISTORY
        fc -p /dev/null
        export "$var_name"="$var_value"
        fc -P
    fi
    
    echo "✅ Environment variable $var_name set securely"
}

echo "🔒 Enhanced history security settings loaded"
echo "💡 Tip: Prefix sensitive commands with a space to avoid logging"
echo "💡 Or use: secure_cmd <your-sensitive-command>"
echo "💡 For secure environment variables: secure_env API_KEY"
EOF
                
                chmod 644 "$history_security_file"
                log_info "Created enhanced history security file: $history_security_file"
            else
                log_debug "Would create enhanced history security file: $history_security_file"
            fi
        fi
    else
        log_info "Found existing history security file: $history_security_file"
        
        # Check if the file needs updating
        if ! grep -q "secure_env" "$history_security_file" || ! grep -q "EXTENDED_HISTORY" "$history_security_file"; then
            log_warning "History security file could be enhanced with additional protections"
            
            if confirm_action "Update history security file with enhanced protections?"; then
                if [ "$DRY_RUN" = false ]; then
                    # Backup the original file
                    cp "$history_security_file" "${history_security_file}.backup_$(date +%s)"
                    
                    # Update the file with enhanced security
                    sed -i 's/export HISTIGNORE=".*"/export HISTIGNORE="*password*:*secret*:*token*:*key*:*credential*:*auth*:*pass*:*login*:mysql*:psql*:*sudo*:ssh*:curl*-u*:*bearer*:*api*key*:*access*token*:*-p*:*--password*"/' "$history_security_file"
                    
                    # Add secure_env function if it doesn't exist
                    if ! grep -q "secure_env" "$history_security_file"; then
                        cat >> "$history_security_file" << 'EOF'

# Function to securely set environment variables
secure_env() {
    local var_name="$1"
    # Use read -s to avoid showing the value in terminal
    read -s -p "Enter value for $var_name: " var_value
    echo ""  # Add newline after hidden input
    
    # Export the variable without logging
    if [ -n "$BASH_VERSION" ]; then
        set +o history
        export "$var_name"="$var_value"
        set -o history
    elif [ -n "$ZSH_VERSION" ]; then
        unsetopt SHARE_HISTORY
        fc -p /dev/null
        export "$var_name"="$var_value"
        fc -P
    fi
    
    echo "✅ Environment variable $var_name set securely"
}
EOF
                    fi
                    
                    # Add EXTENDED_HISTORY for zsh if it doesn't exist
                    if ! grep -q "EXTENDED_HISTORY" "$history_security_file"; then
                        sed -i '/setopt INC_APPEND_HISTORY/a \    # Add timestamps to history\n    setopt EXTENDED_HISTORY' "$history_security_file"
                    fi
                    
                    log_info "Updated history security file with enhanced protections"
                else
                    log_debug "Would update history security file with enhanced protections"
                fi
            fi
        else
            log_info "History security file already has enhanced protections"
        fi
    }
    
    # Update shell configuration files to include history security
    local shell_files=("$HOME/.bashrc" "$HOME/.zshrc" "$SHELL_DIR/.bashrc" "$SHELL_DIR/.zshrc")
    
    for shell_file in "${shell_files[@]}"; do
        if [ -f "$shell_file" ]; then
            log_debug "Checking shell file: $shell_file"
            
            if ! grep -q "history_security.sh" "$shell_file"; then
                log_warning "Shell file does not include history security: $shell_file"
                
                if confirm_action "Update $shell_file to include history security?"; then
                    if [ "$DRY_RUN" = false ]; then
                        # Backup the original file
                        cp "$shell_file" "${shell_file}.backup_$(date +%s)"
                        
                        # Add history security include
                        cat >> "$shell_file" << EOF

# Load enhanced history security settings
if [ -f "$SHELL_DIR/history_security.sh" ]; then
    source "$SHELL_DIR/history_security.sh"
fi
EOF
                        
                        log_info "Updated shell file to include history security: $shell_file"
                    else
                        log_debug "Would update shell file to include history security: $shell_file"
                    fi
                fi
            else
                log_info "Shell file already includes history security: $shell_file"
            fi
        fi
    done
}

# Function to harden script permissions
harden_script_permissions() {
    log_section "SCRIPT PERMISSION HARDENING"
    
    # Find all shell scripts
    local scripts=($(find "$DOTFILES_DIR" -name "*.sh" -type f))
    
    log_info "Found ${#scripts[@]} shell scripts to check"
    
    for script in "${scripts[@]}"; do
        local current_perms=$(stat -c "%a" "$script")
        
        # Check if permissions are too permissive
        if [[ "$current_perms" == "777" || "$current_perms" == "775" || "$current_perms" == "755" ]]; then
            log_warning "Script has overly permissive permissions: $script ($current_perms)"
            
            if confirm_action "Change permissions to 700 (owner only)?"; then
                if [ "$DRY_RUN" = false ]; then
                    chmod 700 "$script"
                    log_info "Changed permissions for $script: $current_perms -> 700"
                else
                    log_debug "Would change permissions for $script: $current_perms -> 700"
                fi
            fi
        elif [[ "$current_perms" != "700" && "$current_perms" != "744" && "$current_perms" != "754" && "$current_perms" != "764" ]]; then
            # If not already set to a reasonable executable permission
            log_warning "Script has non-standard permissions: $script ($current_perms)"
            
            if confirm_action "Change permissions to 700 (owner only)?"; then
                if [ "$DRY_RUN" = false ]; then
                    chmod 700 "$script"
                    log_info "Changed permissions for $script: $current_perms -> 700"
                else
                    log_debug "Would change permissions for $script: $current_perms -> 700"
                fi
            fi
        else
            log_debug "Script has appropriate permissions: $script ($current_perms)"
        fi
        
        # Check if script is executable
        if [ ! -x "$script" ]; then
            log_warning "Script is not executable: $script"
            
            if confirm_action "Make script executable?"; then
                if [ "$DRY_RUN" = false ]; then
                    chmod +x "$script"
                    log_info "Made script executable: $script"
                else
                    log_debug "Would make script executable: $script"
                fi
            fi
        fi
    }
}

# Function to detect and protect sensitive data
detect_sensitive_data() {
    log_section "SENSITIVE DATA DETECTION"
    
    local sensitive_patterns=(
        "password" "secret" "token" "key" "credential" "auth"
        "apikey" "api_key" "access_token" "private_key" "client_secret"
    )
    
    local sensitive_files=()
    
    log_info "Scanning for files with potentially sensitive data..."
    
    for pattern in "${sensitive_patterns[@]}"; do
        local found_files=($(find "$DOTFILES_DIR" -type f -not -path "*/\.*" -name "*$pattern*" 2>/dev/null || true))
        
        if [ ${#found_files[@]} -gt 0 ]; then
            for file in "${found_files[@]}"; do
                sensitive_files+=("$file")
                log_warning "Potentially sensitive file found: $file"
            done
        fi
    }
    
    # Deduplicate the list
    sensitive_files=($(echo "${sensitive_files[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    if [ ${#sensitive_files[@]} -gt 0 ]; then
        log_warning "Found ${#sensitive_files[@]} potentially sensitive files"
        
        if confirm_action "Would you like to secure these files with restricted permissions?"; then
            for file in "${sensitive_files[@]}"; do
                if [ "$DRY_RUN" = false ]; then
                    chmod 600 "$file"
                    log_info "Restricted permissions for sensitive file: $file (600)"
                else
                    log_debug "Would restrict permissions for sensitive file: $file (600)"
                fi
            done
        fi
        
        if confirm_action "Would you like to add these files to .gitignore?"; then
            if [ "$DRY_RUN" = false ]; then
                local gitignore_file="$DOTFILES_DIR/.gitignore"
                
                # Create .gitignore if it doesn't exist
                if [ ! -f "$gitignore_file" ]; then
                    touch "$gitignore_file"
                fi
                
                # Add a section for sensitive files
                echo -e "\n# Automatically detected sensitive files" >> "$gitignore_file"
                
                for file in "${sensitive_files[@]}"; do
                    # Get relative path from dotfiles directory
                    local rel_path="${file#$DOTFILES_DIR/}"
                    echo "$rel_path" >> "$gitignore_file"
                    log_info "Added to .gitignore: $rel_path"
                done
            else
                log_debug "Would add ${#sensitive_files[@]} sensitive files to .gitignore"
            fi
        fi
    else
        log_info "No potentially sensitive files found"
    }
    
    # Also scan for hardcoded secrets in files
    log_info "Scanning for hardcoded secrets in files..."
    
    local secret_patterns=(
        "password[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "secret[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "token[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "key[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "apikey[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "api_key[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "access_token[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    )
    
    local files_with_secrets=()
    
    for pattern in "${secret_patterns[@]}"; do
        local found_files=($(grep -l -r -E "$pattern" --include="*.sh" --include="*.bash" --include="*.zsh" --include="*.conf" --include="*.cfg" --include="*.ini" "$DOTFILES_DIR" 2>/dev/null || true))
        
        if [ ${#found_files[@]} -gt 0 ]; then
            for file in "${found_files[@]}"; do
                files_with_secrets+=("$file")
                log_warning "File may contain hardcoded secrets: $file"
                
                if [ "$VERBOSE" = true ]; then
                    log_debug "Matched pattern: $pattern"
                    grep -E "$pattern" "$file" | head -3 | while read -r line; do
                        log_debug "  $line"
                    done
                fi
            done
        fi
    }
    
    # Deduplicate the list
    files_with_secrets=($(echo "${files_with_secrets[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    if [ ${#files_with_secrets[@]} -gt 0 ]; then
        log_warning "Found ${#files_with_secrets[@]} files with potential hardcoded secrets"
        
        if confirm_action "Would you like to create a report of these files?"; then
            local report_file="$DOTFILES_DIR/security_report_$(date +%s).txt"
            
            if [ "$DRY_RUN" = false ]; then
                echo "SECURITY REPORT - POTENTIAL HARDCODED SECRETS" > "$report_file"
                echo "Generated: $(date)" >> "$report_file"
                echo "========================================" >> "$report_file"
                echo "" >> "$report_file"
                
                for file in "${files_with_secrets[@]}"; do
                    echo "FILE: $file" >> "$report_file"
                    echo "----------------------------------------" >> "$report_file"
                    
                    for pattern in "${secret_patterns[@]}"; do
                        if grep -q -E "$pattern" "$file"; then
                            echo "MATCHES FOR: $pattern" >> "$report_file"
                            grep -n -E "$pattern" "$file" >> "$report_file"
                            echo "" >> "$report_file"
                        fi
                    done
                    
                    echo "RECOMMENDATION: Replace hardcoded secrets with environment variables or secure storage" >> "$report_file"
                    echo "========================================" >> "$report_file"
                    echo "" >> "$report_file"
                done
                
                chmod 600 "$report_file"
                log_info "Created security report: $report_file"
            else
                log_debug "Would create security report: $report_file"
            fi
        fi
    else
        log_info "No files with hardcoded secrets found"
    }
}

# Function to harden SSH configuration
harden_ssh_config() {
    log_section "SSH CONFIGURATION HARDENING"
    
    local ssh_config_dir="$HOME/.ssh"
    local ssh_config_file="$ssh_config_dir/config"
    
    if [ ! -d "$ssh_config_dir" ]; then
        log_warning "SSH directory not found: $ssh_config_dir"
        
        if confirm_action "Create SSH directory with secure permissions?"; then
            if [ "$DRY_RUN" = false ]; then
                mkdir -p "$ssh_config_dir"
                chmod 700 "$ssh_config_dir"
                log_info "Created SSH directory with secure permissions: $ssh_config_dir"
            else
                log_debug "Would create SSH directory with secure permissions: $ssh_config_dir"
            fi
        fi
    else
        # Check SSH directory permissions
        local ssh_dir_perms=$(stat -c "%a" "$ssh_config_dir")
        
        if [ "$ssh_dir_perms" != "700" ]; then
            log_warning "SSH directory has insecure permissions: $ssh_config_dir ($ssh_dir_perms)"
            
            if confirm_action "Change SSH directory permissions to 700?"; then
                if [ "$DRY_RUN" = false ]; then
                    chmod 700 "$ssh_config_dir"
                    log_info "Changed SSH directory permissions: $ssh_dir_perms -> 700"
                else
                    log_debug "Would change SSH directory permissions: $ssh_dir_perms -> 700"
                fi
            fi
        else
            log_info "SSH directory has secure permissions: 700"
        fi
    }
    
    # Check SSH key files
    local ssh_keys=($(find "$ssh_config_dir" -name "id_*" -not -name "*.pub" 2>/dev/null || true))
    
    for key_file in "${ssh_keys[@]}"; do
        local key_perms=$(stat -c "%a" "$key_file")
        
        if [ "$key_perms" != "600" ]; then
            log_warning "SSH key file has insecure permissions: $key_file ($key_perms)"
            
            if confirm_action "Change SSH key file permissions to 600?"; then
                if [ "$DRY_RUN" = false ]; then
                    chmod 600 "$key_file"
                    log_info "Changed SSH key file permissions: $key_perms -> 600"
                else
                    log_debug "Would change SSH key file permissions: $key_perms -> 600"
                fi
            fi
        else
            log_info "SSH key file has secure permissions: $key_file (600)"
        fi
    }
    
    # Create or update SSH config with secure defaults
    if [ ! -f "$ssh_config_file" ]; then
        log_warning "SSH config file not found: $ssh_config_file"
        
        if confirm_action "Create SSH config with secure defaults?"; then
            if [ "$DRY_RUN" = false ]; then
                cat > "$ssh_config_file" << 'EOF'
# Secure SSH Client Configuration

# Global defaults for all hosts
Host *
    # Security settings
    HashKnownHosts yes
    StrictHostKeyChecking ask
    VerifyHostKeyDNS yes
    
    # Prevent MITM attacks with clear warning
    VisualHostKey yes
    
    # Connection security
    Protocol 2
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
    KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
    
    # Authentication
    PubkeyAuthentication yes
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    
    # Connection settings
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
    
    # Security: Disable agent forwarding by default (enable only when needed)
    ForwardAgent no
    
    # Security: Disable X11 forwarding by default (enable only when needed)
    ForwardX11 no
    ForwardX11Trusted no

# Example of a specific host configuration
# Host example
#     HostName example.com
#     User username
#     Port 22
#     IdentityFile ~/.ssh/id_ed25519_example
EOF
                
                chmod 600 "$ssh_config_file"
                log_info "Created SSH config with secure defaults: $ssh_config_file"
            else
                log_debug "Would create SSH config with secure defaults: $ssh_config_file"
            fi
        fi
    else
        log_info "SSH config file exists: $ssh_config_file"
        
        # Check for insecure settings
        local insecure_settings=()
        
        if grep -q "PasswordAuthentication yes" "$ssh_config_file"; then
            insecure_settings+=("PasswordAuthentication yes")
        fi
        
        if grep -q "StrictHostKeyChecking no" "$ssh_config_file"; then
            insecure_settings+=("StrictHostKeyChecking no")
        fi
        
        if grep -q "ForwardAgent yes" "$ssh_config_file"; then
            insecure_settings+=("ForwardAgent yes")
        fi
        
        if [ ${#insecure_settings[@]} -gt 0 ]; then
            log_warning "Found ${#insecure_settings[@]} potentially insecure SSH settings"
            
            for setting in "${insecure_settings[@]}"; do
                log_warning "  - $setting"
            done
            
            if confirm_action "Would you like to update SSH config with more secure settings?"; then
                if [ "$DRY_RUN" = false ]; then
                    # Backup the original file
                    cp "$ssh_config_file" "${ssh_config_file}.backup_$(date +%s)"
                    
                    # Update insecure settings
                    if grep -q "PasswordAuthentication yes" "$ssh_config_file"; then
                        sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' "$ssh_config_file"
                    fi
                    
                    if grep -q "StrictHostKeyChecking no" "$ssh_config_file"; then
                        sed -i 's/StrictHostKeyChecking no/StrictHostKeyChecking ask/' "$ssh_config_file"
                    fi
                    
                    if grep -q "ForwardAgent yes" "$ssh_config_file"; then
                        sed -i 's/ForwardAgent yes/ForwardAgent no/' "$ssh_config_file"
                    fi
                    
                    log_info "Updated SSH config with more secure settings"
                else
                    log_debug "Would update SSH config with more secure settings"
                fi
            fi
        else
            log_info "SSH config appears to have secure settings"
        fi
    }
}

# Function to improve Git security
improve_git_security() {
    log_section "GIT SECURITY IMPROVEMENTS"
    
    local gitconfig_file="$HOME/.gitconfig"
    local dotfiles_gitconfig="$DOTFILES_DIR/.gitconfig"
    
    # Check if .gitconfig exists
    if [ -f "$gitconfig_file" ] || [ -f "$dotfiles_gitconfig" ]; then
        log_info "Found Git configuration file"
        
        # Determine which file to use
        local config_file="$gitconfig_file"
        if [ -f "$dotfiles_gitconfig" ]; then
            config_file="$dotfiles_gitconfig"
        fi
        
        # Check for security settings
        local missing_settings=()
        
        if ! git config --file "$config_file" --get-regexp "^core\.askPass" >/dev/null 2>&1; then
            missing_settings+=("core.askPass")
        fi
        
        if ! git config --file "$config_file" --get-regexp "^credential\.helper" >/dev/null 2>&1; then
            missing_settings+=("credential.helper")
        fi
        
        if ! git config --file "$config_file" --get-regexp "^http\.sslVerify" >/dev/null 2>&1; then
            missing_settings+=("http.sslVerify")
        fi
        
        if ! git config --file "$config_file" --get-regexp "^pull\.rebase" >/dev/null 2>&1; then
            missing_settings+=("pull.rebase")
        fi
        
        if [ ${#missing_settings[@]} -gt 0 ]; then
            log_warning "Missing recommended Git security settings: ${missing_settings[*]}"
            
            if confirm_action "Add recommended Git security settings?"; then
                if [ "$DRY_RUN" = false ]; then
                    # Add missing security settings
                    if [[ " ${missing_settings[*]} " =~ " core.askPass " ]]; then
                        git config --file "$config_file" core.askPass ""
                    fi
                    
                    if [[ " ${missing_settings[*]} " =~ " credential.helper " ]]; then
                        # Use the appropriate credential helper based on OS
                        if [ "$(uname)" == "Darwin" ]; then
                            git config --file "$config_file" credential.helper osxkeychain
                        elif [ "$(uname)" == "Linux" ]; then
                            if command -v libsecret-tools >/dev/null 2>&1; then
                                git config --file "$config_file" credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
                            else
                                git config --file "$config_file" credential.helper cache
                                git config --file "$config_file" credential.helper 'cache --timeout=3600'
                            fi
                        fi
                    fi
                    
                    if [[ " ${missing_settings[*]} " =~ " http.sslVerify " ]]; then
                        git config --file "$config_file" http.sslVerify true
                    fi
                    
                    if [[ " ${missing_settings[*]} " =~ " pull.rebase " ]]; then
                        git config --file "$config_file" pull.rebase true
                    fi
                    
                    log_info "Added recommended Git security settings to $config_file"
                else
                    log_debug "Would add recommended Git security settings to $config_file"
                fi
            fi
        else
            log_info "Git configuration already has recommended security settings"
        fi
    else
        log_warning "Git configuration file not found"
        
        if confirm_action "Create Git configuration with secure defaults?"; then
            if [ "$DRY_RUN" = false ]; then
                # Create Git config with secure defaults
                cat > "$dotfiles_gitconfig" << 'EOF'
[user]
	name = Your Name
	email = your.email@example.com

[core]
	editor = nano
	autocrlf = input
	safecrlf = true
	fileMode = true
	pager = less -FRX

[init]
	defaultBranch = main

[color]
	ui = auto

[pull]
	rebase = true

[push]
	default = simple

[fetch]
	prune = true

[http]
	sslVerify = true

[credential]
	helper = cache --timeout=3600

[diff]
	algorithm = histogram
	renames = copies

[merge]
	ff = only
	conflictstyle = diff3

[transfer]
	fsckObjects = true

[alias]
	lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
	st = status
	ci = commit
	co = checkout
	br = branch
	unstage = reset HEAD --
	last = log -1 HEAD
EOF
                
                log_info "Created Git configuration with secure defaults: $dotfiles_gitconfig"
                log_warning "Please update the user.name and user.email fields in the Git config"
            else
                log_debug "Would create Git configuration with secure defaults: $dotfiles_gitconfig"
            fi
        fi
    }
}

# Function to enhance environment variable security
enhance_env_var_security() {
    log_section "ENVIRONMENT VARIABLE SECURITY"
    
    # Create a secure environment variables script
    local secure_env_file="$SHELL_DIR/secure_env.sh"
    
    if [ ! -f "$secure_env_file" ]; then
        log_warning "Secure environment variables file not found: $secure_env_file"
        
        if confirm_action "Create secure environment variables file?"; then
            if [ "$DRY_RUN" = false ]; then
                mkdir -p "$SHELL_DIR"
                
                cat > "$secure_env_file" << 'EOF'
#!/bin/bash

# SECURE ENVIRONMENT VARIABLES MANAGER
# Safely manage sensitive environment variables

# Function to securely load environment variables from an encrypted file
load_secure_env() {
    local env_file="${1:-$HOME/.secure_env}"
    
    if [ ! -f "$env_file" ]; then
        echo "❌ Secure environment file not found: $env_file"
        return 1
    fi
    
    # Check if file is encrypted (GPG)
    if file "$env_file" | grep -q "GPG symmetrically encrypted"; then
        # Decrypt and source the file
        if command -v gpg >/dev/null 2>&1; then
            # Temporarily disable history
            if [ -n "$BASH_VERSION" ]; then
                set +o history
                source <(gpg --quiet --decrypt "$env_file" 2>/dev/null)
                set -o history
            elif [ -n "$ZSH_VERSION" ]; then
                unsetopt SHARE_HISTORY
                fc -p /dev/null
                source <(gpg --quiet --decrypt "$env_file" 2>/dev/null)
                fc -P
            fi
            echo "✅ Loaded encrypted environment variables from $env_file"
        else
            echo "❌ GPG not installed. Cannot decrypt environment file."
            return 1
        fi
    else
        # File is not encrypted, warn and source directly
        echo "⚠️  WARNING: Environment file is not encrypted: $env_file"
        echo "⚠️  Consider encrypting with: encrypt_secure_env $env_file"
        
        # Temporarily disable history
        if [ -n "$BASH_VERSION" ]; then
            set +o history
            source "$env_file"
            set -o history
        elif [ -n "$ZSH_VERSION" ]; then
            unsetopt SHARE_HISTORY
            fc -p /dev/null
            source "$env_file"
            fc -P
        fi
        echo "✅ Loaded unencrypted environment variables from $env_file"
    fi
}

# Function to create and encrypt an environment variables file
create_secure_env() {
    local env_file="${1:-$HOME/.secure_env}"
    
    # Check if file already exists
    if [ -f "$env_file" ]; then
        echo "⚠️  File already exists: $env_file"
        read -p "Overwrite? [y/N] " confirm
        if [[ "$confirm" != [yY]* ]]; then
            echo "❌ Operation cancelled"
            return 1
        fi
    fi
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Add header
    cat > "$temp_file" << 'HEADER'
# SECURE ENVIRONMENT VARIABLES
# This file contains sensitive environment variables
# It should be encrypted when not in use

# Format: export NAME=value

HEADER
    
    # Open the file in the default editor
    ${EDITOR:-nano} "$temp_file"
    
    # Encrypt the file
    if command -v gpg >/dev/null 2>&1; then
        gpg --symmetric --cipher-algo AES256 --output "$env_file" "$temp_file"
        echo "✅ Created and encrypted environment variables file: $env_file"
    else
        # If GPG is not available, save as plaintext but warn
        cp "$temp_file" "$env_file"
        chmod 600 "$env_file"
        echo "⚠️  GPG not installed. Saved as unencrypted file with restricted permissions."
        echo "⚠️  Install GPG and run: encrypt_secure_env $env_file"
    fi
    
    # Remove the temporary file
    rm -f "$temp_file"
}

# Function to encrypt an existing environment variables file
encrypt_secure_env() {
    local env_file="${1:-$HOME/.secure_env}"
    
    if [ ! -f "$env_file" ]; then
        echo "❌ File not found: $env_file"
        return 1
    fi
    
    # Check if file is already encrypted
    if file "$env_file" | grep -q "GPG symmetrically encrypted"; then
        echo "⚠️  File is already encrypted: $env_file"
        return 0
    fi
    
    if command -v gpg >/dev/null 2>&1; then
        # Create backup
        cp "$env_file" "${env_file}.backup"
        
        # Encrypt the file
        gpg --symmetric --cipher-algo AES256 --output "${env_file}.gpg" "$env_file"
        
        # If encryption successful, replace original with encrypted version
        if [ -f "${env_file}.gpg" ]; then
            mv "${env_file}.gpg" "$env_file"
            echo "✅ Encrypted environment variables file: $env_file"
            echo "✅ Original backed up to: ${env_file}.backup"
        else
            echo "❌ Encryption failed"
            return 1
        fi
    else
        echo "❌ GPG not installed. Cannot encrypt file."
        return 1
    fi
}

# Function to securely set an individual environment variable
secure_set_env() {
    local var_name="$1"
    
    if [ -z "$var_name" ]; then
        echo "❌ Variable name required"
        echo "Usage: secure_set_env VARIABLE_NAME"
        return 1
    fi
    
    # Use read -s to avoid showing the value in terminal
    read -s -p "Enter value for $var_name: " var_value
    echo ""  # Add newline after hidden input
    
    # Export the variable without logging
    if [ -n "$BASH_VERSION" ]; then
        set +o history
        export "$var_name"="$var_value"
        set -o history
    elif [ -n "$ZSH_VERSION" ]; then
        unsetopt SHARE_HISTORY
        fc -p /dev/null
        export "$var_name"="$var_value"
        fc -P
    fi
    
    echo "✅ Environment variable $var_name set securely"
}

# Function to list all environment variables, hiding sensitive values
list_env_vars() {
    local sensitive_patterns=("key" "token" "secret" "password" "credential" "auth")
    
    echo "ENVIRONMENT VARIABLES:"
    echo "======================"
    
    # Get all environment variables
    env | sort | while read -r line; do
        local var_name="${line%%=*}"
        local var_value="${line#*=}"
        local is_sensitive=false
        
        # Check if variable name contains sensitive patterns
        for pattern in "${sensitive_patterns[@]}"; do
            if [[ "$var_name" =~ $pattern ]]; then
                is_sensitive=true
                break
            fi
        done
        
        # Display with masked value if sensitive
        if [ "$is_sensitive" = true ]; then
            echo "$var_name=[HIDDEN]"
        else
            echo "$line"
        fi
    done
}

echo "🔒 Secure environment variables manager loaded"
echo "💡 Available commands:"
echo "  - load_secure_env [file]     # Load variables from encrypted file"
echo "  - create_secure_env [file]   # Create and encrypt a variables file"
echo "  - encrypt_secure_env [file]  # Encrypt an existing variables file"
echo "  - secure_set_env VAR_NAME    # Securely set a variable"
echo "  - list_env_vars              # List all variables (hiding sensitive values)"
EOF
                
                chmod 700 "$secure_env_file"
                log_info "Created secure environment variables file: $secure_env_file"
            else
                log_debug "Would create secure environment variables file: $secure_env_file"
            fi
        fi
    else
        log_info "Secure environment variables file already exists: $secure_env_file"
    }
    
    # Update shell configuration files to include secure environment variables
    local shell_files=("$HOME/.bashrc" "$HOME/.zshrc" "$SHELL_DIR/.bashrc" "$SHELL_DIR/.zshrc")
    
    for shell_file in "${shell_files[@]}"; do
        if [ -f "$shell_file" ]; then
            log_debug "Checking shell file: $shell_file"
            
            if ! grep -q "secure_env.sh" "$shell_file"; then
                log_warning "Shell file does not include secure environment variables: $shell_file"
                
                if confirm_action "Update $shell_file to include secure environment variables?"; then
                    if [ "$DRY_RUN" = false ]; then
                        # Backup the original file
                        cp "$shell_file" "${shell_file}.backup_$(date +%s)"
                        
                        # Add secure environment variables include
                        cat >> "$shell_file" << EOF

# Load secure environment variables manager
if [ -f "$SHELL_DIR/secure_env.sh" ]; then
    source "$SHELL_DIR/secure_env.sh"
fi
EOF
                        
                        log_info "Updated shell file to include secure environment variables: $shell_file"
                    else
                        log_debug "Would update shell file to include secure environment variables: $shell_file"
                    fi
                fi
            else
                log_info "Shell file already includes secure environment variables: $shell_file"
            fi
        fi
    done
}

# Function to audit file permissions
audit_file_permissions() {
    log_section "FILE PERMISSION AUDIT"
    
    local audit_report="$DOTFILES_DIR/permission_audit_$(date +%s).txt"
    
    log_info "Auditing file permissions in dotfiles directory..."
    
    if [ "$DRY_RUN" = false ]; then
        echo "FILE PERMISSION AUDIT REPORT" > "$audit_report"
        echo "Generated: $(date)" >> "$audit_report"
        echo "========================================" >> "$audit_report"
        echo "" >> "$audit_report"
        
        # Check for world-writable files
        echo "WORLD-WRITABLE FILES (CRITICAL SECURITY RISK):" >> "$audit_report"
        find "$DOTFILES_DIR" -type f -perm -002 -not -path "*/\.*" 2>/dev/null | while read -r file; do
            local perms=$(stat -c "%a" "$file")
            echo "  - $file ($perms)" >> "$audit_report"
            
            # Automatically fix critical permissions if force mode is enabled
            if [ "$FORCE" = true ]; then
                chmod o-w "$file"
                local new_perms=$(stat -c "%a" "$file")
                echo "    ✓ Fixed: $perms -> $new_perms" >> "$audit_report"
            fi
        done
        echo "" >> "$audit_report"
        
        # Check for world-writable directories
        echo "WORLD-WRITABLE DIRECTORIES (CRITICAL SECURITY RISK):" >> "$audit_report"
        find "$DOTFILES_DIR" -type d -perm -002 -not -path "*/\.*" 2>/dev/null | while read -r dir; do
            local perms=$(stat -c "%a" "$dir")
            echo "  - $dir ($perms)" >> "$audit_report"
            
            # Automatically fix critical permissions if force mode is enabled
            if [ "$FORCE" = true ]; then
                chmod o-w "$dir"
                local new_perms=$(stat -c "%a" "$dir")
                echo "    ✓ Fixed: $perms -> $new_perms" >> "$audit_report"
            fi
        done
        echo "" >> "$audit_report"
        
        # Check for setuid/setgid files
        echo "SETUID/SETGID FILES (POTENTIAL SECURITY RISK):" >> "$audit_report"
        find "$DOTFILES_DIR" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while read -r file; do
            local perms=$(stat -c "%a" "$file")
            echo "  - $file ($perms)" >> "$audit_report"
        done
        echo "" >> "$audit_report"
        
        # Check for executable scripts
        echo "EXECUTABLE SCRIPTS:" >> "$audit_report"
        find "$DOTFILES_DIR" -type f -name "*.sh" -perm /111 2>/dev/null | while read -r file; do
            local perms=$(stat -c "%a" "$file")
            echo "  - $file ($perms)" >> "$audit_report"
        done
        echo "" >> "$audit_report"
        
        # Check for sensitive files with lax permissions
        echo "SENSITIVE FILES WITH LAX PERMISSIONS:" >> "$audit_report"
        find "$DOTFILES_DIR" -type f \( -name "*password*" -o -name "*secret*" -o -name "*token*" -o -name "*key*" -o -name "*credential*" \) -not -path "*/\.*" 2>/dev/null | while read -r file; do
            local perms=$(stat -c "%a" "$file")
            if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
                echo "  - $file ($perms)" >> "$audit_report"
                
                # Automatically fix sensitive file permissions if force mode is enabled
                if [ "$FORCE" = true ]; then
                    chmod 600 "$file"
                    local new_perms=$(stat -c "%a" "$file")
                    echo "    ✓ Fixed: $perms -> $new_perms" >> "$audit_report"
                fi
            fi
        done
        echo "" >> "$audit_report"
        
        # Recommendations
        echo "RECOMMENDATIONS:" >> "$audit_report"
        echo "  - World-writable files should be fixed immediately (chmod o-w)" >> "$audit_report"
        echo "  - Sensitive files should have 600 permissions (chmod 600)" >> "$audit_report"
        echo "  - Executable scripts should have 700 permissions (chmod 700)" >> "$audit_report"
        echo "  - Directories should have 755 or 750 permissions" >> "$audit_report"
        echo "  - SetUID/SetGID should be removed unless specifically required" >> "$audit_report"
        
        chmod 600 "$audit_report"
        log_info "Created file permission audit report: $audit_report"
    else
        log_debug "Would create file permission audit report: $audit_report"
    fi
}

# Main function
main() {
    log_section "DOTFILES SECURITY HARDENING"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check if dotfiles directory exists
    if [ ! -d "$DOTFILES_DIR" ]; then
        log_error "Dotfiles directory not found: $DOTFILES_DIR"
        exit 1
    fi
    
    # Run security enhancement functions
    enhance_shell_history_security
    harden_script_permissions
    detect_sensitive_data
    harden_ssh_config
    improve_git_security
    enhance_env_var_security
    audit_file_permissions
    
    log_section "SECURITY HARDENING COMPLETE"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "This was a dry run. No changes were made."
        log_info "Run without --dry-run to apply the changes."
    else
        log_info "Security hardening completed successfully."
        log_info "Your dotfiles are now more secure."
    fi
}

# Run the main function
main "$@"