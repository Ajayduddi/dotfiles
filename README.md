# ✨ **Dotfiles with GNU Stow**

![Managed with GNU Stow](https://img.shields.io/badge/Managed%20with-GNU%20Stow-4D7EA8?logo=gnu&logoColor=white)
![OS: Linux](https://img.shields.io/badge/OS-Linux-FCC624?logo=linux&logoColor=000)


Make your dev environment reproducible and tidy. This repo uses GNU Stow to symlink clean, modular “packages” of configs into your home directory. Handy scripts back up packages and desktop settings, and optionally manage system configs and firewall rules.

---

## 🧭 **Table of contents**

- [🧰 What is GNU Stow?](#-what-is-gnu-stow)
- [🚀 Quick start](#-quick-start)
- [💾 Backup and ♻️ Restore](#-backup-and-️-restore)
- [🧩 Stow tips](#-stow-tips)
- [🧭 Common workflows](#-common-workflows)
- [🔐 Pre-push safety](#-pre-push-safety)
- [🧩 Customize](#-customize)

---

## 🧰 **What is GNU Stow?**

GNU Stow is a symlink manager. Keep each app’s config in its own folder (“package”) and Stow links them into `$HOME`.
- **Separation**: One folder per tool (e.g., `zsh/`, `git/`, `tmux/`).
- **Safety**: Symlinks = easy rollbacks with `stow -D`.
- **Portability**: Reuse the same repo on any machine; stow only what you need.

Docs: https://www.gnu.org/software/stow/

> Tip: Stow is idempotent. Re-run `stow -R` anytime to reconcile symlinks safely.


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


```bash
bash backup-dotfiles.sh --dry-run  # preview
bash backup-dotfiles.sh            # run
```


```bash
# Preview all actions
bash restore-dotfiles.sh --dry-run

# Apply, and adopt pre-existing files in $HOME into the repo if stow conflicts occur
STOW_ADOPT=true bash restore-dotfiles.sh

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

## 🔐 **Pre-push safety**

- Run the sensitive-data scan manually:
```bash
bash scripts/pre-push-safety-scan.sh
```

- Enable the repo-managed pre-push hook:
```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/pre-push-safety-scan.sh
```

- What high-confidence findings block push:
  - Secret-like credentials such as API keys, tokens, bearer auth strings, and private key blocks.

- Pre-push routine:
  1. Run scan: `bash scripts/pre-push-safety-scan.sh`
  2. Review diffs: `git diff --staged` (and `git diff` if needed)
  3. Push: `git push`

---



## 🧩 **Customize**

- Add a package: create folder, mirror paths, commit, then `stow -R -t "$HOME" <folder>`.
- Keep secrets out of the repo; backups skip common credential paths.
- Update `.stowignore` if you add more non-stow assets.
