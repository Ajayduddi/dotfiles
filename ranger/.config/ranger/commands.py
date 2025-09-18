# Custom Ranger commands integrating fzf and zoxide
# Place in: ~/.config/ranger/commands.py (managed here via stow)

from ranger.api.commands import Command
import os
import shutil
import subprocess


def _which(cmd: str) -> bool:
    return shutil.which(cmd) is not None


class fzf_select(Command):
    """
    :fzf_select

    Use fzf to select a file or directory starting from the current directory.
    - Uses `fd` if available, falls back to `find`.
    - If a directory is selected, cd into it; otherwise, select/open the file.
    """

    def execute(self) -> None:
        if not _which("fzf"):
            self.fm.notify("fzf not found in PATH", bad=True)
            return

        # Build the search command
        if _which("fd"):
            search = "fd -H -t f -t d --follow --exclude .git ."
        else:
            # -L follow symlinks, -mindepth 1 to skip '.'
            # Use printf to avoid color/control sequences in some find setups; suppress errors
            search = "find -L . -mindepth 1 -printf '%p\n' 2>/dev/null"

        # Preview: use bat if available, else head/ls
        preview = (
            "[ -f {} ] && (bat --style=numbers --color=always {} 2>/dev/null || head -n 200 {}) || ls -la {}"
        )

        fzf_opts = (
            "--height=40% --layout=reverse --border "
            "--bind 'ctrl-/:toggle-preview' "
            "--preview '" + preview + "' --preview-window=right:60%"
        )

        cmd = f"{search} | fzf {fzf_opts}"

        try:
            # Suspend UI to avoid redraw glitches while running fzf
            self.fm.ui.suspend()
            choice = subprocess.check_output(
                cmd, shell=True, cwd=self.fm.thisdir.path, text=True, stderr=subprocess.DEVNULL
            )
        except subprocess.CalledProcessError:
            return  # user cancelled
        finally:
            # Resume and redraw UI after returning from fzf
            self.fm.ui.initialize()
            self.fm.ui.redraw_window()

        choice = choice.strip()
        if not choice:
            return

        # If search used 'find', paths are relative; resolve absolute path
        path = os.path.abspath(os.path.join(self.fm.thisdir.path, choice))
        if os.path.isdir(path):
            self.fm.cd(path)
        else:
            self.fm.select_file(path)


class fzf_search_dir(Command):
    """
    :fzf_search_dir

    Use fzf to select a directory (dirs only) and cd into it.
    """

    def execute(self) -> None:
        if not _which("fzf"):
            self.fm.notify("fzf not found in PATH", bad=True)
            return

        if _which("fd"):
            search = "fd -H -t d --follow --exclude .git ."
        else:
            # Suppress errors and use printf for predictable output
            search = "find -L . -type d -mindepth 1 -printf '%p\n' 2>/dev/null"

        preview = "ls -la {}"
        fzf_opts = (
            "--height=40% --layout=reverse --border "
            "--bind 'ctrl-/:toggle-preview' "
            "--preview '" + preview + "' --preview-window=right:60%"
        )

        cmd = f"{search} | fzf {fzf_opts}"

        try:
            # Suspend UI to avoid redraw glitches while running fzf
            self.fm.ui.suspend()
            choice = subprocess.check_output(
                cmd, shell=True, cwd=self.fm.thisdir.path, text=True, stderr=subprocess.DEVNULL
            )
        except subprocess.CalledProcessError:
            return
        finally:
            # Resume and redraw UI after returning from fzf
            self.fm.ui.initialize()
            self.fm.ui.redraw_window()

        choice = choice.strip()
        if not choice:
            return

        path = os.path.abspath(os.path.join(self.fm.thisdir.path, choice))
        if os.path.isdir(path):
            self.fm.cd(path)
        else:
            self.fm.notify("Selection is not a directory", bad=True)


class zoxide_cd(Command):
    """
    :zoxide_cd

    Jump to a directory using zoxide interactively.
    - Uses `zoxide query -i` for interactive selection if available.
    - Falls back to `zoxide query -l | fzf` if needed.
    """

    def execute(self) -> None:
        if not _which("zoxide"):
            self.fm.notify("zoxide not found in PATH", bad=True)
            return

        dest = None

        # Prefer interactive mode built into zoxide (uses fzf if installed)
        try:
            dest = subprocess.check_output(
                "zoxide query -i", shell=True, text=True, stderr=subprocess.DEVNULL
            ).strip()
        except subprocess.CalledProcessError:
            dest = None

        # Fallback: list + fzf
        if not dest:
            if _which("fzf"):
                try:
                    dest = subprocess.check_output(
                        "zoxide query -l | fzf --height=40% --layout=reverse --border",
                        shell=True,
                        text=True,
                        stderr=subprocess.DEVNULL,
                    ).strip()
                except subprocess.CalledProcessError:
                    dest = None

        if dest:
            if os.path.isdir(dest):
                self.fm.cd(dest)
            else:
                self.fm.notify(f"Not a directory: {dest}", bad=True)


class open_default(Command):
    """
    :open_default

    Open the selected file with the system default application (xdg-open).
    If the selection is a directory, enter it instead.
    """

    def execute(self) -> None:
        f = self.fm.thisfile
        if not f:
            return
        path = f.path
        if os.path.isdir(path):
            self.fm.cd(path)
            return
        if shutil.which("xdg-open") is None:
            self.fm.notify("xdg-open not found in PATH", bad=True)
            return
        try:
            # Detach so ranger remains responsive
            subprocess.Popen(["xdg-open", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            self.fm.notify(f"Failed to open via xdg-open: {e}", bad=True)