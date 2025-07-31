#!/bin/bash

# System-Wide Configuration Backup and Restoration Script
# Scans entire system for development, server, and production configurations

set -e

# Configuration
DOTFILES_DIR="$HOME/.dotfiles"
SYSTEM_BACKUP_DIR="$DOTFILES_DIR/system-configs"
DRY_RUN=false
RESTORE_MODE=false
BACKUP_MODE=true

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be done without making changes"
            echo ""
            ;;
        --restore)
            RESTORE_MODE=true
            BACKUP_MODE=false
            echo "🔄 RESTORE MODE: Will restore system configurations"
            echo ""
            ;;
        --backup)
            BACKUP_MODE=true
            RESTORE_MODE=false
            echo "💾 BACKUP MODE: Will backup system configurations"
            echo ""
            ;;
        --help)
            echo "System Configuration Backup & Restore Tool"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --backup     Backup system configurations (default)"
            echo "  --restore    Restore system configurations"
            echo "  --dry-run    Show what would be done without making changes"
            echo "  --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --backup --dry-run    # Preview what would be backed up"
            echo "  $0 --backup              # Backup all system configs"
            echo "  $0 --restore --dry-run   # Preview what would be restored"
            echo "  $0 --restore             # Restore all system configs"
            exit 0
            ;;
    esac
done

# System configuration locations to scan
SYSTEM_CONFIG_PATHS=(
    "/etc"
    "/opt"
    "/usr/local/etc"
    "/var/lib"
    "/srv"
)

# Development and server software patterns
SOFTWARE_PATTERNS=(
    # Web servers
    "*apache*" "*httpd*" "*nginx*" "*lighttpd*"
    # Application servers
    "*tomcat*" "*jetty*" "*wildfly*" "*jboss*" "*glassfish*"
    # Databases
    "*mysql*" "*mariadb*" "*postgresql*" "*postgres*" "*redis*" "*mongodb*" "*mongo*"
    # Development tools
    "*maven*" "*gradle*" "*ant*" "*sbt*" "*nodejs*" "*node*" "*npm*"
    # DevOps tools
    "*docker*" "*kubernetes*" "*k8s*" "*jenkins*" "*gitlab*" "*nexus*" "*artifactory*"
    # Monitoring & logging
    "*prometheus*" "*grafana*" "*elasticsearch*" "*logstash*" "*kibana*" "*splunk*"
    # Message queues
    "*rabbitmq*" "*kafka*" "*activemq*" "*artemis*"
    # Caching
    "*memcached*" "*hazelcast*" "*ehcache*"
    # Security
    "*keycloak*" "*vault*" "*consul*"
)

# Configuration file extensions
CONFIG_EXTENSIONS=(
    "*.conf" "*.config" "*.cfg"
    "*.xml" "*.yml" "*.yaml" "*.json"
    "*.properties" "*.ini" "*.toml"
    "*.env" "*.sh" "*.bash"
)

# Function to check if we have read access to a path
has_read_access() {
    local path="$1"
    [ -r "$path" ] 2>/dev/null
}

# Function to safely copy with sudo if needed
safe_copy() {
    local src="$1"
    local dest="$2"
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Copy $src -> $dest"
        return 0
    fi
    
    # Create destination directory
    mkdir -p "$(dirname "$dest")"
    
    # Try regular copy first, then sudo if needed
    if cp "$src" "$dest" 2>/dev/null; then
        echo "✅ Copied: $src"
        return 0
    elif sudo cp "$src" "$dest" 2>/dev/null; then
        echo "✅ Copied (sudo): $src"
        return 0
    else
        echo "❌ Failed to copy: $src"
        return 1
    fi
}

# Function to safely restore with sudo if needed
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
        sudo cp "$dest" "${dest}.backup_$(date +%s)" 2>/dev/null || true
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

# Paths to exclude (too generic or not useful)
EXCLUDE_PATHS=(
    "*/flatpak/*" "*/snap/*" "*/cache/*" "*/tmp/*" "*/temp/*"
    "*/node_modules/*" "*/deps/*" "*/build/*" "*/dist/*"
    "*/locale/*" "*/locales/*" "*/i18n/*" "*/translations/*"
    "*/fonts/*" "*/icons/*" "*/themes/*" "*/mime/*"
    "*/doc/*" "*/docs/*" "*/man/*" "*/help/*"
)

# Function to check if path should be excluded
should_exclude_path() {
    local path="$1"
    for exclude in "${EXCLUDE_PATHS[@]}"; do
        if [[ "$path" == $exclude ]]; then
            return 0  # Should exclude
        fi
    done
    return 1  # Should not exclude
}

# Function to find configuration files
find_config_files() {
    local search_path="$1"
    
    if [ ! -d "$search_path" ]; then
        return
    fi
    
    # Build find command with all extensions
    local find_args=()
    for ext in "${CONFIG_EXTENSIONS[@]}"; do
        find_args+=(-name "$ext" -o)
    done
    # Remove the last -o
    unset 'find_args[-1]'
    
    # Find files matching software patterns and config extensions
    find "$search_path" -type f \( "${find_args[@]}" \) 2>/dev/null | while read -r file; do
        # Skip if path should be excluded
        if should_exclude_path "$file"; then
            continue
        fi
        
        # Check if file matches any software pattern
        local basename_file=$(basename "$file")
        local dirname_file=$(dirname "$file")
        local full_path="$file"
        
        for software in "${SOFTWARE_PATTERNS[@]}"; do
            if [[ "$basename_file" == $software ]] || [[ "$dirname_file" == *$software* ]] || [[ "$full_path" == *$software* ]]; then
                # Additional filtering for meaningful configs
                if [[ "$file" == *"/conf/"* ]] || [[ "$file" == *"/config/"* ]] || [[ "$file" == *"/etc/"* ]] || [[ "$basename_file" == *.conf ]] || [[ "$basename_file" == *.xml ]] || [[ "$basename_file" == *.properties ]] || [[ "$basename_file" == *.yml ]] || [[ "$basename_file" == *.yaml ]]; then
                    echo "$file"
                    break
                fi
            fi
        done
    done
}

# Function to backup system configurations
backup_system_configs() {
    echo "🔍 Scanning system for development and server configurations..."
    echo "📁 Backup directory: $SYSTEM_BACKUP_DIR"
    echo ""
    
    local total_files=0
    local backed_up_files=0
    
    # Scan each system path
    for path in "${SYSTEM_CONFIG_PATHS[@]}"; do
        if [ ! -d "$path" ]; then
            continue
        fi
        
        echo "🔍 Scanning: $path"
        
        # Find configuration files
        while IFS= read -r config_file; do
            if [ -z "$config_file" ]; then
                continue
            fi
            
            ((total_files++))
            
            # Create relative path for backup
            local rel_path="${config_file#/}"
            local backup_path="$SYSTEM_BACKUP_DIR/$rel_path"
            
            # Check if we can read the file
            if has_read_access "$config_file"; then
                if safe_copy "$config_file" "$backup_path"; then
                    ((backed_up_files++))
                fi
            else
                echo "⚠️ No read access: $config_file"
            fi
            
        done < <(find_config_files "$path")
    done
    
    echo ""
    echo "📊 BACKUP SUMMARY:"
    echo "=================="
    echo "Total config files found: $total_files"
    echo "Successfully backed up: $backed_up_files"
    echo "Backup location: $SYSTEM_BACKUP_DIR"
}

# Function to restore system configurations
restore_system_configs() {
    echo "🔄 Restoring system configurations from backup..."
    echo "📁 Restore source: $SYSTEM_BACKUP_DIR"
    echo ""
    
    if [ ! -d "$SYSTEM_BACKUP_DIR" ]; then
        echo "❌ Backup directory not found: $SYSTEM_BACKUP_DIR"
        echo "   Run backup first: $0 --backup"
        exit 1
    fi
    
    local total_files=0
    local restored_files=0
    
    # Find all backed up files
    find "$SYSTEM_BACKUP_DIR" -type f | while read -r backup_file; do
        ((total_files++))
        
        # Calculate original system path
        local rel_path="${backup_file#$SYSTEM_BACKUP_DIR/}"
        local system_path="/$rel_path"
        
        echo "🔄 Restoring: $system_path"
        
        if safe_restore "$backup_file" "$system_path"; then
            ((restored_files++))
        fi
    done
    
    echo ""
    echo "📊 RESTORE SUMMARY:"
    echo "==================="
    echo "Total files to restore: $total_files"
    echo "Successfully restored: $restored_files"
    echo ""
    echo "⚠️  IMPORTANT: You may need to restart services for changes to take effect"
    echo "   Example: sudo systemctl restart httpd nginx mysql"
}

# Function to list what would be backed up
list_discoverable_configs() {
    echo "🔍 DISCOVERABLE SYSTEM CONFIGURATIONS:"
    echo "======================================"
    echo ""
    
    for path in "${SYSTEM_CONFIG_PATHS[@]}"; do
        if [ ! -d "$path" ]; then
            continue
        fi
        
        echo "📂 $path:"
        local found_any=false
        
        while IFS= read -r config_file; do
            if [ -n "$config_file" ]; then
                found_any=true
                if has_read_access "$config_file"; then
                    echo "  ✅ $config_file"
                else
                    echo "  🔒 $config_file (requires sudo)"
                fi
            fi
        done < <(find_config_files "$path" | head -10)
        
        if [ "$found_any" = false ]; then
            echo "  (no matching configurations found)"
        fi
        echo ""
    done
}

# Main execution
echo "🖥️ SYSTEM-WIDE CONFIGURATION BACKUP & RESTORE TOOL"
echo "=================================================="
echo ""

if [ "$BACKUP_MODE" = true ]; then
    if [ "$DRY_RUN" = true ]; then
        list_discoverable_configs
    else
        backup_system_configs
    fi
elif [ "$RESTORE_MODE" = true ]; then
    restore_system_configs
fi

echo ""
echo "✅ Operation completed!"