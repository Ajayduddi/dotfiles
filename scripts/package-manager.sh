#!/usr/bin/env bash

# AUTOMATED PACKAGE MANAGER (non_stow-aware)
# - Uses non_stow/packages/<os>-packages.txt with universal fallback
# - Saves OS-specific package list and generates a filtered universal candidate
# - Respects --dry-run and --verbose

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Globals
DRY_RUN=false
VERBOSE=false
FORCE_INSTALL=false
COMMAND=""

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
NON_STOW_DIR="$DOTFILES_DIR/non_stow"
PKG_DIR="$NON_STOW_DIR/packages"
GENERATED_DIR="$PKG_DIR/.generated"

# --- Help ---
show_help() {
  cat << HELP
🔧 AUTOMATED PACKAGE MANAGER (non_stow-aware)

USAGE:
  $0 [OPTIONS] COMMAND

COMMANDS:
  install         Install packages for detected OS (uses OS list, falls back to universal)
  save            Save currently installed packages to non_stow/packages/<os>-packages.txt
                  and build filtered candidate at non_stow/packages/.generated/universal-candidate.txt
  restore         Same as install
  update          Update package lists and system
  check           Check package installation status against chosen list

OPTIONS:
  --dry-run, -n   Simulate actions without making changes
  --verbose, -v   Enable detailed output
  --force, -f     Force install (still relies on package manager to skip installed)
  --help, -h      Show this help message

FILES:
  OS list:        non_stow/packages/<os>-packages.txt
  Universal list: non_stow/packages/universal-packages.txt (curated by you)
  Excludes file:  non_stow/packages/universal-excludes.txt (regex for filtering candidate)
  Candidate:      non_stow/packages/.generated/universal-candidate.txt (review, then promote)

Promote candidate to universal:
  cp -f "$GENERATED_DIR/universal-candidate.txt" "$PKG_DIR/universal-packages.txt"
HELP
}

# --- Arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=true; shift;;
    --verbose|-v) VERBOSE=true; shift;;
    --force|-f)   FORCE_INSTALL=true; shift;;
    --help|-h)    show_help; exit 0;;
    *)            COMMAND="${1}"; shift;;
  esac
done

# --- OS detection ---
detect_os() {
  local id="unknown"
  if command -v dnf >/dev/null 2>&1; then id=fedora
  elif command -v apt-get >/dev/null 2>&1; then id=debian
  elif command -v pacman >/dev/null 2>&1; then id=arch
  elif command -v zypper >/dev/null 2>&1; then id=opensuse
  elif command -v brew >/dev/null 2>&1; then id=mac
  fi
  echo "$id"
}

OS_ID=$(detect_os)
if [[ "$OS_ID" == unknown ]]; then
  echo -e "${RED}❌ Unsupported OS${NC}"; exit 1
fi

echo -e "${GREEN}✅ Detected OS: $OS_ID${NC}"

# --- Paths depending on OS ---
SPECIFIC_LIST="$PKG_DIR/${OS_ID}-packages.txt"
UNIVERSAL_LIST="$PKG_DIR/universal-packages.txt"
EXCLUDES_FILE="$PKG_DIR/universal-excludes.txt"
CANDIDATE_LIST="$GENERATED_DIR/universal-candidate.txt"

# --- Ensure dirs ---
ensure_dirs() {
  if [[ "$DRY_RUN" == true ]]; then
    [[ -d "$PKG_DIR" ]] || echo -e "${YELLOW}🔍 DRY RUN: Would mkdir -p '$PKG_DIR'${NC}"
    [[ -d "$GENERATED_DIR" ]] || echo -e "${YELLOW}🔍 DRY RUN: Would mkdir -p '$GENERATED_DIR'${NC}"
    return 0
  fi
  mkdir -p "$PKG_DIR" "$GENERATED_DIR"
}

# --- Create excludes template if missing ---
ensure_excludes() {
  [[ -f "$EXCLUDES_FILE" ]] && return 0
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🔍 DRY RUN: Would create excludes at '$EXCLUDES_FILE'${NC}"
    return 0
  fi
  cat > "$EXCLUDES_FILE" <<'EXCL'
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
  echo -e "${BLUE}📝 Created universal excludes template -> $EXCLUDES_FILE${NC}"
}

# --- Choose list with universal fallback ---
choose_pkg_list() {
  if [[ -s "$SPECIFIC_LIST" ]]; then
    echo "$SPECIFIC_LIST"
  elif [[ -s "$UNIVERSAL_LIST" ]]; then
    echo "$UNIVERSAL_LIST"
  else
    echo "" # none
  fi
}

# --- Save installed packages to OS-specific list and build universal candidate ---
save_packages() {
  ensure_dirs; ensure_excludes

  local cmd=""; local target="$SPECIFIC_LIST"
  case "$OS_ID" in
    fedora)
      cmd="(dnf repoquery --userinstalled --qf '%{name}\n' || repoquery --userinstalled -q --qf '%{name}\n' || rpm -qa --qf '%{NAME}\n') | sort -u"
      ;;
    opensuse)
      cmd="zypper search -i --type package --details | awk -F'|' '/^i\\+/{gsub(/^ +| +$/,"",$2); print $2}' | sort -u"
      ;;
    debian)
      cmd="comm -12 <(apt-mark showmanual | sort -u) <(dpkg-query -W -f='\${binary:Package}\n' | sort -u)"
      ;;
    arch)
      cmd="pacman -Qqe | sort -u"
      ;;
    mac)
      if brew help leaves >/dev/null 2>&1; then
        cmd="brew leaves"
      else
        cmd="brew list --formula"
      fi
      ;;
  esac

  if [[ -z "$cmd" ]]; then echo -e "${YELLOW}🟡 No save command for OS '$OS_ID'${NC}"; return 0; fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🔍 DRY RUN: Would save packages -> $target${NC}"
    echo -e "${YELLOW}🔍 DRY RUN: Would build candidate -> $CANDIDATE_LIST (filtered by $EXCLUDES_FILE, union with universal if present)${NC}"
    return 0
  fi

  # Save OS-specific list
  if bash -lc "$cmd" > "$target"; then
    local count; count=$(wc -l < "$target" | tr -d ' ')
    echo -e "${GREEN}✅ Saved $count packages -> $target${NC}"
  else
    echo -e "${RED}❌ Failed to save package list${NC}"; return 1
  fi

  # Build filtered candidate and union with curated universal
  local tmp1; tmp1=$(mktemp)
  if [[ -s "$EXCLUDES_FILE" ]]; then
    grep -Ev -f "$EXCLUDES_FILE" "$target" | sort -u > "$tmp1" || true
  else
    sort -u "$target" > "$tmp1"
  fi

  if [[ -s "$UNIVERSAL_LIST" ]]; then
    sort -u "$tmp1" "$UNIVERSAL_LIST" > "$CANDIDATE_LIST"
  else
    mv "$tmp1" "$CANDIDATE_LIST"
  fi
  rm -f "$tmp1" 2>/dev/null || true
  echo -e "${BLUE}💾 Generated universal candidate -> $CANDIDATE_LIST${NC}"
  echo -e "${BLUE}➡️  Promote when ready: cp -f '$CANDIDATE_LIST' '$UNIVERSAL_LIST'${NC}"
}

# --- Update caches ---
refresh_cache() {
  case "$OS_ID" in
    fedora)   sudo dnf makecache --refresh ;;
    debian)   sudo apt-get update ;;
    arch)     sudo pacman -Sy ;;
    opensuse) sudo zypper refresh ;;
    mac)      : ;;
  esac
}

# --- Install packages from chosen list ---
install_packages() {
  ensure_dirs
  local list; list=$(choose_pkg_list)
  if [[ -z "$list" ]]; then
    echo -e "${YELLOW}🟡 No package lists found. Expected: $SPECIFIC_LIST or $UNIVERSAL_LIST${NC}"
    return 0
  fi
  [[ "$VERBOSE" == true ]] && echo -e "${BLUE}Using package list: $list${NC}"

  # Update cache first
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🔍 DRY RUN: Would refresh package cache${NC}"
  else
    refresh_cache || true
  fi

  case "$OS_ID" in
    fedora)
      if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would xargs -a '$list' -r -n 50 sudo dnf install -y${NC}"
      else
        xargs -a "$list" -r -n 50 sudo dnf install -y || echo -e "${YELLOW}⚠️ Some packages may have failed${NC}"
      fi
      ;;
    debian)
      if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would xargs -a '$list' -r -n 50 sudo apt-get install -y${NC}"
      else
        xargs -a "$list" -r -n 50 sudo apt-get install -y || echo -e "${YELLOW}⚠️ Some packages may have failed${NC}"
      fi
      ;;
    arch)
      if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would xargs -a '$list' -r -n 50 sudo pacman -S --needed --noconfirm${NC}"
      else
        xargs -a "$list" -r -n 50 sudo pacman -S --needed --noconfirm || echo -e "${YELLOW}⚠️ Some packages may have failed${NC}"
      fi
      ;;
    opensuse)
      if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would xargs -a '$list' -r -n 50 sudo zypper --non-interactive install${NC}"
      else
        xargs -a "$list" -r -n 50 sudo zypper --non-interactive install || echo -e "${YELLOW}⚠️ Some packages may have failed${NC}"
      fi
      ;;
    mac)
      if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 DRY RUN: Would xargs -a '$list' -r -n 50 brew install${NC}"
      else
        xargs -a "$list" -r -n 50 brew install || echo -e "${YELLOW}⚠️ Some packages may have failed${NC}"
      fi
      ;;
  esac
  echo -e "${GREEN}✅ Install complete (if no errors above)${NC}"
}

# --- Check status against chosen list ---
check_packages() {
  ensure_dirs
  local list; list=$(choose_pkg_list)
  if [[ -z "$list" ]]; then
    echo -e "${YELLOW}🟡 No package lists found. Expected: $SPECIFIC_LIST or $UNIVERSAL_LIST${NC}"
    return 0
  fi
  echo -e "${BLUE}🔍 Checking package installation status against: $list${NC}"

  local total=0 installed=0 missing=()
  while IFS= read -r package; do
    [[ -z "$package" || "$package" =~ ^# ]] && continue
    total=$((total+1))
    case "$OS_ID" in
      fedora)   if rpm -q "$package" >/dev/null 2>&1; then installed=$((installed+1)); [[ "$VERBOSE" == true ]] && echo -e "${GREEN}✅ $package${NC}"; else missing+=("$package"); [[ "$VERBOSE" == true ]] && echo -e "${RED}❌ $package${NC}"; fi ;;
      debian)   if dpkg -s "$package" >/dev/null 2>&1; then installed=$((installed+1)); [[ "$VERBOSE" == true ]] && echo -e "${GREEN}✅ $package${NC}"; else missing+=("$package"); [[ "$VERBOSE" == true ]] && echo -e "${RED}❌ $package${NC}"; fi ;;
      arch)     if pacman -Q "$package" >/dev/null 2>&1; then installed=$((installed+1)); [[ "$VERBOSE" == true ]] && echo -e "${GREEN}✅ $package${NC}"; else missing+=("$package"); [[ "$VERBOSE" == true ]] && echo -e "${RED}❌ $package${NC}"; fi ;;
      opensuse) if rpm -q "$package" >/dev/null 2>&1; then installed=$((installed+1)); [[ "$VERBOSE" == true ]] && echo -e "${GREEN}✅ $package${NC}"; else missing+=("$package"); [[ "$VERBOSE" == true ]] && echo -e "${RED}❌ $package${NC}"; fi ;;
      mac)      if brew list --formula --versions "$package" >/dev/null 2>&1; then installed=$((installed+1)); [[ "$VERBOSE" == true ]] && echo -e "${GREEN}✅ $package${NC}"; else missing+=("$package"); [[ "$VERBOSE" == true ]] && echo -e "${RED}❌ $package${NC}"; fi ;;
    esac
  done < "$list"

  echo -e "${BLUE}📊 Summary: $installed/$total packages installed${NC}"
  if ((${#missing[@]} > 0)); then
    echo -e "${YELLOW}⚠️  Missing packages (${#missing[@]}):${NC}"
    for pkg in "${missing[@]}"; do echo "   - $pkg"; done
  fi
}

# --- Update system ---
update_system() {
  echo -e "${BLUE}🔄 Updating system packages...${NC}"
  if [[ "$DRY_RUN" == true ]]; then
    case "$OS_ID" in
      fedora)   echo -e "${YELLOW}🔍 DRY RUN: sudo dnf update -y${NC}" ;;
      debian)   echo -e "${YELLOW}🔍 DRY RUN: sudo apt-get update && sudo apt-get upgrade -y${NC}" ;;
      arch)     echo -e "${YELLOW}🔍 DRY RUN: sudo pacman -Syu --noconfirm${NC}" ;;
      opensuse) echo -e "${YELLOW}🔍 DRY RUN: sudo zypper refresh && sudo zypper update -y${NC}" ;;
      mac)      echo -e "${YELLOW}🔍 DRY RUN: brew update && brew upgrade${NC}" ;;
    esac
    return 0
  fi
  case "$OS_ID" in
    fedora)   sudo dnf update -y ;;
    debian)   sudo apt-get update && sudo apt-get upgrade -y ;;
    arch)     sudo pacman -Syu --noconfirm ;;
    opensuse) sudo zypper refresh && sudo zypper update -y ;;
    mac)      brew update && brew upgrade ;;
  esac
  echo -e "${GREEN}✅ System update completed${NC}"
}

# --- Main ---
case "${COMMAND:-}" in
  install) install_packages ;;
  save)    save_packages ;;
  restore) install_packages ;;
  check)   check_packages ;;
  update)  update_system ;;
  *)       echo -e "${RED}❌ Unknown or missing command: ${COMMAND:-}${NC}"; show_help; exit 1 ;;
esac