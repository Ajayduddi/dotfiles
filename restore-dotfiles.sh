#!/bin/bash
# Dotfiles Restoration Script
# Version: 1.1.0
# Last Updated: $(date +%Y-%m-%d)
# Description: Restores dotfiles from a repository and configures system settings

set -e  # Exit on first error
umask 077  # Restrict file permissions for security

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

# Function to log messages
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to log warnings
warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to handle errors
error_exit() {
    echo -e "${RED}[ERROR]${NC} $1"
    # Clean up temp directory on exit
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    exit 1
}

# Function to run Git safely
dotfiles() {
    git --git-dir="$DOTFILES_DIR/.git" --work-tree="$HOME" "$@"
}

# Function to clean up on exit
cleanup() {
    log "Cleaning up temporary files..."
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

# Set up trap to ensure cleanup on exit
trap cleanup EXIT INT TERM

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
        rm -rf "$DOTFILES_DIR"
    else
        log "Skipping cloning. Using existing dotfiles."
    fi
fi

# Clone Dotfiles Repo only if it was removed
if [ ! -d "$DOTFILES_DIR" ]; then
    log "Cloning Dotfiles Repository from $REPO_URL (branch: $DEFAULT_BRANCH)..."
    git clone --branch "$DEFAULT_BRANCH" "$REPO_URL" "$DOTFILES_DIR" || error_exit "Failed to clone dotfiles repo"
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
    dotfiles checkout 2>&1 | grep -E "^\s+(.+)$" | awk '{print $1}' > "$TEMP_DIR/conflict_files.txt"
    
    # Backup conflicting files before force checkout
    if [ -s "$TEMP_DIR/conflict_files.txt" ]; then
        while IFS= read -r file; do
            if [ -f "$HOME/$file" ]; then
                cp -a "$HOME/$file" "$TEMP_DIR/conflicts/" 2>/dev/null || true
                log "Backed up conflicting file: $file"
            fi
        done < "$TEMP_DIR/conflict_files.txt"
    fi
    
    # Force checkout
    dotfiles checkout -f "$DEFAULT_BRANCH" || error_exit "Failed to checkout dotfiles."
    log "Conflicting files were backed up to: $TEMP_DIR/conflicts"
}
log "Dotfiles checkout successful!"

# Restore GNOME Settings with error capture
if [ -f "$DOTFILES_DIR/gnome-settings.dconf" ]; then
    log "Restoring GNOME Settings..."
    # Attempt to load settings; capture any errors to a temporary log
    if ! sudo -u "$(logname)" dconf load / < "$DOTFILES_DIR/gnome-settings.dconf" 2> "$TEMP_DIR/dconf_error.log"; then
        log "Some settings couldn't be restored. Check $TEMP_DIR/dconf_error.log for details."
    fi
else
    log "No GNOME settings backup found."
fi

# Restore .config files safely: if .config exists, rename it; then link the backup
log "Restoring .config files..."
if [ -e "$CONFIG_DIR" ]; then
    mv "$CONFIG_DIR" "${CONFIG_DIR}_backup_$(date +%s)" && log "Renamed existing .config to backup."
fi
ln -s "$DOTFILES_DIR/.config" "$CONFIG_DIR" || error_exit "Failed to link .config folder."

# Restore GNOME Extensions safely: if extensions folder exists, rename it; then link the backup
log "Restoring GNOME Extensions..."
if [ -e "$EXTENSIONS_DIR" ]; then
    mv "$EXTENSIONS_DIR" "${EXTENSIONS_DIR}_backup_$(date +%s)" && log "Renamed existing extensions folder to backup."
fi
ln -s "$DOTFILES_DIR/.local/share/gnome-shell/extensions" "$EXTENSIONS_DIR" || error_exit "Failed to link GNOME extensions folder."

# Restore Shell Configuration Files & Create Symlinks
log "Restoring shell configuration files..."
for file in .bashrc .zshrc .bash_history .bash_profile .zsh_history .mysql_history; do
    if [ -f "$DOTFILES_DIR/shell/$file" ]; then
        if [ -e "$HOME/$file" ]; then
            mv "$HOME/$file" "$HOME/${file}_backup_$(date +%s)" && log "Renamed existing $file to backup."
        fi
        ln -sf "$DOTFILES_DIR/shell/$file" "$HOME/$file" || error_exit "Failed to link $file"
    fi
done

# Function to install packages more efficiently
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
    local packages=$(grep -v '^#' "$package_file" | grep -v '^$')
    local to_install=()
    local already_installed=0
    local total_packages=0
    
    # Check which packages need to be installed
    for pkg in $packages; do
        ((total_packages++))
        if eval "$check_cmd $pkg" &>/dev/null; then
            ((already_installed++))
            log "Package already installed: $pkg"
        else
            to_install+=("$pkg")
        fi
    done
    
    log "$already_installed out of $total_packages packages are already installed."
    
    # Install missing packages
    if [ ${#to_install[@]} -gt 0 ]; then
        log "Installing ${#to_install[@]} $os_name packages..."
        if eval "$install_cmd ${to_install[*]}"; then
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
            sudo dnf check-update -y || true
            install_packages "$DOTFILES_DIR/dnf-packages.txt" \
                            "sudo dnf install -y" \
                            "rpm -q" \
                            "Fedora"
            ;;
        2)
            log "Installing Ubuntu/Debian Packages..."
            # Update package database first
            sudo apt-get update -y || warn "Failed to update APT package database"
            install_packages "$DOTFILES_DIR/apt-packages.txt" \
                            "sudo apt-get install -y" \
                            "dpkg -l | grep -q" \
                            "Debian/Ubuntu"
            ;;
        3)
            log "Installing Arch Linux Packages..."
            # Update package database first
            sudo pacman -Sy || warn "Failed to update Pacman package database"
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
    
    # Find and remove old backup files
    log "Finding backup files older than $days_threshold days..."
    local old_backups=$(find "$HOME" -name "*$BACKUP_SUFFIX*" -type f -o -type d -mtime +$days_threshold 2>/dev/null)
    local count=0
    
    if [ -n "$old_backups" ]; then
        echo "$old_backups" | while read -r backup; do
            if rm -rf "$backup" 2>/dev/null; then
                ((count++))
                log "Removed old backup: $backup"
            else
                warn "Failed to remove: $backup"
            fi
        done
        log "Removed $count old backup files/directories."
    else
        log "No old backup files found."
    fi
}

# Perform cleanup if requested
cleanup_old_backups

# Calculate execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

log "GNOME settings restored. Please **log out and log back in** manually to apply changes."
log "Dotfiles restoration completed successfully in $EXECUTION_TIME seconds!"

# Final recommendations
echo -e "\n${BLUE}[RECOMMENDATIONS]${NC}"
echo "• Review any error messages above"
echo "• Check that all your configurations were properly restored"
echo "• Log out and log back in to apply all GNOME settings"
echo "• If you encounter any issues, check the backup files in $TEMP_DIR/conflicts"

