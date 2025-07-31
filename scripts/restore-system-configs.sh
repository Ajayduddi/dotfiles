#!/bin/bash

# System Configuration Restoration Script
# Restores system-wide configurations backed up by system-config-backup.sh

set -e

DOTFILES_DIR="$HOME/.dotfiles"
SYSTEM_BACKUP_DIR="$DOTFILES_DIR/system-configs"
DRY_RUN=false

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be restored without making changes"
            echo ""
            ;;
        --help)
            echo "System Configuration Restoration Tool"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be restored without making changes"
            echo "  --help       Show this help message"
            echo ""
            echo "This script restores system configurations backed up by system-config-backup.sh"
            echo "It requires sudo privileges to restore files to system locations."
            exit 0
            ;;
    esac
done

echo "🔄 SYSTEM CONFIGURATION RESTORATION TOOL"
echo "========================================"
echo ""

# Check if backup directory exists
if [ ! -d "$SYSTEM_BACKUP_DIR" ]; then
    echo "❌ System backup directory not found: $SYSTEM_BACKUP_DIR"
    echo ""
    echo "To create a system backup, run:"
    echo "  ./system-config-backup.sh --backup"
    exit 1
fi

echo "📁 Restoring from: $SYSTEM_BACKUP_DIR"
echo ""

# Function to safely restore with sudo
safe_restore() {
    local src="$1"
    local dest="$2"
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Restore $src -> $dest"
        return 0
    fi
    
    # Create destination directory with sudo if needed
    if ! sudo mkdir -p "$(dirname "$dest")" 2>/dev/null; then
        echo "❌ Failed to create directory: $(dirname "$dest")"
        return 1
    fi
    
    # Backup existing file if it exists
    if [ -f "$dest" ]; then
        local backup_name="${dest}.backup_$(date +%s)"
        if sudo cp "$dest" "$backup_name" 2>/dev/null; then
            echo "📦 Backed up existing: $dest -> $backup_name"
        fi
    fi
    
    # Restore the file
    if sudo cp "$src" "$dest" 2>/dev/null; then
        echo "✅ Restored: $dest"
        return 0
    else
        echo "❌ Failed to restore: $dest"
        return 1
    fi
}

# Count files to restore
total_files=$(find "$SYSTEM_BACKUP_DIR" -type f | wc -l)
echo "📊 Found $total_files configuration files to restore"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 PREVIEW - Files that would be restored:"
    echo "=========================================="
fi

restored_files=0
failed_files=0

# Restore all backed up files
find "$SYSTEM_BACKUP_DIR" -type f | sort | while read -r backup_file; do
    # Calculate original system path
    rel_path="${backup_file#$SYSTEM_BACKUP_DIR/}"
    system_path="/$rel_path"
    
    if [ "$DRY_RUN" = false ]; then
        echo "🔄 Restoring: $system_path"
    fi
    
    if safe_restore "$backup_file" "$system_path"; then
        ((restored_files++))
    else
        ((failed_files++))
    fi
done

echo ""
echo "📊 RESTORATION SUMMARY:"
echo "======================="
echo "Total files: $total_files"
echo "Successfully restored: $restored_files"
echo "Failed: $failed_files"
echo ""

if [ "$DRY_RUN" = false ] && [ $restored_files -gt 0 ]; then
    echo "⚠️  IMPORTANT POST-RESTORATION STEPS:"
    echo "====================================="
    echo ""
    echo "1. 🔄 Restart affected services:"
    echo "   sudo systemctl restart httpd nginx mysql postgresql redis"
    echo ""
    echo "2. 🔍 Verify configurations:"
    echo "   sudo httpd -t                    # Test Apache config"
    echo "   sudo nginx -t                   # Test Nginx config"
    echo "   sudo systemctl status httpd     # Check Apache status"
    echo ""
    echo "3. 🔥 Check firewall rules if services don't start:"
    echo "   sudo firewall-cmd --list-all"
    echo "   sudo firewall-cmd --add-service=http --permanent"
    echo "   sudo firewall-cmd --add-service=https --permanent"
    echo "   sudo firewall-cmd --reload"
    echo ""
    echo "4. 📝 Review restored configurations for any needed adjustments"
fi

echo ""
echo "✅ Restoration completed!"