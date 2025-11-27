#!/bin/bash

# ===============================
# INFRASTRUCTURE BACKUP & RESTORE
# Author: Ajay Duddi
# Final version with simplified Jetty detection and handling, and notes for Nginx SSL certs
# ===============================

BACKUP_DIR=~/.dotfiles/infra-backup
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$BACKUP_DIR/backup-$TIMESTAMP.log"

mkdir -p "$BACKUP_DIR"/{nginx,jetty,maven,mysql}

set -euo pipefail
shopt -s nullglob

DRY_RUN=${DRY_RUN:-false}

trap 'rc=$?; echo "[ERROR] $0 failed at line $LINENO (exit $rc) - last cmd: $BASH_COMMAND" | tee -a "$LOG_FILE"' ERR

log() { echo "[INFO] $1" | tee -a "$LOG_FILE"; }
warn() { echo "[WARNING] $1" | tee -a "$LOG_FILE"; }
error_exit() { echo "[ERROR] $1" | tee -a "$LOG_FILE"; exit 1; }
would() { echo "[DRYRUN] $1" | tee -a "$LOG_FILE"; }

PKG_MANAGER=""
APT_UPDATED=0
JETTY_INSTALL_DIR="/opt/jetty"
JETTY_DOWNLOAD_URL="https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.1.4/jetty-home-12.1.4.tar.gz"

detect_package_manager() {
  if [ -n "$PKG_MANAGER" ]; then return 0; fi
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

install_package_java() {
  case "$PKG_MANAGER" in
    apt)
      sudo apt-get update
      sudo apt-get install -y openjdk-21-jdk || return 1
      ;;
    dnf|dnf5)
      sudo dnf install -y java-21-openjdk-devel || return 1
      ;;
    yum)
      sudo yum install -y java-21-openjdk-devel || return 1
      ;;
    pacman)
      sudo pacman -Sy --noconfirm jdk-openjdk || return 1
      ;;
    zypper)
      sudo zypper install -y java-21-openjdk-devel || return 1
      ;;
    *)
      warn "Java install unsupported on this package manager."
      return 1
      ;;
  esac
  return 0
}

ensure_java() {
  if command -v java >/dev/null 2>&1; then
    log "Java already installed."
    return 0
  fi
  log "Java not found, installing OpenJDK 21..."
  if [ -z "$PKG_MANAGER" ]; then detect_package_manager || { warn "No package manager to install Java"; return 1; }; fi
  if install_package_java && command -v java >/dev/null 2>&1; then
    log "Java installation successful."
    return 0
  fi
  warn "Java installation failed."
  return 1
}

check_jetty_installed() {
  log "Checking if Jetty is installed..."

  if [[ -d "$JETTY_INSTALL_DIR" && -f "$JETTY_INSTALL_DIR/start.jar" ]]; then
    log "Jetty installation detected at $JETTY_INSTALL_DIR."
    return 0
  fi

  log "Jetty not detected."
  return 1
}

install_jetty_manual() {
  local url="$JETTY_DOWNLOAD_URL"
  local tmp_dir archive_path extract_dir jetty_src

  if [ -z "$url" ]; then
    warn "Jetty download URL not set."
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    warn "Neither curl nor wget available for Jetty download."
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    would "Download Jetty from $url"
    would "Extract Jetty archive"
    would "Backup existing Jetty directory ($JETTY_INSTALL_DIR) if it exists"
    would "Move extracted Jetty to $JETTY_INSTALL_DIR"
    would "Create jetty CLI wrapper at /usr/local/bin/jetty"
    return 0
  fi

  tmp_dir=$(mktemp -d) || return 1
  archive_path="$tmp_dir/jetty.tar.gz"
  extract_dir="$tmp_dir/extracted"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$archive_path" || { warn "Curl download failed"; rm -rf "$tmp_dir"; return 1; }
  else
    wget -q "$url" -O "$archive_path" || { warn "Wget download failed"; rm -rf "$tmp_dir"; return 1; }
  fi

  mkdir -p "$extract_dir"
  tar -xzf "$archive_path" -C "$extract_dir" || { warn "Jetty extraction failed"; rm -rf "$tmp_dir"; return 1; }

  jetty_src=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  if [[ -z "$jetty_src" ]]; then
    warn "No install directory found in Jetty archive"
    rm -rf "$tmp_dir"
    return 1
  fi

  if [[ -d "$JETTY_INSTALL_DIR" ]]; then
    local backup_dir="${JETTY_INSTALL_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
    log "Backing up existing Jetty directory to $backup_dir"
    sudo mv "$JETTY_INSTALL_DIR" "$backup_dir" || { warn "Jetty backup failed"; rm -rf "$tmp_dir"; return 1; }
  fi

  sudo mv "$jetty_src" "$JETTY_INSTALL_DIR" || { warn "Failed to move Jetty"; rm -rf "$tmp_dir"; return 1; }
  sudo chown -R root:root "$JETTY_INSTALL_DIR" || warn "Failed to set ownership for Jetty"
  sudo chmod -R a+rX "$JETTY_INSTALL_DIR" || warn "Failed to set permissions for Jetty"

  # Create jetty CLI wrapper
  sudo tee /usr/local/bin/jetty > /dev/null <<'EOF'
#!/bin/bash
java -jar /opt/jetty/start.jar "$@"
EOF
  sudo chmod +x /usr/local/bin/jetty

  rm -rf "$tmp_dir"

  log "Jetty installed successfully at $JETTY_INSTALL_DIR"
  sleep 5
  return 0
}

ensure_jetty_dependency() {
  ensure_java || warn "Java missing or failed install; Jetty may not work correctly"
  if check_jetty_installed; then
    log "Jetty already installed."
    return 0
  fi
  log "Jetty not found; installing..."
  install_jetty_manual
  if check_jetty_installed; then
    log "Jetty installation successful."
    return 0
  else
    warn "Jetty installation failed."
    return 1
  fi
}

ensure_prerequisites() {
  if ! detect_package_manager; then
    warn "No supported package manager detected."
    return 1
  fi

  ensure_dependency "NGINX" "command -v nginx >/dev/null 2>&1" "nginx" || warn "NGINX missing or install failed."
  ensure_jetty_dependency || warn "Jetty missing or install failed."
  ensure_dependency "Maven" "command -v mvn >/dev/null 2>&1" "maven" || warn "Maven missing or install failed."
  ensure_dependency "MySQL" "command -v mysql >/dev/null 2>&1" "mysql-server" "mysql" "mariadb-server" || warn "MySQL missing or install failed."

  return 0
}

backup_configs() {
  log "Starting backup at $TIMESTAMP"

  files=(/etc/nginx/*)
  if (( ${#files[@]} )); then
    log "Backing up NGINX config..."
    sudo cp -r /etc/nginx/* "$BACKUP_DIR/nginx/" || warn "NGINX backup failed"
  else
    warn "NGINX directory empty or missing"
  fi

  if [[ -d /opt/jetty ]]; then
    log "Backing up Jetty config..."
    sudo cp -r /opt/jetty "$BACKUP_DIR/jetty/" || warn "Jetty backup failed"
  else
    warn "Jetty base not found"
  fi

  if [[ -f /etc/systemd/system/jetty.service ]]; then
    sudo cp /etc/systemd/system/jetty.service "$BACKUP_DIR/jetty/" || warn "Jetty systemd service backup failed"
  fi

  if [[ -f ~/.m2/settings.xml ]]; then
    log "Backing up Maven settings.xml..."
    mkdir -p "$BACKUP_DIR/maven"
    cp ~/.m2/settings.xml "$BACKUP_DIR/maven/"
  else
    warn "Maven settings.xml not found"
  fi

  if [[ -f /etc/mysql/my.cnf ]]; then
    sudo cp /etc/mysql/my.cnf "$BACKUP_DIR/mysql/"
  elif [[ -f /etc/my.cnf ]]; then
    sudo cp /etc/my.cnf "$BACKUP_DIR/mysql/"
  else
    warn "MySQL config not found"
  fi

  log "✅ Backup complete. Files saved at $BACKUP_DIR"
}

restore_configs() {
  log "Starting restoration process..."

  ensure_prerequisites || warn "Some prerequisites failed; continuing..."

  files=( "$BACKUP_DIR"/nginx/* )
  if (( ${#files[@]} )); then
    log "Restoring NGINX config..."
    sudo cp -r "$BACKUP_DIR/nginx/"* /etc/nginx/ || warn "NGINX restore failed"
  else
    warn "No NGINX backup files found"
  fi

  if [[ -d "$BACKUP_DIR/jetty/jetty" ]]; then
    log "Restoring Jetty config..."
    sudo cp -r "$BACKUP_DIR/jetty/jetty" /opt/
    if [[ -f "$BACKUP_DIR/jetty/jetty.service" ]]; then
      sudo cp "$BACKUP_DIR/jetty/jetty.service" /etc/systemd/system/
      sudo systemctl daemon-reload || warn "systemd daemon-reload failed"
      sudo systemctl enable jetty || warn "Jetty service enable failed"
    fi
  else
    warn "No Jetty backup found"
  fi

  if [[ -f "$BACKUP_DIR/maven/settings.xml" ]]; then
    log "Restoring Maven settings.xml..."
    mkdir -p ~/.m2
    cp "$BACKUP_DIR/maven/settings.xml" ~/.m2/
  else
    warn "No Maven backup found"
  fi

  if [[ -f "$BACKUP_DIR/mysql/my.cnf" ]]; then
    log "Restoring MySQL config..."
    sudo cp "$BACKUP_DIR/mysql/my.cnf" /etc/mysql/ 2>/dev/null || sudo cp "$BACKUP_DIR/mysql/my.cnf" /etc/
  else
    warn "No MySQL backup found"
  fi

  log "Reloading systemd and restarting services..."

  if [[ "$DRY_RUN" == "true" ]]; then
    would "sudo systemctl daemon-reload"
    would "sudo systemctl restart nginx"
    would "sudo systemctl restart jetty"
  else
    sudo systemctl daemon-reload || warn "systemd daemon-reload failed"
    sudo systemctl restart nginx || warn "NGINX restart failed or systemd unavailable"
    sudo systemctl restart jetty || warn "Jetty restart failed or systemd unavailable"
  fi

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
