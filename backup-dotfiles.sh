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
  if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 WOULD copy $src -> $dest"
    return 0
  fi

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --chmod=Du=rwx,Dg=rx,Do= --chmod=Fu=rw,Fg=r,Fo=       --exclude='*.pem' --exclude='*.key' --exclude='*.p12'       --exclude='*Login Data*' --exclude='*Cookies*' --exclude='*Web Data*'       --exclude='*History*' --exclude='*Bookmarks*'       "$src/" "$dest/" 2>/dev/null || true
  else
    mkdir -p "$dest"
    cp -a "$src/" "$dest/" 2>/dev/null || true
  fi
}

copy_file() {
  local src="$1" dest="$2"
  if [[ ! -e "$src" ]]; then echo "🟡 Source '$src' not found, skipping"; return 0; fi
  mkdir_p "$(dirname "$dest")"
  if [[ "$DRY_RUN" == true ]]; then echo "🔍 WOULD copy $src -> $dest"; else cp -f "$src" "$dest" 2>/dev/null || true; echo "💾 Copied $src -> $dest"; fi
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
# Trim whitespace from OS_ID (some environments add unexpected spaces)
OS_ID=${OS_ID//[[:space:]]/}
DE_ID=$(detect_de)
echo "🖥️ Desktop: $DE_ID  |  🐧 OS: $OS_ID  |  Dry-run: $DRY_RUN"

mkdir_p "$NON_STOW_DIR"
mkdir_p "$NON_STOW_DIR/packages"

# --- Export package list (user-installed only when possible) ---
export_packages() {
  local outfile="$NON_STOW_DIR/packages/${OS_ID}-packages.txt"
  local universal="$NON_STOW_DIR/packages/universal-packages.txt"
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
  if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 WOULD: $cmd"
    echo "🔍 WOULD: ensure template excludes at '$NON_STOW_DIR/packages/universal-excludes.txt' if missing"
    echo "🔍 WOULD: build filtered candidate at '$NON_STOW_DIR/packages/.generated/universal-candidate.txt' (union with existing universal, unique + sorted)"
  else
    bash -lc "$cmd" || true
    echo "💾 Saved packages -> $outfile"

    # Prepare paths
    local excludes="$NON_STOW_DIR/packages/universal-excludes.txt"
    local canddir="$NON_STOW_DIR/packages/.generated"
    local candidate="$canddir/universal-candidate.txt"
    mkdir -p "$canddir"

    # Create excludes template if missing (one-time)
    if [[ ! -f "$excludes" ]]; then
      cat > "$excludes" <<'EXCL'
# Regex patterns (one per line) to EXCLUDE from universal candidates
# Tweak to your preference. Examples below aim to drop OS/base/system bits.
^(kernel|grub2|systemd|glibc|linux-firmware|microcode_ctl|dracut.*|anaconda.*)$
^(NetworkManager(.*)?|firewalld|selinux-.*)$
^(filesystem|setup|shadow-utils)$
^(dnf5?|rpm|rpmfusion-.*-release|fedora-.*)$
^(mesa-.*|xorg-.*)$
^(gnome-.*|kde-.*|plasma-.*)$
^(cups.*|plymouth.*)$
.*firmware$
# Add more lines to exclude additional packages
EXCL
      echo "📝 Created universal excludes template -> $excludes"
    fi

    # Build candidate: start with filtered current OS list
    local tmp1
    tmp1=$(mktemp)
    if [[ -s "$outfile" ]]; then
      if [[ -s "$excludes" ]]; then
        grep -Ev -f "$excludes" "$outfile" | sort -u > "$tmp1" || true
      else
        sort -u "$outfile" > "$tmp1"
      fi
    fi

    # Union with existing curated universal (if any), without overwriting it
    if [[ -f "$universal" && -s "$universal" ]]; then
      sort -u "$tmp1" "$universal" > "$candidate"
    else
      mv "$tmp1" "$candidate"
    fi
    rm -f "$tmp1" 2>/dev/null || true

    echo "💾 Generated candidate universal list -> $candidate"
    echo "➡️  Review and promote if OK: cp -f '$candidate' '$universal'"
  fi
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
  local plasmoids_src="$HOME/.local/share/plasma/plasmoids"
  local plasmoids_out="$NON_STOW_DIR/kde/plasmoids"
  mkdir_p "$NON_STOW_DIR/kde"
  if [[ -d "$plasmoids_src" ]]; then
    mkdir_p "$plasmoids_out"
    copy_tree "$plasmoids_src" "$plasmoids_out"
    echo "💾 KDE plasmoids -> $plasmoids_out"
  else
    echo "🟡 KDE plasmoids not found, skipping"
  fi
  copy_file "$HOME/.config/kglobalshortcutsrc" "$NON_STOW_DIR/kde/config/kglobalshortcutsrc"
  copy_file "$HOME/.config/khotkeysrc" "$NON_STOW_DIR/kde/config/khotkeysrc"
}

# --- Dev backups: Python ---
backup_python() {
  local base="$NON_STOW_DIR/dev/python"
  local venv_out="$base/venvs"
  mkdir_p "$base" && mkdir_p "$venv_out"

  # Global Python3 site-packages
  if command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
    local req="$base/global-requirements-python3.txt"
    if [[ "$DRY_RUN" == true ]]; then
      echo "🔍 WOULD: python3 -m pip freeze > '$req'"
    else
      python3 -m pip freeze > "$req" 2>/dev/null || true
      echo "💾 Python3 global requirements -> $req"
    fi
  else
    echo "🟡 python3/pip not found; skipping global Python backup"
  fi

  # pyenv versions list
  if command -v pyenv >/dev/null 2>&1; then
    local pe="$base/pyenv-versions.txt"
    if [[ "$DRY_RUN" == true ]]; then
      echo "🔍 WOULD: pyenv versions --bare > '$pe'"
    else
      pyenv versions --bare > "$pe" 2>/dev/null || true
      echo "💾 pyenv versions -> $pe"
    fi
  fi

  # Common virtualenv locations
  local roots=("$HOME/.virtualenvs" "$HOME/.venvs" "$HOME/venvs")
  for r in "${roots[@]}"; do
    [[ -d "$r" ]] || continue
    shopt -s nullglob
    for vdir in "$r"/*; do
      [[ -d "$vdir" && -x "$vdir/bin/pip" ]] || continue
      local name
      name=$(basename "$vdir")
      local out="$venv_out/${name}-requirements.txt"
      if [[ "$DRY_RUN" == true ]]; then
        echo "🔍 WOULD: '$vdir/bin/pip' freeze > '$out'"
      else
        "$vdir/bin/pip" freeze > "$out" 2>/dev/null || true
        echo "💾 Venv '$name' requirements -> $out"
      fi
    done
    shopt -u nullglob
  done

  # Single-project venvs at $HOME (common names)
  for single in "$HOME/.venv" "$HOME/venv"; do
    if [[ -d "$single" && -x "$single/bin/pip" ]]; then
      local out="$venv_out/$(basename "$single")-requirements.txt"
      if [[ "$DRY_RUN" == true ]]; then
        echo "🔍 WOULD: '$single/bin/pip' freeze > '$out'"
      else
        "$single/bin/pip" freeze > "$out" 2>/dev/null || true
        echo "💾 Venv '$(basename "$single")' requirements -> $out"
      fi
    fi
  done
}

# --- Dev backups: Node/NPM ---
backup_node() {
  local base="$NON_STOW_DIR/dev/node"
  mkdir_p "$base"

  # Node current version
  if command -v node >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "🔍 WOULD: node -v > '$base/node-current-version.txt'"
    else
      node -v > "$base/node-current-version.txt" 2>/dev/null || true
      echo "💾 Node current version -> $base/node-current-version.txt"
    fi
  fi

  # Installed Node versions from common managers
  local versions_file="$base/node-installed-versions.txt"
  if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 WOULD: detect nvm/fnm/asdf installed node versions -> '$versions_file'"
  else
    : > "$versions_file"
    # nvm directory listing
    if [[ -d "$HOME/.nvm/versions/node" ]]; then
      find "$HOME/.nvm/versions/node" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | sort -u >> "$versions_file" || true
    fi
    # fnm directory listing
    if [[ -d "$HOME/.fnm/node-versions" ]]; then
      find "$HOME/.fnm/node-versions" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | sort -u >> "$versions_file" || true
    fi
    # asdf directory listing
    if [[ -d "$HOME/.asdf/installs/nodejs" ]]; then
      find "$HOME/.asdf/installs/nodejs" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | sort -u >> "$versions_file" || true
    fi
    sed -i '/^$/d' "$versions_file" 2>/dev/null || true
    [[ -s "$versions_file" ]] && echo "💾 Node installed versions -> $versions_file" || rm -f "$versions_file" 2>/dev/null || true
  fi

  # Global npm packages
  if command -v npm >/dev/null 2>&1; then
    local npmlist="$base/npm-global-packages.txt"
    if [[ "$DRY_RUN" == true ]]; then
      echo "🔍 WOULD: npm -g ls --depth=0 --parseable | tail -n +2 | xargs -n1 basename | sort -u > '$npmlist'"
    else
      npm -g ls --depth=0 --parseable=true 2>/dev/null | tail -n +2 | xargs -n1 basename | sort -u > "$npmlist" || true
      echo "💾 npm global packages -> $npmlist"
    fi
  else
    echo "🟡 npm not found; skipping npm global packages backup"
  fi
}

# --- Run tasks ---
export_packages
backup_python
backup_node
case "$DE_ID" in
  gnome)    backup_gnome ;;
  cinnamon) backup_cinnamon ;;
  mate)     backup_mate ;;
  cosmic)   backup_cosmic ;;
  xfce)     backup_xfce ;;
  kde)      backup_kde ;;
  *)        echo "🟡 Desktop '$DE_ID' not specifically supported for backup. Skipping." ;;
esac

echo "✅ Backup complete. Files saved under: $NON_STOW_DIR"