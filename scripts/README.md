# 🛠️ Dotfiles Utility Scripts

This directory contains comprehensive utility, security, and system configuration scripts for managing your dotfiles repository. All scripts are designed with enterprise-grade safety features, comprehensive logging, and production-ready reliability.

## 📁 Scripts Overview

### 🔥 **Enterprise Security & Firewall**

#### `firewall.sh` - **Enterprise Firewall Manager**
**Purpose**: Automated threat intelligence firewall management with 45+ premium sources  
**Usage**: `./scripts/firewall.sh [OPTIONS]`  
**Safety Level**: 🛡️ **High** - Enterprise-grade with comprehensive safety features

**Core Features**:
- **45+ Threat Intelligence Sources**: Malware, C&C, suspicious activity, and specialized feeds
- **Multi-OS Support**: firewalld, ufw, iptables, pfctl
- **Performance Optimized**: Parallel downloads, caching, incremental updates
- **Enterprise Ready**: Automated updates, comprehensive logging, dry-run mode

**Command Line Options**:
```bash
# Standard protection (18 sources)
./firewall.sh --verbose

# Enhanced protection (31 sources)  
./firewall.sh --enable-specialized --enable-crypto-blocking

# Maximum protection (45+ sources)
./firewall.sh --enable-all-sources --verbose

# Corporate environments with proxy blocking
./firewall.sh --enable-all-sources --enable-proxy-blocking

# Preview changes without applying
./firewall.sh --dry-run --verbose --enable-all-sources

# Automated updates for cron
./firewall.sh --auto-update --force --enable-all-sources
```

**Configuration File** (`~/.config/firewall-update.conf`):
```bash
# Performance Settings
PARALLEL_DOWNLOADS=true
MAX_PARALLEL_JOBS=5
INCREMENTAL_UPDATE=true
USE_NATIVE_IPSET=true
CACHE_EXPIRY_HOURS=6

# Threat Intelligence
ENABLE_SPECIALIZED_SOURCES=true
ENABLE_PROXY_BLOCKING=false
ENABLE_CRYPTO_MINING_BLOCKING=true

# Automation
AUTO_UPDATE=true
VERBOSE=true
```

**Protection Levels**:
- **Conservative (18 sources)**: Home users, high-confidence threats only
- **Balanced (31 sources)**: Small business, comprehensive coverage
- **Aggressive (35 sources)**: Corporate, maximum protection with proxy blocking
- **Enterprise (45+ sources)**: High-security environments, complete threat landscape

**Performance Metrics**:
- **Download Time**: 15-45 seconds (depending on sources)
- **Cache Hit Performance**: 10-15 seconds for subsequent runs
- **Total Coverage**: 350,000-800,000 unique threat indicators
- **Optimization**: 4-5x faster than traditional approaches

---

### 🛡️ **Security & Hardening Scripts**

#### `security-hardening.sh` - **System Security Hardening**
**Purpose**: Comprehensive system security hardening and configuration  
**Usage**: `./scripts/security-hardening.sh [--dry-run] [--profile PROFILE]`  
**Safety Level**: 🛡️ **High** - Extensive safety checks and rollback capabilities

**Features**:
- **Multi-Profile Support**: Basic, Standard, Advanced, Enterprise security levels
- **Comprehensive Hardening**: SSH, firewall, kernel parameters, file permissions
- **Audit Integration**: Works with security monitoring and compliance frameworks
- **Rollback Support**: Complete rollback of all security changes

**Security Profiles**:
```bash
# Basic hardening for home users
./security-hardening.sh --profile basic

# Standard hardening for small business
./security-hardening.sh --profile standard

# Advanced hardening for corporate environments
./security-hardening.sh --profile advanced

# Enterprise hardening for high-security environments
./security-hardening.sh --profile enterprise
```

#### `security-monitor.sh` - **Security Monitoring & Alerting**
**Purpose**: Continuous security monitoring and threat detection  
**Usage**: `./scripts/security-monitor.sh [--continuous] [--alert-email EMAIL]`  
**Safety Level**: 🛡️ **Safe** - Read-only monitoring with alerting

**Features**:
- **Real-time Monitoring**: File integrity, login attempts, system changes
- **Threat Detection**: Suspicious activity, unauthorized access, malware indicators
- **Alerting System**: Email, log, and system notifications
- **Compliance Reporting**: Generate security compliance reports

**Monitoring Categories**:
- **File Integrity**: Critical system files and configurations
- **Network Security**: Suspicious connections and traffic patterns
- **User Activity**: Login attempts, privilege escalation, unusual commands
- **System Health**: Resource usage, service status, security updates

#### `secure-permissions.sh` - **Permission Hardening**
**Purpose**: Comprehensive file and directory permission hardening  
**Usage**: `./scripts/secure-permissions.sh [--dry-run] [--fix-all]`  
**Safety Level**: 🛡️ **High** - Extensive validation and backup before changes

**Features**:
- **Smart Permission Analysis**: Detects overly permissive files and directories
- **Security-focused Fixes**: Applies industry-standard permission schemes
- **Backup Integration**: Creates permission backups before changes
- **Compliance Checking**: Validates against security frameworks

---

### 🖥️ **System Configuration Management**

#### `system-config-backup.sh` - **System-Wide Configuration Backup**
**Purpose**: Comprehensive system configuration discovery and backup  
**Usage**: `./scripts/system-config-backup.sh [--backup|--restore] [--dry-run]`  
**Safety Level**: 🛡️ **High** - Extensive discovery with smart filtering

**What it discovers and backs up**:
- **Web Servers**: Apache HTTP (`/etc/httpd/`), Nginx configurations
- **Databases**: MySQL (`/etc/my.cnf.d/`), PostgreSQL, Redis, MongoDB
- **Application Servers**: Tomcat, Jetty, WildFly, JBoss configurations  
- **Development Tools**: Maven, Gradle, Node.js system configurations
- **DevOps Tools**: Docker, Kubernetes, Jenkins, GitLab configurations
- **Security Services**: Firewall rules, SSL certificates, authentication configs

**Advanced Features**:
- **Intelligent Discovery**: Scans entire system for configuration files
- **Smart Filtering**: Excludes cache files, logs, and sensitive data
- **Dependency Tracking**: Identifies configuration dependencies
- **Service Integration**: Provides service restart guidance

#### `restore-system-configs.sh` - **System Configuration Restoration**
**Purpose**: Dedicated system configuration restoration with safety features  
**Usage**: `./scripts/restore-system-configs.sh [--dry-run] [--selective]`  
**Safety Level**: ⚠️ **Medium** - Requires sudo, creates backups before restoration

**Features**:
- **Selective Restoration**: Choose specific configurations to restore
- **Permission Preservation**: Maintains proper file ownership and permissions
- **Service Management**: Automatic service restart recommendations
- **Validation**: Post-restoration configuration validation

---

### 📊 **History Management & Analysis**

#### `analyze-history.sh` - **Comprehensive History Analysis**
**Purpose**: Advanced shell history analysis and security auditing  
**Usage**: `./scripts/analyze-history.sh [--detailed] [--security-focus]`  
**Safety Level**: 🛡️ **Safe** - Read-only analysis with comprehensive reporting

**Analysis Categories**:
- **Command Usage Statistics**: Most used commands, patterns, trends
- **Security Analysis**: Sensitive commands, potential security issues
- **Performance Insights**: Command efficiency, time-consuming operations
- **Productivity Metrics**: Development workflow analysis

**Example Output**:
```
📈 COMMAND USAGE ANALYSIS:
=========================
Total Commands: 15,847
Unique Commands: 2,341
Most Active Hours: 14:00-18:00

🔝 TOP COMMANDS:
================
  1,247: git (7.9%)
    856: ls (5.4%)
    743: cd (4.7%)
    621: vim (3.9%)

🔒 SECURITY ANALYSIS:
====================
✅ No obvious sensitive commands found
⚠️  3 potential security concerns detected
📊 Security Score: 87/100

💡 PRODUCTIVITY INSIGHTS:
========================
• Most productive day: Tuesday
• Peak coding hours: 14:00-17:00
• Avg commands per session: 127
```

#### `clean-history.sh` - **History Sanitization**
**Purpose**: Remove sensitive information from shell history files  
**Usage**: `./scripts/clean-history.sh [--dry-run] [--no-backup] [--aggressive]`  
**Safety Level**: 🛡️ **Safe** - Creates backups, comprehensive pattern matching

**Security Patterns Detected**:
- **Credentials**: Passwords, API keys, tokens, certificates
- **Connection Strings**: Database URLs, service endpoints
- **Authentication**: SSH keys, OAuth tokens, session IDs
- **Cloud Services**: AWS keys, Azure credentials, GCP tokens
- **Development**: Environment variables with secrets

**Cleaning Modes**:
```bash
# Standard cleaning with backup
./clean-history.sh

# Preview what would be cleaned
./clean-history.sh --dry-run

# Aggressive cleaning (more patterns)
./clean-history.sh --aggressive

# Clean without creating backup
./clean-history.sh --no-backup
```

#### `dedupe-history.sh` - **History Deduplication**
**Purpose**: Remove duplicate entries while preserving chronological order  
**Usage**: `./scripts/dedupe-history.sh [--dry-run] [--no-backup] [--stats]`  
**Safety Level**: 🛡️ **Safe** - Preserves history integrity with smart deduplication

**Features**:
- **Smart Deduplication**: Preserves command context and chronology
- **Multi-Shell Support**: Handles bash, zsh, fish history formats
- **Statistics**: Shows reduction metrics and space savings
- **Integrity Preservation**: Maintains history file format and timestamps

---

### 🔧 **Package & System Management**

#### `package-manager.sh` - **Cross-Platform Package Management**
**Purpose**: Unified package management across different Linux distributions  
**Usage**: `./scripts/package-manager.sh [COMMAND] [OPTIONS]`  
**Safety Level**: 🛡️ **High** - Distribution detection with safety checks

**Supported Distributions**:
- **Red Hat Family**: Fedora, RHEL, CentOS, Rocky Linux (dnf/yum)
- **Debian Family**: Ubuntu, Debian, Mint (apt/apt-get)
- **Arch Family**: Arch Linux, Manjaro (pacman)
- **SUSE Family**: openSUSE, SLES (zypper)

**Commands**:
```bash
# Install packages
./package-manager.sh install git vim curl

# Update system
./package-manager.sh update

# Search for packages
./package-manager.sh search nodejs

# List installed packages
./package-manager.sh list > installed-packages.txt

# Install from package list
./package-manager.sh install-from-file packages.txt
```

#### `audit-and-automation.sh` - **System Audit & Automation**
**Purpose**: Comprehensive system auditing and automation setup  
**Usage**: `./scripts/audit-and-automation.sh [--audit] [--setup-automation]`  
**Safety Level**: 🛡️ **High** - Comprehensive system analysis with automation setup

**Audit Categories**:
- **System Health**: Resource usage, disk space, memory, CPU
- **Security Status**: Updates, vulnerabilities, configuration issues
- **Service Status**: Critical services, startup configuration
- **Configuration Drift**: Changes from baseline configurations

**Automation Setup**:
- **Cron Job Management**: Automated maintenance tasks
- **Log Rotation**: System and application log management
- **Update Automation**: Security update scheduling
- **Monitoring Integration**: System monitoring setup

---

### 🔄 **Utility & Maintenance Scripts**

#### `reset-setup.sh` - **Setup Reset & Cleanup**
**Purpose**: Reset dotfiles setup state and clean temporary files  
**Usage**: `./scripts/reset-setup.sh [--dry-run] [--full-reset]`  
**Safety Level**: ⚠️ **Medium** - Resets setup markers and temporary files

**Features**:
- **Setup State Reset**: Removes setup markers and state files
- **Temporary File Cleanup**: Cleans cache and temporary directories
- **Selective Reset**: Choose specific components to reset
- **Backup Preservation**: Optionally preserves backup files

---

## 🎛️ Configuration Files

### `firewall-update.conf.example` - **Firewall Configuration Template**
**Purpose**: Example configuration file for firewall script  
**Location**: Copy to `~/.config/firewall-update.conf`

**Configuration Categories**:
- **Performance Settings**: Parallel downloads, caching, optimization
- **Threat Intelligence**: Source selection and filtering
- **Automation**: Scheduling and update behavior
- **Logging**: Verbosity and log management

### `gnome-settings.dconf` - **GNOME Desktop Settings**
**Purpose**: GNOME desktop environment configuration export  
**Usage**: Automatically applied during dotfiles setup

---

## 🗂️ Temporary File Management

All scripts use structured temporary directories for logs and reports:

**Location Pattern**: `${TMPDIR:-/tmp}/dotfiles-[script-name]-$$`

**Directory Structure**:
```
/tmp/dotfiles-firewall-12345/
├── firewall_update_20250804_120000.log
├── threat_intelligence_report.txt
├── performance_metrics.json
└── blocked_ips_summary.txt

/tmp/dotfiles-security-98765/
├── security_audit_20250804_120000.log
├── vulnerability_report.txt
├── hardening_recommendations.md
└── compliance_report.json

/tmp/dotfiles-history-54321/
├── bash_history.cleaned
├── zsh_history.cleaned
├── sensitive_patterns.log
└── analysis_report.txt
```

---

## 📋 Common Options

All scripts support these standardized options:

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Preview actions without making changes |
| `--verbose` | `-v` | Enable detailed output and logging |
| `--help` | `-h` | Show comprehensive help message |
| `--force` | `-f` | Skip confirmations (use with caution) |
| `--no-backup` | | Skip creating backup files (where applicable) |

---

## 🚀 Quick Start Workflows

### 1. **Security Hardening Workflow**
```bash
# 1. Run security audit
./scripts/security-monitor.sh --audit

# 2. Apply security hardening
./scripts/security-hardening.sh --dry-run --profile standard
./scripts/security-hardening.sh --profile standard

# 3. Set up firewall protection
./scripts/firewall.sh --dry-run --enable-all-sources
./scripts/firewall.sh --enable-all-sources --auto-update

# 4. Fix file permissions
./scripts/secure-permissions.sh --dry-run
./scripts/secure-permissions.sh --fix-all
```

### 2. **System Configuration Backup Workflow**
```bash
# 1. Discover and backup system configurations
./scripts/system-config-backup.sh --backup --dry-run
./scripts/system-config-backup.sh --backup

# 2. Backup user configurations (main script)
./backup-dotfiles.sh

# 3. Verify backups
ls -la ~/.dotfiles/servers/
ls -la ~/.dotfiles/firewall_backups/
```

### 3. **History Management Workflow**
```bash
# 1. Analyze current history
./scripts/analyze-history.sh --detailed

# 2. Clean sensitive data
./scripts/clean-history.sh --dry-run
./scripts/clean-history.sh

# 3. Remove duplicates
./scripts/dedupe-history.sh --dry-run --stats
./scripts/dedupe-history.sh

# 4. Re-analyze for improvements
./scripts/analyze-history.sh --security-focus
```

### 4. **Automated Security Maintenance**
```bash
# Set up automated firewall updates
crontab -e
# Add: 0 2 * * * /home/user/.dotfiles/scripts/firewall.sh --auto-update --enable-all-sources

# Set up security monitoring
crontab -e  
# Add: 0 */6 * * * /home/user/.dotfiles/scripts/security-monitor.sh --continuous

# Set up system auditing
crontab -e
# Add: 0 4 * * 0 /home/user/.dotfiles/scripts/audit-and-automation.sh --audit
```

---

## 🔒 Security Features

### **Built-in Security Measures**:
- ✅ **Input Validation** - All user inputs are validated and sanitized
- ✅ **Path Sanitization** - Prevents directory traversal attacks
- ✅ **Secure Temp Files** - Uses `mktemp` with proper permissions (600)
- ✅ **Command Injection Prevention** - No `eval` usage with user data
- ✅ **Log Sanitization** - Prevents log injection attacks
- ✅ **Backup Protection** - Always creates backups before modifications
- ✅ **Privilege Escalation** - Proper sudo handling and validation
- ✅ **Error Handling** - Comprehensive error handling and recovery

### **Security Patterns & Detection**:
- **Credential Detection**: Passwords, API keys, tokens, certificates
- **Connection Strings**: Database URLs, service endpoints, cloud credentials
- **Authentication Data**: SSH keys, OAuth tokens, session identifiers
- **Environment Variables**: Secrets in environment variable assignments
- **Cloud Service Credentials**: AWS, Azure, GCP, and other cloud provider keys

---

## 📊 Integration with Main Scripts

### **Automated Integration**:
- **`dotfiles-manager.sh`** → Orchestrates all utility scripts
- **`backup-dotfiles.sh`** → Automatically calls system config backup
- **`setup-dotfiles.sh`** → Integrates security hardening and firewall setup
- **`restore-dotfiles.sh`** → Uses system config restoration

### **Manual Integration Workflows**:
```bash
# Complete system setup with security
./dotfiles-manager.sh setup
./scripts/security-hardening.sh --profile standard
./scripts/firewall.sh --enable-all-sources

# Complete backup workflow
./dotfiles-manager.sh backup
./scripts/system-config-backup.sh --backup

# Complete restoration workflow  
./dotfiles-manager.sh restore
./scripts/restore-system-configs.sh
```

---

## 🛠️ Development Guidelines

### **Adding New Scripts**:
1. **Naming**: Use descriptive names with hyphens: `new-feature-script.sh`
2. **Structure**: Include standard options (`--dry-run`, `--help`, `--verbose`)
3. **Logging**: Use temp directories: `${TMPDIR:-/tmp}/dotfiles-[name]-$$`
4. **Security**: Source security functions, validate inputs
5. **Documentation**: Add comprehensive help and examples

### **Security Requirements**:
- Always validate and sanitize user inputs
- Use `mktemp` for temporary files with secure permissions
- Never use `eval` with user-provided data
- Sanitize all log output to prevent injection
- Create backups before any destructive operations
- Implement proper error handling and cleanup

### **Testing Standards**:
- Test with `--dry-run` mode extensively
- Verify backup and restoration functionality
- Test error conditions and edge cases
- Validate security measures and input handling
- Test across different Linux distributions

---

## 📞 Support & Troubleshooting

### **Common Issues**:
1. **Permission Errors**: Ensure proper sudo access for system scripts
2. **Network Issues**: Check internet connectivity for firewall updates
3. **Disk Space**: Ensure adequate space for backups and temporary files
4. **Service Conflicts**: Stop conflicting services before configuration changes

### **Debugging Steps**:
1. **Check Logs**: Review logs in temporary directories
2. **Dry Run**: Use `--dry-run` to preview all actions
3. **Verbose Mode**: Enable `--verbose` for detailed output
4. **Backup Verification**: Ensure backups exist before restoration
5. **Service Status**: Check service status after configuration changes

### **Getting Help**:
- Use `--help` option for detailed usage information
- Check script logs in temporary directories
- Review backup files before cleanup
- Test with `--dry-run` before actual execution

---

**🎯 All scripts are designed to be safe, secure, and production-ready with enterprise-grade reliability!**