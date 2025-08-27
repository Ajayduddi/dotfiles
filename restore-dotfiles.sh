#!/bin/bash
# Dotfiles Restoration Script
# Version: 1.1.0
# Last Updated: $(date +%Y-%m-%d)
# Description: Restores dotfiles from a repository and configures system settings
#
# SECURITY WARNING:
# This script will modify your home directory files and install packages.
# It requires sudo privileges for package installation.
# Review the script and understand what it does before running.
# Only run this script if you trust the source repository.

set -e  # Exit on first error
umask 077  # Restrict file permissions for security

# Minimal emoji output (set NO_EMOJI=true to strip icons)
NO_EMOJI=${NO_EMOJI:-true}
strip_emojis() { sed -E 's/(✅|🔍|⚠️|❌|🟡|📝|🔧|💾|📦|🖥️|🚀|🌐|🗄️|🔒|🔗|🔄|➡️|🐱|☕|🛠️|📁|🔌|🛡️|🧪|🔎|📊|🧹|🟢|🟠|🔵)//g'; }
echo() {
  local newline=true; local enable_escape=false; local args=()
  while [[ $# -gt 0 ]]; do case "$1" in -n) newline=false;; -e) enable_escape=true;; *) args+=("$1");; esac; shift; done
  local msg="${args[*]}"
  if [[ "$NO_EMOJI" = "true" ]]; then msg=$(printf "%s" "$msg" | strip_emojis); fi
  if $enable_escape; then if $newline; then builtin echo -e "$msg"; else builtin echo -ne "$msg"; fi
  else if $newline; then builtin echo "$msg"; else builtin echo -n "$msg"; fi; fi
}

# Record start time for execution time calculation
START_TIME=$(date +%s)

# Configuration variables - can be overridden with environment variables
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
EXTENSIONS_DIR="${EXTENSIONS_DIR:-$HOME/.local/share/gnome-shell/extensions}"
REPO_URL="${REPO_URL:-https://github.com/Ajayduddi/dotfiles.git}"
DEFAULT_BRANCH="${BRANCH:-linux}"
BACKUP_SUFFIX="_backup_$(date +%s)"

# Create temp directory for logs with secure permissions
TEMP_DIR=$(mktemp -d)
chmod 700 "$TEMP_DIR"

# Colors for better output
GREEN='\e[1;32m'
RED='\e[1;31m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m' # No Color

# Function to log messages with timestamp
log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}[INFO]${NC} [$timestamp] $1"
}

# Function to log warnings with timestamp
warn() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}[WARNING]${NC} [$timestamp] $1"
}

# Enhanced error handling function
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    local rollback="${3:-false}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${RED}[ERROR]${NC} [$timestamp] $message"
    
    if [[ "$rollback" == "true" ]]; then
        echo -e "${YELLOW}[ROLLBACK]${NC} Attempting to restore previous state..."
        # Implement rollback logic here if needed
    fi
    
    # Clean up temp directory on exit
    [ -d "$TEMP_DIR" ] && safe_remove "$TEMP_DIR"
    
    exit "$exit_code"
}

# Function to run Git safely
dotfiles() {
    git --git-dir="$DOTFILES_DIR/.git" --work-tree="$HOME" "$@"
}

# Function to clean up on exit
cleanup() {
    log "Cleaning up temporary files..."
    [ -d "$TEMP_DIR" ] && safe_remove "$TEMP_DIR"
}

# Set up trap to ensure cleanup on exit
trap cleanup EXIT INT TERM

# Function to create secure temporary files
create_temp_file() {
    local prefix="${1:-temp}"
    local temp_file
    
    temp_file=$(mktemp "$TEMP_DIR/${prefix}_XXXXXX")
    chmod 600 "$temp_file"
    echo "$temp_file"
}

# Safe removal function
safe_remove() {
    local path="$1"
    
    # Don't remove critical directories
    if [[ "$path" == "/" || "$path" == "/home" || "$path" == "$HOME" || -z "$path" ]]; then
        error_exit "Attempted to remove critical directory: $path"
        return 1
    fi
    
    # Ensure path exists before removing
    if [[ -e "$path" ]]; then
        rm -rf "$path"
        return $?
    fi
    
    return 0
}

# Function to safely run commands with sudo
safe_sudo() {
    local cmd="$1"
    shift
    
    # Log the command being executed with sudo
    log "Executing with sudo: $cmd $*"
    
    # Execute the command with sudo
    sudo "$cmd" "$@"
}

# Function to validate path safety
validate_path() {
    local path="$1"
    local base_dir="$2"
    
    # Convert to absolute path
    local abs_path
    abs_path=$(realpath -s "$path" 2>/dev/null)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Check if path is within base directory
    if [[ "$abs_path" != "$base_dir"* ]]; then
        return 1
    fi
    
    return 0
}

# Function to safely create symlinks
safe_symlink() {
    local source="$1"
    local target="$2"
    local base_dir="$3"
    
    # Validate source path
    if ! validate_path "$source" "$base_dir"; then
        error_exit "Invalid source path for symlink: $source"
        return 1
    fi
    
    # Create the symlink
    ln -sf "$source" "$target" || return 1
    return 0
}

# Function to detect OS type automatically
detect_os_type() {
    if [ -f /etc/fedora-release ]; then
        echo "1" # Fedora
    elif [ -f /etc/debian_version ]; then
        echo "2" # Debian/Ubuntu
    elif [ -f /etc/arch-release ]; then
        echo "3" # Arch Linux
    else
        # Try to detect using package managers
        if command -v dnf &>/dev/null; then
            echo "1" # Fedora/RPM-based
        elif command -v apt-get &>/dev/null; then
            echo "2" # Debian/Ubuntu
        elif command -v pacman &>/dev/null; then
            echo "3" # Arch Linux
        else
            echo "0" # Unknown
        fi
    fi
}

# Prompt user to select OS type with auto-detection
AUTO_DETECTED_OS=$(detect_os_type)
log "Select your Linux OS type:"
echo "1) Fedora (RPM)"
echo "2) Ubuntu/Debian (APT)"
echo "3) Arch Linux (Pacman)"
echo "4) Other (Skip package installation)"

if [ "$AUTO_DETECTED_OS" != "0" ]; then
    case $AUTO_DETECTED_OS in
        1) detected_name="Fedora" ;;
        2) detected_name="Ubuntu/Debian" ;;
        3) detected_name="Arch Linux" ;;
    esac
    echo -e "${BLUE}Auto-detected OS: $detected_name${NC}"
    read -p "Enter your choice (1-4) [default: $AUTO_DETECTED_OS]: " OS_TYPE
    OS_TYPE=${OS_TYPE:-$AUTO_DETECTED_OS}
else
    read -p "Enter your choice (1-4): " OS_TYPE
fi

# Validate OS selection
if [[ ! "$OS_TYPE" =~ ^[1-4]$ ]]; then
    error_exit "Invalid OS type selection. Please run the script again and select a valid option."
fi

# Check for sudo privileges upfront
log "Checking for sudo privileges (required for package installation)..."
if ! sudo -n true 2>/dev/null; then
    warn "This script requires sudo privileges for package installation"
    sudo -v || warn "Failed to obtain sudo privileges. Package installation may fail."
else
    log "Sudo privileges confirmed"
fi

# Check if dotfiles repo exists
if [ -d "$DOTFILES_DIR" ]; then
    log "Dotfiles repository already exists!"
    read -p "Do you want to delete and re-clone it? (y/n): " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        log "Removing existing dotfiles directory..."
        safe_remove "$DOTFILES_DIR"
    else
        log "Skipping cloning. Using existing dotfiles."
    fi
fi

# Clone Dotfiles Repo only if it was removed
if [ ! -d "$DOTFILES_DIR" ]; then
    log "Cloning Dotfiles Repository from $REPO_URL (branch: $DEFAULT_BRANCH)..."
    git clone --branch "$DEFAULT_BRANCH" "$REPO_URL" "$DOTFILES_DIR" --config transfer.fsckObjects=true || error_exit "Failed to clone dotfiles repo"
fi

# Ensure the repository is valid before running Git commands
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    error_exit "Dotfiles repository is missing .git directory. Clone might have failed."
fi

# Move into the dotfiles directory before running Git commands
cd "$DOTFILES_DIR" || error_exit "Failed to access dotfiles directory."

# Ensure the correct branch is checked out
log "Checking out dotfiles (branch: $DEFAULT_BRANCH)..."
dotfiles checkout "$DEFAULT_BRANCH" 2>/dev/null || {
    log "Some files are blocking checkout. Backing up conflicting files..."
    
    # Create a list of conflicting files
    mkdir -p "$TEMP_DIR/conflicts"
    local conflict_file=$(create_temp_file "conflict_files")
    dotfiles checkout 2>&1 | grep -E "^\s+(.+)$" | awk '{print $1}' > "$conflict_file"
    
    # Backup conflicting files before force checkout
    if [ -s "$conflict_file" ]; then
        while IFS= read -r file; do
            if [ -f "$HOME/$file" ]; then
                cp -a "$HOME/$file" "$TEMP_DIR/conflicts/" 2>/dev/null || true
                log "Backed up conflicting file: $file"
            fi
        done < "$conflict_file"
    fi
    
    # Force checkout
    dotfiles checkout -f "$DEFAULT_BRANCH" || error_exit "Failed to checkout dotfiles."
    log "Conflicting files were backed up to: $TEMP_DIR/conflicts"
}
log "Dotfiles checkout successful!"

# Detect desktop environment in a robust way
_detect_desktop_env() {
    local de
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        de="$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        de="$DESKTOP_SESSION"
    elif [ -n "$GDMSESSION" ]; then
        de="$GDMSESSION"
    else
        de="unknown"
    fi
    de=$(printf '%s' "$de" | tr '[:upper:]' '[:lower:]')
    case "$de" in
        *gnome*) echo "gnome" ;;
        *cinnamon*) echo "cinnamon" ;;
        *cosmic*) echo "cosmic" ;;
        *plasma*|*kde*) echo "kde" ;;
        *xfce*) echo "xfce" ;;
        *mate*) echo "mate" ;;
        *) echo "unknown" ;;
    esac
}

_restore_gnome() {
    log "Restoring GNOME desktop settings..."
    # Restore dconf settings if backup exists
    if [ -f "$DOTFILES_DIR/gnome-settings.dconf" ]; then
        local dconf_error_log; dconf_error_log=$(create_temp_file "dconf_error_gnome")
        if dconf load / < "$DOTFILES_DIR/gnome-settings.dconf" 2> "$dconf_error_log"; then
            log "GNOME settings restored from dconf backup."
            echo GNOME > "$TEMP_DIR/desktop_applied"
        else
            warn "Some GNOME settings couldn't be restored. See $dconf_error_log"
        fi
    else
        log "No GNOME dconf backup found; skipping dconf restore."
    fi

    # Restore GNOME extensions if present in dotfiles
    local ext_src="$DOTFILES_DIR/.local/share/gnome-shell/extensions"
    if [ -d "$ext_src" ]; then
        log "Restoring GNOME Extensions..."
        if [ -e "$EXTENSIONS_DIR" ]; then
            mv "$EXTENSIONS_DIR" "${EXTENSIONS_DIR}${BACKUP_SUFFIX}" && log "Renamed existing extensions folder to backup."
        fi
        safe_symlink "$ext_src" "$EXTENSIONS_DIR" "$DOTFILES_DIR" || warn "Failed to link GNOME extensions folder."
    fi
}

_restore_cinnamon() {
    log "Restoring Cinnamon desktop settings..."
    local file="$DOTFILES_DIR/cinnamon-settings.dconf"
    if [ -f "$file" ]; then
        local dconf_error_log; dconf_error_log=$(create_temp_file "dconf_error_cinnamon")
        if dconf load / < "$file" 2> "$dconf_error_log"; then
            log "Cinnamon settings restored from dconf backup."
            echo CINNAMON > "$TEMP_DIR/desktop_applied"
        else
            warn "Some Cinnamon settings couldn't be restored. See $dconf_error_log"
        fi
    else
        log "No Cinnamon dconf backup found; skipping."
    fi
}

_restore_cosmic() {
    log "Restoring COSMIC desktop settings..."
    local file="$DOTFILES_DIR/cosmic-settings.dconf"
    if [ -f "$file" ]; then
        local dconf_error_log; dconf_error_log=$(create_temp_file "dconf_error_cosmic")
        if dconf load / < "$file" 2> "$dconf_error_log"; then
            log "COSMIC settings restored from dconf backup."
            echo COSMIC > "$TEMP_DIR/desktop_applied"
        else
            warn "Some COSMIC settings couldn't be restored. See $dconf_error_log"
        fi
    else
        log "No COSMIC dconf backup found; skipping."
    fi
}

_restore_kde() {
    log "Restoring KDE Plasma settings..."
    # Restore plasmoids if backed up
    local plasmoids_src="$DOTFILES_DIR/.local/share/plasma/plasmoids"
    local plasmoids_dst="$HOME/.local/share/plasma/plasmoids"
    if [ -d "$plasmoids_src" ]; then
        log "Restoring KDE plasmoids..."
        if [ -e "$plasmoids_dst" ]; then
            mv "$plasmoids_dst" "${plasmoids_dst}${BACKUP_SUFFIX}" && log "Renamed existing plasmoids folder to backup."
        fi
        safe_symlink "$plasmoids_src" "$plasmoids_dst" "$DOTFILES_DIR" || warn "Failed to link KDE plasmoids folder."
        echo KDE > "$TEMP_DIR/desktop_applied"
    fi

    # Import konsave profile if available and konsave is installed
    if command -v konsave >/dev/null 2>&1; then
        local ks
        ks=$(ls -1 "$DOTFILES_DIR"/kde/*.knsv 2>/dev/null | head -n1 || true)
        if [ -n "$ks" ]; then
            local prof
            prof=$(basename "$ks" .knsv)
            log "Importing KDE konsave profile: $prof"
            if konsave -i "$ks" && konsave -a "$prof"; then
                log "Applied konsave profile: $prof"
                echo KDE > "$TEMP_DIR/desktop_applied"
            else
                warn "Failed to import/apply konsave profile: $prof"
            fi
        fi
    fi
}

restore_desktop_settings() {
    local de; de=$(_detect_desktop_env)
    log "Detected desktop environment: $de"
    case "$de" in
        gnome) _restore_gnome ;;
        cinnamon) _restore_cinnamon ;;
        cosmic) _restore_cosmic ;;
        kde) _restore_kde ;;
        *) log "No desktop-specific restore steps for: $de" ;;
    esac
}

# Desktop environment-specific restore
restore_desktop_settings

# Restore .config files safely: if .config exists, rename it; then link the backup
log "Restoring .config files..."
if [ -e "$CONFIG_DIR" ]; then
    mv "$CONFIG_DIR" "${CONFIG_DIR}${BACKUP_SUFFIX}" && log "Renamed existing .config to backup."
fi
safe_symlink "$DOTFILES_DIR/.config" "$CONFIG_DIR" "$DOTFILES_DIR" || error_exit "Failed to link .config folder."

# Restore Shell Configuration Files & Create Symlinks
log "WARNING: Shell history files may contain sensitive information. Review them before restoring."
log "Restoring shell configuration files..."

# Handle regular config files
for file in .bashrc .zshrc .bash_profile; do
    if [ -f "$DOTFILES_DIR/shell/$file" ]; then
        if [ -e "$HOME/$file" ]; then
            mv "$HOME/$file" "$HOME/${file}${BACKUP_SUFFIX}" && log "Renamed existing $file to backup."
        fi
        safe_symlink "$DOTFILES_DIR/shell/$file" "$HOME/$file" "$DOTFILES_DIR" || error_exit "Failed to link $file"
    fi
done

# Handle history files separately with a prompt
for history_file in .bash_history .zsh_history .mysql_history; do
    if [ -f "$DOTFILES_DIR/shell/$history_file" ]; then
        echo -e "${YELLOW}[WARNING]${NC} $history_file may contain sensitive information."
        read -p "Do you want to restore this history file? (y/n): " RESTORE_HISTORY
        if [[ "$RESTORE_HISTORY" =~ ^[Yy]$ ]]; then
            if [ -e "$HOME/$history_file" ]; then
                mv "$HOME/$history_file" "$HOME/${history_file}${BACKUP_SUFFIX}" && log "Renamed existing $history_file to backup."
            fi
            safe_symlink "$DOTFILES_DIR/shell/$history_file" "$HOME/$history_file" "$DOTFILES_DIR" || error_exit "Failed to link $history_file"
            log "Restored $history_file"
        else
            log "Skipped restoring $history_file"
        fi
    fi
done

# Restore tmux and nano configurations
# We keep only .tmux.conf under version control and re-clone plugins via TPM.
for cfg_file in ".tmux.conf" ".nanorc"; do
    if [ -f "$DOTFILES_DIR/shell/$cfg_file" ]; then
        if [ -e "$HOME/$cfg_file" ]; then
            mv "$HOME/$cfg_file" "$HOME/${cfg_file}${BACKUP_SUFFIX}" && log "Renamed existing $cfg_file to backup."
        fi
        safe_symlink "$DOTFILES_DIR/shell/$cfg_file" "$HOME/$cfg_file" "$DOTFILES_DIR" || error_exit "Failed to link $cfg_file"
    fi
done

# Ensure TPM and install plugins at pinned versions
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" || warn "Failed to clone TPM"
fi

# Install plugins (non-fatal if tmux not present)
if command -v tmux >/dev/null 2>&1 && [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "TPM plugin install reported issues"
fi

# Pin catppuccin/tmux to v2.1.3 if present
if [ -d "$HOME/.tmux/plugins/tmux" ]; then
    git -C "$HOME/.tmux/plugins/tmux" fetch --tags --quiet || true
    git -C "$HOME/.tmux/plugins/tmux" checkout -q v2.1.3 || warn "Failed to checkout catppuccin/tmux v2.1.3"
fi

# Prune any leftover plugin directories in dotfiles backup (we don't track them)
if [ -d "$DOTFILES_DIR/.tmux/plugins" ]; then
    warn "Pruning backed-up TPM plugin checkouts from dotfiles repo"
    rm -rf "$DOTFILES_DIR/.tmux/plugins" || true
fi

# Restore nano and tmux directories only if intentionally backed up (excluding plugins)
for cfg_dir in ".tmuxp" ".nano"; do
    if [ -d "$DOTFILES_DIR/$cfg_dir" ]; then
        if [ -e "$HOME/$cfg_dir" ]; then
            mv "$HOME/$cfg_dir" "$HOME/${cfg_dir}${BACKUP_SUFFIX}" && log "Renamed existing $cfg_dir to backup."
        fi
        safe_symlink "$DOTFILES_DIR/$cfg_dir" "$HOME/$cfg_dir" "$DOTFILES_DIR" || error_exit "Failed to link $cfg_dir"
    fi
done

# Helper function to check if a package is installed
check_package_installed() {
    local check_cmd="$1"
    local package="$2"
    
    case "$check_cmd" in
        "rpm -q")
            rpm -q "$package" &>/dev/null
            ;;
        "dpkg -l | grep -q")
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        "pacman -Q")
            pacman -Q "$package" &>/dev/null
            ;;
        *)
            warn "Unknown package check command: $check_cmd"
            return 1
            ;;
    esac
}

# Helper function to install packages safely
install_packages_safely() {
    local install_cmd="$1"
    shift
    local packages=("$@")
    
    case "$install_cmd" in
        "sudo dnf install -y")
            safe_sudo dnf install -y "${packages[@]}"
            ;;
        "sudo apt-get install -y")
            safe_sudo apt-get install -y "${packages[@]}"
            ;;
        "sudo pacman -S --needed --noconfirm")
            safe_sudo pacman -S --needed --noconfirm "${packages[@]}"
            ;;
        *)
            warn "Unknown install command: $install_cmd"
            return 1
            ;;
    esac
}

# Function to install packages more efficiently and securely
install_packages() {
    local package_file="$1"
    local install_cmd="$2"
    local check_cmd="$3"
    local os_name="$4"
    
    if [[ ! -s "$package_file" ]]; then
        warn "No $os_name package list found at $package_file."
        return 1
    fi
    
    log "Reading package list from $package_file..."
    
    # Filter out comments and empty lines
    local to_install=()
    local already_installed=0
    local total_packages=0
    
    # Read packages safely line by line
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]] && continue
        
        # Trim whitespace
        pkg=$(echo "$line" | xargs)
        [[ -z "$pkg" ]] && continue
        
        ((total_packages++))
        
        # Check if package is installed - avoid eval
        if check_package_installed "$check_cmd" "$pkg"; then
            ((already_installed++))
            log "Package already installed: $pkg"
        else
            to_install+=("$pkg")
        fi
    done < "$package_file"
    
    log "$already_installed out of $total_packages packages are already installed."
    
    # Install missing packages
    if [ ${#to_install[@]} -gt 0 ]; then
        log "Installing ${#to_install[@]} $os_name packages..."
        
        # Execute the install command with proper array handling
        if install_packages_safely "$install_cmd" "${to_install[@]}"; then
            log "Successfully installed all missing $os_name packages."
        else
            warn "Failed to install some $os_name packages. Check the output above for details."
        fi
    else
        log "All $os_name packages are already installed."
    fi
}

# Restore Installed Packages
log "Restoring Installed Packages..."

if [ "$OS_TYPE" = "4" ]; then
    log "Skipping package installation as requested."
else
    case "$OS_TYPE" in
        1)
            log "Installing Fedora Packages..."
            # Update package database first
            safe_sudo dnf check-update -y || true
            install_packages "$DOTFILES_DIR/dnf-packages.txt" \
                            "sudo dnf install -y" \
                            "rpm -q" \
                            "Fedora"
            ;;
        2)
            log "Installing Ubuntu/Debian Packages..."
            # Update package database first
            safe_sudo apt-get update -y || warn "Failed to update APT package database"
            install_packages "$DOTFILES_DIR/apt-packages.txt" \
                            "sudo apt-get install -y" \
                            "dpkg -l | grep -q" \
                            "Debian/Ubuntu"
            ;;
        3)
            log "Installing Arch Linux Packages..."
            # Update package database first
            safe_sudo pacman -Sy || warn "Failed to update Pacman package database"
            install_packages "$DOTFILES_DIR/pacman-packages.txt" \
                            "sudo pacman -S --needed --noconfirm" \
                            "pacman -Q" \
                            "Arch Linux"
            ;;
    esac
fi

# Function to clean up old backups
cleanup_old_backups() {
    log "Checking for old backup files to clean up..."
    
    # Ask user if they want to clean up old backups
    read -p "Do you want to clean up old backup files? (y/n): " CLEANUP_REPLY
    if [[ ! "$CLEANUP_REPLY" =~ ^[Yy]$ ]]; then
        log "Skipping backup cleanup."
        return
    fi
    
    # Define how many days old backups should be to be considered for cleanup
    local days_threshold=30
    read -p "Remove backups older than how many days? [default: $days_threshold]: " DAYS_INPUT
    days_threshold=${DAYS_INPUT:-$days_threshold}
    
    # Validate input
    if ! [[ "$days_threshold" =~ ^[0-9]+$ ]]; then
        warn "Invalid input: $days_threshold is not a number. Using default: 30"
        days_threshold=30
    fi
    
    # Use a more specific pattern for backup files
    log "Finding backup files older than $days_threshold days..."
    local backup_pattern="*${BACKUP_SUFFIX}*"
    local old_backups=$(find "$HOME" -path "$HOME/.*${BACKUP_SUFFIX}*" -type f -o -type d -mtime "+$days_threshold" 2>/dev/null)
    local count=0
    
    if [ -n "$old_backups" ]; then
        # Show files that will be removed and ask for confirmation
        echo "The following backup files will be removed:"
        echo "$old_backups"
        read -p "Are you sure you want to remove these files? (y/n): " CONFIRM_REMOVE
        
        if [[ "$CONFIRM_REMOVE" =~ ^[Yy]$ ]]; then
            echo "$old_backups" | while IFS= read -r backup; do
                # Additional validation to ensure we're only removing backup files
                if [[ "$backup" == *"$BACKUP_SUFFIX"* ]]; then
                    if safe_remove "$backup"; then
                        ((count++))
                        log "Removed old backup: $backup"
                    else
                        warn "Failed to remove: $backup"
                    fi
                else
                    warn "Skipping non-backup file: $backup"
                fi
            done
            log "Removed $count old backup files/directories."
        else
            log "Backup removal cancelled."
        fi
    else
        log "No old backup files found."
    fi
}

# Perform cleanup if requested
cleanup_old_backups

# Calculate execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

if [ -f "$TEMP_DIR/desktop_applied" ]; then
    DESKTOP_APPLIED=$(cat "$TEMP_DIR/desktop_applied")
    log "$DESKTOP_APPLIED settings restored. Please log out and log back in to apply all changes."
else
    log "Desktop settings restore skipped or not detected."
fi
log "Dotfiles restoration completed successfully in $EXECUTION_TIME seconds!"

# Final recommendations
echo -e "\n${BLUE}[RECOMMENDATIONS]${NC}"
echo "• Review any error messages above"
echo "• Check that all your configurations were properly restored"
echo "• Log out and log back in to apply desktop settings if applicable"
echo "• If you encounter any issues, check the backup files in $TEMP_DIR/conflicts"
