# 🏠 Personal Dotfiles Management System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-green.svg)](https://www.linux.org/)
[![GNOME Compatible](https://img.shields.io/badge/DE-GNOME-orange.svg)](https://www.gnome.org/)

A comprehensive, production-ready dotfiles management system for Linux environments with enterprise-grade safety features, comprehensive logging, and unified management interface.

## 📋 Table of Contents

- [🚀 Quick Start](#-quick-start)
- [📁 What's Included](#-whats-included)
- [🔧 Core Scripts Overview](#-core-scripts-overview)
- [📖 Detailed Usage Guide](#-detailed-usage-guide)
- [🛡️ Safety Features](#️-safety-features)
- [🔄 Common Workflows](#-common-workflows)
- [📂 Directory Structure](#-directory-structure)
- [🚨 Troubleshooting](#-troubleshooting)
- [🧪 Development](#-development)
- [❓ FAQ](#-faq)

## 🚀 Quick Start

### For End Users (First Time Setup)

```bash
# 1. Clone the repository
git clone https://github.com/your-username/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# 2. Preview what will be installed (recommended)
./dotfiles-manager.sh --dry-run setup

# 3. Run the installation
./dotfiles-manager.sh setup
```

### For Developers

```bash
# Test setup changes
./dotfiles-manager.sh --dry-run test    # Test all components
./dotfiles-manager.sh --force setup     # Apply changes quickly
```

## 📁 What's Included

### 🎨 **Visual Customizations**
- **Shell Configuration**: Bash and Zsh with custom prompts and aliases
- **GNOME Theme System**: Custom themes, icons, and fonts
- **Terminal Styling**: Enhanced terminal appearance and functionality
- **Application Configs**: Optimized settings for development tools

### 🔧 **Development Environment**
- **Shell Enhancements**: Productivity aliases and functions
- **Git Configuration**: Streamlined version control setup
- **Editor Settings**: Optimized configurations for popular editors
- **GNOME Extensions**: Curated productivity extensions

### 🖥️ **System-Wide Configuration Management**
- **Complete System Scanning**: Finds configurations anywhere in the system
- **Development Server Configs**: Apache, Nginx, Tomcat, Jetty, MySQL, PostgreSQL
- **Build Tool Configurations**: Maven, Gradle, NPM, Java, SBT settings
- **DevOps Tool Configs**: Docker, Terraform, Ansible, Jenkins configurations
- **Production-Ready Backup**: Comprehensive backup and restoration system

### 🛡️ **Enterprise Safety Features**
- **Automatic Backups**: Original files preserved before modification
- **Dry-run Mode**: Preview changes without applying them
- **Comprehensive Logging**: Detailed logs of all operations
- **Error Recovery**: Robust error handling and rollback capabilities
- **Multi-layer Confirmations**: Prevents accidental destructive operations
- **Security Filtering**: Automatic exclusion of sensitive data and credentials
- **Enhanced Security**: Advanced security hardening and monitoring
- **Sensitive Data Protection**: Encryption of sensitive files and secure environment variables
- **Permission Hardening**: Automatic secure permission management
- **Security Auditing**: Regular security checks and reporting

## 🔧 Core Scripts Overview

| Script | Purpose | Safety Level | When to Use |
|--------|---------|--------------|-------------|
| **dotfiles-manager.sh** | **Unified Interface** | 🛡️ **High** | Primary entry point for all operations |
| **setup-dotfiles.sh** | **Initial Setup + System Backup** | 🛡️ **High** | First installation or major updates |
| **backup-dotfiles.sh** | **Complete Backup System** | 🛡️ **Safe** | Regular maintenance and updates |
| **restore-dotfiles.sh** | **System Restore** | ⚠️ **Medium** | Restore from remote repository |
| **reset-dotfiles.sh** | **Complete Uninstall** | 🚨 **Destructive** | Permanent removal |

### 🛠️ System Configuration Scripts (in `scripts/` directory)

| Script | Purpose | Safety Level | When to Use |
|--------|---------|--------------|-------------|
| **system-config-backup.sh** | **System-Wide Config Backup** | 🛡️ **High** | Backup server/development configs |
| **restore-system-configs.sh** | **System Config Restoration** | ⚠️ **Medium** | Restore system configurations |
| **security-hardening.sh** | **Security Hardening** | 🛡️ **High** | Apply comprehensive security improvements |
| **security-monitor.sh** | **Security Monitoring** | 🛡️ **Safe** | Regular security checks and reporting |
| **secure-permissions.sh** | **Permission Hardening** | 🛡️ **High** | Fix file and directory permissions |
| **firewall.sh** | **🔥 Enterprise Firewall Manager** | 🛡️ **High** | Automated threat intelligence firewall |
| **clean-history.sh** | **History Sanitization** | 🛡️ **Safe** | Remove sensitive data from history |
| **dedupe-history.sh** | **History Deduplication** | 🛡️ **Safe** | Remove duplicate commands from history |
| **analyze-history.sh** | **History Analysis** | 🛡️ **Safe** | Analyze command patterns and security |
| **package-manager.sh** | **Package Management** | 🛡️ **High** | Cross-platform package management |
| **audit-and-automation.sh** | **System Audit & Automation** | 🛡️ **High** | Comprehensive system auditing |

## 📖 Detailed Usage Guide

### 🎯 **dotfiles-manager.sh** - Unified Management Interface

**Purpose**: Single entry point for all dotfiles operations with comprehensive safety features.

**When to use**:
- ✅ **Primary interface** for all dotfiles operations
- ✅ **Daily maintenance** and status checking
- ✅ **Safe operations** with built-in error handling
- ✅ **Testing and validation** of configurations

**Where to run**: `~/.dotfiles` directory

**Core Commands**:

```bash
# === CORE OPERATIONS ===
./dotfiles-manager.sh setup               # Set up dotfiles environment
./dotfiles-manager.sh backup              # Create comprehensive backup
./dotfiles-manager.sh restore             # Restore from backups
./dotfiles-manager.sh reset               # Reset to defaults

# === MAINTENANCE ===
./dotfiles-manager.sh test                # Run comprehensive testing
./dotfiles-manager.sh audit               # Security and quality audit
./dotfiles-manager.sh clean               # Clean up unnecessary files
./dotfiles-manager.sh status              # Show current status

# === PACKAGE MANAGEMENT ===
./dotfiles-manager.sh install-packages    # Install packages for current OS
./dotfiles-manager.sh save-packages       # Save installed packages
./dotfiles-manager.sh sync-packages       # Sync with saved packages

# === ADVANCED ===
./dotfiles-manager.sh full-automation     # Complete automated setup
./dotfiles-manager.sh emergency-restore   # Emergency restoration
./dotfiles-manager.sh validate            # Validate configurations
```

**Global Options**:
```bash
--dry-run, -n       # Preview without making changes
--verbose, -v       # Detailed output
--force, -f         # Skip confirmations
--help, -h          # Show help
```

**Example Usage**:
```bash
# Safe daily workflow
./dotfiles-manager.sh status              # Check system health
./dotfiles-manager.sh --dry-run backup    # Preview backup
./dotfiles-manager.sh backup              # Create backup

# Development workflow
./dotfiles-manager.sh --verbose test      # Test with details
./dotfiles-manager.sh --dry-run setup     # Preview setup changes
./dotfiles-manager.sh --force setup       # Apply quickly

# Emergency situations
./dotfiles-manager.sh emergency-restore --force
```

---

### 🔧 **setup-dotfiles.sh** - Initial Setup & Configuration

**Purpose**: Initializes dotfiles environment and creates comprehensive backup of your system.

**When to use**:
- ✅ **First-time installation** on a new system
- ✅ **Major updates** to dotfiles configuration
- ✅ **After pulling changes** from repository
- ✅ **System recovery** after configuration corruption

**Where to run**: `~/.dotfiles` directory

**What it does**:
1. **Re-run Protection**: Detects existing installations
2. **Git Initialization**: Sets up bare repository
3. **Security Setup**: Creates comprehensive `.gitignore`
4. **System Backup**: Backs up existing configurations
5. **Symlink Creation**: Links dotfiles to system locations
6. **GNOME Integration**: Applies desktop settings
7. **Package Tracking**: Saves installed packages
8. **History Cleaning**: Removes sensitive data from shell history

**Usage Examples**:
```bash
# Safe interactive setup
./setup-dotfiles.sh

# Preview what would be done
./setup-dotfiles.sh --dry-run

# Force re-run (bypass protection)
./setup-dotfiles.sh --force

# Get help
./setup-dotfiles.sh --help
```

**Expected Output**:
```
🔧 DOTFILES SETUP SCRIPT
========================

🔍 ANALYZING SYSTEM STATE...
  ✅ No previous installation detected
  📁 Found 5 configuration directories to process

💾 CREATING BACKUPS...
  ✅ Backed up .bashrc to .bashrc.backup_20250727_181234
  ✅ Backed up .config to .config.backup_20250727_181234

🔗 CREATING SYMLINKS...
  ✅ Linked .bashrc → ~/.dotfiles/shell/.bashrc
  ✅ Linked .config → ~/.dotfiles/.config

🎨 APPLYING GNOME SETTINGS...
  ✅ Loaded custom GNOME configuration

✅ SETUP COMPLETE! Your dotfiles are now active.
```

---

### 💾 **backup-dotfiles.sh** - Incremental Backup System

**Purpose**: Creates secure, incremental backups of your dotfiles and system configurations.

**When to use**:
- ✅ **Regular maintenance** (weekly/monthly)
- ✅ **Before making changes** to configurations
- ✅ **Before system updates** or major changes
- ✅ **Continuous integration** with your dotfiles

**Where to run**: `~/.dotfiles` directory

**What it does**:
1. **Security Filtering**: Excludes sensitive files (passwords, tokens, keys)
2. **Incremental Backup**: Only backs up changed files
3. **GNOME Settings**: Backs up desktop environment settings
4. **Shell History**: Cleans and deduplicates command history
5. **Package Lists**: Updates installed package inventories
6. **Git Integration**: Commits changes automatically

**Security Features**:
- 🔒 **159 security patterns** exclude sensitive data
- 🔒 **History cleaning** removes passwords and secrets
- 🔒 **Browser data exclusion** protects login information
- 🔒 **Certificate filtering** excludes private keys

**Usage Examples**:
```bash
# Standard backup
./backup-dotfiles.sh

# Preview what would be backed up
./backup-dotfiles.sh --dry-run

# Get help and see features
./backup-dotfiles.sh --help
```

**What gets backed up**:

#### 🏠 **User-Level Configurations**:
- ✅ Shell configurations (`.bashrc`, `.zshrc`, histories)
- ✅ Application settings (`.config` directory)
- ✅ GNOME desktop settings (dconf export)
- ✅ Themes, icons, and fonts
- ✅ GNOME extensions

#### 🛠️ **Development Tool Configurations**:
- ✅ **Maven** (`.m2/` - settings, wrapper, excludes repository cache)
- ✅ **Java** (`.java/` - user preferences, fonts)
- ✅ **NPM** (`.npm/` - configuration, excludes cache)
- ✅ **Git** (`.gitconfig` - global configuration)
- ✅ **Database tools** (`shell/.mysql_history`, `.pgpass`, `.mongorc.js`)
- ✅ **Build tools** (`.gradle/gradle.properties`, `.sbt/`, `.ivy2/ivysettings.xml`)
- ✅ **DevOps tools** (`.dockerconfig`, `.terraformrc`, `.ansible.cfg`)
- ✅ **Editors** (`.vimrc`, `.tmux.conf`, `.screenrc`)

#### 🚀 **Development Server Configurations**:
- ✅ **Apache Tomcat** - Configuration directories (`conf/`)
- ✅ **Jetty** - Auto-detects installations and configs
- ✅ **Nginx** - Custom user configurations
- ✅ **Eclipse** - Workspace settings

#### 🖥️ **System-Wide Configurations**:
- ✅ **Apache HTTP Server** - `/etc/httpd/` configurations
- ✅ **MySQL/MariaDB** - `/etc/my.cnf.d/` database configs
- ✅ **Development tools** - System-installed server configurations
- ✅ **Custom services** - User-installed server configurations

#### ❌ **Smart Exclusions (Security & Performance)**:
- ❌ **Sensitive data**: SSH keys, passwords, tokens, browser data
- ❌ **Large caches**: Maven repository, Gradle caches, NPM cache, node_modules
- ❌ **IDE conflicts**: VSCode, JetBrains (have built-in sync)
- ❌ **System noise**: Flatpak, snap, locale files, documentation

---

### 🔄 **restore-dotfiles.sh** - System Restoration

**Purpose**: Restores dotfiles from a remote Git repository (typically for new system setup).

**When to use**:
- ✅ **New system setup** from existing dotfiles
- ✅ **Disaster recovery** from remote backup
- ✅ **Multiple system synchronization**
- ✅ **Clean installation** on fresh OS

**Where to run**: Any directory (will create `~/.dotfiles`)

**What it does**:
1. **Repository Cloning**: Downloads dotfiles from Git remote
2. **OS Detection**: Automatically detects Linux distribution
3. **Configuration Restoration**: Restores all backed-up settings
4. **Package Installation**: Installs saved packages for your OS
5. **GNOME Settings**: Applies desktop environment settings
6. **Symlink Creation**: Links configurations to system locations

**Interactive Process**:
```bash
./restore-dotfiles.sh

# You'll be prompted to select your OS:
# 1) Fedora (RPM)
# 2) Ubuntu/Debian (APT)  
# 3) Arch Linux (Pacman)
```

**What gets restored**:
- ✅ All configuration files
- ✅ GNOME desktop settings
- ✅ Shell configurations
- ✅ Application settings
- ✅ Installed packages (OS-specific)
- ✅ Themes and extensions

**Post-restoration**:
- 🔄 **Log out and back in** to apply GNOME settings
- 🔄 **Restart terminal** for shell changes
- 🔄 **Verify symlinks** with `ls -la ~`

---

### 🗑️ **reset-dotfiles.sh** - Complete Uninstaller

**Purpose**: Completely removes dotfiles installation and restores original system state.

**When to use**:
- ⚠️ **Permanent uninstallation** of dotfiles system
- ⚠️ **Switching to different** dotfiles solution
- ⚠️ **System cleanup** before major changes
- ⚠️ **Troubleshooting** by complete removal

**Where to run**: `~/.dotfiles` directory

**🚨 WARNING**: This is a **PERMANENT** operation that:
- 🗑️ Removes all dotfiles symlinks
- ♻️ Restores original configuration files
- 🎨 Resets GNOME settings to original state
- 💾 Optionally removes backup files

**Safety Features**:
- 🛡️ **Comprehensive analysis** before uninstall
- 🛡️ **Safety backups** created before restoration
- 🛡️ **Detailed logging** of all operations
- 🛡️ **Confirmation required** for permanent operations

**Usage Examples**:
```bash
# Safe interactive uninstall
./reset-dotfiles.sh

# Preview what would be uninstalled (HIGHLY RECOMMENDED)
./reset-dotfiles.sh --dry-run

# Quick uninstall without confirmations
./reset-dotfiles.sh --force

# Uninstall but keep backup files
./reset-dotfiles.sh --keep-backups
```

**Uninstall Process**:
1. **Analysis Phase**: Identifies all dotfiles components
2. **Impact Assessment**: Shows what will be removed
3. **Confirmation**: Requires typing "UNINSTALL" to proceed
4. **GNOME Restoration**: Restores original desktop settings
5. **Symlink Removal**: Removes all dotfiles symlinks
6. **File Restoration**: Restores original configurations
7. **Cleanup**: Optionally removes backup files

**Expected Output**:
```
🗑️  DOTFILES COMPLETE UNINSTALLER
==================================

📊 UNINSTALL IMPACT ANALYSIS:
=============================
  • Directory symlink: .config
  • File symlink: .bashrc
  • GNOME settings backup available

⚠️  PERMANENT UNINSTALL CONFIRMATION
====================================
Type 'UNINSTALL' to confirm permanent removal: UNINSTALL

🔄 PROCEEDING WITH DOTFILES UNINSTALL...
✅ GNOME settings restored from backup
✅ Restored original directory: .config
✅ Restored original file: .bashrc

✅ UNINSTALL COMPLETED SUCCESSFULLY!
```

---

## 🖥️ System-Wide Configuration Management

### **Complete System Scanning & Backup**

The dotfiles system now includes **comprehensive system-wide configuration management** that scans your entire system for development, server, and production configurations.

### 🔍 **What Gets Discovered & Backed Up**

#### **📂 System Locations Scanned**:
- `/etc` - System configuration files
- `/opt` - Optional software installations
- `/usr/local/etc` - Local system configurations
- `/var/lib` - Service data and configurations
- `/srv` - Service-specific data

#### **🛠️ Software Patterns Detected**:
- **Web Servers**: Apache, Nginx, Lighttpd
- **Application Servers**: Tomcat, Jetty, WildFly, JBoss, GlassFish
- **Databases**: MySQL, MariaDB, PostgreSQL, Redis, MongoDB
- **Development Tools**: Maven, Gradle, Ant, SBT, Node.js, NPM
- **DevOps Tools**: Docker, Kubernetes, Jenkins, GitLab, Nexus, Artifactory
- **Monitoring**: Prometheus, Grafana, Elasticsearch, Logstash, Kibana
- **Message Queues**: RabbitMQ, Kafka, ActiveMQ, Artemis
- **Caching**: Memcached, Hazelcast, EhCache
- **Security**: Keycloak, Vault, Consul

### 🚀 **System Configuration Scripts**

#### **`scripts/system-config-backup.sh`** - System-Wide Backup

**Purpose**: Scans entire system for development and server configurations

**Usage Examples**:
```bash
# Preview what would be backed up
./scripts/system-config-backup.sh --backup --dry-run

# Backup all system configurations
./scripts/system-config-backup.sh --backup

# Get help
./scripts/system-config-backup.sh --help
```

**What it finds on your system**:
- ✅ **Apache HTTP Server** (`/etc/httpd/`) - All configuration files
- ✅ **MySQL/MariaDB** (`/etc/my.cnf.d/`) - Database configurations
- ✅ **Development tools** - System-installed server configurations
- ✅ **Custom services** - User-installed server configurations

**Smart Filtering**:
- ✅ **Includes**: Configuration files (`.conf`, `.xml`, `.yml`, `.properties`)
- ❌ **Excludes**: Cache files, documentation, locale files, build artifacts

#### **`scripts/restore-system-configs.sh`** - System Configuration Restoration

**Purpose**: Restores system-wide configurations with proper permissions

**Usage Examples**:
```bash
# Preview what would be restored
./scripts/restore-system-configs.sh --dry-run

# Restore all system configurations (requires sudo)
./scripts/restore-system-configs.sh

# Get help
./scripts/restore-system-configs.sh --help
```

**Safety Features**:
- 🛡️ **Backup before restore**: Existing configs backed up before replacement
- 🛡️ **Sudo handling**: Automatic privilege escalation when needed
- 🛡️ **Service restart guidance**: Instructions for restarting affected services
- 🛡️ **Dry-run mode**: Preview all operations before execution

### 📁 **Backup Structure**

Your complete backup structure:
```
~/.dotfiles/
├── .config/                    # User application configs
├── .m2/                        # Maven configuration (no repository)
├── .java/                      # Java user preferences
├── .npm/                       # NPM configuration (no cache)
├── servers/                    # Development servers
│   ├── apache-tomcat-11.0.6/   # Tomcat configuration
│   ├── jetty-*/                # Jetty configurations
│   └── nginx/                  # Nginx configurations
├── eclipse/                    # Eclipse workspace settings
├── system-configs/             # System-wide configurations
│   ├── etc/httpd/              # Apache HTTP server
│   ├── etc/my.cnf.d/           # MySQL configuration
│   └── opt/*/                  # Optional software configs
└── scripts/                    # Utility and system scripts
```

### 🔄 **Complete Restoration Workflow**

#### **For Fresh System Setup**:
```bash
# 1. Clone dotfiles repository
git clone https://your-repo.git ~/.dotfiles
cd ~/.dotfiles

# 2. Restore user configurations
./setup-dotfiles.sh

# 3. Restore system configurations (requires sudo)
./scripts/restore-system-configs.sh --dry-run  # Preview first
./scripts/restore-system-configs.sh            # Actually restore

# 4. Restart services
sudo systemctl restart httpd nginx mysql postgresql redis

# 5. Verify configurations
sudo httpd -t                    # Test Apache config
sudo nginx -t                   # Test Nginx config
sudo systemctl status httpd     # Check service status
```

### 🎯 **Production-Ready Features**

#### ✅ **Complete Coverage**:
- **User configurations**: Personal settings and preferences
- **Development environment**: All dev tools and their configurations
- **Server configurations**: Production and development servers
- **System services**: System-wide service configurations

#### ✅ **Security & Safety**:
- **Sensitive data exclusion**: Automatic filtering of credentials
- **Backup before restore**: Existing configs backed up before replacement
- **Dry-run mode**: Preview all operations before execution
- **Sudo handling**: Automatic privilege escalation when needed

#### ✅ **Cross-System Compatibility**:
- **Fresh system setup**: Complete environment recreation
- **Selective restoration**: Choose what to restore
- **Service management**: Automatic service restart recommendations
- **Error handling**: Graceful failure handling and reporting

---

### 🔥 **firewall.sh** - Enterprise Firewall Manager

**Purpose**: Automated threat intelligence firewall management with enterprise-grade security features.

**When to use**:
- ✅ **Daily/Weekly security updates** with latest threat intelligence
- ✅ **Enterprise environments** requiring comprehensive threat blocking
- ✅ **Home users** wanting advanced protection against malware and attacks
- ✅ **Automated security** with cron job integration

**Where to run**: `~/.dotfiles/scripts/` directory

**What it does**:
1. **Threat Intelligence**: Downloads from 45+ premium threat intelligence sources
2. **Malware Protection**: Blocks C&C servers, botnets, and ransomware infrastructure
3. **Attack Prevention**: Stops brute force, web attacks, and suspicious activity
4. **Advanced Threats**: Protects against APTs, cryptojacking, and zero-day infrastructure
5. **Multi-OS Support**: Works with firewalld, ufw, iptables, and pfctl
6. **Performance Optimized**: Parallel downloads, caching, and incremental updates

**Core Features**:

#### 🎯 **Threat Intelligence Sources (45+ total)**:

**Malware & C&C Sources (14 sources)**:
- **IPsum** - Daily updated malicious IPs with confidence scoring
- **Spamhaus DROP/EDROP** - Known bad networks and extended lists
- **Emerging Threats** - Compromised IPs from ET intelligence
- **FireHOL Cybercrime** - Comprehensive cybercrime IP tracker
- **Zeus, Ransomware, C&C Trackers** - Botnet and malware infrastructure
- **Bambenek C&C & DGA Feeds** - Command & control and domain generation algorithms
- **Feodo & Palevo Trackers** - Banking trojans and worm infrastructure

**Suspicious Activity Sources (18 sources)**:
- **FireHOL Level 1 & 2** - High and medium confidence threats
- **DShield** - Top attackers from SANS Internet Storm Center
- **Cisco Talos** - Enterprise-grade threat intelligence
- **BruteForce & Web Attack Sources** - Attack-specific blocking
- **SSL Blacklist & Malicious URLs** - Certificate and URL-based threats
- **PHP Harvesters & Spammers** - Web application attack sources

**Specialized Sources (13 sources)**:
- **Cryptocurrency Mining IPs** - Cryptojacking prevention
- **Proxy & Anonymization Services** - Corporate environment protection
- **IBM X-Force & NormShield** - Enterprise threat intelligence feeds

#### ⚡ **Performance Optimizations**:
- **Parallel Downloads**: 5 concurrent downloads reduce time from ~60s to ~15s
- **Intelligent Caching**: 6-hour cache with hash-based change detection
- **Incremental Updates**: Only process changed IPs (seconds vs minutes)
- **Native ipset Integration**: 10x faster bulk operations

#### 🎛️ **Configuration Options**:

**Command Line Usage**:
```bash
# Standard protection (18 sources)
./firewall.sh --verbose

# Enhanced protection (31 sources)
./firewall.sh --enable-specialized --enable-crypto-blocking

# Maximum protection (45+ sources)
./firewall.sh --enable-all-sources --verbose

# Corporate environments
./firewall.sh --enable-all-sources --enable-proxy-blocking

# Preview changes
./firewall.sh --dry-run --verbose --enable-all-sources

# Automated updates
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

#### 📊 **Protection Levels**:

| Level | Sources | Use Case | Coverage | False Positives |
|-------|---------|----------|----------|-----------------|
| **Conservative** | 18 | Home users | High-confidence threats | Low |
| **Balanced** | 31 | Small business | Comprehensive coverage | Minimal |
| **Aggressive** | 35 | Corporate | Maximum protection | Potential proxy blocking |
| **Enterprise** | 45+ | High-security | Complete threat landscape | Highest |

#### 🔄 **Automation & Monitoring**:

**Cron Job Setup**:
```bash
# Daily updates at 2 AM
0 2 * * * /home/ajay/.dotfiles/scripts/firewall.sh --auto-update --verbose >> /var/log/firewall-update.log 2>&1

# Weekly full update with all sources
0 3 * * 0 /home/ajay/.dotfiles/scripts/firewall.sh --enable-all-sources --force --auto-update
```

**Performance Metrics**:
- **Download Time**: 15-45 seconds (depending on sources enabled)
- **Processing Time**: 5-15 seconds with optimizations
- **Cache Hit Performance**: 10-15 seconds for subsequent runs
- **Total Coverage**: 350,000-800,000 unique threat indicators

#### 🛡️ **Security Benefits**:
- **Malware Protection**: Blocks C&C communication and botnet infrastructure
- **Attack Prevention**: Stops brute force, web attacks, and spam sources
- **Advanced Threats**: Protects against APTs and zero-day infrastructure
- **Cryptojacking Prevention**: Blocks unauthorized cryptocurrency mining
- **Real-time Updates**: Multiple daily updates from premium sources

**Example Output**:
```
🛡️ AUTOMATED FIREWALL RULES UPDATE SCRIPT
===========================================
✅ Including specialized threat intelligence sources
✅ Including cryptocurrency mining blocking sources
✅ Downloading from 45 threat intelligence sources...
✅ Processed 127,543 malware IPs and 284,921 suspicious IPs
✅ Applied 412,464 blocking rules to firewall
⏱️ Total execution time: 32 seconds
```

---

## 🛡️ Safety Features

### 🔒 **Multi-Layer Protection System**

#### **1. Re-run Protection**
- **Setup Marker Detection**: Prevents accidental re-installation
- **Symlink Analysis**: Detects existing dotfiles installation
- **Backup Verification**: Ensures backups exist before proceeding
- **Interactive Confirmation**: Requires explicit user confirmation

#### **2. Comprehensive Backup System**
- **Pre-Installation Backups**: Automatic backup of existing files
- **Timestamped Backups**: Unique timestamps prevent conflicts
- **Safety Backups**: Additional backups before destructive operations
- **Backup Verification**: Confirms backup integrity before proceeding

#### **3. Security Filtering**
- **159 Security Patterns**: Comprehensive exclusion of sensitive files
- **History Cleaning**: Removes passwords, tokens, and secrets from shell history
- **Browser Data Protection**: Excludes login data, cookies, and session information
- **Certificate Filtering**: Protects private keys and authentication files

#### **4. Error Recovery System**
- **Comprehensive Logging**: Every operation logged with details
- **Error Detection**: Robust error handling for all operations
- **Graceful Rollback**: Automatic rollback on critical failures
- **Recovery Instructions**: Clear guidance for manual recovery

#### **5. Dry-Run System**
- **Complete Preview**: Shows exactly what would be changed
- **Risk Assessment**: Identifies potential conflicts before applying
- **Impact Analysis**: Detailed breakdown of system changes
- **Safe Testing**: Test configurations without system changes

## 🔄 Common Workflows

### 📋 **First-Time Setup Workflow**
```bash
# 1. Clone repository
git clone <repo-url> ~/.dotfiles && cd ~/.dotfiles

# 2. Review what will be installed
./dotfiles-manager.sh --dry-run setup

# 3. Install dotfiles
./dotfiles-manager.sh setup

# 4. Verify installation
./dotfiles-manager.sh status
```

### 📋 **Daily Maintenance Workflow**
```bash
# 1. Check system health
./dotfiles-manager.sh status

# 2. Create backup if needed
./dotfiles-manager.sh --dry-run backup
./dotfiles-manager.sh backup

# 3. Run tests periodically
./dotfiles-manager.sh test
```

### 📋 **Update Workflow**
```bash
# 1. Create backup before updating
./dotfiles-manager.sh backup

# 2. Pull latest changes
git pull origin main

# 3. Preview updates
./dotfiles-manager.sh --dry-run setup

# 4. Apply updates
./dotfiles-manager.sh setup
```

### 📋 **Development Workflow**
```bash
# 1. Test changes safely
./dotfiles-manager.sh --dry-run test

# 2. Preview setup changes
./dotfiles-manager.sh --dry-run setup

# 3. Apply and verify
./dotfiles-manager.sh --force setup
./dotfiles-manager.sh status

# 4. Run comprehensive tests
./dotfiles-manager.sh test
```

### 📋 **New System Setup Workflow**
```bash
# 1. Clone or restore from remote
./restore-dotfiles.sh

# 2. Verify restoration
./dotfiles-manager.sh status

# 3. Update if needed
./dotfiles-manager.sh backup
```

### 📋 **Emergency Recovery Workflow**
```bash
# 1. Assess damage
./dotfiles-manager.sh status

# 2. Try emergency restore
./dotfiles-manager.sh emergency-restore

# 3. If that fails, complete reset and restore
./reset-dotfiles.sh --dry-run
./reset-dotfiles.sh
./restore-dotfiles.sh
```

### 📋 **Uninstall Workflow**
```bash
# 1. Preview uninstall impact
./reset-dotfiles.sh --dry-run

# 2. Create final backup (optional)
./dotfiles-manager.sh backup

# 3. Perform uninstall
./reset-dotfiles.sh

# 4. Remove dotfiles directory (optional)
cd ~ && rm -rf ~/.dotfiles
```

## 📚 Comprehensive Documentation

### 📖 **Available Documentation**

| Document | Purpose | Location |
|----------|---------|----------|
| **README.md** | Main documentation and usage guide | `/README.md` |
| **scripts/README.md** | Comprehensive scripts documentation | `/scripts/README.md` |
| **THREAT_SOURCES_UPDATE.md** | Firewall threat intelligence sources | `/THREAT_SOURCES_UPDATE.md` |
| **scripts/SECURITY.md** | Security guidelines and best practices | `/scripts/SECURITY.md` |
| **firewall-update.conf.example** | Firewall configuration template | `/scripts/firewall-update.conf.example` |

### 🔥 **Latest Updates**

#### **Enterprise Firewall Manager (firewall.sh)**
- **45+ Threat Intelligence Sources**: Expanded from 10 to 45+ premium sources
- **Performance Optimized**: 4-5x faster with parallel downloads and caching
- **Enterprise Ready**: Automated updates, comprehensive logging, multiple protection levels
- **Multi-OS Support**: Works with firewalld, ufw, iptables, and pfctl
- **Threat Coverage**: 350,000-800,000 unique threat indicators

**Quick Start**:
```bash
# Standard protection for home users
./scripts/firewall.sh --verbose

# Maximum protection for enterprises  
./scripts/firewall.sh --enable-all-sources --auto-update

# Preview all changes first
./scripts/firewall.sh --dry-run --verbose --enable-all-sources
```

#### **Enhanced Security Scripts**
- **security-hardening.sh**: Multi-profile system hardening (Basic → Enterprise)
- **security-monitor.sh**: Real-time security monitoring and alerting
- **secure-permissions.sh**: Comprehensive permission hardening
- **analyze-history.sh**: Advanced shell history analysis with security focus

#### **System Configuration Management**
- **system-config-backup.sh**: Discovers and backs up system-wide configurations
- **restore-system-configs.sh**: Safely restores system configurations
- **package-manager.sh**: Cross-platform package management
- **audit-and-automation.sh**: System auditing and automation setup

---

## 📂 Directory Structure

```
~/.dotfiles/
├── README.md                    # This comprehensive guide
├── dotfiles-manager.sh          # 🎯 UNIFIED MANAGER (START HERE)
├── setup-dotfiles.sh            # Initial setup and configuration
├── backup-dotfiles.sh           # Incremental backup system
├── restore-dotfiles.sh          # System restoration from remote
├── reset-dotfiles.sh            # Complete uninstaller
├── .setup_completed             # Setup completion marker
├── .gitignore                   # Comprehensive security patterns
├── shell/                       # Shell configuration files
│   ├── .bashrc                 # Bash configuration
│   ├── .zshrc                  # Zsh configuration
│   ├── .bash_profile           # Bash profile
│   └── aliases.sh              # Common aliases
├── .config/                     # Application configurations
│   ├── git/                    # Git configuration
│   ├── terminal/               # Terminal settings
│   └── [other-apps]/           # Other application configs
├── .themes/                     # Custom themes
├── .icons/                      # Custom icon sets
├── .fonts/                      # Custom fonts
├── .local/share/gnome-shell/    # GNOME extensions
│   └── extensions/             # Custom extensions
├── gnome-settings.dconf         # GNOME settings backup
├── dnf-packages.txt             # Fedora package list
├── apt-packages.txt             # Debian/Ubuntu package list
├── pacman-packages.txt          # Arch package list
├── scripts/                     # Supporting automation scripts
│   ├── package-manager.sh      # Multi-OS package management
│   ├── audit-and-automation.sh # Security auditing
│   ├── cleanup-and-secure.sh   # System cleanup
│   ├── clean-history.sh        # History cleaning
│   ├── dedupe-history.sh       # History deduplication
│   └── analyze-history.sh      # History analysis
└── logs/                        # Operation logs (auto-created)
    ├── setup_*.log             # Setup operation logs
    ├── backup_*.log            # Backup operation logs
    └── uninstall_*.log         # Uninstall operation logs
```

## 🚨 Troubleshooting

### **Common Issues and Solutions**

#### **Issue: "Setup already completed" message**
```bash
# Problem: Script detects previous installation
# Solution: Use force flag or backup script instead
./dotfiles-manager.sh --force setup    # Force re-run
# OR
./dotfiles-manager.sh backup           # Use backup instead
```

#### **Issue: Broken symlinks after update**
```bash
# Problem: Symlinks pointing to wrong locations
# Solution: Reset and re-setup
./reset-dotfiles.sh --dry-run          # Preview reset
./reset-dotfiles.sh                    # Reset system
./dotfiles-manager.sh setup            # Re-setup
```

#### **Issue: GNOME settings not applying**
```bash
# Problem: Desktop settings not taking effect
# Solution: Manual GNOME settings reload
dconf load / < ~/.dotfiles/gnome-settings.dconf
# Then log out and back in
```

#### **Issue: Package installation fails**
```bash
# Problem: Package manager errors
# Solution: Update package lists and retry
./dotfiles-manager.sh sync-packages    # Check package status
sudo dnf update                         # Update system (Fedora)
sudo apt update && sudo apt upgrade    # Update system (Ubuntu)
```

#### **Issue: Permission denied errors**
```bash
# Problem: Scripts not executable
# Solution: Fix permissions
chmod +x ~/.dotfiles/*.sh
chmod +x ~/.dotfiles/scripts/*.sh
```

#### **Issue: Git repository issues**
```bash
# Problem: Git operations failing
# Solution: Reinitialize repository
cd ~/.dotfiles
rm -rf .git
git init
git remote add origin <your-repo-url>
```

### **Emergency Recovery**

If your system becomes unusable:

1. **Emergency Restore**:
   ```bash
   ./dotfiles-manager.sh emergency-restore --force
   ```

2. **Complete Reset**:
   ```bash
   ./reset-dotfiles.sh --force
   ```

3. **Fresh Start**:
   ```bash
   cd ~
   rm -rf ~/.dotfiles
   git clone <your-repo> ~/.dotfiles
   cd ~/.dotfiles
   ./dotfiles-manager.sh setup
   ```

### **Getting Help**

```bash
# Get help for any script
./dotfiles-manager.sh --help
./setup-dotfiles.sh --help
./backup-dotfiles.sh --help
./restore-dotfiles.sh --help
./reset-dotfiles.sh --help

# Check system status
./dotfiles-manager.sh status

# Run comprehensive tests
./dotfiles-manager.sh test

# Run security audit
./dotfiles-manager.sh audit
```

## 🧪 Development

### **Testing Changes**

```bash
# Test all components
./dotfiles-manager.sh --dry-run test

# Test specific operations
./dotfiles-manager.sh --dry-run setup
./dotfiles-manager.sh --dry-run backup

# Validate configurations
./dotfiles-manager.sh validate
```

### **Development Workflow**

```bash
# 1. Make changes to dotfiles
# 2. Test changes safely
./dotfiles-manager.sh --dry-run setup

# 3. Apply changes
./dotfiles-manager.sh --force setup

# 4. Verify everything works
./dotfiles-manager.sh test
./dotfiles-manager.sh status

# 5. Create backup of working state
./dotfiles-manager.sh backup
```

### **Contributing**

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## ❓ FAQ

### **Q: Which script should I use for daily maintenance?**
**A:** Use `./dotfiles-manager.sh backup` for regular updates and `./dotfiles-manager.sh status` to check system health.

### **Q: How do I set up dotfiles on a new computer?**
**A:** Use `./restore-dotfiles.sh` to clone and restore from your remote repository, or `./dotfiles-manager.sh setup` if you already have the files locally.

### **Q: What's the difference between setup and backup scripts?**
**A:** `setup-dotfiles.sh` is for initial installation and major changes. `backup-dotfiles.sh` is for regular maintenance and incremental updates.

### **Q: Is it safe to run these scripts multiple times?**
**A:** Yes! All scripts have built-in protection against re-runs and will warn you before making changes. Use `--dry-run` to preview first.

### **Q: What happens to my original configuration files?**
**A:** They're automatically backed up with timestamps (e.g., `.bashrc.backup_1234567890`) before any changes are made.

### **Q: How do I completely remove the dotfiles system?**
**A:** Use `./reset-dotfiles.sh` to completely uninstall and restore your original configurations.

### **Q: Can I use this on different Linux distributions?**
**A:** Yes! The system auto-detects your OS and supports Fedora/RHEL, Ubuntu/Debian, and Arch Linux.

### **Q: What sensitive files are excluded from backups?**
**A:** 159 security patterns exclude passwords, tokens, keys, browser data, SSH keys, and other sensitive information.

### **Q: How do I update my dotfiles from a remote repository?**
**A:** Run `git pull` in `~/.dotfiles`, then `./dotfiles-manager.sh setup` to apply updates.

### **Q: What if something goes wrong during setup?**
**A:** All operations are logged, and you can use `./dotfiles-manager.sh emergency-restore` or `./reset-dotfiles.sh` to recover.

---

## 🎯 **Quick Reference Card**

| Task | Command | Safety |
|------|---------|--------|
| **First Setup** | `./dotfiles-manager.sh setup` | 🛡️ Safe |
| **Daily Backup** | `./dotfiles-manager.sh backup` | 🛡️ Safe |
| **Check Status** | `./dotfiles-manager.sh status` | 🛡️ Safe |
| **New System** | `./restore-dotfiles.sh` | ⚠️ Medium |
| **Test Changes** | `./dotfiles-manager.sh --dry-run test` | 🛡️ Safe |
| **Emergency** | `./dotfiles-manager.sh emergency-restore` | ⚠️ Medium |
| **Uninstall** | `./reset-dotfiles.sh` | 🚨 Destructive |

**Remember**: Always use `--dry-run` first to preview changes!

---

*This dotfiles system is designed for safety, security, and ease of use. When in doubt, use the unified manager (`dotfiles-manager.sh`) as your primary interface.*