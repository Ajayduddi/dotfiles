#!/usr/bin/env bash
# Restore Packages Script - MATCHES your backup script (debian-packages.txt for Ubuntu/Debian/Kali)
set +e  # Continue on errors

# Configuration
NON_STOW_DIR="${NON_STOW_DIR:-$HOME/.dotfiles/non_stow}"
DRY_RUN="${DRY_RUN:-false}"

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err() { echo "[ERROR] $*"; exit 1; }
debug() { echo "[DEBUG] $*"; }

# EXACT SAME OS detection as your backup script
detect_os() {
  if command -v dnf >/dev/null 2>&1 || command -v dnf5 >/dev/null 2>&1; then echo "fedora"
  elif command -v yum >/dev/null 2>&1; then echo "rpm"
  elif command -v apt-get >/dev/null 2>&1; then
    if [[ -r /etc/os-release ]]; then . /etc/os-release; case "${ID:-}" in ubuntu) echo "ubuntu";; debian|kali) echo "debian";; *) echo "debian";; esac; fi || echo "debian"
  elif command -v pacman >/dev/null 2>&1; then echo "arch"
  elif command -v zypper >/dev/null 2>&1; then echo "opensuse"
  elif command -v brew >/dev/null 2>&1; then echo "mac"
  else echo "unknown"; fi
}

OS_ID=$(detect_os)
log "Detected OS: $OS_ID | Dry-run: $DRY_RUN"

# MATCHES your backup script - debian-packages.txt for Ubuntu/Debian/Kali
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

main() {
  local pkg_file=$(get_package_file)
  [[ -z "$pkg_file" ]] && { warn "No package file defined for OS '$OS_ID'"; return 1; }
  
  [[ ! -f "$pkg_file" ]] && { warn "Package file not found: $pkg_file"; ls -la "$NON_STOW_DIR/packages/" 2>/dev/null; return 1; }
  
  local total_packages=$(wc -l < "$pkg_file")
  log "=== Package Restore Script v3.1 ==="
  log "Processing $total_packages packages from $pkg_file"
  log "Testing sudo access..."
  
  # Pre-authenticate sudo
  sudo -v 2>/dev/null || warn "Sudo auth skipped"
  
  log "Updating apt cache..."
  timeout 30 sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null || warn "apt update skipped"
  
  local count=0 success=0 failed=0
  log "[DEBUG] Starting package installation loop..."
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    debug "Read line: '$line'"
    
    # Skip empty lines and comments (matches your backup format)
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    local pkg
    pkg=$(echo "$line" | xargs)
    [[ -z "$pkg" ]] && continue
    
    ((count++))
    printf "\r[%03d/%d] Installing: %s" "$count" "$total_packages" "$pkg"
    
    case "$OS_ID" in
      ubuntu|debian|kali)
        if timeout 15 sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" 2>/dev/null; then
          printf " ✅\n"
          ((success++))
        else
          printf " ❌ (not available)\n"
          ((failed++))
        fi
        ;;
      fedora|rpm)
        if sudo dnf install -y -q "$pkg" 2>/dev/null || sudo yum install -y -q "$pkg" 2>/dev/null; then
          printf " ✅\n"
          ((success++))
        else
          printf " ❌ (not available)\n"
          ((failed++))
        fi
        ;;
      arch)
        if sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
          printf " ✅\n"
          ((success++))
        else
          printf " ❌ (not available)\n"
          ((failed++))
        fi
        ;;
      opensuse)
        if sudo zypper install -y "$pkg" 2>/dev/null; then
          printf " ✅\n"
          ((success++))
        else
          printf " ❌ (not available)\n"
          ((failed++))
        fi
        ;;
      mac)
        if brew install "$pkg" 2>/dev/null; then
          printf " ✅\n"
          ((success++))
        else
          printf " ❌ (not available)\n"
          ((failed++))
        fi
        ;;
    esac
  done < "$pkg_file"
  
  echo -e "\n=== FINAL SUMMARY ==="
  log "Total processed: $count"
  log "✅ Success: $success"
  log "❌ Failed/Missing: $failed"
}

log "=== Package Restore Script v3.1 ==="
main "$@"
log "=== Script complete ==="
