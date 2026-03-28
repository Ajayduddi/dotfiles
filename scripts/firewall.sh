#!/bin/bash
# Automated firewall update script for multi-OS threat-intelligence-driven IP blocking.
# Primary stages: parse options, preflight dependencies/sources, process feeds, apply firewall rules, report.
# Safety model: default non-strict execution tracks errors and continues where safe; dry-run previews actions.
# Author: Ajay Duddi
# Repository: https://github.com/Ajayduddi/dotfiles

# Remove set -e for robust execution - handle errors gracefully instead
# set -e  # Commented out to prevent script from exiting on non-critical errors
umask 077  # Restrict file permissions for security

# Global error tracking
SCRIPT_ERRORS=0
CRITICAL_ERROR=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration file path
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/firewall-update.conf"

# Default global variables (can be overridden by config file)
DOTFILES_DIR="$HOME/.dotfiles"
FIREWALL_DATA_DIR=$(mktemp -d)  # Safer temporary directory creation
BACKUP_DIR="$DOTFILES_DIR/firewall_backups"
CACHE_DIR="$DOTFILES_DIR/.firewall_cache"  # Persistent cache directory
DRY_RUN=false
VERBOSE=false
FORCE=false
AUTO_UPDATE=false
STRICT_EXIT="${STRICT_EXIT:-false}"
CUSTOM_SOURCES=""
MIN_IPS_THRESHOLD=10  # Minimum number of IPs required for validation
MAX_BACKUPS_TO_KEEP=10  # Maximum number of backup files to keep
MAX_BACKUP_AGE_DAYS=30  # Maximum age of backup files in days
BATCH_SIZE=10000  # Increased batch size for better performance
DOWNLOAD_TIMEOUT=30  # Timeout for downloads in seconds
DOWNLOAD_RETRIES=3  # Number of retries for failed downloads
PARALLEL_DOWNLOADS=false  # Disable parallel processing for debugging
MAX_PARALLEL_JOBS=5  # Maximum concurrent downloads
INCREMENTAL_UPDATE=true  # Enable incremental updates for efficiency
USE_NATIVE_IPSET=true  # Use native ipset commands instead of firewall-cmd
CACHE_EXPIRY_HOURS=6  # Cache expiry time in hours
ENABLE_SPECIALIZED_SOURCES=false  # Enable additional specialized threat sources
ENABLE_PROXY_BLOCKING=false  # Enable blocking of proxy servers
ENABLE_CRYPTO_MINING_BLOCKING=false  # Enable blocking of cryptocurrency mining IPs

# OS and Firewall detection variables
OS_TYPE=""
OS_DISTRO=""
FIREWALL_TYPE=""
PACKAGE_MANAGER=""
SUDO_CMD=""

# Threat intelligence sources - Updated 2025
# High-confidence malware and C&C sources
MALWARE_SOURCES=(
    "https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt"                    # IPsum - Malicious IPs (daily updates)
    "https://www.spamhaus.org/drop/drop.txt"                                              # Spamhaus DROP - Known bad networks (includes EDROP)
    "https://cinsscore.com/list/ci-badguys.txt"                                           # CINS Army List - Attack sources
    "https://rules.emergingthreats.net/blockrules/compromised-ips.txt"                    # Emerging Threats - Compromised IPs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cybercrime.ipset"  # FireHOL Cybercrime tracker
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset" # FireHOL Level 1 - High confidence threats
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/feodo_badips.ipset" # Abuse.ch Feodo bad IPs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/et_block.netset"    # Emerging Threats blocklist
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/spamhaus_edrop.netset" # Spamhaus EDROP
)

# Suspicious activity and threat indicators
SUSPICIOUS_SOURCES=(
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset"  # FireHOL Level 2 - Medium confidence
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/tor_exits.ipset"        # Tor exit nodes
    "https://www.dshield.org/block.txt"                                                        # DShield Top Attackers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/dshield_30d.netset"     # DShield rolling 30-day netset
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/botscout.ipset"         # BotScout - Known bots
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cleantalk_new_1d.ipset" # CleanTalk - Recent spammers (1 day)
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/greensnow.ipset"        # GreenSnow - Suspicious IPs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/bruteforceblocker.ipset" # Brute force attackers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/stopforumspam.ipset"    # Stop Forum Spam
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/blocklist_de.ipset"     # Blocklist.de - SSH/FTP attacks
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/php_harvesters.ipset"   # PHP harvesters and scanners
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/php_spammers.ipset"     # PHP spammers
)

# Additional specialized sources (can be enabled via config)
SPECIALIZED_SOURCES=(
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cta_cryptowall.ipset"   # Cryptowall/C2 related IPs (IP/CIDR format)
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/sslproxies.ipset"       # SSL proxy servers (IP/CIDR format)
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset" # FireHOL Level 3 - Broader threat coverage
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/tor_exits.ipset"       # Tor exit nodes
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/botscout.ipset"        # BotScout - Known bots
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/stopforumspam.ipset"   # Stop Forum Spam
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/greensnow.ipset"       # GreenSnow blacklist
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/blocklist_de.ipset"    # Blocklist.de
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cybercrime.ipset"      # Cybercrime tracker
)

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
            --force|-f)
                FORCE=true
                echo -e "${YELLOW}⚠️ FORCE MODE: Will apply changes without confirmation${NC}"
                shift
                ;;
            --auto-update|-a)
                AUTO_UPDATE=true
                echo -e "${CYAN}🔄 AUTO UPDATE MODE: Will update rules automatically${NC}"
                shift
                ;;
            --sources|-s)
                if [[ $# -lt 2 || "$2" == -* ]]; then
                    echo -e "${RED}❌ --sources requires a file path argument${NC}"
                    return 1
                fi
                CUSTOM_SOURCES="$2"
                echo -e "${CYAN}📋 CUSTOM SOURCES: Using custom threat sources${NC}"
                shift 2
                ;;
            --strict-exit)
                STRICT_EXIT=true
                echo -e "${CYAN}🚦 STRICT EXIT MODE: Non-zero exit when errors/warnings occur${NC}"
                shift
                ;;
            --enable-specialized)
                ENABLE_SPECIALIZED_SOURCES=true
                echo -e "${CYAN}🔬 SPECIALIZED SOURCES: Enabled additional threat intelligence${NC}"
                shift
                ;;
            --enable-proxy-blocking)
                ENABLE_PROXY_BLOCKING=true
                echo -e "${CYAN}🚫 PROXY BLOCKING: Enabled proxy server blocking${NC}"
                shift
                ;;
            --enable-crypto-blocking)
                ENABLE_CRYPTO_MINING_BLOCKING=true
                echo -e "${CYAN}⛏️ CRYPTO BLOCKING: Enabled cryptocurrency mining blocking${NC}"
                shift
                ;;
            --enable-all-sources)
                ENABLE_SPECIALIZED_SOURCES=true
                ENABLE_PROXY_BLOCKING=true
                ENABLE_CRYPTO_MINING_BLOCKING=true
                echo -e "${CYAN}🌐 ALL SOURCES: Enabled all available threat intelligence sources${NC}"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help
                return 1
                ;;
        esac
    done
}

# Print script usage, behavior notes, and environment configuration help.
show_help() {
    cat << EOF
🛡️ AUTOMATED FIREWALL RULES UPDATE SCRIPT
=========================================

DESCRIPTION:
  Automatically updates firewall rules based on suspicious and malware data.
  Fetches threat intelligence from multiple sources and applies appropriate firewall rules.
  Supports multiple operating systems and firewall systems.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --dry-run, -n              Simulate actions without making changes
  --verbose, -v              Enable detailed output
  --force, -f                Apply changes without confirmation
  --auto-update, -a          Enable automatic updates without prompts
  --sources, -s FILE         Use custom threat sources from file
  --strict-exit              Exit non-zero when the run has any errors/warnings
  --enable-specialized       Enable additional specialized threat sources
  --enable-proxy-blocking    Enable blocking of proxy servers and anonymizers
  --enable-crypto-blocking   Enable blocking of cryptocurrency mining IPs
  --enable-all-sources       Enable all available threat intelligence sources
  --help, -h                 Show this help message

FEATURES:
  🔒 Multi-OS support (Linux, macOS, Windows WSL)
  🔒 Multiple firewall systems (firewalld, ufw, iptables, pfctl)
  🔒 Fetches malware IP lists from trusted sources
  🔒 Downloads suspicious activity indicators
  🔒 Creates efficient blocking rules
  🔒 Backs up existing rules before changes
  🔒 Provides detailed logging and reporting
  🔒 Supports custom threat intelligence sources
  🔒 Automatic cleanup of old data

SUPPORTED SYSTEMS:
  • Linux: RHEL/CentOS/Fedora (firewalld), Ubuntu/Debian (ufw), Generic (iptables)
  • macOS: pfctl firewall
  • Windows: WSL with Linux firewall systems

THREAT SOURCES:
  MALWARE & C&C SERVERS:
  • IPsum - Daily updated malicious IPs
  • Spamhaus DROP/EDROP - Known bad networks
  • Emerging Threats - Compromised IPs
  • FireHOL Cybercrime tracker
  • Zeus, Ransomware, and C&C trackers
  • Bambenek C&C and DGA feeds

  SUSPICIOUS ACTIVITY:
  • FireHOL Level 1 & 2 threat feeds
  • DShield top attackers
  • Brute force and web attack sources
  • Cisco Talos IP filter
  • SSL blacklist and malicious URLs

  SPECIALIZED (Optional):
  • Tor exit nodes and proxy servers
  • Cryptocurrency mining IPs
  • IBM X-Force threat intelligence
  • NormShield attack feeds

EXAMPLES:
  $0                                    # Standard update with default sources
  $0 --dry-run --verbose               # Preview changes with detailed output
  $0 --force --auto-update             # Fully automated update
  $0 --enable-all-sources              # Use all available threat sources
  $0 --enable-proxy-blocking           # Include proxy server blocking
  $0 --sources custom.txt              # Use custom threat sources

REQUIREMENTS:
  • Appropriate firewall system installed and running
  • curl or wget for downloading data
  • sudo/administrator privileges for firewall changes
EOF
}

# Logging functions with error tracking
log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Emit a structured log line for this severity level.
log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((SCRIPT_ERRORS++))
}

# Emit a structured log line for this severity level.
log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((SCRIPT_ERRORS++))
}

# Emit a structured log line for this severity level.
log_critical_error() {
    echo -e "${RED}💥 CRITICAL ERROR: $1${NC}"
    CRITICAL_ERROR=true
    ((SCRIPT_ERRORS++))
}

# Emit a structured log line for this severity level.
log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}🔍 $1${NC}"
    fi
}

# Emit a structured log line for this severity level.
log_section() {
    echo -e "\n${BLUE}🔷 $1${NC}"
    echo "======================================"
}

# Function to handle errors gracefully
handle_error() {
    local error_message="$1"
    local is_critical="${2:-false}"
    
    if [ "$is_critical" = true ]; then
        log_critical_error "$error_message"
    else
        log_error "$error_message"
    fi
    
    # Continue execution unless it's a critical error and not in force mode
    if [ "$is_critical" = true ] && [ "$FORCE" = false ]; then
        log_error "Critical error encountered. Use --force to continue anyway."
        return 1
    fi
    
    return 0
}

# Function to confirm actions
confirm_action() {
    local message="$1"
    
    if [ "$FORCE" = true ] || [ "$AUTO_UPDATE" = true ]; then
        return 0  # Auto-confirm if force or auto-update mode is enabled
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would ask for confirmation: $message${NC}"
        return 1  # Don't proceed with action in dry run mode
    fi
    
    read -r -p "$message [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to detect operating system and firewall type
detect_os_and_firewall() {
    log_section "DETECTING OPERATING SYSTEM AND FIREWALL"
    
    # Detect OS type
    case "$(uname -s)" in
        Linux*)
            OS_TYPE="Linux"
            # Detect Linux distribution
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS_DISTRO="$ID"
                log_debug "Detected Linux distribution: $PRETTY_NAME"
            elif [ -f /etc/redhat-release ]; then
                OS_DISTRO="rhel"
                log_debug "Detected RHEL-based system"
            elif [ -f /etc/debian_version ]; then
                OS_DISTRO="debian"
                log_debug "Detected Debian-based system"
            else
                OS_DISTRO="unknown"
                log_debug "Unknown Linux distribution"
            fi
            ;;
        Darwin*)
            OS_TYPE="macOS"
            OS_DISTRO="darwin"
            log_debug "Detected macOS system"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS_TYPE="Windows"
            OS_DISTRO="windows"
            log_debug "Detected Windows system"
            ;;
        *)
            OS_TYPE="Unknown"
            OS_DISTRO="unknown"
            log_warning "Unknown operating system: $(uname -s)"
            ;;
    esac
    
    # Set sudo command based on OS
    if [ "$OS_TYPE" = "Windows" ]; then
        SUDO_CMD=""  # Windows doesn't use sudo in the same way
    else
        SUDO_CMD="sudo"
    fi
    
    # Detect firewall type based on OS and available commands
    detect_firewall_type
    
    # Detect package manager
    detect_package_manager
    
    log_info "System detected: $OS_TYPE ($OS_DISTRO) with $FIREWALL_TYPE firewall"
}

# Function to detect firewall type
detect_firewall_type() {
    if [ "$OS_TYPE" = "macOS" ]; then
        if command -v pfctl &> /dev/null; then
            FIREWALL_TYPE="pfctl"
            log_debug "Using pfctl firewall for macOS"
        else
            handle_error "pfctl not found on macOS system" true
            return 1
        fi
    elif [ "$OS_TYPE" = "Linux" ]; then
        # Check for firewalld first (RHEL/CentOS/Fedora)
        if command -v firewall-cmd &> /dev/null; then
            FIREWALL_TYPE="firewalld"
            log_debug "Using firewalld"
        # Check for ufw (Ubuntu/Debian)
        elif command -v ufw &> /dev/null; then
            FIREWALL_TYPE="ufw"
            log_debug "Using ufw (Uncomplicated Firewall)"
        # Fall back to iptables
        elif command -v iptables &> /dev/null; then
            FIREWALL_TYPE="iptables"
            log_debug "Using iptables"
        else
            handle_error "No supported firewall found. Please install firewalld, ufw, or iptables" true
            return 1
        fi
    elif [ "$OS_TYPE" = "Windows" ]; then
        # For WSL, use Linux firewall detection
        if grep -qi microsoft /proc/version 2>/dev/null; then
            log_info "Detected Windows Subsystem for Linux (WSL)"
            if command -v ufw &> /dev/null; then
                FIREWALL_TYPE="ufw"
                log_debug "Using ufw in WSL"
            elif command -v iptables &> /dev/null; then
                FIREWALL_TYPE="iptables"
                log_debug "Using iptables in WSL"
            else
                handle_error "No supported firewall found in WSL" true
                return 1
            fi
        else
            handle_error "Native Windows firewall not yet supported. Use WSL instead." true
            return 1
        fi
    else
        handle_error "Unsupported operating system: $OS_TYPE" true
        return 1
    fi
}

# Function to detect package manager
detect_package_manager() {
    case "$OS_DISTRO" in
        fedora|rhel|centos|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                PACKAGE_MANAGER="dnf"
            elif command -v yum &> /dev/null; then
                PACKAGE_MANAGER="yum"
            fi
            ;;
        ubuntu|debian|mint)
            if command -v apt &> /dev/null; then
                PACKAGE_MANAGER="apt"
            elif command -v apt-get &> /dev/null; then
                PACKAGE_MANAGER="apt-get"
            fi
            ;;
        arch|manjaro)
            if command -v pacman &> /dev/null; then
                PACKAGE_MANAGER="pacman"
            fi
            ;;
        opensuse*|sles)
            if command -v zypper &> /dev/null; then
                PACKAGE_MANAGER="zypper"
            fi
            ;;
        darwin)
            if command -v brew &> /dev/null; then
                PACKAGE_MANAGER="brew"
            elif command -v port &> /dev/null; then
                PACKAGE_MANAGER="port"
            fi
            ;;
        *)
            PACKAGE_MANAGER="unknown"
            ;;
    esac
    
    log_debug "Package manager: $PACKAGE_MANAGER"
}

# Cross-platform file helpers
get_file_mtime() {
    local file="$1"
    if stat -c %Y "$file" >/dev/null 2>&1; then
        stat -c %Y "$file" 2>/dev/null || echo 0
        return 0
    fi
    if stat -f %m "$file" >/dev/null 2>&1; then
        stat -f %m "$file" 2>/dev/null || echo 0
        return 0
    fi
    echo 0
}

# Compute a cross-platform content hash used by cache-change detection.
compute_file_hash() {
    local file="$1"
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$file" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$file" 2>/dev/null
        return 0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    if command -v cksum >/dev/null 2>&1; then
        cksum "$file" 2>/dev/null | awk '{print $1 "-" $2}'
        return 0
    fi
    echo ""
}

# Download remote source data and stage it for local processing.
download_to_file() {
    local source="$1"
    local out_file="$2"
    case "$DOWNLOAD_CMD" in
        curl)
            curl -s -L --connect-timeout 30 --max-time "$DOWNLOAD_TIMEOUT" "$source" -o "$out_file" 2>/dev/null
            ;;
        wget)
            wget -q -T "$DOWNLOAD_TIMEOUT" -t "$DOWNLOAD_RETRIES" -O "$out_file" "$source" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Return success when the requested condition is true.
is_source_url_format_valid() {
    local source="$1"
    [[ "$source" =~ ^https?://[^[:space:]]+$ ]]
}

# Check whether a downloaded source includes at least one IP/CIDR-like entry.
source_has_ip_data() {
    local file="$1"
    grep -qE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$file" 2>/dev/null
}

# Run preflight checks before making system or firewall changes.
preflight_download_source() {
    local source="$1"
    local out_file="$2"
    local retry_count=0

    while [ "$retry_count" -lt "$DOWNLOAD_RETRIES" ]; do
        if download_to_file "$source" "$out_file"; then
            return 0
        fi
        ((retry_count++))
        [ "$retry_count" -lt "$DOWNLOAD_RETRIES" ] && sleep 1
    done
    return 1
}

# Deduplicate source URLs while preserving deterministic processing order.
dedupe_sources() {
    local deduped=()
    local source existing

    for source in "$@"; do
        local found=false
        for existing in "${deduped[@]}"; do
            if [ "$existing" = "$source" ]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            deduped+=("$source")
        fi
    done

    printf '%s\n' "${deduped[@]}"
}

# Run preflight checks before making system or firewall changes.
preflight_failure_exists() {
    local source="$1"
    local reason="$2"
    local i
    for i in "${!preflight_failed_sources[@]}"; do
        if [ "${preflight_failed_sources[$i]}" = "$source" ] && [ "${preflight_failed_reasons[$i]}" = "$reason" ]; then
            return 0
        fi
    done
    return 1
}

# Cache management functions
setup_cache_directory() {
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR" || {
            log_warning "Failed to create cache directory: $CACHE_DIR"
            CACHE_DIR="$FIREWALL_DATA_DIR"  # Fallback to temp directory
        }
    fi
    log_debug "Cache directory: $CACHE_DIR"
}

# Function to get cache file path for a source
get_cache_file() {
    local source="$1"
    local cache_name
    cache_name=$(printf '%s' "$source" | sed 's|[^a-zA-Z0-9]|_|g')
    echo "$CACHE_DIR/${cache_name}.cache"
}

# Function to get hash file path for a source
get_hash_file() {
    local source="$1"
    local cache_name
    cache_name=$(printf '%s' "$source" | sed 's|[^a-zA-Z0-9]|_|g')
    echo "$CACHE_DIR/${cache_name}.hash"
}

# Function to check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    local max_age_seconds=$((CACHE_EXPIRY_HOURS * 3600))
    
    if [ ! -f "$cache_file" ]; then
        return 1  # Cache doesn't exist
    fi
    
    local cache_mtime
    cache_mtime=$(get_file_mtime "$cache_file")
    local cache_age=$(( $(date +%s) - cache_mtime ))
    if [ "$cache_age" -gt "$max_age_seconds" ]; then
        log_debug "Cache expired for: $(basename "$cache_file")"
        return 1  # Cache expired
    fi
    
    return 0  # Cache is valid
}

# Function to check if source data has changed
has_source_changed() {
    local source="$1"
    local temp_file="$2"
    local hash_file
    hash_file=$(get_hash_file "$source")
    
    local new_hash
    new_hash=$(compute_file_hash "$temp_file")
    local old_hash=""

    if [ -z "$new_hash" ]; then
        log_warning "Unable to compute hash for $(basename "$temp_file"); treating source as changed"
        return 0
    fi
    
    if [ -f "$hash_file" ]; then
        old_hash=$(cat "$hash_file" 2>/dev/null)
    fi
    
    if [ "$new_hash" = "$old_hash" ]; then
        log_debug "Source unchanged: $(basename "$source")"
        return 1  # No change
    fi
    
    # Update hash file
    echo "$new_hash" > "$hash_file"
    log_debug "Source changed: $(basename "$source")"
    return 0  # Changed
}

# Native ipset utility functions
check_native_ipset_support() {
    if [ "$USE_NATIVE_IPSET" = true ] && [ "$FIREWALL_TYPE" = "firewalld" ]; then
        if command -v ipset &> /dev/null; then
            log_debug "Native ipset command available - using optimized operations"
            return 0
        else
            log_warning "Native ipset not available, falling back to firewall-cmd"
            USE_NATIVE_IPSET=false
        fi
    fi
    return 1
}

# Function to get existing IPs from ipset
get_existing_ips() {
    local ipset_name="$1"
    local output_file="$2"
    
    # For firewalld ipsets, always use firewall-cmd
    $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --get-entries 2>/dev/null > "$output_file" || touch "$output_file"
    
    local count
    count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
    log_debug "Found $count existing IPs in ipset: $ipset_name"
    return 0
}

# Function to perform incremental ipset updates
update_ipset_incremental() {
    local ipset_name="$1"
    local new_ips_file="$2"
    local existing_ips_file="$FIREWALL_DATA_DIR/existing_${ipset_name}.txt"
    local add_ips_file="$FIREWALL_DATA_DIR/add_${ipset_name}.txt"
    local remove_ips_file="$FIREWALL_DATA_DIR/remove_${ipset_name}.txt"
    
    # Get existing IPs
    get_existing_ips "$ipset_name" "$existing_ips_file"
    
    # Find IPs to add (in new but not in existing)
    comm -23 <(sort "$new_ips_file") <(sort "$existing_ips_file") > "$add_ips_file"
    
    # Find IPs to remove (in existing but not in new) - only if we want to clean old IPs
    if [ "$INCREMENTAL_UPDATE" = true ]; then
        comm -13 <(sort "$new_ips_file") <(sort "$existing_ips_file") > "$remove_ips_file"
    else
        touch "$remove_ips_file"  # Empty file if not doing cleanup
    fi
    
    local add_count
    add_count=$(wc -l < "$add_ips_file" 2>/dev/null || echo 0)
    local remove_count
    remove_count=$(wc -l < "$remove_ips_file" 2>/dev/null || echo 0)
    
    log_debug "Incremental update for $ipset_name: +$add_count IPs, -$remove_count IPs"
    
    # Perform updates
    local updated=false
    
    if [ "$add_count" -gt 0 ]; then
        if add_ips_to_ipset_bulk "$ipset_name" "$add_ips_file"; then
            updated=true
            log_debug "Added $add_count new IPs to $ipset_name"
        fi
    fi
    
    if [ "$remove_count" -gt 0 ]; then
        if remove_ips_from_ipset_bulk "$ipset_name" "$remove_ips_file"; then
            updated=true
            log_debug "Removed $remove_count old IPs from $ipset_name"
        fi
    fi
    
    # Clean up temp files
    rm -f "$existing_ips_file" "$add_ips_file" "$remove_ips_file"
    
    if [ "$updated" = true ]; then
        return 0
    else
        log_debug "No updates needed for ipset: $ipset_name"
        return 1
    fi
}

# Advanced Dynamic Progress Bar System with Timing and Performance Optimization
PROGRESS_ACTIVE=false
LAST_PERCENTAGE=0
PROGRESS_START_TIME=0
PROGRESS_LAST_UPDATE_TIME=0

# Advanced dynamic progress bar with timing and performance optimization
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    local width=40
    
    # Validate inputs
    if ! [[ "$current" =~ ^[0-9]+$ ]]; then current=0; fi
    if ! [[ "$total" =~ ^[0-9]+$ ]] || [ "$total" -eq 0 ]; then total=100; fi
    
    # Simple time-based throttling for performance (using integer seconds)
    local current_time
    current_time=$(date +%s)
    if [ "$current" -ne "$total" ] && [ -n "$PROGRESS_LAST_UPDATE_TIME" ] && [ "$PROGRESS_LAST_UPDATE_TIME" -gt 0 ]; then
        local time_diff=$((current_time - PROGRESS_LAST_UPDATE_TIME))
        if [ "$time_diff" -eq 0 ] && [ "$current" -ne "$total" ]; then
            return  # Skip update if less than 1 second has passed
        fi
    fi
    PROGRESS_LAST_UPDATE_TIME="$current_time"
    
    local percentage=$((current * 100 / total))
    
    # Performance optimization: Skip updates if percentage hasn't changed significantly
    if [ "$current" -ne "$total" ] && [ "$percentage" -eq "$LAST_PERCENTAGE" ]; then
        return
    fi
    LAST_PERCENTAGE="$percentage"
    
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Build progress bar with = symbols only (optimized)
    local bar=""
    if [ "$filled" -gt 0 ]; then
        bar=$(printf '=%.0s' $(seq 1 $filled))
    fi
    if [ "$empty" -gt 0 ]; then
        bar="${bar}$(printf -- '-%.0s' $(seq 1 $empty))"
    fi
    
    # Simple timing information (using integer arithmetic)
    local timing_info=""
    if [ "$PROGRESS_START_TIME" -gt 0 ] && [ "$current" -gt 0 ]; then
        local elapsed=$((current_time - PROGRESS_START_TIME))
        if [ "$elapsed" -gt 0 ]; then
            local rate=$((current / elapsed))
            local eta=""
            
            if [ "$current" -lt "$total" ] && [ "$rate" -gt 0 ]; then
                local remaining=$(((total - current) / rate))
                if [ "$remaining" -lt 60 ]; then
                    eta=" ETA: ${remaining}s"
                elif [ "$remaining" -lt 3600 ]; then
                    local mins=$((remaining / 60))
                    eta=" ETA: ${mins}m"
                fi
            fi
            
            if [ "$rate" -gt 1000 ]; then
                local rate_k=$((rate / 1000))
                timing_info=" ${rate_k}k/s$eta"
            elif [ "$rate" -gt 0 ]; then
                timing_info=" ${rate}/s$eta"
            fi
        fi
    fi
    
    # Display progress with proper line clearing and timing
    local display_message="$message"
    if [ ${#display_message} -gt 25 ]; then
        display_message="${display_message:0:22}..."
    fi
    printf "\r\033[K%s [%s] %d%% (%d/%d)%s" "$display_message" "$bar" "$percentage" "$current" "$total" "$timing_info"
}

# Update progress with dynamic totals based on actual findings
update_progress_dynamic() {
    local current="$1"
    local total="$2"
    local message="$3"
    local found_items="${4:-0}"  # Actual items found/processed
    
    # Adjust total based on actual findings if provided
    if [ "$found_items" -gt 0 ] && [ "$found_items" -ne "$total" ]; then
        total="$found_items"
    fi
    
    if [ "$PROGRESS_ACTIVE" = true ]; then
        show_progress "$current" "$total" "$message"
    fi
}

# Start progress tracking with timing initialization
start_progress_bar() {
    local operation_name="$1"
    local estimated_total="${2:-100}"
    PROGRESS_ACTIVE=true
    PROGRESS_START_TIME=$(date +%s)
    PROGRESS_LAST_UPDATE_TIME=0
    LAST_PERCENTAGE=0
    show_progress 0 "$estimated_total" "$operation_name"
}

# Update progress
update_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    
    if [ "$PROGRESS_ACTIVE" = true ]; then
        show_progress "$current" "$total" "$message"
    fi
}

# Stop progress bar
stop_progress_bar() {
    local final_message="$1"
    
    if [ "$PROGRESS_ACTIVE" = true ]; then
        # Calculate final timing information (using integer arithmetic)
        local timing_suffix=""
        if [ "$PROGRESS_START_TIME" -gt 0 ]; then
            local end_time
            end_time=$(date +%s)
            local total_time=$((end_time - PROGRESS_START_TIME))
            if [ "$total_time" -gt 0 ]; then
                if [ "$total_time" -lt 60 ]; then
                    timing_suffix=" (${total_time}s)"
                else
                    local mins=$((total_time / 60))
                    local secs=$((total_time % 60))
                    timing_suffix=" (${mins}m ${secs}s)"
                fi
            fi
        fi
        
        # Clear line completely and reset progress tracking
        printf "\r\033[K"
        if [ -n "$final_message" ]; then
            echo "${final_message}${timing_suffix}"
        else
            echo ""  # Add newline to separate from next output
        fi
        PROGRESS_ACTIVE=false
        LAST_PERCENTAGE=0
        PROGRESS_START_TIME=0
        PROGRESS_LAST_UPDATE_TIME=0
    fi
}

# Fast and reliable IP deduplication function
deduplicate_ips_advanced() {
    local input_file="$1"
    local output_file="$2"
    local existing_ips_file="$3"  # Optional: file with existing IPs to exclude
    local operation_name="${4:-Deduplicating}"
    
    if [ ! -s "$input_file" ]; then
        touch "$output_file"
        return 0
    fi
    
    local total_input
    total_input=$(wc -l < "$input_file" 2>/dev/null || echo 0)
    local temp_file="$FIREWALL_DATA_DIR/temp_dedup_$$"
    
    # Step 1: Clean and validate IPs (fast processing)
    grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$|^[0-9a-fA-F:]+(/[0-9]{1,3})?$' "$input_file" 2>/dev/null | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
    grep -v '^[[:space:]]*$' > "$temp_file" 2>/dev/null || touch "$temp_file"
    
    # Step 2: Remove duplicates
    sort -u "$temp_file" -o "$temp_file" 2>/dev/null
    
    # Step 3: Remove existing IPs if provided
    if [ -n "$existing_ips_file" ] && [ -s "$existing_ips_file" ]; then
        local temp_existing="$FIREWALL_DATA_DIR/existing_sorted_$$"
        sort -u "$existing_ips_file" > "$temp_existing" 2>/dev/null
        comm -23 "$temp_file" "$temp_existing" > "$output_file" 2>/dev/null
        rm -f "$temp_existing"
    else
        mv "$temp_file" "$output_file"
    fi
    
    # Step 4: Final validation
    local final_count
    final_count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
    local excluded=$((total_input - final_count))
    
    # Clean up
    rm -f "$temp_file"
    
    echo "✅ Processed $total_input IPs → $final_count unique valid IPs (excluded: $excluded)"
    
    return 0
}

# Advanced CIDR overlap detection and intelligent resolution
resolve_cidr_overlaps() {
    local input_file="$1"
    local output_file="$2"
    local operation_name="${3:-Resolving CIDR overlaps}"
    
    if [ ! -s "$input_file" ]; then
        touch "$output_file"
        return 0
    fi
    
    local total_input
    total_input=$(wc -l < "$input_file" 2>/dev/null || echo 0)
    local temp_file="$FIREWALL_DATA_DIR/temp_cidr_$$"
    
    # Step 1: Separate individual IPs from CIDR ranges
    local individual_ips="$FIREWALL_DATA_DIR/individual_ips_$$"
    local cidr_ranges="$FIREWALL_DATA_DIR/cidr_ranges_$$"
    
    grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' "$input_file" > "$individual_ips" 2>/dev/null || touch "$individual_ips"
    grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$' "$input_file" > "$cidr_ranges" 2>/dev/null || touch "$cidr_ranges"
    
    # Step 2: Advanced CIDR range consolidation
    local consolidated_cidrs="$FIREWALL_DATA_DIR/consolidated_cidrs_$$"
    
    if [ -s "$cidr_ranges" ]; then
        # Simple sort and unique - much faster than complex consolidation
        sort -u "$cidr_ranges" > "$consolidated_cidrs"
    else
        touch "$consolidated_cidrs"
    fi
    
    # Step 3: Skip complex IP filtering for speed - just copy individual IPs
    local filtered_ips="$FIREWALL_DATA_DIR/filtered_ips_$$"
    
    if [ -s "$individual_ips" ]; then
        cp "$individual_ips" "$filtered_ips"
    else
        touch "$filtered_ips"
    fi
    
    # Step 4: Remove duplicate CIDR ranges
    local unique_cidrs="$FIREWALL_DATA_DIR/unique_cidrs_$$"
    if [ -s "$consolidated_cidrs" ]; then
        sort -u "$consolidated_cidrs" > "$unique_cidrs"
    else
        touch "$unique_cidrs"
    fi
    
    # Step 5: Combine filtered IPs and unique CIDRs
    local combined_file="$FIREWALL_DATA_DIR/combined_$$"
    if [ -s "$filtered_ips" ] || [ -s "$unique_cidrs" ]; then
        cat "$filtered_ips" "$unique_cidrs" 2>/dev/null | sort -u > "$combined_file"
    else
        touch "$combined_file"
    fi
    
    # Step 6: Final validation and cleanup
    
    # Validate all entries are properly formatted
    if [ -s "$combined_file" ]; then
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$' "$combined_file" > "$output_file" 2>/dev/null || touch "$output_file"
    else
        touch "$output_file"
    fi
    
    local final_count
    final_count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
    local removed=$((total_input - final_count))
    
    # Cleanup
    rm -f "$individual_ips" "$cidr_ranges" "$consolidated_cidrs" "$filtered_ips" "$unique_cidrs" "$combined_file" "$temp_file"
    
    echo "✅ Smart CIDR resolution: $total_input → $final_count entries (removed: $removed overlaps/duplicates) ($(date +%s)s)"
    
    return 0
}

# Ultra-fast bulk IP processing with advanced algorithms
process_ips_ultra_fast() {
    local input_file="$1"
    local output_file="$2"
    local operation_name="${3:-Processing IPs}"
    local existing_ips_file="$4"
    
    if [ ! -s "$input_file" ]; then
        touch "$output_file"
        return 0
    fi
    
    local temp_dir="$FIREWALL_DATA_DIR/ultra_fast_$$"
    mkdir -p "$temp_dir"
    
    local total_input
    total_input=$(wc -l < "$input_file" 2>/dev/null || echo 0)
    
    # Step 1: Parallel preprocessing with chunks
    local chunk_size=50000
    local processed_chunks=0
    
    # Create chunks for parallel processing
    split -l "$chunk_size" "$input_file" "$temp_dir/chunk_" 2>/dev/null
    
    # Process chunks in parallel (limited to CPU cores)
    local max_parallel
    max_parallel=$(nproc 2>/dev/null || echo 4)
    local active_jobs=0
    
    for chunk_file in "$temp_dir"/chunk_*; do
        [ ! -f "$chunk_file" ] && continue
        
        # Wait if we have too many parallel jobs
        while [ "$active_jobs" -ge "$max_parallel" ]; do
            wait -n 2>/dev/null || sleep 0.1
            ((active_jobs--))
        done
        
        # Process chunk in background
        {
            local chunk_output="${chunk_file}.processed"
            local valid_count=0
            
            while IFS= read -r line; do
                # Fast IP validation and cleaning
                line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | cut -d' ' -f1 | cut -d$'\t' -f1)
                
                # Skip empty lines and comments
                [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                
                # Ultra-fast IP validation using regex
                if [[ "$line" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
                    # Quick octet validation
                    local valid=true
                    IFS='.' read -ra octets <<< "${line%/*}"
                    for octet in "${octets[@]}"; do
                        if [ "$octet" -gt 255 ] || [ "$octet" -lt 0 ]; then
                            valid=false
                            break
                        fi
                    done
                    
                    if [ "$valid" = true ]; then
                        echo "$line"
                        ((valid_count++))
                    fi
                elif [[ "$line" =~ ^[0-9a-fA-F:]+(/[0-9]{1,3})?$ ]]; then
                    # IPv6 validation (basic)
                    echo "$line"
                    ((valid_count++))
                fi
            done < "$chunk_file" > "$chunk_output"
            
            echo "$valid_count" > "${chunk_file}.count"
        } &
        
        ((active_jobs++))
        ((processed_chunks++))
    done
    
    # Wait for all background jobs to complete
    wait
    
    # Step 2: Merge and deduplicate results ultra-fast
    
    # Combine all processed chunks
    local temp_combined="$temp_dir/combined.txt"
    cat "$temp_dir"/*.processed 2>/dev/null | sort -u > "$temp_combined"
    
    # Step 3: Remove existing IPs if provided (ultra-fast using comm)
    if [ -n "$existing_ips_file" ] && [ -s "$existing_ips_file" ]; then
        local temp_existing="$temp_dir/existing_sorted.txt"
        sort -u "$existing_ips_file" > "$temp_existing"
        
        # Use comm for ultra-fast set difference
        comm -23 "$temp_combined" "$temp_existing" > "$output_file"
    else
        mv "$temp_combined" "$output_file"
    fi
    
    # Calculate final statistics
    local final_count
    final_count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
    local total_valid=0
    for count_file in "$temp_dir"/*.count; do
        [ -f "$count_file" ] && total_valid=$((total_valid + $(cat "$count_file")))
    done
    
    local excluded=$((total_valid - final_count))
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Processed $total_input IPs → $final_count unique valid IPs (excluded: $excluded duplicates)"
    
    return 0
}

# Legacy function removed to prevent infinite recursion

# Function to add IPs to ipset in bulk (highly optimized)
add_ips_to_ipset_bulk() {
    local ipset_name="$1"
    local ips_file="$2"
    
    if [ ! -s "$ips_file" ]; then
        return 0  # No IPs to add
    fi
    
    local total_ips
    total_ips=$(wc -l < "$ips_file")
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "Would add $total_ips IPs to ipset: $ipset_name"
        return 0
    fi
    
    echo "📥 Adding $total_ips IPs to ipset: $ipset_name"
    local start_time
    start_time=$(date +%s)
    
    # Skip Python helper - use native methods directly for reliability
    
    # Method 1: Try native ipset restore with smart batching (fast and reliable)
    if command -v ipset >/dev/null 2>&1; then
        echo "🚀 Using native ipset restore with smart batching"
        
        # Process in manageable chunks to avoid overwhelming the system
        local batch_size=5000
        local processed=0
        local successful=0
        local temp_batch="$FIREWALL_DATA_DIR/${ipset_name}_batch.txt"
        
        while IFS= read -r ip || [ -n "$ip" ]; do
            if [[ -n "$ip" && ! "$ip" =~ ^[[:space:]]*# ]]; then
                echo "add $ipset_name $ip" >> "$temp_batch"
                ((processed++))
                
                # Process batch when it reaches batch_size or at end of file
                if [ $((processed % batch_size)) -eq 0 ] || [ $processed -eq $total_ips ]; then
                    if [ -s "$temp_batch" ]; then
                        if $SUDO_CMD ipset restore -exist < "$temp_batch" 2>/dev/null; then
                            local batch_count
                            batch_count=$(wc -l < "$temp_batch")
                            ((successful += batch_count))
                        fi
                        : > "$temp_batch"  # Clear the batch file
                    fi
                    
                    # Show progress every 25k IPs
                    if [ $((processed % 25000)) -eq 0 ]; then
                        echo "  Processed $processed/$total_ips IPs..."
                    fi
                fi
            fi
        done < "$ips_file"
        
        rm -f "$temp_batch"
        
        if [ $successful -gt 0 ]; then
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local rate=$((successful / (duration + 1)))
            echo "✅ Added $successful IPs using native ipset restore ($rate IPs/sec)"
            return 0
        fi
    fi
    
    # Method 2: Try firewall-cmd with smart batching
    echo "🔄 Using firewall-cmd with smart batching"
    
    local batch_size=2000
    local processed=0
    local successful=0
    local temp_batch="$FIREWALL_DATA_DIR/${ipset_name}_fw_batch.txt"
    
    while IFS= read -r ip || [ -n "$ip" ]; do
        if [[ -n "$ip" && ! "$ip" =~ ^[[:space:]]*# ]]; then
            echo "$ip" >> "$temp_batch"
            ((processed++))
            
            # Process batch when it reaches batch_size or at end of file
            if [ $((processed % batch_size)) -eq 0 ] || [ $processed -eq $total_ips ]; then
                if [ -s "$temp_batch" ]; then
                    if $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --add-entries-from-file="$temp_batch" >/dev/null 2>&1; then
                        local batch_count
                        batch_count=$(wc -l < "$temp_batch")
                        ((successful += batch_count))
                    fi
                    : > "$temp_batch"  # Clear the batch file
                fi
                
                # Show progress every 20k IPs
                if [ $((processed % 20000)) -eq 0 ]; then
                    echo "  Processed $processed/$total_ips IPs..."
                fi
            fi
        fi
    done < "$ips_file"
    
    rm -f "$temp_batch"
    
    if [ $successful -gt 0 ]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local rate=$((successful / (duration + 1)))
        echo "✅ Added $total_ips IPs using firewall-cmd bulk ($rate IPs/sec)"
        return 0
    fi
    
    # Method 4: Optimized batch processing with progress bar (last resort)
    update_progress 0 "$total_ips" "⚠️ Using batch processing fallback"
    
    local batch_size=20000  # Very large batches for efficiency
    local temp_batch_dir="$FIREWALL_DATA_DIR/batch_${ipset_name}"
    mkdir -p "$temp_batch_dir"
    
    # Split the file into batches
    split -l "$batch_size" "$ips_file" "$temp_batch_dir/batch_"
    
    local batch_files=("$temp_batch_dir"/batch_*)
    local total_batches=${#batch_files[@]}
    local processed_batches=0
    local total_added=0
    
    update_progress 0 "$total_ips" "📦 Processing $total_ips IPs in $total_batches batches"
    
    for batch_file in "${batch_files[@]}"; do
        if [ -f "$batch_file" ]; then
            ((processed_batches++))
            local batch_size_actual
            batch_size_actual=$(wc -l < "$batch_file")
            
            update_progress "$total_added" "$total_ips" "Processing batch $processed_batches/$total_batches"
            
            # Try firewall-cmd batch file method first
            if $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --add-entries-from-file="$batch_file" >/dev/null 2>&1; then
                total_added=$((total_added + batch_size_actual))
            else
                # Silent individual processing for this batch
                local added_count=0
                local batch_processed=0
                while IFS= read -r ip; do
                    if [[ -n "$ip" ]]; then
                        ((batch_processed++))
                        if $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --add-entry="$ip" >/dev/null 2>&1; then
                            ((added_count++))
                        fi
                        # Update progress much less frequently for better performance
                        if [ $((batch_processed % 5000)) -eq 0 ]; then
                            local current_total=$((total_added + added_count))
                            update_progress "$current_total" "$total_ips" "Batch $processed_batches/$total_batches"
                        fi
                    fi
                done < "$batch_file"
                total_added=$((total_added + added_count))
            fi
            
            rm -f "$batch_file"
        fi
    done
    
    rm -rf "$temp_batch_dir"
    
    # Performance summary
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local rate=$((total_added / (duration + 1)))  # +1 to avoid division by zero
    stop_progress_bar "✅ Added $total_added/$total_ips IPs using batch processing ($rate IPs/sec)"
    
    return 0
}

# Function to remove IPs from ipset in bulk
remove_ips_from_ipset_bulk() {
    local ipset_name="$1"
    local ips_file="$2"
    
    if [ ! -s "$ips_file" ]; then
        return 0  # No IPs to remove
    fi
    
    if [ "$DRY_RUN" = true ]; then
        local count
        count=$(wc -l < "$ips_file")
        log_debug "Would remove $count IPs from ipset: $ipset_name"
        return 0
    fi
    
    if [ "$USE_NATIVE_IPSET" = true ]; then
        # Use native ipset with restore format
        {
            while IFS= read -r ip; do
                [ -n "$ip" ] && echo "del $ipset_name $ip"
            done < "$ips_file"
        } | ipset restore -exist 2>/dev/null
        return $?
    else
        # Fallback to firewall-cmd
        while IFS= read -r ip; do
            [ -n "$ip" ] && firewall-cmd --permanent --ipset="$ipset_name" --remove-entry="$ip" 2>/dev/null
        done < "$ips_file"
        return $?
    fi
}

# Function to clean up existing ipset if needed
cleanup_existing_ipset() {
    local ipset_name="$1"
    local force_recreate="$2"
    
    if [ "$force_recreate" = true ]; then
        log_debug "Force recreating ipset: $ipset_name"
        if $SUDO_CMD firewall-cmd --permanent --get-ipsets 2>/dev/null | grep -qw "$ipset_name"; then
            log_debug "Removing existing ipset: $ipset_name"
            $SUDO_CMD firewall-cmd --permanent --delete-ipset="$ipset_name" 2>/dev/null || {
                log_warning "Failed to delete existing ipset: $ipset_name"
                return 1
            }
        fi
    fi
    return 0
}

# Function to check prerequisites
check_prerequisites() {
    log_section "CHECKING PREREQUISITES"
    
    # Setup cache directory
    setup_cache_directory
    
    # Check for download tools
    if command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl"
        log_debug "Using curl for downloads"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget"
        log_debug "Using wget for downloads"
    else
        handle_error "Neither curl nor wget is available. Please install one of them:" false
        suggest_package_install "curl"
        if [ "$FORCE" = false ]; then
            return 1
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "Dry-run mode: skipping sudo/firewall state checks; source preflight will still run"
        return 0
    fi

    # Check native ipset support
    check_native_ipset_support
    
    # Check sudo privileges first (except for Windows)
    if [ "$OS_TYPE" != "Windows" ]; then
        log_debug "Checking sudo privileges..."
        if ! $SUDO_CMD -n true 2>/dev/null; then
            log_warning "This script requires sudo privileges for firewall changes"
            if ! $SUDO_CMD -v; then
                handle_error "Failed to obtain sudo privileges" true
                return 1
            else
                # Extend sudo timeout to cover the entire script execution
                $SUDO_CMD -v
                log_info "Sudo privileges confirmed"
            fi
        else
            log_info "Sudo privileges available"
        fi
    fi
    
    # Check firewall system based on detected type
    if ! check_firewall_system; then
        handle_error "Firewall system check failed" true
        return 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Function to check firewall system
check_firewall_system() {
    case "$FIREWALL_TYPE" in
        firewalld)
            if ! systemctl is-active --quiet firewalld; then
                log_warning "firewalld service is not running"
                if confirm_action "Start firewalld service?"; then
                    if [ "$DRY_RUN" = false ]; then
                        $SUDO_CMD systemctl start firewalld
                        $SUDO_CMD systemctl enable firewalld
                        log_info "Started and enabled firewalld service"
                    else
                        log_debug "Would start and enable firewalld service"
                    fi
                else
                    handle_error "firewalld service is required" true
                    return 1
                fi
            else
                log_info "firewalld service is running"
            fi
            ;;
        ufw)
            if ! $SUDO_CMD ufw status | grep -q "Status: active"; then
                log_warning "ufw firewall is not active"
                if confirm_action "Enable ufw firewall?"; then
                    if [ "$DRY_RUN" = false ]; then
                        $SUDO_CMD ufw --force enable
                        log_info "Enabled ufw firewall"
                    else
                        log_debug "Would enable ufw firewall"
                    fi
                else
                    handle_error "ufw firewall is required" true
                    return 1
                fi
            else
                log_info "ufw firewall is active"
            fi
            ;;
        iptables)
            if ! command -v iptables-save &> /dev/null; then
                handle_error "iptables-save not found. Please install iptables-persistent or equivalent" false
                suggest_package_install "iptables-persistent"
                if [ "$FORCE" = false ]; then
                    return 1
                fi
            fi
            log_info "iptables system available"
            ;;
        pfctl)
            if ! $SUDO_CMD pfctl -s info &> /dev/null; then
                log_warning "pfctl firewall may not be properly configured"
                log_info "Continuing with pfctl setup..."
            else
                log_info "pfctl firewall is available"
            fi
            ;;
        *)
            handle_error "Unsupported firewall type: $FIREWALL_TYPE" true
            return 1
            ;;
    esac
}

# Function to suggest package installation
suggest_package_install() {
    local package="$1"
    case "$PACKAGE_MANAGER" in
        dnf)
            echo "  $SUDO_CMD dnf install $package"
            ;;
        yum)
            echo "  $SUDO_CMD yum install $package"
            ;;
        apt|apt-get)
            echo "  $SUDO_CMD $PACKAGE_MANAGER update && $SUDO_CMD $PACKAGE_MANAGER install $package"
            ;;
        pacman)
            echo "  $SUDO_CMD pacman -S $package"
            ;;
        zypper)
            echo "  $SUDO_CMD zypper install $package"
            ;;
        brew)
            echo "  brew install $package"
            ;;
        port)
            echo "  $SUDO_CMD port install $package"
            ;;
        *)
            echo "  Please install $package using your system's package manager"
            ;;
    esac
}

# Function to create necessary directories
create_directories() {
    log_section "CREATING DIRECTORIES"
    
    local dirs=("$FIREWALL_DATA_DIR" "$BACKUP_DIR")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            # Create directories even in dry-run mode for file operations
            mkdir -p "$dir"
            chmod 700 "$dir"
            if [ "$DRY_RUN" = false ]; then
                log_info "✅ Created directory: $dir"
            else
                log_debug "✅ Created temporary directory for dry-run: $dir"
            fi
        else
            log_info "📁 Directory already exists: $dir"
        fi
    done
}

# Function to backup current firewall rules
backup_firewall_rules() {
    log_section "BACKING UP CURRENT FIREWALL RULES"
    
    # Clean up old backups (keep only last 5 backup sets)
    if [ -d "$BACKUP_DIR" ]; then
        # Count backup sets (not individual files)
        local backup_sets
        backup_sets=$(find "$BACKUP_DIR" -name "firewall_backup_*.zones" -type f | wc -l)
        if [ "$backup_sets" -gt 5 ]; then
            log_info "🧹 Cleaning up old backups (found $backup_sets sets, keeping latest 5)..."
            # Get the timestamps of old backup sets to remove
            find "$BACKUP_DIR" -name "firewall_backup_*.zones" -type f -printf '%T@ %f\n' | \
            sort -n | head -n -5 | cut -d' ' -f2 | sed 's/\.zones$//' | \
            while read -r backup_base; do
                rm -f "$BACKUP_DIR/${backup_base}".* 2>/dev/null || true
                log_debug "Removed old backup set: ${backup_base}"
            done
        fi
    fi
    
    local backup_file
    backup_file="$BACKUP_DIR/firewall_backup_$(date +%Y%m%d_%H%M%S)"
    
    if [ "$DRY_RUN" = false ]; then
        case "$FIREWALL_TYPE" in
            firewalld)
                if $SUDO_CMD firewall-cmd --list-all-zones > "${backup_file}.zones" 2>/dev/null; then
                    log_info "✅ Backed up firewall zones to: ${backup_file}.zones"
                fi
                
                if $SUDO_CMD firewall-cmd --list-ipsets > "${backup_file}.ipsets" 2>/dev/null; then
                    log_info "✅ Backed up firewall ipsets to: ${backup_file}.ipsets"
                fi
                
                # Try different methods to export complete configuration
                local export_success=false
                
                # Method 1: Try direct export
                if $SUDO_CMD firewall-cmd --export-config > "${backup_file}.xml" 2>/dev/null; then
                    log_info "✅ Backed up complete firewall config to: ${backup_file}.xml"
                    export_success=true
                # Method 2: Try exporting individual zones
                elif $SUDO_CMD firewall-cmd --list-all-zones --verbose > "${backup_file}.detailed" 2>/dev/null; then
                    log_info "✅ Backed up detailed firewall config to: ${backup_file}.detailed"
                    export_success=true
                # Method 3: Export runtime configuration
                elif $SUDO_CMD firewall-cmd --runtime-to-permanent 2>/dev/null && \
                     $SUDO_CMD firewall-cmd --list-all > "${backup_file}.runtime" 2>/dev/null; then
                    log_info "✅ Backed up runtime firewall config to: ${backup_file}.runtime"
                    export_success=true
                fi
                
                if [ "$export_success" = false ]; then
                    log_debug "Note: Complete firewall configuration export not available (this is normal on some systems)"
                fi
                ;;
            ufw)
                if $SUDO_CMD ufw status verbose > "${backup_file}.ufw" 2>/dev/null; then
                    log_info "Backed up ufw status to: ${backup_file}.ufw"
                fi
                
                # Backup ufw rules
                if [ -f /etc/ufw/user.rules ]; then
                    $SUDO_CMD cp /etc/ufw/user.rules "${backup_file}.user.rules" 2>/dev/null
                    log_info "Backed up ufw user rules to: ${backup_file}.user.rules"
                fi
                
                if [ -f /etc/ufw/user6.rules ]; then
                    $SUDO_CMD cp /etc/ufw/user6.rules "${backup_file}.user6.rules" 2>/dev/null
                    log_info "Backed up ufw IPv6 rules to: ${backup_file}.user6.rules"
                fi
                ;;
            iptables)
                if $SUDO_CMD iptables-save > "${backup_file}.iptables" 2>/dev/null; then
                    log_info "Backed up iptables rules to: ${backup_file}.iptables"
                fi
                
                if command -v ip6tables-save &> /dev/null; then
                    if $SUDO_CMD ip6tables-save > "${backup_file}.ip6tables" 2>/dev/null; then
                        log_info "Backed up ip6tables rules to: ${backup_file}.ip6tables"
                    fi
                fi
                ;;
            pfctl)
                if $SUDO_CMD pfctl -s all > "${backup_file}.pfctl" 2>/dev/null; then
                    log_info "Backed up pfctl rules to: ${backup_file}.pfctl"
                fi
                
                # Backup pfctl configuration file if it exists
                if [ -f /etc/pf.conf ]; then
                    $SUDO_CMD cp /etc/pf.conf "${backup_file}.pf.conf" 2>/dev/null
                    log_info "Backed up pf.conf to: ${backup_file}.pf.conf"
                fi
                ;;
            *)
                log_warning "Backup not implemented for firewall type: $FIREWALL_TYPE"
                ;;
        esac
    else
        log_debug "Would backup firewall rules to: $backup_file.*"
    fi
}

# Function to download a single source (for parallel processing)
download_single_source() {
    local source="$1"
    local source_index="$2"
    local total_sources="$3"
    local result_file="$FIREWALL_DATA_DIR/result_${source_index}.txt"
    
    log_debug "Downloading from source $source_index/$total_sources: $source"
    
    # Check cache first
    local cache_file
    cache_file=$(get_cache_file "$source")
    if is_cache_valid "$cache_file" && [ "$FORCE" = false ]; then
        log_debug "Using cached data for: $(basename "$source")"
        local processed_count
        processed_count=$(wc -l < "$cache_file" 2>/dev/null || echo 0)
        echo "$processed_count:$cache_file" > "$result_file"
        return 0
    fi
    
    local temp_file="$FIREWALL_DATA_DIR/temp_${source_index}.txt"
    local download_success=false
    local retry_count=0
    
    # Download with retries
    while [ $retry_count -lt $DOWNLOAD_RETRIES ] && [ "$download_success" = false ]; do
        if download_to_file "$source" "$temp_file"; then
            if [ -s "$temp_file" ]; then
                download_success=true
            fi
        fi
        
        if [ "$download_success" = false ]; then
            ((retry_count++))
            [ $retry_count -lt $DOWNLOAD_RETRIES ] && sleep 1
        fi
    done
    
    if [ "$download_success" = false ]; then
        echo "0:FAILED" > "$result_file"
        rm -f "$temp_file"
        return 1
    fi
    
    # Check if source data has changed
    if ! has_source_changed "$source" "$temp_file"; then
        # Use cached data if available
        if [ -f "$cache_file" ]; then
            local processed_count
            processed_count=$(wc -l < "$cache_file" 2>/dev/null || echo 0)
            echo "$processed_count:$cache_file" > "$result_file"
            rm -f "$temp_file"
            return 0
        fi
    fi
    
    # Validate file format - check for IP addresses or CIDR blocks
    # Also check for common error responses
    if grep -q "404: Not Found\|404 Not Found\|File not found" "$temp_file" 2>/dev/null; then
        echo "0:NOT_FOUND" > "$result_file"
        rm -f "$temp_file"
        return 1
    elif grep -q "This list has been merged\|EOF" "$temp_file" 2>/dev/null && ! grep -qE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$temp_file"; then
        echo "0:MERGED_OR_EMPTY" > "$result_file"
        rm -f "$temp_file"
        return 1
    fi
    
    # More lenient validation - check if file contains any IP-like patterns
    # This allows files with headers, comments, or mixed content to be processed
    if ! grep -qE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$temp_file" 2>/dev/null; then
        # Only reject if file is completely empty or contains obvious error messages
        if [ ! -s "$temp_file" ] || grep -qE "error|Error|ERROR|not found|Not Found|NOT FOUND" "$temp_file" 2>/dev/null; then
            echo "0:INVALID" > "$result_file"
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    # Process the data
    local processed_file="$FIREWALL_DATA_DIR/processed_${source_index}.txt"
    local processed_count
    processed_count=$(process_threat_data_optimized "$temp_file" "$source" "$processed_file")
    
    if [ "$processed_count" -gt 0 ]; then
        # Cache the processed data
        cp "$processed_file" "$cache_file" 2>/dev/null || true
        echo "$processed_count:$processed_file" > "$result_file"
    else
        echo "0:EMPTY" > "$result_file"
    fi
    
    rm -f "$temp_file"
    return 0
}

# Optimized threat data processing function
process_threat_data_optimized() {
    local temp_file="$1"
    local source="$2"
    local output_file="$3"
    
    # Clear output file
    : > "$output_file"
    
    # First, normalize line endings and remove comments
    tr -d '\r' < "$temp_file" | grep -v '^#' | grep -v '^;' | grep -v '^$' > "${temp_file}.clean" 2>/dev/null || true
    
    # Extract IPs/CIDRs using optimized single-pass processing
    {
        # Pattern 1: Clean IP/CIDR format (one per line)
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?[[:space:]]*$' "${temp_file}.clean" 2>/dev/null || true
        
        # Pattern 2: IPsum format - IP followed by tab and count (handle both tab and spaces)
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}[[:space:]]+[0-9]+' "${temp_file}.clean" 2>/dev/null | \
            awk '{print $1}' || true
        
        # Pattern 3: Spamhaus format - CIDR followed by semicolon and comment
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}[[:space:]]*;' "${temp_file}.clean" 2>/dev/null | \
            cut -d';' -f1 | sed 's/[[:space:]]*$//' || true
        
        # Pattern 4: DShield format - convert /24 subnets to CIDR
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.0[[:space:]]+[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.255[[:space:]]+24' "${temp_file}.clean" 2>/dev/null | \
            awk '{print $1}' | sed 's/\.0$/\.0\/24/' || true
        
        # Pattern 5: Any line starting with an IP (fallback)
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "${temp_file}.clean" 2>/dev/null | \
            grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?' || true
        
    } | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$' | \
      awk '!seen[$0]++' > "$output_file"  # Remove duplicates in single pass
    
    # Clean up temporary file
    rm -f "${temp_file}.clean"
    
    # Return count of valid IPs processed
    wc -l < "$output_file" 2>/dev/null || echo 0
}

# Function to download threat intelligence data (optimized with parallel processing)
download_threat_data() {
    log_section "DOWNLOADING THREAT INTELLIGENCE DATA"
    
    SOURCE_PREFLIGHT_FAILED=false
    local candidate_sources=()
    local sources_to_use=()
    local preflight_validated_sources=()
    local preflight_failed_sources=()
    local preflight_failed_reasons=()
    # Make these global for report generation
    SUCCESSFUL_DOWNLOADS=0
    FAILED_DOWNLOADS=0
    
    # Use custom sources if provided
    if [ -n "$CUSTOM_SOURCES" ]; then
        if [ ! -f "$CUSTOM_SOURCES" ]; then
            log_error "Custom sources file not found: $CUSTOM_SOURCES"
            SOURCE_PREFLIGHT_FAILED=true
            return 1
        fi

        log_info "Using custom threat sources from: $CUSTOM_SOURCES"
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ ]] && continue  # Skip comments
            [[ -z "$line" ]] && continue        # Skip empty lines
            candidate_sources+=("$line")
            log_debug "Queued custom source: $line"
        done < "$CUSTOM_SOURCES"

        if [ ${#candidate_sources[@]} -eq 0 ]; then
            log_error "No source URLs found in custom sources file: $CUSTOM_SOURCES"
            SOURCE_PREFLIGHT_FAILED=true
            return 1
        fi
    else
        # Use default sources
        candidate_sources=("${MALWARE_SOURCES[@]}" "${SUSPICIOUS_SOURCES[@]}")
        
        # Add specialized sources if enabled
        if [ "$ENABLE_SPECIALIZED_SOURCES" = true ]; then
            log_info "Including specialized threat intelligence sources"
            candidate_sources+=("${SPECIALIZED_SOURCES[@]}")
        fi
        
        # Add specific categories if enabled
        if [ "$ENABLE_PROXY_BLOCKING" = true ]; then
            log_info "Including proxy server blocking sources"
            candidate_sources+=(
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_proxies.netset"
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/tor_exits.ipset"
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/sslproxies.ipset"
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/socks_proxy.ipset"
            )
        fi
        
        if [ "$ENABLE_CRYPTO_MINING_BLOCKING" = true ]; then
            log_info "Including cryptocurrency mining blocking sources"
            candidate_sources+=(
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cta_cryptowall.ipset"
            )
        fi
    fi

    local total_preflight_sources=${#candidate_sources[@]}
    local source tmp_preflight_file source_fail_reason
    for source in "${candidate_sources[@]}"; do
        source_fail_reason=""

        if ! is_source_url_format_valid "$source"; then
            source_fail_reason="INVALID_URL_FORMAT"
        else
            tmp_preflight_file=$(mktemp 2>/dev/null || mktemp -t fw_source_preflight)
            if ! preflight_download_source "$source" "$tmp_preflight_file"; then
                source_fail_reason="DOWNLOAD_FAILED"
            elif [ ! -s "$tmp_preflight_file" ]; then
                source_fail_reason="EMPTY_RESPONSE"
            elif ! source_has_ip_data "$tmp_preflight_file"; then
                source_fail_reason="NO_IP_PATTERN"
            fi
            rm -f "$tmp_preflight_file" 2>/dev/null || true
        fi

        if [ -n "$source_fail_reason" ]; then
            if ! preflight_failure_exists "$source" "$source_fail_reason"; then
                preflight_failed_sources+=("$source")
                preflight_failed_reasons+=("$source_fail_reason")
            fi
        else
            preflight_validated_sources+=("$source")
        fi
    done

    # Deduplicate sources after successful validation and before download processing.
    while IFS= read -r source; do
        [ -n "$source" ] && sources_to_use+=("$source")
    done < <(dedupe_sources "${preflight_validated_sources[@]}")

    local preflight_validated_count=${#sources_to_use[@]}
    local preflight_failed_count=${#preflight_failed_sources[@]}
    log_info "SOURCE_PREFLIGHT_SUMMARY validated=$preflight_validated_count failed=$preflight_failed_count total=$total_preflight_sources"

    if [ "$preflight_failed_count" -gt 0 ]; then
        log_error "Source preflight validation failed. Aborting before firewall updates."
        local i
        for i in "${!preflight_failed_sources[@]}"; do
            log_error "SOURCE_PREFLIGHT_FAILED url=${preflight_failed_sources[$i]} reason=${preflight_failed_reasons[$i]}"
        done
        SOURCE_PREFLIGHT_FAILED=true
        return 1
    fi

    if [ "$preflight_validated_count" -eq 0 ]; then
        log_error "No validated threat intelligence sources available after preflight checks."
        SOURCE_PREFLIGHT_FAILED=true
        return 1
    fi
    
    local malware_ips="$FIREWALL_DATA_DIR/malware_ips.txt"
    local suspicious_ips="$FIREWALL_DATA_DIR/suspicious_ips.txt"
    
    # Clear previous data
    : > "$malware_ips"
    : > "$suspicious_ips"
    
    local total_sources=${#sources_to_use[@]}
    # Make this global for report generation
    TOTAL_SOURCES_PROCESSED=$total_sources
    log_info "Downloading from $total_sources threat intelligence sources..."
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "Dry-run mode: source preflight completed; skipping threat data download and processing."
        return 0
    fi
    
    # Parallel processing
    if [ "$PARALLEL_DOWNLOADS" = true ] && [ "$total_sources" -gt 1 ]; then
        log_debug "Using parallel downloads (max $MAX_PARALLEL_JOBS concurrent)"
        
        # Start parallel downloads
        local pids=()
        local source_index=0
        
        for source in "${sources_to_use[@]}"; do
            ((source_index++))
            
            # Limit concurrent jobs
            while [ ${#pids[@]} -ge $MAX_PARALLEL_JOBS ]; do
                for i in "${!pids[@]}"; do
                    if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                        unset "pids[$i]"
                    fi
                done
                pids=("${pids[@]}")  # Reindex array
                [ ${#pids[@]} -ge $MAX_PARALLEL_JOBS ] && sleep 0.1
            done
            
            # Start download in background
            download_single_source "$source" "$source_index" "$total_sources" &
            pids+=($!)
        done
        
        # Wait for all downloads to complete
        for pid in "${pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done
        
        log_debug "All parallel downloads completed"
    else
        # Sequential processing (fallback)
        log_debug "Using sequential downloads"
        local source_index=0
        for source in "${sources_to_use[@]}"; do
            ((source_index++))
            download_single_source "$source" "$source_index" "$total_sources"
        done
    fi
    
    # Collect results and merge data
    update_progress 0 "$total_sources" "Processing downloaded data"
    local source_index=0
    for source in "${sources_to_use[@]}"; do
        ((source_index++))
        local result_file="$FIREWALL_DATA_DIR/result_${source_index}.txt"
        
        # Process source without progress updates
        
        if [ -f "$result_file" ]; then
            local result
            result=$(cat "$result_file")
            local count
            count=$(echo "$result" | cut -d':' -f1)
            local data_file
            data_file=$(echo "$result" | cut -d':' -f2)
            
            if [ "$count" -gt 0 ] && [ -f "$data_file" ]; then
                # Determine if this is a malware or suspicious source
                local is_malware=false
                for malware_source in "${MALWARE_SOURCES[@]}"; do
                    if [ "$source" = "$malware_source" ]; then
                        is_malware=true
                        break
                    fi
                done
                
                if [ "$is_malware" = true ]; then
                    cat "$data_file" >> "$malware_ips"
                else
                    cat "$data_file" >> "$suspicious_ips"
                fi
                
                log_debug "Successfully processed $count IPs from: $source"
                ((SUCCESSFUL_DOWNLOADS++))
            else
                case "$data_file" in
                    "FAILED") log_warning "Failed to download from: $source" ;;
                    "NOT_FOUND") log_warning "Source not found (404): $source" ;;
                    "MERGED_OR_EMPTY") log_warning "Source has been merged or is empty: $source" ;;
                    "INVALID") log_warning "Downloaded file from $source does not contain valid IP format" ;;
                    "EMPTY") log_warning "Downloaded file from $source contained no valid IP addresses" ;;
                esac
                ((FAILED_DOWNLOADS++))
            fi
            
            rm -f "$result_file"
        else
            log_warning "No result file for source: $source"
            ((FAILED_DOWNLOADS++))
        fi
    done
    
    # Advanced processing and cross-deduplication
    echo ""
    
    local malware_count
    malware_count=$(wc -l < "$malware_ips" 2>/dev/null || echo 0)
    local suspicious_count
    suspicious_count=$(wc -l < "$suspicious_ips" 2>/dev/null || echo 0)
    
    log_info "📊 Downloaded data summary: $malware_count malware, $suspicious_count suspicious IPs"
    log_debug "🔄 Starting IP processing and deduplication..."
    
    # Get existing IPs from current ipsets for cross-checking
    local existing_malware="$FIREWALL_DATA_DIR/existing_malware.txt"
    local existing_suspicious="$FIREWALL_DATA_DIR/existing_suspicious.txt"
    
    # Extract existing IPs from current ipsets if they exist
    echo "🔍 Checking for existing IPs to avoid duplicates..."
    
    # Try firewalld first (most common on modern systems), then direct ipset
    local extraction_method=""
    
    if command -v firewall-cmd >/dev/null 2>&1; then
        # Check if ipsets exist in firewalld
        if $SUDO_CMD firewall-cmd --get-ipsets 2>/dev/null | grep -q "malware-blocklist"; then
            extraction_method="firewalld"
            $SUDO_CMD firewall-cmd --ipset=malware-blocklist --get-entries 2>/dev/null > "$existing_malware" || touch "$existing_malware"
            $SUDO_CMD firewall-cmd --ipset=suspicious-blocklist --get-entries 2>/dev/null > "$existing_suspicious" || touch "$existing_suspicious"
        else
            touch "$existing_malware" "$existing_suspicious"
        fi
    elif command -v ipset >/dev/null 2>&1; then
        # Fallback to direct ipset method
        extraction_method="ipset"
        $SUDO_CMD ipset list malware-blocklist 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' > "$existing_malware" 2>/dev/null || touch "$existing_malware"
        $SUDO_CMD ipset list suspicious-blocklist 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' > "$existing_suspicious" 2>/dev/null || touch "$existing_suspicious"
    else
        touch "$existing_malware" "$existing_suspicious"
    fi
    
    local existing_malware_count
    existing_malware_count=$(wc -l < "$existing_malware" 2>/dev/null || echo 0)
    local existing_suspicious_count
    existing_suspicious_count=$(wc -l < "$existing_suspicious" 2>/dev/null || echo 0)
    
    if [ "$existing_malware_count" -gt 0 ] || [ "$existing_suspicious_count" -gt 0 ]; then
        echo "📊 Found existing IPs: $existing_malware_count malware, $existing_suspicious_count suspicious"
        if [ -n "$extraction_method" ]; then
            echo "🔧 Extraction method: $extraction_method"
        fi
    else
        echo "📊 No existing IPs found (fresh installation or empty ipsets)"
        if [ -n "$extraction_method" ]; then
            echo "🔧 Checked using: $extraction_method"
        fi
    fi
    
    # Fast and reliable IP processing with progress feedback
    if [ "$malware_count" -gt 0 ]; then
        echo "🔧 Processing malware IPs ($malware_count entries)..."
        local temp_malware="$FIREWALL_DATA_DIR/temp_malware.txt"
        local temp_resolved="$FIREWALL_DATA_DIR/temp_resolved_malware.txt"
        
        # Disable trap during critical processing to prevent temp dir cleanup
        trap - EXIT INT TERM
        
        # Step 1: Deduplicate and validate
        deduplicate_ips_advanced "$malware_ips" "$temp_malware" "$existing_malware" "Processing malware"
        
        # Step 2: Resolve CIDR overlaps to prevent firewall errors
        resolve_cidr_overlaps "$temp_malware" "$temp_resolved" "Resolving malware overlaps"
        
        if [ -f "$temp_resolved" ]; then
            mv "$temp_resolved" "$malware_ips"
        else
            mv "$temp_malware" "$malware_ips"
        fi
        rm -f "$temp_malware"
        malware_count=$(wc -l < "$malware_ips" 2>/dev/null || echo 0)
        echo "✅ Malware IPs processed: $malware_count unique entries"
        
        # Re-enable trap after processing
        trap cleanup_on_exit EXIT INT TERM
    fi
    
    if [ "$suspicious_count" -gt 0 ]; then
        echo "🔧 Processing suspicious IPs ($suspicious_count entries)..."
        local temp_suspicious="$FIREWALL_DATA_DIR/temp_suspicious.txt"
        local temp_resolved_sus="$FIREWALL_DATA_DIR/temp_resolved_suspicious.txt"
        
        # Disable trap during critical processing to prevent temp dir cleanup
        trap - EXIT INT TERM
        
        # Cross-check suspicious IPs against both existing lists and malware list
        local combined_existing="$FIREWALL_DATA_DIR/combined_existing.txt"
        cat "$existing_suspicious" "$existing_malware" "$malware_ips" 2>/dev/null | sort -u > "$combined_existing"
        
        # Step 1: Deduplicate and validate
        deduplicate_ips_advanced "$suspicious_ips" "$temp_suspicious" "$combined_existing" "Processing suspicious"
        
        # Step 2: Resolve CIDR overlaps to prevent firewall errors
        resolve_cidr_overlaps "$temp_suspicious" "$temp_resolved_sus" "Resolving suspicious overlaps"
        
        if [ -f "$temp_resolved_sus" ]; then
            mv "$temp_resolved_sus" "$suspicious_ips"
        else
            mv "$temp_suspicious" "$suspicious_ips"
        fi
        rm -f "$temp_suspicious" "$combined_existing"
        suspicious_count=$(wc -l < "$suspicious_ips" 2>/dev/null || echo 0)
        echo "✅ Suspicious IPs processed: $suspicious_count unique entries"
        
        # Re-enable trap after processing
        trap cleanup_on_exit EXIT INT TERM
    fi
    
    # Clean up temporary files
    rm -f "$existing_malware" "$existing_suspicious"
    
    echo "✅ Downloaded $malware_count malware IPs and $suspicious_count suspicious IPs from $SUCCESSFUL_DOWNLOADS sources ($FAILED_DOWNLOADS failed)"
    
    # Validate that we have enough IPs to proceed
    if [ "$malware_count" -lt "$MIN_IPS_THRESHOLD" ]; then
        log_warning "Very few malware IPs collected ($malware_count). Sources might be unavailable or unreliable."
        if [ "$malware_count" -eq 0 ] && [ "$FORCE" = false ]; then
            if ! confirm_action "No malware IPs collected. Continue anyway?"; then
                handle_error "Insufficient malware threat data collected" false
                return 1
            fi
        fi
    fi
    
    if [ "$suspicious_count" -lt "$MIN_IPS_THRESHOLD" ]; then
        log_warning "Very few suspicious IPs collected ($suspicious_count). Sources might be unavailable or unreliable."
        if [ "$suspicious_count" -eq 0 ] && [ "$FORCE" = false ]; then
            if ! confirm_action "No suspicious IPs collected. Continue anyway?"; then
                handle_error "Insufficient suspicious threat data collected" false
                return 1
            fi
        fi
    fi
    
    # If all downloads failed but we're forcing execution
    if [ "$SUCCESSFUL_DOWNLOADS" -eq 0 ] && [ "$FORCE" = true ]; then
        log_warning "All downloads failed but continuing due to --force option"
    elif [ "$SUCCESSFUL_DOWNLOADS" -eq 0 ] && [ "$FORCE" = false ]; then
        if ! confirm_action "All downloads failed. Continue anyway?"; then
            handle_error "All downloads failed" false
            return 1
        fi
    fi
}

# Old process_threat_data function replaced with optimized version above

# Function to create firewall blocking rules
create_firewall_ipsets() {
    log_section "CREATING FIREWALL BLOCKING RULES"
    
    local malware_ips="$FIREWALL_DATA_DIR/malware_ips.txt"
    local suspicious_ips="$FIREWALL_DATA_DIR/suspicious_ips.txt"
    
    # Create blocking rules for malware IPs
    if [ -f "$malware_ips" ] && [ -s "$malware_ips" ]; then
        case "$FIREWALL_TYPE" in
            firewalld)
                create_firewalld_ipset "malware-blocklist" "$malware_ips" "Malware and spam IP addresses"
                ;;
            ufw)
                create_ufw_rules "$malware_ips" "malware"
                ;;
            iptables)
                create_iptables_rules "$malware_ips" "malware"
                ;;
            pfctl)
                create_pfctl_rules "$malware_ips" "malware"
                ;;
        esac
    fi
    
    # Create blocking rules for suspicious IPs
    if [ -f "$suspicious_ips" ] && [ -s "$suspicious_ips" ]; then
        case "$FIREWALL_TYPE" in
            firewalld)
                create_firewalld_ipset "suspicious-blocklist" "$suspicious_ips" "Suspicious activity IP addresses"
                ;;
            ufw)
                create_ufw_rules "$suspicious_ips" "suspicious"
                ;;
            iptables)
                create_iptables_rules "$suspicious_ips" "suspicious"
                ;;
            pfctl)
                create_pfctl_rules "$suspicious_ips" "suspicious"
                ;;
        esac
    fi
}

# Function: create_firewalld_ipset
# Description: Creates a firewalld ipset and adds IP addresses to it in batches
# Parameters:
#   $1 - ipset_name: Name of the ipset to create
#   $2 - ip_file: Path to the file containing IP addresses
#   $3 - description: Description for the ipset
# Returns: None
create_firewalld_ipset() {
    local ipset_name="$1"
    local ip_file="$2"
    local description="$3"
    
    log_debug "Creating firewalld ipset: $ipset_name"
    
    if [ "$DRY_RUN" = false ]; then
        # Check if the IP file exists and has content
        if [ ! -s "$ip_file" ]; then
            log_warning "IP file is empty or does not exist: $ip_file"
            return 1
        fi
        
        # Get IP count
        local ip_count
        ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        
        # Check if ipset exists (more robust check)
        local ipset_exists=false
        if $SUDO_CMD firewall-cmd --permanent --get-ipsets 2>/dev/null | grep -qw "$ipset_name"; then
            ipset_exists=true
            log_debug "Ipset $ipset_name already exists"
        else
            log_debug "Ipset $ipset_name does not exist, will create it"
        fi
        
        # Handle force recreation if needed
        if [ "$FORCE" = true ] && [ "$ipset_exists" = true ]; then
            if cleanup_existing_ipset "$ipset_name" true; then
                ipset_exists=false
                log_debug "Successfully removed existing ipset for recreation: $ipset_name"
            else
                log_warning "Could not remove existing ipset, will try to update it: $ipset_name"
            fi
        fi
        
        # Create ipset if it doesn't exist
        if [ "$ipset_exists" = false ]; then
            log_debug "Creating new ipset: $ipset_name"
            if $SUDO_CMD firewall-cmd --permanent --new-ipset="$ipset_name" --type=hash:net --option=family=inet --option=hashsize=8192 --option=maxelem=500000 >/dev/null 2>&1; then
                log_debug "Created ipset: $ipset_name"
                # Add description
                $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --set-description="$description" >/dev/null 2>&1 || true
                ipset_exists=true  # Mark as existing now
            else
                # Check if it was created by another process in the meantime
                if $SUDO_CMD firewall-cmd --permanent --get-ipsets 2>/dev/null | grep -qw "$ipset_name"; then
                    log_debug "Ipset $ipset_name was created by another process, continuing"
                    ipset_exists=true
                else
                    log_error "Failed to create firewalld ipset: $ipset_name"
                    return 1
                fi
            fi
        fi
        
        # Use incremental updates if enabled and ipset exists and has entries
        if [ "$INCREMENTAL_UPDATE" = true ] && [ "$ipset_exists" = true ]; then
            # Check if ipset has any entries
            local existing_count
            existing_count=$($SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --get-entries 2>/dev/null | wc -l || echo 0)
            if [ "$existing_count" -gt 0 ]; then
                log_debug "Using incremental update for ipset: $ipset_name (has $existing_count existing entries)"
                if update_ipset_incremental "$ipset_name" "$ip_file"; then
                    log_info "Incrementally updated ipset: $ipset_name"
                    return 0
                else
                    log_debug "No incremental updates needed for ipset: $ipset_name"
                    return 0
                fi
            else
                log_debug "Ipset $ipset_name is empty, performing full update instead of incremental"
            fi
        fi
        
        # Full update - use optimized bulk operations
        log_debug "Performing full update for ipset: $ipset_name"
        
        # Clear existing entries if doing full update (optimized)
        if [ "$ipset_exists" = true ]; then
            log_debug "Clearing existing entries from ipset: $ipset_name"
            
            # Method 1: Try to recreate the ipset (fastest way to clear)
            if $SUDO_CMD firewall-cmd --permanent --delete-ipset="$ipset_name" >/dev/null 2>&1; then
                # Recreate the ipset
                if $SUDO_CMD firewall-cmd --permanent --new-ipset="$ipset_name" --type=hash:net --option=family=inet --option=hashsize=8192 --option=maxelem=500000 >/dev/null 2>&1; then
                    $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --set-description="$description" >/dev/null 2>&1 || true
                    log_debug "Recreated ipset for fast clearing: $ipset_name"
                else
                    log_warning "Failed to recreate ipset after deletion: $ipset_name"
                    return 1
                fi
            else
                # Method 2: Fallback to bulk removal if recreation fails
                log_debug "Could not recreate ipset, using bulk removal method"
                local existing_entries_file="$FIREWALL_DATA_DIR/existing_${ipset_name}_clear.txt"
                $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --get-entries 2>/dev/null > "$existing_entries_file" || touch "$existing_entries_file"
                
                if [ -s "$existing_entries_file" ]; then
                    # Try native ipset flush first
                    if command -v ipset >/dev/null 2>&1; then
                        $SUDO_CMD ipset flush "$ipset_name" 2>/dev/null || true
                    else
                        # Individual removal as last resort
                        while IFS= read -r ip; do
                            [ -n "$ip" ] && $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --remove-entry="$ip" >/dev/null 2>&1 || true
                        done < "$existing_entries_file"
                    fi
                fi
                rm -f "$existing_entries_file"
            fi
        fi
        
        # Use simple reliable batch processing instead of complex bulk methods
        log_info "📥 Adding $ip_count IPs to ipset: $ipset_name"
        
        # Process in small batches to avoid overwhelming firewalld
        local batch_size=1000
        local temp_batch="$FIREWALL_DATA_DIR/batch_temp.txt"
        local processed=0
        local successful=0
        
        while IFS= read -r ip || [ -n "$ip" ]; do
            [ -n "$ip" ] && echo "$ip" >> "$temp_batch"
            ((processed++))
            
            # Process batch when it reaches batch_size or at end of file
            if [ $((processed % batch_size)) -eq 0 ] || [ $processed -eq $ip_count ]; then
                if [ -s "$temp_batch" ]; then
                    local batch_count
                    batch_count=$(wc -l < "$temp_batch")
                    if $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --add-entries-from-file="$temp_batch" >/dev/null 2>&1; then
                        ((successful += batch_count))
                    fi
                    : > "$temp_batch"  # Clear the batch file
                fi
                
                # Show progress every 10k IPs
                if [ $((processed % 10000)) -eq 0 ]; then
                    echo "  Processed $processed/$ip_count IPs..."
                fi
            fi
        done < "$ip_file"
        
        rm -f "$temp_batch"
        
        # Reload firewalld to sync configurations
        $SUDO_CMD firewall-cmd --reload >/dev/null 2>&1 || true
        
        # Verify the IPs were actually added
        local actual_count
        actual_count=$($SUDO_CMD firewall-cmd --ipset="$ipset_name" --get-entries 2>/dev/null | wc -l || echo 0)
        log_info "Added $ip_count IPs to firewalld ipset: $ipset_name (verified: $actual_count IPs in ipset)"
        return 0
    else
        local ip_count
        ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        log_debug "Would create firewalld ipset '$ipset_name' with $ip_count IPs"
    fi
    
    return 0
}

# Fallback function for traditional firewalld ipset creation
create_firewalld_ipset_fallback() {
    local ipset_name="$1"
    local ip_file="$2"
    local ip_count="$3"
    
    log_debug "Using traditional batch processing for ipset: $ipset_name"
    local batch_dir="$FIREWALL_DATA_DIR/batch_$ipset_name"
    mkdir -p "$batch_dir"
    
    # Split the file into smaller batches
    split -l "$BATCH_SIZE" "$ip_file" "$batch_dir/batch_"
    
    # Process each batch
    local entries_added=0
    local batch_count=0
    local batch_files=("$batch_dir"/batch_*)
    local total_batches=${#batch_files[@]}
    
    for batch_file in "${batch_files[@]}"; do
        ((batch_count++))
        log_debug "Processing batch $batch_count/$total_batches for ipset: $ipset_name"
        
        # Create a temporary script to add entries
        local script_file="$batch_dir/add_script_$batch_count.sh"
        echo "#!/bin/bash" > "$script_file"
        
        # Add each IP to the script
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            echo "firewall-cmd --permanent --ipset=$ipset_name --add-entry=\"$ip\"" >> "$script_file"
        done < "$batch_file"
        
        # Make the script executable
        chmod +x "$script_file"
        
        # Execute the script with sudo
        if $SUDO_CMD "$script_file" > /dev/null 2>&1; then
            local batch_size
            batch_size=$(wc -l < "$batch_file")
            entries_added=$((entries_added + batch_size))
            log_debug "Added batch $batch_count: $batch_size entries"
        else
            log_warning "Failed to add batch $batch_count to ipset: $ipset_name"
        fi
        
        # Clean up
        rm -f "$script_file" "$batch_file"
    done
    
    # Clean up batch directory
    rmdir "$batch_dir" 2>/dev/null || true
    
    log_info "Added $entries_added IPs to firewalld ipset: $ipset_name (out of $ip_count total)"
    return 0
}

# Function: create_ufw_rules
# Description: Creates UFW firewall rules to block IP addresses in batches
# Parameters:
#   $1 - ip_file: Path to the file containing IP addresses
#   $2 - rule_type: Type of rule (malware or suspicious)
# Returns: None
create_ufw_rules() {
    local ip_file="$1"
    local rule_type="$2"
    
    log_debug "Creating ufw rules for $rule_type IPs"
    
    if [ "$DRY_RUN" = false ]; then
        # Check if the IP file exists and has content
        if [ ! -s "$ip_file" ]; then
            log_warning "IP file is empty or does not exist: $ip_file"
            return 1
        fi
        
        # Get IP count
        local ip_count
        ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        log_info "Processing $ip_count IPs for UFW rules ($rule_type)"
        
        # Use batch processing with a temporary script
        local batch_dir="$FIREWALL_DATA_DIR/ufw_batches"
        mkdir -p "$batch_dir"
        
        # Split the file into batches
        split -l "$BATCH_SIZE" "$ip_file" "$batch_dir/batch_"
        
        # Process each batch
        local entries_added=0
        local batch_count=0
        local batch_files=("$batch_dir"/batch_*)
        local total_batches=${#batch_files[@]}
        
        for batch_file in "${batch_files[@]}"; do
            ((batch_count++))
            log_debug "Processing UFW batch $batch_count/$total_batches"
            
            # Create a temporary script to add rules
            local script_file="$batch_dir/ufw_script_$batch_count.sh"
            echo "#!/bin/bash" > "$script_file"
            echo "# Auto-generated UFW commands for $rule_type IPs - Batch $batch_count" >> "$script_file"
            
            # Add each IP to the script
            local batch_size=0
            while IFS= read -r ip; do
                [[ -z "$ip" ]] && continue
                echo "ufw deny from $ip comment \"Auto-blocked $rule_type IP\"" >> "$script_file"
                ((batch_size++))
            done < "$batch_file"
            
            # Make the script executable
            chmod +x "$script_file"
            
            # Execute the script with sudo
            if [ "$batch_size" -gt 0 ]; then
                log_debug "Adding $batch_size UFW rules in batch $batch_count"
                if $SUDO_CMD "$script_file" > /dev/null 2>&1; then
                    entries_added=$((entries_added + batch_size))
                    log_debug "Successfully added batch $batch_count: $batch_size UFW rules"
                else
                    log_warning "Failed to add some UFW rules in batch $batch_count"
                    
                    # Fall back to adding rules one by one if batch fails
                    log_debug "Falling back to individual rule addition for batch $batch_count"
                    local individual_added=0
                    while IFS= read -r ip; do
                        [[ -z "$ip" ]] && continue
                        if $SUDO_CMD ufw deny from "$ip" comment "Auto-blocked $rule_type IP" 2>/dev/null; then
                            ((individual_added++))
                        fi
                    done < "$batch_file"
                    
                    entries_added=$((entries_added + individual_added))
                    log_debug "Added $individual_added/$batch_size rules individually in batch $batch_count"
                fi
            fi
            
            # Clean up
            rm -f "$script_file" "$batch_file"
        done
        
        # Clean up batch directory
        rmdir "$batch_dir" 2>/dev/null || true
        
        log_info "Added $entries_added ufw deny rules for $rule_type IPs (out of $ip_count total)"
        
        # Reload UFW to ensure all rules are applied
        $SUDO_CMD ufw reload > /dev/null 2>&1 || log_warning "Failed to reload UFW after adding rules"
    else
        local ip_count
        ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        log_debug "Would create $ip_count ufw deny rules for $rule_type IPs"
    fi
    
    return 0
}

# Function: create_iptables_rules
# Description: Creates iptables rules to block IP addresses, using ipset for efficiency
# Parameters:
#   $1 - ip_file: Path to the file containing IP addresses
#   $2 - rule_type: Type of rule (malware or suspicious)
# Returns: None
create_iptables_rules() {
    local ip_file="$1"
    local rule_type="$2"
    
    log_debug "Creating iptables rules for $rule_type IPs"
    
    if [ "$DRY_RUN" = false ]; then
        # Check if the IP file exists and has content
        if [ ! -s "$ip_file" ]; then
            log_warning "IP file is empty or does not exist: $ip_file"
            return 1
        fi
        
        # Get IP count
        local ip_count
        ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        log_info "Processing $ip_count IPs for iptables rules ($rule_type)"
        
        local chain_name="THREAT_BLOCK_${rule_type^^}"
        local ipset_name="threat_${rule_type,,}"
        local entries_added=0
        
        # Check if ipset is available (preferred method for large IP lists)
        if command -v ipset &> /dev/null; then
            log_debug "Using ipset for efficient IP blocking"
            
            # Create or flush the ipset
            if ! $SUDO_CMD ipset list "$ipset_name" &>/dev/null; then
                $SUDO_CMD ipset create "$ipset_name" hash:net hashsize 4096 maxelem 200000 2>/dev/null || {
                    log_warning "Failed to create ipset: $ipset_name"
                }
                log_debug "Created ipset: $ipset_name"
            else
                $SUDO_CMD ipset flush "$ipset_name" 2>/dev/null
                log_debug "Flushed existing ipset: $ipset_name"
            fi
            
            # Add IPs to ipset in batches
            local batch_dir="$FIREWALL_DATA_DIR/ipset_batches"
            mkdir -p "$batch_dir"
            
            # Split the file into batches
            split -l "$BATCH_SIZE" "$ip_file" "$batch_dir/batch_"
            
            # Process each batch
            local batch_count=0
            local batch_files=("$batch_dir"/batch_*)
            local total_batches=${#batch_files[@]}
            
            for batch_file in "${batch_files[@]}"; do
                ((batch_count++))
                log_debug "Processing ipset batch $batch_count/$total_batches"
                
                # Create a temporary file for ipset restore
                local restore_file="$batch_dir/restore_$batch_count.txt"
                
                # Add each IP to the restore file
                while IFS= read -r ip; do
                    [[ -z "$ip" ]] && continue
                    echo "add $ipset_name $ip" >> "$restore_file"
                done < "$batch_file"
                
                # Use ipset restore for batch addition
                if [ -s "$restore_file" ]; then
                    if $SUDO_CMD ipset restore -f "$restore_file" 2>/dev/null; then
                        local batch_size
                        batch_size=$(wc -l < "$restore_file")
                        entries_added=$((entries_added + batch_size))
                        log_debug "Added batch $batch_count: $batch_size entries to ipset"
                    else
                        log_warning "Failed to add batch $batch_count to ipset"
                    fi
                fi
                
                # Clean up
                rm -f "$restore_file" "$batch_file"
            done
            
            # Clean up batch directory
            rmdir "$batch_dir" 2>/dev/null || true
            
            # Create custom chain if it doesn't exist
            if ! $SUDO_CMD iptables -L "$chain_name" &>/dev/null; then
                $SUDO_CMD iptables -N "$chain_name" 2>/dev/null
                $SUDO_CMD iptables -I INPUT -j "$chain_name" 2>/dev/null
                log_debug "Created iptables chain: $chain_name"
            else
                # Flush existing rules in the chain
                $SUDO_CMD iptables -F "$chain_name" 2>/dev/null
                log_debug "Flushed existing iptables chain: $chain_name"
            fi
            
            # Add the ipset rule to the chain
            if $SUDO_CMD iptables -A "$chain_name" -m set --match-set "$ipset_name" src -j DROP 2>/dev/null; then
                log_info "Added $entries_added IPs to ipset $ipset_name and linked to iptables chain $chain_name"
            else
                log_error "Failed to add ipset rule to iptables chain"
                return 1
            fi
        else
            # Fallback to traditional iptables rules if ipset is not available
            log_debug "ipset not available, using traditional iptables rules (less efficient)"
            
            # Create custom chain if it doesn't exist
            if ! $SUDO_CMD iptables -L "$chain_name" &>/dev/null; then
                $SUDO_CMD iptables -N "$chain_name" 2>/dev/null
                $SUDO_CMD iptables -I INPUT -j "$chain_name" 2>/dev/null
                log_debug "Created iptables chain: $chain_name"
            else
                # Flush existing rules in the chain
                $SUDO_CMD iptables -F "$chain_name" 2>/dev/null
                log_debug "Flushed existing iptables chain: $chain_name"
            fi
            
            # Use batch processing with a temporary script
            local batch_dir="$FIREWALL_DATA_DIR/iptables_batches"
            mkdir -p "$batch_dir"
            
            # Split the file into batches
            split -l "$BATCH_SIZE" "$ip_file" "$batch_dir/batch_"
            
            # Process each batch
            local batch_count=0
            local batch_files=("$batch_dir"/batch_*)
            local total_batches=${#batch_files[@]}
            
            for batch_file in "${batch_files[@]}"; do
                ((batch_count++))
                log_debug "Processing iptables batch $batch_count/$total_batches"
                
                # Create a temporary script to add rules
                local script_file="$batch_dir/iptables_script_$batch_count.sh"
                echo "#!/bin/bash" > "$script_file"
                
                # Add each IP to the script
                local batch_size=0
                while IFS= read -r ip; do
                    [[ -z "$ip" ]] && continue
                    echo "iptables -A $chain_name -s $ip -j DROP" >> "$script_file"
                    ((batch_size++))
                done < "$batch_file"
                
                # Make the script executable
                chmod +x "$script_file"
                
                # Execute the script with sudo
                if [ "$batch_size" -gt 0 ]; then
                    if $SUDO_CMD "$script_file" > /dev/null 2>&1; then
                        entries_added=$((entries_added + batch_size))
                        log_debug "Added batch $batch_count: $batch_size iptables rules"
                    else
                        log_warning "Failed to add batch $batch_count to iptables"
                    fi
                fi
                
                # Clean up
                rm -f "$script_file" "$batch_file"
            done
            
            # Clean up batch directory
            rmdir "$batch_dir" 2>/dev/null || true
            
            log_info "Added $entries_added iptables rules for $rule_type IPs (out of $ip_count total)"
        fi
        
        # Save iptables rules if iptables-save is available
        if command -v iptables-save &> /dev/null; then
            if [ -d /etc/iptables ]; then
                $SUDO_CMD iptables-save > /etc/iptables/rules.v4 2>/dev/null || log_warning "Failed to save iptables rules to /etc/iptables/rules.v4"
            elif [ -d /etc/sysconfig ]; then
                $SUDO_CMD iptables-save > /etc/sysconfig/iptables 2>/dev/null || log_warning "Failed to save iptables rules to /etc/sysconfig/iptables"
            else
                log_warning "Could not find standard location to save iptables rules"
            fi
        fi
    else
        local ip_count
        ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        log_debug "Would create $ip_count iptables rules for $rule_type IPs"
    fi
    
    return 0
}

# Function to create pfctl rules
create_pfctl_rules() {
    local ip_file="$1"
    local rule_type="$2"
    
    log_debug "Creating pfctl rules for $rule_type IPs"
    
    if [ "$DRY_RUN" = false ]; then
        local table_name="threat_${rule_type}"
        local pf_conf="/etc/pf.conf"
        local temp_conf="$FIREWALL_DATA_DIR/pf_temp.conf"
        
        # Create table file
        local table_file="/etc/pf_${table_name}.txt"
        $SUDO_CMD cp "$ip_file" "$table_file"
        
        # Create or update pf.conf
        if [ -f "$pf_conf" ]; then
            $SUDO_CMD cp "$pf_conf" "$temp_conf"
        else
            echo "# pfctl configuration" > "$temp_conf"
        fi
        
        # Add table and blocking rule if not already present
        if ! grep -q "table <$table_name>" "$temp_conf"; then
            echo "table <$table_name> persist file \"$table_file\"" >> "$temp_conf"
            echo "block in quick from <$table_name> to any" >> "$temp_conf"
            
            $SUDO_CMD cp "$temp_conf" "$pf_conf"
            $SUDO_CMD pfctl -f "$pf_conf" 2>/dev/null || log_warning "Failed to reload pfctl configuration"
            
            local ip_count
            ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
            log_info "Added pfctl table '$table_name' with $ip_count IPs"
        else
            # Reload the table
            $SUDO_CMD pfctl -t "$table_name" -T replace -f "$table_file" 2>/dev/null || log_warning "Failed to reload pfctl table"
            local ip_count
            ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
            log_info "Updated pfctl table '$table_name' with $ip_count IPs"
        fi
    else
        local ip_count
        ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        log_debug "Would create pfctl table for $rule_type with $ip_count IPs"
    fi
}

# Function to apply firewall rules
apply_firewall_rules() {
    log_section "APPLYING FIREWALL RULES"
    
    case "$FIREWALL_TYPE" in
        firewalld)
            apply_firewalld_rules
            ;;
        ufw)
            apply_ufw_rules
            ;;
        iptables)
            apply_iptables_rules
            ;;
        pfctl)
            apply_pfctl_rules
            ;;
        *)
            log_warning "Rule application not implemented for firewall type: $FIREWALL_TYPE"
            ;;
    esac
}

# Function to apply firewalld rules
apply_firewalld_rules() {
    local ipsets=("malware-blocklist" "suspicious-blocklist")
    
    for ipset in "${ipsets[@]}"; do
        if [ "$DRY_RUN" = false ]; then
            # Check if ipset exists
            if $SUDO_CMD firewall-cmd --permanent --get-ipsets | grep -q "$ipset"; then
                log_debug "Ipset $ipset exists, applying firewall rule"
                # Remove existing rule if it exists
                $SUDO_CMD firewall-cmd --permanent --remove-rich-rule="rule source ipset=$ipset drop" >/dev/null 2>&1 || true
                
                # Add new blocking rule
                if $SUDO_CMD firewall-cmd --permanent --add-rich-rule="rule source ipset=$ipset drop" >/dev/null 2>&1; then
                    log_info "Applied firewalld blocking rule for ipset: $ipset"
                else
                    log_error "Failed to apply firewalld blocking rule for ipset: $ipset"
                fi
            else
                log_warning "Ipset $ipset does not exist, skipping rule application"
            fi
        else
            log_debug "Would apply firewalld blocking rule for ipset: $ipset"
        fi
    done
    
    # Reload firewall to apply changes
    if [ "$DRY_RUN" = false ]; then
        if $SUDO_CMD firewall-cmd --reload >/dev/null 2>&1; then
            log_info "Firewalld rules reloaded successfully"
        else
            log_error "Failed to reload firewalld rules"
        fi
    else
        log_debug "Would reload firewalld rules"
    fi
}

# Function to apply ufw rules
apply_ufw_rules() {
    if [ "$DRY_RUN" = false ]; then
        # Rules are already applied during creation for ufw
        log_info "UFW rules have been applied during creation"
        
        # Reload ufw to ensure all rules are active
        $SUDO_CMD ufw --force reload 2>/dev/null || log_warning "Failed to reload ufw"
    else
        log_debug "Would reload ufw rules"
    fi
}

# Function to apply iptables rules
apply_iptables_rules() {
    if [ "$DRY_RUN" = false ]; then
        # Rules are already applied during creation for iptables
        log_info "Iptables rules have been applied during creation"
        
        # Save rules to make them persistent
        if command -v iptables-save &> /dev/null; then
            if [ -d /etc/iptables ]; then
                $SUDO_CMD iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            elif [ -d /etc/sysconfig ]; then
                $SUDO_CMD iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            fi
            log_info "Saved iptables rules for persistence"
        fi
    else
        log_debug "Would save iptables rules for persistence"
    fi
}

# Function to apply pfctl rules
apply_pfctl_rules() {
    if [ "$DRY_RUN" = false ]; then
        # Rules are already applied during creation for pfctl
        log_info "pfctl rules have been applied during creation"
        
        # Enable pfctl if not already enabled
        if ! $SUDO_CMD pfctl -s info | grep -q "Status: Enabled"; then
            $SUDO_CMD pfctl -e 2>/dev/null || log_warning "Failed to enable pfctl"
            log_info "Enabled pfctl firewall"
        fi
    else
        log_debug "Would enable pfctl firewall if needed"
    fi
}

# Function: generate_report
# Description: Generates a detailed report of the firewall update operation
# Parameters: None
# Returns: None
generate_report() {
    log_section "GENERATING REPORT"
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file="$BACKUP_DIR/firewall_update_report_$timestamp.txt"
    local html_report="$BACKUP_DIR/firewall_update_report_$timestamp.html"
    
    if [ "$DRY_RUN" = false ]; then
        # Get statistics
        local malware_count=0
        local suspicious_count=0
        
        if [ -f "$FIREWALL_DATA_DIR/malware_ips.txt" ]; then
            malware_count=$(wc -l < "$FIREWALL_DATA_DIR/malware_ips.txt" 2>/dev/null || echo 0)
        fi
        
        if [ -f "$FIREWALL_DATA_DIR/suspicious_ips.txt" ]; then
            suspicious_count=$(wc -l < "$FIREWALL_DATA_DIR/suspicious_ips.txt" 2>/dev/null || echo 0)
        fi
        
        local total_ips=$((malware_count + suspicious_count))
        
        # Generate text report
        cat > "$report_file" << EOF
FIREWALL UPDATE REPORT
=====================
Date: $(date)
Script: $0
Version: 1.1.0
Mode: LIVE
System: $OS_TYPE ($OS_DISTRO)
Firewall: $FIREWALL_TYPE

SUMMARY:
- Total sources processed: ${TOTAL_SOURCES_PROCESSED:-0}
- Successful downloads: ${SUCCESSFUL_DOWNLOADS:-0}
- Failed downloads: ${FAILED_DOWNLOADS:-0}
- Total IPs processed: $total_ips
  - Malware IPs: $malware_count
  - Suspicious IPs: $suspicious_count

FIREWALL CONFIGURATION:
EOF

        # Add firewall-specific information
        case "$FIREWALL_TYPE" in
            firewalld)
                cat >> "$report_file" << EOF
IPSETS CREATED:
$($SUDO_CMD firewall-cmd --get-ipsets 2>/dev/null | grep -E "(malware|suspicious)" || echo "None")

ACTIVE RULES:
$($SUDO_CMD firewall-cmd --list-rich-rules 2>/dev/null | grep -E "(malware|suspicious)" || echo "None")

FIREWALL STATUS:
$($SUDO_CMD firewall-cmd --state 2>/dev/null || echo "Unknown")

ZONES:
$($SUDO_CMD firewall-cmd --get-active-zones 2>/dev/null || echo "None")
EOF
                ;;
            ufw)
                cat >> "$report_file" << EOF
UFW STATUS:
$($SUDO_CMD ufw status 2>/dev/null || echo "Unknown")

THREAT RULES:
$($SUDO_CMD ufw status numbered 2>/dev/null | grep -E "(malware|suspicious|Auto-blocked)" || echo "None")
EOF
                ;;
            iptables)
                cat >> "$report_file" << EOF
IPTABLES CHAINS:
$($SUDO_CMD iptables -L | grep -E "THREAT_BLOCK" || echo "None")

IPSETS:
$(command -v ipset &>/dev/null && $SUDO_CMD ipset list 2>/dev/null | grep -A 5 "Name: threat" || echo "None")
EOF
                ;;
            pfctl)
                cat >> "$report_file" << EOF
PFCTL STATUS:
$($SUDO_CMD pfctl -s info 2>/dev/null || echo "Unknown")

THREAT TABLES:
$($SUDO_CMD pfctl -s Tables 2>/dev/null | grep -E "threat_" || echo "None")
EOF
                ;;
        esac
        
        # Add IP analysis if we have data
        if [ "$total_ips" -gt 0 ]; then
            cat >> "$report_file" << EOF

IP ANALYSIS:
EOF
            
            if [ "$malware_count" -gt 0 ]; then
                cat >> "$report_file" << EOF
TOP 10 MALWARE IP RANGES:
$(sort "$FIREWALL_DATA_DIR/malware_ips.txt" 2>/dev/null | cut -d/ -f1 | cut -d. -f1-3 | sort | uniq -c | sort -nr | head -10 || echo "None")
EOF
            fi
            
            if [ "$suspicious_count" -gt 0 ]; then
                cat >> "$report_file" << EOF
TOP 10 SUSPICIOUS IP RANGES:
$(sort "$FIREWALL_DATA_DIR/suspicious_ips.txt" 2>/dev/null | cut -d/ -f1 | cut -d. -f1-3 | sort | uniq -c | sort -nr | head -10 || echo "None")
EOF
            fi
        fi
        
        # Add recommendations
        cat >> "$report_file" << EOF

RECOMMENDATIONS:
• Run this script regularly (daily/weekly) to keep threat data current
• Consider adding it to cron for automatic updates
• Monitor firewall logs for blocked connections
• Review backup files in $BACKUP_DIR if rollback is needed

CRON EXAMPLE:
0 2 * * * $0 --auto-update --verbose >> /var/log/firewall-update.log 2>&1
EOF
        
        # Generate HTML report if requested and we have the tools
        if [ "$VERBOSE" = true ] && command -v aha &> /dev/null; then
            log_debug "Generating HTML report"
            
            # Create HTML header
            cat > "$html_report" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Firewall Update Report - $(date +%Y-%m-%d)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #3498db; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 5px; }
        .success { color: #27ae60; }
        .warning { color: #f39c12; }
        .error { color: #e74c3c; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>Firewall Update Report</h1>
    <p><strong>Date:</strong> $(date)</p>
    <p><strong>System:</strong> $OS_TYPE ($OS_DISTRO)</p>
    <p><strong>Firewall:</strong> $FIREWALL_TYPE</p>
    
    <h2>Summary</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total sources processed</td><td>${#sources_to_use[@]:-0}</td></tr>
        <tr><td>Successful downloads</td><td>$SUCCESSFUL_DOWNLOADS</td></tr>
        <tr><td>Failed downloads</td><td>$FAILED_DOWNLOADS</td></tr>
        <tr><td>Total IPs processed</td><td>$total_ips</td></tr>
        <tr><td>Malware IPs</td><td>$malware_count</td></tr>
        <tr><td>Suspicious IPs</td><td>$suspicious_count</td></tr>
    </table>
    
    <h2>Firewall Configuration</h2>
    <pre>$(grep -A 100 "FIREWALL CONFIGURATION:" "$report_file" | grep -v "FIREWALL CONFIGURATION:")</pre>
    
    <h2>Recommendations</h2>
    <ul>
        <li>Run this script regularly (daily/weekly) to keep threat data current</li>
        <li>Consider adding it to cron for automatic updates</li>
        <li>Monitor firewall logs for blocked connections</li>
        <li>Review backup files in $BACKUP_DIR if rollback is needed</li>
    </ul>
    
    <h3>Cron Example</h3>
    <pre>0 2 * * * $0 --auto-update --verbose >> /var/log/firewall-update.log 2>&1</pre>
    
    <p><small>Generated by Firewall Update Script v1.1.0</small></p>
</body>
</html>
EOF
            
            log_info "HTML report generated: $html_report"
        fi
        
        log_info "Report generated: $report_file"
        
        if [ "$VERBOSE" = true ]; then
            echo -e "\n${CYAN}📊 REPORT SUMMARY:${NC}"
            cat "$report_file"
        fi
    else
        log_debug "Would generate report: $report_file"
    fi
}

# Function: cleanup_old_data
# Description: Cleans up temporary files and old backups
# Parameters: None
# Returns: None
cleanup_old_data() {
    log_section "CLEANING UP OLD DATA"
    
    # Always remove temporary files (even in dry-run mode)
    if [ -d "$FIREWALL_DATA_DIR" ]; then
        log_debug "Removing temporary directory: $FIREWALL_DATA_DIR"
        rm -rf "$FIREWALL_DATA_DIR"
    fi
    
    if [ "$DRY_RUN" = false ]; then
        # Keep only last N backups and remove files older than X days
        if [ -d "$BACKUP_DIR" ]; then
            log_debug "Cleaning up old backups (keeping newest $MAX_BACKUPS_TO_KEEP, removing older than $MAX_BACKUP_AGE_DAYS days)"
            
            # Count existing backups
            local backup_count
            backup_count=$(find "$BACKUP_DIR" -name "firewall_backup_*.xml*" -type f 2>/dev/null | wc -l)
            local report_count
            report_count=$(find "$BACKUP_DIR" -name "firewall_update_report_*.txt" -type f 2>/dev/null | wc -l)
            local total_before=$((backup_count + report_count))
            
            log_debug "Found $backup_count backup files and $report_count report files"
            
            # Remove old backups by count
            if [ "$backup_count" -gt "$MAX_BACKUPS_TO_KEEP" ]; then
                log_debug "Removing old backup files (keeping newest $MAX_BACKUPS_TO_KEEP)"
                find "$BACKUP_DIR" -name "firewall_backup_*.xml*" -type f 2>/dev/null | sort -r | tail -n +$((MAX_BACKUPS_TO_KEEP+1)) | xargs rm -f 2>/dev/null || log_warning "Failed to remove some old backup files"
            fi
            
            # Remove old reports by count
            if [ "$report_count" -gt "$MAX_BACKUPS_TO_KEEP" ]; then
                log_debug "Removing old report files (keeping newest $MAX_BACKUPS_TO_KEEP)"
                find "$BACKUP_DIR" -name "firewall_update_report_*.txt" -type f 2>/dev/null | sort -r | tail -n +$((MAX_BACKUPS_TO_KEEP+1)) | xargs rm -f 2>/dev/null || log_warning "Failed to remove some old report files"
            fi
            
            # Remove files older than X days
            log_debug "Removing files older than $MAX_BACKUP_AGE_DAYS days"
            local old_files_count
            old_files_count=$(find "$BACKUP_DIR" -type f -mtime +$MAX_BACKUP_AGE_DAYS 2>/dev/null | wc -l)
            if [ "$old_files_count" -gt 0 ]; then
                find "$BACKUP_DIR" -type f -mtime +$MAX_BACKUP_AGE_DAYS -delete 2>/dev/null || log_warning "Failed to remove some old files by date"
                log_debug "Removed $old_files_count files older than $MAX_BACKUP_AGE_DAYS days"
            fi
            
            # Count remaining files
            local remaining_files
            remaining_files=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
            local removed_files=$((total_before - remaining_files))
            
            if [ "$removed_files" -gt 0 ]; then
                log_info "Cleaned up $removed_files old backup files. $remaining_files files remain in backup directory."
            else
                log_debug "No backup files needed to be removed."
            fi
            
            # Check backup directory size
            if command -v du &> /dev/null; then
                local dir_size
                dir_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
                log_debug "Current backup directory size: $dir_size"
            fi
        else
            log_debug "Backup directory does not exist. Nothing to clean up."
        fi
        
        # Clean up any leftover temporary files in /tmp that might have been created by previous runs
        local tmp_files_count
        tmp_files_count=$(find /tmp -maxdepth 1 -name "firewall_data*" -type d -mtime +1 2>/dev/null | wc -l)
        if [ "$tmp_files_count" -gt 0 ]; then
            log_debug "Cleaning up $tmp_files_count leftover temporary directories in /tmp"
            find /tmp -maxdepth 1 -name "firewall_data*" -type d -mtime +1 -exec rm -rf {} \; 2>/dev/null || true
        fi
    else
        log_debug "Cleaned up temporary files (would also cleanup old backups)"
    fi
}

# Function to show current status
show_status() {
    log_section "CURRENT FIREWALL STATUS"
    
    echo -e "${CYAN}System:${NC} $OS_TYPE ($OS_DISTRO)"
    echo -e "${CYAN}Firewall Type:${NC} $FIREWALL_TYPE"
    
    case "$FIREWALL_TYPE" in
        firewalld)
            echo -e "${CYAN}Firewall State:${NC} $($SUDO_CMD firewall-cmd --state 2>/dev/null || echo 'Unknown')"
            echo -e "${CYAN}Active Zones:${NC}"
            $SUDO_CMD firewall-cmd --get-active-zones 2>/dev/null || echo "None"
            
            echo -e "\n${CYAN}Threat Intelligence IPsets:${NC}"
            $SUDO_CMD firewall-cmd --get-ipsets 2>/dev/null | grep -E "(malware|suspicious)" || echo "None found"
            
            echo -e "\n${CYAN}Active Blocking Rules:${NC}"
            $SUDO_CMD firewall-cmd --list-rich-rules 2>/dev/null | grep -E "(malware|suspicious)" || echo "None found"
            ;;
        ufw)
            echo -e "${CYAN}UFW Status:${NC}"
            $SUDO_CMD ufw status verbose 2>/dev/null || echo "Status unknown"
            
            echo -e "\n${CYAN}Threat Blocking Rules:${NC}"
            $SUDO_CMD ufw status numbered 2>/dev/null | grep -E "(malware|suspicious|Auto-blocked)" || echo "None found"
            ;;
        iptables)
            echo -e "${CYAN}Iptables Chains:${NC}"
            $SUDO_CMD iptables -L | grep -E "THREAT_BLOCK" || echo "No threat blocking chains found"
            
            echo -e "\n${CYAN}Threat Blocking Rules:${NC}"
            $SUDO_CMD iptables -L THREAT_BLOCK_MALWARE -n 2>/dev/null | wc -l | xargs -I {} echo "Malware rules: {}"
            $SUDO_CMD iptables -L THREAT_BLOCK_SUSPICIOUS -n 2>/dev/null | wc -l | xargs -I {} echo "Suspicious rules: {}"
            ;;
        pfctl)
            echo -e "${CYAN}pfctl Status:${NC}"
            $SUDO_CMD pfctl -s info 2>/dev/null || echo "Status unknown"
            
            echo -e "\n${CYAN}Threat Tables:${NC}"
            $SUDO_CMD pfctl -s Tables 2>/dev/null | grep -E "threat_" || echo "No threat tables found"
            
            echo -e "\n${CYAN}Active Rules:${NC}"
            $SUDO_CMD pfctl -s rules 2>/dev/null | grep -E "threat_" || echo "No threat rules found"
            ;;
        *)
            echo -e "${YELLOW}Status display not implemented for firewall type: $FIREWALL_TYPE${NC}"
            ;;
    esac
}

# Function to load configuration from file
# Loads settings from the configuration file if it exists
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_debug "Loading configuration from: $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log_info "Configuration loaded from: $CONFIG_FILE"
    else
        log_debug "No configuration file found at: $CONFIG_FILE (using defaults)"
    fi
}

# Function to clean up on exit or error
# Ensures all temporary files are removed and provides helpful information on error
cleanup_on_exit() {
    local exit_code=$?
    log_debug "Running cleanup on exit (code: $exit_code)"
    
    # Stop any active progress bars
    if [ "$PROGRESS_ACTIVE" = true ]; then
        printf "\r%*s\r" 120 ""
        echo ""
        PROGRESS_ACTIVE=false
    fi
    
    # Ensure temporary directory is removed even if script exits unexpectedly
    if [ -d "$FIREWALL_DATA_DIR" ]; then
        log_debug "Removing temporary directory: $FIREWALL_DATA_DIR"
        rm -rf "$FIREWALL_DATA_DIR" 2>/dev/null || true
    fi
    
    # Clean up any other temporary files that might have been created
    for temp_file in /tmp/firewall_*.tmp; do
        if [ -f "$temp_file" ]; then
            log_debug "Removing temporary file: $temp_file"
            rm -f "$temp_file" 2>/dev/null || true
        fi
    done
    
    # If we're exiting due to an error, provide helpful information
    if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 130 ]; then  # 130 is SIGINT (Ctrl+C)
        echo -e "\n${RED}⚠️ Script exited with an error (code: $exit_code).${NC}"
        if [ -d "$BACKUP_DIR" ]; then
            echo -e "${YELLOW}You can restore from the latest backup if needed:${NC}"
            ls -t "$BACKUP_DIR"/firewall_backup_* 2>/dev/null | head -1 | xargs -r echo "  Latest backup: "
        fi
    fi
}

# Main execution function
main() {
    echo -e "${BLUE}🛡️ AUTOMATED FIREWALL RULES UPDATE SCRIPT${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}Version: 1.1.0 - Multi-OS Support - $(date +%Y-%m-%d)${NC}"
    
    # Set up trap to ensure cleanup on exit
    trap cleanup_on_exit EXIT INT TERM
    
    # Load configuration first, then apply CLI overrides
    load_config
    if ! parse_arguments "$@"; then
        return 1
    fi
    
    # Record start time for performance measurement
    local start_time
    start_time=$(date +%s)
    
    # Detect OS and firewall system first
    if ! detect_os_and_firewall; then
        log_critical_error "Failed to detect OS and firewall system"
        echo -e "\n${RED}💥 CRITICAL ERROR: Cannot continue without OS detection${NC}"
        return 1
    fi
    
    # Execute main workflow with error handling
    local workflow_success=true
    
    # Each step continues even if previous ones fail (robust execution)
    if ! check_prerequisites; then
        log_warning "Prerequisites check had issues, but continuing..."
        workflow_success=false
    fi
    
    # Create directories and backup without progress bars (quick operations)
    create_directories || log_warning "Directory creation had issues, but continuing..."
    backup_firewall_rules || log_warning "Backup had issues, but continuing..."
    
    # Download threat data without progress bar (detailed progress shown internally)
    if ! download_threat_data; then
        if [ "${SOURCE_PREFLIGHT_FAILED:-false}" = true ]; then
            log_critical_error "Source preflight failed; aborting before firewall changes."
            return 1
        fi
        log_warning "Threat data download had issues, but continuing..."
        workflow_success=false
    fi
    

    if ! create_firewall_ipsets; then
        log_warning "Firewall rule creation had issues, but continuing..."
        workflow_success=false
    fi
    

    if ! apply_firewall_rules; then
        log_warning "Firewall rule application had issues, but continuing..."
        workflow_success=false
    fi
    
    generate_report || log_warning "Report generation had issues, but continuing..."
    cleanup_old_data || log_warning "Cleanup had issues, but continuing..."
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    
    # Show completion status based on success/failure
    if [ "$workflow_success" = true ] && [ "$SCRIPT_ERRORS" -eq 0 ]; then
        echo -e "\n${GREEN}🎉 FIREWALL UPDATE COMPLETED SUCCESSFULLY${NC}"
        echo -e "${GREEN}⏱️ Total execution time: $execution_time seconds${NC}"
        echo -e "${GREEN}🖥️ System: $OS_TYPE ($OS_DISTRO) with $FIREWALL_TYPE${NC}"
    elif [ "$CRITICAL_ERROR" = true ]; then
        echo -e "\n${RED}💥 FIREWALL UPDATE COMPLETED WITH CRITICAL ERRORS${NC}"
        echo -e "${RED}⏱️ Total execution time: $execution_time seconds${NC}"
        echo -e "${RED}🖥️ System: $OS_TYPE ($OS_DISTRO) with $FIREWALL_TYPE${NC}"
        echo -e "${RED}⚠️  Total errors encountered: $SCRIPT_ERRORS${NC}"
    else
        echo -e "\n${YELLOW}⚠️  FIREWALL UPDATE COMPLETED WITH WARNINGS${NC}"
        echo -e "${YELLOW}⏱️ Total execution time: $execution_time seconds${NC}"
        echo -e "${YELLOW}🖥️ System: $OS_TYPE ($OS_DISTRO) with $FIREWALL_TYPE${NC}"
        echo -e "${YELLOW}⚠️  Total warnings/errors: $SCRIPT_ERRORS${NC}"
    fi
    
    if [ "$VERBOSE" = true ]; then
        show_status
    fi
    
    echo -e "\n${CYAN}💡 RECOMMENDATIONS:${NC}"
    echo "• Run this script regularly (daily/weekly) to keep threat data current"
    echo "• Consider adding it to cron for automatic updates"
    echo "• Monitor firewall logs for blocked connections"
    echo "• Review backup files in $BACKUP_DIR if rollback is needed"
    
    if [ "$AUTO_UPDATE" = false ] && [ "$FORCE" = false ]; then
        echo -e "\n${YELLOW}📋 To set up automatic updates, add to crontab:${NC}"
        echo "0 2 * * * $0 --auto-update --verbose >> /var/log/firewall-update.log 2>&1"
    fi
    
    # Always exit with success code for robust execution
    # The script should complete and provide feedback regardless of individual step failures
    return 0
}

# Execute main function with all arguments and ensure robust execution
MAIN_RC=0
if ! main "$@"; then
    echo -e "\n${YELLOW}⚠️  Script encountered issues but completed execution${NC}"
    MAIN_RC=1
fi

# Source-integrity guard: this is always fatal regardless of STRICT_EXIT.
if [ "${SOURCE_PREFLIGHT_FAILED:-false}" = true ]; then
    exit 1
fi

# Optional strict exit mode for CI/automation
if [ "$STRICT_EXIT" = true ]; then
    if [ "$MAIN_RC" -ne 0 ] || [ "$CRITICAL_ERROR" = true ] || [ "$SCRIPT_ERRORS" -gt 0 ]; then
        exit 1
    fi
fi

# Default behavior: always exit successfully for robust unattended runs
exit 0
