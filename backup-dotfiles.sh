#!/usr/bin/env bash
# Dotfiles backup script for package lists, desktop settings, and dev environment metadata.
# Primary stages: detect OS/DE, export packages, back up Python/Node/Bun/Rust, back up desktop config.
# Safety model: supports --dry-run and keeps compatibility-first behavior with warning-only soft failures.

set -euo pipefail
SOFT_WARNINGS=0

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

# Render a shorter path form for readable logs (~ and repo-relative paths).
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

# Emit a structured log line for this severity level.
log_info()  { echo "[INFO] $(format_message "$*")"; }
# Emit a structured log line for this severity level.
log_ok()    { echo "[OK] $(format_message "$*")"; }
# Emit a structured log line for this severity level.
log_warn()  { echo "[WARN] $(format_message "$*")"; }
# Emit a structured log line for this severity level.
log_error() { echo "[ERROR] $(format_message "$*")"; }
# Emit a structured log line for this severity level.
log_dry()   { echo "[DRY] $(format_message "$*")"; }
# Print a section header to group output by execution stage.
section()   { echo "[INFO] ===== $* ====="; }

# Record a non-fatal warning and keep execution in compatibility mode.
soft_warn() {
  SOFT_WARNINGS=$((SOFT_WARNINGS + 1))
  log_warn "$*"
}

# Remove blank lines from a file with GNU/BSD sed fallback behavior.
portable_delete_blank_lines() { # file
  local file="$1"
  local tmp
  if sed --version >/dev/null 2>&1; then
    sed -i '/^$/d' "$file" 2>/dev/null && return 0
  fi
  sed -i '' '/^$/d' "$file" 2>/dev/null && return 0
  tmp=$(mktemp) || return 1
  if awk 'NF' "$file" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$file"
    return 0
  fi
  rm -f "$tmp" 2>/dev/null || true
  return 1
}

# --- Args / Help ---
DRY_RUN=${DRY_RUN:-false}
case "${1:-}" in
  --dry-run|-n) DRY_RUN=true; shift || true; log_dry "mode: enabled" ;;
  --help|-h)
    cat <<'USAGE'
🔧 DOTFILES BACKUP
Create a reproducible user backup under: $HOME/.dotfiles/non_stow

WHAT THIS BACKS UP:
  - Package inventory:
      non_stow/packages/<os>-packages.txt
      non_stow/packages/.generated/universal-candidate.txt
  - Desktop settings:
      GNOME/Cinnamon/MATE/COSMIC via dconf dump
      KDE plasmoids + selected KDE config files
      Xfce config tree
  - Developer environments:
      Python (global + venv requirements, pyenv versions)
      Node (current version, installed versions, global npm packages)
      Bun (version, global package.json/bun.lock, derived globals list)
      Rust (rustup/rustc/cargo versions, toolchains, targets, cargo installs)

BEHAVIOR:
  - Missing tools/paths are skipped with warnings.
  - Script stays permissive and finishes with a soft-warning summary.
  - Use --dry-run to preview without writing files.

USAGE:
  backup-dotfiles.sh [--dry-run|-n] [--help|-h]

OPTIONS:
  --dry-run, -n  Show what would be done without making changes
  --help,   -h   Show this help message and exit

ENVIRONMENT VARIABLES:
  DOTFILES_DIR  Target dotfiles directory (default: $HOME/.dotfiles)
  NO_EMOJI      true/false (true = hide emoji icons, default: true)
  DRY_RUN       true/false to force dry-run (default: false)

EXAMPLES:
  # Normal backup
  bash backup-dotfiles.sh

  # Preview only
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
  log_error "'$DOTFILES_DIR' not found. Create it first (git clone or mkdir)."
  exit 1
fi

# Create required directories for script outputs and staged artifacts.
mkdir_p() {
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "mkdir: $(format_path "$1")"
  else
    mkdir -p "$1"
  fi
}

# Copy files/directories while preserving metadata where supported.
copy_tree() { # src dest
  local src="$1" dest="$2"
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "copy: $(format_path "$src") -> $(format_path "$dest")"
    return 0
  fi

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --chmod=Du=rwx,Dg=rx,Do= --chmod=Fu=rw,Fg=r,Fo=       --exclude='*.pem' --exclude='*.key' --exclude='*.p12'       --exclude='*Login Data*' --exclude='*Cookies*' --exclude='*Web Data*'       --exclude='*History*' --exclude='*Bookmarks*'       "$src/" "$dest/" 2>/dev/null || soft_warn "copy failed via rsync: $(format_path "$src") -> $(format_path "$dest")"
  else
    mkdir -p "$dest"
    cp -a "$src/" "$dest/" 2>/dev/null || soft_warn "copy failed via cp: $(format_path "$src") -> $(format_path "$dest")"
  fi
}

# Copy files/directories while preserving metadata where supported.
copy_file() {
  local src="$1" dest="$2"
  if [[ ! -e "$src" ]]; then log_warn "skip missing source: $(format_path "$src")"; return 0; fi
  mkdir_p "$(dirname "$dest")"
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "copy: $(format_path "$src") -> $(format_path "$dest")"
  else
    if cp -f "$src" "$dest" 2>/dev/null; then
      log_ok "copied: $(format_path "$src") -> $(format_path "$dest")"
    else
      soft_warn "copy failed: $(format_path "$src") -> $(format_path "$dest")"
    fi
  fi
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
section "Startup"
log_info "os: $OS_ID"
log_info "desktop: $DE_ID"
log_info "mode: $([[ "$DRY_RUN" == true ]] && echo dry-run || echo apply)"

mkdir_p "$NON_STOW_DIR"
mkdir_p "$NON_STOW_DIR/packages"

# --- Export package list (user-installed only when possible) ---
export_packages() {
  local outfile="$NON_STOW_DIR/packages/${OS_ID}-packages.txt"
  local universal="$NON_STOW_DIR/packages/universal-packages.txt"
  local export_ok=true

  # Execute a bounded subroutine used by a larger workflow stage.
  run_export_for_os() {
    case "$OS_ID" in
      fedora)
        # Prefer dnf repoquery (userinstalled); fallback to rpm -qa
        (dnf repoquery --userinstalled --qf '%{name}\n' || repoquery --userinstalled -q --qf '%{name}\n' || rpm -qa --qf '%{NAME}\n') | sort -u > "$outfile"
        ;;
      rpm)
        if command -v dnf >/dev/null 2>&1; then
          (dnf repoquery --userinstalled --qf '%{name}\n' || repoquery --userinstalled -q --qf '%{name}\n' || rpm -qa --qf '%{NAME}\n') | sort -u > "$outfile"
        elif command -v zypper >/dev/null 2>&1; then
          zypper search -i --type package --details | awk -F'|' '/^i\+/{gsub(/^ +| +$/,"",$2); print $2}' | sort -u > "$outfile"
        else
          rpm -qa --qf '%{NAME}\n' | sort -u > "$outfile"
        fi
        ;;
      opensuse)
        zypper search -i --type package --details | awk -F'|' '/^i\+/{gsub(/^ +| +$/,"",$2); print $2}' | sort -u > "$outfile"
        ;;
      debian)
        # Manual (user-requested) packages intersected with currently installed
        comm -12 <(apt-mark showmanual | sort -u) <(dpkg-query -W -f='${binary:Package}\n' | sort -u) > "$outfile"
        ;;
      arch)
        # Explicitly installed (includes both native and AUR)
        pacman -Qqe | sort -u > "$outfile"
        ;;
      mac)
        # Prefer leaves (top-level), fallback to full list
        if brew help leaves >/dev/null 2>&1; then
          brew leaves > "$outfile"
        else
          brew list --formula > "$outfile"
        fi
        ;;
      *)
        return 1
        ;;
    esac
  }

  if [[ "$DRY_RUN" == true ]]; then
    case "$OS_ID" in
      fedora)
        log_dry "export packages: dnf/repoquery/rpm fallback -> $(format_path "$outfile")"
        ;;
      rpm)
        log_dry "export packages: rpm fallback chain -> $(format_path "$outfile")"
        ;;
      opensuse)
        log_dry "export packages: zypper installed list -> $(format_path "$outfile")"
        ;;
      debian)
        log_dry "export packages: apt-mark/dpkg intersect -> $(format_path "$outfile")"
        ;;
      arch)
        log_dry "export packages: pacman explicit list -> $(format_path "$outfile")"
        ;;
      mac)
        log_dry "export packages: brew leaves/list -> $(format_path "$outfile")"
        ;;
      *)
        log_warn "skip package export: unknown OS '$OS_ID'"
        return 0
        ;;
    esac
    log_dry "ensure excludes template: $(format_path "$NON_STOW_DIR/packages/universal-excludes.txt")"
    log_dry "build universal candidate: $(format_path "$NON_STOW_DIR/packages/.generated/universal-candidate.txt")"
  else
    if ! run_export_for_os; then
      soft_warn "Package export command failed for OS '$OS_ID'"
      export_ok=false
      : > "$outfile" 2>/dev/null || true
    fi
    log_ok "saved: $(format_path "$outfile")"

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
      log_info "created excludes template: $(format_path "$excludes")"
    fi

    # Build candidate: start with filtered current OS list
    local tmp1
    tmp1=$(mktemp)
    if [[ -s "$outfile" ]]; then
      if [[ -s "$excludes" ]]; then
        grep -Ev -f "$excludes" "$outfile" | sort -u > "$tmp1" || { soft_warn "Failed to apply excludes while generating universal candidate"; : > "$tmp1"; }
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

    log_ok "saved: $(format_path "$candidate")"
    log_info "promote command: cp -f '$(format_path "$candidate")' '$(format_path "$universal")'"
    if [[ "$export_ok" != true ]]; then
      soft_warn "Package export finished with issues; review '$outfile' carefully"
    fi
  fi
}

# --- dconf generic backup helper ---
backup_dconf() { # out_file
  local out_file="$1"
  if ! command -v dconf >/dev/null 2>&1; then log_warn "skip dconf backup: tool not found"; return 0; fi
  mkdir_p "$(dirname "$out_file")"
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "save dconf dump: $(format_path "$out_file")"
  else
    dconf dump / > "$out_file" 2>/dev/null || true
    log_ok "saved: $(format_path "$out_file")"
  fi
}

# --- Backup per DE ---
backup_gnome()   { backup_dconf "$NON_STOW_DIR/gnome/gnome-settings.dconf"; }
# Back up current system or configuration state into snapshot files.
backup_cinnamon(){ backup_dconf "$NON_STOW_DIR/cinnamon/cinnamon-settings.dconf"; }
# Back up current system or configuration state into snapshot files.
backup_mate()    { backup_dconf "$NON_STOW_DIR/mate/mate-settings.dconf"; }
# Back up current system or configuration state into snapshot files.
backup_cosmic()  { backup_dconf "$NON_STOW_DIR/cosmic/cosmic-settings.dconf"; }
# Back up current system or configuration state into snapshot files.
backup_xfce() {
  local src="$HOME/.config/xfce4"
  local outdir="$NON_STOW_DIR/xfce/.config/xfce4"
  if [[ ! -d "$src" ]]; then log_warn "skip Xfce backup: source not found"; return 0; fi
  mkdir_p "$outdir"
  copy_tree "$src" "$outdir"
  log_ok "saved: $(format_path "$outdir")"
}
# Back up current system or configuration state into snapshot files.
backup_kde() {
  local plasmoids_src="$HOME/.local/share/plasma/plasmoids"
  local plasmoids_out="$NON_STOW_DIR/kde/plasmoids"
  mkdir_p "$NON_STOW_DIR/kde"
  if [[ -d "$plasmoids_src" ]]; then
    mkdir_p "$plasmoids_out"
    copy_tree "$plasmoids_src" "$plasmoids_out"
    log_ok "saved: $(format_path "$plasmoids_out")"
  else
    log_warn "skip KDE plasmoids backup: source not found"
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
      log_dry "save python globals: $(format_path "$req")"
    else
      python3 -m pip freeze > "$req" 2>/dev/null || soft_warn "python3 -m pip freeze failed"
      log_ok "saved: $(format_path "$req")"
    fi
  else
    log_warn "skip python global backup: python3/pip not found"
  fi

  # pyenv versions list
  if command -v pyenv >/dev/null 2>&1; then
    local pe="$base/pyenv-versions.txt"
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "save pyenv versions: $(format_path "$pe")"
    else
      pyenv versions --bare > "$pe" 2>/dev/null || soft_warn "pyenv versions export failed"
      log_ok "saved: $(format_path "$pe")"
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
        log_dry "save venv requirements ($name): $(format_path "$out")"
      else
        "$vdir/bin/pip" freeze > "$out" 2>/dev/null || soft_warn "Venv freeze failed: $name"
        log_ok "saved: $(format_path "$out")"
      fi
    done
    shopt -u nullglob
  done

  # Single-project venvs at $HOME (common names)
  for single in "$HOME/.venv" "$HOME/venv"; do
    if [[ -d "$single" && -x "$single/bin/pip" ]]; then
      local out
      out="$venv_out/$(basename "$single")-requirements.txt"
      if [[ "$DRY_RUN" == true ]]; then
        log_dry "save venv requirements ($(basename "$single")): $(format_path "$out")"
      else
        "$single/bin/pip" freeze > "$out" 2>/dev/null || soft_warn "Venv freeze failed: $(basename "$single")"
        log_ok "saved: $(format_path "$out")"
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
      log_dry "save node version: $(format_path "$base/node-current-version.txt")"
    else
      node -v > "$base/node-current-version.txt" 2>/dev/null || soft_warn "Failed to detect current Node version"
      log_ok "saved: $(format_path "$base/node-current-version.txt")"
    fi
  fi

  # Installed Node versions from common managers
  local versions_file="$base/node-installed-versions.txt"
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "save node installed versions: $(format_path "$versions_file")"
  else
    : > "$versions_file"
    # nvm directory listing
    if [[ -d "$HOME/.nvm/versions/node" ]]; then
      find "$HOME/.nvm/versions/node" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | sort -u >> "$versions_file" || soft_warn "Failed to enumerate nvm-installed Node versions"
    fi
    # fnm directory listing
    if [[ -d "$HOME/.fnm/node-versions" ]]; then
      find "$HOME/.fnm/node-versions" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | sort -u >> "$versions_file" || soft_warn "Failed to enumerate fnm-installed Node versions"
    fi
    # asdf directory listing
    if [[ -d "$HOME/.asdf/installs/nodejs" ]]; then
      find "$HOME/.asdf/installs/nodejs" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | sort -u >> "$versions_file" || soft_warn "Failed to enumerate asdf-installed Node versions"
    fi
    portable_delete_blank_lines "$versions_file" || soft_warn "Failed to remove blank lines from $versions_file"
    [[ -s "$versions_file" ]] && log_ok "saved: $(format_path "$versions_file")" || rm -f "$versions_file" 2>/dev/null || true
  fi

  # Global npm packages
  if command -v npm >/dev/null 2>&1; then
    local npmlist="$base/npm-global-packages.txt"
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "save npm globals: $(format_path "$npmlist")"
    else
      npm -g ls --depth=0 --parseable=true 2>/dev/null | tail -n +2 | xargs -n1 basename | sort -u > "$npmlist" || soft_warn "Failed to export npm global packages"
      log_ok "saved: $(format_path "$npmlist")"
    fi
  else
    log_warn "skip npm globals backup: npm not found"
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

# Parse `cargo install --list` output into "crate@version" lines.
emit_cargo_installed_crates() {
  cargo install --list 2>/dev/null | awk '/^[^[:space:]][^:]* v[^[:space:]]+:$/ {name=$1; ver=$2; sub(/^v/,"",ver); sub(/:$/,"",ver); print name "@" ver}'
}

# --- Dev backups: Bun ---
backup_bun() {
  local base="$NON_STOW_DIR/dev/bun"
  local bun_global_dir="$HOME/.bun/install/global"
  local bun_global_pkg="$bun_global_dir/package.json"
  local bun_global_lock="$bun_global_dir/bun.lock"
  local dep_out="$base/bun-global-packages.txt"
  mkdir_p "$base"

  if command -v bun >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "save bun version: $(format_path "$base/bun-version.txt")"
    else
      bun --version > "$base/bun-version.txt" 2>/dev/null || soft_warn "Failed to detect Bun version"
      log_ok "saved: $(format_path "$base/bun-version.txt")"
    fi
  else
    log_warn "skip Bun backup: bun not found"
  fi

  if [[ -f "$bun_global_pkg" ]]; then
    copy_file "$bun_global_pkg" "$base/package.json"
  else
    log_warn "skip Bun global package.json: source not found"
  fi
  if [[ -f "$bun_global_lock" ]]; then
    copy_file "$bun_global_lock" "$base/bun.lock"
  else
    log_warn "skip Bun global bun.lock: source not found"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -f "$bun_global_pkg" ]]; then
      log_dry "derive Bun globals list: $(format_path "$dep_out")"
    fi
    return 0
  fi

  if [[ -f "$base/package.json" ]]; then
    local tmp
    tmp=$(mktemp) || { soft_warn "Failed to create temp file for Bun dependency export"; return 0; }
    if emit_package_json_dependencies "$base/package.json" > "$tmp"; then
      portable_delete_blank_lines "$tmp" || true
      if [[ -s "$tmp" ]]; then
        sort -u "$tmp" > "$dep_out"
        log_ok "saved: $(format_path "$dep_out")"
      else
        rm -f "$dep_out" 2>/dev/null || true
        log_warn "skip Bun globals list: no dependencies found"
      fi
    else
      soft_warn "Failed to parse Bun global package dependencies from $base/package.json"
      rm -f "$dep_out" 2>/dev/null || true
    fi
    rm -f "$tmp" 2>/dev/null || true
  fi
}

# --- Dev backups: Rust ---
backup_rust() {
  local base="$NON_STOW_DIR/dev/rust"
  mkdir_p "$base"

  if command -v rustup >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "save rustup version: $(format_path "$base/rustup-version.txt")"
      log_dry "save rustup toolchains: $(format_path "$base/rustup-toolchains.txt")"
      log_dry "save rustup targets: $(format_path "$base/rustup-targets.txt")"
    else
      rustup --version > "$base/rustup-version.txt" 2>/dev/null || soft_warn "Failed to detect rustup version"
      log_ok "saved: $(format_path "$base/rustup-version.txt")"

      if rustup toolchain list 2>/dev/null | awk '{print $1}' | sort -u > "$base/rustup-toolchains.txt"; then
        log_ok "saved: $(format_path "$base/rustup-toolchains.txt")"
      else
        soft_warn "Failed to export rustup toolchains"
      fi

      if rustup target list --installed 2>/dev/null | sort -u > "$base/rustup-targets.txt"; then
        log_ok "saved: $(format_path "$base/rustup-targets.txt")"
      else
        soft_warn "Failed to export rustup installed targets"
      fi
    fi
  else
    log_warn "skip rustup backup: rustup not found"
  fi

  if command -v rustc >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "save rustc version: $(format_path "$base/rustc-version.txt")"
    else
      rustc --version > "$base/rustc-version.txt" 2>/dev/null || soft_warn "Failed to detect rustc version"
      log_ok "saved: $(format_path "$base/rustc-version.txt")"
    fi
  fi

  if command -v cargo >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "save cargo version: $(format_path "$base/cargo-version.txt")"
      log_dry "save cargo installed crates: $(format_path "$base/cargo-installed-crates.txt")"
    else
      cargo --version > "$base/cargo-version.txt" 2>/dev/null || soft_warn "Failed to detect cargo version"
      log_ok "saved: $(format_path "$base/cargo-version.txt")"

      if emit_cargo_installed_crates > "$base/cargo-installed-crates.txt"; then
        if [[ -s "$base/cargo-installed-crates.txt" ]]; then
          log_ok "saved: $(format_path "$base/cargo-installed-crates.txt")"
        else
          rm -f "$base/cargo-installed-crates.txt" 2>/dev/null || true
          log_warn "skip cargo installed crates: none found"
        fi
      else
        soft_warn "Failed to export cargo installed crates"
        rm -f "$base/cargo-installed-crates.txt" 2>/dev/null || true
      fi
    fi
  else
    log_warn "skip cargo backup: cargo not found"
  fi
}

# --- Run tasks ---
section "Packages"
export_packages
section "Python"
backup_python
section "Node"
backup_node
section "Bun"
backup_bun
section "Rust"
backup_rust
section "Desktop"
case "$DE_ID" in
  gnome)    backup_gnome ;;
  cinnamon) backup_cinnamon ;;
  mate)     backup_mate ;;
  cosmic)   backup_cosmic ;;
  xfce)     backup_xfce ;;
  kde)      backup_kde ;;
  *)        log_warn "skip desktop backup: '$DE_ID' not specifically supported" ;;
esac

section "Summary"
if [[ "$SOFT_WARNINGS" -gt 0 ]]; then
  log_warn "backup completed with $SOFT_WARNINGS warning(s)"
  log_ok "output: $(format_path "$NON_STOW_DIR")"
else
  log_ok "backup completed successfully"
  log_ok "output: $(format_path "$NON_STOW_DIR")"
fi
