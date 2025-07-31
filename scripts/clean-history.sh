#!/bin/bash

# HISTORY CLEANER - Secure shell history sanitization tool
# Removes sensitive information from shell history files

set -e

# Parse command line arguments
DRY_RUN=false
BACKUP_ORIGINAL=true

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be cleaned without making changes"
            echo ""
            ;;
        --no-backup)
            BACKUP_ORIGINAL=false
            echo "⚠️  NO BACKUP MODE: Will not create backup of original files"
            echo ""
            ;;
        --help|-h)
            echo "🧹 SHELL HISTORY CLEANER"
            echo "========================"
            echo ""
            echo "Removes sensitive information from shell history files"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run, -n       Show what would be cleaned without making changes"
            echo "  --no-backup         Don't create backup of original files"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                  # Clean history with backup"
            echo "  $0 --dry-run        # Preview what would be cleaned"
            echo "  $0 --no-backup      # Clean without creating backups"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "💡 Use --help for usage information"
            exit 1
            ;;
    esac
done

# Create temp directory for cleaned files
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles-clean-$$"
mkdir -p "$TEMP_DIR"
echo "🧹 History Cleaning - temp files in: $TEMP_DIR"

# Function to securely clean history files
clean_history_file() {
    local input_file="$1"
    local output_file="$TEMP_DIR/$(basename "$input_file").cleaned"
    
    # Comprehensive sensitive patterns for history files
    local sensitive_patterns=(
        # Password patterns
        "mysql.*-p[^[:space:]]*[[:alnum:]]"
        "psql.*password"
        "sudo.*password"  # SAFE: Security exclusion pattern
        "passwd.*"
        # API keys and tokens
        "export.*[A-Z_]*KEY[[:space:]]*="
        "export.*[A-Z_]*TOKEN[[:space:]]*="
        "export.*[A-Z_]*SECRET[[:space:]]*="
        "export.*[A-Z_]*PASS[[:space:]]*="
        # Authentication commands
        "curl.*-H.*[Aa]uthorization"
        "curl.*-u.*:"
        "wget.*--header.*[Aa]uthorization"
        "git.*clone.*://.*:.*@"
        "docker.*login"
        "npm.*set.*registry.*token"
        "ssh.*-i.*key"
        "ssh.*pass"
        # Database connections
        "mongo.*://.*:.*@"
        "redis.*AUTH"
        # Cloud credentials
        "aws.*configure"
        "gcloud.*auth"
        "kubectl.*token"
        # Generic patterns
        ".*password.*="
        ".*secret.*="
        ".*token.*="
        ".*credential.*="
        ".*key.*="
    )
    
    echo "🔍 Cleaning: $input_file"
    
    local original_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")
    local removed_lines=0
    
    # Create cleaned version
    cp "$input_file" "$output_file"
    
    # Remove sensitive patterns
    for pattern in "${sensitive_patterns[@]}"; do
        if grep -q "$pattern" "$output_file" 2>/dev/null; then
            local matches=$(grep -c "$pattern" "$output_file" 2>/dev/null || echo "0")
            if [ "$matches" -gt 0 ]; then
                echo "  🗑️  Removing $matches entries matching: ${pattern:0:30}..."
                grep -v "$pattern" "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
                ((removed_lines += matches))
            fi
        fi
    done
    
    local cleaned_lines=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    local actual_removed=$((original_lines - cleaned_lines))
    
    echo "  📊 Original: $original_lines lines"
    echo "  📊 Cleaned: $cleaned_lines lines" 
    echo "  📊 Removed: $actual_removed lines"
    
    if [ "$actual_removed" -gt 0 ]; then
        local removal_percent=$(echo "scale=1; $actual_removed * 100 / $original_lines" | bc -l 2>/dev/null || echo "?")
        echo "  📊 Reduction: ${removal_percent}%"
        
        if [ "$DRY_RUN" = false ]; then
            # Create backup if requested
            if [ "$BACKUP_ORIGINAL" = true ]; then
                local backup_file="${input_file}.backup_$(date +%s)"
                cp "$input_file" "$backup_file"
                echo "  💾 Backup created: $backup_file"
            fi
            
            # Replace original with cleaned version
            mv "$output_file" "$input_file"
            echo "  ✅ File cleaned and updated"
        else
            echo "  🔍 DRY RUN: Would remove $actual_removed lines"
        fi
    else
        echo "  ✅ No sensitive content found"
        rm -f "$output_file"
    fi
    
    echo ""
}

echo "🧹 SHELL HISTORY CLEANER"
echo "========================"
echo ""

# Find history files to clean
history_files=(
    "$HOME/.bash_history"
    "$HOME/.zsh_history"
    "$HOME/.mysql_history"
    "$HOME/.dotfiles/shell/.bash_history" 
    "$HOME/.dotfiles/shell/.zsh_history"
    "$HOME/.dotfiles/shell/.mysql_history"
)

files_found=()
for file in "${history_files[@]}"; do
    if [ -f "$file" ]; then
        files_found+=("$file")
    fi
done

if [ ${#files_found[@]} -eq 0 ]; then
    echo "❌ No history files found!"
    echo ""
    echo "Checked locations:"
    for file in "${history_files[@]}"; do
        echo "  • $file"
    done
    exit 1
fi

echo "📋 Found ${#files_found[@]} history files to process:"
for file in "${files_found[@]}"; do
    echo "  • $file"
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN: Analyzing what would be cleaned..."
    echo ""
fi

# Process each history file
total_removed=0
for file in "${files_found[@]}"; do
    clean_history_file "$file"
done

echo "✅ CLEANING COMPLETE!"
echo "===================="
echo ""
echo "📊 SUMMARY:"
echo "  • Files processed: ${#files_found[@]}"
if [ "$BACKUP_ORIGINAL" = true ] && [ "$DRY_RUN" = false ]; then
    echo "  • Backups created: ${#files_found[@]}"
fi
if [ "$DRY_RUN" = true ]; then
    echo "  • This was a dry run - no files were modified"
fi

echo ""
echo "🗂️  Temp files saved in: $TEMP_DIR"
echo ""
echo "💡 SECURITY RECOMMENDATIONS:"
echo "   - Review removed content in temp files before deletion"
echo "   - Consider using password managers instead of command line passwords"
echo "   - Use environment variables for API keys instead of inline values"