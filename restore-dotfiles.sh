#!/usr/bin/env bash
# Minimal Dotfiles Restore Script (stow-first workflow)
# - Re-clone from configurable branch into $HOME/.dotfiles
# - Ensure GNU Stow, Zsh, and nvm are installed cross-distro
# - Stow packages from repo root only (avoids non_stow)
# - Restore package lists and developer environment data from non_stow when present
# - Supports --dry-run to simulate all actions without making changes
# - Changes default shell to Zsh if not already set

set -euo pipefail
umask 077

# --- Emoji Handling ---
NO_EMOJI=${NO_EMOJI:-true}
strip_emojis() { sed -E 's/(✅|🔍|⚠️|❌|🟡|📝|🔧|💾|📦|🖥️|🚀|🌐|🗄️|🔒|🔗|🔄|➡️|🐱|☕|🛠️|📁|🔌|🛡️|🧪|🔎|📊|🧹|🟢|🟠|🔵)//g'; }
echo() {
  local newline=true; local enable_escape=false; local args=()
  while [[ $# -gt 0 ]]; do case "$1" in -n) newline=false;; -e) enable_escape=true;; *) args+=("$1");; esac; shift; done
  local msg="${args[*]}"
  if [[ "$NO_EMOJI" == "true" ]]; then
    msg=$(printf "%s" "$msg" | strip_emojis)
  fi
  if $enable_escape; then
    $newline && builtin echo -e "$msg" || builtin echo -ne "$msg"
  else
    $newline && builtin echo "$msg" || builtin echo -n "$msg"
  fi
}

# --- Default Config ---
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/Ajayduddi/dotfiles.git}"
DEFAULT_BRANCH="${BRANCH:-cloud}"
NON_STOW_DIR="$DOTFILES_DIR/non_stow"
DRY_RUN=${DRY_RUN:-false}
STOW_ADOPT=${STOW_ADOPT:-false}
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"

# --- CLI Args ---
case "${1:-}" in
  --dry-run|-n) DRY_RUN=true ;;
  --help|-h)
    cat <<'HELP'
DOTFILES RESTORE (stow-first)
- Re-clones your dotfiles repo into $HOME/.dotfiles (replace .git only)
- Installs GNU Stow, Zsh, and optionally installs nvm
- Stows package folders
- Restores packages from non_stow
- Sets default shell to Zsh
- Use --dry-run to simulate actions
USAGE:
  restore-dotfiles.sh [--dry-run|-n] [--help|-h]
ENV:
  ... (same as previous)
HELP
    exit 0 ;;
  *) ;;
esac

# --- Logging helpers ---
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }
err()  { echo "[ERROR]  $*"; }
would() { echo "[WOULD]  $*"; }

# --- OS detection ---
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
OS_ID=$(_detect_os)
OS_ID=$(echo "$OS_ID" | tr -d '[:space:]')
log "OS: $OS_ID | Dry-run: $DRY_RUN"

# --- Ensure base dir ---
if [[ "$DRY_RUN" == true ]]; then
  [[ -d "$DOTFILES_DIR" ]] || would "mkdir -p '$DOTFILES_DIR'"
else
  mkdir -p "$DOTFILES_DIR"
fi

# --- Clone or Update repo ---
if [[ "$DRY_RUN" == true ]]; then
  would "git clone --branch '$DEFAULT_BRANCH' --depth 1 '$REPO_URL' <temp>"
  would "Replace $DOTFILES_DIR/.git with cloned one (leave files)"
else
  log "Re-cloning dotfiles from $REPO_URL (branch: $DEFAULT_BRANCH)"
  TMP_CLONE="$(mktemp -d)"
  trap 'rm -rf "$TMP_CLONE"' EXIT INT TERM
  if ! git clone --branch "$DEFAULT_BRANCH" --depth 1 "$REPO_URL" "$TMP_CLONE/repo"; then
    err "Failed to clone repository"; exit 1
  fi
  rm -rf "$DOTFILES_DIR/.git" 2>/dev/null || true
  mv "$TMP_CLONE/repo/.git" "$DOTFILES_DIR/.git"
  (cd "$DOTFILES_DIR" && git reset --hard HEAD >/dev/null 2>&1 || true)
  log "Repo setup at $DOTFILES_DIR"
fi

# --- Install GNU Stow, Zsh ---
install_tools() {
  log "Installing tools for OS: $OS_ID"
  case "$OS_ID" in
    fedora) sudo dnf -y install stow zsh ;;
    debian|ubuntu|kali) sudo apt update && sudo apt -y install stow zsh ;;
    arch) sudo pacman -Sy --noconfirm stow zsh ;;
    opensuse) sudo zypper --non-interactive install stow zsh ;;
    mac) brew install stow zsh || true ;;
    *) warn "Unknown OS: install stow, zsh manually" ;;
  esac
}
if ! command -v stow >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    would "Install GNU Stow and Zsh for OS: $OS_ID"
  else
    install_tools
    if ! command -v stow >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
      err "Failed to install stow or zsh"
      exit 1
    fi
  fi
fi
log "Tools ready"

# --- Change default shell to zsh if needed ---
if command -v zsh >/dev/null 2>&1; then
  CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
  ZSH_PATH=$(command -v zsh)
  if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "chsh -s $ZSH_PATH"
      log "Log out and log back in after shell change."
    else
      chsh -s "$ZSH_PATH"
      log "Shell changed to zsh. Log out/login to activate."
    fi
  fi
else
  warn "Zsh is not installed."
fi

# --- Install latest nvm (Node Version Manager) if missing ---
install_nvm() {
  if ! command -v nvm >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      would "Install latest nvm by official script https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh"
    else
      log "Installing latest nvm..."
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
      log "Latest nvm installed."
    fi
  else
    log "nvm already installed."
  fi
}
install_nvm

# --- Stow top-level packages ---
run_stow_in() {
  local base="$1"
  [[ ! -d "$base" ]] && return
  shopt -s dotglob nullglob
  local pkgs=()
  for d in "$base"/*; do
    [[ -d "$d" ]] || continue
    case "$(basename "$d")" in
      .git|non_stow|.github|.zencoder|infra-backup|scripts) continue ;;
    esac
    pkgs+=("$(basename "$d")")
  done
  shopt -u dotglob nullglob
  if ((${#pkgs[@]}==0)); then log "No packages to stow." && return; fi
  log "Stowing from $base: ${pkgs[*]}"
  (
    cd "$base"
    for p in "${pkgs[@]}"; do
      if [[ "$DRY_RUN" == true ]]; then
        if [[ "$STOW_ADOPT" == true ]]; then
          would "stow --adopt -R -v 1 -t '$HOME' '$p'"
        else
          would "stow -R -v 1 -t '$HOME' '$p'"
        fi
      else
        if [[ "$STOW_ADOPT" == true ]]; then
          mkdir -p "$BACKUP_DIR"
          log "Stowing with --adopt: $p"
          stow --adopt -R -v 1 -t "$HOME" "$p" || warn "stow --adopt failed for $p"
        else
          stow -R -v 1 -t "$HOME" "$p" || warn "stow failed for $p"
        fi
      fi
    done
  )
}
run_stow_in "$DOTFILES_DIR"

# --- Restore packages from non_stow ---
restore_packages() {
  local specific="$NON_STOW_DIR/packages/${OS_ID}-packages.txt"
  local universal="$NON_STOW_DIR/packages/universal-packages.txt"
  local list=""

  if [[ -f "$specific" && -s "$specific" ]]; then
    list="$specific"
  elif [[ -f "$universal" && -s "$universal" ]]; then
    warn "Falling back to universal package list."
    list="$universal"
  else
    warn "No package lists found; skipping package restore"
    return 0
  fi

  log "Installing packages from $list for OS $OS_ID"

  case "$OS_ID" in
    fedora)
      local DNF_BIN="dnf"
      command -v dnf5 >/dev/null 2>&1 && DNF_BIN="dnf5"
      if [[ "$DRY_RUN" == true ]]; then
        would "sudo $DNF_BIN -y makecache"
        would "sudo $DNF_BIN install packages from $list"
      else
        sudo "$DNF_BIN" -y makecache
        awk 'NF && $0 !~ /^#/' "$list" | while read -r pkg; do
          sudo "$DNF_BIN" info -q "$pkg" >/dev/null 2>&1 && printf '%s\n' "$pkg"
        done | xargs -r -n 50 sudo "$DNF_BIN" install -y || warn "Some Fedora packages failed"
      fi
      ;;
    debian|ubuntu|kali)
      if [[ "$DRY_RUN" == true ]]; then
        would "sudo apt update"
        would "sudo apt install packages from $list"
      else
        sudo apt update
        awk 'NF && $0 !~ /^#/' "$list" | while read -r pkg; do
          apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -vq '(none)' && printf '%s\n' "$pkg"
        done | xargs -r -n 50 sudo apt install -y || warn "Some APT packages failed"
      fi
      ;;
    arch)
      if [[ "$DRY_RUN" == true ]]; then
        would "sudo pacman -S --needed --noconfirm packages from $list"
      else
        xargs -a "$list" -r -n 50 sudo pacman -S --needed --noconfirm || warn "Some Pacman packages failed"
      fi
      ;;
    opensuse)
      if [[ "$DRY_RUN" == true ]]; then
        would "sudo zypper --non-interactive install packages from $list"
      else
        xargs -a "$list" -r -n 50 sudo zypper --non-interactive install || warn "Some Zypper packages failed"
      fi
      ;;
    mac)
      if [[ "$DRY_RUN" == true ]]; then
        would "brew install packages from $list"
      else
        xargs -a "$list" -r -n 50 brew install || warn "Some brew packages failed"
      fi
      ;;
    *)
      warn "Unknown OS '$OS_ID'; skipping package restore"
      ;;
  esac
}
restore_packages

# --- Restore Python environment ---
restore_python() {
  local base="$NON_STOW_DIR/dev/python"
  local req="$base/global-requirements-python3.txt"
  if [[ -f "$req" && "$(command -v python3 || true)" && python3 -m pip --version >/dev/null 2>&1 ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "python3 -m pip install --user -r '$req'"
    else
      log "Restoring Python packages"
      python3 -m pip install --user -r "$req" || warn "Python packages installation failed"
    fi
  fi

  # Virtualenvs
  local venvs="$base/venvs"
  if [[ -d "$venvs" ]]; then
    shopt -s nullglob
    for f in "$venvs"/*-requirements.txt; do
      local bn=$(basename "$f")
      local name="${bn%-requirements.txt}"
      local venv_path=""
      for r in "$HOME/.virtualenvs" "$HOME/.venvs" "$HOME/venvs"; do
        [[ -d "$r/$name" ]] && { venv_path="$r/$name"; break; }
      done
      [[ -n "$venv_path" ]] || venv_path="$HOME/.venvs/$name"

      if [[ "$DRY_RUN" == true ]]; then
        [[ ! -d "$venv_path" ]] && would "python3 -m venv '$venv_path'"
        would "'$venv_path/bin/pip' install -r '$f'"
      else
        [[ ! -d "$venv_path" ]] && {
          log "Creating venv: $venv_path"
          python3 -m venv "$venv_path" || { warn "Failed to create venv"; continue; }
        }
        if [[ -x "$venv_path/bin/pip" ]]; then
          log "Installing packages for venv: $name"
          "$venv_path/bin/pip" install -r "$f" || warn "Failed virtual env install"
        fi
      fi
    done
    shopt -u nullglob
  fi
}

# --- Restore Node.js environment ---
restore_node() {
  local base="$NON_STOW_DIR/dev/node"
  local versions="$base/node-installed-versions.txt"
  local npmlist="$base/npm-global-packages.txt"

  # Load/install nvm
  install_nvm

  # Install node versions
  if [[ -f "$versions" ]]; then
    while IFS= read -r ver || [[ -n "$ver" ]]; do
      [[ -n "$ver" ]] || continue
      if [[ "$DRY_RUN" == true ]]; then
        command -v nvm >/dev/null 2>&1 && would "nvm install '$ver'"
        command -v fnm >/dev/null 2>&1 && would "fnm install '$ver'"
        command -v asdf >/dev/null 2>&1 && would "asdf plugin add nodejs && asdf install nodejs '$ver'"
      else
        if command -v nvm >/dev/null 2>&1; then
          nvm install "$ver" || warn "nvm install $ver failed"
        elif command -v fnm >/dev/null 2>&1; then
          fnm install "$ver" || warn "fnm install $ver failed"
        elif command -v asdf >/dev/null 2>&1; then
          asdf plugin add nodejs >/dev/null 2>&1 || true
          asdf install nodejs "$ver" || warn "asdf install $ver failed"
        else
          warn "No node version manager found to install $ver"
        fi
      fi
    done < "$versions"
  fi

  # Install npm global packages
  if [[ -f "$npmlist" && -s "$npmlist" && "$(command -v npm || true)" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "xargs -a '$npmlist' -r npm -g install"
    else
      log "Installing npm global packages"
      xargs -a "$npmlist" -r npm -g install || warn "npm global install failed"
    fi
  elif [[ "$(command -v npm || true)" == "" ]]; then
    warn "npm not found; cannot restore global packages"
  fi
}

# Run restores
restore_python
restore_node

log "✅ Restore complete. Verify your session and applications."
