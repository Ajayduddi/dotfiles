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
- `scripts/` — Extra tools (system configs, firewall, package helper)

---

## 🚀 **Quick start**

1) Install Stow
```bash
# Fedora
sudo dnf install -y stow

# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y stow

# Arch
sudo pacman -Sy --noconfirm stow
```

2) Clone
```bash
git clone https://github.com/Ajayduddi/dotfiles.git ~/.dotfiles
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
bash -lc 'sudo dnf -y install stow || true; git clone https://github.com/Ajayduddi/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow -R -t "$HOME" .'
```

---

## 💾 **Backup and ♻️ Restore**

backup-dotfiles.sh
- Saves: `non_stow/packages/<os>-packages.txt` and DE settings (GNOME/KDE/Xfce/MATE/Cinnamon/COSMIC)
- Builds a filtered candidate for `non_stow/packages/universal-packages.txt` at `non_stow/packages/.generated/universal-candidate.txt` using regex excludes in `non_stow/packages/universal-excludes.txt`
- Backs up developer environments:
  - Python: global `pip freeze` to `non_stow/dev/python/global-requirements-python3.txt`; per-venv freezes under `non_stow/dev/python/venvs/*.txt`; pyenv versions to `non_stow/dev/python/pyenv-versions.txt`
  - Node: Node current version to `non_stow/dev/node/node-current-version.txt`; installed versions discovered from nvm/fnm/asdf to `non_stow/dev/node/node-installed-versions.txt`; global npm packages to `non_stow/dev/node/npm-global-packages.txt`
- Usage:
```bash
bash backup-dotfiles.sh --dry-run  # preview
bash backup-dotfiles.sh            # run
```

restore-dotfiles.sh
- Ensures Stow is present, stows packages, installs packages, restores DE settings
- Package restore: prefers `non_stow/packages/<os>-packages.txt`, falls back to `non_stow/packages/universal-packages.txt` if OS file is missing/empty
- Restores developer environments when backups exist:
  - Python: installs user-site packages from `non_stow/dev/python/global-requirements-python3.txt`; recreates venvs under `~/.venvs/<name>` (or existing roots) from `non_stow/dev/python/venvs/*-requirements.txt`
  - Node: installs Node versions (if nvm/fnm/asdf present) from `non_stow/dev/node/node-installed-versions.txt`; installs global npm packages from `non_stow/dev/node/npm-global-packages.txt`
- To curate universal list safely: the backup script writes a filtered candidate at `non_stow/packages/.generated/universal-candidate.txt` using regex excludes from `non_stow/packages/universal-excludes.txt`. Promote when satisfied:
```bash
cp -f ~/.dotfiles/non_stow/packages/.generated/universal-candidate.txt ~/.dotfiles/non_stow/packages/universal-packages.txt
```
- Usage:
```bash
bash restore-dotfiles.sh --dry-run # preview
bash restore-dotfiles.sh           # run
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

---

## 🛠️ **Scripts**

<details>
  <summary><b>Root-level</b> (click to expand)</summary>

- `backup-dotfiles.sh`
  - **Purpose**: Save user-installed packages + DE settings to `non_stow/`
  - **Flag**: `--dry-run`
- `restore-dotfiles.sh`
  - **Purpose**: Stow packages + restore packages + DE settings
  - **Flag**: `--dry-run`

</details>

<details>
  <summary><b>scripts/</b> (click to expand)</summary>

- `scripts/package-manager.sh`
  - **Purpose**: Cross-distro package helper (Fedora/Debian/Arch)
  - **Commands**: `install`, `save`, `restore`, `update`, `check`
  - **Examples**:
    ```bash
    ./scripts/package-manager.sh install
    ./scripts/package-manager.sh save
    ./scripts/package-manager.sh --verbose check
    ./scripts/package-manager.sh --dry-run restore
    ```

- `scripts/system-config-backup.sh`
  - **Purpose**: Backup system-wide configs to `~/.dotfiles/system-configs/`
  - **Modes**: `--backup` (default), `--restore`, `--dry-run`
  - **Notes**: Scans `/etc`, `/opt`, `/usr/local/etc`, `/var/lib`, `/srv`; safe copy/restore

- `scripts/restore-system-configs.sh`
  - **Purpose**: Restore from `~/.dotfiles/system-configs/`
  - **Flag**: `--dry-run`; uses sudo; creates backups

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
git clone https://github.com/Ajayduddi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && stow -R -t "$HOME" .
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

- Preview system config backup
```bash
./scripts/system-config-backup.sh --backup --dry-run
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

