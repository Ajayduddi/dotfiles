#!/usr/bin/env bash
# Package restore helper for non_stow OS package lists across supported distributions.
# Primary stages: parse input, preflight package manager state, install in batches, verify and report gaps.
# Safety model: non-strict mode is warning/continue with missing report; strict mode fails fast on errors.

set -u -o pipefail

# Defaults (backward-compatible with env usage)
NON_STOW_DIR="${NON_STOW_DIR:-$HOME/.dotfiles/non_stow}"
DRY_RUN="${DRY_RUN:-false}"
STRICT_MODE="${STRICT_MODE:-false}"
DEBUG_MODE="${DEBUG_MODE:-false}"
CHUNK_SIZE="${CHUNK_SIZE:-120}"

OS_ID=""
PKG_FILE=""
REQUESTED_COUNT=0
INSTALLED_OK=0
MISSING_COUNT=0
FAILED_COUNT=0
REPORT_FILE=""
declare -a PACKAGES=()
declare -a MISSING_PACKAGES=()

# Normalize boolean-like input values to true/false semantics.
to_bool() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|on|ON) echo "true" ;;
    *) echo "false" ;;
  esac
}

# Print script usage, behavior notes, and environment configuration help.
show_help() {
  cat <<'HELP'
[INFO] Package Restore Helper

Purpose:
  Restore OS packages from non_stow package lists quickly and safely.
  Default mode is compatibility-first: continue on failures and report missing.

Usage:
  restore_packages.sh [--dry-run|-n] [--strict|--non-strict] [--debug] [--help|-h]

Options:
  --dry-run, -n   Show planned actions without installing packages
  --strict        Stop on install failure and return non-zero
  --non-strict    Continue on failures (default)
  --debug         Show debug logs
  --help, -h      Show this help and exit

Environment Variables:
  NON_STOW_DIR    Base non_stow path (default: $HOME/.dotfiles/non_stow)
  DRY_RUN         true/false (CLI overrides env)
  STRICT_MODE     true/false (CLI overrides env)
  DEBUG_MODE      true/false (CLI overrides env)
  CHUNK_SIZE      Batch size for bulk installs (default: 120)

Behavior:
  - Fedora/non-strict uses batched dnf installs with:
      --skip-unavailable --skip-broken
  - Strict mode disables skip flags and fails fast.
  - Post-check verifies installed status and writes missing report to:
      non_stow/packages/.generated/restore-missing-<os>-<timestamp>.txt

Examples:
  bash restore_packages.sh --dry-run
  bash restore_packages.sh
  bash restore_packages.sh --strict
  DRY_RUN=true STRICT_MODE=false bash restore_packages.sh
HELP
}

# Render a shorter path form for readable logs (~ and repo-relative paths).
format_path() {
  local p="${1:-}"
  # shellcheck disable=SC2088
  local home_slash='~/'
  # shellcheck disable=SC2088
  local home_token='~'
  [[ -z "$p" ]] && { printf '%s\n' "$p"; return 0; }
  case "$p" in
    "$NON_STOW_DIR"/*) p="non_stow/${p#"$NON_STOW_DIR"/}" ;;
    "$HOME"/*) p="${home_slash}${p#"$HOME"/}" ;;
    "$HOME") p="$home_token" ;;
  esac
  printf '%s\n' "$p"
}

# Normalize a log message and shorten embedded filesystem paths.
format_message() {
  local msg="$*"
  # shellcheck disable=SC2088
  local home_slash='~/'
  # shellcheck disable=SC2088
  local home_token='~'
  msg="${msg//"$NON_STOW_DIR/"/non_stow/}"
  msg="${msg//"$HOME/"/$home_slash}"
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
# Emit a structured log line for this severity level.
log_debug() { [[ "$DEBUG_MODE" == "true" ]] && echo "[DEBUG] $(format_message "$*")"; }
# Print a section header to group output by execution stage.
section()   { echo "[INFO] ===== $* ====="; }

# Print an error and terminate with a non-zero exit code.
die() {
  log_error "$*"
  exit 1
}

# Render a human-readable representation for logs or shell output.
render_cmd() {
  local out="" part
  for part in "$@"; do
    out+="${out:+ }$(printf '%q' "$part")"
  done
  printf '%s\n' "$out"
}

# Detect runtime platform/tooling details used to select execution paths.
detect_os() {
  if command -v dnf5 >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then echo "fedora"
  elif command -v yum >/dev/null 2>&1; then echo "rpm"
  elif command -v apt-get >/dev/null 2>&1; then
    if [[ -r /etc/os-release ]]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      case "${ID:-}" in
        ubuntu) echo "ubuntu" ;;
        debian|kali) echo "debian" ;;
        *) echo "debian" ;;
      esac
    else
      echo "debian"
    fi
  elif command -v pacman >/dev/null 2>&1; then echo "arch"
  elif command -v zypper >/dev/null 2>&1; then echo "opensuse"
  elif command -v brew >/dev/null 2>&1; then echo "mac"
  else echo "unknown"
  fi
}

# Return computed metadata or resolved paths needed by later stages.
get_package_file() {
  case "$OS_ID" in
    ubuntu|debian|kali) echo "$NON_STOW_DIR/packages/debian-packages.txt" ;;
    fedora|rpm) echo "$NON_STOW_DIR/packages/fedora-packages.txt" ;;
    arch) echo "$NON_STOW_DIR/packages/arch-packages.txt" ;;
    opensuse) echo "$NON_STOW_DIR/packages/opensuse-packages.txt" ;;
    mac) echo "$NON_STOW_DIR/packages/mac-packages.txt" ;;
    *) echo "" ;;
  esac
}

# Parse CLI flags and update runtime options used by the script.
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run|-n) DRY_RUN="true" ;;
      --strict) STRICT_MODE="true" ;;
      --non-strict) STRICT_MODE="false" ;;
      --debug) DEBUG_MODE="true" ;;
      --help|-h) show_help; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done
}

# Load config/input data into script state for subsequent processing.
load_packages() {
  local pkg_file="$1" line pkg
  PACKAGES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    pkg="$(printf '%s' "$line" | xargs)"
    [[ -z "$pkg" ]] && continue
    PACKAGES+=("$pkg")
  done < "$pkg_file"
}

# Run preflight checks before making system or firewall changes.
preflight_auth() {
  if [[ "$OS_ID" == "mac" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "sudo -v"
    return 0
  fi

  if ! sudo -v >/dev/null 2>&1; then
    log_warn "sudo authentication failed or skipped"
    [[ "$STRICT_MODE" == "true" ]] && return 1
  fi
  return 0
}

# Prepare package manager/runtime state before install operations.
prepare_package_manager() {
  case "$OS_ID" in
    ubuntu|debian|kali)
      if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "sudo apt-get update -qq"
      else
        sudo apt-get update -qq >/dev/null 2>&1 || {
          log_warn "apt cache update failed"
          [[ "$STRICT_MODE" == "true" ]] && return 1
        }
      fi
      ;;
    fedora|rpm)
      if [[ "$DRY_RUN" == "true" ]]; then
        if command -v dnf5 >/dev/null 2>&1; then
          log_dry "sudo dnf5 -q makecache"
        elif command -v dnf >/dev/null 2>&1; then
          log_dry "sudo dnf -q makecache"
        else
          log_dry "sudo yum -q makecache"
        fi
      else
        if command -v dnf5 >/dev/null 2>&1; then
          sudo dnf5 -q makecache >/dev/null 2>&1 || true
        elif command -v dnf >/dev/null 2>&1; then
          sudo dnf -q makecache >/dev/null 2>&1 || true
        elif command -v yum >/dev/null 2>&1; then
          sudo yum -q makecache >/dev/null 2>&1 || true
        fi
      fi
      ;;
    arch)
      if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "sudo pacman -Sy --noconfirm"
      else
        sudo pacman -Sy --noconfirm >/dev/null 2>&1 || {
          log_warn "pacman sync failed"
          [[ "$STRICT_MODE" == "true" ]] && return 1
        }
      fi
      ;;
    opensuse)
      if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "sudo zypper refresh -q"
      else
        sudo zypper refresh -q >/dev/null 2>&1 || {
          log_warn "zypper refresh failed"
          [[ "$STRICT_MODE" == "true" ]] && return 1
        }
      fi
      ;;
    mac)
      log_debug "brew update skipped for speed"
      ;;
    *)
      log_warn "Unknown OS '$OS_ID'; package manager preflight skipped"
      ;;
  esac
  return 0
}

# Install required packages or runtimes for this restore/workflow stage.
install_batch() {
  local -a batch=("$@")
  local -a cmd=()

  case "$OS_ID" in
    fedora|rpm)
      if command -v dnf5 >/dev/null 2>&1; then
        cmd=(sudo dnf5 install -y -q)
      elif command -v dnf >/dev/null 2>&1; then
        cmd=(sudo dnf install -y -q)
      elif command -v yum >/dev/null 2>&1; then
        cmd=(sudo yum install -y -q)
      else
        return 1
      fi
      if [[ "$STRICT_MODE" != "true" ]] && (command -v dnf5 >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1); then
        cmd+=(--skip-unavailable --skip-broken)
      fi
      ;;
    ubuntu|debian|kali)
      cmd=(sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq)
      [[ "$STRICT_MODE" != "true" ]] && cmd+=(--ignore-missing)
      ;;
    arch)
      cmd=(sudo pacman -S --needed --noconfirm)
      ;;
    opensuse)
      cmd=(sudo zypper install -y)
      ;;
    mac)
      cmd=(brew install)
      ;;
    *)
      return 1
      ;;
  esac

  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "$(render_cmd "${cmd[@]}" "${batch[@]}")"
    return 0
  fi

  "${cmd[@]}" "${batch[@]}" >/dev/null 2>&1
}

# Install required packages or runtimes for this restore/workflow stage.
install_one() {
  local pkg="$1"
  if install_batch "$pkg"; then
    return 0
  fi
  return 1
}

# Install required packages or runtimes for this restore/workflow stage.
install_packages() {
  local total="${#PACKAGES[@]}"
  local idx=0 batch_no=0 batch_total=0 batch_len=0
  batch_total=$(( (total + CHUNK_SIZE - 1) / CHUNK_SIZE ))

  while (( idx < total )); do
    local -a batch=( "${PACKAGES[@]:idx:CHUNK_SIZE}" )
    batch_len="${#batch[@]}"
    ((batch_no++))
    log_info "batch ${batch_no}/${batch_total}: ${batch_len} package(s)"

    if install_batch "${batch[@]}"; then
      log_ok "batch ${batch_no}: complete"
    else
      ((FAILED_COUNT++))
      if [[ "$STRICT_MODE" == "true" ]]; then
        log_error "batch ${batch_no}: failed in strict mode"
        return 1
      fi
      log_warn "batch ${batch_no}: failed, retrying package-by-package"
      local pkg
      for pkg in "${batch[@]}"; do
        if ! install_one "$pkg"; then
          ((FAILED_COUNT++))
          log_debug "individual install failed: $pkg"
        fi
      done
    fi
    idx=$((idx + CHUNK_SIZE))
  done
  return 0
}

# Return success when the requested condition is true.
is_package_installed() {
  local pkg="$1"
  case "$OS_ID" in
    fedora|rpm|opensuse)
      rpm -q "$pkg" >/dev/null 2>&1
      ;;
    ubuntu|debian|kali)
      dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
      ;;
    arch)
      pacman -Q "$pkg" >/dev/null 2>&1
      ;;
    mac)
      brew list --formula "$pkg" >/dev/null 2>&1 || brew list "$pkg" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

# Verify requested packages post-install and write a missing-packages report.
verify_and_report() {
  local pkg
  INSTALLED_OK=0
  MISSING_PACKAGES=()

  if [[ "$DRY_RUN" == "true" ]]; then
    INSTALLED_OK="$REQUESTED_COUNT"
    MISSING_COUNT=0
    log_dry "verification skipped in dry-run"
    return 0
  fi

  for pkg in "${PACKAGES[@]}"; do
    if is_package_installed "$pkg"; then
      ((INSTALLED_OK++))
    else
      MISSING_PACKAGES+=("$pkg")
    fi
  done
  MISSING_COUNT="${#MISSING_PACKAGES[@]}"

  if (( MISSING_COUNT > 0 )); then
    local out_dir stamp
    out_dir="$NON_STOW_DIR/packages/.generated"
    stamp="$(date +%Y%m%d_%H%M%S)"
    REPORT_FILE="$out_dir/restore-missing-${OS_ID}-${stamp}.txt"
    mkdir -p "$out_dir"
    {
      echo "# Missing/unavailable packages after restore"
      echo "# os=$OS_ID requested=$REQUESTED_COUNT installed_ok=$INSTALLED_OK missing=$MISSING_COUNT"
      for pkg in "${MISSING_PACKAGES[@]}"; do
        echo "$pkg"
      done
    } > "$REPORT_FILE"
    log_warn "missing report: $(format_path "$REPORT_FILE")"
  fi
}

# Orchestrate all stages in the intended order for this script.
main() {
  parse_args "$@"
  DRY_RUN="$(to_bool "$DRY_RUN")"
  STRICT_MODE="$(to_bool "$STRICT_MODE")"
  DEBUG_MODE="$(to_bool "$DEBUG_MODE")"

  section "Startup"
  OS_ID="$(detect_os)"
  log_info "os: $OS_ID"
  log_info "mode: $([[ "$DRY_RUN" == "true" ]] && echo dry-run || echo apply)"
  log_info "strict: $STRICT_MODE"
  log_info "chunk-size: $CHUNK_SIZE"

  section "Input"
  PKG_FILE="$(get_package_file)"
  [[ -z "$PKG_FILE" ]] && { log_warn "no package file mapping for OS '$OS_ID'"; return 1; }
  [[ ! -f "$PKG_FILE" ]] && { log_warn "package file not found: $(format_path "$PKG_FILE")"; return 1; }

  load_packages "$PKG_FILE"
  REQUESTED_COUNT="${#PACKAGES[@]}"
  log_info "package-file: $(format_path "$PKG_FILE")"
  log_info "requested: $REQUESTED_COUNT"
  (( REQUESTED_COUNT == 0 )) && { log_warn "package list is empty"; return 0; }

  section "Preflight"
  preflight_auth || return 1
  prepare_package_manager || return 1
  log_ok "preflight complete"

  section "Install"
  install_packages || [[ "$STRICT_MODE" != "true" ]]

  section "Verify"
  verify_and_report
  log_ok "verify complete"

  section "Summary"
  log_info "requested: $REQUESTED_COUNT"
  log_info "installed/ok: $INSTALLED_OK"
  log_info "missing: $MISSING_COUNT"
  log_info "failed: $FAILED_COUNT"
  [[ -n "$REPORT_FILE" ]] && log_info "report: $(format_path "$REPORT_FILE")"

  if [[ "$STRICT_MODE" == "true" && ( "$FAILED_COUNT" -gt 0 || "$MISSING_COUNT" -gt 0 ) ]]; then
    return 1
  fi
  return 0
}

main "$@"
rc=$?
if [[ "$(to_bool "${STRICT_MODE:-false}")" == "true" && "$rc" -ne 0 ]]; then
  exit "$rc"
fi
exit 0
