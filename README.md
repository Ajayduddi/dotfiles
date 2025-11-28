# ✨ **Dotfiles with GNU Stow**

![Managed with GNU Stow](https://img.shields.io/badge/Managed%20with-GNU%20Stow-4D7EA8?logo=gnu&logoColor=white)
![OS: Linux](https://img.shields.io/badge/OS-Linux-FCC624?logo=linux&logoColor=000)


Make your dev environment reproducible and tidy. This repo uses GNU Stow to symlink clean, modular “packages” of configs into your home directory. Handy scripts back up packages and desktop settings, and optionally manage system configs and firewall rules.

---

## 🧭 **Table of contents**

- [🧰 What is GNU Stow?](#-what-is-gnu-stow)
- [📂 Layout](#-layout)
- [🚀 Quick start](#-quick-start)
- [💾 Backup and ♻️ Restore](#-backup-and-️-restore)
- [🧩 Stow tips](#-stow-tips)
- [🛠️ Scripts](#️-scripts)
- [🧭 Common workflows](#-common-workflows)
- [🐛 Troubleshooting](#-troubleshooting)
- [🧩 Customize](#-customize)

---

## 🧰 **What is GNU Stow?**

GNU Stow is a symlink manager. Keep each app’s config in its own folder (“package”) and Stow links them into `$HOME`.
- **Separation**: One folder per tool (e.g., `zsh/`, `git/`, `tmux/`).
- **Safety**: Symlinks = easy rollbacks with `stow -D`.
- **Portability**: Reuse the same repo on any machine; stow only what you need.

Docs: https://www.gnu.org/software/stow/

> Tip: Stow is idempotent. Re-run `stow -R` anytime to reconcile symlinks safely.

---

## 📂 **Layout**

Stow packages (mirror final paths under `$HOME`):
- `bash/` — Bash rc/profile
- `config/` — XDG configs under `~/.config`
- `eclipse/` — Eclipse settings/workspace
- `fonts/` — User fonts
- `git/` — Global git config
- `gnome-extentions/` — GNOME extensions
- `nano/` — Nano config
- `starship/` — Starship prompt
- `tmux/` — Tmux config + plugins
- `zsh/` — Zsh + Oh My Zsh

Not stowed / helpers:
- `non_stow/` — Backups: packages list and DE settings
- `wallpapers/` — Assets
- `.stowignore`, `.stow-global-ignore` — Ignore rules
- `backup-dotfiles.sh` — User-level backup
- `restore-dotfiles.sh` — User-level restore
- `restore_packages.sh` — Optional helper to safely reinstall packages (uses `non_stow/packages/*` lists). See the section below for usage and safety notes.
- `scripts/` — Extra tools (firewall)

---

## 🚀 **Quick start**

1) Install Stow
```bash
# Fedora (dnf5 or dnf)
sudo dnf5 install -y stow || sudo dnf install -y stow

# Debian/Ubuntu/Kali
sudo apt-get update && sudo apt-get install -y stow

# Arch
sudo pacman -Sy --noconfirm stow
```

2) Clone
```bash
git clone --branch linux_stow https://github.com/Ajayduddi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

3) Stow packages
```bash
# Stow everything (thanks to .stowignore)
stow -R -t "$HOME" .

# Or pick specific ones
stow -R -t "$HOME" zsh git tmux starship
```

4) Update later
```bash
cd ~/.dotfiles && git pull
stow -R -t "$HOME" .
```

Unstow a package
```bash
stow -D -t "$HOME" zsh
```

> One‑liner bootstrap (fresh machine):
```bash
bash -lc 'command -v dnf5 >/dev/null && sudo dnf5 -y install stow || command -v dnf >/dev/null && sudo dnf -y install stow || (sudo apt-get update && sudo apt-get -y install stow) || sudo pacman -Sy --noconfirm stow; git clone --branch linux_stow https://github.com/Ajayduddi/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow -R -t "$HOME" .'
```

---

## 💾 **Backup and ♻️ Restore**

backup-dotfiles.sh
- Saves: `non_stow/packages/<os>-packages.txt` and DE settings (GNOME/KDE/Xfce/MATE/Cinnamon/COSMIC)
- Builds a filtered candidate for `non_stow/packages/universal-packages.txt` at `non_stow/packages/.generated/universal-candidate.txt` using regex excludes in `non_stow/packages/universal-excludes.txt`
- Backs up developer environments:
 - Backs up developer environments:
  - Python: global `pip freeze` to `non_stow/dev/python/global-requirements-python3.txt`; per-venv freezes under `non_stow/dev/python/venvs/*.txt`; pyenv versions to `non_stow/dev/python/pyenv-versions.txt`
  - Node: Node current version to `non_stow/dev/node/node-current-version.txt`; installed versions discovered from nvm/fnm/asdf to `non_stow/dev/node/node-installed-versions.txt`; global npm packages to `non_stow/dev/node/npm-global-packages.txt`
- Usage:
```bash
bash backup-dotfiles.sh --dry-run  # preview
bash backup-dotfiles.sh            # run
```

- restore-dotfiles.sh
  - Ensures Stow is present and stows packages from the repo root (non-destructive by default), restores desktop-environment settings from `non_stow/` when available

  - To reinstall packages from backups, use the separate, opt-in helper `restore_packages.sh` (described below).

- To curate universal list safely: the backup script writes a filtered candidate at `non_stow/packages/.generated/universal-candidate.txt` using regex excludes from `non_stow/packages/universal-excludes.txt`. Promote when satisfied:
```bash
cp -f ~/.dotfiles/non_stow/packages/.generated/universal-candidate.txt ~/.dotfiles/non_stow/packages/universal-packages.txt
```
- Usage:
```bash
# Preview all actions
bash restore-dotfiles.sh --dry-run

# Apply, and adopt pre-existing files in $HOME into the repo if stow conflicts occur
STOW_ADOPT=true bash restore-dotfiles.sh

restore_packages.sh (optional)
- Purpose: a small, opt-in helper that reads the package list generated by `backup-dotfiles.sh` (`non_stow/packages/<os>-packages.txt`) and attempts to install the packages for the detected OS. This helper is separate from the main restore script so package installation remains explicit and visible.
- Notes: `restore_packages.sh` tries reasonable timeouts and per-distro install commands, pre-authenticates sudo when needed and prints a summary of success/failures. Always review your package lists and prefer `--dry-run` or manual inspection before applying on a production machine.
```

Only reinstall packages (Fedora example):
```bash
xargs -a ~/.dotfiles/non_stow/packages/fedora-packages.txt -r sudo dnf install -y
```

---

## 🧩 **Stow tips**

- One dir = one package; mirror target paths:
```text
~/.dotfiles/zsh/.zshrc        -> $HOME/.zshrc
~/.dotfiles/git/.gitconfig    -> $HOME/.gitconfig
~/.dotfiles/starship/.config/ -> $HOME/.config/
```
- Idempotent: `stow -R -t "$HOME" .` is safe any time.
- Ignore extras via `.stowignore` / `.stow-global-ignore`.
- Before deleting a package dir: `stow -D -t "$HOME" <pkg>`.
- If stow fails due to existing files, either:
  - Run with adoption to absorb files into the repo: `STOW_ADOPT=true bash restore-dotfiles.sh`
  - Or manually move/backup the conflicting files, then re-run `stow -R`.

---

## 🛠️ **Scripts**

<details>
  <summary><b>Root-level</b> (click to expand)</summary>

- `backup-dotfiles.sh`
  - **Purpose**: Save user-installed packages + DE settings to `non_stow/`
  - **Notes**: The backup script performs filtering for a curated universal package candidate and now includes safer file-copy behavior — it prefers `rsync` but falls back to `cp -a` if `rsync` is not available. `OS_ID` is normalized (whitespace trimmed) before generating package filenames to avoid accidental mismatches.
  - **Flag**: `--dry-run`
- `restore-dotfiles.sh`
  - **Purpose**: Stow packages + restore packages + DE settings
  - **Flag**: `--dry-run`

</details>

<details>
  <summary><b>scripts/</b> (click to expand)</summary>

Legacy scripts removed
  - NOTE: some earlier, higher-risk helpers were intentionally removed from the public repo to avoid accidental destructive restores. The following were removed: `scripts/package-manager.sh`, `scripts/system-config-backup.sh`, and `scripts/restore-system-configs.sh`.
  - Use `restore_packages.sh` (opt-in) to reinstall packages from `non_stow/packages/*`, and for system-level configuration/backups prefer a manual, audited approach or a private/archive copy of per-machine scripts.

- `scripts/firewall.sh`
  - **Purpose**: Update firewall rules from multiple threat feeds; firewalld/ufw/iptables/pf
  - **Key options**: `--dry-run`, `--verbose`, `--force`, `--auto-update`, `--enable-all-sources`, `--enable-proxy-blocking`, `--enable-crypto-blocking`, `--sources <file>`
  - **Config**: `~/.config/firewall-update.conf` (see `scripts/firewall-update.conf.example`)

- `scripts/ipset_bulk_helper.py`
  - **Purpose**: Very fast bulk IP add via native `ipset restore` or batched `firewall-cmd`
  - **Usage**:
    ```bash
    python3 scripts/ipset_bulk_helper.py add <ipset_name> <ips_file>
    ```

- `scripts/firewall-update.conf.example`
  - **Purpose**: Example config for firewall.sh
  - **Usage**: Copy to `~/.config/firewall-update.conf` and edit

</details>

---

## 🧭 **Common workflows**

- Fresh machine
```bash
git clone --branch linux_stow https://github.com/Ajayduddi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash restore-dotfiles.sh
```

- Update configs
```bash
cd ~/.dotfiles && git pull
stow -R -t "$HOME" .
```

- Backup current machine
```bash
cd ~/.dotfiles
bash backup-dotfiles.sh
```

- Preview firewall updates
```bash
./scripts/firewall.sh --dry-run --enable-all-sources
```

---


## 🧩 **Customize**

- Add a package: create folder, mirror paths, commit, then `stow -R -t "$HOME" <folder>`.
- Keep secrets out of the repo; backups skip common credential paths.
- Update `.stowignore` if you add more non-stow assets.

