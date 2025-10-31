############################################
# Starship Prompt
############################################
if [ -n "$TMUX" ]; then
    # In tmux session → use special config
    export STARSHIP_CONFIG="$HOME/.config/starship-tmux.toml"
else
    # Normal terminal → use default config
    export STARSHIP_CONFIG="$HOME/.config/starship.toml"
fi


# Modern, customizable shell prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

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
# Colors for ls (LS_COLORS)
# - Prefer vivid (8-bit palette) if available
# - Fallback to a rich static LS_COLORS mapping
############################################
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi
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

# Quick legend for LS_COLORS
lscolor_legend() {
  local rows=(
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
    printf '\e[%sm%s\e[0m\n' "${row%% *}" "${row#* }"
  done
}

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
"

# Reverse search (Ctrl+R) preview few lines
export FZF_CTRL_R_OPTS="
    --preview 'echo {}' --preview-window=up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'
"

# Load fzf keybindings & completion (packaged location for many distros)
if [ -f /usr/share/fzf/shell/key-bindings.bash ]; then
    source /usr/share/fzf/shell/key-bindings.bash
fi
if [ -f /usr/share/fzf/shell/completion.bash ]; then
    source /usr/share/fzf/shell/completion.bash
fi

# If fzf provides a helper, try to source it (safe guard)
if command -v fzf >/dev/null 2>&1; then
    # This registers default bash keybindings if fzf supports it
    # (some distro packages use different paths; this is a generic call)
    if fzf --version >/dev/null 2>&1; then
        # This will print a 'completion' script; if it's available it will be sourced.
        # Use a subshell to avoid errors if command substitution fails
        if [ -n "$(fzf 2>/dev/null --version 2>/dev/null)" ]; then
            # try to source the completion helper if present (safe no-op otherwise)
            # note: this may print an error on some setups, ignore failures
            source <(fzf --completion bash 2>/dev/null) 2>/dev/null || true
        fi
    fi
fi

############################################
# Smart FZF Search (Ctrl+F) for Bash
# - Ctrl+F opens an fzf search
# - If first word is "cd", acts as directory picker
# - If you typed a path ending with '/', it searches inside that dir
# - If you typed a token (e.g., "desktop"), it filters by that pattern
# - Expands ~ and variables safely and never passes a literal ~ to fd/find
# - Uses fd when present, falls back to find
# - Inserts/replace the last token in the commandline
############################################
fzf_smart_widget() {
    # Only run if fzf exists
    command -v fzf >/dev/null 2>&1 || return

    local line left point base prefix expanded dir pattern pat selected preview_cmd cmd firstword suffix new_point

    # Read current readline state
    line="${READLINE_LINE}"
    point="${READLINE_POINT}"

    # Left side of cursor
    left="${line:0:point}"

    # Suffix (text after cursor) to preserve
    suffix="${line:point}"

    # last token before cursor (may be empty)
    base="${left##* }"

    # prefix = everything before last token (kept for replacement)
    if [[ -z "$base" ]]; then
        prefix="$left"   # append mode: left already contains trailing space or is empty
    else
        prefix="${left%$base}"
    fi

    # Expand ~ and variables using eval (zsh-style ${~var} not available)
    if [[ -n "$base" ]]; then
        # Use printf to expand common constructs; eval to expand ~ and $VAR
        eval "expanded=\"$base\"" 2>/dev/null || expanded="$base"
        # if expansion still starts with ~, replace with $HOME
        if [[ "$expanded" == "~"* ]]; then
            expanded="${expanded/#\~/$HOME}"
        fi
        # Normalize absolute path where possible, tolerant realpath
        expanded=$(realpath -m -- "$expanded" 2>/dev/null || printf '%s' "$expanded")
    else
        expanded=""
    fi

    # Decide whether it's a directory path or a search pattern:
    # directory if existing dir OR user typed trailing '/' OR token is '~'/'~/'
    if [[ -n "$expanded" && ( -d "$expanded" || "${base: -1}" == "/" || "$base" == "~" || "$base" == "~/" ) ]]; then
        dir="$expanded"
        pattern=""
    else
        dir="."
        pattern="$expanded"
    fi

    # ensure pattern fallback
    if [[ -z "$pattern" ]]; then
        pat='.'
    else
        pat="$pattern"
    fi

    # Preview command
    preview_cmd='[[ -f {} ]] && (bat --style=numbers --color=always {} 2>/dev/null || head -n 200 {}) || ls -la {}'

    # extract first word of full line to test for cd
    firstword="${line%% *}"

    if [[ "$firstword" == "cd" ]]; then
        # Directory picker
        if command -v fd >/dev/null 2>&1; then
            selected=$(fd -i -t d --hidden --follow --exclude .git "$pat" "$dir" 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
        else
            selected=$(find "$dir" -type d 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
        fi
    else
        # File picker
        if command -v fd >/dev/null 2>&1; then
            selected=$(fd -i -t f --hidden --follow --exclude .git "$pat" "$dir" 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
        else
            if [[ -n "$pattern" ]]; then
                selected=$(find "$dir" -type f -iname "*$pattern*" 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
            else
                selected=$(find "$dir" -type f 2>/dev/null | fzf --no-multi --preview "$preview_cmd")
            fi
        fi
    fi

    # If user chose something, replace the last token (or append) and restore suffix
    if [[ -n "$selected" ]]; then
        # strip trailing newline
        selected="${selected%%$'\n'*}"

        # New line becomes prefix + selection + suffix
        READLINE_LINE="${prefix}${selected}${suffix}"

        # Place cursor right after the inserted path
        new_point=$(( ${#prefix} + ${#selected} ))
        READLINE_POINT=$new_point
    fi
}

# Bind Ctrl+F to our function (bind -x available in bash)
# Note: this will override any existing Ctrl+F readline binding
if bind -v >/dev/null 2>&1; then
    bind -x '"\C-f": fzf_smart_widget'
fi

############################################
# Make FZF + interactive history play nice
# (If packaged keybindings already set Ctrl+R, Ctrl-T, Alt-C, skip re-binding)
# We keep an explicit Ctrl+R fallback that uses fzf if default not present.
############################################
# If user doesn't already have Ctrl-R from fzf package, set one
if ! bind -q 'reverse-search-history' >/dev/null 2>&1; then
    if command -v fzf >/dev/null 2>&1; then
        # fallback Ctrl-R to fzf history search
        fzf_history_widget() {
            # Use fzf to pick history and insert into command line
            local selected
            selected=$(history | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*//' | fzf --tac --no-sort --reverse --prompt='history> ') || return
            READLINE_LINE="$selected"
            READLINE_POINT=${#selected}
        }
        bind -x '"\C-r": fzf_history_widget'
    fi
fi

############################################
# History Settings (bash)
############################################
HISTFILE=~/.bash_history
HISTSIZE=10000
SAVEHIST=10000

shopt -s histappend       # append rather than overwrite
# You can add other shell options as you like

############################################
# Editor
############################################
export VISUAL=nano
export EDITOR="$VISUAL"

############################################
# zoxide (smarter cd)
############################################
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd bash)"
fi

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
        printf '\033c\e[3J'  # Full screen clear
    fi
}
alias sclear='secure_clear'
. "$HOME/.cargo/env"
