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

# Share history across all sessions
setopt share_history

# Ignore duplicate commands in history
setopt hist_ignore_all_dups

# java Home
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$JAVA_HOME/bin:$PATH

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

