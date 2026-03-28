#!/usr/bin/env bash
# Pre-push sensitive data scan for tracked + working tree files.
# Blocks push on high-confidence secret patterns and reports risky hygiene issues.

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

HIGH_CONF_REGEX='-----BEGIN (RSA|EC|OPENSSH|PGP|PRIVATE) KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|authorization:[[:space:]]*bearer[[:space:]]+[A-Za-z0-9._-]{16,}|(_authToken|aws_secret_access_key|aws_access_key_id)[[:space:]]*[:=][[:space:]]*[^[:space:]]+|((api[_-]?key|token|secret|password)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_+=/-]{20,})'
# Allowlist for non-secret placeholders/schema descriptors that should not block push.
HIGH_CONF_ALLOWLIST_REGEX='xox[baprs]-your-[a-z-]*token|(^|[^A-Za-z])(example|placeholder)([^A-Za-z]|$)|secret:[[:space:]]*[A-Za-z0-9_.-]+\.(personal_access_token|api_key|token|secret|password)$|binary file matches'
RISKY_PATH_REGEX='(^|/)(\.bash_history|\.zsh_history|id_rsa|id_ed25519|\.env(\..*)?|\.npmrc|\.pypirc|\.netrc|\.pgpass)$|(\.pem|\.key|\.p12|\.pfx|\.kdbx|\.ovpn)$|(^|/)\.aws/|(^|/)\.gnupg/|(^|/)\.ssh/|(^|/)\.kube/|(^|/)docker/config\.json$|(^|/)settings\.xml$|(^|/)my\.cnf$'

FAIL_COUNT=0
WARN_COUNT=0

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { printf '[FAIL] %s\n' "$*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# Print first N lines from a multiline string with an optional prefix.
print_limited() {
  local text="${1:-}"
  local limit="${2:-40}"
  [[ -z "$text" ]] && return 0
  printf '%s\n' "$text" | sed -n "1,${limit}p"
}

# Remove known placeholder/schema-only matches from high-confidence regex hits.
filter_high_confidence_hits() {
  local text="${1:-}"
  [[ -z "$text" ]] && return 0
  printf '%s\n' "$text" | rg -v -i -e "$HIGH_CONF_ALLOWLIST_REGEX" || true
}

# Collect changed/staged/untracked files that currently exist on disk.
collect_worktree_files() {
  {
    git diff --name-only
    git diff --cached --name-only
    git ls-files --others --exclude-standard
  } | sed '/^[[:space:]]*$/d' | sort -u | while IFS= read -r p; do
    [[ -f "$p" ]] && printf '%s\n' "$p"
  done
}

scan_tracked_high_confidence() {
  info "Scanning tracked content for high-confidence secret patterns..."
  local raw_hits hits
  raw_hits="$(git grep -nI -E -e "$HIGH_CONF_REGEX" -- . ':!scripts/pre-push-safety-scan.sh' ':!.githooks/pre-push' || true)"
  hits="$(filter_high_confidence_hits "$raw_hits")"
  if [[ -n "$hits" ]]; then
    fail "High-confidence secret-like content found in tracked files."
    print_limited "$hits" 120
  else
    pass "No high-confidence secret patterns found in tracked files."
  fi
}

scan_worktree_high_confidence() {
  info "Scanning changed/untracked files for high-confidence secret patterns..."
  local files
  mapfile -t files < <(collect_worktree_files)
  if ((${#files[@]} == 0)); then
    pass "No changed/untracked files to scan."
    return 0
  fi

  local raw_hits hits
  raw_hits="$(rg -n -e "$HIGH_CONF_REGEX" -- "${files[@]}" 2>/dev/null || true)"
  hits="$(filter_high_confidence_hits "$raw_hits")"
  if [[ -n "$hits" ]]; then
    fail "High-confidence secret-like content found in changed/untracked files."
    print_limited "$hits" 120
  else
    pass "No high-confidence secret patterns found in changed/untracked files."
  fi
}

scan_risky_paths() {
  info "Scanning risky file/path names..."
  local tracked_risky changed_risky
  tracked_risky="$(git ls-files | rg -n -i -e "$RISKY_PATH_REGEX" || true)"
  if [[ -n "$tracked_risky" ]]; then
    warn "Risky path names are tracked; review before push."
    print_limited "$tracked_risky" 80
  else
    pass "No risky path names in tracked files."
  fi

  changed_risky="$(collect_worktree_files | rg -n -i -e "$RISKY_PATH_REGEX" || true)"
  if [[ -n "$changed_risky" ]]; then
    warn "Risky path names in changed/untracked files."
    print_limited "$changed_risky" 80
  else
    pass "No risky path names in changed/untracked files."
  fi
}

scan_backup_artifacts() {
  info "Reviewing backup artifacts under non_stow/ and infra-backup/..."
  local dirs=()
  [[ -d non_stow ]] && dirs+=(non_stow)
  [[ -d infra-backup ]] && dirs+=(infra-backup)
  if ((${#dirs[@]} == 0)); then
    pass "No backup artifact directories found."
    return 0
  fi

  local risky_backup_files
  risky_backup_files="$(
    find "${dirs[@]}" -type f \( \
      -name '.bash_history' -o -name '.zsh_history' -o -name '.env' -o -name '.env.*' -o \
      -name '.npmrc' -o -name '.pypirc' -o -name '.netrc' -o -name '.pgpass' -o \
      -name 'config.json' -o -name 'settings.xml' -o -name 'my.cnf' -o \
      -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' -o -name '*.kdbx' \
    \) 2>/dev/null | sort
  )"
  if [[ -n "$risky_backup_files" ]]; then
    warn "Potentially sensitive backup artifact files detected."
    print_limited "$risky_backup_files" 120
  else
    pass "No obvious high-risk backup artifact filenames detected."
  fi

  local raw_content_hits content_hits
  raw_content_hits="$(rg -n -e "$HIGH_CONF_REGEX" -- "${dirs[@]}" 2>/dev/null || true)"
  content_hits="$(filter_high_confidence_hits "$raw_content_hits")"
  if [[ -n "$content_hits" ]]; then
    fail "High-confidence secret-like content detected in backup artifacts."
    print_limited "$content_hits" 120
  else
    pass "No high-confidence secret patterns detected in backup artifacts."
  fi
}

check_history_hygiene() {
  info "Checking history hygiene for shell history files..."
  local history_paths=(bash/.bash_history zsh/.zsh_history)
  local p

  for p in "${history_paths[@]}"; do
    if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then
      fail "Path is currently tracked and should not be: $p"
    fi
  done

  for p in "${history_paths[@]}"; do
    local commits
    commits="$(git rev-list --all -- "$p" || true)"
    if [[ -n "$commits" ]]; then
      warn "Path exists in git history: $p (commits: $(printf '%s\n' "$commits" | wc -l | tr -d ' '))"
    fi
  done
}

main() {
  info "Running pre-push sensitive data safety scan in: $ROOT_DIR"
  scan_tracked_high_confidence
  scan_worktree_high_confidence
  scan_risky_paths
  scan_backup_artifacts
  check_history_hygiene

  if ((FAIL_COUNT > 0)); then
    printf '[FAIL] Scan finished with %d blocking issue(s) and %d warning(s).\n' "$FAIL_COUNT" "$WARN_COUNT"
    exit 1
  fi

  if ((WARN_COUNT > 0)); then
    printf '[WARN] Scan finished with %d warning(s), no blocking issues.\n' "$WARN_COUNT"
  else
    pass "Scan finished with no blocking issues."
  fi
}

main "$@"
