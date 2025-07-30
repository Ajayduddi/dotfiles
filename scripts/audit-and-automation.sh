#!/bin/bash

# COMPREHENSIVE DOTFILES AUDIT AND AUTOMATION SYSTEM
# This script performs code audit, OS detection, package automation, and testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$HOME/.dotfiles"
AUDIT_DIR="${TMPDIR:-/tmp}/dotfiles-audit-$$"
DRY_RUN=false
VERBOSE=false

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                DRY_RUN=true
                echo -e "${YELLOW}🔍 DRY RUN MODE: Will simulate actions without making changes${NC}"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                echo -e "${BLUE}📢 VERBOSE MODE: Detailed output enabled${NC}"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
🔧 DOTFILES AUDIT AND AUTOMATION SYSTEM

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run, -n    Simulate actions without making changes
    --verbose, -v    Enable detailed output
    --help, -h       Show this help message

FEATURES:
    📊 Comprehensive code audit
    🔍 Automatic OS detection
    📦 Intelligent package management
    🧪 Safe testing environment
    🛡️  Security analysis
    📋 Script file management recommendations

EXAMPLES:
    $0                    # Full audit and automation
    $0 --dry-run         # Preview changes without applying
    $0 --verbose         # Detailed output for debugging
EOF
}

# Logging functions
log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo -e "\n${BLUE}🔷 $1${NC}"
    echo "======================================"
}

# Create audit directory
setup_audit_environment() {
    mkdir -p "$AUDIT_DIR"
    log_info "Audit environment created: $AUDIT_DIR"
}

# OS Detection System
detect_operating_system() {
    log_section "OPERATING SYSTEM DETECTION"
    
    local os_type=""
    local os_name=""
    local os_version=""
    local package_manager=""
    local install_cmd=""
    local update_cmd=""
    
    # Method 1: /etc/os-release (modern standard)
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        os_name="$NAME"
        os_version="$VERSION_ID"
        
        case "$ID" in
            fedora|rhel|centos|rocky|almalinux)
                os_type="fedora"
                ;;
            ubuntu|debian|pop|linuxmint|elementary)
                os_type="debian"
                ;;
            arch|manjaro|artix|endeavouros)
                os_type="arch"
                ;;
            *)
                case "$ID_LIKE" in
                    *fedora*|*rhel*|*centos*)
                        os_type="fedora"
                        ;;
                    *debian*|*ubuntu*)
                        os_type="debian"
                        ;;
                    *arch*)
                        os_type="arch"
                        ;;
                    *)
                        os_type="unknown"
                        ;;
                esac
                ;;
        esac
    fi
    
    # Set package manager commands
    case "$os_type" in
        fedora)
            if command -v dnf >/dev/null 2>&1; then
                package_manager="dnf"
                install_cmd="sudo dnf install -y"
                update_cmd="sudo dnf update -y"
            elif command -v yum >/dev/null 2>&1; then
                package_manager="yum"
                install_cmd="sudo yum install -y"
                update_cmd="sudo yum update -y"
            fi
            ;;
        debian)
            if command -v apt >/dev/null 2>&1; then
                package_manager="apt"
                install_cmd="sudo apt-get install -y"
                update_cmd="sudo apt-get update && sudo apt-get upgrade -y"
            fi
            ;;
        arch)
            if command -v pacman >/dev/null 2>&1; then
                package_manager="pacman"
                install_cmd="sudo pacman -S --needed --noconfirm"
                update_cmd="sudo pacman -Syu --noconfirm"
            fi
            ;;
    esac
    
    # Save detection results
    cat > "$AUDIT_DIR/os_detection.txt" << EOF
OS_TYPE="$os_type"
OS_NAME="$os_name"
OS_VERSION="$os_version"
PACKAGE_MANAGER="$package_manager"
INSTALL_CMD="$install_cmd"
UPDATE_CMD="$update_cmd"
EOF
    
    log_info "Operating System: $os_name ($os_type)"
    log_info "Package Manager: $package_manager"
    log_info "Detection results saved to: $AUDIT_DIR/os_detection.txt"
    
    # Export for use by other functions
    export OS_TYPE="$os_type"
    export OS_NAME="$os_name"
    export PACKAGE_MANAGER="$package_manager"
    export INSTALL_CMD="$install_cmd"
}

# Code Audit Functions
audit_shell_scripts() {
    log_section "SHELL SCRIPT AUDIT"
    
    local audit_report="$AUDIT_DIR/shell_script_audit.txt"
    
    echo "SHELL SCRIPT AUDIT REPORT" > "$audit_report"
    echo "Generated: $(date)" >> "$audit_report"
    echo "========================================" >> "$audit_report"
    echo >> "$audit_report"
    
    # Find all shell scripts
    local scripts=($(find "$DOTFILES_DIR" -name "*.sh" -type f))
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        echo "📄 Auditing: $script_name"
        
        echo "SCRIPT: $script" >> "$audit_report"
        echo "----------------------------------------" >> "$audit_report"
        
        # Check shebang
        local shebang=$(head -n1 "$script")
        if [[ "$shebang" =~ ^#!/bin/bash ]]; then
            echo "✅ Shebang: Correct" >> "$audit_report"
        else
            echo "⚠️  Shebang: $shebang (consider #!/bin/bash)" >> "$audit_report"
        fi
        
        # Check for set -e
        if grep -q "set -e" "$script"; then
            echo "✅ Error handling: set -e present" >> "$audit_report"
        else
            echo "⚠️  Error handling: Missing 'set -e'" >> "$audit_report"
        fi
        
        # Check for hardcoded paths
        local hardcoded_paths=$(grep -n "/home/" "$script" | grep -v "\$HOME" || true)
        if [ -n "$hardcoded_paths" ]; then
            echo "⚠️  Hardcoded paths found:" >> "$audit_report"
            echo "$hardcoded_paths" >> "$audit_report"
        else
            echo "✅ Paths: No hardcoded paths detected" >> "$audit_report"
        fi
        
        # Check for security issues
        local security_issues=()
        
        # Check for potential command injection
        if grep -q 'eval\|`.*`\|\$(' "$script"; then
            security_issues+=("Potential command injection patterns detected")
        fi
        
        # Check for unquoted variables
        local unquoted=$(grep -n '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$script" | head -5 || true)
        if [ -n "$unquoted" ]; then
            security_issues+=("Potential unquoted variables")
        fi
        
        if [ ${#security_issues[@]} -gt 0 ]; then
            echo "🔒 Security concerns:" >> "$audit_report"
            for issue in "${security_issues[@]}"; do
                echo "   - $issue" >> "$audit_report"
            done
        else
            echo "✅ Security: No obvious issues detected" >> "$audit_report"
        fi
        
        echo >> "$audit_report"
    done
    
    log_info "Shell script audit completed: $audit_report"
}

audit_package_management() {
    log_section "PACKAGE MANAGEMENT AUDIT"
    
    local audit_report="$AUDIT_DIR/package_audit.txt"
    
    echo "PACKAGE MANAGEMENT AUDIT" > "$audit_report"
    echo "Generated: $(date)" >> "$audit_report"
    echo "========================================" >> "$audit_report"
    echo >> "$audit_report"
    
    # Check existing package files
    local package_files=("$DOTFILES_DIR/dnf-packages.txt" "$DOTFILES_DIR/apt-packages.txt" "$DOTFILES_DIR/pacman-packages.txt")
    
    for file in "${package_files[@]}"; do
        if [ -f "$file" ]; then
            local package_count=$(wc -l < "$file")
            echo "📦 Found: $(basename "$file") ($package_count packages)" >> "$audit_report"
            
            # Check for potentially problematic packages
            local problematic=$(grep -E "(.*-dev|.*-devel|build-essential)" "$file" | wc -l)
            if [ "$problematic" -gt 0 ]; then
                echo "   ⚠️  Contains $problematic development packages" >> "$audit_report"
            fi
        else
            echo "❌ Missing: $(basename "$file")" >> "$audit_report"
        fi
    done
    
    echo >> "$audit_report"
    echo "RECOMMENDATIONS:" >> "$audit_report"
    echo "- Create unified package management system" >> "$audit_report"
    echo "- Implement automatic OS detection" >> "$audit_report"
    echo "- Add dry-run capability for package operations" >> "$audit_report"
    echo "- Separate essential vs optional packages" >> "$audit_report"
    
    log_info "Package management audit completed: $audit_report"
}

audit_security() {
    log_section "SECURITY AUDIT"
    
    local security_report="$AUDIT_DIR/security_audit.txt"
    
    echo "SECURITY AUDIT REPORT" > "$security_report"
    echo "Generated: $(date)" >> "$security_report"
    echo "========================================" >> "$security_report"
    echo >> "$security_report"
    
    # Check for sensitive files
    log_info "Scanning for sensitive files..."
    
    local sensitive_patterns=(
        "password" "secret" "token" "key" "credential"
        "auth" "login" "passwd" "private"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        local found_files=$(find "$DOTFILES_DIR" -type f -name "*$pattern*" 2>/dev/null || true)
        if [ -n "$found_files" ]; then
            echo "⚠️  Files matching '$pattern':" >> "$security_report"
            echo "$found_files" >> "$security_report"
            echo >> "$security_report"
        fi
    done
    
    # Check .gitignore effectiveness
    echo "GITIGNORE ANALYSIS:" >> "$security_report"
    if [ -f "$DOTFILES_DIR/.gitignore" ]; then
        local gitignore_lines=$(wc -l < "$DOTFILES_DIR/.gitignore")
        echo "✅ .gitignore exists ($gitignore_lines lines)" >> "$security_report"
        
        # Check for essential patterns
        local essential_patterns=("*.key" "*.pem" "*password*" "*secret*" "*.tmp")
        for pattern in "${essential_patterns[@]}"; do
            if grep -q "$pattern" "$DOTFILES_DIR/.gitignore"; then
                echo "✅ Pattern protected: $pattern" >> "$security_report"
            else
                echo "⚠️  Missing pattern: $pattern" >> "$security_report"
            fi
        done
    else
        echo "❌ .gitignore missing" >> "$security_report"
    fi
    
    log_info "Security audit completed: $security_report"
}

# Package Installation System
create_package_manager() {
    log_section "CREATING AUTOMATED PACKAGE MANAGER"
    
    local package_manager_script="$DOTFILES_DIR/package-manager.sh"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN: Would create $package_manager_script"
        return
    fi
    
    cat > "$package_manager_script" << 'EOF'
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
EOF
    
    chmod +x "$package_manager_script"
    log_info "Created automated package manager: $package_manager_script"
}

# Testing System
create_testing_framework() {
    log_section "CREATING TESTING FRAMEWORK"
    
    local test_script="$DOTFILES_DIR/test-system.sh"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN: Would create testing framework"
        return
    fi
    
    cat > "$test_script" << 'EOF'
#!/bin/bash

# DOTFILES TESTING FRAMEWORK
# Safe testing environment for dotfiles scripts

set -e

# Test configuration
TEST_DIR="${TMPDIR:-/tmp}/dotfiles-test-$$"
DOTFILES_DIR="$HOME/.dotfiles"
TEST_RESULTS="$TEST_DIR/test_results.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

setup_test_environment() {
    echo -e "${BLUE}🧪 Setting up test environment...${NC}"
    mkdir -p "$TEST_DIR"
    
    # Create test report
    cat > "$TEST_RESULTS" << REPORT
DOTFILES TESTING REPORT
Generated: $(date)
Test Environment: $TEST_DIR
========================================

REPORT
}

test_os_detection() {
    echo -e "${BLUE}🔍 Testing OS detection...${NC}"
    
    if [ -f "$DOTFILES_DIR/package-manager.sh" ]; then
        if "$DOTFILES_DIR/package-manager.sh" check --dry-run; then
            echo "✅ OS Detection: PASSED" >> "$TEST_RESULTS"
            echo -e "${GREEN}✅ OS detection test passed${NC}"
        else
            echo "❌ OS Detection: FAILED" >> "$TEST_RESULTS"
            echo -e "${RED}❌ OS detection test failed${NC}"
        fi
    else
        echo "⚠️  OS Detection: SKIPPED (package-manager.sh not found)" >> "$TEST_RESULTS"
        echo -e "${YELLOW}⚠️  OS detection test skipped${NC}"
    fi
}

test_package_operations() {
    echo -e "${BLUE}📦 Testing package operations...${NC}"
    
    if [ -f "$DOTFILES_DIR/package-manager.sh" ]; then
        # Test dry-run operations
        local tests=(
            "save --dry-run"
            "install --dry-run" 
            "check --dry-run"
            "update --dry-run"
        )
        
        local passed=0
        local total=${#tests[@]}
        
        for test in "${tests[@]}"; do
            if "$DOTFILES_DIR/package-manager.sh" $test >/dev/null 2>&1; then
                passed=$((passed + 1))
                echo "   ✅ $test" >> "$TEST_RESULTS"
            else
                echo "   ❌ $test" >> "$TEST_RESULTS"
            fi
        done
        
        echo "📦 Package Operations: $passed/$total tests passed" >> "$TEST_RESULTS"
        
        if [ "$passed" -eq "$total" ]; then
            echo -e "${GREEN}✅ Package operations tests passed ($passed/$total)${NC}"
        else
            echo -e "${YELLOW}⚠️  Package operations tests partial ($passed/$total)${NC}"
        fi
    else
        echo "⚠️  Package Operations: SKIPPED (package-manager.sh not found)" >> "$TEST_RESULTS"
        echo -e "${YELLOW}⚠️  Package operations test skipped${NC}"
    fi
}

test_script_syntax() {
    echo -e "${BLUE}📝 Testing script syntax...${NC}"
    
    local scripts=($(find "$DOTFILES_DIR" -name "*.sh" -type f))
    local passed=0
    local total=${#scripts[@]}
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        if bash -n "$script" 2>/dev/null; then
            passed=$((passed + 1))
            echo "   ✅ $script_name" >> "$TEST_RESULTS"
        else
            echo "   ❌ $script_name (syntax error)" >> "$TEST_RESULTS"
        fi
    done
    
    echo "📝 Script Syntax: $passed/$total scripts valid" >> "$TEST_RESULTS"
    
    if [ "$passed" -eq "$total" ]; then
        echo -e "${GREEN}✅ Script syntax tests passed ($passed/$total)${NC}"
    else
        echo -e "${RED}❌ Script syntax tests failed ($passed/$total)${NC}"
    fi
}

test_file_permissions() {
    echo -e "${BLUE}🔐 Testing file permissions...${NC}"
    
    local scripts=($(find "$DOTFILES_DIR" -name "*.sh" -type f))
    local executable=0
    local total=${#scripts[@]}
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        if [ -x "$script" ]; then
            executable=$((executable + 1))
            echo "   ✅ $script_name (executable)" >> "$TEST_RESULTS"
        else
            echo "   ⚠️  $script_name (not executable)" >> "$TEST_RESULTS"
        fi
    done
    
    echo "🔐 File Permissions: $executable/$total scripts executable" >> "$TEST_RESULTS"
    echo -e "${BLUE}📊 File permissions: $executable/$total scripts executable${NC}"
}

run_security_tests() {
    echo -e "${BLUE}🛡️  Running security tests...${NC}"
    
    local issues=0
    
    # Check for sensitive patterns in scripts
    local sensitive_patterns=("password" "secret" "token" "key")
    
    for pattern in "${sensitive_patterns[@]}"; do
        local found=$(grep -r "$pattern" "$DOTFILES_DIR" --include="*.sh" 2>/dev/null | wc -l)
        if [ "$found" -gt 0 ]; then
            issues=$((issues + 1))
            echo "   ⚠️  Found $found instances of '$pattern'" >> "$TEST_RESULTS"
        fi
    done
    
    # Check .gitignore
    if [ -f "$DOTFILES_DIR/.gitignore" ]; then
        echo "   ✅ .gitignore exists" >> "$TEST_RESULTS"
    else
        issues=$((issues + 1))
        echo "   ❌ .gitignore missing" >> "$TEST_RESULTS"
    fi
    
    echo "🛡️  Security Tests: $issues potential issues found" >> "$TEST_RESULTS"
    
    if [ "$issues" -eq 0 ]; then
        echo -e "${GREEN}✅ Security tests passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Security tests found $issues potential issues${NC}"
    fi
}

generate_report() {
    echo -e "${BLUE}📋 Generating test report...${NC}"
    
    echo "" >> "$TEST_RESULTS"
    echo "TEST SUMMARY" >> "$TEST_RESULTS"
    echo "============" >> "$TEST_RESULTS"
    echo "Test completed: $(date)" >> "$TEST_RESULTS"
    echo "Test environment: $TEST_DIR" >> "$TEST_RESULTS"
    echo "" >> "$TEST_RESULTS"
    echo "RECOMMENDATIONS:" >> "$TEST_RESULTS"
    echo "- Review any failed tests above" >> "$TEST_RESULTS"
    echo "- Ensure all scripts are executable" >> "$TEST_RESULTS"
    echo "- Address security concerns if any" >> "$TEST_RESULTS"
    echo "- Run tests regularly after changes" >> "$TEST_RESULTS"
    
    echo -e "${GREEN}✅ Test report generated: $TEST_RESULTS${NC}"
    
    # Show summary
    echo -e "\n${BLUE}📊 TEST SUMMARY:${NC}"
    if [ -f "$TEST_RESULTS" ]; then
        cat "$TEST_RESULTS"
    fi
}

cleanup_test_environment() {
    echo -e "${BLUE}🧹 Test environment preserved at: $TEST_DIR${NC}"
    echo -e "${YELLOW}💡 Review test results and clean up manually when done${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🧪 DOTFILES TESTING FRAMEWORK${NC}"
    echo "======================================"
    
    setup_test_environment
    test_os_detection
    test_package_operations
    test_script_syntax
    test_file_permissions
    run_security_tests
    generate_report
    cleanup_test_environment
}

main "$@"
EOF
    
    chmod +x "$test_script"
    log_info "Created testing framework: $test_script"
}

# Script File Management
analyze_script_files() {
    log_section "SCRIPT FILE ANALYSIS"
    
    local analysis_report="$AUDIT_DIR/script_analysis.txt"
    
    echo "SCRIPT FILE ANALYSIS" > "$analysis_report"
    echo "Generated: $(date)" >> "$analysis_report"
    echo "========================================" >> "$analysis_report"
    echo >> "$analysis_report"
    
    # Find all script files
    local all_scripts=($(find "$DOTFILES_DIR" -name "*.sh" -type f))
    
    echo "FOUND SCRIPTS:" >> "$analysis_report"
    for script in "${all_scripts[@]}"; do
        local script_name=$(basename "$script")
        local size=$(stat -c%s "$script" 2>/dev/null || echo "0")
        local lines=$(wc -l < "$script" 2>/dev/null || echo "0")
        local last_modified=$(stat -c%y "$script" 2>/dev/null || echo "unknown")
        
        echo "📄 $script_name" >> "$analysis_report"
        echo "   Size: $size bytes" >> "$analysis_report"
        echo "   Lines: $lines" >> "$analysis_report"
        echo "   Modified: $last_modified" >> "$analysis_report"
        echo >> "$analysis_report"
    done
    
    # Analyze dependencies
    echo "SCRIPT DEPENDENCIES:" >> "$analysis_report"
    for script in "${all_scripts[@]}"; do
        local script_name=$(basename "$script")
        local sources=$(grep -n "source\|\\." "$script" | grep -v "^#" || true)
        if [ -n "$sources" ]; then
            echo "📄 $script_name sources:" >> "$analysis_report"
            echo "$sources" >> "$analysis_report"
            echo >> "$analysis_report"
        fi
    done
    
    # Recommendations
    echo "RECOMMENDATIONS:" >> "$analysis_report"
    echo "1. Create unified package management system" >> "$analysis_report"
    echo "2. Implement comprehensive testing framework" >> "$analysis_report"
    echo "3. Add OS detection to all scripts" >> "$analysis_report"
    echo "4. Standardize error handling and logging" >> "$analysis_report"
    echo "5. Create modular utility functions" >> "$analysis_report"
    
    log_info "Script analysis completed: $analysis_report"
}

# Main execution
main() {
    echo -e "\n${BLUE}🔧 DOTFILES COMPREHENSIVE AUDIT AND AUTOMATION${NC}"
    echo "=================================================="
    
    parse_arguments "$@"
    setup_audit_environment
    detect_operating_system
    
    # Audit phase
    audit_shell_scripts
    audit_package_management
    audit_security
    analyze_script_files
    
    # Automation phase
    create_package_manager
    create_testing_framework
    
    # Final report
    log_section "AUDIT SUMMARY"
    
    log_info "Audit completed successfully!"
    log_info "Results saved to: $AUDIT_DIR"
    log_info ""
    log_info "Created automation tools:"
    log_info "  📦 package-manager.sh - Automated package management"
    log_info "  🧪 test-system.sh - Testing framework"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Review audit reports in $AUDIT_DIR"
    log_info "  2. Test the new package manager: ./package-manager.sh --help"
    log_info "  3. Run tests: ./test-system.sh"
    log_info "  4. Implement recommendations from audit reports"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN completed - no system changes made"
    fi
}

# Execute main function
main "$@"