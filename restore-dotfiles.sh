#!/usr/bin/env bash
# Dotfiles restore script using a stow-first workflow and non_stow restore artifacts.
# Primary stages: repo metadata refresh, tool bootstrap, stow apply, dev runtime restore, desktop restore.
# Safety model: supports --dry-run and defaults to warning/continue except for critical restore prerequisites.

set -euo pipefail
umask 077

# Minimal emoji output (set NO_EMOJI=true to strip icons)
NO_EMOJI=${NO_EMOJI:-true}
# Strip emoji characters from log text when NO_EMOJI mode is enabled.
strip_emojis() { sed -E 's/(✅|🔍|⚠️|❌|🟡|📝|🔧|💾|📦|🖥️|🚀|🌐|🗄️|🔒|🔗|🔄|➡️|🐱|☕|🛠️|📁|🔌|🛡️|🧪|🔎|📊|🧹|🟢|🟠|🔵)//g'; }
# Wrap builtin echo to support emoji filtering and -n/-e flag handling.
echo() {
  local newline=true; local enable_escape=false; local args=()
  while [[ $# -gt 0 ]]; do case "$1" in -n) newline=false;; -e) enable_escape=true;; *) args+=("$1");; esac; shift; done
  local msg="${args[*]}"
  if [[ "$NO_EMOJI" = "true" ]]; then msg=$(printf "%s" "$msg" | strip_emojis); fi
  if $enable_escape; then if $newline; then builtin echo -e "$msg"; else builtin echo -ne "$msg"; fi
  elif $newline; then builtin echo "$msg"; else builtin echo -n "$msg"; fi
}

# --- Defaults / Config (can override with env) ---
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/Ajayduddi/dotfiles.git}"
DEFAULT_BRANCH="${BRANCH:-linux_stow}"
NON_STOW_DIR="$DOTFILES_DIR/non_stow"
DRY_RUN=${DRY_RUN:-false}
STOW_ADOPT=${STOW_ADOPT:-false}
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"
SKIP_RECLONE=${SKIP_RECLONE:-false}
RECLONE_META_BACKUP=${RECLONE_META_BACKUP:-true}
META_BACKUP_DIR="${META_BACKUP_DIR:-$HOME/.dotfiles_backup/reclone-metadata}"

# --- CLI Args ---
show_help() {
    cat <<'HELP'
🔧 DOTFILES RESTORE (Stow-First)
Restore your user environment from $HOME/.dotfiles and non_stow backups.

WHAT THIS DOES:
  1) Re-clones git metadata for your dotfiles repo (replaces only .git)
     - Optional backup of old .git metadata before replacement
  2) Ensures required tools and applies GNU Stow packages to $HOME
     - Best-effort installs Homebrew on macOS when missing
     - Best-effort installs Starship binary when missing
  3) Restores non_stow developer environment backups:
     - Python, Node, Bun, Rust (best-effort, warning on failures)
     - Missing runtimes may be auto-installed when backup metadata exists
  4) Restores desktop settings (when available):
     - GNOME/Cinnamon/MATE/COSMIC via dconf
     - KDE plasmoids, Xfce config tree

BEHAVIOR:
  - Default flow is non-destructive for stow symlinks.
  - Package-manager system reinstall is intentionally not done here.
  - Use --dry-run to preview every planned action.

USAGE:
  restore-dotfiles.sh [--dry-run|-n] [--skip-reclone] [--help|-h]

OPTIONS:
  --dry-run, -n  Show what would be done without making changes
  --skip-reclone Skip the git metadata re-clone step and use existing repo state
  --help,   -h   Show this help message and exit

ENVIRONMENT VARIABLES:
  DOTFILES_DIR  Target dotfiles directory (default: $HOME/.dotfiles)
  REPO_URL      Git repository URL (default: https://github.com/Ajayduddi/dotfiles.git)
  BRANCH        Branch to clone (default: linux_stow)
  NO_EMOJI      true/false (true = hide emoji icons, default: true)
  DRY_RUN       true/false to force dry-run (default: false)
  STOW_ADOPT    true/false to use 'stow --adopt' and absorb existing files into the repo (default: false)
  SKIP_RECLONE  true/false to skip replacing .git metadata (default: false)
  RECLONE_META_BACKUP true/false to back up existing .git before replacement (default: true)

WHAT GETS STOWED:
  - Every top-level directory in the repo root is considered a stow package, except:
    .git, non_stow, wallpapers, .github, .zencoder

WHAT GETS RESTORED FROM non_stow (if present):
  - Developer environments:
    Python, Node, Bun, Rust
  - GNOME/Cinnamon/MATE/COSMIC: dconf dump file
  - KDE: ~/.local/share/plasma/plasmoids
  - Xfce: ~/.config/xfce4

REQUIREMENTS:
  - Network access to clone the repo (normal mode)
  - Network access may be needed for Homebrew bootstrap on macOS
  - sudo privileges to install GNU Stow (if it's missing in normal mode)

EXAMPLES:
  # Full restore
  bash restore-dotfiles.sh

  # Preview only
  bash restore-dotfiles.sh --dry-run

  # Keep existing git metadata and reuse current repo state
  bash restore-dotfiles.sh --skip-reclone

  # Adopt existing files into stow-managed packages when conflicts occur
  STOW_ADOPT=true bash restore-dotfiles.sh

  # Override source repo/branch
  REPO_URL="https://github.com/Ajayduddi/dotfiles.git" BRANCH="linux_stow" bash restore-dotfiles.sh
HELP
}

# Parse CLI flags and update runtime options used by the script.
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run|-n)
        DRY_RUN=true
        ;;
      --skip-reclone)
        SKIP_RECLONE=true
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
    shift
  done
}

# --- Logging helpers ---
format_path() { # path
  local p="${1:-}"
  local df="${DOTFILES_DIR:-$HOME/.dotfiles}"
  # shellcheck disable=SC2088
  local home_prefix='~/'
  [[ -z "$p" ]] && { printf '%s\n' "$p"; return 0; }
  case "$p" in
    "$df"/*) p="${p#"$df"/}" ;;
    "$HOME"/*) p="${home_prefix}${p#"$HOME"/}" ;;
    "$HOME") p="~" ;;
  esac
  printf '%s\n' "$p"
}

# Normalize a log message and shorten embedded filesystem paths.
format_message() { # message
  local msg="$*"
  local df="${DOTFILES_DIR:-$HOME/.dotfiles}"
  # shellcheck disable=SC2088
  local home_token='~'
  # shellcheck disable=SC2088
  local home_slash_token='~/'
  msg="${msg//"$df/"/}"
  msg="${msg//"$HOME/"/$home_slash_token}"
  msg="${msg//"$HOME"/$home_token}"
  printf '%s\n' "$msg"
}

# Emit a formatted log line for status, warnings, errors, or dry-run output.
log()     { echo "[INFO] $(format_message "$*")"; }
# Emit a structured log line for this severity level.
log_ok()  { echo "[OK] $(format_message "$*")"; }
# Emit a formatted log line for status, warnings, errors, or dry-run output.
warn()    { echo "[WARN] $(format_message "$*")"; }
# Emit a formatted log line for status, warnings, errors, or dry-run output.
err()     { echo "[ERROR] $*"; }
# Emit a formatted log line for status, warnings, errors, or dry-run output.
would()   { echo "[DRY] $(format_message "$*")"; }
# Print a section header to group output by execution stage.
section() { echo "[INFO] ===== $* ====="; }

parse_args "$@"

# Detect OS and DE
_detect_os() {
  if [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; then echo mac; return; fi
  if command -v dnf5 >/dev/null 2>&1; then echo fedora; return; fi
  if command -v dnf >/dev/null 2>&1; then echo fedora; return; fi
  if command -v apt-get >/dev/null 2>&1; then
    if [[ -r /etc/os-release ]]; then
      . /etc/os-release
      case "${ID:-}" in
        kali) echo kali; return ;;
        ubuntu) echo ubuntu; return ;;
        debian) echo debian; return ;;
      esac
      case "${ID_LIKE:-}" in
        *debian*) echo debian; return ;;
      esac
    fi
    echo debian; return
  fi
  if command -v pacman >/dev/null 2>&1; then echo arch; return; fi
  if command -v zypper >/dev/null 2>&1; then echo opensuse; return; fi
  if command -v brew >/dev/null 2>&1; then echo mac; return; fi
  echo unknown
}
# Detect the current desktop environment to select DE-specific restore steps.
_detect_de() {
  local de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-${GDMSESSION:-unknown}}}"
  de=$(printf '%s' "$de" | tr '[:upper:]' '[:lower:]')
  case "$de" in
    *gnome*) echo gnome ;;
    *plasma*|*kde*) echo kde ;;
    *xfce*) echo xfce ;;
    *mate*) echo mate ;;
    *cinnamon*) echo cinnamon ;;
    *cosmic*) echo cosmic ;;
    *) echo unknown ;;
  esac
}
OS_ID=$(_detect_os)
# trim whitespace (safety: some environments concat IDs or include extra chars)
OS_ID=${OS_ID//[[:space:]]/}
DE_ID=$(_detect_de)
section "Startup"
log "os: $OS_ID"
log "desktop: $DE_ID"
log "mode: $([[ "$DRY_RUN" == true ]] && echo dry-run || echo apply)"
log "skip-reclone: $SKIP_RECLONE"

# --- Ensure base dir ---
if [[ "$DRY_RUN" == true ]]; then
  [[ -d "$DOTFILES_DIR" ]] || would "mkdir -p '$DOTFILES_DIR'"
else
  mkdir -p "$DOTFILES_DIR"
fi

# Git is required by this script (used to clone the repo and install plugins)
if ! command -v git >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    would "Install git (git is required to clone dotfiles and plugins)"
  else
    err "git is required but not found. Please install git and re-run."
    exit 1
  fi
fi

# Back up current system or configuration state into snapshot files.
backup_existing_git_metadata() {
  local git_dir="$DOTFILES_DIR/.git"
  if [[ ! -d "$git_dir" ]]; then
    return 0
  fi
  if [[ "$RECLONE_META_BACKUP" != true ]]; then
    return 0
  fi

  local stamp out_file
  stamp=$(date +%Y%m%d_%H%M%S)
  out_file="$META_BACKUP_DIR/dotfiles-git-metadata-$stamp.tar.gz"

  if [[ "$DRY_RUN" == true ]]; then
    would "mkdir -p '$META_BACKUP_DIR'"
    would "tar -C '$DOTFILES_DIR' -czf '$out_file' '.git'"
    return 0
  fi

  mkdir -p "$META_BACKUP_DIR"
  if command -v tar >/dev/null 2>&1; then
    if tar -C "$DOTFILES_DIR" -czf "$out_file" .git 2>/dev/null; then
      log_ok "saved: $(format_path "$out_file")"
    else
      warn "Failed to back up existing git metadata"
    fi
  else
    warn "tar not found; skipping git metadata backup"
  fi
}

# --- Reclone linux_stow branch (replace .git only) ---
section "Repo"
if [[ "$SKIP_RECLONE" == true ]]; then
  log "Skipping re-clone step as requested"
else
  if [[ "$DRY_RUN" == true ]]; then
    would "git clone --branch '$DEFAULT_BRANCH' --depth 1 '$REPO_URL' <temp>"
    would "Replace $DOTFILES_DIR/.git with the one from clone (leave files intact)"
    backup_existing_git_metadata
  else
    log "Re-cloning dotfiles from $REPO_URL (branch: $DEFAULT_BRANCH) -> $DOTFILES_DIR"
    TMP_CLONE="$(mktemp -d)"
    trap 'rm -rf "$TMP_CLONE"' EXIT INT TERM
    if ! git clone --branch "$DEFAULT_BRANCH" --depth 1 "$REPO_URL" "$TMP_CLONE/repo"; then
      err "Failed to clone repository. Aborting."; exit 1
    fi
    backup_existing_git_metadata
    rm -rf "$DOTFILES_DIR/.git" 2>/dev/null || true
    mv "$TMP_CLONE/repo/.git" "$DOTFILES_DIR/.git"
    (
      cd "$DOTFILES_DIR"
      git reset --hard HEAD >/dev/null 2>&1 || true
    )
    log_ok "repo ready: $(format_path "$DOTFILES_DIR")"
  fi
fi

# --- Install required tools (stow + zsh) ---
install_tools() {
  log "Installing stow and zsh on $OS_ID"
  case "$OS_ID" in
    debian|ubuntu|kali)
      sudo apt-get update
      sudo apt-get install -y stow zsh
      ;;
    fedora)
      sudo dnf -y install stow zsh
      ;;
    arch)
      sudo pacman -Sy --noconfirm stow zsh
      ;;
    opensuse)
      sudo zypper install -y stow zsh
      ;;
    mac)
      brew install stow zsh || true
      ;;
    *)
      warn "Unknown OS; manual install of stow and zsh required"
      ;;
  esac
}

# Ensure required runtime/tooling is available; warn/continue when allowed.
ensure_homebrew_runtime() {
  # Refresh PATH for common Homebrew install locations in the current shell.
  refresh_homebrew_path() {
    [[ "$DRY_RUN" == true ]] && return 0
    local hb_path
    for hb_path in /opt/homebrew/bin /usr/local/bin; do
      [[ -d "$hb_path" ]] || continue
      case ":$PATH:" in
        *":$hb_path:"*) ;;
        *) export PATH="$hb_path:$PATH" ;;
      esac
    done
  }

  [[ "$OS_ID" == "mac" ]] || return 0

  if command -v brew >/dev/null 2>&1; then
    log_ok "homebrew already installed"
    return 0
  fi

  log "homebrew not found; attempting bootstrap install"
  if [[ "$DRY_RUN" == true ]]; then
    would "NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    would "NONINTERACTIVE=1 /bin/bash -c \"\$(wget -qO- https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"  # fallback when curl missing"
    would "export PATH='/opt/homebrew/bin:/usr/local/bin:\$PATH'"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || warn "homebrew installer via curl failed"
  elif command -v wget >/dev/null 2>&1; then
    NONINTERACTIVE=1 /bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || warn "homebrew installer via wget failed"
  else
    warn "Neither curl nor wget found; cannot bootstrap homebrew"
  fi

  refresh_homebrew_path

  if command -v brew >/dev/null 2>&1; then
    log_ok "homebrew installed"
  else
    warn "homebrew still unavailable; continuing without brew bootstrap"
  fi
}

# Ensure required runtime/tooling is available; warn/continue when allowed.
ensure_starship_runtime() {
  # Refresh PATH so freshly installed starship is discoverable in this shell.
  refresh_starship_path() {
    [[ "$DRY_RUN" == true ]] && return 0
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
  }

  # Install required packages or runtimes for this restore/workflow stage.
  install_starship_pkg() {
    if [[ "$DRY_RUN" == true ]]; then
      case "$OS_ID" in
        debian|ubuntu|kali) would "sudo apt-get update && sudo apt-get install -y starship" ;;
        fedora)             would "sudo dnf -y install starship" ;;
        arch)               would "sudo pacman -Sy --noconfirm starship" ;;
        opensuse)           would "sudo zypper install -y starship" ;;
        mac)                would "brew install starship" ;;
        *)                  would "Install starship via package manager (unsupported OS '$OS_ID')" ;;
      esac
      return 0
    fi

    case "$OS_ID" in
      debian|ubuntu|kali)
        sudo apt-get update || warn "apt-get update failed while installing starship"
        sudo apt-get install -y starship || warn "apt-get install starship failed"
        ;;
      fedora)
        sudo dnf -y install starship || warn "dnf install starship failed"
        ;;
      arch)
        sudo pacman -Sy --noconfirm starship || warn "pacman install starship failed"
        ;;
      opensuse)
        sudo zypper install -y starship || warn "zypper install starship failed"
        ;;
      mac)
        brew install starship || warn "brew install starship failed"
        ;;
      *)
        warn "Unknown OS; cannot install starship via package manager"
        ;;
    esac
  }

  # Install required packages or runtimes for this restore/workflow stage.
  install_starship_fallback() {
    if [[ "$DRY_RUN" == true ]]; then
      would "curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b '$HOME/.local/bin'"
      would "wget -qO- https://starship.rs/install.sh | sh -s -- -y -b '$HOME/.local/bin'  # fallback when curl missing"
      would "export PATH='$HOME/.local/bin:$PATH'"
      return 0
    fi

    mkdir -p "$HOME/.local/bin"
    if command -v curl >/dev/null 2>&1; then
      if ! curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; then
        warn "starship installer via curl failed"
        return 1
      fi
    elif command -v wget >/dev/null 2>&1; then
      if ! wget -qO- https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; then
        warn "starship installer via wget failed"
        return 1
      fi
    else
      warn "Neither curl nor wget found; cannot run starship installer fallback"
      return 1
    fi
    refresh_starship_path
    return 0
  }

  if command -v starship >/dev/null 2>&1; then
    log_ok "starship already installed"
    return 0
  fi

  log "starship not found; attempting package-manager install"
  install_starship_pkg
  refresh_starship_path

  if command -v starship >/dev/null 2>&1; then
    log_ok "starship installed"
    return 0
  fi

  log "starship package install unavailable/failed; attempting official installer fallback"
  install_starship_fallback || true
  refresh_starship_path

  if command -v starship >/dev/null 2>&1; then
    log_ok "starship installed"
  else
    warn "starship not installed; continuing without starship binary"
  fi
}

# If either stow or zsh is missing, offer to install both (dry-run respects would/skip)
section "Tools"
ensure_homebrew_runtime
if ! command -v stow >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    would "Install stow and zsh"
  else
    install_tools
    if ! command -v stow >/dev/null 2>&1; then
      err "stow not installed; please install manually"
      exit 1
    fi
    if ! command -v zsh >/dev/null 2>&1; then
      warn "zsh not installed; some features may not work"
    fi
  fi
fi
ensure_starship_runtime
log_ok "tools ready"

# --- Stow packages (repo root only) ---
run_stow_in() { # base_dir
  local base="$1"
  [[ ! -d "$base" ]] && return 0
  shopt -s dotglob nullglob
  local pkgs=()
  for d in "$base"/*; do
    [[ -d "$d" ]] || continue
    case "$(basename "$d")" in
      .git|non_stow|wallpapers|.github|.zencoder|scripts) continue ;;
    esac
    pkgs+=("$(basename "$d")")
  done
  shopt -u dotglob nullglob
  if ((${#pkgs[@]}==0)); then log "No stow packages found at $base. Skipping stow."; return 0; fi
  log "Stowing from $base: ${pkgs[*]}"
  (
    cd "$base"
    for p in "${pkgs[@]}"; do
      # When files already exist in $HOME, stow may fail with conflicts.
      # If STOW_ADOPT=true, we use --adopt to let stow move existing files into the repo tree.
      if [[ "$DRY_RUN" == true ]]; then
        if [[ "$STOW_ADOPT" == true ]]; then
          would "mkdir -p '$BACKUP_DIR' && stow --adopt -R -v 1 -t '$HOME' '$p'"
        else
          would "stow -R -v 1 -t '$HOME' '$p'"
        fi
      else
        if [[ "$STOW_ADOPT" == true ]]; then
          log "Applying stow with --adopt for package: $p"
          # Create a backup of any files that stow might modify by copying from HOME to BACKUP_DIR
          mkdir -p "$BACKUP_DIR"
          # Note: stow --adopt relocates real files into repo; we rely on git status to review changes
          if ! stow --adopt -R -v 1 -t "$HOME" "$p"; then
            warn "Stow --adopt failed for package: $p"
          fi
        else
          if ! stow -R -v 1 -t "$HOME" "$p"; then
            warn "Stow failed for package: $p (consider re-running with STOW_ADOPT=true)"
          fi
        fi
      fi
    done
  )
}
section "Stow"
run_stow_in "$DOTFILES_DIR"

# Install required packages or runtimes for this restore/workflow stage.
install_zsh_plugins() {
  local ZSH_CUSTOM="${DOTFILES_DIR}/zsh/.oh-my-zsh/custom"
  local plugins_dir="$ZSH_CUSTOM/plugins"

  if [[ "$DRY_RUN" == true ]]; then
    would "git clone zsh-autosuggestions to $plugins_dir/zsh-autosuggestions"
    would "git clone zsh-syntax-highlighting to $plugins_dir/zsh-syntax-highlighting"
    return
  fi

  mkdir -p "$plugins_dir"
  if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
    if ! git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"; then
      warn "Failed to clone zsh-autosuggestions into $plugins_dir"
    else
      log "Installed zsh-autosuggestions into $plugins_dir/zsh-autosuggestions"
    fi
  else
    log "zsh-autosuggestions already present in dotfiles"
  fi

  if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
    if ! git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting"; then
      warn "Failed to clone zsh-syntax-highlighting into $plugins_dir"
    else
      log "Installed zsh-syntax-highlighting into $plugins_dir/zsh-syntax-highlighting"
    fi
  else
    log "zsh-syntax-highlighting already present in dotfiles"
  fi
}

install_zsh_plugins

# Return computed metadata or resolved paths needed by later stages.
get_current_login_shell() {
  if command -v getent >/dev/null 2>&1; then
    getent passwd "$USER" | cut -d: -f7
    return 0
  fi
  if command -v dscl >/dev/null 2>&1; then
    dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}'
    return 0
  fi
  printf '%s\n' "${SHELL:-}"
}

# Sync a source tree to destination with rsync first, then cp -a fallback.
sync_tree_with_fallback() { # src dst label
  local src="$1" dst="$2" label="$3"
  if [[ "$DRY_RUN" == true ]]; then
    would "rsync -a '$src/' '$dst/'  # $label"
    would "cp -a '$src/.' '$dst/'    # fallback if rsync missing"
    return 0
  fi
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    if ! rsync -a "$src/" "$dst/"; then
      warn "$label: rsync failed; trying cp -a fallback"
      cp -a "$src/." "$dst/" || warn "$label: cp fallback failed"
    fi
  else
    cp -a "$src/." "$dst/" || warn "$label: cp fallback failed"
  fi
}

if command -v zsh >/dev/null 2>&1; then
  CURRENT_SHELL=$(get_current_login_shell)
  ZSH_PATH=$(command -v zsh)
  if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "chsh -s $ZSH_PATH"
      log "Please log out/in to activate zsh"
    else
      chsh -s "$ZSH_PATH" || warn "chsh failed; you may need to run it manually"
      log "Shell changed to zsh. Log out/login to activate."
    fi
  fi
else
  warn "Zsh is not installed. Skipping plugin installation and shell change."
fi

# NOTE: package restoration from non_stow/packages is intentionally omitted
# from this (production) script. Package installation is potentially destructive
# and requires elevated privileges — keep package lists in non_stow for manual
# review or for an alternate automation script that you control.

# --- Restore developer environments ---
restore_python() {
  local base="$NON_STOW_DIR/dev/python"
  local venv_specs_dir="$base/venvs"
  local req="$base/global-requirements-python3.txt"
  local has_metadata=false

  [[ -f "$req" ]] && has_metadata=true
  if [[ -d "$venv_specs_dir" ]] && compgen -G "$venv_specs_dir/*-requirements.txt" >/dev/null; then
    has_metadata=true
  fi

  # Ensure required runtime/tooling is available; warn/continue when allowed.
  ensure_python_runtime() {
    if command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
      return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
      case "$OS_ID" in
        debian|ubuntu|kali)
          would "sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv"
          ;;
        fedora)
          would "sudo dnf -y install python3 python3-pip"
          ;;
        arch)
          would "sudo pacman -Sy --noconfirm python python-pip"
          ;;
        opensuse)
          would "sudo zypper install -y python3 python3-pip"
          ;;
        mac)
          would "brew install python"
          ;;
        *)
          would "Install python3 + pip manually (unknown OS: $OS_ID)"
          ;;
      esac
      would "python3 -m ensurepip --upgrade  # fallback if pip missing"
      return 0
    fi

    case "$OS_ID" in
      debian|ubuntu|kali)
        sudo apt-get update || warn "apt-get update failed while preparing Python runtime"
        sudo apt-get install -y python3 python3-pip python3-venv || warn "apt install for python3/pip failed"
        ;;
      fedora)
        sudo dnf -y install python3 python3-pip || warn "dnf install for python3/pip failed"
        ;;
      arch)
        sudo pacman -Sy --noconfirm python python-pip || warn "pacman install for python/pip failed"
        ;;
      opensuse)
        sudo zypper install -y python3 python3-pip || warn "zypper install for python3/pip failed"
        ;;
      mac)
        brew install python || warn "brew install python failed"
        ;;
      *)
        warn "Unknown OS; cannot auto-install python3/pip"
        ;;
    esac

    if command -v python3 >/dev/null 2>&1 && ! python3 -m pip --version >/dev/null 2>&1; then
      python3 -m ensurepip --upgrade >/dev/null 2>&1 || warn "ensurepip failed; pip may still be unavailable"
    fi
  }

  if [[ "$has_metadata" == true ]] && { ! command -v python3 >/dev/null 2>&1 || ! python3 -m pip --version >/dev/null 2>&1; }; then
    log "Python metadata found; attempting to auto-install python3/pip"
    ensure_python_runtime || true
  fi

  # Restore global Python packages (user site)
  if [[ -f "$req" ]]; then
    if command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
      if [[ "$DRY_RUN" == true ]]; then
        would "python3 -m pip install --user -r '$req'"
      else
        log "Restoring Python3 user site packages from $req"
        python3 -m pip install --user -r "$req" || warn "Some Python user packages failed"
      fi
    else
      warn "python3/pip not found; cannot restore Python global packages"
    fi
  fi

  # Restore virtualenvs (create if missing)
  if [[ -d "$venv_specs_dir" ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
      warn "python3 not found; cannot restore virtualenvs"
      return 0
    fi
    shopt -s nullglob
    for f in "$venv_specs_dir"/*-requirements.txt; do
      local bn; bn=$(basename "$f")
      local name; name="${bn%-requirements.txt}"
      local venv_path=""
      local roots=("$HOME/.virtualenvs" "$HOME/.venvs" "$HOME/venvs")
      for r in "${roots[@]}"; do
        if [[ -d "$r/$name" ]]; then venv_path="$r/$name"; break; fi
      done
      [[ -n "$venv_path" ]] || venv_path="$HOME/.venvs/$name"

      if [[ "$DRY_RUN" == true ]]; then
        if [[ ! -d "$venv_path" ]]; then would "python3 -m venv '$venv_path'"; fi
        would "'$venv_path/bin/pip' install -r '$f'"
      else
        if [[ ! -d "$venv_path" ]]; then
          log "Creating venv: $venv_path"
          python3 -m venv "$venv_path" || { warn "Failed to create venv $venv_path"; continue; }
        fi
        if [[ -x "$venv_path/bin/pip" ]]; then
          log "Installing venv packages for '$name'"
          "$venv_path/bin/pip" install -r "$f" || warn "Some packages failed for venv '$name'"
        else
          warn "pip not found in $venv_path"
        fi
      fi
    done
    shopt -u nullglob
  fi
}

# Restore saved state/artifacts back onto the current system.
restore_node() {
  local base="$NON_STOW_DIR/dev/node"
  local versions="$base/node-installed-versions.txt"
  local npmlist="$base/npm-global-packages.txt"
  local current_version_file="$base/node-current-version.txt"

  ## nvm installer helper (top-level, safe)
  install_nvm() {
    if command -v nvm >/dev/null 2>&1; then
      log "nvm already installed."
      return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
      would "Install nvm official script (curl required)"
      return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
      warn "curl not found; cannot install nvm automatically. Please install curl or nvm manually."
      return 1
    fi

    log "Installing nvm..."
    if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash; then
      warn "nvm install script failed"
      return 1
    fi
    return 0
  }

  # Source NVM scripts when available so `nvm` commands work in-process.
  source_nvm_if_present() {
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
      . "$NVM_DIR/nvm.sh" 2>/dev/null || true
    fi
    if [ -s "$NVM_DIR/bash_completion" ]; then
      . "$NVM_DIR/bash_completion" 2>/dev/null || true
    fi
  }

  # Install required packages or runtimes for this restore/workflow stage.
  install_node_version() { # version (optional)
    local ver="${1:-}"
    local asdf_ver=""
    [[ -n "$ver" ]] && asdf_ver="${ver#v}"

    if [[ "$DRY_RUN" == true ]]; then
      if command -v nvm >/dev/null 2>&1; then
        if [[ -n "$ver" ]]; then
          would "nvm install $ver"
        else
          would "nvm install --lts"
        fi
      elif command -v fnm >/dev/null 2>&1; then
        if [[ -n "$ver" ]]; then
          would "fnm install $ver"
        else
          would "fnm install --lts"
        fi
      elif command -v asdf >/dev/null 2>&1; then
        if [[ -n "$asdf_ver" ]]; then
          would "asdf plugin add nodejs && asdf install nodejs $asdf_ver"
        else
          would "asdf plugin add nodejs && asdf install nodejs latest"
        fi
      else
        would "Install Node runtime (manager not currently detected; nvm/fnm/asdf)"
      fi
      return 0
    fi

    if command -v nvm >/dev/null 2>&1; then
      if [[ -n "$ver" ]]; then
        nvm install "$ver" || warn "nvm install $ver failed"
      else
        nvm install --lts || warn "nvm install --lts failed"
      fi
    elif command -v fnm >/dev/null 2>&1; then
      if [[ -n "$ver" ]]; then
        fnm install "$ver" || warn "fnm install $ver failed"
      else
        fnm install --lts || warn "fnm install --lts failed"
      fi
    elif command -v asdf >/dev/null 2>&1; then
      asdf plugin add nodejs >/dev/null 2>&1 || true
      if [[ -n "$asdf_ver" ]]; then
        asdf install nodejs "$asdf_ver" || warn "asdf install $asdf_ver failed"
      else
        asdf install nodejs latest || warn "asdf install latest failed"
      fi
    else
      warn "No Node version manager (nvm/fnm/asdf) found to install Node"
      return 1
    fi
    return 0
  }

  # Choose the best Node version to bootstrap from backup metadata.
  pick_bootstrap_version() {
    local ver=""
    if [[ -f "$versions" ]]; then
      while IFS= read -r ver || [[ -n "$ver" ]]; do
        [[ -z "$ver" || "$ver" == \#* ]] && continue
        printf '%s\n' "$ver"
        return 0
      done < "$versions"
    fi
    if [[ -f "$current_version_file" ]]; then
      ver=$(head -n 1 "$current_version_file" 2>/dev/null | tr -d '[:space:]')
      [[ -n "$ver" ]] && { printf '%s\n' "$ver"; return 0; }
    fi
    return 1
  }

  # Ensure required runtime/tooling is available; warn/continue when allowed.
  ensure_node_runtime() {
    local bootstrap_ver=""
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      return 0
    fi

    install_nvm || true
    source_nvm_if_present
    bootstrap_ver="$(pick_bootstrap_version 2>/dev/null || true)"

    if [[ -n "$bootstrap_ver" ]]; then
      log "Node runtime missing; attempting install of $bootstrap_ver"
    else
      log "Node runtime missing; attempting default Node install"
    fi
    install_node_version "$bootstrap_ver" || true
  }

  # Ensure Node/npm exists before restore actions when missing.
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    ensure_node_runtime
  fi

  # Restore Node versions via nvm/fnm/asdf if version inventory exists.
  if [[ -f "$versions" ]]; then
    install_nvm || true
    source_nvm_if_present
    while IFS= read -r ver || [[ -n "$ver" ]]; do
      [[ -z "$ver" || "$ver" == \#* ]] && continue
      install_node_version "$ver" || true
    done < "$versions"
  fi

  # Restore npm global packages
  if [[ -f "$npmlist" && -s "$npmlist" ]]; then
    if ! command -v npm >/dev/null 2>&1; then
      warn "npm missing before global restore; attempting Node runtime bootstrap"
      ensure_node_runtime
    fi
    if command -v npm >/dev/null 2>&1; then
      if [[ "$DRY_RUN" == true ]]; then
        would "xargs -a '$npmlist' -r npm -g install"
      else
        log "Installing npm global packages"
        xargs -a "$npmlist" -r npm -g install || warn "Some npm globals failed"
      fi
    else
      warn "npm not found; cannot restore global packages"
    fi
  fi
}

# Emit "name@version" for top-level dependencies in a package.json.
emit_package_json_dependencies() { # package_json
  local package_json="$1"
  local js_parser
  js_parser='const fs=require("fs"); const p=process.argv[1]; const j=JSON.parse(fs.readFileSync(p,"utf8")); const d=(j&&j.dependencies&&typeof j.dependencies==="object")?j.dependencies:{}; for (const [k,v] of Object.entries(d)) { console.log(`${k}@${v}`); }'
  [[ -f "$package_json" ]] || return 1

  if command -v jq >/dev/null 2>&1; then
    jq -r '.dependencies // {} | to_entries[]? | "\(.key)@\(.value)"' "$package_json" 2>/dev/null && return 0
  fi
  if command -v bun >/dev/null 2>&1; then
    bun -e "$js_parser" "$package_json" 2>/dev/null && return 0
  fi
  if command -v node >/dev/null 2>&1; then
    node -e "$js_parser" "$package_json" 2>/dev/null && return 0
  fi
  return 1
}

# Restore saved state/artifacts back onto the current system.
restore_bun() {
  local base="$NON_STOW_DIR/dev/bun"
  local bun_ver_file="$base/bun-version.txt"
  local bun_pkgs_file="$base/bun-global-packages.txt"
  local bun_pkg_json="$base/package.json"
  local has_metadata=false
  local dep_source="$bun_pkgs_file"
  local dep_tmp=""

  [[ -f "$bun_ver_file" ]] && has_metadata=true
  [[ -f "$bun_pkgs_file" ]] && has_metadata=true
  [[ -f "$bun_pkg_json" ]] && has_metadata=true
  [[ "$has_metadata" == true ]] || return 0

  # Ensure required runtime/tooling is available; warn/continue when allowed.
  ensure_bun_path() {
    local bun_install="${BUN_INSTALL:-$HOME/.bun}"
    export BUN_INSTALL="$bun_install"
    case ":$PATH:" in
      *":$bun_install/bin:"*) ;;
      *) export PATH="$bun_install/bin:$PATH" ;;
    esac
  }

  # Install required packages or runtimes for this restore/workflow stage.
  install_bun_runtime() {
    if command -v bun >/dev/null 2>&1; then
      return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
      would "Install Bun via official installer (curl/wget -> https://bun.sh/install)"
      return 0
    fi

    if command -v curl >/dev/null 2>&1; then
      if ! curl -fsSL https://bun.sh/install | bash; then
        warn "Bun installation via curl failed"
        return 1
      fi
    elif command -v wget >/dev/null 2>&1; then
      if ! wget -qO- https://bun.sh/install | bash; then
        warn "Bun installation via wget failed"
        return 1
      fi
    else
      warn "Neither curl nor wget found; cannot auto-install Bun"
      return 1
    fi
    return 0
  }

  ensure_bun_path
  if ! command -v bun >/dev/null 2>&1; then
    log "Bun metadata found; attempting to auto-install Bun"
    install_bun_runtime || true
    ensure_bun_path
  fi

  if [[ -f "$bun_ver_file" ]] && command -v bun >/dev/null 2>&1; then
    local saved_ver current_ver
    saved_ver=$(head -n 1 "$bun_ver_file" 2>/dev/null | tr -d '[:space:]')
    current_ver=$(bun --version 2>/dev/null | head -n 1 | tr -d '[:space:]')
    if [[ -n "$saved_ver" && -n "$current_ver" && "$saved_ver" != "$current_ver" ]]; then
      warn "Bun version mismatch: backup=$saved_ver current=$current_ver"
    fi
  fi

  if [[ ! -s "$bun_pkgs_file" && -f "$bun_pkg_json" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "Generate Bun global package list from '$bun_pkg_json'"
      dep_source="$bun_pkg_json"
    else
      dep_tmp=$(mktemp) || dep_tmp=""
      if [[ -n "$dep_tmp" ]] && emit_package_json_dependencies "$bun_pkg_json" > "$dep_tmp"; then
        if [[ -s "$dep_tmp" ]]; then
          dep_source="$dep_tmp"
        else
          rm -f "$dep_tmp" 2>/dev/null || true
          dep_tmp=""
        fi
      else
        warn "Failed to parse Bun global dependencies from $bun_pkg_json"
        rm -f "$dep_tmp" 2>/dev/null || true
        dep_tmp=""
      fi
    fi
  fi

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -f "$bun_pkgs_file" ]]; then
      would "Install Bun globals from '$bun_pkgs_file' via bun add -g"
    elif [[ -f "$bun_pkg_json" ]]; then
      would "Install Bun globals by reading top-level dependencies from '$bun_pkg_json'"
    fi
  else
    if ! command -v bun >/dev/null 2>&1; then
      warn "bun not found; cannot restore Bun global packages"
    elif [[ -f "$bun_pkgs_file" || -n "$dep_tmp" ]]; then
      while IFS= read -r spec || [[ -n "$spec" ]]; do
        [[ -z "$spec" || "$spec" == \#* ]] && continue
        log "Installing Bun global package: $spec"
        bun add -g "$spec" || warn "Failed to install Bun global package '$spec'"
      done < "$dep_source"
    fi
  fi

  rm -f "$dep_tmp" 2>/dev/null || true
}

# Restore saved state/artifacts back onto the current system.
restore_rust() {
  local base="$NON_STOW_DIR/dev/rust"
  local rustup_toolchains="$base/rustup-toolchains.txt"
  local rustup_targets="$base/rustup-targets.txt"
  local cargo_crates="$base/cargo-installed-crates.txt"
  local has_metadata=false

  [[ -f "$rustup_toolchains" ]] && has_metadata=true
  [[ -f "$rustup_targets" ]] && has_metadata=true
  [[ -f "$cargo_crates" ]] && has_metadata=true
  [[ "$has_metadata" == true ]] || return 0

  # Ensure required runtime/tooling is available; warn/continue when allowed.
  ensure_cargo_path() {
    case ":$PATH:" in
      *":$HOME/.cargo/bin:"*) ;;
      *) export PATH="$HOME/.cargo/bin:$PATH" ;;
    esac
    if [[ -f "$HOME/.cargo/env" ]]; then
      # shellcheck disable=SC1090
      . "$HOME/.cargo/env" 2>/dev/null || true
    fi
  }

  # Install required packages or runtimes for this restore/workflow stage.
  install_rustup_runtime() {
    if command -v rustup >/dev/null 2>&1; then
      return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
      would "Install rustup via official installer (curl/wget -> https://sh.rustup.rs)"
      would "Source '$HOME/.cargo/env' after install"
      return 0
    fi

    if command -v curl >/dev/null 2>&1; then
      if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path; then
        warn "rustup installation via curl failed"
        return 1
      fi
    elif command -v wget >/dev/null 2>&1; then
      if ! wget -qO- https://sh.rustup.rs | sh -s -- -y --no-modify-path; then
        warn "rustup installation via wget failed"
        return 1
      fi
    else
      warn "Neither curl nor wget found; cannot auto-install rustup"
      return 1
    fi
    return 0
  }

  ensure_cargo_path
  if ! command -v rustup >/dev/null 2>&1; then
    log "Rust metadata found; attempting to auto-install rustup"
    install_rustup_runtime || true
    ensure_cargo_path
  fi

  if [[ -f "$rustup_toolchains" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "Install Rust toolchains from '$rustup_toolchains'"
    elif command -v rustup >/dev/null 2>&1; then
      while IFS= read -r toolchain || [[ -n "$toolchain" ]]; do
        [[ -z "$toolchain" || "$toolchain" == \#* ]] && continue
        log "Installing rustup toolchain: $toolchain"
        rustup toolchain install "$toolchain" || warn "Failed to install rustup toolchain '$toolchain'"
      done < "$rustup_toolchains"
    else
      warn "rustup not found; cannot restore toolchains"
    fi
  fi

  if [[ -f "$rustup_targets" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "Install Rust targets from '$rustup_targets'"
    elif command -v rustup >/dev/null 2>&1; then
      while IFS= read -r target || [[ -n "$target" ]]; do
        [[ -z "$target" || "$target" == \#* ]] && continue
        log "Installing rustup target: $target"
        rustup target add "$target" || warn "Failed to install rustup target '$target'"
      done < "$rustup_targets"
    else
      warn "rustup not found; cannot restore targets"
    fi
  fi

  if [[ -f "$cargo_crates" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "Install cargo crates from '$cargo_crates'"
    else
      ensure_cargo_path
      if command -v cargo >/dev/null 2>&1; then
        while IFS= read -r spec || [[ -n "$spec" ]]; do
          local crate version
          [[ -z "$spec" || "$spec" == \#* ]] && continue
          if [[ "$spec" == *@* ]]; then
            crate="${spec%@*}"
            version="${spec##*@}"
          else
            crate="$spec"
            version=""
          fi
          if [[ -n "$version" ]]; then
            log "Installing cargo crate: $crate@$version"
            cargo install "$crate" --version "$version" || warn "Failed to install cargo crate '$crate@$version'"
          else
            log "Installing cargo crate: $crate"
            cargo install "$crate" || warn "Failed to install cargo crate '$crate'"
          fi
        done < "$cargo_crates"
      else
        warn "cargo not found; cannot restore cargo-installed crates"
      fi
    fi
  fi
}

section "Python"
restore_python
section "Node"
restore_node
section "Bun"
restore_bun
section "Rust"
restore_rust

# --- Restore DE settings from non_stow backups ---
section "Desktop"
# Restore saved state/artifacts back onto the current system.
restore_dconf() { # file label
  local file="$1" label="$2"
  if [[ -f "$file" ]]; then
    if command -v dconf >/dev/null 2>&1; then
      if [[ "$DRY_RUN" == true ]]; then
        would "dconf load / < '$file'  # $label"
      else
        log "Restoring $label settings from $file"
        if ! dconf load / < "$file" 2>/dev/null; then warn "$label: some settings failed to import"; fi
      fi
    else
      warn "$label: dconf not available; cannot restore"
    fi
  fi
}
# Restore saved state/artifacts back onto the current system.
restore_xfce() {
  local src="$NON_STOW_DIR/xfce/.config/xfce4"
  local dst="$HOME/.config/xfce4"
  if [[ -d "$src" ]]; then
    log "Restoring Xfce -> $dst"
    sync_tree_with_fallback "$src" "$dst" "Xfce"
  fi
}
# Restore saved state/artifacts back onto the current system.
restore_kde() {
  local src="$NON_STOW_DIR/kde/plasmoids"
  local dst="$HOME/.local/share/plasma/plasmoids"
  if [[ -d "$src" ]]; then
    log "Restoring KDE plasmoids -> $dst"
    sync_tree_with_fallback "$src" "$dst" "KDE plasmoids"
  fi
}

case "$DE_ID" in
  gnome)    restore_dconf "$NON_STOW_DIR/gnome/gnome-settings.dconf" GNOME ;;
  cinnamon) restore_dconf "$NON_STOW_DIR/cinnamon/cinnamon-settings.dconf" Cinnamon ;;
  mate)     restore_dconf "$NON_STOW_DIR/mate/mate-settings.dconf" MATE ;;
  cosmic)   restore_dconf "$NON_STOW_DIR/cosmic/cosmic-settings.dconf" COSMIC ;;
  xfce)     restore_xfce ;;
  kde)      restore_kde ;;
  *)        : ;;
esac

section "Summary"
log_ok "restore completed"
log "verify your session and restart the desktop environment if needed"
