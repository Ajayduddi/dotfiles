#!/bin/bash

# SECURITY MONITORING SCRIPT
# Monitors dotfiles for security issues and provides alerts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
DOTFILES_DIR="$HOME/.dotfiles"
REPORT_DIR="$DOTFILES_DIR/security_reports"
VERBOSE=false

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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
🔍 SECURITY MONITORING SCRIPT
============================

DESCRIPTION:
  Monitors dotfiles for security issues and provides alerts.
  Performs regular security checks and generates reports.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --verbose, -v    Enable detailed output
  --help, -h       Show this help message

FEATURES:
  ✅ Detects sensitive files
  ✅ Checks file permissions
  ✅ Monitors for suspicious changes
  ✅ Generates security reports
  ✅ Provides remediation recommendations

EXAMPLES:
  $0                    # Run standard security check
  $0 --verbose         # Run with detailed output
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
        echo -e "${BLUE}🔍 $1${NC}"
    fi
}

log_section() {
    echo -e "\n${BLUE}🔷 $1${NC}"
    echo "======================================"
}

# Function to create report directory
create_report_directory() {
    if [ ! -d "$REPORT_DIR" ]; then
        mkdir -p "$REPORT_DIR"
        chmod 700 "$REPORT_DIR"
        log_info "Created security reports directory: $REPORT_DIR"
    fi
}

# Function to check for sensitive files
check_sensitive_files() {
    log_section "CHECKING FOR SENSITIVE FILES"
    
    local report_file="$REPORT_DIR/sensitive_files_$(date +%Y%m%d).txt"
    
    echo "SENSITIVE FILES REPORT" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "========================================" >> "$report_file"
    echo "" >> "$report_file"
    
    local sensitive_patterns=(
        "*password*" "*secret*" "*token*" "*key*" "*credential*" "*auth*"
        "*.pem" "*.key" "*.p12" "*.pfx" "*.jks" "*.keystore"
        "*apikey*" "*api_key*" "*access_token*" "*refresh_token*" "*client_secret*"
        "*private*" "*confidential*" "*sensitive*"
    )
    
    local found_files=0
    
    for pattern in "${sensitive_patterns[@]}"; do
        local matches=($(find "$DOTFILES_DIR" -type f -name "$pattern" -not -path "*/\.*" 2>/dev/null || true))
        
        if [ ${#matches[@]} -gt 0 ]; then
            echo "FILES MATCHING PATTERN: $pattern" >> "$report_file"
            echo "----------------------------------------" >> "$report_file"
            
            for file in "${matches[@]}"; do
                # Skip encrypted files
                if [[ "$file" == *.gpg ]] || [[ "$file" == *.asc ]]; then
                    continue
                fi
                
                echo "  - $file" >> "$report_file"
                
                # Check file permissions
                local perms=$(stat -c "%a" "$file")
                if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
                    echo "    ⚠️  INSECURE PERMISSIONS: $perms (should be 600)" >> "$report_file"
                fi
                
                # Check if file is in .gitignore
                if ! grep -q "$(basename "$file")" "$DOTFILES_DIR/.gitignore" 2>/dev/null; then
                    echo "    ⚠️  NOT IN .GITIGNORE: Risk of accidental commit" >> "$report_file"
                fi
                
                ((found_files++))
            done
            
            echo "" >> "$report_file"
        fi
    done
    
    # Check for files with sensitive content
    local content_patterns=(
        "password[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "secret[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "token[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "key[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "apikey[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "api_key[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "access_token[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "client_secret[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY"
    )
    
    echo "FILES WITH SENSITIVE CONTENT" >> "$report_file"
    echo "----------------------------------------" >> "$report_file"
    
    for pattern in "${content_patterns[@]}"; do
        local matches=($(grep -l -r -E "$pattern" --include="*.conf" --include="*.cfg" --include="*.ini" --include="*.properties" --include="*.xml" --include="*.json" --include="*.yml" --include="*.yaml" "$DOTFILES_DIR" 2>/dev/null || true))
        
        if [ ${#matches[@]} -gt 0 ]; then
            for file in "${matches[@]}"; do
                # Skip encrypted files
                if [[ "$file" == *.gpg ]] || [[ "$file" == *.asc ]]; then
                    continue
                fi
                
                echo "  - $file" >> "$report_file"
                echo "    MATCHING PATTERN: $pattern" >> "$report_file"
                
                # Show matching lines (limited to 3)
                echo "    SAMPLE MATCHES:" >> "$report_file"
                grep -n -E "$pattern" "$file" | head -3 | while read -r line; do
                    echo "      $line" >> "$report_file"
                done
                
                # Check file permissions
                local perms=$(stat -c "%a" "$file")
                if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
                    echo "    ⚠️  INSECURE PERMISSIONS: $perms (should be 600)" >> "$report_file"
                fi
                
                # Check if file is in .gitignore
                if ! grep -q "$(basename "$file")" "$DOTFILES_DIR/.gitignore" 2>/dev/null; then
                    echo "    ⚠️  NOT IN .GITIGNORE: Risk of accidental commit" >> "$report_file"
                fi
                
                echo "" >> "$report_file"
                ((found_files++))
            done
        fi
    done
    
    echo "RECOMMENDATIONS:" >> "$report_file"
    echo "----------------------------------------" >> "$report_file"
    echo "1. Encrypt sensitive files: $DOTFILES_DIR/scripts/encrypt-sensitive.sh" >> "$report_file"
    echo "2. Set secure permissions: chmod 600 <file>" >> "$report_file"
    echo "3. Add sensitive files to .gitignore" >> "$report_file"
    echo "4. Use environment variables instead of hardcoded secrets" >> "$report_file"
    echo "5. Consider using a password manager for sensitive data" >> "$report_file"
    
    chmod 600 "$report_file"
    
    if [ $found_files -gt 0 ]; then
        log_warning "Found $found_files potentially sensitive files"
        log_info "Report saved to: $report_file"
    else
        log_info "No sensitive files found"
    fi
}

# Function to check file permissions
check_file_permissions() {
    log_section "CHECKING FILE PERMISSIONS"
    
    local report_file="$REPORT_DIR/permission_issues_$(date +%Y%m%d).txt"
    
    echo "FILE PERMISSION ISSUES REPORT" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "========================================" >> "$report_file"
    echo "" >> "$report_file"
    
    local issues_found=0
    
    # Check for world-writable files (critical)
    echo "WORLD-WRITABLE FILES (CRITICAL SECURITY RISK):" >> "$report_file"
    local world_writable=($(find "$DOTFILES_DIR" -type f -perm -002 2>/dev/null || true))
    
    if [ ${#world_writable[@]} -gt 0 ]; then
        for file in "${world_writable[@]}"; do
            local perms=$(stat -c "%a" "$file")
            echo "  - $file ($perms)" >> "$report_file"
            ((issues_found++))
        done
    else
        echo "  None found (good)" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # Check for world-writable directories (critical)
    echo "WORLD-WRITABLE DIRECTORIES (CRITICAL SECURITY RISK):" >> "$report_file"
    local world_writable_dirs=($(find "$DOTFILES_DIR" -type d -perm -002 2>/dev/null || true))
    
    if [ ${#world_writable_dirs[@]} -gt 0 ]; then
        for dir in "${world_writable_dirs[@]}"; do
            local perms=$(stat -c "%a" "$dir")
            echo "  - $dir ($perms)" >> "$report_file"
            ((issues_found++))
        done
    else
        echo "  None found (good)" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # Check for setuid/setgid files (potential risk)
    echo "SETUID/SETGID FILES (POTENTIAL SECURITY RISK):" >> "$report_file"
    local setuid_files=($(find "$DOTFILES_DIR" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null || true))
    
    if [ ${#setuid_files[@]} -gt 0 ]; then
        for file in "${setuid_files[@]}"; do
            local perms=$(stat -c "%a" "$file")
            echo "  - $file ($perms)" >> "$report_file"
            ((issues_found++))
        done
    else
        echo "  None found (good)" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # Check for sensitive files with lax permissions
    echo "SENSITIVE FILES WITH LAX PERMISSIONS:" >> "$report_file"
    local sensitive_patterns=(
        "*password*" "*secret*" "*token*" "*key*" "*credential*" "*auth*"
        "*.pem" "*.key" "*.p12" "*.pfx" "*.jks" "*.keystore"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        find "$DOTFILES_DIR" -type f -name "$pattern" 2>/dev/null | while read -r file; do
            local perms=$(stat -c "%a" "$file")
            if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
                echo "  - $file ($perms)" >> "$report_file"
                ((issues_found++))
            fi
        done
    done
    
    echo "" >> "$report_file"
    
    # Check for script files with incorrect permissions
    echo "SCRIPT FILES WITH INCORRECT PERMISSIONS:" >> "$report_file"
    find "$DOTFILES_DIR" -type f -name "*.sh" 2>/dev/null | while read -r script; do
        local perms=$(stat -c "%a" "$script")
        if [ "$perms" != "700" ] && [ "$perms" != "755" ] && [ "$perms" != "744" ]; then
            echo "  - $script ($perms)" >> "$report_file"
            ((issues_found++))
        fi
    done
    
    echo "" >> "$report_file"
    
    # Recommendations
    echo "RECOMMENDATIONS:" >> "$report_file"
    echo "----------------------------------------" >> "$report_file"
    echo "1. Fix world-writable files: chmod o-w <file>" >> "$report_file"
    echo "2. Fix world-writable directories: chmod o-w <directory>" >> "$report_file"
    echo "3. Set secure permissions for sensitive files: chmod 600 <file>" >> "$report_file"
    echo "4. Set secure permissions for scripts: chmod 700 <script>" >> "$report_file"
    echo "5. Remove setuid/setgid bits if not needed: chmod -s <file>" >> "$report_file"
    echo "6. Run permission fixing script: $DOTFILES_DIR/scripts/secure-permissions.sh" >> "$report_file"
    
    chmod 600 "$report_file"
    
    if [ $issues_found -gt 0 ]; then
        log_warning "Found $issues_found permission issues"
        log_info "Report saved to: $report_file"
    else
        log_info "No permission issues found"
    fi
}

# Function to check for suspicious changes
check_suspicious_changes() {
    log_section "CHECKING FOR SUSPICIOUS CHANGES"
    
    local report_file="$REPORT_DIR/suspicious_changes_$(date +%Y%m%d).txt"
    
    echo "SUSPICIOUS CHANGES REPORT" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "========================================" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check if git is available and repository exists
    if ! command -v git >/dev/null 2>&1 || [ ! -d "$DOTFILES_DIR/.git" ]; then
        log_warning "Git not available or not a git repository"
        echo "Git not available or not a git repository" >> "$report_file"
        echo "Cannot check for suspicious changes" >> "$report_file"
        return
    fi
    
    # Get recent changes
    echo "RECENT CHANGES (LAST 10 COMMITS):" >> "$report_file"
    echo "----------------------------------------" >> "$report_file"
    
    cd "$DOTFILES_DIR"
    git log --pretty=format:"%h %ad | %s [%an]" --date=short -10 >> "$report_file"
    
    echo "" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check for sensitive data in recent commits
    echo "POTENTIAL SENSITIVE DATA IN RECENT COMMITS:" >> "$report_file"
    echo "----------------------------------------" >> "$report_file"
    
    local sensitive_patterns=(
        "password" "secret" "token" "key" "credential" "auth"
        "apikey" "api_key" "access_token" "refresh_token" "client_secret"
    )
    
    local found_sensitive=false
    
    for pattern in "${sensitive_patterns[@]}"; do
        local matches=$(git log -p --all -10 | grep -i "$pattern" | wc -l)
        
        if [ "$matches" -gt 0 ]; then
            echo "⚠️  Found pattern '$pattern' in recent commits ($matches matches)" >> "$report_file"
            
            if [ "$VERBOSE" = true ]; then
                echo "SAMPLE MATCHES:" >> "$report_file"
                git log -p --all -10 | grep -i -A 2 -B 2 "$pattern" | head -10 >> "$report_file"
                echo "" >> "$report_file"
            fi
            
            found_sensitive=true
        fi
    done
    
    if [ "$found_sensitive" = false ]; then
        echo "No obvious sensitive data found in recent commits (good)" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # Check for unusual file types or potentially dangerous files
    echo "POTENTIALLY DANGEROUS FILES:" >> "$report_file"
    echo "----------------------------------------" >> "$report_file"
    
    local dangerous_patterns=(
        "*.exe" "*.dll" "*.so" "*.dylib" "*.bin" "*.pyc" "*.pyo"
        "*.jar" "*.war" "*.ear" "*.class" "*.o" "*.obj"
    )
    
    local found_dangerous=false
    
    for pattern in "${dangerous_patterns[@]}"; do
        local matches=($(find "$DOTFILES_DIR" -name "$pattern" 2>/dev/null || true))
        
        if [ ${#matches[@]} -gt 0 ]; then
            echo "⚠️  Found potentially dangerous files matching '$pattern':" >> "$report_file"
            
            for file in "${matches[@]}"; do
                echo "  - $file" >> "$report_file"
            done
            
            echo "" >> "$report_file"
            found_dangerous=true
        fi
    done
    
    if [ "$found_dangerous" = false ]; then
        echo "No potentially dangerous files found (good)" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # Recommendations
    echo "RECOMMENDATIONS:" >> "$report_file"
    echo "----------------------------------------" >> "$report_file"
    echo "1. If sensitive data was committed, consider using BFG Repo-Cleaner or git-filter-repo" >> "$report_file"
    echo "2. Add sensitive patterns to .gitignore to prevent future commits" >> "$report_file"
    echo "3. Use pre-commit hooks to prevent committing sensitive data" >> "$report_file"
    echo "4. Review binary files and remove if not necessary" >> "$report_file"
    echo "5. Consider using git-crypt or git-secret for encrypting sensitive files" >> "$report_file"
    
    chmod 600 "$report_file"
    
    log_info "Suspicious changes check completed"
    log_info "Report saved to: $report_file"
}

# Function to generate security summary
generate_security_summary() {
    log_section "GENERATING SECURITY SUMMARY"
    
    local summary_file="$REPORT_DIR/security_summary_$(date +%Y%m%d).txt"
    
    echo "DOTFILES SECURITY SUMMARY" > "$summary_file"
    echo "Generated: $(date)" >> "$summary_file"
    echo "========================================" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # Overall security score
    local security_score=100
    local issues_found=0
    
    # Check for critical issues
    local world_writable_count=$(find "$DOTFILES_DIR" -type f -perm -002 2>/dev/null | wc -l)
    local world_writable_dir_count=$(find "$DOTFILES_DIR" -type d -perm -002 2>/dev/null | wc -l)
    local setuid_count=$(find "$DOTFILES_DIR" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
    
    if [ $world_writable_count -gt 0 ]; then
        security_score=$((security_score - 20))
        issues_found=$((issues_found + world_writable_count))
        echo "⚠️  CRITICAL: Found $world_writable_count world-writable files" >> "$summary_file"
    fi
    
    if [ $world_writable_dir_count -gt 0 ]; then
        security_score=$((security_score - 20))
        issues_found=$((issues_found + world_writable_dir_count))
        echo "⚠️  CRITICAL: Found $world_writable_dir_count world-writable directories" >> "$summary_file"
    fi
    
    if [ $setuid_count -gt 0 ]; then
        security_score=$((security_score - 10))
        issues_found=$((issues_found + setuid_count))
        echo "⚠️  WARNING: Found $setuid_count setuid/setgid files" >> "$summary_file"
    fi
    
    # Check for sensitive files
    local sensitive_patterns=(
        "*password*" "*secret*" "*token*" "*key*" "*credential*" "*auth*"
        "*.pem" "*.key" "*.p12" "*.pfx" "*.jks" "*.keystore"
    )
    
    local sensitive_count=0
    
    for pattern in "${sensitive_patterns[@]}"; do
        local count=$(find "$DOTFILES_DIR" -type f -name "$pattern" -not -path "*/\.*" 2>/dev/null | grep -v "\.gpg$" | wc -l)
        sensitive_count=$((sensitive_count + count))
    done
    
    if [ $sensitive_count -gt 0 ]; then
        security_score=$((security_score - (sensitive_count * 2)))
        issues_found=$((issues_found + sensitive_count))
        echo "⚠️  WARNING: Found $sensitive_count potentially sensitive files" >> "$summary_file"
    fi
    
    # Check for script permissions
    local script_count=$(find "$DOTFILES_DIR" -type f -name "*.sh" 2>/dev/null | wc -l)
    local incorrect_script_count=0
    
    find "$DOTFILES_DIR" -type f -name "*.sh" 2>/dev/null | while read -r script; do
        local perms=$(stat -c "%a" "$script")
        if [ "$perms" != "700" ] && [ "$perms" != "755" ] && [ "$perms" != "744" ]; then
            incorrect_script_count=$((incorrect_script_count + 1))
        fi
    done
    
    if [ $incorrect_script_count -gt 0 ]; then
        security_score=$((security_score - (incorrect_script_count * 1)))
        issues_found=$((issues_found + incorrect_script_count))
        echo "⚠️  WARNING: Found $incorrect_script_count scripts with incorrect permissions" >> "$summary_file"
    fi
    
    # Ensure security score doesn't go below 0
    if [ $security_score -lt 0 ]; then
        security_score=0
    fi
    
    echo "" >> "$summary_file"
    echo "SECURITY SCORE: $security_score/100" >> "$summary_file"
    echo "ISSUES FOUND: $issues_found" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # Security rating
    if [ $security_score -ge 90 ]; then
        echo "RATING: EXCELLENT" >> "$summary_file"
    elif [ $security_score -ge 70 ]; then
        echo "RATING: GOOD" >> "$summary_file"
    elif [ $security_score -ge 50 ]; then
        echo "RATING: FAIR" >> "$summary_file"
    else
        echo "RATING: POOR" >> "$summary_file"
    fi
    
    echo "" >> "$summary_file"
    
    # Security recommendations
    echo "SECURITY RECOMMENDATIONS:" >> "$summary_file"
    echo "----------------------------------------" >> "$summary_file"
    echo "1. Run security hardening script: $DOTFILES_DIR/scripts/security-hardening.sh" >> "$summary_file"
    echo "2. Fix permission issues: $DOTFILES_DIR/scripts/secure-permissions.sh" >> "$summary_file"
    echo "3. Encrypt sensitive files: $DOTFILES_DIR/scripts/encrypt-sensitive.sh" >> "$summary_file"
    echo "4. Clean shell history: $DOTFILES_DIR/scripts/clean-history.sh" >> "$summary_file"
    echo "5. Review security reports in: $REPORT_DIR" >> "$summary_file"
    
    chmod 600 "$summary_file"
    
    log_info "Security summary generated: $summary_file"
    
    # Display summary
    echo ""
    echo "SECURITY SUMMARY:"
    echo "================="
    echo "Security Score: $security_score/100"
    echo "Issues Found: $issues_found"
    
    if [ $security_score -ge 90 ]; then
        echo -e "Rating: ${GREEN}EXCELLENT${NC}"
    elif [ $security_score -ge 70 ]; then
        echo -e "Rating: ${GREEN}GOOD${NC}"
    elif [ $security_score -ge 50 ]; then
        echo -e "Rating: ${YELLOW}FAIR${NC}"
    else
        echo -e "Rating: ${RED}POOR${NC}"
    fi
    
    echo ""
    echo "Reports saved to: $REPORT_DIR"
}

# Main function
main() {
    log_section "SECURITY MONITORING"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Create report directory
    create_report_directory
    
    # Run security checks
    check_sensitive_files
    check_file_permissions
    check_suspicious_changes
    
    # Generate summary
    generate_security_summary
    
    log_section "SECURITY MONITORING COMPLETE"
    log_info "All security checks completed"
    log_info "Review the reports in: $REPORT_DIR"
}

# Run the main function
main "$@"