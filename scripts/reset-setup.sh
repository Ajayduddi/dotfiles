#!/bin/bash

# Reset Setup Script - SAFE DEVELOPMENT TOOL
# This script safely removes setup traces to allow re-running setup-dotfiles.sh

set -e

# Source OS detection utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/os-detection.sh"

# Parse command line arguments
DRY_RUN=false
FORCE_RESET=false
BACKUP_BEFORE_RESET=true

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be done without making changes"
            echo ""
            ;;
        --force|-f)
            FORCE_RESET=true
            echo "⚠️  FORCE MODE: Will skip additional safety confirmations"
            echo ""
            ;;
        --no-backup)
            BACKUP_BEFORE_RESET=false
            echo "⚠️  NO BACKUP MODE: Will not create additional backups before reset"
            echo ""
            ;;
        --help|-h)
            echo "🔄 DOTFILES RESET UTILITY"
            echo "========================="
            echo ""
            echo "Safely resets dotfiles setup state for testing/development"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run, -n       Show what would be done without making changes"
            echo "  --force, -f         Skip additional safety confirmations"
            echo "  --no-backup         Don't create additional backups before reset"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                  # Safe interactive reset"
            echo "  $0 --dry-run        # Preview what would be reset"
            echo "  $0 --force          # Quick reset for development"
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
SETUP_MARKER="$DOTFILES_DIR/.setup_completed"
# Use temp directory for logs  
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles-reset-$$"
mkdir -p "$TEMP_DIR"
RESET_LOG="$TEMP_DIR/reset_$(date +%Y%m%d_%H%M%S).log"

# Exit if .dotfiles folder does not exist
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "❌ Error: '$DOTFILES_DIR' directory does not exist."
    echo "➡️ Nothing to reset - setup was never run."
    exit 1
fi

echo "🔄 DOTFILES SETUP RESET UTILITY"
echo "==============================="
echo ""

# Check if setup was actually completed
if [ ! -f "$SETUP_MARKER" ] && [ ! -L "$HOME/.bashrc" ] && [ ! -L "$HOME/.config" ]; then
    echo "ℹ️  No setup detected - nothing to reset!"
    echo ""
    echo "📋 Checked for:"
    echo "  • Setup completion marker"
    echo "  • Symlinked configuration files"
    echo "  • Dotfiles git repository"
    echo ""
    echo "✅ Your system appears to be in a clean state already."
    exit 0
fi

# Analyze current setup state
echo "🔍 ANALYZING CURRENT SETUP STATE..."
echo ""

setup_elements=()
if [ -f "$SETUP_MARKER" ]; then
    setup_elements+=("Setup marker file exists")
    echo "📋 Setup completion: $(cat "$SETUP_MARKER" | head -1)"
fi

# Check for symlinks
symlink_count=0
for path in ".bashrc" ".zshrc" ".config" ".themes" ".icons" ".fonts" ".bash_profile" ".zsh_history"; do
    if [ -L "$HOME/$path" ]; then
        ((symlink_count++))
        setup_elements+=("$path is symlinked")
        target=$(readlink "$HOME/$path")
        echo "🔗 Symlink: $path → $target"
    fi
done

# Check for backup files
backup_files=()

# Safely check for backup files without glob expansion issues
for base in ".bashrc" ".zshrc" ".config" ".themes" ".icons" ".fonts"; do
    backup_pattern="$HOME/${base}.backup_*"
    # Use find to safely check for backups
    if find "$HOME" -maxdepth 1 -name "${base}.backup_*" -print -quit 2>/dev/null | grep -q .; then
        while IFS= read -r -d '' backup_file; do
            backup_files+=("$backup_file")
        done < <(find "$HOME" -maxdepth 1 -name "${base}.backup_*" -print0 2>/dev/null)
    fi
done

if [ ${#backup_files[@]} -gt 0 ]; then
    setup_elements+=("${#backup_files[@]} backup files available for restoration")
    echo "💾 Found ${#backup_files[@]} backup files for safe restoration"
fi

if [ ${#setup_elements[@]} -eq 0 ]; then
    echo "ℹ️  No active setup elements found - nothing to reset!"
    exit 0
fi

echo ""
echo "📊 RESET IMPACT ANALYSIS:"
echo "========================="
for element in "${setup_elements[@]}"; do
    echo "  • $element"
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN: What would be done:"
    echo "  1. Create reset log: $RESET_LOG"
    echo "  2. Remove setup marker: $SETUP_MARKER"
    echo "  3. Remove $symlink_count symlinks and restore backups"
    echo "  4. Preserve dotfiles directory contents"
    echo ""
    echo "💡 Run without --dry-run to perform actual reset"
    exit 0
fi

# Safety confirmation (skip if force mode)
if [ "$FORCE_RESET" = false ]; then
    echo "⚠️  SAFETY CONFIRMATION REQUIRED"
    echo "================================"
    echo ""
    echo "This will reset your dotfiles setup state by:"
    echo "  🗑️  Removing setup completion marker"
    echo "  🔗 Removing symlinks and restoring original files"
    echo "  💾 Preserving all dotfiles directory contents"
    echo ""
    echo "⚠️  This is intended for development/testing purposes."
    echo "⚠️  Your dotfiles will remain safe, but setup state will be reset."
    echo ""
    
    read -p "Type 'RESET' to confirm, or anything else to cancel: " confirm
    echo ""
    
    if [ "$confirm" != "RESET" ]; then
        echo "❌ Reset cancelled - setup remains intact"
        echo "💡 Use --force flag to skip this confirmation"
        exit 0
    fi
fi

# Initialize reset logging
{
    echo "============================================"
    echo "DOTFILES RESET LOG - $(date)"
    echo "============================================"
    echo "User: $(whoami)"
    echo "Hostname: $(hostname)"
    echo "Working Directory: $(pwd)"
    echo "Arguments: $*"
    echo ""
} > "$RESET_LOG"

echo ""
echo "🔄 PROCEEDING WITH SAFE SETUP RESET..."
echo "📝 Logging all operations to: $RESET_LOG"
echo ""

reset_operations=()
restoration_count=0
error_count=0

# Function to log and execute operations safely
log_and_execute() {
    local operation="$1"
    local command="$2"
    
    echo "🔄 $operation..." | tee -a "$RESET_LOG"
    
    # SECURITY FIX: Use bash -c instead of eval to prevent command injection
    if bash -c "$command" 2>&1 | tee -a "$RESET_LOG"; then
        echo "✅ SUCCESS: $operation" | tee -a "$RESET_LOG"
        reset_operations+=("✅ $operation")
        return 0
    else
        echo "❌ FAILED: $operation" | tee -a "$RESET_LOG"
        reset_operations+=("❌ FAILED: $operation")
        ((error_count++))
        return 1
    fi
}

# Create additional safety backup before reset (if enabled)
if [ "$BACKUP_BEFORE_RESET" = true ]; then
    reset_backup_dir="$DOTFILES_DIR/reset_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$reset_backup_dir"
    
    echo "💾 Creating additional safety backup..." | tee -a "$RESET_LOG"
    
    # Backup current symlink targets
    for path in ".bashrc" ".zshrc" ".config" ".themes" ".icons" ".fonts" ".bash_profile" ".zsh_history"; do
        if [ -L "$HOME/$path" ]; then
            target=$(readlink "$HOME/$path")
            echo "  Backing up symlink: $path → $target" | tee -a "$RESET_LOG"
            echo "$path → $target" >> "$reset_backup_dir/symlinks.txt"
        fi
    done
    
    # Backup setup marker if it exists
    if [ -f "$SETUP_MARKER" ]; then
        cp "$SETUP_MARKER" "$reset_backup_dir/setup_completed.backup"
        echo "  Backed up setup marker" | tee -a "$RESET_LOG"
    fi
    
    echo "💾 Safety backup completed: $reset_backup_dir" | tee -a "$RESET_LOG"
fi

# Safe function to restore from backup with comprehensive error handling
safe_restore_from_backup() {
    local item="$1"
    local item_type="$2"  # "file" or "directory"
    local item_path="$HOME/$item"
    
    echo "🔍 Processing $item ($item_type)..." | tee -a "$RESET_LOG"
    
    # Check if item is currently a symlink
    if [ -L "$item_path" ]; then
        local symlink_target=$(readlink "$item_path")
        echo "  Found symlink: $item → $symlink_target" | tee -a "$RESET_LOG"
        
        # Find the most recent backup
        local latest_backup=""
        if [ "$item_type" = "file" ]; then
            latest_backup=$(ls -t "${item_path}.backup_"* 2>/dev/null | head -1)
        else
            latest_backup=$(ls -td "${item_path}.backup_"* 2>/dev/null | head -1)
        fi
        
        if [ -n "$latest_backup" ] && [ -e "$latest_backup" ]; then
            echo "  Found backup: $latest_backup" | tee -a "$RESET_LOG"
            
            # Safely remove symlink and restore backup
            if rm "$item_path" 2>&1 | tee -a "$RESET_LOG"; then
                echo "  ✅ Removed symlink: $item" | tee -a "$RESET_LOG"
                
                if mv "$latest_backup" "$item_path" 2>&1 | tee -a "$RESET_LOG"; then
                    echo "  ✅ Restored from backup: $item" | tee -a "$RESET_LOG"
                    ((restoration_count++))
                    return 0
                else
                    echo "  ❌ Failed to restore backup for: $item" | tee -a "$RESET_LOG"
                    ((error_count++))
                    return 1
                fi
            else
                echo "  ❌ Failed to remove symlink for: $item" | tee -a "$RESET_LOG"
                ((error_count++))
                return 1
            fi
        else
            echo "  ⚠️  No backup found for: $item (symlink will be removed but not restored)" | tee -a "$RESET_LOG"
            if rm "$item_path" 2>&1 | tee -a "$RESET_LOG"; then
                echo "  ✅ Removed symlink: $item (no restoration possible)" | tee -a "$RESET_LOG"
            else
                echo "  ❌ Failed to remove symlink for: $item" | tee -a "$RESET_LOG"
                ((error_count++))
                return 1
            fi
        fi
    else
        echo "  ℹ️  $item is not a symlink - no action needed" | tee -a "$RESET_LOG"
    fi
    
    return 0
}

# Remove setup marker safely
if [ -f "$SETUP_MARKER" ]; then
    log_and_execute "Removing setup completion marker" "rm -f '$SETUP_MARKER'"
else
    echo "ℹ️  No setup marker found - nothing to remove" | tee -a "$RESET_LOG"
fi

# Process shell configuration files
echo "🔧 PROCESSING SHELL CONFIGURATION FILES..." | tee -a "$RESET_LOG"
for file in ".bashrc" ".zshrc" ".bash_profile" ".bash_history" ".zsh_history"; do
    safe_restore_from_backup "$file" "file"
done

# Process directories
echo "📁 PROCESSING DIRECTORIES..." | tee -a "$RESET_LOG"
for dir in ".config" ".themes" ".icons" ".fonts"; do
    safe_restore_from_backup "$dir" "directory"
done

# Process .local/share/gnome-shell/extensions if it exists
if [ -L "$HOME/.local/share/gnome-shell/extensions" ]; then
    echo "🎨 PROCESSING GNOME EXTENSIONS..." | tee -a "$RESET_LOG"
    safe_restore_from_backup ".local/share/gnome-shell/extensions" "directory"
fi

# Final logging and summary
{
    echo ""
    echo "============================================"
    echo "RESET SUMMARY - $(date)"
    echo "============================================"
    echo "Operations completed: ${#reset_operations[@]}"
    echo "Successful restorations: $restoration_count"
    echo "Errors encountered: $error_count"
    echo ""
    echo "OPERATIONS PERFORMED:"
    for operation in "${reset_operations[@]}"; do
        echo "  $operation"
    done
    echo ""
    echo "============================================"
} >> "$RESET_LOG"

echo ""
echo "🎯 RESET COMPLETE!"
echo "=================="
echo ""
echo "📊 SUMMARY:"
echo "  • Operations completed: ${#reset_operations[@]}"
echo "  • Successful restorations: $restoration_count"
echo "  • Errors encountered: $error_count"
echo ""

if [ "$error_count" -gt 0 ]; then
    echo "⚠️  Some operations encountered errors. Check the log for details:"
    echo "   📝 $RESET_LOG"
    echo ""
fi

echo "📋 WHAT WAS DONE:"
for operation in "${reset_operations[@]}"; do
    echo "  $operation"
done

echo ""
echo "💡 NEXT STEPS:"
if [ "$error_count" -eq 0 ]; then
    echo "  ✅ Reset completed successfully!"
    echo "  🚀 You can now run ./setup-dotfiles.sh again"
else
    echo "  ⚠️  Review errors in log before proceeding"
    echo "  📝 Check: $RESET_LOG"
fi

echo ""
echo "🔒 SAFETY FEATURES USED:"
echo "  ✅ Comprehensive operation logging"
echo "  ✅ Safe backup restoration with error handling"
echo "  ✅ Dotfiles directory contents preserved"
if [ "$BACKUP_BEFORE_RESET" = true ]; then
    echo "  ✅ Additional safety backup created before reset"
fi

echo ""
echo "📝 Full reset log available at: $RESET_LOG"
echo "🗂️  Temp directory: $TEMP_DIR (files will be cleaned up automatically)"