############################################
# Starship Prompt
############################################
# Detect if inside tmux
if [[ -n "$TMUX" ]]; then
  # In tmux session → use special config
  export STARSHIP_CONFIG="$HOME/.config/starship-tmux.toml"
else
  # Normal terminal → use default config
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
fi

# Modern, customizable shell prompt
eval "$(starship init zsh)"

############################################
# Paths
############################################
# Ensure user-local bin dirs are in PATH
case ":$PATH:" in
    *":$HOME/.local/bin:"*|*":$HOME/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac
export PATH

############################################
# Java
############################################
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$JAVA_HOME/bin:$PATH

############################################
# NVM (Node Version Manager)
############################################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

############################################
# Zsh Plugins: Autocomplete, Autosuggestions, Syntax Highlighting
############################################
# Enable tab completion
autoload -U compinit && compinit -u

# Enable colors
autoload -U colors && colors

# Autosuggestions
if [ -f "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
else
    echo "⚠️  zsh-autosuggestions not found."
    echo "   Install with: git clone https://github.com/zsh-users/zsh-autosuggestions \\
        \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
fi

# Syntax Highlighting
if [ -f "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
    echo "⚠️  zsh-syntax-highlighting not found."
    echo "   Install with: git clone https://github.com/zsh-users/zsh-syntax-highlighting \\
        \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
fi

############################################
# FZF (Fuzzy Finder) Configuration
############################################
# Use fd if available (faster than find)
if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
else
    export FZF_DEFAULT_COMMAND='find . -type f'
fi

# Default fzf appearance & keybinds
export FZF_DEFAULT_OPTS="
    --height=40% --layout=reverse --border
    --ignore-case
    --info=inline
    --preview '[[ -f {} ]] && bat --style=numbers --color=always {} || ls -la {}'
    --preview-window=right:60%
    --bind 'ctrl-/:toggle-preview'
    --bind 'ctrl-u:page-up,ctrl-d:page-down'
    --bind 'ctrl-j:down,ctrl-k:up'
    --bind 'alt-j:half-page-down,alt-k:half-page-up'
    --color=bg+:#1e1e1e,bg:#121212,spinner:#ffcc00,hl:#00ffff
    --color=fg:#ffffff,header:#ff9900,info:#00ffff,pointer:#ff9900
    --color=marker:#ffcc00,fg+:#ffffff,prompt:#00ffcc,hl+:#ffcc00
"

# Reverse search (Ctrl+R)
export FZF_CTRL_R_OPTS="
    --preview 'echo {}' --preview-window=up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'
"

# Load fzf bindings if installed
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Load fzf keybindings + completion (Fedora packaged version)
if [ -f /usr/share/fzf/shell/key-bindings.zsh ]; then
    source /usr/share/fzf/shell/key-bindings.zsh
fi
if [ -f /usr/share/fzf/shell/completion.zsh ]; then
    source /usr/share/fzf/shell/completion.zsh
fi

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

############################################
# Smart FZF Search (Ctrl+F)
# - If command starts with 'cd' → pick directory
# - Else → pick file
# - Supports optional pattern (regex/glob/case-insensitive)
############################################
fzf-smart-widget() {
    local raw_base base expanded dir pattern selected prefix pat preview_cmd

    # Get last token (may be empty if trailing space)
    raw_base=${(Q)LBUFFER##* }
    base="$raw_base"

    # Prefix = everything before the last token (so we can replace the token later)
    if [[ -z "$base" ]]; then
        prefix="$LBUFFER"      # append mode
    else
        prefix=${LBUFFER%"$base"}  # replace last token
    fi

    # Expand ~ and variables using zsh expansion
    if [[ -n "$base" ]]; then
        # ${~base} tells zsh: re-scan the value as if it were a shell word (expands ~, $VAR, etc.)
        # Use a try/fallback in case of weird values
        expanded=${~base} 2>/dev/null || expanded="$base"
        # If expansion still contains a leading ~ (rare), replace with $HOME
        if [[ "$expanded" == "~"* ]]; then
            expanded="${expanded/#\~/$HOME}"
        fi
        # Normalize to an absolute path where possible (realpath -m is tolerant)
        expanded=$(realpath -m -- "$expanded" 2>/dev/null || printf '%s' "$expanded")
    else
        expanded=""
    fi

    # Decide whether user intended a directory or a search pattern:
    # - If expanded is an existing directory OR the token ends with '/', treat as directory search
    # - If token is exactly '~' or '~/' treat as home dir
    if [[ -n "$expanded" && ( -d "$expanded" || "$base" == */ || "$base" == "~" || "$base" == "~/" ) ]]; then
        dir="$expanded"
        pattern=""   # no extra filtering; show contents of dir
    else
        dir="."
        pattern="$expanded"   # may be empty -> show everything
    fi

    # Pattern to pass to fd/find: if empty, use '.' (matches everything)
    if [[ -z "$pattern" ]]; then
        pat='.'
    else
        pat="$pattern"
    fi

    # Preview: bat if available, fallback to head
    preview_cmd='[[ -f {} ]] && (bat --style=numbers --color=always {} 2>/dev/null || head -n 200 {}) || ls -la {}'

    # Decide cd (directory) mode — check first word of buffer
    if [[ "${LBUFFER%% *}" == cd ]]; then
        # Directory picker
        if command -v fd >/dev/null 2>&1; then
            # fd: pattern then path
            selected=$(fd -i -t d --hidden --follow --exclude .git "$pat" "$dir" 2>/dev/null | \
                       fzf --no-multi --preview "$preview_cmd")
        else
            selected=$(find "$dir" -type d 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
        fi
    else
        # File picker
        if command -v fd >/dev/null 2>&1; then
            selected=$(fd -i -t f --hidden --follow --exclude .git "$pat" "$dir" 2>/dev/null | \
                       fzf --no-multi --preview "$preview_cmd")
        else
            if [[ -n "$pattern" ]]; then
                selected=$(find "$dir" -type f -iname "*$pattern*" 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
            else
                selected=$(find "$dir" -type f 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
            fi
        fi
    fi

    # If something selected, replace last token (or append)
    if [[ -n "$selected" ]]; then
        selected=${selected%%$'\n'*}   # strip trailing newline(s) if any
        LBUFFER="${prefix}${selected}"
        zle redisplay
    fi
}
zle -N fzf-smart-widget
bindkey '^F' fzf-smart-widget

############################################
# Make FZF + Autosuggestions Play Nice
############################################
# Disable autosuggestions while using history search
fzf-history-widget-without-autosuggest() {
    zle autosuggest-disable
    fzf-history-widget
    zle autosuggest-enable
}
zle -N fzf-history-widget-without-autosuggest
bindkey '^R' fzf-history-widget-without-autosuggest

############################################
# History Settings
############################################
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

setopt append_history           # Append instead of overwrite
unsetopt share_history          # Don't instantly share between sessions
setopt inc_append_history       # Save incrementally
setopt hist_ignore_all_dups     # Remove older duplicate entries
setopt hist_ignore_space        # Ignore commands starting with space
setopt hist_save_no_dups        # Avoid saving duplicates
setopt extended_history         # Add timestamps

############################################
# Security & Environment
############################################
[ -f "$HOME/.dotfiles/shell/history_security.sh" ] && source "$HOME/.dotfiles/shell/history_security.sh"
[ -f "$HOME/.dotfiles/shell/secure_env.sh" ] && source "$HOME/.dotfiles/shell/secure_env.sh"

############################################
# Editor
############################################
export VISUAL=nano
export EDITOR="$VISUAL"

############################################
# Aliases
############################################
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias sudo='sudo '

############################################
# Secure Clear Function
############################################
secure_clear() {
    if [ -x /usr/bin/clear_console ]; then
        /usr/bin/clear_console -q
    else
        echo -e "\033c\e[3J"  # Full screen clear
    fi
}
alias sclear='secure_clear'

