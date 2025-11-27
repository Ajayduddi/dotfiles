#!/bin/bash

# ===============================
# INFRASTRUCTURE BACKUP & RESTORE
# Author: Ajay Duddi
# Updated for safety, dry-run, robust error handling, and permission fixes
# ===============================

BACKUP_DIR=~/.dotfiles/infra-backup
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$BACKUP_DIR/backup-$TIMESTAMP.log"

mkdir -p "$BACKUP_DIR"/{nginx,jetty,maven,mysql}

# Robust shell options
set -euo pipefail
shopt -s nullglob

DRY_RUN=${DRY_RUN:-false}

# Enhanced trap for diagnostics with last command
trap 'ec=$?; echo "[ERROR] $0 failed at line $LINENO (exit $ec) - last cmd: $BASH_COMMAND" | tee -a "$LOG_FILE"' ERR

log() { echo "[INFO] $1" | tee -a "$LOG_FILE"; }
warn() { echo "[WARNING] $1" | tee -a "$LOG_FILE"; }
error_exit() { echo "[ERROR] $1" | tee -a "$LOG_FILE"; exit 1; }
would() { echo "[DRYRUN] $1" | tee -a "$LOG_FILE"; }

PKG_MANAGER=""
APT_UPDATED=0
JETTY_VERSION_REQUIRED="12"
JETTY_INSTALL_DIR="/opt/jetty-base"
JETTY_DOWNLOAD_URL="${JETTY_DOWNLOAD_URL:-https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.0.10/jetty-home-12.0.10.tar.gz}"

# -------- Jetty detection with regex match for more accuracy --------
check_jetty_12_installed() {
  if command -v jetty >/dev/null 2>&1; then
    if jetty --version 2>&1 | grep -E -q "(^|[^0-9])12(\.[0-9]+)*"; then return 0; fi
  fi
  if command -v java >/dev/null 2>&1; then
    for jar in /opt/jetty-base/start.jar /opt/jetty-home/start.jar /opt/jetty/start.jar; do
      [ -f "$jar" ] && java -jar "$jar" --version 2>&1 | grep -E -q "(^|[^0-9])12(\.[0-9]+)*" && return 0
    done
  fi
  for dir in /opt/jetty-home-12 /opt/jetty-12 /opt/jetty-base-12; do
    [ -d "$dir" ] && return 0
  done
  return 1
}

# -------- Jetty manual installation with backup and dry-run checks --------
install_jetty_manual() {
  local url="$JETTY_DOWNLOAD_URL"
  local tmp_dir archive_path extract_dir jetty_src

  if [ -z "$url" ]; then
    warn "Jetty download URL not configured."
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    warn "Neither curl nor wget found for Jetty download."
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    would "Download Jetty from $url to /tmp"
    would "Extract Jetty archive"
    would "Backup existing Jetty dir $JETTY_INSTALL_DIR if exists"
    would "Move extracted Jetty to $JETTY_INSTALL_DIR"
    return 0
  fi

  tmp_dir=$(mktemp -d) || return 1
  archive_path="$tmp_dir/jetty.tar.gz"
  extract_dir="$tmp_dir/extracted"

  # Download archive with checksum validation (optional, not implemented here for brevity)
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$archive_path" || { warn "Jetty download failed via curl."; rm -rf "$tmp_dir"; return 1; }
  else
    wget -q "$url" -O "$archive_path" || { warn "Jetty download failed via wget."; rm -rf "$tmp_dir"; return 1; }
  fi

  mkdir -p "$extract_dir"
  if ! tar -xzf "$archive_path" -C "$extract_dir"; then
    warn "Jetty extraction failed."
    rm -rf "$tmp_dir"
    return 1
  fi

  jetty_src=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  if [ -z "$jetty_src" ]; then
    warn "No directory in Jetty archive."
    rm -rf "$tmp_dir"
    return 1
  fi

  if [ -d "$JETTY_INSTALL_DIR" ]; then
    local backup_dir="${JETTY_INSTALL_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
    log "Backing up existing Jetty to $backup_dir"
    sudo mv "$JETTY_INSTALL_DIR" "$backup_dir" || { warn "Failed to backup existing Jetty."; rm -rf "$tmp_dir"; return 1; }
  fi

  sudo mv "$jetty_src" "$JETTY_INSTALL_DIR" || { warn "Failed to move Jetty to $JETTY_INSTALL_DIR."; rm -rf "$tmp_dir"; return 1; }
  sudo chown -R root:root "$JETTY_INSTALL_DIR" || warn "Failed to chown Jetty."
  rm -rf "$tmp_dir"

  log "Jetty 12 installed at $JETTY_INSTALL_DIR"
  return 0
}

ensure_jetty_dependency() {
  if check_jetty_12_installed; then
    log "Jetty 12 already installed."
    return 0
  fi

  log "Jetty 12 not found; installing..."
  install_jetty_manual
  if check_jetty_12_installed; then
    log "Jetty 12 installation successful."
    return 0
  else
    warn "Jetty 12 installation failed."
    return 1
  fi
}

detect_package_manager() {
  if [ -n "$PKG_MANAGER" ]; then return 0; fi
  for cmd in apt dnf5 dnf yum zypper pacman apk brew; do
    if command -v "$cmd" >/dev/null 2>&1; then PKG_MANAGER="$cmd"; return 0; fi
  done
  return 1
}

install_package() {
  local package="$1"
  if [ -z "$package" ]; then return 1; fi
  if [ -z "$PKG_MANAGER" ]; then detect_package_manager || return 1; fi

  if [[ "$DRY_RUN" == "true" ]]; then
    would "Install package $package via $PKG_MANAGER"
    return 0
  fi

  case "$PKG_MANAGER" in
    apt)
      if [ "$APT_UPDATED" -eq 0 ]; then
        sudo apt-get update || return 1
        APT_UPDATED=1
      fi
      sudo apt-get install -y "$package" || return 1
      ;;
    dnf5)
      sudo dnf5 install -y "$package" || return 1
      ;;
    dnf)
      sudo dnf install -y "$package" || return 1
      ;;
    yum)
      sudo yum install -y "$package" || return 1
      ;;
    zypper)
      sudo zypper install -y "$package" || return 1
      ;;
    pacman)
      sudo pacman -S --needed --noconfirm "$package" || return 1
      ;;
    apk)
      sudo apk add --no-cache "$package" || return 1
      ;;
    brew)
      brew install "$package" || return 1
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

ensure_dependency() {
  local name="$1"; shift
  local check_cmd="$1"; shift
  local packages=("$@")

  if eval "$check_cmd"; then
    log "$name already installed."
    return 0
  fi

  log "$name not found; installing..."

  for pkg in "${packages[@]}"; do
    if install_package "$pkg"; then
      if eval "$check_cmd"; then
        log "$name installed via $pkg."
        return 0
      fi
    fi
  done

  warn "Failed to install $name."
  return 1
}

ensure_prerequisites() {
  if ! detect_package_manager; then
    warn "No supported package manager detected."
    return 1
  fi

  # Attempt all dependencies, log warnings, do not abort
  ensure_dependency "NGINX" "command -v nginx >/dev/null 2>&1" "nginx" || warn "NGINX missing or failed"
  ensure_jetty_dependency || warn "Jetty 12 missing or failed"
  ensure_dependency "Maven" "command -v mvn >/dev/null 2>&1" "maven" || warn "Maven missing or failed"
  ensure_dependency "MySQL" "command -v mysql >/dev/null 2>&1" "mysql-server" "mysql" "mariadb-server" || warn "MySQL missing or failed"

  # Always return success to continue restoration
  return 0
}

backup_configs() {
  log "Starting backup at $TIMESTAMP"

  # NGINX
  files=(/etc/nginx/*)
  if (( ${#files[@]} )); then
    log "Backing up NGINX config..."
    sudo cp -r /etc/nginx/* "$BACKUP_DIR/nginx/" || warn "NGINX backup failed"
  else
    warn "NGINX directory empty or missing"
  fi

  # Jetty
  if [ -d /opt/jetty-base ]; then
    log "Backing up Jetty config..."
    sudo cp -r /opt/jetty-base "$BACKUP_DIR/jetty/" || warn "Jetty backup failed"
  else
    warn "Jetty base not found"
  fi
  if [ -f /etc/systemd/system/jetty.service ]; then
    sudo cp /etc/systemd/system/jetty.service "$BACKUP_DIR/jetty/" || warn "Jetty systemd service backup failed"
  fi

  # Maven
  if [ -f ~/.m2/settings.xml ]; then
    log "Backing up Maven settings.xml..."
    mkdir -p "$BACKUP_DIR/maven"
    cp ~/.m2/settings.xml "$BACKUP_DIR/maven/"
  else
    warn "Maven settings.xml not found"
  fi

  # MySQL config (check multiple common paths)
  if [ -f /etc/mysql/my.cnf ]; then
    sudo cp /etc/mysql/my.cnf "$BACKUP_DIR/mysql/"
  elif [ -f /etc/my.cnf ]; then
    sudo cp /etc/my.cnf "$BACKUP_DIR/mysql/"
  else
    warn "MySQL config not found"
  fi

  log "✅ Backup complete. Files saved at $BACKUP_DIR"
}

restore_configs() {
  log "Starting restoration process..."

  ensure_prerequisites || warn "Prerequisite installation warnings occurred, continuing..."

  files=( "$BACKUP_DIR"/nginx/* )
  if (( ${#files[@]} )); then
    log "Restoring NGINX config..."
    sudo cp -r "$BACKUP_DIR/nginx/"* /etc/nginx/ || warn "NGINX restore failed"
  else
    warn "No NGINX backup files found"
  fi

  if [ -d "$BACKUP_DIR/jetty/jetty-base" ]; then
    log "Restoring Jetty config..."
    sudo cp -r "$BACKUP_DIR/jetty/jetty-base" /opt/
    if [ -f "$BACKUP_DIR/jetty/jetty.service" ]; then
      sudo cp "$BACKUP_DIR/jetty/jetty.service" /etc/systemd/system/
      systemctl daemon-reload || warn "Failed to reload systemd"
      systemctl enable jetty || warn "Failed to enable jetty"
    fi
  else
    warn "No Jetty backup found"
  fi

  if [ -f "$BACKUP_DIR/maven/settings.xml" ]; then
    log "Restoring Maven settings.xml..."
    mkdir -p ~/.m2
    cp "$BACKUP_DIR/maven/settings.xml" ~/.m2/
  else
    warn "No Maven settings backup found"
  fi

  if [ -f "$BACKUP_DIR/mysql/my.cnf" ]; then
    log "Restoring MySQL config..."
    sudo cp "$BACKUP_DIR/mysql/my.cnf" /etc/mysql/ || sudo cp "$BACKUP_DIR/mysql/my.cnf" /etc/
  else
    warn "No MySQL config backup found"
  fi

  log "Restarting services (if available)..."
  systemctl restart nginx || warn "NGINX restart failed or systemd not available"
  systemctl restart jetty || warn "Jetty restart failed or systemd not available"

  log "✅ Restoration complete."
}

case "$1" in
  backup)
    backup_configs
    ;;
  restore)
    restore_configs
    ;;
  *)
    echo "Usage: $0 {backup|restore}"
    exit 1
    ;;
esac
