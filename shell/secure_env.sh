#!/bin/bash

# SECURE ENVIRONMENT VARIABLES MANAGER
# Safely manage sensitive environment variables

# Function to securely load environment variables from an encrypted file
load_secure_env() {
    local env_file="${1:-$HOME/.secure_env}"
    
    if [ ! -f "$env_file" ]; then
        echo "❌ Secure environment file not found: $env_file"
        return 1
    fi
    
    # Check if file is encrypted (GPG)
    if file "$env_file" | grep -q "GPG symmetrically encrypted"; then
        # Decrypt and source the file
        if command -v gpg >/dev/null 2>&1; then
            # Temporarily disable history
            if [ -n "$BASH_VERSION" ]; then
                set +o history
                source <(gpg --quiet --decrypt "$env_file" 2>/dev/null)
                set -o history
            elif [ -n "$ZSH_VERSION" ]; then
                unsetopt SHARE_HISTORY
                fc -p /dev/null
                source <(gpg --quiet --decrypt "$env_file" 2>/dev/null)
                fc -P
            fi
            echo "✅ Loaded encrypted environment variables from $env_file"
        else
            echo "❌ GPG not installed. Cannot decrypt environment file."
            return 1
        fi
    else
        # File is not encrypted, warn and source directly
        echo "⚠️  WARNING: Environment file is not encrypted: $env_file"
        echo "⚠️  Consider encrypting with: encrypt_secure_env $env_file"
        
        # Temporarily disable history
        if [ -n "$BASH_VERSION" ]; then
            set +o history
            source "$env_file"
            set -o history
        elif [ -n "$ZSH_VERSION" ]; then
            unsetopt SHARE_HISTORY
            fc -p /dev/null
            source "$env_file"
            fc -P
        fi
        echo "✅ Loaded unencrypted environment variables from $env_file"
    fi
}

# Function to create and encrypt an environment variables file
create_secure_env() {
    local env_file="${1:-$HOME/.secure_env}"
    
    # Check if file already exists
    if [ -f "$env_file" ]; then
        echo "⚠️  File already exists: $env_file"
        read -p "Overwrite? [y/N] " confirm
        if [[ "$confirm" != [yY]* ]]; then
            echo "❌ Operation cancelled"
            return 1
        fi
    fi
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Add header
    cat > "$temp_file" << 'HEADER'
# SECURE ENVIRONMENT VARIABLES
# This file contains sensitive environment variables
# It should be encrypted when not in use

# Format: export NAME=value

HEADER
    
    # Open the file in the default editor
    ${EDITOR:-nano} "$temp_file"
    
    # Encrypt the file
    if command -v gpg >/dev/null 2>&1; then
        gpg --symmetric --cipher-algo AES256 --output "$env_file" "$temp_file"
        echo "✅ Created and encrypted environment variables file: $env_file"
    else
        # If GPG is not available, save as plaintext but warn
        cp "$temp_file" "$env_file"
        chmod 600 "$env_file"
        echo "⚠️  GPG not installed. Saved as unencrypted file with restricted permissions."
        echo "⚠️  Install GPG and run: encrypt_secure_env $env_file"
    fi
    
    # Remove the temporary file
    rm -f "$temp_file"
}

# Function to encrypt an existing environment variables file
encrypt_secure_env() {
    local env_file="${1:-$HOME/.secure_env}"
    
    if [ ! -f "$env_file" ]; then
        echo "❌ File not found: $env_file"
        return 1
    fi
    
    # Check if file is already encrypted
    if file "$env_file" | grep -q "GPG symmetrically encrypted"; then
        echo "⚠️  File is already encrypted: $env_file"
        return 0
    fi
    
    if command -v gpg >/dev/null 2>&1; then
        # Create backup
        cp "$env_file" "${env_file}.backup"
        
        # Encrypt the file
        gpg --symmetric --cipher-algo AES256 --output "${env_file}.gpg" "$env_file"
        
        # If encryption successful, replace original with encrypted version
        if [ -f "${env_file}.gpg" ]; then
            mv "${env_file}.gpg" "$env_file"
            echo "✅ Encrypted environment variables file: $env_file"
            echo "✅ Original backed up to: ${env_file}.backup"
        else
            echo "❌ Encryption failed"
            return 1
        fi
    else
        echo "❌ GPG not installed. Cannot encrypt file."
        return 1
    fi
}

# Function to securely set an individual environment variable
secure_set_env() {
    local var_name="$1"
    
    if [ -z "$var_name" ]; then
        echo "❌ Variable name required"
        echo "Usage: secure_set_env VARIABLE_NAME"
        return 1
    fi
    
    # Use read -s to avoid showing the value in terminal
    read -s -p "Enter value for $var_name: " var_value
    echo ""  # Add newline after hidden input
    
    # Export the variable without logging
    if [ -n "$BASH_VERSION" ]; then
        set +o history
        export "$var_name"="$var_value"
        set -o history
    elif [ -n "$ZSH_VERSION" ]; then
        unsetopt SHARE_HISTORY
        fc -p /dev/null
        export "$var_name"="$var_value"
        fc -P
    fi
    
    echo "✅ Environment variable $var_name set securely"
}

# Function to list all environment variables, hiding sensitive values
list_env_vars() {
    local sensitive_patterns=("key" "token" "secret" "password" "credential" "auth")
    
    echo "ENVIRONMENT VARIABLES:"
    echo "======================"
    
    # Get all environment variables
    env | sort | while read -r line; do
        local var_name="${line%%=*}"
        local var_value="${line#*=}"
        local is_sensitive=false
        
        # Check if variable name contains sensitive patterns
        for pattern in "${sensitive_patterns[@]}"; do
            if [[ "$var_name" =~ $pattern ]]; then
                is_sensitive=true
                break
            fi
        done
        
        # Display with masked value if sensitive
        if [ "$is_sensitive" = true ]; then
            echo "$var_name=[HIDDEN]"
        else
            echo "$line"
        fi
    done
}

# Secure environment variables manager loaded silently
# Available commands:
#   - load_secure_env [file]     # Load variables from encrypted file
#   - create_secure_env [file]   # Create and encrypt a variables file
#   - encrypt_secure_env [file]  # Encrypt an existing variables file
#   - secure_set_env VAR_NAME    # Securely set a variable
#   - list_env_vars              # List all variables (hiding sensitive values)