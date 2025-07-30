#!/bin/bash

set -e  # Exit on first error

DOTFILES_DIR="$HOME/.dotfiles"
CONFIG_DIR="$HOME/.config"
EXTENSIONS_DIR="$HOME/.local/share/gnome-shell/extensions"

# Create temp directory for logs
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles-restore-$$"
mkdir -p "$TEMP_DIR"

# Function to log messages
log() {
    echo -e "\e[1;32m[INFO]\e[0m $1"
}

# Function to handle errors
error_exit() {
    echo -e "\e[1;31m[ERROR]\e[0m $1"
    exit 1
}

# Function to run Git safely
dotfiles() {
    git --git-dir="$DOTFILES_DIR/.git" --work-tree="$HOME" "$@"
}

# Prompt user to select OS type
log "Select your Linux OS type:"
echo "1) Fedora (RPM)"
echo "2) Ubuntu/Debian (APT)"
echo "3) Arch Linux (Pacman)"
read -p "Enter your choice (1-3): " OS_TYPE

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
    log "Cloning Dotfiles Repository..."
    git clone --branch linux https://github.com/Ajayduddi/dotfiles.git "$DOTFILES_DIR" || error_exit "Failed to clone dotfiles repo"
fi

# Ensure the repository is valid before running Git commands
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    error_exit "Dotfiles repository is missing .git directory. Clone might have failed."
fi

# Move into the dotfiles directory before running Git commands
cd "$DOTFILES_DIR" || error_exit "Failed to access dotfiles directory."

# Ensure `linux` branch is checked out
log "Checking out dotfiles..."
dotfiles checkout linux 2>/dev/null || {
    log "Some files are blocking checkout. Forcing overwrite..."
    dotfiles checkout -f linux || error_exit "Failed to checkout dotfiles."
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
for file in .bashrc .zshrc .bash_history .bash_profile; do
    if [ -f "$DOTFILES_DIR/shell/$file" ]; then
        if [ -e "$HOME/$file" ]; then
            mv "$HOME/$file" "$HOME/${file}_backup_$(date +%s)" && log "Renamed existing $file to backup."
        fi
        ln -sf "$DOTFILES_DIR/shell/$file" "$HOME/$file" || error_exit "Failed to link $file"
    fi
done

# Restore Installed Packages
log "Restoring Installed Packages..."
case "$OS_TYPE" in
    1)
        log "Installing Fedora Packages..."
        if [[ -s "$DOTFILES_DIR/dnf-packages.txt" ]]; then
            # Filter out empty lines and comments, then install packages
            grep -v '^#' "$DOTFILES_DIR/dnf-packages.txt" | grep -v '^$' | xargs -r sudo dnf install -y || log "Failed to install Fedora packages."
        else
            log "No Fedora package list found."
        fi
        ;;
    2)
        log "Installing Ubuntu/Debian Packages..."
        if [[ -s "$DOTFILES_DIR/apt-packages.txt" ]]; then
            # Filter out empty lines and comments, then install packages
            grep -v '^#' "$DOTFILES_DIR/apt-packages.txt" | grep -v '^$' | xargs -r sudo apt-get install -y || log "Failed to install Debian packages."
        else
            log "No Debian package list found."
        fi
        ;;
    3)
        log "Installing Arch Linux Packages..."
        if [[ -s "$DOTFILES_DIR/pacman-packages.txt" ]]; then
            # Filter out empty lines and comments, then install packages
            grep -v '^#' "$DOTFILES_DIR/pacman-packages.txt" | grep -v '^$' | xargs -r sudo pacman -S --needed || log "Failed to install Arch packages."
        else
            log "No Arch package list found."
        fi
        ;;
    *)
        error_exit "Invalid OS type. Please install packages manually."
        ;;
esac

log "GNOME settings restored. Please **log out and log back in** manually to apply changes."
log "Dotfiles restoration completed successfully!"

