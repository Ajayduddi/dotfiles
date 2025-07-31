# Dotfiles Security Guide

This document provides an overview of the security features and best practices implemented in this dotfiles repository.

## Security Features

### 1. Shell History Security

The shell history security system prevents sensitive information from being logged in your shell history:

- **Enhanced History Filtering**: Prevents commands containing passwords, tokens, keys, and other sensitive data from being saved in history
- **Secure Command Execution**: The `secure_cmd` function allows running commands without logging them to history
- **Secure Environment Variables**: The `secure_env` function securely sets environment variables without exposing them in history

Usage:
```bash
# Prefix sensitive commands with a space to avoid logging
 mysql -u root -p

# Use secure command function
secure_cmd aws configure

# Set sensitive environment variables securely
secure_env API_KEY
```

### 2. Secure Environment Variables Management

The secure environment variables system provides tools for safely managing sensitive environment variables:

- **Encrypted Storage**: Store environment variables in encrypted files
- **Secure Loading**: Load variables without exposing them in history or logs
- **Variable Masking**: List environment variables with sensitive values masked

Usage:
```bash
# Create a new encrypted environment file
create_secure_env

# Load variables from an encrypted file
load_secure_env

# List all environment variables (with sensitive values masked)
list_env_vars
```

### 3. File Encryption

The file encryption system provides tools for encrypting sensitive files:

- **Automatic Detection**: Automatically detect files that may contain sensitive information
- **Strong Encryption**: Use GPG for strong symmetric encryption
- **Secure Decryption**: Safely decrypt files when needed

Usage:
```bash
# Encrypt sensitive files
/home/ajay/.dotfiles/scripts/encrypt-sensitive.sh

# Decrypt a file when needed
/home/ajay/.dotfiles/scripts/decrypt-file.sh file.gpg
```

### 4. Permission Hardening

The permission hardening system ensures files and directories have appropriate permissions:

- **Secure Defaults**: Set secure default permissions for files and directories
- **Automatic Fixing**: Automatically fix insecure permissions
- **Targeted Protection**: Special handling for sensitive files and directories

Usage:
```bash
# Secure file permissions
/home/ajay/.dotfiles/scripts/secure-permissions.sh
```

### 5. Security Monitoring

The security monitoring system regularly checks for security issues:

- **Sensitive File Detection**: Find files that may contain sensitive information
- **Permission Auditing**: Check for files with insecure permissions
- **Change Monitoring**: Detect suspicious changes in the repository
- **Security Reporting**: Generate comprehensive security reports

Usage:
```bash
# Run security monitoring
/home/ajay/.dotfiles/scripts/security-monitor.sh
```

### 6. Comprehensive Security Hardening

The security hardening script applies all security best practices at once:

- **Shell History Security**: Enhance shell history security
- **Script Permission Hardening**: Set secure permissions for scripts
- **Sensitive Data Detection**: Find and protect sensitive data
- **SSH Configuration Hardening**: Secure SSH configuration
- **Git Security Improvements**: Enhance Git security
- **Environment Variable Security**: Improve environment variable security
- **File Permission Auditing**: Audit and fix file permissions

Usage:
```bash
# Run security hardening
/home/ajay/.dotfiles/scripts/security-hardening.sh
```

## Security Best Practices

### Handling Sensitive Data

1. **Never store unencrypted sensitive data** in your dotfiles repository
2. **Use environment variables** for sensitive configuration values
3. **Encrypt sensitive files** using the provided encryption tools
4. **Use secure permissions** (600 for sensitive files, 700 for scripts)
5. **Regularly audit** your dotfiles for sensitive information

### SSH Security

1. **Use strong key types** (ED25519 or RSA with 4096 bits)
2. **Protect private keys** with secure permissions (600)
3. **Use a secure SSH config** with modern algorithms
4. **Consider using a passphrase** for SSH keys

### Git Security

1. **Use a global .gitignore** to prevent committing sensitive files
2. **Configure Git** to use secure defaults
3. **Sign commits** with GPG when possible
4. **Use a credential helper** to securely store credentials

## Security Tools

| Tool | Description | Usage |
|------|-------------|-------|
| `security-hardening.sh` | Comprehensive security hardening | `./scripts/security-hardening.sh` |
| `secure-permissions.sh` | Fix file and directory permissions | `./scripts/secure-permissions.sh` |
| `encrypt-sensitive.sh` | Detect and encrypt sensitive files | `./scripts/encrypt-sensitive.sh` |
| `security-monitor.sh` | Monitor for security issues | `./scripts/security-monitor.sh` |
| `secure_env.sh` | Manage sensitive environment variables | Source in shell config |
| `history_security.sh` | Prevent logging sensitive commands | Source in shell config |
| `clean-history.sh` | Clean sensitive data from history | `./scripts/clean-history.sh` |

## Regular Security Maintenance

1. **Run security monitoring** regularly to check for issues
2. **Update security tools** when new versions are available
3. **Review security reports** and address any findings
4. **Clean shell history** periodically to remove any sensitive data
5. **Audit file permissions** to ensure they remain secure

## Additional Resources

- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
- [Linux Security Checklist](https://linuxsecurity.expert/checklists/linux-security-checklist/)
- [GPG Documentation](https://gnupg.org/documentation/)
- [SSH Security Best Practices](https://www.ssh.com/academy/ssh/security)