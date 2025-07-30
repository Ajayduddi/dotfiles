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

### 🛡️ **Enterprise Safety Features**
- **Automatic Backups**: Original files preserved before modification
- **Dry-run Mode**: Preview changes without applying them
- **Comprehensive Logging**: Detailed logs of all operations
- **Error Recovery**: Robust error handling and rollback capabilities
- **Multi-layer Confirmations**: Prevents accidental destructive operations

## 🔧 Core Scripts Overview

| Script | Purpose | Safety Level | When to Use |
|--------|---------|--------------|-------------|
| **dotfiles-manager.sh** | **Unified Interface** | 🛡️ **High** | Primary entry point for all operations |
| **setup-dotfiles.sh** | **Initial Setup** | 🛡️ **High** | First installation or major updates |
| **backup-dotfiles.sh** | **Create Backups** | 🛡️ **Safe** | Regular maintenance and updates |
| **restore-dotfiles.sh** | **System Restore** | ⚠️ **Medium** | Restore from remote repository |
| **reset-dotfiles.sh** | **Complete Uninstall** | 🚨 **Destructive** | Permanent removal |

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
- ✅ Shell configurations (`.bashrc`, `.zshrc`, etc.)
- ✅ Application settings (`.config` directory)
- ✅ GNOME desktop settings
- ✅ Themes, icons, and fonts
- ✅ GNOME extensions
- ✅ Package lists (DNF/APT/Pacman)
- ❌ Sensitive files (automatically excluded)

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