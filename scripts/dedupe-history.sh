#!/bin/bash

# HISTORY DEDUPLICATOR - Shell history deduplication tool
# Removes duplicate entries from shell history files while preserving chronological order

set -e

# Parse command line arguments  
DRY_RUN=false
BACKUP_ORIGINAL=true

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be deduplicated without making changes"
            echo ""
            ;;
        --no-backup)
            BACKUP_ORIGINAL=false
            echo "⚠️  NO BACKUP MODE: Will not create backup of original files"
            echo ""
            ;;
        --help|-h)
            echo "🔄 SHELL HISTORY DEDUPLICATOR"
            echo "============================="
            echo ""
            echo "Removes duplicate entries from shell history files"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run, -n       Show what would be deduplicated without making changes"
            echo "  --no-backup         Don't create backup of original files"  
            echo "  --help, -h          Show this help message"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                  # Deduplicate history with backup"
            echo "  $0 --dry-run        # Preview what would be deduplicated"
            echo "  $0 --no-backup      # Deduplicate without creating backups"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "💡 Use --help for usage information"
            exit 1
            ;;
    esac
done

# Create temp directory for processed files
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles-dedup-$$"
mkdir -p "$TEMP_DIR"
echo "🔄 History Deduplication - temp files in: $TEMP_DIR"

# Function to deduplicate history while preserving chronological order
deduplicate_history() {
    local input_file="$1"
    local temp_file="$TEMP_DIR/$(basename "$input_file").dedup"
    
    echo "🔄 Deduplicating $(basename "$input_file")..."
    
    # For zsh history format (: timestamp:0;command)
    if [[ "$input_file" == *"zsh_history"* ]]; then
        # Use awk to keep only the last occurrence of each command
        awk -F';' '
        {
            cmd = substr($0, index($0, ";") + 1)  # Extract command part
            if (cmd != "") {
                # Store line with command as key, overwriting previous occurrences
                lines[cmd] = $0
                order[NR] = cmd
            }
        }
        END {
            # Print in original order, but only last occurrence of each command
            seen_cmds=""
            for (i = NR; i >= 1; i--) {
                cmd = order[i]
                if (cmd in lines && index(seen_cmds, cmd "|") == 0) {
                    print lines[cmd]
                    seen_cmds = seen_cmds cmd "|"
                }
            }
        }' "$input_file" | tac > "$temp_file"
    else
        # For bash history (simple line format)
        tac "$input_file" | awk '!seen[$0]++' | tac > "$temp_file"
    fi
    
    # Count results
    local original_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")
    local dedup_lines=$(wc -l < "$temp_file" 2>/dev/null || echo "0") 
    local removed_duplicates=$((original_lines - dedup_lines))
    
    echo "  📊 Original lines: $original_lines"
    echo "  📊 After deduplication: $dedup_lines"
    echo "  📊 Duplicates removed: $removed_duplicates"
    
    if [ "$removed_duplicates" -gt 0 ]; then
        local reduction_percent=$(echo "scale=1; $removed_duplicates * 100 / $original_lines" | bc -l 2>/dev/null || echo "?")
        echo "  📊 Size reduction: ${reduction_percent}%"
        
        if [ "$DRY_RUN" = false ]; then
            # Create backup if requested
            if [ "$BACKUP_ORIGINAL" = true ]; then
                local backup_file="${input_file}.backup_$(date +%s)"
                cp "$input_file" "$backup_file"
                echo "  💾 Backup created: $backup_file"
            fi
            
            # Replace original with deduplicated version
            mv "$temp_file" "$input_file"
            echo "  ✅ File deduplicated and updated"
        else
            echo "  🔍 DRY RUN: Would remove $removed_duplicates duplicate lines"
        fi
    else
        echo "  ✅ No duplicates found"
        rm -f "$temp_file"
    fi
    
    echo ""
}

echo "🔄 SHELL HISTORY DEDUPLICATOR"
echo "============================="
echo ""

# Find history files to process
history_files=(
    "$HOME/.bash_history"
    "$HOME/.zsh_history"
    "$HOME/.dotfiles/shell/.bash_history"
    "$HOME/.dotfiles/shell/.zsh_history"
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
    echo "🔍 DRY RUN: Analyzing duplicates without making changes..."
    echo ""
fi

# Process each history file
total_removed=0
for file in "${files_found[@]}"; do
    deduplicate_history "$file"
done

echo "✅ DEDUPLICATION COMPLETE!"
echo "=========================="
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
echo "💡 RECOMMENDATIONS:"
echo "   - Run this tool periodically to maintain clean history"
echo "   - Use 'ignoredups' in HISTCONTROL to prevent future duplicates"
echo "   - Consider setting HISTSIZE and HISTFILESIZE limits"