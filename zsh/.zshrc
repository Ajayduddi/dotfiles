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
eval "$(ssh-agent -s)"

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

# LS_COLORS: improved palette with distinct colors per file type
# - Directories/link/executables are clear; no bright backgrounds on dirs
# - Many common extensions mapped for quick visual scanning
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi
# Prefer vivid (256-color) if available; fallback to static LS_COLORS above
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid -m 8-bit generate molokai)"
else
  export LS_COLORS="${LS_COLORS}:no=00:fi=00:di=01;34:ln=01;36:ex=01;32:so=01;35:pi=01;33:bd=01;33:cd=01;33:su=01;41:sg=01;43:tw=01;34:ow=01;34:st=01;34:or=01;31:mi=01;31:\
*.sh=01;32:*.bash=01;32:*.zsh=01;32:*.py=01;32:*.rb=01;31:*.pl=01;33:*.js=01;33:*.ts=01;36:*.jsx=01;33:*.tsx=01;36:*.go=01;36:*.rs=01;33:*.c=01;36:*.h=36:*.cpp=01;36:*.hpp=36:*.java=01;33:*.kt=01;33:*.swift=01;33:\
*.md=01;35:*.txt=00;37:*.rst=00;37:*.org=00;37:\
*.json=36:*.yaml=36:*.yml=36:*.toml=36:*.ini=36:*.conf=36:\
*.jpg=01;33:*.jpeg=01;33:*.png=01;33:*.gif=01;33:*.bmp=01;33:*.tiff=01;33:*.svg=01;33:*.ico=01;33:*.webp=01;33:\
*.mp3=00;36:*.wav=00;36:*.flac=00;36:*.ogg=00;36:*.m4a=00;36:*.aac=00;36:*.opus=00;36:\
*.mp4=01;35:*.mkv=01;35:*.webm=01;35:*.avi=01;35:*.mov=01;35:*.wmv=01;35:*.flv=01;35:\
*.zip=01;31:*.tar=01;31:*.gz=01;31:*.bz2=01;31:*.xz=01;31:*.7z=01;31:*.rar=01;31:*.tgz=01;31:*.tbz=01;31:*.tbz2=01;31:*.txz=01;31:*.zst=01;31:\
*.pdf=01;31:*.doc=01;31:*.docx=01;31:*.xls=01;31:*.xlsx=01;31:*.ppt=01;31:*.pptx=01;31"
fi

# Colored ls defaults and helpers
alias ls='ls --color=auto'
alias ll='ls -lh --color=auto --group-directories-first'
alias la='ls -A --color=auto --group-directories-first'

# Show a quick legend of key LS_COLORS categories
lscolor-legend() {
  local -a rows=(
    "01;34 [dir]        folder/"
    "01;36 [link]       link -> target"
    "01;32 [exec]       run.sh*"
    "01;31 [archive]    archive.zip"
    "01;33 [image]      image.png"
    "01;35 [video]      video.mkv"
    "00;36 [audio]      song.mp3"
    "36    [json]       config.json"
    "36    [yaml]       config.yaml"
    "01;35 [markdown]   README.md"
    "01;32 [python]     script.py"
    "01;33 [javascript] app.js"
    "01;36 [c/c++]      main.c"
  )
  echo "LS_COLORS legend (sample):"
  for row in "${rows[@]}"; do
    printf "\e[%sm%s\e[0m\n" ${row%% *} "${row#* }"
  done
}

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
# Editor
############################################
export VISUAL=nano
export EDITOR="$VISUAL"

############################################
# zoxide (smarter cd)
############################################
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd zsh)"
fi

############################################
# Aliases
############################################
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias sudo='sudo '
alias cl='clear'

# Load Angular CLI autocompletion.
source <(ng completion script)
