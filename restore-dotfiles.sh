#!/usr/bin/env bash
# Minimal Dotfiles Restore Script (stow-first workflow)
# - Re-clone to $HOME/.dotfiles
# - Corrected OS detection to avoid concatenated IDs
# - Install GNU Stow, Zsh, nvm, and Oh My Zsh plugins inside dotfiles directory
# - Stow packages and restore environments
# - Supports --dry-run, switches default shell to Zsh if needed

set -euo pipefail
umask 077

NO_EMOJI=${NO_EMOJI:-true}
strip_emojis() { sed -E 's/(✅|🔍|⚠️|❌|🟡|📝|🔧|💾|📦|🖥️|🚀|🌐|🗄️|🔒|🔗|🔄|➡️|🐱|☕|🛠️|📁|🔌|🛡️|🧪|🔎|📊|🧹|🟢|🟠|🔵)//g'; }
echo() {
  local newline=true; local escape=false; local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in -n) newline=false ;; -e) escape=true ;; *) args+=("$1") ;; esac; shift
  done
  local msg="${args[*]}"
  if [[ "$NO_EMOJI" == "true" ]]; then
    msg=$(printf "%s" "$msg" | strip_emojis)
  fi
  if $escape; then
    $newline && builtin echo -e "$msg" || builtin echo -ne "$msg"
  else
    $newline && builtin echo "$msg" || builtin echo -n "$msg"
  fi
}

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/Ajayduddi/dotfiles.git}"
DEFAULT_BRANCH="${BRANCH:-cloud}"
NON_STOW_DIR="$DOTFILES_DIR/non_stow"
DRY_RUN=${DRY_RUN:-false}
STOW_ADOPT=${STOW_ADOPT:-false}
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err() { echo "[ERROR] $*"; }
would() { echo "[WOULD] $*"; }

_detect_os() {
  if command -v dnf5 >/dev/null 2>&1; then echo fedora; return; fi
  if command -v dnf >/dev/null 2>&1; then echo fedora; return; fi
  if command -v apt-get >/dev/null 2>&1; then
    if [[ -r /etc/os-release ]]; then
      . /etc/os-release
      if [[ -n "$ID" ]]; then
        case "$ID" in
          kali) echo kali ;;
          ubuntu) echo ubuntu ;;
          debian) echo debian ;;
          *) echo debian ;;
        esac
        return
      fi
    fi
    echo debian; return
  fi
  if command -v pacman >/dev/null 2>&1; then echo arch; return; fi
  if command -v zypper >/dev/null 2>&1; then echo opensuse; return; fi
  if command -v brew >/dev/null 2>&1; then echo mac; return; fi
  echo unknown
}

OS_ID=$(_detect_os)
OS_ID=${OS_ID//[[:space:]]/}
log "OS: $OS_ID | Dry-run: $DRY_RUN"

if [[ "$DRY_RUN" == true ]]; then
  [[ -d "$DOTFILES_DIR" ]] || would "mkdir -p '$DOTFILES_DIR'"
else
  mkdir -p "$DOTFILES_DIR"
fi

if [[ "$DRY_RUN" == true ]]; then
  would "git clone --branch '$DEFAULT_BRANCH' --depth 1 '$REPO_URL' <tmp_dir>"
  would "Replace $DOTFILES_DIR/.git"
else
  log "Re-cloning dotfiles repo $REPO_URL branch $DEFAULT_BRANCH"
  TMP_CLONE="$(mktemp -d)"
  trap 'rm -rf "$TMP_CLONE"' EXIT INT TERM
  if ! git clone --branch "$DEFAULT_BRANCH" --depth 1 "$REPO_URL" "$TMP_CLONE/repo"; then
    err "Git clone failed"; exit 1
  fi
  rm -rf "$DOTFILES_DIR/.git" 2>/dev/null || true
  mv "$TMP_CLONE/repo/.git" "$DOTFILES_DIR/.git"
  (cd "$DOTFILES_DIR" && git reset --hard HEAD >/dev/null 2>&1 || true)
  log "Repo setup at $DOTFILES_DIR"
fi

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
  if ((${#pkgs[@]} == 0)); then log "No packages to stow." && return; fi
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

install_zsh_plugins() {
  local ZSH_CUSTOM="${DOTFILES_DIR}/zsh/.oh-my-zsh/custom"
  local plugins_dir="$ZSH_CUSTOM/plugins"
  if [[ "$DRY_RUN" == true ]]; then
    would "git clone zsh-autosuggestions to $plugins_dir/zsh-autosuggestions"
    would "git clone zsh-syntax-highlighting to $plugins_dir/zsh-syntax-highlighting"
  else
    mkdir -p "$plugins_dir"
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
      git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions" || warn "Failed to clone zsh-autosuggestions"
    else
      log "zsh-autosuggestions already installed in dotfiles"
    fi
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
      git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting" || warn "Failed to clone zsh-syntax-highlighting"
    else
      log "zsh-syntax-highlighting already installed in dotfiles"
    fi
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
      chsh -s "$ZSH_PATH"
      log "Shell changed to zsh. Log out/login to activate."
    fi
  fi
else
  warn "Zsh is not installed."
fi

install_nvm() {
  if ! command -v nvm >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      would "Install nvm official script"
    else
      log "Installing nvm..."
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    fi
  else
    log "nvm already installed."
  fi
}
install_nvm

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

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
    return
  fi

  log "Installing packages from $list for OS $OS_ID"

  if [[ "$OS_ID" =~ (debian|ubuntu|kali) ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "sudo apt update && sudo apt install packages from $list"
    else
      sudo apt update
      xargs -a "$list" -r sudo apt install -y || warn "Failed installing some packages"
    fi
  else
    log "Package restore logic for OS $OS_ID not implemented; add as needed."
  fi
}
restore_packages

restore_python() {
  local base="$NON_STOW_DIR/dev/python"
  local req="$base/global-requirements-python3.txt"
  if [[ -f "$req" && "$(command -v python3 || true)" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "python3 -m pip install --user -r '$req'"
    else
      python3 -m pip install --user -r "$req" || warn "Python packages installation failed"
    fi
  fi

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
restore_python

restore_node() {
  local base="$NON_STOW_DIR/dev/node"
  local versions="$base/node-installed-versions.txt"
  local npmlist="$base/npm-global-packages.txt"

  install_nvm

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

  if [[ ! -f "$versions" ]]; then
    warn "No Node.js versions list; skipping Node.js install"
    return
  fi

  while IFS= read -r ver || [[ -n "$ver" ]]; do
    [[ -z "$ver" ]] && continue
    if [[ "$DRY_RUN" == true ]]; then
      would "nvm install $ver"
    else
      if command -v nvm >/dev/null 2>&1; then
        nvm install "$ver" || warn "Failed to install node version $ver"
      else
        warn "nvm not found after install; skipping node install for $ver"
      fi
    fi
  done < "$versions"

  if [[ -f "$npmlist" && -s "$npmlist" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      would "npm global install packages from $npmlist"
    else
      if command -v npm >/dev/null 2>&1; then
        xargs -a "$npmlist" -r npm -g install || warn "npm global install failed"
      else
        warn "npm not found; cannot install global packages"
      fi
    fi
  fi
}
restore_node

log "✅ Restore complete. Restart your terminal session to apply all changes."
