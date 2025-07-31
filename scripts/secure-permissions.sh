#!/bin/bash

# SECURE PERMISSIONS SCRIPT
# Automatically sets secure permissions for files and directories

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
DOTFILES_DIR="$HOME/.dotfiles"
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
🔒 SECURE PERMISSIONS SCRIPT
===========================

DESCRIPTION:
  Automatically sets secure permissions for files and directories.
  Applies best practices for file system security.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --dry-run, -n    Simulate actions without making changes
  --verbose, -v    Enable detailed output
  --force, -f      Apply changes without confirmation
  --help, -h       Show this help message

FEATURES:
  ✅ Sets secure permissions for sensitive files
  ✅ Restricts directory permissions
  ✅ Secures SSH and GPG directories
  ✅ Protects configuration files
  ✅ Secures script files

EXAMPLES:
  $0                    # Run with confirmation prompts
  $0 --dry-run         # Preview changes without applying
  $0 --force           # Apply all changes without prompting
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
        echo -e "${BLUE}🔍 $1${NC}"
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

# Function to set permissions for a file
set_file_permissions() {
    local file="$1"
    local perms="$2"
    local description="$3"
    
    if [ ! -f "$file" ]; then
        log_debug "File not found: $file"
        return
    fi
    
    local current_perms=$(stat -c "%a" "$file")
    
    if [ "$current_perms" != "$perms" ]; then
        log_warning "File has incorrect permissions: $file ($current_perms, should be $perms)"
        log_debug "File type: $description"
        
        if [ "$DRY_RUN" = true ]; then
            log_debug "Would change permissions for $file: $current_perms -> $perms"
        elif [ "$FORCE" = true ] || confirm_action "Change permissions for $file to $perms?"; then
            chmod "$perms" "$file"
            log_info "Changed permissions for $file: $current_perms -> $perms"
        else
            log_debug "Skipped changing permissions for $file"
        fi
    else
        log_debug "File already has correct permissions: $file ($perms)"
    fi
}

# Function to set permissions for a directory
set_directory_permissions() {
    local dir="$1"
    local perms="$2"
    local description="$3"
    
    if [ ! -d "$dir" ]; then
        log_debug "Directory not found: $dir"
        return
    fi
    
    local current_perms=$(stat -c "%a" "$dir")
    
    if [ "$current_perms" != "$perms" ]; then
        log_warning "Directory has incorrect permissions: $dir ($current_perms, should be $perms)"
        log_debug "Directory type: $description"
        
        if [ "$DRY_RUN" = true ]; then
            log_debug "Would change permissions for $dir: $current_perms -> $perms"
        elif [ "$FORCE" = true ] || confirm_action "Change permissions for $dir to $perms?"; then
            chmod "$perms" "$dir"
            log_info "Changed permissions for $dir: $current_perms -> $perms"
        else
            log_debug "Skipped changing permissions for $dir"
        fi
    else
        log_debug "Directory already has correct permissions: $dir ($perms)"
    fi
}

# Function to secure SSH directory
secure_ssh_directory() {
    log_section "SECURING SSH DIRECTORY"
    
    local ssh_dir="$HOME/.ssh"
    
    if [ ! -d "$ssh_dir" ]; then
        log_warning "SSH directory not found: $ssh_dir"
        
        if [ "$DRY_RUN" = true ]; then
            log_debug "Would create SSH directory with secure permissions"
        elif [ "$FORCE" = true ] || confirm_action "Create SSH directory with secure permissions?"; then
            mkdir -p "$ssh_dir"
            chmod 700 "$ssh_dir"
            log_info "Created SSH directory with secure permissions: $ssh_dir"
        fi
        
        return
    }
    
    # Set permissions for SSH directory
    set_directory_permissions "$ssh_dir" "700" "SSH directory"
    
    # Find and secure SSH key files
    log_info "Securing SSH key files..."
    
    # Private keys
    find "$ssh_dir" -type f -name "id_*" ! -name "*.pub" 2>/dev/null | while read -r key_file; do
        set_file_permissions "$key_file" "600" "SSH private key"
    done
    
    # Public keys
    find "$ssh_dir" -type f -name "*.pub" 2>/dev/null | while read -r pub_file; do
        set_file_permissions "$pub_file" "644" "SSH public key"
    done
    
    # Known hosts and config
    if [ -f "$ssh_dir/known_hosts" ]; then
        set_file_permissions "$ssh_dir/known_hosts" "644" "SSH known hosts"
    fi
    
    if [ -f "$ssh_dir/config" ]; then
        set_file_permissions "$ssh_dir/config" "600" "SSH config"
    fi
    
    if [ -f "$ssh_dir/authorized_keys" ]; then
        set_file_permissions "$ssh_dir/authorized_keys" "600" "SSH authorized keys"
    fi
}

# Function to secure GPG directory
secure_gpg_directory() {
    log_section "SECURING GPG DIRECTORY"
    
    local gpg_dir="$HOME/.gnupg"
    
    if [ ! -d "$gpg_dir" ]; then
        log_warning "GPG directory not found: $gpg_dir"
        
        if [ "$DRY_RUN" = true ]; then
            log_debug "Would create GPG directory with secure permissions"
        elif [ "$FORCE" = true ] || confirm_action "Create GPG directory with secure permissions?"; then
            mkdir -p "$gpg_dir"
            chmod 700 "$gpg_dir"
            log_info "Created GPG directory with secure permissions: $gpg_dir"
        fi
        
        return
    }
    
    # Set permissions for GPG directory
    set_directory_permissions "$gpg_dir" "700" "GPG directory"
    
    # Set permissions for all files in GPG directory
    find "$gpg_dir" -type f 2>/dev/null | while read -r gpg_file; do
        set_file_permissions "$gpg_file" "600" "GPG file"
    done
}

# Function to secure script files
secure_script_files() {
    log_section "SECURING SCRIPT FILES"
    
    # Find all shell scripts in dotfiles directory
    find "$DOTFILES_DIR" -type f -name "*.sh" 2>/dev/null | while read -r script; do
        # Make scripts executable by owner only
        set_file_permissions "$script" "700" "Shell script"
    done
    
    log_info "Secured all shell scripts"
}

# Function to secure sensitive configuration files
secure_config_files() {
    log_section "SECURING CONFIGURATION FILES"
    
    # Define sensitive configuration files
    local sensitive_configs=(
        "$HOME/.netrc"
        "$HOME/.pgpass"
        "$HOME/.my.cnf"
        "$HOME/.npmrc"
        "$HOME/.docker/config.json"
        "$HOME/.aws/credentials"
        "$HOME/.aws/config"
        "$HOME/.kube/config"
        "$HOME/.config/gcloud/credentials"
        "$HOME/.config/rclone/rclone.conf"
        "$HOME/.config/hub"
        "$HOME/.config/git/credentials"
        "$HOME/.gitconfig"
        "$HOME/.config/pip/pip.conf"
        "$HOME/.gradle/gradle.properties"
        "$HOME/.m2/settings.xml"
        "$HOME/.config/pulse/cookie"
        "$HOME/.config/hexchat/certs"
    )
    
    for config in "${sensitive_configs[@]}"; do
        if [ -f "$config" ]; then
            set_file_permissions "$config" "600" "Sensitive configuration file"
        fi
    done
    
    # Find and secure files with sensitive names
    log_info "Securing files with sensitive names..."
    
    local sensitive_patterns=(
        "*password*" "*secret*" "*token*" "*key*" "*credential*" "*auth*"
        "*.pem" "*.key" "*.p12" "*.pfx" "*.jks" "*.keystore"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        find "$HOME" -type f -name "$pattern" -not -path "*/\.*" 2>/dev/null | while read -r sensitive_file; do
            set_file_permissions "$sensitive_file" "600" "File with sensitive name"
        done
    done
}

# Function to secure home directory
secure_home_directory() {
    log_section "SECURING HOME DIRECTORY"
    
    # Set permissions for home directory
    set_directory_permissions "$HOME" "750" "Home directory"
    
    # Secure important dot directories
    local dot_dirs=(
        "$HOME/.config"
        "$HOME/.local"
        "$HOME/.cache"
    )
    
    for dir in "${dot_dirs[@]}"; do
        if [ -d "$dir" ]; then
            set_directory_permissions "$dir" "750" "User configuration directory"
        fi
    done
}

# Function to secure dotfiles directory
secure_dotfiles_directory() {
    log_section "SECURING DOTFILES DIRECTORY"
    
    # Set permissions for dotfiles directory
    set_directory_permissions "$DOTFILES_DIR" "750" "Dotfiles directory"
    
    # Secure important subdirectories
    local subdirs=(
        "$DOTFILES_DIR/scripts"
        "$DOTFILES_DIR/shell"
    )
    
    for dir in "${subdirs[@]}"; do
        if [ -d "$dir" ]; then
            set_directory_permissions "$dir" "750" "Dotfiles subdirectory"
        fi
    done
}

# Main function
main() {
    log_section "SECURE PERMISSIONS SCRIPT"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Run security functions
    secure_home_directory
    secure_dotfiles_directory
    secure_ssh_directory
    secure_gpg_directory
    secure_script_files
    secure_config_files
    
    log_section "PERMISSIONS SECURED"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "This was a dry run. No changes were made."
        log_info "Run without --dry-run to apply the changes."
    else
        log_info "File and directory permissions have been secured."
        log_info "Your system is now more protected."
    fi
}

# Run the main function
main "$@"