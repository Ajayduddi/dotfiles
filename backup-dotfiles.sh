#!/usr/bin/env bash
# Minimal Dotfiles Backup Script (DE + packages only)
# Cross-distro, safe defaults. Creates backups into $HOME/.dotfiles/non_stow
# Supports DEs: GNOME, KDE, Xfce, MATE, Cinnamon, COSMIC. Skips gracefully if tools/paths missing.
# Supports --dry-run to simulate all actions without making changes.

set -euo pipefail

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

# --- Args / Help ---
DRY_RUN=${DRY_RUN:-false}
case "${1:-}" in
  --dry-run|-n) DRY_RUN=true; shift || true; echo "🔍 DRY RUN MODE" ;;
  --help|-h)
    cat <<'USAGE'
🔧 DOTFILES BACKUP (Simplified)
- Backs up: desktop environment settings (GNOME/KDE/Xfce/MATE/Cinnamon/COSMIC) and package list
- Writes into: $HOME/.dotfiles/non_stow
- Use --dry-run to preview all actions without changing your system

USAGE:
  backup-dotfiles.sh [--dry-run|-n] [--help|-h]

OPTIONS:
  --dry-run, -n  Show what would be done without making changes
  --help,   -h   Show this help message and exit

ENVIRONMENT VARIABLES:
  DOTFILES_DIR  Target dotfiles directory (default: $HOME/.dotfiles)
  NO_EMOJI      Set to false to show emoji icons (default: true)
  DRY_RUN       true/false to force dry-run (default: false)

EXAMPLES:
  bash backup-dotfiles.sh
  bash backup-dotfiles.sh --dry-run
USAGE
    exit 0
    ;;
  *) ;;
esac

# --- Paths ---
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
NON_STOW_DIR="$DOTFILES_DIR/non_stow"

if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "❌ '$DOTFILES_DIR' not found. Create it first (git clone or mkdir)."
  exit 1
fi

mkdir_p() {
  if [[ "$DRY_RUN" == true ]]; then echo "🔍 WOULD mkdir -p $1"; else mkdir -p "$1"; fi
}

copy_tree() { # src dest
  local src="$1" dest="$2"
  if [[ "$DRY_RUN" == true ]]; then echo "🔍 WOULD copy $src -> $dest"; return 0; fi
  rsync -a --delete --chmod=Du=rwx,Dg=rx,Do= --chmod=Fu=rw,Fg=r,Fo= \
    --exclude='*.pem' --exclude='*.key' --exclude='*.p12' \
    --exclude='*Login Data*' --exclude='*Cookies*' --exclude='*Web Data*' \
    --exclude='*History*' --exclude='*Bookmarks*' \
    "$src/" "$dest/" 2>/dev/null || true
}

# --- Detect OS / package manager ---
detect_os() {
  if command -v rpm >/dev/null 2>&1; then
    if command -v dnf >/dev/null 2>&1; then echo fedora; return; fi
    if command -v zypper >/dev/null 2>&1; then echo opensuse; return; fi
    echo rpm
  elif command -v apt-get >/dev/null 2>&1; then echo debian
  elif command -v pacman >/dev/null 2>&1; then echo arch
  elif command -v brew >/dev/null 2>&1; then echo mac
  else echo unknown
  fi
}

# --- Detect Desktop Environment ---
detect_de() {
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

OS_ID=$(detect_os)
DE_ID=$(detect_de)
echo "🖥️ Desktop: $DE_ID  |  🐧 OS: $OS_ID  |  Dry-run: $DRY_RUN"

mkdir_p "$NON_STOW_DIR"
mkdir_p "$NON_STOW_DIR/packages"

# --- Export package list (user-installed only when possible) ---
export_packages() {
  local outfile="$NON_STOW_DIR/packages/${OS_ID}-packages.txt"
  case "$OS_ID" in
    fedora)
      # Prefer dnf repoquery (userinstalled); enforce newline per item; fallback to rpm -qa
      cmd="(dnf repoquery --userinstalled --qf '%{name}\n' || repoquery --userinstalled -q --qf '%{name}\n' || rpm -qa --qf '%{NAME}\n') | sort -u > '$outfile'"
      ;;
    rpm)
      if command -v dnf >/dev/null 2>&1; then
        cmd="(dnf repoquery --userinstalled --qf '%{name}\n' || repoquery --userinstalled -q --qf '%{name}\n' || rpm -qa --qf '%{NAME}\n') | sort -u > '$outfile'"
      elif command -v zypper >/dev/null 2>&1; then
        # zypper marks explicit installs with i+
        cmd="zypper search -i --type package --details | awk -F'|' '/^i\\+/{gsub(/^ +| +$/,\"\",$2); print $2}' | sort -u > '$outfile'"
      else
        cmd="rpm -qa --qf '%{NAME}\n' | sort -u > '$outfile'"
      fi
      ;;
    opensuse)
      cmd="zypper search -i --type package --details | awk -F'|' '/^i\\+/{gsub(/^ +| +$/,\"\",$2); print $2}' | sort -u > '$outfile'"
      ;;
    debian)
      # Manual (user-requested) packages intersected with currently installed
      cmd="comm -12 <(apt-mark showmanual | sort -u) <(dpkg-query -W -f='\${binary:Package}\n' | sort -u) > '$outfile'"
      ;;
    arch)
      # Explicitly installed (includes both native and AUR)
      cmd="pacman -Qqe | sort -u > '$outfile'"
      ;;
    mac)
      # Prefer leaves (top-level), fallback to full list
      if brew help leaves >/dev/null 2>&1; then
        cmd="brew leaves > '$outfile'"
      else
        cmd="brew list --formula > '$outfile'"
      fi
      ;;
    *)
      echo "🟡 Unknown OS. Skipping package export."; return 0
      ;;
  esac
  if [[ "$DRY_RUN" == true ]]; then echo "🔍 WOULD: $cmd"; else bash -lc "$cmd" || true; echo "💾 Saved packages -> $outfile"; fi
}

# --- dconf generic backup helper ---
backup_dconf() { # out_file
  local out_file="$1"
  if ! command -v dconf >/dev/null 2>&1; then echo "🟡 dconf not found, skipping"; return 0; fi
  mkdir_p "$(dirname "$out_file")"
  if [[ "$DRY_RUN" == true ]]; then echo "🔍 WOULD: dconf dump / > '$out_file'"; else dconf dump / > "$out_file" 2>/dev/null || true; echo "💾 dconf -> $out_file"; fi
}

# --- Backup per DE ---
backup_gnome()   { backup_dconf "$NON_STOW_DIR/gnome/gnome-settings.dconf"; }
backup_cinnamon(){ backup_dconf "$NON_STOW_DIR/cinnamon/cinnamon-settings.dconf"; }
backup_mate()    { backup_dconf "$NON_STOW_DIR/mate/mate-settings.dconf"; }
backup_cosmic()  { backup_dconf "$NON_STOW_DIR/cosmic/cosmic-settings.dconf"; }
backup_xfce() {
  local src="$HOME/.config/xfce4"
  local outdir="$NON_STOW_DIR/xfce/.config/xfce4"
  if [[ ! -d "$src" ]]; then echo "🟡 Xfce config not found, skipping"; return 0; fi
  mkdir_p "$outdir"
  copy_tree "$src" "$outdir"
  echo "💾 Xfce -> $outdir"
}
backup_kde() {
  local src="$HOME/.local/share/plasma/plasmoids"
  local outdir="$NON_STOW_DIR/kde/plasmoids"
  if [[ ! -d "$src" ]]; then echo "🟡 KDE plasmoids not found, skipping"; return 0; fi
  mkdir_p "$NON_STOW_DIR/kde"
  mkdir_p "$outdir"
  copy_tree "$src" "$outdir"
  echo "💾 KDE plasmoids -> $outdir"
}

# --- Run tasks ---
export_packages
case "$DE_ID" in
  gnome)    backup_gnome ;;
  cinnamon) backup_cinnamon ;;
  mate)     backup_mate ;;
  cosmic)   backup_cosmic ;;
  xfce)     backup_xfce ;;
  kde)      backup_kde ;;
  *)        echo "🟡 Desktop '$DE_ID' not specifically supported for backup. Skipping." ;;
esac

echo "✅ Backup complete (minimal). Files saved under: $NON_STOW_DIR"