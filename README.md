<div align="center">
<h1>✨ Dotfiles (managed with GNU Stow for cloud)</h1>

![Managed with GNU Stow](https://img.shields.io/badge/Managed%20with-GNU%20Stow-4D7EA8?logo=gnu&logoColor=white) &nbsp; ![OS: Linux](https://img.shields.io/badge/OS-Linux-FCC624?logo=linux&logoColor=000)

<p>Portable dotfiles using GNU Stow — helper scripts to backup/restore dotfiles, production environments and infrastructure artifacts.</p>
</div>

---

## Quick overview

- Top-level directories are GNU Stow packages (e.g. `zsh`, `bash`, `git`, `tmux`, `starship`) — stow them into `$HOME`.
- `non_stow/` stores reproducible artifacts: package lists, Python venv requirements, Node version lists, npm globals, and infrastructure backups.

### Main helper scripts
- `backup-dotfiles.sh` — collect system state into `non_stow/` (packages, venv requirements, node versions).
- `restore_packages.sh` — distro-aware installer that reads `non_stow/packages/*` and attempts reinstall (opt-in; prefer dry-run).
- `restore-dotfiles.sh` — repo restore helper: re-clones repo, ensures tools (stow, zsh, nvm), stows packages into `$HOME`, installs zsh plugins and restores developer environments.
- `infra-backup.sh` — infra-level helper to snapshot/restore server artifacts (nginx, jetty, maven, mysql) into `infra-backup/`.

---

## 🔁 Recommended restore order (fresh machine)

Follow this simple, safe order to rebuild a machine.

1) Clone / acquire the repo

```bash
# Option A — manual
git clone --branch cloud https://github.com/Ajayduddi/dotfiles.git "$HOME/.dotfiles"

# Option B — let the helper re-clone and prepare (safe + idempotent)
bash "$HOME/.dotfiles/restore-dotfiles.sh"
```

2) Restore OS packages (optional but helpful before tool installation)

```bash
cd "$HOME/.dotfiles"
# Preview only
DRY_RUN=true bash restore_packages.sh

# Apply
bash restore_packages.sh
```

3) Stow your dotfiles (repo restore will usually do this)

```bash
bash restore-dotfiles.sh
```

4) Optional: restore infra artifacts (servers only)

```bash
bash infra-backup.sh restore
```

Note: `restore-dotfiles.sh` re-clones and runs a stow pass so it is safe to run it after packages are installed.

---

## ⚙️ How stow is used in this repo

- This repo organizes config into top-level directories that are treated as stow packages. Each package typically mirrors the target layout in `$HOME`.
- The restore script runs stow for every package under `$DOTFILES_DIR` except for: `.git`, `non_stow`, `.github`, `.zencoder`, `infra-backup`, and `scripts`. That means creating a new package is as simple as adding another top-level folder containing the desired relative paths.

### Stow examples

```bash
# From inside the dotfiles directory
cd ~/.dotfiles

# Stow a specific package (makes symlinks in your $HOME)
stow -v 1 -t "$HOME" zsh

# Remove a package (unstow)
stow -D -t "$HOME" zsh

# Adopt mode: if you want stow to take ownership of existing files
stow --adopt -R -v 1 -t "$HOME" somepackage
```

When adding a new package:
- Create a folder that contains the file tree you want to mirror into `$HOME`, not absolute paths.
- Verify with `stow -n` (dry-run) before making changes.

---

## 💾 Backups — capture your system & infra state (recommended)

This repo ships two different backup helpers depending on what you want to save:

- `backup-dotfiles.sh` — captures user-level environment artifacts (package lists, Python venv snapshots, node versions, npm global packages) into `$DOTFILES_DIR/non_stow` (default: `$HOME/.dotfiles/non_stow`). This is the safe place to store reproducible lists you can later use with `restore_packages.sh` and `restore-dotfiles.sh`.
- `infra-backup.sh` — intended for server/infra-level config backups (nginx, jetty, maven, mysql). Files are saved under `~/.dotfiles/infra-backup/` with timestamped directories.

Why backup first?
- Backups allow safe migration and reproducible restore. For example, run `backup-dotfiles.sh` prior to upgrading or changing system packages so you can reproduce package lists and dev environment snapshots.

#### How to use `backup-dotfiles.sh` (typical flow):

```bash
# Dry-run to preview what will be written (good default)
bash backup-dotfiles.sh --dry-run

# Or explicitly set the DRY_RUN env var
DRY_RUN=true bash backup-dotfiles.sh

# To actually write files into the repo (default DOTFILES_DIR=$HOME/.dotfiles)
bash backup-dotfiles.sh
```

What it writes (common outputs):
- `non_stow/packages/${OS_ID}-packages.txt` — OS-specific installed package list.
	The script detects `OS_ID` from the host (examples: debian, ubuntu, fedora, arch, opensuse, mac)
- `non_stow/packages/universal-packages.txt` — curated universal list (not written automatically — `backup-dotfiles.sh` generates a `.generated/universal-candidate.txt` you can review and promote)
- `non_stow/dev/python/global-requirements-python3.txt` — frozen system-wide Python3 packages
- `non_stow/dev/python/venvs/*-requirements.txt` — per-venv requirements listed
- `non_stow/dev/node/node-current-version.txt` — local/active node version
- `non_stow/dev/node/node-installed-versions.txt` — installed Node versions across managers (nvm/fnm/asdf).
- `non_stow/dev/node/npm-global-packages.txt` — global npm packages list


#### 🏗️ infra backups (server / infra)

```bash
# Backup infra artifacts to timestamped folders
bash infra-backup.sh backup

# Preview
DRY_RUN=true bash infra-backup.sh backup

# Restore artifacts (use with care; requires sudo/service restarts)
bash infra-backup.sh restore
```

## 🔒 Safety tips

- Always run backups with `--dry-run` or `DRY_RUN=true` first when you're unsure what will change.
- Avoid storing secrets in `non_stow` if the repository is public. Keep sensitive data out of the repo or encrypted separately.

