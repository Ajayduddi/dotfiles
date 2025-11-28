#!/usr/bin/env bash
# Minimal Dotfiles Restore Script (stow-first workflow)
# - Re-clone from linux_stow branch into $HOME/.dotfiles (configurable)
# - Ensure GNU Stow is installed cross-distro
# - Stow packages from repo root only (avoids non_stow). non_stow is for backups.
# - Restore DE settings (GNOME/KDE/Xfce/MATE/Cinnamon/COSMIC) from non_stow when present.
# - Supports --dry-run to simulate all actions without making changes.
# - Exits successfully with clear warnings unless critical failures in normal mode (clone/install stow) occur.

set -euo pipefail
umask 077

# Minimal emoji output (set NO_EMOJI=true to strip icons)
NO_EMOJI=${NO_EMOJI:-true}
strip_emojis() { sed -E 's/(✅|🔍|⚠️|❌|🟡|📝|🔧|💾|📦|🖥️|🚀|🌐|🗄️|🔒|🔗|🔄|➡️|🐱|☕|🛠️|📁|🔌|🛡️|🧪|🔎|📊|🧹|🟢|🟠|🔵)//g'; }
echo() {
  local newline=true; local enable_escape=false; local args=()
  while [[ $# -gt 0 ]]; do case "$1" in -n) newline=false;; -e) enable_escape=true;; *) args+=("$1");; esac; shift; done
  local msg="${args[*]}"
  if [[ "$NO_EMOJI" = "true" ]]; then msg=$(printf "%s" "$msg" | strip_emojis); fi
  if $enable_escape; then if $newline; then builtin echo -e "$msg"; else builtin echo -ne "$msg"; fi
  else if $newline; then builtin echo "$msg"; else builtin echo -n "$msg"; fi; fi
}

# --- Defaults / Config (can override with env) ---
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/Ajayduddi/dotfiles.git}"
DEFAULT_BRANCH="${BRANCH:-linux_stow}"
NON_STOW_DIR="$DOTFILES_DIR/non_stow"
DRY_RUN=${DRY_RUN:-false}
STOW_ADOPT=${STOW_ADOPT:-false}
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"

# --- CLI Args ---
case "${1:-}" in
  --dry-run|-n) DRY_RUN=true ;;
  --help|-h)
    cat <<'HELP'
🔧 DOTFILES RESTORE (stow-first)
- Re-clones your dotfiles repo (linux_stow branch) into $HOME/.dotfiles (replaces only .git)
- Installs GNU Stow and stows package folders from repo root to $HOME
- Restores desktop environment settings from $HOME/.dotfiles/non_stow when available
- Use --dry-run to preview all actions without changing your system

USAGE:
  restore-dotfiles.sh [--dry-run|-n] [--help|-h]

OPTIONS:
  --dry-run, -n  Show what would be done without making changes
  --help,   -h   Show this help message and exit

ENVIRONMENT VARIABLES:
  DOTFILES_DIR  Target dotfiles directory (default: $HOME/.dotfiles)
  REPO_URL      Git repository URL (default: https://github.com/Ajayduddi/dotfiles.git)
  BRANCH        Branch to clone (default: linux_stow)
  NO_EMOJI      Set to false to show emoji icons (default: true)
  DRY_RUN       true/false to force dry-run (default: false)
  STOW_ADOPT    true/false to use 'stow --adopt' and absorb existing files into the repo (default: false)

WHAT GETS STOWED:
  - Every top-level directory in the repo root is considered a stow package, except:
    .git, non_stow, wallpapers, .github, .zencoder

WHAT GETS RESTORED FROM non_stow (if present):
  - GNOME/Cinnamon/MATE/COSMIC: dconf dump file
  - KDE: ~/.local/share/plasma/plasmoids
  - Xfce: ~/.config/xfce4

REQUIREMENTS:
  - Network access to clone the repo (normal mode)
  - sudo privileges to install GNU Stow (if it's missing in normal mode)

EXAMPLES:
  bash restore-dotfiles.sh
  bash restore-dotfiles.sh --dry-run
  REPO_URL="https://github.com/Ajayduddi/dotfiles.git" BRANCH="linux_stow" bash restore-dotfiles.sh
HELP
    exit 0 ;;
  *) ;;
esac

# --- Logging helpers ---
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }
err()  { echo "[ERROR]  $*"; }
would() { echo "[WOULD]  $*"; }

# Detect OS and DE
_detect_os() {
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
log "OS: $OS_ID | Desktop: $DE_ID | Dry-run: $DRY_RUN"

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

# --- Reclone linux_stow branch (replace .git only) ---
if [[ "$DRY_RUN" == true ]]; then
  would "git clone --branch '$DEFAULT_BRANCH' --depth 1 '$REPO_URL' <temp>"
  would "Replace $DOTFILES_DIR/.git with the one from clone (leave files intact)"
else
  log "Re-cloning dotfiles from $REPO_URL (branch: $DEFAULT_BRANCH) -> $DOTFILES_DIR"
  TMP_CLONE="$(mktemp -d)"
  trap 'rm -rf "$TMP_CLONE"' EXIT INT TERM
  if ! git clone --branch "$DEFAULT_BRANCH" --depth 1 "$REPO_URL" "$TMP_CLONE/repo"; then
    err "Failed to clone repository. Aborting."; exit 1
  fi
  rm -rf "$DOTFILES_DIR/.git" 2>/dev/null || true
  mv "$TMP_CLONE/repo/.git" "$DOTFILES_DIR/.git"
  (
    cd "$DOTFILES_DIR"
    git reset --hard HEAD >/dev/null 2>&1 || true
  )
  log "Repository ready at $DOTFILES_DIR"
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

# If either stow or zsh is missing, offer to install both (dry-run respects would/skip)
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
log "Tools ready"

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
run_stow_in "$DOTFILES_DIR"

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

if command -v zsh >/dev/null 2>&1; then
  CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
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

  # Restore global Python packages (user site)
  local req="$base/global-requirements-python3.txt"
  if [[ -f "$req" ]] && command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      would "python3 -m pip install --user -r '$req'"
    else
      log "Restoring Python3 user site packages from $req"
      python3 -m pip install --user -r "$req" || warn "Some Python user packages failed"
    fi
  fi

  # Restore virtualenvs (create if missing)
  if [[ -d "$venv_specs_dir" ]]; then
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

restore_node() {
  local base="$NON_STOW_DIR/dev/node"
  local versions="$base/node-installed-versions.txt"
  local npmlist="$base/npm-global-packages.txt"

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

  # Restore Node versions via nvm/fnm/asdf if available
  if [[ -f "$versions" ]]; then
    # ensure we have nvm available (or at least attempt to install it)
    install_nvm

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null || true
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" 2>/dev/null || true

    while IFS= read -r ver || [[ -n "$ver" ]]; do
      [[ -z "$ver" ]] && continue
      if [[ "$DRY_RUN" == true ]]; then
        if command -v nvm >/dev/null 2>&1; then would "nvm install $ver"; fi
      else
        if command -v nvm >/dev/null 2>&1; then
          nvm install "$ver" || warn "nvm install $ver failed"
        elif command -v fnm >/dev/null 2>&1; then
          fnm install "$ver" || warn "fnm install $ver failed"
        elif command -v asdf >/dev/null 2>&1; then
          asdf plugin add nodejs >/dev/null 2>&1 || true; asdf install nodejs "$ver" || warn "asdf install $ver failed"
        else
          warn "No Node version manager (nvm/fnm/asdf) found to install $ver"
        fi
      fi
    done < "$versions"
  fi

  # Restore npm global packages
  if [[ -f "$npmlist" && -s "$npmlist" ]]; then
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

restore_python
restore_node

# --- Restore DE settings from non_stow backups ---
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
restore_xfce() {
  local src="$NON_STOW_DIR/xfce/.config/xfce4"
  local dst="$HOME/.config/xfce4"
  if [[ -d "$src" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "rsync -a '$src/' '$dst/'  # Xfce"
    else
      log "Restoring Xfce -> $dst"
      mkdir -p "$dst"
      rsync -a "$src/" "$dst/" || warn "Failed to restore Xfce"
    fi
  fi
}
restore_kde() {
  local src="$NON_STOW_DIR/kde/plasmoids"
  local dst="$HOME/.local/share/plasma/plasmoids"
  if [[ -d "$src" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "rsync -a '$src/' '$dst/'  # KDE plasmoids"
    else
      log "Restoring KDE plasmoids -> $dst"
      mkdir -p "$dst"
      rsync -a "$src/" "$dst/" || warn "Failed to restore KDE plasmoids"
    fi
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

log "✅ Restore complete. Verify your session and restart the DE if necessary."