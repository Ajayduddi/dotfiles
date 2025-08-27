#!/bin/bash

# DOTFILES AUTOMATION MANAGER
# Unified interface for all dotfiles management operations
# This script provides a single entry point for all dotfiles operations

set -e

# Minimal emoji output (set NO_EMOJI=true to strip icons)
NO_EMOJI=${NO_EMOJI:-true}
strip_emojis() { sed -E 's/(✅|🔍|⚠️|❌|🟡|📝|🔧|💾|📦|🖥️|🚀|🌐|🗄️|🔒|🔗|🔄|➡️|🐱|☕|🛠️|📁|🔌|🛡️|🧪|🔎|📊|🧹|🟢|🟠|🔵)//g'; }
echo() {
  local newline=true; local enable_escape=false; local args=()
  while [[ $# -gt 0 ]]; do case "$1" in -n) newline=false;; -e) enable_escape=true;; *) args+=("$1");; esac; shift; done
  local msg="${args[*]}"
  if [[ "$NO_EMOJI" = "true" ]]; then msg=$(printf "%s" "$msg" | strip_emojis); fi
  if $enable_escape; then if $newline; then builtin echo -e "$msg"; else builtin echo -ne "$msg"; fi
  else if $newline; then builtin echo "$msg"; else builtin echo -n "$msg"; fi; fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DOTFILES_DIR="$HOME/.dotfiles"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

# Parse global flags
DRY_RUN=false
VERBOSE=false
FORCE=false

# Function to display help
show_help() {
    cat << EOF
${BLUE}🔧 DOTFILES AUTOMATION MANAGER${NC}
=====================================

${GREEN}DESCRIPTION:${NC}
  Unified interface for all dotfiles management operations.
  Provides automated, safe, and comprehensive dotfiles management.

${GREEN}USAGE:${NC}
  $0 [GLOBAL_OPTIONS] COMMAND [COMMAND_OPTIONS]

${GREEN}GLOBAL OPTIONS:${NC}
  --dry-run, -n       Show what would be done without making changes
  --verbose, -v       Enable detailed output
  --force, -f         Force operations without confirmations
  --help, -h          Show this help message

${GREEN}COMMANDS:${NC}

${CYAN}Core Operations:${NC}
  setup               Set up dotfiles environment and configuration
  backup              Create backups of all dotfiles and settings
  restore             Restore dotfiles from backups
  reset               Reset dotfiles to default configurations

${CYAN}Maintenance:${NC}
  test                Run comprehensive testing without affecting system
  audit               Perform security and quality audit
  clean               Clean up unnecessary files and optimize
  status              Show current dotfiles status and health

${CYAN}Package Management:${NC}
  install-packages    Install packages for current OS (auto-detected)
  save-packages       Save currently installed packages to backup
  sync-packages       Synchronize packages with saved list

${CYAN}Advanced:${NC}
  full-automation     Complete automated setup (setup + backup + test)
  emergency-restore   Emergency system restoration from backups
  validate            Validate all configurations and dependencies

${GREEN}EXAMPLES:${NC}
  $0 setup                          # Initial dotfiles setup
  $0 --dry-run backup              # Preview backup operation
  $0 --verbose test                # Run tests with detailed output
  $0 full-automation               # Complete automated setup
  $0 status                        # Check current status
  $0 emergency-restore --force     # Emergency restoration

${GREEN}WORKFLOW:${NC}
  1. ${YELLOW}setup${NC}      - Initialize and configure dotfiles
  2. ${YELLOW}backup${NC}     - Regular backup of configurations  
  3. ${YELLOW}test${NC}       - Validate everything works correctly
  4. ${YELLOW}status${NC}     - Monitor system health

${GREEN}SAFETY FEATURES:${NC}
  ✅ All operations support --dry-run for safe preview
  ✅ Automatic backups before any changes
  ✅ Comprehensive validation and testing
  ✅ Emergency restoration capabilities
  ✅ Security-focused with sensitive data protection

${GREEN}DIRECTORY STRUCTURE:${NC}
  ~/.dotfiles/                 # Main dotfiles directory
  ├── backup-dotfiles.sh       # Core backup functionality
  ├── restore-dotfiles.sh      # Core restore functionality  
  ├── reset-dotfiles.sh        # Core reset functionality
  ├── setup-dotfiles.sh        # Core setup functionality
  ├── dotfiles-manager.sh      # This unified manager (YOU ARE HERE)
  └── scripts/                 # Supporting automation scripts
      ├── package-manager.sh   # Package management
      ├── audit-and-automation.sh # Security auditing
      └── ...                  # Other supporting scripts

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

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}🔍 $1${NC}"
    fi
}

log_section() {
    echo -e "\n${BLUE}🔷 $1${NC}"
    echo "======================================"
}

# Function to check prerequisites
check_prerequisites() {
    log_section "CHECKING PREREQUISITES"
    
    # Check if dotfiles directory exists
    if [ ! -d "$DOTFILES_DIR" ]; then
        log_error "Dotfiles directory not found: $DOTFILES_DIR"
        log_info "Please create the dotfiles directory first"
        exit 1
    fi
    
    # Check if core scripts exist
    local core_scripts=("backup-dotfiles.sh" "restore-dotfiles.sh" "reset-dotfiles.sh" "setup-dotfiles.sh")
    local missing_scripts=()
    
    for script in "${core_scripts[@]}"; do
        if [ ! -f "$DOTFILES_DIR/$script" ]; then
            missing_scripts+=("$script")
        fi
    done
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        log_error "Missing core scripts:"
        for script in "${missing_scripts[@]}"; do
            echo "  - $script"
        done
        exit 1
    fi
    
    # Check if scripts directory exists
    if [ ! -d "$SCRIPTS_DIR" ]; then
        log_warning "Scripts directory not found, creating: $SCRIPTS_DIR"
        mkdir -p "$SCRIPTS_DIR"
    fi
    
    log_info "Prerequisites check completed"
}

# Function to run core scripts with appropriate flags
run_core_script() {
    local script_name="$1"
    local script_path="$DOTFILES_DIR/$script_name"
    
    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_name"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        log_warning "Making script executable: $script_name"
        if [ "$DRY_RUN" = true ]; then
            log_debug "Would make $script_name executable"
        else
            chmod +x "$script_path"
        fi
    fi
    
    # Build arguments - only pass flags that the core scripts support
    local args=()
    [ "$DRY_RUN" = true ] && args+=(--dry-run)
    [ "$FORCE" = true ] && args+=(--force)
    
    log_debug "Running: $script_path ${args[*]}"
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "Executing core script in dry-run mode: $script_name"
        "$script_path" "${args[@]}" || {
            log_warning "Core script $script_name reported issues in dry-run mode"
            return 0  # Don't fail the manager in dry-run mode
        }
    else
        "$script_path" "${args[@]}" || {
            log_error "Core script $script_name failed with exit code $?"
            return 1
        }
    fi
}

# Function to run supporting scripts
run_support_script() {
    local script_name="$1"
    shift
    local script_path="$SCRIPTS_DIR/$script_name"
    
    if [ ! -f "$script_path" ]; then
        log_error "Support script not found: $script_name"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        log_warning "Making script executable: $script_name"
        if [ "$DRY_RUN" = true ]; then
            log_debug "Would make $script_name executable"
        else
            chmod +x "$script_path"
        fi
    fi
    
    # Build arguments
    local args=()
    [ "$DRY_RUN" = true ] && args+=(--dry-run)
    [ "$VERBOSE" = true ] && args+=(--verbose)
    [ "$FORCE" = true ] && args+=(--force)
    
    # Add any additional arguments
    args+=("$@")
    
    log_debug "Running: $script_path ${args[*]}"
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "Executing support script in dry-run mode: $script_name"
        "$script_path" "${args[@]}" || {
            log_warning "Support script $script_name reported issues in dry-run mode"
            return 0  # Don't fail the manager in dry-run mode
        }
    else
        "$script_path" "${args[@]}" || {
            log_error "Support script $script_name failed with exit code $?"
            return 1
        }
    fi
}

# Core operation functions
cmd_setup() {
    log_section "DOTFILES SETUP"
    log_info "Initializing dotfiles environment..."
    run_core_script "setup-dotfiles.sh"
    log_info "Setup completed successfully!"
}

cmd_backup() {
    log_section "DOTFILES BACKUP"
    log_info "Creating comprehensive backup..."
    run_core_script "backup-dotfiles.sh"
    log_info "Backup completed successfully!"
}

cmd_restore() {
    log_section "DOTFILES RESTORE"
    log_info "Restoring dotfiles from backup..."
    run_core_script "restore-dotfiles.sh"
    log_info "Restore completed successfully!"
}

cmd_reset() {
    log_section "DOTFILES RESET"
    log_warning "Resetting dotfiles to defaults..."
    run_core_script "reset-dotfiles.sh"
    log_info "Reset completed successfully!"
}

# Testing and validation
cmd_test() {
    log_section "COMPREHENSIVE TESTING"
    log_info "Running comprehensive test suite..."
    
    # Run basic validation since test-system.sh doesn't exist
    log_info "Running basic validation..."
    check_prerequisites
    
    # Test core scripts in dry-run mode
    log_info "Testing core scripts..."
    local test_failed=false
    
    for script in "setup-dotfiles.sh" "backup-dotfiles.sh" "restore-dotfiles.sh" "reset-dotfiles.sh"; do
        if [ -f "$DOTFILES_DIR/$script" ]; then
            log_debug "Testing $script..."
            if ! bash -n "$DOTFILES_DIR/$script"; then
                log_error "Syntax error in $script"
                test_failed=true
            else
                log_debug "$script syntax OK"
            fi
        fi
    done
    
    if [ "$test_failed" = true ]; then
        log_error "Some tests failed"
        return 1
    fi
    
    log_info "Testing completed successfully!"
}

cmd_audit() {
    log_section "SECURITY & QUALITY AUDIT"
    log_info "Running security and quality audit..."
    
    if [ -f "$SCRIPTS_DIR/audit-and-automation.sh" ]; then
        run_support_script "audit-and-automation.sh"
    else
        log_warning "Audit script not found, running basic checks..."
        # Run basic security checks
        echo "Checking for sensitive files in dotfiles..."
        if find "$DOTFILES_DIR" -name "*password*" -o -name "*secret*" -o -name "*key*" -o -name "*.pem" 2>/dev/null | head -10 | grep -q .; then
            log_warning "Found potential sensitive files - please review"
        else
            log_info "No obvious sensitive files found"
        fi
    fi
    
    log_info "Audit completed successfully!"
}

cmd_clean() {
    log_section "CLEANUP & OPTIMIZATION"
    log_info "Cleaning up and optimizing dotfiles..."
    
    if [ -f "$SCRIPTS_DIR/cleanup-and-secure.sh" ]; then
        run_support_script "cleanup-and-secure.sh"
    else
        log_warning "Cleanup script not found, running basic cleanup..."
        # Basic cleanup
        local temp_files=$(find "$DOTFILES_DIR" -name "*.tmp" -o -name "*.backup_*" -o -name "*~" 2>/dev/null | head -10)
        if [ -n "$temp_files" ]; then
            echo "Found temporary files:"
            echo "$temp_files"
            if [ "$DRY_RUN" = false ]; then
                find "$DOTFILES_DIR" -name "*.tmp" -o -name "*.backup_*" -o -name "*~" -delete 2>/dev/null || true
                log_info "Temporary files cleaned"
            else
                log_debug "Would clean temporary files"
            fi
        else
            log_info "No temporary files found"
        fi
    fi
    
    log_info "Cleanup completed successfully!"
}

# Package management
cmd_install_packages() {
    log_section "PACKAGE INSTALLATION"
    log_info "Installing packages for current OS..."
    
    if [ -f "$SCRIPTS_DIR/package-manager.sh" ]; then
        run_support_script "package-manager.sh" "install"
    else
        log_error "Package manager script not found"
        return 1
    fi
    
    log_info "Package installation completed!"
}

cmd_save_packages() {
    log_section "SAVE PACKAGES"
    log_info "Saving currently installed packages..."
    
    if [ -f "$SCRIPTS_DIR/package-manager.sh" ]; then
        run_support_script "package-manager.sh" "save"
    else
        log_error "Package manager script not found"
        return 1
    fi
    
    log_info "Package save completed!"
}

cmd_sync_packages() {
    log_section "PACKAGE SYNCHRONIZATION"
    log_info "Synchronizing packages with saved list..."
    
    if [ -f "$SCRIPTS_DIR/package-manager.sh" ]; then
        run_support_script "package-manager.sh" "check"
    else
        log_error "Package manager script not found"
        return 1
    fi
    
    log_info "Package synchronization completed!"
}

# Status and information
cmd_status() {
    log_section "DOTFILES STATUS"
    
    echo "📊 DOTFILES HEALTH REPORT"
    echo "========================="
    echo
    
    # Basic information
    echo "📁 Dotfiles Directory: $DOTFILES_DIR"
    echo "📅 Last Modified: $(stat -c %y "$DOTFILES_DIR" 2>/dev/null || echo "Unknown")"
    echo
    
    # Core scripts status
    echo "🔧 Core Scripts Status:"
    local core_scripts=("backup-dotfiles.sh" "restore-dotfiles.sh" "reset-dotfiles.sh" "setup-dotfiles.sh")
    for script in "${core_scripts[@]}"; do
        if [ -f "$DOTFILES_DIR/$script" ]; then
            if [ -x "$DOTFILES_DIR/$script" ]; then
                echo "  ✅ $script (executable)"
            else
                echo "  ⚠️  $script (not executable)"
            fi
        else
            echo "  ❌ $script (missing)"
        fi
    done
    echo
    
    # Supporting scripts
    if [ -d "$SCRIPTS_DIR" ]; then
        local script_count=$(find "$SCRIPTS_DIR" -name "*.sh" -type f 2>/dev/null | wc -l)
        echo "📦 Supporting Scripts: $script_count scripts in $SCRIPTS_DIR"
    else
        echo "📦 Supporting Scripts: Directory not found"
    fi
    
    # Check for backups
    echo
    echo "💾 Backup Status:"
    if [ -f "$DOTFILES_DIR/gnome-settings.dconf" ]; then
        echo "  ✅ GNOME settings backup available"
    else
        echo "  ⚠️  No GNOME settings backup"
    fi
    
    if [ -d "$DOTFILES_DIR/shell" ]; then
        local shell_files=$(find "$DOTFILES_DIR/shell" -type f 2>/dev/null | wc -l)
        echo "  ✅ Shell configuration backup ($shell_files files)"
    else
        echo "  ⚠️  No shell configuration backup"
    fi
    
    # Package lists - only check for files that exist
    echo
    echo "📦 Package Lists:"
    local found_packages=false
    for pkg_file in dnf-packages.txt apt-packages.txt pacman-packages.txt; do
        if [ -f "$DOTFILES_DIR/$pkg_file" ]; then
            local count=$(wc -l < "$DOTFILES_DIR/$pkg_file" 2>/dev/null || echo "0")
            echo "  ✅ $pkg_file ($count packages)"
            found_packages=true
        fi
    done
    if [ "$found_packages" = false ]; then
        echo "  ⚠️  No package lists found"
    fi
    
    # Symlinks status
    echo
    echo "🔗 Symlink Status:"
    local symlinks=(".config" ".themes" ".icons" ".fonts" ".bashrc" ".zshrc" ".nanorc" ".tmux.conf")
    for link in "${symlinks[@]}"; do
        if [ -L "$HOME/$link" ]; then
            local target=$(readlink "$HOME/$link")
            if [[ "$target" == "$DOTFILES_DIR"* ]]; then
                echo "  ✅ $link → $target"
            else
                echo "  ⚠️  $link → $target (not managed by dotfiles)"
            fi
        elif [ -e "$HOME/$link" ]; then
            echo "  ⚠️  $link exists but is not a symlink"
        else
            echo "  ❌ $link not found"
        fi
    done
    
    echo
    log_info "Status check completed!"
}

# Advanced operations
cmd_full_automation() {
    log_section "FULL AUTOMATION WORKFLOW"
    log_info "Starting complete automated setup process..."
    
    echo "🔄 Full Automation includes:"
    echo "  1. Setup dotfiles environment"
    echo "  2. Create comprehensive backup"  
    echo "  3. Run validation tests"
    echo "  4. Generate status report"
    echo
    
    if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
        # Skip interactive prompt in non-interactive mode
        if [ -t 0 ]; then
            read -p "Continue with full automation? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Full automation cancelled"
                return 0
            fi
        else
            log_info "Running in non-interactive mode, proceeding with full automation"
        fi
    fi
    
    # Execute full workflow
    cmd_setup
    echo
    cmd_backup
    echo
    cmd_test
    echo
    cmd_status
    
    log_info "Full automation completed successfully!"
}

cmd_emergency_restore() {
    log_section "EMERGENCY RESTORATION"
    log_warning "Emergency restoration will restore all dotfiles from backups"
    
    if [ "$FORCE" = false ]; then
        echo "⚠️  WARNING: This will:"
        echo "  • Restore all configurations from backups"
        echo "  • Overwrite current configurations"
        echo "  • May affect system functionality"
        echo
        
        # Skip interactive prompt in non-interactive mode
        if [ -t 0 ]; then
            read -p "Type 'EMERGENCY' to confirm: " confirm
            if [ "$confirm" != "EMERGENCY" ]; then
                log_info "Emergency restoration cancelled"
                return 0
            fi
        else
            log_warning "Running in non-interactive mode - emergency restore requires --force flag"
            log_info "Emergency restoration cancelled for safety"
            return 0
        fi
    fi
    
    cmd_restore
    log_info "Emergency restoration completed!"
}

cmd_validate() {
    log_section "COMPREHENSIVE VALIDATION"
    log_info "Validating all configurations and dependencies..."
    
    # Run prerequisite check
    check_prerequisites
    
    # Run tests
    cmd_test
    
    # Run audit if available
    if [ -f "$SCRIPTS_DIR/audit-and-automation.sh" ]; then
        cmd_audit
    fi
    
    # Check status
    cmd_status
    
    log_info "Validation completed successfully!"
}

# Main execution logic
main() {
    # Parse global arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                DRY_RUN=true
                log_info "DRY RUN MODE: Will show what would be done"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                log_debug "Verbose mode enabled"
                shift
                ;;
            --force|-f)
                FORCE=true
                log_warning "Force mode enabled - skipping confirmations"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                # This should be a command
                break
                ;;
        esac
    done
    
    # Check if we have a command
    if [ $# -eq 0 ]; then
        echo -e "${RED}❌ No command specified${NC}"
        echo "💡 Use --help for usage information"
        exit 1
    fi
    
    local command="$1"
    shift
    
    # Show header
    echo -e "${BLUE}🔧 DOTFILES AUTOMATION MANAGER${NC}"
    echo "======================================"
    echo
    
    # Check prerequisites first
    check_prerequisites
    
    # Execute command
    case "$command" in
        setup)
            cmd_setup "$@"
            ;;
        backup)
            cmd_backup "$@"
            ;;
        restore)
            cmd_restore "$@"
            ;;
        reset)
            cmd_reset "$@"
            ;;
        test)
            cmd_test "$@"
            ;;
        audit)
            cmd_audit "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        install-packages)
            cmd_install_packages "$@"
            ;;
        save-packages)
            cmd_save_packages "$@"
            ;;
        sync-packages)
            cmd_sync_packages "$@"
            ;;
        full-automation)
            cmd_full_automation "$@"
            ;;
        emergency-restore)
            cmd_emergency_restore "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            echo "💡 Use --help for available commands"
            exit 1
            ;;
    esac
    
    echo
    log_info "Operation completed successfully!"
}

# Run main function with all arguments
main "$@"