#!/bin/bash

# HISTORY ANALYZER - Comprehensive shell history analysis tool
# Analyzes shell history files for patterns, security issues, and usage statistics

set -e

# Create temp directory for analysis
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles-history-$$"
mkdir -p "$TEMP_DIR"
echo "📊 History Analysis - temp files in: $TEMP_DIR"

# Function to analyze a history file
analyze_history_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo "⚠️ File not found: $file"
        return 1
    fi
    
    echo "🔍 Analyzing: $file"
    echo "=================="
    
    local file_size=$(du -h "$file" | cut -f1)
    local line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
    echo "📏 Lines: $line_count"
    echo "💾 File size: $file_size"
    
    # Extract commands (handle zsh format)
    if [[ "$file" == *"zsh_history"* ]]; then
        # SECURITY FIX: Use secure temporary file creation
        local commands_file=$(mktemp -t dotfiles-commands.XXXXXX -p "$TEMP_DIR")
        cut -d';' -f2- "$file" 2>/dev/null > "$commands_file"
    else
        local commands_file="$file"
    fi
    
    if [ -s "$commands_file" ]; then
        echo ""
        echo "📈 TOP COMMANDS:"
        echo "================"
        # Get top 10 most used commands
        awk '{print $1}' "$commands_file" | sort | uniq -c | sort -nr | head -10 | \
        while read count cmd; do
            printf "  %3d: %s\n" "$count" "$cmd"
        done
        
        echo ""
        echo "📊 COMMAND CATEGORIES:"
        echo "======================"
        echo "Git commands: $(grep -c "^git" "$commands_file" 2>/dev/null || echo 0)"
        echo "File operations: $(grep -c -E "^(ls|cd|cp|mv|rm|mkdir|find)" "$commands_file" 2>/dev/null || echo 0)"
        echo "System commands: $(grep -c -E "^(ps|top|htop|free|df|du)" "$commands_file" 2>/dev/null || echo 0)"
        echo "Network commands: $(grep -c -E "^(ssh|scp|curl|wget|ping)" "$commands_file" 2>/dev/null || echo 0)"
        echo "Package management: $(grep -c -E "^(sudo )?(dnf|apt|yum|pacman)" "$commands_file" 2>/dev/null || echo 0)"
        echo "Text processing: $(grep -c -E "^(grep|sed|awk|cut|sort|uniq)" "$commands_file" 2>/dev/null || echo 0)"
        
        echo ""
        echo "🔒 SECURITY ANALYSIS:"
        echo "===================="
        local sensitive_count=$(grep -c -i -E "(password|secret|token|key|auth)" "$commands_file" 2>/dev/null || echo 0)
        if [ "$sensitive_count" -gt 0 ]; then
            echo "⚠️ Found $sensitive_count potentially sensitive commands"
            echo "💡 Consider running clean-history.sh to remove sensitive entries"
        else
            echo "✅ No obvious sensitive commands found"
        fi
        
        # Check for duplicate commands
        local total_commands=$(wc -l < "$commands_file" 2>/dev/null || echo 0)
        local unique_commands=$(sort "$commands_file" | uniq | wc -l 2>/dev/null || echo 0)
        local duplicates=$((total_commands - unique_commands))
        
        echo ""
        echo "🔄 DUPLICATION ANALYSIS:" 
        echo "========================"
        echo "Total commands: $total_commands"
        echo "Unique commands: $unique_commands"
        echo "Duplicates: $duplicates"
        if [ "$duplicates" -gt 0 ]; then
            local duplicate_percent=$(echo "scale=1; $duplicates * 100 / $total_commands" | bc -l 2>/dev/null || echo "?")
            echo "Duplication rate: ${duplicate_percent}%"
            echo "💡 Consider running dedupe-history.sh to remove duplicates"
        fi
    else
        echo "⚠️ No commands found in history file"
    fi
    
    echo ""
}

# Main analysis
echo "📊 SHELL HISTORY ANALYSIS"
echo "=========================="
echo ""

# Check common history file locations
history_files=(
    "$HOME/.bash_history"
    "$HOME/.zsh_history"
    "$HOME/.mysql_history"
    "$HOME/.dotfiles/shell/.bash_history"
    "$HOME/.dotfiles/shell/.zsh_history"
    "$HOME/.dotfiles/shell/.mysql_history"
)

files_analyzed=0
for file in "${history_files[@]}"; do
    if [ -f "$file" ]; then
        analyze_history_file "$file"
        ((files_analyzed++))
    fi
done

if [ "$files_analyzed" -eq 0 ]; then
    echo "❌ No history files found!"
    echo ""
    echo "Checked locations:"
    for file in "${history_files[@]}"; do
        echo "  • $file"
    done
else
    echo "✅ Analysis complete! Analyzed $files_analyzed history files"
fi

echo ""
echo "🗂️  Analysis files saved in: $TEMP_DIR"
echo "💡 Available tools:"
echo "   • ./scripts/clean-history.sh - Remove sensitive commands"
echo "   • ./scripts/dedupe-history.sh - Remove duplicate commands"