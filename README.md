# Dotfiles (managed with GNU Stow)

This repository is a portable, GNU Stow-managed dotfiles collection with helper scripts to backup and restore both dotfiles and system-level packages & infrastructure. The repo aims to keep config in a stow-friendly layout and a small `non_stow` store for extras (package lists, virtualenv requirements, node lists, infra backups).

---

## Quick overview

- Dotfiles are laid out as stow packages — each top-level directory (e.g., `zsh`, `bash`, `git`, `tmux`, `starship`, etc.) is a stow package you can `stow` into your `$HOME`.
- `non_stow/` contains system or environment artifacts that don't belong in stow packages: package lists, Python venv requirements, npm/global lists, and infra backups.
- Several helper scripts automate backups and restores:
	- `backup-dotfiles.sh` — collects current system state into `non_stow/` (packages, venv requirements, node versions).
	- `restore_packages.sh` — installs packages from `non_stow/packages/*` in a distro-aware manner.
	- `restore-dotfiles.sh` — re-clones repository, ensures tools (zsh, stow, nvm), stows packages into `$HOME`, installs zsh plugins, restores dev toolchains (python venvs, node via nvm).
	- `infra-backup.sh` — specialized: backup/restore Nginx, Jetty, Maven, MySQL infrastructure configs under `infra-backup/`.

---

## Recommended restore order (new machine)

When setting up a fresh system, run these in this order to safely replicate both environment packages and dotfiles.

1) Clone the repo into $HOME (or let `restore-dotfiles.sh` do it):

```bash
# manual clone (optional)
git clone --branch cloud https://github.com/Ajayduddi/dotfiles.git "$HOME/.dotfiles"

# OR use the helper script which will re-clone the repo cleanly
bash "$HOME/.dotfiles/restore-dotfiles.sh"
```

2) Restore OS packages (best-run after the repo is present because package lists live in `non_stow/packages`):

```bash
cd "$HOME/.dotfiles"
# Dry-run first if you want to preview
DRY_RUN=true bash restore_packages.sh

# Then run for real
bash restore_packages.sh
```

3) Re-apply stow-managed dotfiles

```bash
# The restore-dotfiles script auto-stows packages for you when you run it. It also installs zsh plugins and other tooling.
bash restore-dotfiles.sh
```

4) (Optional) Restore infrastructure files

```bash
# Used for servers/VMs where nginx/jetty/mysql configs are stored in infra backups
bash infra-backup.sh restore
```

Note: `restore-dotfiles.sh` already performs a re-clone of the repo and executes the stow pass. Running `restore-dotfiles.sh` after you have restored packages is safe and recommended so any required tools (e.g., stow, zsh) are present.

---

## How stow is used in this repo

- This repo organizes config into top-level directories that are treated as stow packages. Each package typically mirrors the target layout in `$HOME`.
- The restore script runs stow for every package under `$DOTFILES_DIR` except for: `.git`, `non_stow`, `.github`, `.zencoder`, `infra-backup`, and `scripts`. That means creating a new package is as simple as adding another top-level folder containing the desired relative paths.

Stow examples:

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

## Backups — how to capture your system & infra state (recommended)

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
- `non_stow/packages/${OS_ID}-packages.txt` — OS-specific installed package list (where OS_ID is detected by the script: debian, ubuntu, fedora, arch, opensuse, mac)
- `non_stow/packages/universal-packages.txt` — curated universal list (not written automatically — `backup-dotfiles.sh` generates a `.generated/universal-candidate.txt` you can review and promote)
- `non_stow/dev/python/global-requirements-python3.txt` — frozen system-wide Python3 packages
- `non_stow/dev/python/venvs/*-requirements.txt` — per-venv requirements listed
- `non_stow/dev/node/node-current-version.txt` — local/active node version
- `non_stow/dev/node/node-installed-versions.txt` — installed Node versions across managers (nvm/fnm/asdf)
- `non_stow/dev/node/npm-global-packages.txt` — global npm packages list


#### How to use `infra-backup.sh` (server/infra backups):

```bash
# Backup infrastructure (nginx/jetty/maven/mysql) into ~/.dotfiles/infra-backup/<timestamp>/
bash infra-backup.sh backup

# Dry-run preview
DRY_RUN=true bash infra-backup.sh backup

# Restore the backed-up artifacts (careful, requires sudo and service restarts)
bash infra-backup.sh restore

# When restoring, the script will try to ensure prerequisites (nginx, java/jetty, maven, mysql) are present and may install or warn as needed.
```

### Safety tips

- Always run backups with `--dry-run` or `DRY_RUN=true` first when you're unsure what will change.
- Avoid storing secrets in `non_stow` if the repository is public. Keep sensitive data out of the repo or encrypted separately.

