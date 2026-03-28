#!/bin/bash
# Infrastructure backup/restore script for nginx, jetty, maven, mysql, and docker config snapshots.
# Primary stages: parse action, verify dependencies, run backup or restore, and log all operations.
# Safety model: supports --dry-run and uses explicit preflight checks before privileged changes.

BACKUP_DIR=~/.dotfiles/infra-backup
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$BACKUP_DIR/backup-$TIMESTAMP.log"

mkdir -p "$BACKUP_DIR"/{nginx,jetty,maven,mysql}
mkdir -p "$BACKUP_DIR"/docker/{engine,user,desktop}

set -euo pipefail
shopt -s nullglob

DRY_RUN=${DRY_RUN:-false}
ACTION=""

# Capture the failing command context and append it to the backup log.
on_error() {
  local rc=$?
  echo "[ERROR] $0 failed at line ${BASH_LINENO[0]} (exit $rc) - last cmd: $BASH_COMMAND" | tee -a "$LOG_FILE"
}
trap on_error ERR

# Emit a formatted log line for status, warnings, errors, or dry-run output.
log() { echo "[INFO] $1" | tee -a "$LOG_FILE"; }
# Emit a formatted log line for status, warnings, errors, or dry-run output.
warn() { echo "[WARNING] $1" | tee -a "$LOG_FILE"; }
# Emit a formatted log line for status, warnings, errors, or dry-run output.
error_exit() { echo "[ERROR] $1" | tee -a "$LOG_FILE"; exit 1; }
# Emit a formatted log line for status, warnings, errors, or dry-run output.
would() { echo "[DRYRUN] $1" | tee -a "$LOG_FILE"; }

# Print command usage and supported action examples.
usage() {
  cat <<'USAGE'
Usage: infra-backup.sh [--dry-run|-n] {backup|restore}
Backs up/restores nginx, jetty, maven, mysql, and docker configs.

Examples:
  infra-backup.sh backup
  infra-backup.sh restore
  infra-backup.sh --dry-run backup
USAGE
}

# Parse CLI flags and update runtime options used by the script.
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run|-n)
        DRY_RUN=true
        ;;
      backup|restore)
        ACTION="$1"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        error_exit "Unknown option/command: $1"
        ;;
    esac
    shift
  done
}

PKG_MANAGER=""
APT_UPDATED=0
JETTY_INSTALL_DIR="/opt/jetty"
JETTY_DOWNLOAD_URL="https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.1.4/jetty-home-12.1.4.tar.gz"
DOCKER_ENGINE_INSTALL_URL="https://get.docker.com"
DOCKER_DESKTOP_DOCS_URL="https://docs.docker.com/desktop/"

# Docker backup exclusion patterns to avoid credential leaks and large runtime payloads.
DOCKER_BACKUP_EXCLUDE_PATTERNS=(
  "config.json"
  "*.pem"
  "*.key"
  "key.json"
  "certs.d/*/client.*"
  "trust/private/*"
  "desktop/vms/**"
  ".docker/desktop/vms/**"
  "desktop/docker-desktop-data/**"
  ".docker/desktop/docker-desktop-data/**"
  "desktop-data/**"
  ".docker/desktop-data/**"
  "desktop/log/**"
  ".docker/desktop/log/**"
  "desktop/tmp/**"
  ".docker/desktop/tmp/**"
  "*.sock"
  "**/*.sock"
  "Docker.raw"
  "**/Docker.raw"
  "*.raw"
  "**/*.raw"
  "*.qcow2"
  "**/*.qcow2"
  "*.img"
  "**/*.img"
)

# Detect runtime platform/tooling details used to select execution paths.
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

# Install required packages or runtimes for this restore/workflow stage.
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

# Ensure required runtime/tooling is available; warn/continue when allowed.
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

# Install required packages or runtimes for this restore/workflow stage.
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

# Ensure required runtime/tooling is available; warn/continue when allowed.
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

# Validate prerequisites or runtime state before continuing.
check_jetty_installed() {
  log "Checking if Jetty is installed..."

  if [[ -d "$JETTY_INSTALL_DIR" && -f "$JETTY_INSTALL_DIR/start.jar" ]]; then
    log "Jetty installation detected at $JETTY_INSTALL_DIR."
    return 0
  fi

  log "Jetty not detected."
  return 1
}

# Install required packages or runtimes for this restore/workflow stage.
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
    local backup_dir
    backup_dir="${JETTY_INSTALL_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
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

# Ensure required runtime/tooling is available; warn/continue when allowed.
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

# Detect runtime platform/tooling details used to select execution paths.
get_os_family() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin) echo "mac" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

# Return computed metadata or resolved paths needed by later stages.
list_docker_desktop_paths() {
  local os_family
  os_family="$(get_os_family)"
  case "$os_family" in
    mac)
      printf '%s\n' \
        "$HOME/Library/Group Containers/group.com.docker" \
        "$HOME/Library/Containers/com.docker.docker" \
        "$HOME/Library/Application Support/Docker Desktop"
      ;;
    linux)
      printf '%s\n' \
        "$HOME/.docker/desktop" \
        "$HOME/.config/docker-desktop"
      ;;
  esac
}

# Build rsync/tar exclusion args from configured Docker backup patterns.
build_docker_exclude_args() {
  local -n _rsync_ref="$1"
  local -n _tar_ref="$2"
  local pattern
  for pattern in "${DOCKER_BACKUP_EXCLUDE_PATTERNS[@]}"; do
    _rsync_ref+=("--exclude=$pattern")
    _tar_ref+=("--exclude=$pattern")
  done
}

# Build tar exclusion args from configured Docker backup patterns.
build_docker_tar_exclude_args() {
  # shellcheck disable=SC2178
  local -n _tar_ref="$1"
  local pattern
  for pattern in "${DOCKER_BACKUP_EXCLUDE_PATTERNS[@]}"; do
    _tar_ref+=("--exclude=$pattern")
  done
}

# Validate prerequisites or runtime state before continuing.
check_docker_engine_installed() {
  command -v docker >/dev/null 2>&1
}

# Validate prerequisites or runtime state before continuing.
check_docker_desktop_installed() {
  local os_family
  os_family="$(get_os_family)"

  if command -v docker-desktop >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$os_family" == "mac" && -d /Applications/Docker.app ]]; then
    return 0
  fi

  return 1
}

# Install required packages or runtimes for this restore/workflow stage.
install_docker_engine_fallback() {
  if [[ "$DRY_RUN" == "true" ]]; then
    would "curl -fsSL '$DOCKER_ENGINE_INSTALL_URL' | sudo sh"
    would "wget -qO- '$DOCKER_ENGINE_INSTALL_URL' | sudo sh"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$DOCKER_ENGINE_INSTALL_URL" | sudo sh || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$DOCKER_ENGINE_INSTALL_URL" | sudo sh || return 1
  else
    warn "Neither curl nor wget found for Docker Engine fallback install."
    return 1
  fi

  check_docker_engine_installed
}

# Ensure required runtime/tooling is available; warn/continue when allowed.
ensure_docker_engine_dependency() {
  local candidates=()

  if check_docker_engine_installed; then
    log "Docker Engine already installed."
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    would "Attempt Docker Engine install via package manager"
    would "Fallback Docker Engine install via '$DOCKER_ENGINE_INSTALL_URL'"
    return 0
  fi

  log "Docker Engine not found; installing..."
  if [ -z "$PKG_MANAGER" ]; then
    detect_package_manager || warn "No package manager detected for Docker Engine install."
  fi

  case "$PKG_MANAGER" in
    apt) candidates=("docker.io" "docker-ce") ;;
    dnf|dnf5|yum|zypper) candidates=("docker-ce" "docker") ;;
    pacman) candidates=("docker") ;;
    apk) candidates=("docker" "docker-cli") ;;
    brew) candidates=("docker") ;;
    *) candidates=("docker") ;;
  esac

  for pkg in "${candidates[@]}"; do
    if install_package "$pkg" && check_docker_engine_installed; then
      log "Docker Engine installed via $pkg."
      return 0
    fi
  done

  warn "Package-manager install for Docker Engine failed; trying official installer fallback."
  if install_docker_engine_fallback && check_docker_engine_installed; then
    log "Docker Engine installed via official fallback."
    return 0
  fi

  warn "Docker Engine install failed."
  return 1
}

# Install required packages or runtimes for this restore/workflow stage.
install_docker_desktop_fallback() {
  local os_family arch_slug dmg_url dmg_path
  os_family="$(get_os_family)"

  if [[ "$DRY_RUN" == "true" ]]; then
    case "$os_family" in
      mac)
        would "Download and install Docker Desktop from official macOS DMG"
        ;;
      linux)
        would "Manual Docker Desktop install may be required: ${DOCKER_DESKTOP_DOCS_URL}install/linux/"
        ;;
      *)
        would "Manual Docker Desktop install may be required: $DOCKER_DESKTOP_DOCS_URL"
        ;;
    esac
    return 0
  fi

  case "$os_family" in
    mac)
      if ! command -v hdiutil >/dev/null 2>&1; then
        warn "hdiutil not available; cannot run Docker Desktop DMG fallback install."
        return 1
      fi

      case "$(uname -m 2>/dev/null || true)" in
        arm64|aarch64) arch_slug="arm64" ;;
        *) arch_slug="amd64" ;;
      esac
      dmg_url="https://desktop.docker.com/mac/main/${arch_slug}/Docker.dmg"
      dmg_path="/tmp/docker-desktop.dmg"

      if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$dmg_url" -o "$dmg_path" || return 1
      elif command -v wget >/dev/null 2>&1; then
        wget -q "$dmg_url" -O "$dmg_path" || return 1
      else
        warn "Neither curl nor wget found for Docker Desktop fallback install."
        return 1
      fi

      hdiutil attach "$dmg_path" -nobrowse -quiet || { rm -f "$dmg_path"; return 1; }
      sudo cp -R "/Volumes/Docker/Docker.app" /Applications/ || {
        hdiutil detach "/Volumes/Docker" -quiet >/dev/null 2>&1 || true
        rm -f "$dmg_path"
        return 1
      }
      hdiutil detach "/Volumes/Docker" -quiet >/dev/null 2>&1 || true
      rm -f "$dmg_path"
      ;;
    linux)
      warn "Automated Docker Desktop fallback is not available on this Linux host. Use: ${DOCKER_DESKTOP_DOCS_URL}install/linux/"
      return 1
      ;;
    *)
      warn "Docker Desktop fallback unsupported on this OS. Use: $DOCKER_DESKTOP_DOCS_URL"
      return 1
      ;;
  esac

  check_docker_desktop_installed
}

# Ensure required runtime/tooling is available; warn/continue when allowed.
ensure_docker_desktop_dependency() {
  if check_docker_desktop_installed; then
    log "Docker Desktop already installed."
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    would "Attempt Docker Desktop install via package manager"
    install_docker_desktop_fallback || true
    return 0
  fi

  log "Docker Desktop not found; installing..."
  if [ -z "$PKG_MANAGER" ]; then
    detect_package_manager || warn "No package manager detected for Docker Desktop install."
  fi

  case "$PKG_MANAGER" in
    brew)
      brew install --cask docker || warn "brew cask install for Docker Desktop failed"
      ;;
    apt|dnf|dnf5|yum|zypper|pacman|apk)
      install_package "docker-desktop" || warn "Package-manager install for Docker Desktop failed"
      ;;
    *)
      warn "Package-manager install for Docker Desktop not supported on this host."
      ;;
  esac

  if check_docker_desktop_installed; then
    log "Docker Desktop installed via package manager."
    return 0
  fi

  warn "Package-manager install for Docker Desktop failed; trying official/recommended fallback."
  if install_docker_desktop_fallback && check_docker_desktop_installed; then
    log "Docker Desktop installed via fallback."
    return 0
  fi

  warn "Docker Desktop install failed."
  return 1
}

# Back up current system or configuration state into snapshot files.
backup_docker_configs() {
  local docker_backup_dir="$BACKUP_DIR/docker"
  local engine_backup_dir="$docker_backup_dir/engine"
  local user_backup_dir="$docker_backup_dir/user"
  local desktop_backup_dir="$docker_backup_dir/desktop"
  local desktop_found=false
  local desktop_path rel_path
  local rsync_excludes=()
  local tar_excludes=()

  log "Backing up Docker config..."
  build_docker_exclude_args rsync_excludes tar_excludes
  if [[ "$DRY_RUN" == "true" ]]; then
    would "mkdir -p '$engine_backup_dir' '$user_backup_dir' '$desktop_backup_dir'"
  else
    mkdir -p "$engine_backup_dir" "$user_backup_dir" "$desktop_backup_dir"
  fi

  if [[ -d /etc/docker ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp -a /etc/docker/. '$engine_backup_dir/'"
    else
      sudo cp -a /etc/docker/. "$engine_backup_dir/" || warn "Docker Engine config backup failed"
    fi
  else
    warn "Docker Engine config directory not found: /etc/docker"
  fi

  if [[ -d "$HOME/.docker" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "Backup ~/.docker to '$user_backup_dir/' excluding credentials and runtime payloads"
    else
      if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "${rsync_excludes[@]}" "$HOME/.docker/" "$user_backup_dir/" || warn "Docker user config backup failed via rsync"
      elif command -v tar >/dev/null 2>&1; then
        (cd "$HOME/.docker" && tar "${tar_excludes[@]}" -cf - .) | (cd "$user_backup_dir" && tar -xf -) || warn "Docker user config backup failed via tar"
      else
        warn "Neither rsync nor tar found; cannot back up ~/.docker with credential exclusions"
      fi
    fi
  else
    warn "Docker user config directory not found: $HOME/.docker"
  fi

  while IFS= read -r desktop_path; do
    [[ -n "$desktop_path" ]] || continue
    [[ -e "$desktop_path" ]] || continue
    desktop_found=true
    rel_path="${desktop_path#"$HOME"/}"
    rel_path="${rel_path#/}"
    if [[ "$DRY_RUN" == "true" ]]; then
      would "Backup Docker Desktop config '$desktop_path' -> '$desktop_backup_dir/home/$rel_path' (excluding runtime payloads)"
    else
      mkdir -p "$desktop_backup_dir/home"
      (cd "$HOME" && tar "${tar_excludes[@]}" -cf - "$rel_path") | (cd "$desktop_backup_dir/home" && tar -xf -) || warn "Docker Desktop config backup failed for $desktop_path"
    fi
  done < <(list_docker_desktop_paths)

  if [[ "$desktop_found" != true ]]; then
    warn "Docker Desktop config paths not found on this host"
  fi
}

# Restore saved state/artifacts back onto the current system.
restore_docker_configs() {
  local docker_backup_dir="$BACKUP_DIR/docker"
  local engine_backup_dir="$docker_backup_dir/engine"
  local user_backup_dir="$docker_backup_dir/user"
  local desktop_backup_home="$docker_backup_dir/desktop/home"
  local engine_has_data=false
  local user_has_data=false

  log "Restoring Docker config..."

  if [[ -d "$engine_backup_dir" ]] && [[ -n "$(find "$engine_backup_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    engine_has_data=true
  fi

  if [[ "$engine_has_data" == true ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo mkdir -p /etc/docker"
      would "sudo cp -a '$engine_backup_dir'/. /etc/docker/"
    else
      sudo mkdir -p /etc/docker
      sudo cp -a "$engine_backup_dir"/. /etc/docker/ || warn "Docker Engine config restore failed"
    fi
  else
    warn "No Docker Engine backup found"
  fi

  if [[ -d "$user_backup_dir" ]] && [[ -n "$(find "$user_backup_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    user_has_data=true
  fi

  if [[ "$user_has_data" == true ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "mkdir -p '$HOME/.docker'"
      would "Restore '$user_backup_dir/' -> '$HOME/.docker/'"
    else
      mkdir -p "$HOME/.docker"
      if command -v rsync >/dev/null 2>&1; then
        rsync -a "$user_backup_dir"/ "$HOME/.docker/" || warn "Docker user config restore failed via rsync"
      elif command -v tar >/dev/null 2>&1; then
        (cd "$user_backup_dir" && tar -cf - .) | (cd "$HOME/.docker" && tar -xf -) || warn "Docker user config restore failed via tar"
      else
        warn "Neither rsync nor tar found; cannot restore ~/.docker"
      fi
    fi
  else
    warn "No Docker user backup found"
  fi

  if [[ -d "$desktop_backup_home" ]] && [[ -n "$(find "$desktop_backup_home" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "Restore Docker Desktop config from '$desktop_backup_home/' -> '$HOME/'"
    else
      (cd "$desktop_backup_home" && tar -cf - .) | (cd "$HOME" && tar -xf -) || warn "Docker Desktop config restore failed"
    fi
  else
    warn "No Docker Desktop backup found"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    would "sudo systemctl restart docker (if systemd/docker service exists)"
  else
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^docker\.service'; then
      sudo systemctl restart docker || warn "Docker service restart failed"
    fi
  fi
}

# Ensure required runtime/tooling is available; warn/continue when allowed.
ensure_prerequisites() {
  if ! detect_package_manager; then
    warn "No supported package manager detected."
    return 1
  fi

  ensure_dependency "NGINX" "command -v nginx >/dev/null 2>&1" "nginx" || warn "NGINX missing or install failed."
  ensure_jetty_dependency || warn "Jetty missing or install failed."
  ensure_dependency "Maven" "command -v mvn >/dev/null 2>&1" "maven" || warn "Maven missing or install failed."
  ensure_dependency "MySQL" "command -v mysql >/dev/null 2>&1" "mysql-server" "mysql" "mariadb-server" || warn "MySQL missing or install failed."
  ensure_docker_engine_dependency || warn "Docker Engine missing or install failed."
  ensure_docker_desktop_dependency || warn "Docker Desktop missing or install failed."

  return 0
}

# Run preflight checks before making system or firewall changes.
preflight_checks() {
  if [[ -z "$ACTION" ]]; then
    usage
    error_exit "Please specify an action: backup or restore"
  fi

  for cmd in mkdir cp; do
    command -v "$cmd" >/dev/null 2>&1 || error_exit "Required command missing: $cmd"
  done

  if ! command -v tar >/dev/null 2>&1; then
    warn "tar not found; restore snapshots will be unavailable"
  fi

  if [[ "$DRY_RUN" != "true" && "$EUID" -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || error_exit "sudo is required for non-dry-run operations"
    sudo -v || error_exit "Unable to obtain sudo privileges"
  fi

  if [[ "$ACTION" == "restore" && ! -d "$BACKUP_DIR" ]]; then
    warn "Backup directory not found: $BACKUP_DIR"
  fi
}

# Snapshot target paths before restore so rollback artifacts are available.
snapshot_restore_targets() {
  local snapshot_dir="$BACKUP_DIR/restore-pre-snapshot-$TIMESTAMP"
  log "Creating pre-restore snapshot at $snapshot_dir"

  if [[ "$DRY_RUN" == "true" ]]; then
    would "mkdir -p '$snapshot_dir'"
    would "Snapshot /etc/nginx, /opt/jetty, jetty.service, mysql config, /etc/docker, ~/.docker, Docker Desktop paths, and ~/.m2/settings.xml if present"
    return 0
  fi

  mkdir -p "$snapshot_dir"

  if [[ -d /etc/nginx ]]; then
    sudo tar -czf "$snapshot_dir/etc-nginx.tar.gz" -C / etc/nginx 2>/dev/null || warn "Failed to snapshot /etc/nginx"
  fi

  if [[ -d /opt/jetty ]]; then
    sudo tar -czf "$snapshot_dir/opt-jetty.tar.gz" -C / opt/jetty 2>/dev/null || warn "Failed to snapshot /opt/jetty"
  fi

  if [[ -f /etc/systemd/system/jetty.service ]]; then
    sudo tar -czf "$snapshot_dir/jetty-service.tar.gz" -C / etc/systemd/system/jetty.service 2>/dev/null || warn "Failed to snapshot jetty.service"
  fi

  if [[ -f /etc/mysql/my.cnf ]]; then
    sudo tar -czf "$snapshot_dir/mysql-mycnf.tar.gz" -C / etc/mysql/my.cnf 2>/dev/null || warn "Failed to snapshot /etc/mysql/my.cnf"
  elif [[ -f /etc/my.cnf ]]; then
    sudo tar -czf "$snapshot_dir/mysql-mycnf-alt.tar.gz" -C / etc/my.cnf 2>/dev/null || warn "Failed to snapshot /etc/my.cnf"
  fi

  if [[ -f "$HOME/.m2/settings.xml" ]]; then
    tar -czf "$snapshot_dir/home-m2-settings.tar.gz" -C "$HOME" .m2/settings.xml 2>/dev/null || warn "Failed to snapshot ~/.m2/settings.xml"
  fi

  if [[ -d /etc/docker ]]; then
    sudo tar -czf "$snapshot_dir/etc-docker.tar.gz" -C / etc/docker 2>/dev/null || warn "Failed to snapshot /etc/docker"
  fi

  if [[ -d "$HOME/.docker" ]]; then
    local snapshot_tar_excludes=()
    build_docker_tar_exclude_args snapshot_tar_excludes
    tar "${snapshot_tar_excludes[@]}" -czf "$snapshot_dir/home-docker.tar.gz" -C "$HOME" .docker 2>/dev/null || warn "Failed to snapshot ~/.docker"
  fi

  local desktop_path rel_path safe_name
  local desktop_snapshot_tar_excludes=()
  build_docker_tar_exclude_args desktop_snapshot_tar_excludes
  while IFS= read -r desktop_path; do
    [[ -n "$desktop_path" ]] || continue
    [[ -e "$desktop_path" ]] || continue
    rel_path="${desktop_path#"$HOME"/}"
    rel_path="${rel_path#/}"
    safe_name=$(printf '%s' "$rel_path" | tr '/ ' '__')
    tar "${desktop_snapshot_tar_excludes[@]}" -czf "$snapshot_dir/docker-desktop-${safe_name}.tar.gz" -C "$HOME" "$rel_path" 2>/dev/null || warn "Failed to snapshot Docker Desktop path: $desktop_path"
  done < <(list_docker_desktop_paths)
}

# Back up current system or configuration state into snapshot files.
backup_configs() {
  log "Starting backup at $TIMESTAMP"

  files=(/etc/nginx/*)
  if (( ${#files[@]} )); then
    log "Backing up NGINX config..."
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp -r /etc/nginx/* '$BACKUP_DIR/nginx/'"
    else
      sudo cp -r /etc/nginx/* "$BACKUP_DIR/nginx/" || warn "NGINX backup failed"
    fi
  else
    warn "NGINX directory empty or missing"
  fi

  if [[ -d /opt/jetty ]]; then
    log "Backing up Jetty config..."
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp -r /opt/jetty '$BACKUP_DIR/jetty/'"
    else
      sudo cp -r /opt/jetty "$BACKUP_DIR/jetty/" || warn "Jetty backup failed"
    fi
  else
    warn "Jetty base not found"
  fi

  if [[ -f /etc/systemd/system/jetty.service ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp /etc/systemd/system/jetty.service '$BACKUP_DIR/jetty/'"
    else
      sudo cp /etc/systemd/system/jetty.service "$BACKUP_DIR/jetty/" || warn "Jetty systemd service backup failed"
    fi
  fi

  if [[ -f ~/.m2/settings.xml ]]; then
    log "Backing up Maven settings.xml..."
    if [[ "$DRY_RUN" == "true" ]]; then
      would "mkdir -p '$BACKUP_DIR/maven'"
      would "cp ~/.m2/settings.xml '$BACKUP_DIR/maven/'"
    else
      mkdir -p "$BACKUP_DIR/maven"
      cp ~/.m2/settings.xml "$BACKUP_DIR/maven/"
    fi
  else
    warn "Maven settings.xml not found"
  fi

  if [[ -f /etc/mysql/my.cnf ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp /etc/mysql/my.cnf '$BACKUP_DIR/mysql/'"
    else
      sudo cp /etc/mysql/my.cnf "$BACKUP_DIR/mysql/"
    fi
  elif [[ -f /etc/my.cnf ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp /etc/my.cnf '$BACKUP_DIR/mysql/'"
    else
      sudo cp /etc/my.cnf "$BACKUP_DIR/mysql/"
    fi
  else
    warn "MySQL config not found"
  fi

  backup_docker_configs

  log "✅ Backup complete. Files saved at $BACKUP_DIR"
}

# Restore saved state/artifacts back onto the current system.
restore_configs() {
  log "Starting restoration process..."

  ensure_prerequisites || warn "Some prerequisites failed; continuing..."
  snapshot_restore_targets

  files=( "$BACKUP_DIR"/nginx/* )
  if (( ${#files[@]} )); then
    log "Restoring NGINX config..."
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp -r '$BACKUP_DIR/nginx/'* /etc/nginx/"
    else
      sudo cp -r "$BACKUP_DIR/nginx/"* /etc/nginx/ || warn "NGINX restore failed"
    fi
  else
    warn "No NGINX backup files found"
  fi

  if [[ -d "$BACKUP_DIR/jetty/jetty" ]]; then
    log "Restoring Jetty config..."
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp -r '$BACKUP_DIR/jetty/jetty' /opt/"
      if [[ -f "$BACKUP_DIR/jetty/jetty.service" ]]; then
        would "sudo cp '$BACKUP_DIR/jetty/jetty.service' /etc/systemd/system/"
        would "sudo systemctl daemon-reload"
        would "sudo systemctl enable jetty"
      fi
    else
      sudo cp -r "$BACKUP_DIR/jetty/jetty" /opt/
      if [[ -f "$BACKUP_DIR/jetty/jetty.service" ]]; then
        sudo cp "$BACKUP_DIR/jetty/jetty.service" /etc/systemd/system/
        sudo systemctl daemon-reload || warn "systemd daemon-reload failed"
        sudo systemctl enable jetty || warn "Jetty service enable failed"
      fi
    fi
  else
    warn "No Jetty backup found"
  fi

  if [[ -f "$BACKUP_DIR/maven/settings.xml" ]]; then
    log "Restoring Maven settings.xml..."
    if [[ "$DRY_RUN" == "true" ]]; then
      would "mkdir -p ~/.m2"
      would "cp '$BACKUP_DIR/maven/settings.xml' ~/.m2/"
    else
      mkdir -p ~/.m2
      cp "$BACKUP_DIR/maven/settings.xml" ~/.m2/
    fi
  else
    warn "No Maven backup found"
  fi

  if [[ -f "$BACKUP_DIR/mysql/my.cnf" ]]; then
    log "Restoring MySQL config..."
    if [[ "$DRY_RUN" == "true" ]]; then
      would "sudo cp '$BACKUP_DIR/mysql/my.cnf' /etc/mysql/ || sudo cp '$BACKUP_DIR/mysql/my.cnf' /etc/"
    else
      sudo cp "$BACKUP_DIR/mysql/my.cnf" /etc/mysql/ 2>/dev/null || sudo cp "$BACKUP_DIR/mysql/my.cnf" /etc/
    fi
  else
    warn "No MySQL backup found"
  fi

  restore_docker_configs

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

parse_args "$@"
preflight_checks

case "${ACTION:-}" in
  backup)
    backup_configs
    ;;
  restore)
    restore_configs
    ;;
  *)
    usage
    exit 1
    ;;
esac
