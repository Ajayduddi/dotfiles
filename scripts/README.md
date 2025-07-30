# 🛠️ Dotfiles Utility Scripts

This directory contains utility and security scripts for managing your dotfiles repository. All scripts generate logs and reports in temporary directories for easy cleanup.

## 📁 Scripts Overview

### 🛡️ Security Scripts

#### `security-functions.sh`
**Purpose**: Shared security utilities for dotfiles scripts  
**Usage**: `source scripts/security-functions.sh`  
**Features**:
- Input validation and sanitization
- Secure temporary file creation
- Path traversal protection
- Command injection prevention
- File permission checking

#### `run-security-audit.sh`
**Purpose**: Comprehensive security audit of dotfiles repository  
**Usage**: `./scripts/run-security-audit.sh [--dry-run] [--fix]`  
**Features**:
- Automated vulnerability scanning
- Security scoring system
- Detailed audit logging
- Automatic issue detection
- Fix recommendations

**Example**:
```bash
# Run security audit
./scripts/run-security-audit.sh

# Preview what would be audited
./scripts/run-security-audit.sh --dry-run
```

---

### 📊 History Management Scripts

#### `analyze-history.sh`
**Purpose**: Comprehensive shell history analysis tool  
**Usage**: `./scripts/analyze-history.sh`  
**Features**:
- Command usage statistics
- Security analysis
- Duplication detection
- Category breakdown
- Performance insights

**Example Output**:
```
📈 TOP COMMANDS:
================
  45: git
  32: ls
  28: cd
  19: vim

🔒 SECURITY ANALYSIS:
====================
✅ No obvious sensitive commands found
```

#### `clean-history.sh`
**Purpose**: Remove sensitive information from shell history  
**Usage**: `./scripts/clean-history.sh [--dry-run] [--no-backup]`  
**Features**:
- Removes passwords, tokens, API keys
- Pattern-based sensitive content detection
- Automatic backup creation
- Comprehensive cleaning patterns
- Security-focused sanitization

**Example**:
```bash
# Clean history with backup
./scripts/clean-history.sh

# Preview what would be cleaned
./scripts/clean-history.sh --dry-run

# Clean without backup
./scripts/clean-history.sh --no-backup
```

#### `dedupe-history.sh`
**Purpose**: Remove duplicate entries from shell history  
**Usage**: `./scripts/dedupe-history.sh [--dry-run] [--no-backup]`  
**Features**:
- Preserves chronological order
- Handles both bash and zsh formats
- Shows reduction statistics
- Automatic backup creation
- Efficient deduplication algorithm

**Example**:
```bash
# Deduplicate history with backup
./scripts/dedupe-history.sh

# Preview duplicates to be removed
./scripts/dedupe-history.sh --dry-run
```

---

## 🗂️ Temporary File Management

All scripts use temporary directories for logs and reports:

- **Location**: `${TMPDIR:-/tmp}/dotfiles-[script-name]-$$`
- **Structure**: Each script creates its own temp directory
- **Cleanup**: Temporary files are preserved for review
- **Contents**: Logs, analysis reports, backup files

### Example Temp Directory Structure:
```
/tmp/dotfiles-audit-12345/
├── security_audit_20250726_120000.log
├── vulnerability_report.txt
└── recommendations.md

/tmp/dotfiles-clean-98765/
├── bash_history.cleaned
├── zsh_history.cleaned
└── sensitive_patterns.log
```

---

## 📋 Common Options

All scripts support these common options:

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be done without making changes |
| `--help` | `-h` | Show detailed help message |
| `--no-backup` | | Skip creating backup files (where applicable) |

---

## 🚀 Quick Start Guide

### 1. Run Security Audit
```bash
# Check repository security
./scripts/run-security-audit.sh
```

### 2. Analyze Shell History
```bash
# Get usage statistics
./scripts/analyze-history.sh
```

### 3. Clean Sensitive Data
```bash
# Remove passwords and tokens
./scripts/clean-history.sh --dry-run  # Preview first
./scripts/clean-history.sh            # Actually clean
```

### 4. Remove Duplicates
```bash
# Remove duplicate commands
./scripts/dedupe-history.sh --dry-run  # Preview first
./scripts/dedupe-history.sh            # Actually deduplicate
```

---

## 🔒 Security Features

### Built-in Security Measures:
- ✅ **Input Validation** - All user inputs are validated
- ✅ **Path Sanitization** - Prevents directory traversal attacks
- ✅ **Secure Temp Files** - Uses `mktemp` with proper permissions
- ✅ **Command Injection Prevention** - No `eval` usage
- ✅ **Log Sanitization** - Prevents log injection attacks
- ✅ **Backup Protection** - Always creates backups before modifications

### Security Patterns Detected:
- Passwords in command history
- API keys and tokens
- SSH keys and certificates
- Database connection strings
- Authentication commands
- Cloud service credentials

---

## 📊 Integration with Main Scripts

These utility scripts integrate with the main dotfiles scripts:

- **`backup-dotfiles.sh`** → Uses `clean-history.sh` patterns
- **`setup-dotfiles.sh`** → Can call `run-security-audit.sh`
- **`reset-dotfiles.sh`** → Uses security functions
- **`reset-setup.sh`** → Uses security functions

---

## 🛠️ Development

### Adding New Scripts:
1. Create script in `scripts/` directory
2. Use temp directories for logs: `${TMPDIR:-/tmp}/dotfiles-[name]-$$`
3. Include `--dry-run` and `--help` options
4. Source `security-functions.sh` if needed
5. Make executable: `chmod +x scripts/new-script.sh`

### Security Guidelines:
- Always validate user inputs
- Use `create_secure_temp()` for temporary files
- Never use `eval` with user data
- Sanitize all log output
- Create backups before modifications

---

## 📞 Support

For issues with utility scripts:
1. Check script logs in temp directories
2. Run with `--dry-run` to preview actions
3. Use `--help` for detailed usage information
4. Review temporary files before cleanup

---

**🎯 All scripts are designed to be safe, secure, and reversible!**