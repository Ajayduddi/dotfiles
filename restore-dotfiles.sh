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
  REPO_URL="https://github.com/you/repo.git" BRANCH="linux_stow" bash restore-dotfiles.sh
HELP
    exit 0 ;;
  *) ;;
esac

# --- Logging helpers ---
log()  { echo "\e[1;32m[INFO]\e[0m  $*"; }
warn() { echo "\e[1;33m[WARN]\e[0m  $*"; }
err()  { echo "\e[1;31m[ERROR]\e[0m $*"; }
would() { echo "\e[1;34m[WOULD]\e[0m $*"; }

# Detect OS and DE
_detect_os() {
  if command -v dnf >/dev/null 2>&1; then echo fedora; return; fi
  if command -v apt-get >/dev/null 2>&1; then echo debian; return; fi
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
DE_ID=$(_detect_de)
log "OS: $OS_ID | Desktop: $DE_ID | Dry-run: $DRY_RUN"

# --- Ensure base dir ---
if [[ "$DRY_RUN" == true ]]; then
  [[ -d "$DOTFILES_DIR" ]] || would "mkdir -p '$DOTFILES_DIR'"
else
  mkdir -p "$DOTFILES_DIR"
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

# --- Install GNU Stow ---
install_stow() {
  case "$OS_ID" in
    fedora)   sudo dnf -y install stow || sudo dnf -y groupinstall "Development Tools" && sudo dnf -y install stow ;;
    debian)   sudo apt-get update && sudo apt-get -y install stow ;;
    arch)     sudo pacman -Sy --noconfirm stow ;;
    opensuse) sudo zypper --non-interactive install stow || { sudo zypper refresh && sudo zypper --non-interactive install stow; } ;;
    mac)      brew install stow || true ;;
    *)        warn "Unknown OS. Please install GNU Stow manually and re-run." ;;
  esac
}
if ! command -v stow >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    would "Install GNU Stow for OS '$OS_ID'"
    log "Skipping stow installation in dry-run"
  else
    log "Installing GNU Stow..."; install_stow
    if ! command -v stow >/dev/null 2>&1; then err "GNU Stow not found after install. Abort."; exit 1; fi
  fi
fi
[[ "$DRY_RUN" == true ]] && log "GNU Stow ready (simulated)" || log "GNU Stow ready"

# --- Stow packages (repo root only) ---
run_stow_in() { # base_dir
  local base="$1"
  [[ ! -d "$base" ]] && return 0
  shopt -s dotglob nullglob
  local pkgs=()
  for d in "$base"/*; do
    [[ -d "$d" ]] || continue
    case "$(basename "$d")" in
      .git|non_stow|wallpapers|.github|.zencoder) continue ;;
    esac
    pkgs+=("$(basename "$d")")
  done
  shopt -u dotglob nullglob
  if ((${#pkgs[@]}==0)); then log "No stow packages found at $base. Skipping stow."; return 0; fi
  log "Stowing from $base: ${pkgs[*]}"
  (
    cd "$base"
    for p in "${pkgs[@]}"; do
      if [[ "$DRY_RUN" == true ]]; then
        would "stow -R -v 1 -t '$HOME' '$p'"
      else
        stow -R -v 1 -t "$HOME" "$p" || warn "Stow failed for package: $p"
      fi
    done
  )
}
run_stow_in "$DOTFILES_DIR"

# --- Restore packages from non_stow/packages/<os>-packages.txt ---
restore_packages() {
  local list="$NON_STOW_DIR/packages/${OS_ID}-packages.txt"
  if [[ ! -f "$list" ]]; then
    warn "Package list not found: $list; skipping package restore"
    return 0
  fi
  case "$OS_ID" in
    fedora)
      if [[ "$DRY_RUN" == true ]]; then
        would "xargs -a '$list' -r -n 50 sudo dnf install -y"
      else
        log "Installing packages from $list (dnf)"
        xargs -a "$list" -r -n 50 sudo dnf install -y || warn "Some packages may have failed to install"
      fi
      ;;
    debian)
      if [[ "$DRY_RUN" == true ]]; then
        would "xargs -a '$list' -r -n 50 sudo apt-get install -y"
      else
        log "Installing packages from $list (apt-get)"
        xargs -a "$list" -r -n 50 sudo apt-get install -y || warn "Some packages may have failed to install"
      fi
      ;;
    arch)
      if [[ "$DRY_RUN" == true ]]; then
        would "xargs -a '$list' -r -n 50 sudo pacman -S --needed --noconfirm"
      else
        log "Installing packages from $list (pacman --needed)"
        xargs -a "$list" -r -n 50 sudo pacman -S --needed --noconfirm || warn "Some packages may have failed to install"
      fi
      ;;
    opensuse)
      if [[ "$DRY_RUN" == true ]]; then
        would "xargs -a '$list' -r -n 50 sudo zypper --non-interactive install"
      else
        log "Installing packages from $list (zypper)"
        xargs -a "$list" -r -n 50 sudo zypper --non-interactive install || warn "Some packages may have failed to install"
      fi
      ;;
    mac)
      if [[ "$DRY_RUN" == true ]]; then
        would "xargs -a '$list' -r -n 50 brew install"
      else
        log "Installing packages from $list (brew)"
        xargs -a "$list" -r -n 50 brew install || warn "Some packages may have failed to install"
      fi
      ;;
    *)
      warn "Unknown OS '$OS_ID'; skipping package restore"
      ;;
  esac
}
restore_packages

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