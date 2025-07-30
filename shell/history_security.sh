# History Security Settings
# Add this to your .bashrc or .zshrc to prevent sensitive commands from being logged

# Bash history security settings
if [ -n "$BASH_VERSION" ]; then
    # Don't log commands that start with a space
    export HISTCONTROL=ignorespace:ignoredups:erasedups
    
    # Don't log sensitive commands
    export HISTIGNORE="*password*:*secret*:*token*:*key*:mysql*-p*:sudo*password*:ssh*pass*"  # SAFE: Security exclusion patterns
    
    # Limit history size
    export HISTSIZE=10000
    export HISTFILESIZE=10000
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
    
    # Limit history size
    export HISTSIZE=10000
    export SAVEHIST=10000
fi

# Universal security aliases to prevent accidental logging
alias mysql_secure='HISTCONTROL=ignorespace mysql'
alias ssh_secure='HISTCONTROL=ignorespace ssh'
alias curl_secure='HISTCONTROL=ignorespace curl'

# Function to run sensitive commands without logging
secure_cmd() {
    # Temporarily disable history
    set +o history
    "$@"
    # Re-enable history
    set -o history
}

echo "🔒 History security settings loaded"
echo "💡 Tip: Prefix sensitive commands with a space to avoid logging"
echo "💡 Or use: secure_cmd <your-sensitive-command>"