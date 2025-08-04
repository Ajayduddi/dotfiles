#!/bin/bash
#
# AUTOMATED FIREWALL RULES UPDATE SCRIPT
# Automatically updates firewall rules based on suspicious and malware data
# Supports multiple operating systems and firewall systems
# Version: 1.1.0
# Last Updated: $(date +%Y-%m-%d)
#
# Author: Ajay Duddi
# Repository: https://github.com/Ajayduddi/dotfiles
#

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
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
FIREWALL_DATA_DIR=$(mktemp -d)  # Safer temporary directory creation
BACKUP_DIR="$DOTFILES_DIR/firewall_backups"
CACHE_DIR="$DOTFILES_DIR/.firewall_cache"  # Persistent cache directory
DRY_RUN=false
VERBOSE=false
FORCE=false
AUTO_UPDATE=false
CUSTOM_SOURCES=""
MIN_IPS_THRESHOLD=10  # Minimum number of IPs required for validation
MAX_BACKUPS_TO_KEEP=10  # Maximum number of backup files to keep
MAX_BACKUP_AGE_DAYS=30  # Maximum age of backup files in days
BATCH_SIZE=10000  # Increased batch size for better performance
DOWNLOAD_TIMEOUT=30  # Timeout for downloads in seconds
DOWNLOAD_RETRIES=3  # Number of retries for failed downloads
PARALLEL_DOWNLOADS=true  # Enable parallel processing
MAX_PARALLEL_JOBS=5  # Maximum concurrent downloads
INCREMENTAL_UPDATE=true  # Enable incremental updates
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
    "https://www.spamhaus.org/drop/drop.txt"                                              # Spamhaus DROP - Known bad networks
    "https://www.spamhaus.org/drop/edrop.txt"                                             # Spamhaus EDROP - Extended DROP list
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/malwaredomainlist.ipset"  # MalwareDomainList IPs
    "https://cinsscore.com/list/ci-badguys.txt"                                           # CINS Army List - Attack sources
    "https://rules.emergingthreats.net/blockrules/compromised-ips.txt"                    # Emerging Threats - Compromised IPs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cybercrime.ipset"  # FireHOL Cybercrime tracker
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/malc0de.ipset"     # Malc0de - Malware C&C servers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/zeus.ipset"        # Zeus botnet tracker
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ransomware_rw.ipset" # Ransomware tracker
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/bambenek_c2.ipset" # Bambenek C&C tracker
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/dga_feed.ipset"    # DGA (Domain Generation Algorithm) IPs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/feodo.ipset"       # Feodo tracker - Banking trojans
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/palevo.ipset"      # Palevo worm tracker
)

# Suspicious activity and threat indicators
SUSPICIOUS_SOURCES=(
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset"  # FireHOL Level 1 - High confidence
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset"  # FireHOL Level 2 - Medium confidence
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/tor_exits.ipset"        # Tor exit nodes
    "https://www.dshield.org/block.txt"                                                        # DShield Top Attackers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/botscout.ipset"         # BotScout - Known bots
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cleantalk_new_1d.ipset" # CleanTalk - Recent spammers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/greensnow.ipset"        # GreenSnow - Suspicious IPs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/bruteforceblocker.ipset" # Brute force attackers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/stopforumspam.ipset"    # Stop Forum Spam
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/talos_ipfilter.ipset"   # Cisco Talos IP filter
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/alienvault_reputation.ipset" # AlienVault reputation
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/blocklist_de.ipset"     # Blocklist.de - SSH/FTP attacks
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cruzit_web_attacks.ipset" # Web attack sources
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/sslbl.ipset"            # SSL Blacklist - Bad SSL certs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/urlvir.ipset"           # URLVir - Malicious URLs
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/php_harvesters.ipset"   # PHP harvesters and scanners
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/php_spammers.ipset"     # PHP spammers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/pushing_inertia_blocklist.ipset" # Pushing Inertia blocklist
)

# Additional specialized sources (can be enabled via config)
SPECIALIZED_SOURCES=(
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/coinbl_ips.ipset"       # CoinBlocker - Cryptocurrency miners
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/proxylists.ipset"       # Open proxy servers
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/proxz.ipset"            # ProxZ - Open proxies
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ri_connect_proxies.ipset" # RI Connect proxies
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ri_web_proxies.ipset"   # RI Web proxies
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/xforce.ipset"           # IBM X-Force threat intelligence
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/normshield_all_attack.ipset" # NormShield attacks
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/normshield_all_wannacry.ipset" # WannaCry related IPs
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
                CUSTOM_SOURCES="$2"
                echo -e "${CYAN}📋 CUSTOM SOURCES: Using custom threat sources${NC}"
                shift 2
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

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((SCRIPT_ERRORS++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((SCRIPT_ERRORS++))
}

log_critical_error() {
    echo -e "${RED}💥 CRITICAL ERROR: $1${NC}"
    CRITICAL_ERROR=true
    ((SCRIPT_ERRORS++))
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
    
    read -p "$message [y/N] " response
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
    local cache_name=$(echo "$source" | sed 's|[^a-zA-Z0-9]|_|g')
    echo "$CACHE_DIR/${cache_name}.cache"
}

# Function to get hash file path for a source
get_hash_file() {
    local source="$1"
    local cache_name=$(echo "$source" | sed 's|[^a-zA-Z0-9]|_|g')
    echo "$CACHE_DIR/${cache_name}.hash"
}

# Function to check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    local max_age_seconds=$((CACHE_EXPIRY_HOURS * 3600))
    
    if [ ! -f "$cache_file" ]; then
        return 1  # Cache doesn't exist
    fi
    
    local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
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
    local hash_file=$(get_hash_file "$source")
    
    local new_hash=$(md5sum "$temp_file" 2>/dev/null | cut -d' ' -f1)
    local old_hash=""
    
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
    
    if [ "$USE_NATIVE_IPSET" = true ]; then
        # Use native ipset command (much faster)
        ipset list "$ipset_name" 2>/dev/null | grep -E '^[0-9]' > "$output_file" || touch "$output_file"
    else
        # Fallback to firewall-cmd
        firewall-cmd --permanent --ipset="$ipset_name" --get-entries 2>/dev/null > "$output_file" || touch "$output_file"
    fi
    
    local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
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
    
    local add_count=$(wc -l < "$add_ips_file" 2>/dev/null || echo 0)
    local remove_count=$(wc -l < "$remove_ips_file" 2>/dev/null || echo 0)
    
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

# Function to add IPs to ipset in bulk (optimized)
add_ips_to_ipset_bulk() {
    local ipset_name="$1"
    local ips_file="$2"
    
    if [ ! -s "$ips_file" ]; then
        return 0  # No IPs to add
    fi
    
    if [ "$DRY_RUN" = true ]; then
        local count=$(wc -l < "$ips_file")
        log_debug "Would add $count IPs to ipset: $ipset_name"
        return 0
    fi
    
    if [ "$USE_NATIVE_IPSET" = true ]; then
        # Use native ipset with restore format (fastest method)
        {
            while IFS= read -r ip; do
                [ -n "$ip" ] && echo "add $ipset_name $ip"
            done < "$ips_file"
        } | ipset restore -exist 2>/dev/null
        return $?
    else
        # Fallback to firewall-cmd batch processing
        local batch_file="$FIREWALL_DATA_DIR/batch_add_${ipset_name}.txt"
        while IFS= read -r ip; do
            [ -n "$ip" ] && echo "--ipset=$ipset_name --add-entry=$ip"
        done < "$ips_file" > "$batch_file"
        
        if [ -s "$batch_file" ]; then
            firewall-cmd --permanent $(cat "$batch_file") 2>/dev/null
            local result=$?
            rm -f "$batch_file"
            return $result
        fi
    fi
    
    return 1
}

# Function to remove IPs from ipset in bulk
remove_ips_from_ipset_bulk() {
    local ipset_name="$1"
    local ips_file="$2"
    
    if [ ! -s "$ips_file" ]; then
        return 0  # No IPs to remove
    fi
    
    if [ "$DRY_RUN" = true ]; then
        local count=$(wc -l < "$ips_file")
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
    
    # Check for download tools
    if command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -s -L --connect-timeout 30 --max-time 300"
        log_debug "Using curl for downloads"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -q -T 30 -t 3 -O -"
        log_debug "Using wget for downloads"
    else
        handle_error "Neither curl nor wget is available. Please install one of them:" false
        suggest_package_install "curl"
        if [ "$FORCE" = false ]; then
            return 1
        fi
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
                log_info "Created directory: $dir"
            else
                log_debug "Created temporary directory for dry-run: $dir"
            fi
        else
            log_debug "Directory already exists: $dir"
        fi
    done
}

# Function to backup current firewall rules
backup_firewall_rules() {
    log_section "BACKING UP CURRENT FIREWALL RULES"
    
    local backup_file="$BACKUP_DIR/firewall_backup_$(date +%Y%m%d_%H%M%S)"
    
    if [ "$DRY_RUN" = false ]; then
        case "$FIREWALL_TYPE" in
            firewalld)
                if $SUDO_CMD firewall-cmd --list-all-zones > "${backup_file}.zones" 2>/dev/null; then
                    log_info "Backed up firewall zones to: ${backup_file}.zones"
                fi
                
                if $SUDO_CMD firewall-cmd --list-ipsets > "${backup_file}.ipsets" 2>/dev/null; then
                    log_info "Backed up firewall ipsets to: ${backup_file}.ipsets"
                fi
                
                # Export complete configuration
                if $SUDO_CMD firewall-cmd --export-config > "${backup_file}.xml" 2>/dev/null; then
                    log_info "Backed up complete firewall config to: ${backup_file}.xml"
                else
                    log_warning "Could not export complete firewall configuration"
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
    local cache_file=$(get_cache_file "$source")
    if is_cache_valid "$cache_file" && [ "$FORCE" = false ]; then
        log_debug "Using cached data for: $(basename "$source")"
        local processed_count=$(wc -l < "$cache_file" 2>/dev/null || echo 0)
        echo "$processed_count:$cache_file" > "$result_file"
        return 0
    fi
    
    local temp_file="$FIREWALL_DATA_DIR/temp_${source_index}.txt"
    local download_success=false
    local retry_count=0
    
    # Download with retries
    while [ $retry_count -lt $DOWNLOAD_RETRIES ] && [ "$download_success" = false ]; do
        if curl -s -L --max-time $DOWNLOAD_TIMEOUT "$source" -o "$temp_file" 2>/dev/null; then
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
            local processed_count=$(wc -l < "$cache_file" 2>/dev/null || echo 0)
            echo "$processed_count:$cache_file" > "$result_file"
            rm -f "$temp_file"
            return 0
        fi
    fi
    
    # Validate file format
    if ! grep -qE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$temp_file"; then
        echo "0:INVALID" > "$result_file"
        rm -f "$temp_file"
        return 1
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
    > "$output_file"
    
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
    
    local sources_to_use=()
    local successful_downloads=0
    local failed_downloads=0
    
    # Use custom sources if provided
    if [ -n "$CUSTOM_SOURCES" ] && [ -f "$CUSTOM_SOURCES" ]; then
        log_info "Using custom threat sources from: $CUSTOM_SOURCES"
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ ]] && continue  # Skip comments
            [[ -z "$line" ]] && continue        # Skip empty lines
            
            # Validate URL format
            if [[ "$line" =~ ^https?:// ]]; then
                sources_to_use+=("$line")
                log_debug "Added custom source: $line"
            else
                log_warning "Skipping invalid URL in custom sources: $line"
            fi
        done < "$CUSTOM_SOURCES"
        
        if [ ${#sources_to_use[@]} -eq 0 ]; then
            log_warning "No valid URLs found in custom sources file. Using default sources."
            sources_to_use=("${MALWARE_SOURCES[@]}" "${SUSPICIOUS_SOURCES[@]}")
        fi
    else
        # Use default sources
        sources_to_use=("${MALWARE_SOURCES[@]}" "${SUSPICIOUS_SOURCES[@]}")
        
        # Add specialized sources if enabled
        if [ "$ENABLE_SPECIALIZED_SOURCES" = true ]; then
            log_info "Including specialized threat intelligence sources"
            sources_to_use+=("${SPECIALIZED_SOURCES[@]}")
        fi
        
        # Add specific categories if enabled
        if [ "$ENABLE_PROXY_BLOCKING" = true ]; then
            log_info "Including proxy server blocking sources"
            sources_to_use+=(
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/proxylists.ipset"
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/proxz.ipset"
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ri_connect_proxies.ipset"
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ri_web_proxies.ipset"
            )
        fi
        
        if [ "$ENABLE_CRYPTO_MINING_BLOCKING" = true ]; then
            log_info "Including cryptocurrency mining blocking sources"
            sources_to_use+=(
                "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/coinbl_ips.ipset"
            )
        fi
    fi
    
    local malware_ips="$FIREWALL_DATA_DIR/malware_ips.txt"
    local suspicious_ips="$FIREWALL_DATA_DIR/suspicious_ips.txt"
    
    # Clear previous data
    > "$malware_ips"
    > "$suspicious_ips"
    
    local total_sources=${#sources_to_use[@]}
    log_info "Downloading from $total_sources threat intelligence sources..."
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "Would download and process threat intelligence data"
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
    local source_index=0
    for source in "${sources_to_use[@]}"; do
        ((source_index++))
        local result_file="$FIREWALL_DATA_DIR/result_${source_index}.txt"
        
        if [ -f "$result_file" ]; then
            local result=$(cat "$result_file")
            local count=$(echo "$result" | cut -d':' -f1)
            local data_file=$(echo "$result" | cut -d':' -f2)
            
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
                ((successful_downloads++))
            else
                case "$data_file" in
                    "FAILED") log_warning "Failed to download from: $source" ;;
                    "INVALID") log_warning "Downloaded file from $source does not contain valid IP format" ;;
                    "EMPTY") log_warning "Downloaded file from $source contained no valid IP addresses" ;;
                esac
                ((failed_downloads++))
            fi
            
            rm -f "$result_file"
        else
            log_warning "No result file for source: $source"
            ((failed_downloads++))
        fi
    done
    
    # Final processing and deduplication
    local malware_count=$(wc -l < "$malware_ips" 2>/dev/null || echo 0)
    local suspicious_count=$(wc -l < "$suspicious_ips" 2>/dev/null || echo 0)
    
    log_info "Downloaded $malware_count malware IPs and $suspicious_count suspicious IPs from $successful_downloads sources ($failed_downloads failed)"
    
    # Sort and deduplicate the IP lists (optimized)
    if [ "$malware_count" -gt 0 ]; then
        sort -u "$malware_ips" -o "$malware_ips"
        malware_count=$(wc -l < "$malware_ips")
        log_debug "After deduplication: $malware_count unique malware IPs"
    fi
    
    if [ "$suspicious_count" -gt 0 ]; then
        sort -u "$suspicious_ips" -o "$suspicious_ips"
        suspicious_count=$(wc -l < "$suspicious_ips")
        log_debug "After deduplication: $suspicious_count unique suspicious IPs"
    fi
    
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
    if [ "$successful_downloads" -eq 0 ] && [ "$FORCE" = true ]; then
        log_warning "All downloads failed but continuing due to --force option"
    elif [ "$successful_downloads" -eq 0 ] && [ "$FORCE" = false ]; then
        if ! confirm_action "All downloads failed. Continue anyway?"; then
            handle_error "All downloads failed" false
            return 1
        fi
    fi
}

# Old process_threat_data function replaced with optimized version above

create_firewall_ipsets() {
    log_section "CREATING FIREWALL BLOCKING RULES"
    
    local malware_ips="$FIREWALL_DATA_DIR/malware_ips.txt"
    local suspicious_ips="$FIREWALL_DATA_DIR/suspicious_ips.txt"
    
    # Process the file to extract valid IP addresses and CIDR blocks
    # Handle different source formats:
    # 1. IPsum format: "IP\tcount" (e.g., "179.43.189.98\t10")
    # 2. Spamhaus format: "CIDR ; comment" (e.g., "1.10.16.0/20 ; SBL256894")
    # 3. DShield format: "IP\tcount\tname" (e.g., "1.2.3.4\t100\tAS1234")
    # 4. FireHOL format: plain IPs or CIDRs, one per line
    # 5. Clean format: just IPs/CIDRs, one per line
    
    # Clear the processed file
    > "$processed_file"
    
    # First, normalize line endings and remove comments
    tr -d '\r' < "$temp_file" | grep -v '^#' | grep -v '^;' | grep -v '^$' > "${temp_file}.clean" 2>/dev/null || true
    
    # Extract IPs/CIDRs using multiple patterns based on source type
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
        # DShield format: start_ip\tend_ip\tcidr\tcount\tname\tcountry\temail
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.0[[:space:]]+[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.255[[:space:]]+24' "${temp_file}.clean" 2>/dev/null | \
            awk '{print $1}' | sed 's/\.0$/\.0\/24/' || true
        
        # Pattern 5: Any line starting with an IP (fallback)
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "${temp_file}.clean" 2>/dev/null | \
            grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?' || true
        
    } | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$' | sort -u > "$processed_file"
    
    # Clean up temporary file
    rm -f "${temp_file}.clean"
    
    # Validate IP addresses and count valid ones
    local valid_count=0
    if [ -s "$processed_file" ]; then
        # Filter for valid IP addresses (basic check)
        while IFS= read -r ip; do
            # Skip empty lines
            [[ -z "$ip" ]] && continue
            
            # Extract IP part (without CIDR)
            local ip_part
            if [[ "$ip" == */* ]]; then
                ip_part=$(echo "$ip" | cut -d'/' -f1)
            else
                ip_part="$ip"
            fi
            
            # Basic validation of IP format
            if [[ "$ip_part" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                # Check each octet is <= 255
                local valid=true
                IFS='.' read -r -a octets <<< "$ip_part"
                for octet in "${octets[@]}"; do
                    if [ "$octet" -gt 255 ]; then
                        valid=false
                        break
                    fi
                done
                
                if [ "$valid" = true ]; then
                    echo "$ip" >> "$target_file"
                    ((valid_count++))
                fi
            fi
        done < "$processed_file"
    fi
    
    # Clean up
    rm -f "$processed_file"
    
    # Return the count of valid IPs processed
    echo "$valid_count"
}

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
        local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
        
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
            if $SUDO_CMD firewall-cmd --permanent --new-ipset="$ipset_name" --type=hash:net --option=family=inet --option=hashsize=8192 --option=maxelem=500000 2>/dev/null; then
                log_debug "Created ipset: $ipset_name"
                # Add description
                $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --set-description="$description" 2>/dev/null || true
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
        
        # Use incremental updates if enabled and ipset exists
        if [ "$INCREMENTAL_UPDATE" = true ] && [ "$ipset_exists" = true ]; then
            log_debug "Using incremental update for ipset: $ipset_name"
            if update_ipset_incremental "$ipset_name" "$ip_file"; then
                log_info "Incrementally updated ipset: $ipset_name"
                return 0
            else
                log_debug "No incremental updates needed for ipset: $ipset_name"
                return 0
            fi
        fi
        
        # Full update - use optimized bulk operations
        log_debug "Performing full update for ipset: $ipset_name"
        
        # Clear existing entries if doing full update
        if [ "$ipset_exists" = true ]; then
            if [ "$USE_NATIVE_IPSET" = true ]; then
                $SUDO_CMD ipset flush "$ipset_name" 2>/dev/null || true
            else
                # Clear entries using firewall-cmd (slower but compatible)
                $SUDO_CMD firewall-cmd --permanent --ipset="$ipset_name" --remove-entries-from-file="$ip_file" 2>/dev/null || true
            fi
        fi
        
        # Add all IPs using optimized method
        if add_ips_to_ipset_bulk "$ipset_name" "$ip_file"; then
            log_info "Added $ip_count IPs to firewalld ipset: $ipset_name (optimized bulk mode)"
            return 0
        else
            # Fallback to traditional batch processing
            log_warning "Bulk addition failed, falling back to traditional batch mode"
            return create_firewalld_ipset_fallback "$ipset_name" "$ip_file" "$ip_count"
        fi
    else
        local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
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
            local batch_size=$(wc -l < "$batch_file")
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
        local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
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
        local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
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
        local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
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
                    use_ipset=false
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
                        local batch_size=$(wc -l < "$restore_file")
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
        local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
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
            
            local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
            log_info "Added pfctl table '$table_name' with $ip_count IPs"
        else
            # Reload the table
            $SUDO_CMD pfctl -t "$table_name" -T replace -f "$table_file" 2>/dev/null || log_warning "Failed to reload pfctl table"
            local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
            log_info "Updated pfctl table '$table_name' with $ip_count IPs"
        fi
    else
        local ip_count=$(wc -l < "$ip_file" 2>/dev/null || echo 0)
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
            if $SUDO_CMD firewall-cmd --get-ipsets | grep -q "$ipset"; then
                # Remove existing rule if it exists
                $SUDO_CMD firewall-cmd --permanent --remove-rich-rule="rule source ipset=$ipset drop" 2>/dev/null || true
                
                # Add new blocking rule
                if $SUDO_CMD firewall-cmd --permanent --add-rich-rule="rule source ipset=$ipset drop"; then
                    log_info "Applied firewalld blocking rule for ipset: $ipset"
                else
                    log_error "Failed to apply firewalld blocking rule for ipset: $ipset"
                fi
            fi
        else
            log_debug "Would apply firewalld blocking rule for ipset: $ipset"
        fi
    done
    
    # Reload firewall to apply changes
    if [ "$DRY_RUN" = false ]; then
        if $SUDO_CMD firewall-cmd --reload; then
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
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
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
- Total sources processed: ${#sources_to_use[@]:-0}
- Successful downloads: $successful_downloads
- Failed downloads: $failed_downloads
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
        <tr><td>Successful downloads</td><td>$successful_downloads</td></tr>
        <tr><td>Failed downloads</td><td>$failed_downloads</td></tr>
        <tr><td>Total IPs processed</td><td>$total_ips</td></tr>
        <tr><td>Malware IPs</td><td>$malware_count</td></tr>
        <tr><td>Suspicious IPs</td><td>$suspicious_count</td></tr>
    </table>
    
    <h2>Firewall Configuration</h2>
    <pre>$(cat "$report_file" | grep -A 100 "FIREWALL CONFIGURATION:" | grep -v "FIREWALL CONFIGURATION:")</pre>
    
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
            local backup_count=$(find "$BACKUP_DIR" -name "firewall_backup_*.xml*" -type f 2>/dev/null | wc -l)
            local report_count=$(find "$BACKUP_DIR" -name "firewall_update_report_*.txt" -type f 2>/dev/null | wc -l)
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
            local old_files_count=$(find "$BACKUP_DIR" -type f -mtime +$MAX_BACKUP_AGE_DAYS 2>/dev/null | wc -l)
            if [ "$old_files_count" -gt 0 ]; then
                find "$BACKUP_DIR" -type f -mtime +$MAX_BACKUP_AGE_DAYS -delete 2>/dev/null || log_warning "Failed to remove some old files by date"
                log_debug "Removed $old_files_count files older than $MAX_BACKUP_AGE_DAYS days"
            fi
            
            # Count remaining files
            local remaining_files=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
            local removed_files=$((total_before - remaining_files))
            
            if [ "$removed_files" -gt 0 ]; then
                log_info "Cleaned up $removed_files old backup files. $remaining_files files remain in backup directory."
            else
                log_debug "No backup files needed to be removed."
            fi
            
            # Check backup directory size
            if command -v du &> /dev/null; then
                local dir_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
                log_debug "Current backup directory size: $dir_size"
            fi
        else
            log_debug "Backup directory does not exist. Nothing to clean up."
        fi
        
        # Clean up any leftover temporary files in /tmp that might have been created by previous runs
        local tmp_files_count=$(find /tmp -maxdepth 1 -name "firewall_data*" -type d -mtime +1 2>/dev/null | wc -l)
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
    
    # Parse command line arguments first
    parse_arguments "$@"
    
    # Load configuration file (after parsing arguments so CLI options take precedence)
    load_config
    
    # Record start time for performance measurement
    local start_time=$(date +%s)
    
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
    
    create_directories || log_warning "Directory creation had issues, but continuing..."
    
    backup_firewall_rules || log_warning "Backup had issues, but continuing..."
    
    if ! download_threat_data; then
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
    local end_time=$(date +%s)
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
if ! main "$@"; then
    echo -e "\n${YELLOW}⚠️  Script encountered issues but completed execution${NC}"
fi

# Always exit successfully to ensure robust behavior
exit 0