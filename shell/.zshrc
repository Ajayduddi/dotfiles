# add starship customization
eval "$(starship init zsh)"

# Enable command autocompletion
autoload -U compinit
compinit

# Case-sensitive completion.
CASE_SENSITIVE="true"

# Enable color support
autoload -U colors
colors

# Set the default starting directory (change to your desired directory)
# cd ~  # This will start in your home directory, change to your preferred directory

# User specific environment
case ":$PATH:" in
    *":$HOME/.local/bin:"*|*":$HOME/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac
export PATH

# Enable auto-correction for typos in commands (e.g., 'sl' instead of 'ls')
ENABLE_CORRECTION="true"

# Set default editor (use your preferred editor)
export VISUAL=nano
export EDITOR="$VISUAL"

# Load history file (you can change the path to your own history file)
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Append to the history file, rather than overwriting it
setopt append_history

# SECURITY ENHANCEMENT: Don't share history across all sessions immediately
# This prevents sensitive commands from being immediately visible in other sessions
unsetopt share_history
setopt inc_append_history

# Ignore duplicate commands in history
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_save_no_dups

# Add timestamps to history
setopt extended_history

# java Home
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$JAVA_HOME/bin:$PATH

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Load enhanced history security settings
if [ -f "$HOME/.dotfiles/shell/history_security.sh" ]; then
    source "$HOME/.dotfiles/shell/history_security.sh"
fi

# Load secure environment variables manager
if [ -f "$HOME/.dotfiles/shell/secure_env.sh" ]; then
    source "$HOME/.dotfiles/shell/secure_env.sh"
fi

# Security aliases
alias rm='rm -i'  # Interactive mode to prevent accidental deletion
alias cp='cp -i'  # Interactive mode to prevent accidental overwriting
alias mv='mv -i'  # Interactive mode to prevent accidental overwriting
alias sudo='sudo '  # Allow aliases to be sudo'ed

# Function to securely clear the terminal (more thorough than clear)
secure_clear() {
    if [ -x /usr/bin/clear_console ]; then
        /usr/bin/clear_console -q
    else
        echo -e "\033c\e[3J"  # More thorough than just 'clear'
    fi
}
alias sclear='secure_clear'

