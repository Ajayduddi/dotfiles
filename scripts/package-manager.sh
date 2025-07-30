#!/bin/bash

# AUTOMATED PACKAGE MANAGER
# Detects OS and manages packages intelligently

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables
DRY_RUN=false
VERBOSE=false
FORCE_INSTALL=false

show_help() {
    cat << HELP
🔧 AUTOMATED PACKAGE MANAGER

USAGE:
    $0 [OPTIONS] COMMAND

COMMANDS:
    install         Install packages for detected OS
    save           Save currently installed packages
    restore        Restore packages from saved list
    update         Update package lists and system
    check          Check package installation status

OPTIONS:
    --dry-run, -n   Simulate actions without making changes
    --verbose, -v   Enable detailed output
    --force, -f     Force installation even if packages exist
    --help, -h      Show this help message

EXAMPLES:
    $0 install                    # Install packages for current OS
    $0 --dry-run save            # Preview saving package list
    $0 restore                   # Restore packages from backup
HELP
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --force|-f)
            FORCE_INSTALL=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# OS Detection
detect_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "$ID" in
            fedora|rhel|centos|rocky|almalinux)
                OS_TYPE="fedora"
                if command -v dnf >/dev/null 2>&1; then
                    PACKAGE_MANAGER="dnf"
                    INSTALL_CMD="sudo dnf install -y"
                    LIST_CMD="dnf list installed"
                    SAVE_CMD="dnf history userinstalled"
                elif command -v yum >/dev/null 2>&1; then
                    PACKAGE_MANAGER="yum"
                    INSTALL_CMD="sudo yum install -y"
                    LIST_CMD="yum list installed"
                    SAVE_CMD="yum history userinstalled"
                fi
                PACKAGE_FILE="dnf-packages.txt"
                ;;
            ubuntu|debian|pop|linuxmint|elementary)
                OS_TYPE="debian"
                PACKAGE_MANAGER="apt"
                INSTALL_CMD="sudo apt-get install -y"
                LIST_CMD="apt list --installed"
                SAVE_CMD="apt-mark showmanual"
                PACKAGE_FILE="apt-packages.txt"
                ;;
            arch|manjaro|artix|endeavouros)
                OS_TYPE="arch"
                PACKAGE_MANAGER="pacman"
                INSTALL_CMD="sudo pacman -S --needed --noconfirm"
                LIST_CMD="pacman -Q"
                SAVE_CMD="pacman -Qqe"
                PACKAGE_FILE="pacman-packages.txt"
                ;;
            *)
                OS_TYPE="unknown"
                echo -e "${RED}❌ Unsupported OS: $ID${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}❌ Cannot detect OS: /etc/os-release not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Detected: $NAME ($OS_TYPE) using $PACKAGE_MANAGER${NC}"
}

# Package operations
install_packages() {
    local package_file="$HOME/.dotfiles/$PACKAGE_FILE"
    
    if [ ! -f "$package_file" ]; then
        echo -e "${RED}❌ Package file not found: $package_file${NC}"
        return 1
    fi
    
    local packages=$(grep -v '^#' "$package_file" | grep -v '^$' | tr '\n' ' ')
    local package_count=$(echo "$packages" | wc -w)
    
    echo -e "${BLUE}📦 Installing $package_count packages...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would execute: $INSTALL_CMD $packages${NC}"
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo "Packages to install: $packages"
    fi
    
    # Update package cache first
    case "$OS_TYPE" in
        fedora)
            sudo $PACKAGE_MANAGER makecache --refresh
            ;;
        debian)
            sudo apt-get update
            ;;
        arch)
            sudo pacman -Sy
            ;;
    esac
    
    # Install packages
    if eval "$INSTALL_CMD $packages"; then
        echo -e "${GREEN}✅ Package installation completed${NC}"
    else
        echo -e "${RED}❌ Some packages failed to install${NC}"
        return 1
    fi
}

save_packages() {
    local package_file="$HOME/.dotfiles/$PACKAGE_FILE"
    
    echo -e "${BLUE}📝 Saving installed packages to $PACKAGE_FILE...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would save packages to $package_file${NC}"
        local temp_list=$(eval "$SAVE_CMD" 2>/dev/null | head -10)
        echo "Preview (first 10 packages):"
        echo "$temp_list"
        return 0
    fi
    
    # Create backup if file exists
    if [ -f "$package_file" ]; then
        cp "$package_file" "${package_file}.backup.$(date +%s)"
        echo -e "${YELLOW}⚠️  Backed up existing package file${NC}"
    fi
    
    # Save packages
    if eval "$SAVE_CMD" | sort > "$package_file"; then
        local count=$(wc -l < "$package_file")
        echo -e "${GREEN}✅ Saved $count packages to $package_file${NC}"
    else
        echo -e "${RED}❌ Failed to save package list${NC}"
        return 1
    fi
}

check_packages() {
    local package_file="$HOME/.dotfiles/$PACKAGE_FILE"
    
    if [ ! -f "$package_file" ]; then
        echo -e "${RED}❌ Package file not found: $package_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Checking package installation status...${NC}"
    
    local total=0
    local installed=0
    local missing=()
    
    while read -r package; do
        if [[ "$package" =~ ^#.*$ ]] || [[ -z "$package" ]]; then
            continue
        fi
        
        total=$((total + 1))
        
        case "$OS_TYPE" in
            fedora)
                if rpm -q "$package" >/dev/null 2>&1; then
                    installed=$((installed + 1))
                    [ "$VERBOSE" = true ] && echo -e "${GREEN}✅ $package${NC}"
                else
                    missing+=("$package")
                    [ "$VERBOSE" = true ] && echo -e "${RED}❌ $package${NC}"
                fi
                ;;
            debian)
                if dpkg -l "$package" >/dev/null 2>&1; then
                    installed=$((installed + 1))
                    [ "$VERBOSE" = true ] && echo -e "${GREEN}✅ $package${NC}"
                else
                    missing+=("$package")
                    [ "$VERBOSE" = true ] && echo -e "${RED}❌ $package${NC}"
                fi
                ;;
            arch)
                if pacman -Q "$package" >/dev/null 2>&1; then
                    installed=$((installed + 1))
                    [ "$VERBOSE" = true ] && echo -e "${GREEN}✅ $package${NC}"
                else
                    missing+=("$package")
                    [ "$VERBOSE" = true ] && echo -e "${RED}❌ $package${NC}"
                fi
                ;;
        esac
    done < "$package_file"
    
    echo -e "${BLUE}📊 Summary: $installed/$total packages installed${NC}"
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Missing packages (${#missing[@]}):${NC}"
        for pkg in "${missing[@]}"; do
            echo "   - $pkg"
        done
    fi
}

update_system() {
    echo -e "${BLUE}🔄 Updating system packages...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        case "$OS_TYPE" in
            fedora)
                echo -e "${YELLOW}🔍 DRY RUN: Would execute: sudo dnf update -y${NC}"
                ;;
            debian)
                echo -e "${YELLOW}🔍 DRY RUN: Would execute: sudo apt-get update && sudo apt-get upgrade -y${NC}"
                ;;
            arch)
                echo -e "${YELLOW}🔍 DRY RUN: Would execute: sudo pacman -Syu --noconfirm${NC}"
                ;;
        esac
        return 0
    fi
    
    case "$OS_TYPE" in
        fedora)
            sudo dnf update -y
            ;;
        debian)
            sudo apt-get update && sudo apt-get upgrade -y
            ;;
        arch)
            sudo pacman -Syu --noconfirm
            ;;
    esac
    
    echo -e "${GREEN}✅ System update completed${NC}"
}

# Main execution
detect_os

case "${COMMAND:-}" in
    install)
        install_packages
        ;;
    save)
        save_packages
        ;;
    restore)
        install_packages
        ;;
    check)
        check_packages
        ;;
    update)
        update_system
        ;;
    *)
        echo -e "${RED}❌ Unknown command: ${COMMAND:-}${NC}"
        show_help
        exit 1
        ;;
esac
