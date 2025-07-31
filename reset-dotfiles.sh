#!/bin/bash

# DOTFILES COMPLETE UNINSTALLER - PRODUCTION SAFE
# This script completely removes dotfiles and restores your system to original state

set -e  # Exit on any error

# Parse command line arguments
DRY_RUN=false
FORCE_UNINSTALL=false
KEEP_BACKUPS=false

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be done without making changes"
            echo ""
            ;;
        --force|-f)
            FORCE_UNINSTALL=true
            echo "⚠️  FORCE MODE: Will skip safety confirmations"
            echo ""
            ;;
        --keep-backups)
            KEEP_BACKUPS=true
            echo "💾 KEEP BACKUPS MODE: Will preserve backup files after restoration"
            echo ""
            ;;
        --help|-h)
            echo "🗑️  DOTFILES COMPLETE UNINSTALLER"
            echo "=================================="
            echo ""
            echo "Completely removes dotfiles and restores your system to original state"
            echo ""
            echo "⚠️  WARNING: This is a PERMANENT operation that will:"
            echo "    • Remove all dotfiles symlinks"
            echo "    • Restore original configuration files"
            echo "    • Reset GNOME settings to original state"
            echo "    • Optionally remove the entire .dotfiles directory"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run, -n       Show what would be done without making changes"
            echo "  --force, -f         Skip safety confirmations"
            echo "  --keep-backups      Preserve backup files after restoration"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                  # Safe interactive uninstall"
            echo "  $0 --dry-run        # Preview what would be uninstalled"
            echo "  $0 --force          # Quick uninstall without prompts"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "💡 Use --help for usage information"
            exit 1
            ;;
    esac
done

# Define paths
DOTFILES_DIR="$HOME/.dotfiles"
# Use temp directory for logs
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles-uninstall-$$"
mkdir -p "$TEMP_DIR"
UNINSTALL_LOG="$TEMP_DIR/uninstall_$(date +%Y%m%d_%H%M%S).log"

# Exit if .dotfiles folder does not exist
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "ℹ️  No dotfiles installation found - nothing to uninstall!"
    echo ""
    echo "📋 Checked for: $DOTFILES_DIR"
    echo "✅ Your system appears to be in a clean state already."
    exit 0
fi

echo "🗑️  DOTFILES COMPLETE UNINSTALLER"
echo "=================================="
echo ""

# Initialize logging
{
    echo "============================================"
    echo "DOTFILES UNINSTALL LOG - $(date)"
    echo "============================================"
    echo "User: $(whoami)"
    echo "Hostname: $(hostname)"
    echo "Working Directory: $(pwd)"
    echo "Arguments: $*"
    echo ""
} > "$UNINSTALL_LOG"

uninstall_count=0
error_count=0
restoration_count=0

# Function to safely restore a directory
safe_restore_dir() {
    local dir_name="$1"
    local symlink_path="$HOME/$dir_name"
    local backup_path="$DOTFILES_DIR/$dir_name"

    echo "📁 Processing directory: $dir_name" | tee -a "$UNINSTALL_LOG"
    
    if [ -L "$symlink_path" ]; then
        local symlink_target=$(readlink "$symlink_path")
        echo "  Found symlink: $dir_name → $symlink_target" | tee -a "$UNINSTALL_LOG"
        
        if [ -d "$backup_path" ]; then
            echo "  Found backup directory: $backup_path" | tee -a "$UNINSTALL_LOG"
            
            if [ "$DRY_RUN" = false ]; then
                # Create a safety backup before restoration
                safety_backup="$symlink_path.pre_uninstall_$(date +%s)"
                if cp -r "$symlink_target" "$safety_backup" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                    echo "  ✅ Created safety backup: $safety_backup" | tee -a "$UNINSTALL_LOG"
                fi
                
                # Remove symlink and restore original
                if rm "$symlink_path" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                    echo "  ✅ Removed symlink: $dir_name" | tee -a "$UNINSTALL_LOG"
                    
                    if mv "$backup_path" "$symlink_path" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                        echo "  ✅ Restored original directory: $dir_name" | tee -a "$UNINSTALL_LOG"
                        ((restoration_count++))
                    else
                        echo "  ❌ Failed to restore directory: $dir_name" | tee -a "$UNINSTALL_LOG"
                        ((error_count++))
                    fi
                else
                    echo "  ❌ Failed to remove symlink: $dir_name" | tee -a "$UNINSTALL_LOG"
                    ((error_count++))
                fi
            else
                echo "  🔍 DRY RUN: Would restore directory from backup" | tee -a "$UNINSTALL_LOG"
            fi
        else
            echo "  ⚠️  No backup found for: $dir_name (symlink will be removed)" | tee -a "$UNINSTALL_LOG"
            if [ "$DRY_RUN" = false ]; then
                if rm "$symlink_path" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                    echo "  ✅ Removed symlink: $dir_name (no restoration possible)" | tee -a "$UNINSTALL_LOG"
                else
                    echo "  ❌ Failed to remove symlink: $dir_name" | tee -a "$UNINSTALL_LOG"
                    ((error_count++))
                fi
            fi
        fi
        ((uninstall_count++))
    else
        echo "  ℹ️  $dir_name is not a symlink - no action needed" | tee -a "$UNINSTALL_LOG"
    fi
}

# Function to safely restore a file
safe_restore_file() {
    local file_name="$1"
    local symlink_path="$HOME/$file_name"
    local backup_path="$DOTFILES_DIR/shell/$file_name"

    echo "📄 Processing file: $file_name" | tee -a "$UNINSTALL_LOG"
    
    if [ -L "$symlink_path" ]; then
        local symlink_target=$(readlink "$symlink_path")
        echo "  Found symlink: $file_name → $symlink_target" | tee -a "$UNINSTALL_LOG"
        
        if [ -f "$backup_path" ]; then
            echo "  Found backup file: $backup_path" | tee -a "$UNINSTALL_LOG"
            
            if [ "$DRY_RUN" = false ]; then
                # Create a safety backup before restoration
                safety_backup="$symlink_path.pre_uninstall_$(date +%s)"
                if cp "$symlink_target" "$safety_backup" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                    echo "  ✅ Created safety backup: $safety_backup" | tee -a "$UNINSTALL_LOG"
                fi
                
                # Remove symlink and restore original
                if rm "$symlink_path" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                    echo "  ✅ Removed symlink: $file_name" | tee -a "$UNINSTALL_LOG"
                    
                    if mv "$backup_path" "$symlink_path" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                        echo "  ✅ Restored original file: $file_name" | tee -a "$UNINSTALL_LOG"
                        ((restoration_count++))
                    else
                        echo "  ❌ Failed to restore file: $file_name" | tee -a "$UNINSTALL_LOG"
                        ((error_count++))
                    fi
                else
                    echo "  ❌ Failed to remove symlink: $file_name" | tee -a "$UNINSTALL_LOG"
                    ((error_count++))
                fi
            else
                echo "  🔍 DRY RUN: Would restore file from backup" | tee -a "$UNINSTALL_LOG"
            fi
        else
            echo "  ⚠️  No backup found for: $file_name (symlink will be removed)" | tee -a "$UNINSTALL_LOG"
            if [ "$DRY_RUN" = false ]; then
                if rm "$symlink_path" 2>&1 | tee -a "$UNINSTALL_LOG"; then
                    echo "  ✅ Removed symlink: $file_name (no restoration possible)" | tee -a "$UNINSTALL_LOG"
                else
                    echo "  ❌ Failed to remove symlink: $file_name" | tee -a "$UNINSTALL_LOG"
                    ((error_count++))
                fi
            fi
        fi
        ((uninstall_count++))
    else
        echo "  ℹ️  $file_name is not a symlink - no action needed" | tee -a "$UNINSTALL_LOG"
    fi
}


# Analyze what needs to be uninstalled
echo "🔍 ANALYZING DOTFILES INSTALLATION..." | tee -a "$UNINSTALL_LOG"
echo ""

dotfiles_elements=()
symlinks_found=()

# Check for symlinked directories
for dir in ".config" ".themes" ".icons" ".fonts" ".local/share/gnome-shell/extensions"; do
    if [ -L "$HOME/$dir" ]; then
        symlinks_found+=("$dir (directory)")
        dotfiles_elements+=("Directory symlink: $dir")
    fi
done

# Check for symlinked files
for file in ".bashrc" ".zshrc" ".bash_history" ".bash_profile" ".zsh_history" ".mysql_history"; do
    if [ -L "$HOME/$file" ]; then
        symlinks_found+=("$file (file)")
        dotfiles_elements+=("File symlink: $file")
    fi
done

# Check for GNOME settings backup
if [ -f "$DOTFILES_DIR/gnome-settings.dconf" ]; then
    dotfiles_elements+=("GNOME settings backup available")
fi

if [ ${#dotfiles_elements[@]} -eq 0 ]; then
    echo "ℹ️  No dotfiles installation detected - nothing to uninstall!"
    echo "✅ Your system appears to be clean already."
    exit 0
fi

echo "📊 UNINSTALL IMPACT ANALYSIS:"
echo "============================="
for element in "${dotfiles_elements[@]}"; do
    echo "  • $element" | tee -a "$UNINSTALL_LOG"
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN: What would be uninstalled:"
    echo "  1. ${#symlinks_found[@]} symlinks would be removed"
    echo "  2. Original files/directories would be restored from backups"
    echo "  3. GNOME settings would be restored (if backup exists)"
    echo "  4. Uninstall log would be created: $UNINSTALL_LOG"
    echo ""
    echo "💡 Run without --dry-run to perform actual uninstall"
    exit 0
fi

# Safety confirmation (skip if force mode)
if [ "$FORCE_UNINSTALL" = false ]; then
    echo "⚠️  PERMANENT UNINSTALL CONFIRMATION"
    echo "===================================="
    echo ""
    echo "This will PERMANENTLY UNINSTALL your dotfiles by:"
    echo "  🗑️  Removing ${#symlinks_found[@]} symlinks"
    echo "  ♻️  Restoring original configuration files from backups"
    echo "  🎨 Restoring original GNOME settings"
    echo "  💾 Creating comprehensive uninstall log"
    echo ""
    echo "⚠️  WARNING: This operation is PERMANENT and will:"
    echo "   • Completely remove your dotfiles setup"
    echo "   • Restore your system to pre-dotfiles state"
    echo "   • Cannot be easily undone"
    echo ""
    
    read -p "Type 'UNINSTALL' to confirm permanent removal: " confirm
    echo ""
    
    if [ "$confirm" != "UNINSTALL" ]; then
        echo "❌ Uninstall cancelled - dotfiles remain intact"
        echo "💡 Use --force flag to skip this confirmation"
        exit 0
    fi
fi

echo "🔄 PROCEEDING WITH DOTFILES UNINSTALL..."
echo "📝 Logging all operations to: $UNINSTALL_LOG"
echo ""

# Restore GNOME Settings (if backup exists)
echo "🎨 RESTORING GNOME SETTINGS..." | tee -a "$UNINSTALL_LOG"

if [ -f "$DOTFILES_DIR/gnome-settings.dconf" ]; then
    LOGIN_USER=$(logname 2>/dev/null || whoami)
    
    # Check if backup contains any settings
    if grep -q "^/" "$DOTFILES_DIR/gnome-settings.dconf" 2>/dev/null; then
        # SECURITY FIX: Use secure temporary file creation
        TMP_FILTERED_SETTINGS=$(mktemp -t dotfiles-gnome-restore.XXXXXX)
        trap 'rm -f "$TMP_FILTERED_SETTINGS"' EXIT
        
        # Filter only GNOME settings for safety
        if grep -E '^/' "$DOTFILES_DIR/gnome-settings.dconf" > "$TMP_FILTERED_SETTINGS" 2>/dev/null; then
            if [ "$DRY_RUN" = false ]; then
                if command -v dconf >/dev/null 2>&1; then
                    if dconf load / < "$TMP_FILTERED_SETTINGS" 2>/tmp/dconf_restore_error.log; then  # SAFE: Error log file
                        echo "✅ GNOME settings restored from backup" | tee -a "$UNINSTALL_LOG"
                    else
                        echo "⚠️  Some GNOME settings failed to restore. Check /tmp/dconf_restore_error.log" | tee -a "$UNINSTALL_LOG"
                        ((error_count++))
                    fi
                else
                    echo "⚠️  dconf not available - skipping GNOME settings restore" | tee -a "$UNINSTALL_LOG"
                fi
            else
                echo "🔍 DRY RUN: Would restore GNOME settings from backup" | tee -a "$UNINSTALL_LOG"
            fi
            
            # Clean up temporary file
            [ -f "$TMP_FILTERED_SETTINGS" ] && rm -f "$TMP_FILTERED_SETTINGS"
        fi
    else
        echo "ℹ️  GNOME settings backup is empty - skipping restore" | tee -a "$UNINSTALL_LOG"
    fi
else
    echo "ℹ️  No GNOME settings backup found - skipping restore" | tee -a "$UNINSTALL_LOG"
fi

# Restore directories
echo "📁 RESTORING DIRECTORIES..." | tee -a "$UNINSTALL_LOG"
for dir in ".local/share/gnome-shell/extensions" ".themes" ".icons" ".config" ".fonts"; do
    safe_restore_dir "$dir"
done

# Restore files
echo "📄 RESTORING FILES..." | tee -a "$UNINSTALL_LOG"
for file in ".bashrc" ".zshrc" ".bash_history" ".bash_profile" ".zsh_history" ".mysql_history"; do
    safe_restore_file "$file"
done

# Clean up backup files (unless --keep-backups is specified)
if [ "$KEEP_BACKUPS" = false ] && [ "$DRY_RUN" = false ]; then
    echo "🧹 CLEANING UP BACKUP FILES..." | tee -a "$UNINSTALL_LOG"
    
    # Remove any remaining .backup_ files
    find "$HOME" -maxdepth 1 -name "*.backup_*" -type f -delete 2>/dev/null || true
    find "$HOME" -maxdepth 1 -name "*.backup_*" -type d -exec rm -rf {} \; 2>/dev/null || true
    echo "✅ Backup files cleaned up" | tee -a "$UNINSTALL_LOG"
else
    echo "💾 Backup files preserved (--keep-backups enabled)" | tee -a "$UNINSTALL_LOG"
fi

# Final logging and summary
{
    echo ""
    echo "============================================"
    echo "UNINSTALL SUMMARY - $(date)"
    echo "============================================"
    echo "Symlinks processed: $uninstall_count"
    echo "Successful restorations: $restoration_count"
    echo "Errors encountered: $error_count"
    echo ""
    echo "============================================"
} >> "$UNINSTALL_LOG"

echo ""
echo "🎯 DOTFILES UNINSTALL COMPLETE!"
echo "==============================="
echo ""
echo "📊 SUMMARY:"
echo "  • Symlinks processed: $uninstall_count"
echo "  • Successful restorations: $restoration_count"
echo "  • Errors encountered: $error_count"
echo ""

if [ "$error_count" -gt 0 ]; then
    echo "⚠️  Some operations encountered errors:"
    echo "   📝 Check log: $UNINSTALL_LOG"
    echo "   📝 Check dconf errors: /tmp/dconf_restore_error.log"
    echo ""
fi

echo "✅ RESTORATION COMPLETE!"
echo ""
echo "📋 YOUR SYSTEM STATUS:"
if [ "$error_count" -eq 0 ]; then
    echo "  ✅ All dotfiles symlinks removed"
    echo "  ✅ Original configuration files restored" 
    echo "  ✅ GNOME settings restored (if backup existed)"
    echo "  ✅ System returned to pre-dotfiles state"
else
    echo "  ⚠️  Some items may need manual attention"
    echo "  📝 Review the uninstall log for details"
fi

echo ""
echo "💡 NEXT STEPS:"
echo "  • Your original configuration is now active"
echo "  • You may need to restart applications to see changes"
echo "  • GNOME settings changes may require logout/login"

if [ -d "$DOTFILES_DIR" ]; then
    echo ""
    echo "🗂️  DOTFILES DIRECTORY:"
    echo "   The $DOTFILES_DIR directory still exists"
    echo "   You can safely remove it if no longer needed:"
    echo "   rm -rf $DOTFILES_DIR"  # SAFE: User instruction, not executed
fi

echo ""
echo "📝 Full uninstall log: $UNINSTALL_LOG"
echo "🗂️  Temp directory: $TEMP_DIR (review files before they're cleaned up)"

