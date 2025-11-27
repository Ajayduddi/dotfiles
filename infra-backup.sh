#!/bin/bash

# ===============================
# INFRASTRUCTURE BACKUP & RESTORE
# Author: Ajay Duddi
# ===============================

BACKUP_DIR=~/.dotfiles/infra-backup
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$BACKUP_DIR/backup-$TIMESTAMP.log"

# Create required directories
mkdir -p "$BACKUP_DIR"/{nginx,jetty,maven,mysql}

# Exit on any error
set -e

# Trap signals and log on failure
trap 'echo "[ERROR] Script failed at line $LINENO with exit code $?" | tee -a "$LOG_FILE"' ERR

log() {
  echo "[INFO] $1" | tee -a "$LOG_FILE"
}

warn() {
  echo "[WARNING] $1" | tee -a "$LOG_FILE"
}

error_exit() {
  echo "[ERROR] $1" | tee -a "$LOG_FILE"
  exit 1
}

PKG_MANAGER=""
APT_UPDATED=0
JETTY_VERSION_REQUIRED="12"
JETTY_INSTALL_DIR="/opt/jetty-base"
JETTY_DOWNLOAD_URL="${JETTY_DOWNLOAD_URL:-https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.0.10/jetty-home-12.0.10.tar.gz}"

check_jetty_12_installed() {
  local version_output

  if command -v jetty >/dev/null 2>&1; then
    version_output=$(jetty --version 2>/dev/null || true)
    if echo "$version_output" | grep -q "$JETTY_VERSION_REQUIRED"; then
      return 0
    fi
  fi

  if command -v java >/dev/null 2>&1; then
    for jar in /opt/jetty-base/start.jar /opt/jetty-home/start.jar /opt/jetty/start.jar; do
      if [ -f "$jar" ]; then
        version_output=$(java -jar "$jar" --version 2>/dev/null || true)
        if echo "$version_output" | grep -q "$JETTY_VERSION_REQUIRED"; then
          return 0
        fi
      fi
    done
  fi

  for dir in /opt/jetty-home-12 /opt/jetty-12 /opt/jetty-base-12; do
    if [ -d "$dir" ]; then
      return 0
    fi
  done

  return 1
}

install_jetty_manual() {
  local url="$JETTY_DOWNLOAD_URL"
  local tmp_dir archive_path extract_dir jetty_src

  if [ -z "$url" ]; then
    warn "Jetty download URL is not configured."
    return 1
  fi

  tmp_dir=$(mktemp -d) || return 1
  archive_path="$tmp_dir/jetty.tar.gz"
  extract_dir="$tmp_dir/extracted"

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$url" -o "$archive_path"; then
      warn "Failed to download Jetty archive via curl."
      rm -rf "$tmp_dir"
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -q "$url" -O "$archive_path"; then
      warn "Failed to download Jetty archive via wget."
      rm -rf "$tmp_dir"
      return 1
    fi
  else
    warn "Neither curl nor wget is available to download Jetty."
    rm -rf "$tmp_dir"
    return 1
  fi

  mkdir -p "$extract_dir"
  if ! tar -xzf "$archive_path" -C "$extract_dir"; then
    warn "Failed to extract Jetty archive."
    rm -rf "$tmp_dir"
    return 1
  fi

  jetty_src=$(find "$extract_dir" -maxdepth 1 -mindepth 1 -type d | head -n 1)
  if [ -z "$jetty_src" ]; then
    warn "Jetty archive did not contain an installable directory."
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! sudo rm -rf "$JETTY_INSTALL_DIR"; then
    warn "Unable to remove existing Jetty directory at $JETTY_INSTALL_DIR."
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! sudo mv "$jetty_src" "$JETTY_INSTALL_DIR"; then
    warn "Failed to move Jetty files into $JETTY_INSTALL_DIR."
    rm -rf "$tmp_dir"
    return 1
  fi

  sudo chown -R root:root "$JETTY_INSTALL_DIR" || true
  rm -rf "$tmp_dir"

  log "Jetty 12 installed at $JETTY_INSTALL_DIR using manual archive installation."
  return 0
}

ensure_jetty_dependency() {
  if check_jetty_12_installed; then
    log "Jetty 12 already installed."
    return 0
  fi

  log "Jetty 12 not found. Attempting manual installation..."

  if install_jetty_manual && check_jetty_12_installed; then
    log "Jetty 12 installation successful."
    return 0
  fi

  warn "Jetty 12 installation failed."
  return 1
}

detect_package_manager() {
  if [ -n "$PKG_MANAGER" ]; then
    return 0
  fi

  for cmd in apt dnf5 dnf yum zypper pacman apk brew; do
    if command -v "$cmd" >/dev/null 2>&1; then
      PKG_MANAGER="$cmd"
      return 0
    fi
  done

  return 1
}

install_package() {
  local package="$1"

  if [ -z "$package" ]; then
    return 1
  fi

  if [ -z "$PKG_MANAGER" ]; then
    detect_package_manager || return 1
  fi

  case "$PKG_MANAGER" in
    apt)
      if [ "$APT_UPDATED" -eq 0 ]; then
        if ! sudo apt update; then
          return 1
        fi
        APT_UPDATED=1
      fi
      if ! sudo apt-get install -y "$package"; then
        return 1
      fi
      ;;
    dnf5)
      if ! sudo dnf5 install -y "$package"; then
        return 1
      fi
      ;;
    dnf)
      if ! sudo dnf install -y "$package"; then
        return 1
      fi
      ;;
    yum)
      if ! sudo yum install -y "$package"; then
        return 1
      fi
      ;;
    zypper)
      if ! sudo zypper install -y "$package"; then
        return 1
      fi
      ;;
    pacman)
      if ! sudo pacman -Sy --noconfirm "$package"; then
        return 1
      fi
      ;;
    apk)
      if ! sudo apk add --no-cache "$package"; then
        return 1
      fi
      ;;
    brew)
      if ! brew install "$package"; then
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

ensure_dependency() {
  local name="$1"
  local check_cmd="$2"
  shift 2
  local packages=("$@")

  if eval "$check_cmd"; then
    log "$name already installed."
    return 0
  fi

  log "$name not found. Attempting installation..."

  for pkg in "${packages[@]}"; do
    if install_package "$pkg"; then
      if eval "$check_cmd"; then
        log "$name installation successful via package $pkg."
        return 0
      fi
    fi
  done

  warn "Failed to install $name automatically."
  return 1
}

ensure_prerequisites() {
  if ! detect_package_manager; then
    warn "No supported package manager detected."
    return 1
  fi

  ensure_dependency "NGINX" "command -v nginx >/dev/null 2>&1" "nginx" || return 1
  ensure_jetty_dependency || return 1
  ensure_dependency "Maven" "command -v mvn >/dev/null 2>&1" "maven" || return 1
  ensure_dependency "MySQL" "command -v mysql >/dev/null 2>&1" "mysql-server" "mysql" "mariadb-server" || return 1

  return 0
}

# -----------------------
# 🔄 BACKUP FUNCTION
# -----------------------

backup_configs() {
  log "Starting backup at $TIMESTAMP"

  # NGINX
  if [ -d /etc/nginx ]; then
    log "Backing up NGINX config..."
    sudo cp -r /etc/nginx/* "$BACKUP_DIR/nginx/" || warn "NGINX backup failed"
  else
    warn "NGINX not found"
  fi

  # Jetty
  if [ -d /opt/jetty-base ]; then
    log "Backing up Jetty config..."
    sudo cp -r /opt/jetty-base "$BACKUP_DIR/jetty/" || warn "Jetty base backup failed"
    sudo cp /etc/systemd/system/jetty.service "$BACKUP_DIR/jetty/" || warn "Jetty service file missing"
  else
    warn "Jetty base not found"
  fi

  # Maven
  if [ -f ~/.m2/settings.xml ]; then
    log "Backing up Maven settings.xml..."
    cp ~/.m2/settings.xml "$BACKUP_DIR/maven/"
  else
    warn "Maven settings.xml not found"
  fi

  # MySQL
  if [ -f /etc/mysql/my.cnf ]; then
    log "Backing up MySQL config..."
    sudo cp /etc/mysql/my.cnf "$BACKUP_DIR/mysql/"
  else
    warn "MySQL config file not found"
  fi

  log "✅ Backup complete. Files saved at $BACKUP_DIR"
}

# -----------------------
# 🔁 RESTORE FUNCTION
# -----------------------

restore_configs() {
  log "Starting restoration process..."

  if ! ensure_prerequisites; then
    error_exit "Unable to ensure required software is installed."
  fi

  # NGINX
  if [ -d "$BACKUP_DIR/nginx" ]; then
    log "Restoring NGINX config..."
    sudo cp -r "$BACKUP_DIR/nginx/"* /etc/nginx/ || warn "Failed to restore NGINX"
  else
    warn "No NGINX backup found"
  fi

  # Jetty
  if [ -d "$BACKUP_DIR/jetty/jetty-base" ]; then
    log "Restoring Jetty config..."
    sudo cp -r "$BACKUP_DIR/jetty/jetty-base" /opt/
    sudo cp "$BACKUP_DIR/jetty/jetty.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable jetty
  else
    warn "Jetty backup not found"
  fi

  # Maven
  if [ -f "$BACKUP_DIR/maven/settings.xml" ]; then
    log "Restoring Maven settings.xml..."
    mkdir -p ~/.m2
    cp "$BACKUP_DIR/maven/settings.xml" ~/.m2/
  else
    warn "No Maven settings found"
  fi

  # MySQL
  if [ -f "$BACKUP_DIR/mysql/my.cnf" ]; then
    log "Restoring MySQL config..."
    sudo cp "$BACKUP_DIR/mysql/my.cnf" /etc/mysql/
  else
    warn "No MySQL config found"
  fi


  # Restart services
  log "Restarting services..."
  sudo systemctl restart nginx || warn "NGINX restart failed"
  sudo systemctl restart jetty || warn "Jetty restart failed"

  log "✅ Restoration complete."
}

# -----------------------
# 🧭 MENU & USAGE
# -----------------------

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