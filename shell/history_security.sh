# Enhanced History Security Settings
# Add this to your .bashrc or .zshrc to prevent sensitive commands from being logged

# Bash history security settings
if [ -n "$BASH_VERSION" ]; then
    # Don't log commands that start with a space
    export HISTCONTROL=ignorespace:ignoredups:erasedups
    
    # Don't log sensitive commands (expanded patterns)
    export HISTIGNORE="*password*:*secret*:*token*:*key*:*credential*:*auth*:*pass*:*login*:mysql*:psql*:*sudo*:ssh*:curl*-u*:*bearer*:*api*key*:*access*token*:*-p*:*--password*"
    
    # Limit history size
    export HISTSIZE=10000
    export HISTFILESIZE=10000
    
    # Enable history timestamps
    export HISTTIMEFORMAT="%F %T "
fi

# Zsh history security settings  
if [ -n "$ZSH_VERSION" ]; then
    # Don't log commands that start with a space
    setopt HIST_IGNORE_SPACE
    setopt HIST_IGNORE_DUPS
    setopt HIST_IGNORE_ALL_DUPS
    setopt HIST_SAVE_NO_DUPS
    
    # Don't share history between sessions immediately (more secure)
    unsetopt SHARE_HISTORY
    setopt INC_APPEND_HISTORY
    
    # Add timestamps to history
    setopt EXTENDED_HISTORY
    
    # Limit history size
    export HISTSIZE=10000
    export SAVEHIST=10000
fi

# Universal security aliases to prevent accidental logging
alias mysql_secure='HISTCONTROL=ignorespace mysql'
alias ssh_secure='HISTCONTROL=ignorespace ssh'
alias curl_secure='HISTCONTROL=ignorespace curl'
alias aws_secure='HISTCONTROL=ignorespace aws'
alias gcloud_secure='HISTCONTROL=ignorespace gcloud'
alias docker_secure='HISTCONTROL=ignorespace docker'
alias kubectl_secure='HISTCONTROL=ignorespace kubectl'
alias terraform_secure='HISTCONTROL=ignorespace terraform'

# Function to run sensitive commands without logging
secure_cmd() {
    # Temporarily disable history
    if [ -n "$BASH_VERSION" ]; then
        set +o history
        "$@"
        set -o history
    elif [ -n "$ZSH_VERSION" ]; then
        unsetopt SHARE_HISTORY
        fc -p /dev/null
        "$@"
        fc -P
    fi
}

# Function to securely set environment variables
secure_env() {
    local var_name="$1"
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

# Security settings loaded silently
# Tips:
# - Prefix sensitive commands with a space to avoid logging
# - Use: secure_cmd <your-sensitive-command>
# - For secure environment variables: secure_env API_KEY