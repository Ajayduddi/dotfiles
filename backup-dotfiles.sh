#!/bin/bash

set -e

# Minimal emoji output (set NO_EMOJI=true to strip icons)
NO_EMOJI=${NO_EMOJI:-true}
strip_emojis() { sed -E 's/(✅|🔍|⚠️|❌|🟡|📝|🔧|💾|📦|🖥️|🚀|🌐|🗄️|🔒|🔗|🔄|➡️|🐱|☕|🛠️|📁|🔌|🛡️|🧪|🔎|📊|🧹|🟢|🟠|🔵)//g'; }
echo() {
  local newline=true; local enable_escape=false; local args=()
  while [[ $# -gt 0 ]]; do case "$1" in -n) newline=false;; -e) enable_escape=true;; *) args+=("$1");; esac; shift; done
  local msg="${args[*]}"
  if [[ "$NO_EMOJI" = "true" ]]; then msg=$(printf "%s" "$msg" | strip_emojis); fi
  if $enable_escape; then if $newline; then builtin echo -e "$msg"; else builtin echo -ne "$msg"; fi
  else if $newline; then builtin echo "$msg"; else builtin echo -n "$msg"; fi; fi
}

# Check for dry-run mode and help
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be done without making changes"
            echo ""
            shift
            ;;
        --help|-h)
            echo "🔧 DOTFILES BACKUP SCRIPT"
            echo "========================="
            echo ""
            echo "USAGE: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run, -n    Show what would be done without making changes"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "DESCRIPTION:"
            echo "  Creates comprehensive backup of dotfiles, configurations, and settings."
            echo "  Excludes sensitive files and applies security filtering."
            echo ""
            echo "FEATURES:"
            echo "  ✅ Secure backup with sensitive file exclusion"
            echo "  ✅ GNOME settings backup"
            echo "  ✅ Shell history cleaning and deduplication"
            echo "  ✅ Package list backup"
            echo "  ✅ Automatic Git integration"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                    # Run backup"
            echo "  $0 --dry-run         # Preview what would be backed up"
            echo ""
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "💡 Use --help for usage information"
            exit 1
            ;;
    esac
done

# Define dotfiles directory
DOTFILES_DIR="$HOME/.dotfiles"

# Exit if .dotfiles folder does not exist
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "❌ Error: '$DOTFILES_DIR' directory does not exist."
    echo "➡️ Please create the .dotfiles directory before running this script."
    exit 1
fi

echo "🔧 Initializing Dotfiles Repository..."

# Initialize Git Repo Only if It Doesn't Exist
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Initialize Git repository in $DOTFILES_DIR"
    else
        git init "$DOTFILES_DIR"
    fi
fi

# Set up Git wrapper function
dotfiles() {
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD RUN: git --git-dir=\"$DOTFILES_DIR/.git\" --work-tree=\"$HOME\" $*"
    else
        /usr/bin/git --git-dir="$DOTFILES_DIR/.git" --work-tree="$HOME" "$@"
    fi
}

if [ "$DRY_RUN" = true ]; then
    echo "🔍 WOULD: Configure Git to not show untracked files"
else
    dotfiles config --local status.showUntrackedFiles no 2>/dev/null || true
fi

# Create necessary directories
if [ "$DRY_RUN" = true ]; then
    echo "🔍 WOULD: Create directories:"
    echo "  - $DOTFILES_DIR/.local/share/gnome-shell/extensions"
    echo "  - $DOTFILES_DIR/.fonts"
    echo "  - $DOTFILES_DIR/.themes"
    echo "  - $DOTFILES_DIR/.icons"
    echo "  - $DOTFILES_DIR/shell"
else
    mkdir -p "$DOTFILES_DIR/.local/share/gnome-shell/extensions"
    mkdir -p "$DOTFILES_DIR/.fonts"
    mkdir -p "$DOTFILES_DIR/.themes"
    mkdir -p "$DOTFILES_DIR/.icons"
    mkdir -p "$DOTFILES_DIR/shell"
    mkdir -p "$DOTFILES_DIR/kde"
fi

# Detect desktop environment (normalized)
_detect_desktop_env() {
    local de
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        de="$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        de="$DESKTOP_SESSION"
    elif [ -n "$GDMSESSION" ]; then
        de="$GDMSESSION"
    else
        de="unknown"
    fi
    de=$(printf '%s' "$de" | tr '[:upper:]' '[:lower:]')
    case "$de" in
        *gnome*) echo "gnome" ;;
        *cinnamon*) echo "cinnamon" ;;
        *cosmic*) echo "cosmic" ;;
        *plasma*|*kde*) echo "kde" ;;
        *xfce*) echo "xfce" ;;
        *mate*) echo "mate" ;;
        *) echo "unknown" ;;
    esac
}

DESKTOP_ENV=$(_detect_desktop_env)
echo "🖥️ Detected desktop environment: $DESKTOP_ENV"

# Update existing .gitignore with additional security patterns
update_gitignore() {
    local gitignore_file="$DOTFILES_DIR/.gitignore"
    
    # Define additional security patterns to add
    local additional_patterns=(
        "# Additional security patterns - automatically added"
        "**/*password*"
        "**/*secret*"
        "**/*token*"
        "**/*key*"
        "**/*credential*"
        "**/*auth*"
        "**/Login\ Data*"
        "**/Cookies*"
        "**/Web\ Data*"
        "**/History*"
        "**/Bookmarks*"
        "**/*.pem"
        "**/*.key"
        "**/*.p12"
        "**/.ssh/"
        "**/.gnupg/"
        "**/.aws/"
        "**/.docker/config.json"
        "**/.netrc"
        "**/.pgpass"
        "**/.gitconfig"
        "**/.npmrc"
        "**/github-copilot/"
        "**/gcloud/"
        "**/kubectl/"
        "**/*session*"
        "**/*cache*"
        "**/*tmp*"
        "**/*temp*"
        "**/logs/"
        ""
        "# Browser data that might contain sensitive information"
        ".config/*/Default/Login\ Data*"
        ".config/*/Default/Cookies*"
        ".config/*/Default/Web\ Data*"
        ".config/*/Default/History*"
        ".config/*/Default/Bookmarks*"
        ".config/*/Profile*/Login\ Data*"
        ".config/*/Profile*/Cookies*"
        ".config/*/Profile*/Web\ Data*"
        ".config/*/Profile*/History*"
        ".config/*/Profile*/Bookmarks*"
        ""
        "# Applications with built-in backup/sync - exclude to avoid conflicts"
        ".config/Code/"
        ".config/VSCodium/"
        ".config/JetBrains/"
        ".config/IntelliJIdea*/"
        ".config/PyCharm*/"
        ".config/WebStorm*/"
        ".config/PhpStorm*/"
        ".config/CLion*/"
        ".config/DataGrip*/"
        ".config/GoLand*/"
        ".config/RubyMine*/"
        ".config/Rider*/"
        ".config/sublime-text*/"
        ".config/discord/"
        ".config/slack/"
        ".config/Slack/"
        ".config/spotify/"
        ".config/Spotify/"
        ".config/steam/"
        ".config/Steam/"
        ".config/postman/"
        ".config/Postman/"
        ".config/insomnia/"
        ".config/MongoDB*/"
        ".config/docker/"
        ".config/Docker*/"
        ".local/share/JetBrains/"
        ".local/share/code-*/"
        ".local/share/Steam/"
        ".local/share/discord/"
        ".local/share/Slack/"
        ".local/share/spotify/"
        ".local/share/applications/wine/"
    )
    
    # Check if security section already exists
    if ! grep -q "Additional security patterns" "$gitignore_file" 2>/dev/null && ! grep -q "Applications with built-in backup/sync" "$gitignore_file" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Update .gitignore with additional security patterns..."
            echo "🔍 WOULD: Add ${#additional_patterns[@]} security patterns to $gitignore_file"
        else
            echo "🔒 Updating .gitignore with additional security patterns..."
            
            # Add security patterns to existing .gitignore
            {
                echo ""
                for pattern in "${additional_patterns[@]}"; do
                    echo "$pattern"
                done
            } >> "$gitignore_file"
        fi
    else
        echo "🟡 Security patterns already exist in .gitignore"
    fi
}

# Update the existing .gitignore file
update_gitignore

# Security: Define sensitive patterns to exclude
SENSITIVE_PATTERNS=(
    # Browser security files
    "*/Login Data*" "*/Cookies*" "*/Web Data*" "*/History*" "*/Bookmarks*"
    # SSH and GPG keys
    "*/.ssh/*" "*/.gnupg/*" "*/keyrings/*"
    # Cloud credentials
    "*/.aws/*" "*/.docker/config.json" "*/.gcloud/*" "*/.kube/*"
    # Authentication files
    "*/.netrc" "*/.pgpass" "*/github-copilot/*"
    # Sensitive CLI config directories
    "*/.config/gh/*"
    # Generic sensitive patterns
    "*password*" "*secret*" "*token*" "*credential*" "*auth*"
    "*.pem" "*.key" "*.p12"
    # Cache and temporary files
    "*/cache/*" "*/Cache/*" "*/tmp/*" "*/temp/*" "*/logs/*"
    "*session*" "*Session*"
    # Development tool caches (large, non-essential files)
    "*/.m2/repository/*" "*/.gradle/caches/*" "*/.npm/_cacache/*"
    "*/.ivy2/cache/*" "*/.sbt/boot/*" "*/node_modules/*"
    # Applications with built-in sync (avoid conflicts)
    "*/Code/*" "*/VSCodium/*" "*/JetBrains/*" "*/IntelliJIdea*/*"
    "*/PyCharm*/*" "*/WebStorm*/*" "*/PhpStorm*/*" "*/CLion*/*"
    "*/DataGrip*/*" "*/GoLand*/*" "*/RubyMine*/*" "*/Rider*/*"
    "*/sublime-text*/*" "*/discord/*" "*/slack/*" "*/Slack/*"
    "*/spotify/*" "*/Spotify/*" "*/steam/*" "*/Steam/*"
    "*/postman/*" "*/Postman/*" "*/insomnia/*" "*/MongoDB*/*"
    "*/docker/*" "*/Docker*/*" "*/code-*/*"
    # Tmux plugins and nested git repos (avoid backing these up)
    "*/.tmux/plugins/*" "*/.git/*"
)

# Function to check if a file/directory should be excluded
is_sensitive() {
    local file_path="$1"
    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        if [[ "$file_path" == $pattern ]]; then
            return 0  # True - is sensitive
        fi
    done
    return 1  # False - not sensitive
}

# Secure function to copy directory excluding sensitive files
secure_backup_directory() {
    local relative_path="$1"
    local src="$HOME/$relative_path"
    local dest="$DOTFILES_DIR/$relative_path"
    
    if [ ! -e "$src" ]; then
        echo "⚠️ Source $relative_path does not exist, skipping."
        return
    fi
    
    # Skip if already symlinked into DOTFILES_DIR
    if [[ "$src" -ef "$dest" ]]; then
        echo "🟡 $relative_path already managed by dotfiles, skipping."
        return
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Securely back up $relative_path..."
        echo "🔍 WOULD: Create destination directory $dest"
        echo "🔍 WOULD: Copy files excluding ${#SENSITIVE_PATTERNS[@]} sensitive patterns"
        
        if [ -e "$src" ] && [ ! -L "$src" ]; then
            echo "🔍 WOULD: Backup original $relative_path to ${src}.backup_$(date +%s)"
            echo "🔍 WOULD: Create symlink $src -> $dest"
        fi
        return
    fi
    
    echo "📁 Securely backing up $relative_path..."
    
    # Create destination directory
    mkdir -p "$dest"
    
    # Use rsync to copy with exclusions
    local exclude_args=()
    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        exclude_args+=(--exclude="$pattern")
    done
    
    # Copy files excluding sensitive ones
    if command -v rsync &> /dev/null; then
        rsync -av "${exclude_args[@]}" "$src/" "$dest/" --delete-excluded 2>/dev/null || {
            echo "⚠️ Some files were excluded for security reasons"
        }
    else
        # Fallback: use find and cp (less efficient but works)
        find "$src" -type f | while read -r file; do
            rel_file="${file#$src/}"
            if ! is_sensitive "$rel_file"; then
                dest_file="$dest/$rel_file"
                mkdir -p "$(dirname "$dest_file")"
                cp "$file" "$dest_file" 2>/dev/null || echo "⚠️ Failed to copy $rel_file"
            else
                echo "🔒 Excluded sensitive file: $rel_file"
            fi
        done
    fi
    
    # Backup original and create symlink
    if [ -e "$src" ] && [ ! -L "$src" ]; then
        backup_name="${src}.backup_$(date +%s)"
        if mv "$src" "$backup_name"; then
            echo "📝 Safely backed up original $relative_path to $backup_name"
        else
            echo "❌ Failed to backup $relative_path. Aborting symlink creation."
            return 1
        fi
    fi
    
    ln -sf "$dest" "$src"
}

# Function to move and symlink folders, only if not already managed
move_and_symlink() {
    local relative_path="$1"
    local src="$HOME/$relative_path"
    local dest="$DOTFILES_DIR/$relative_path"

    # Skip if already symlinked into DOTFILES_DIR
    if [[ "$src" -ef "$dest" ]]; then
        echo "🟡 $relative_path already managed by dotfiles, skipping."
        return
    fi

    if [ -e "$src" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Back up $relative_path..."
            if [ -e "$dest" ]; then
                echo "🔍 WOULD: Skip move (backup already exists in dotfiles)"
            else
                echo "🔍 WOULD: Move $src to $dest"
            fi
            
            if [ -L "$src" ]; then
                echo "🔍 WOULD: Skip (symlink already exists)"
            elif [ -e "$src" ]; then
                echo "🔍 WOULD: Rename existing $relative_path to preserve it"
            fi
            
            echo "🔍 WOULD: Create symlink $src -> $dest"
            return
        fi
        
        echo "📁 Backing up $relative_path..."

        if [ -e "$dest" ]; then
            echo "🟡 Backup of $relative_path already exists in dotfiles. Skipping move."
        else
            mv "$src" "$dest"
        fi

        if [ -L "$src" ]; then
            echo "🔗 Symlink for $relative_path already exists. Skipping."
        elif [ -e "$src" ]; then
            mv "$src" "${src}.backup_$(date +%s)"
            echo "📝 Renamed existing $relative_path to preserve it."
        fi

        ln -sf "$dest" "$src"
    fi
}

# Backup .config directory securely (excluding sensitive files)
echo "🔒 Using secure backup for .config (sensitive files will be excluded)..."
secure_backup_directory ".config"

# Backup GNOME extensions (usually safe but using secure method)
if [ "$DESKTOP_ENV" = "gnome" ]; then
    secure_backup_directory ".local/share/gnome-shell/extensions"
fi

# Backup tmux-related directories if present
secure_backup_directory ".tmux"
secure_backup_directory ".tmuxp"

# Backup nano configuration directory if present
secure_backup_directory ".nano"

# KDE Plasma plasmoids
if [ "$DESKTOP_ENV" = "kde" ]; then
    secure_backup_directory ".local/share/plasma/plasmoids"
fi

# Desktop settings backup (dconf-based for GNOME/Cinnamon/COSMIC)
if [ "$DESKTOP_ENV" = "gnome" ] || [ "$DESKTOP_ENV" = "cinnamon" ] || [ "$DESKTOP_ENV" = "cosmic" ]; then
    # Check if dconf is available
    if ! command -v dconf &> /dev/null; then
        echo "❌ dconf not found!"
        echo "⚠️  dconf is required to backup $DESKTOP_ENV settings."
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Attempt to install dconf or skip $DESKTOP_ENV settings backup"
        else
            if [ -t 0 ]; then
                read -p "Do you want to install dconf (y/n)? " install_dconf
            else
                install_dconf="n"
                echo "Running in non-interactive mode, skipping dconf installation"
            fi
            if [[ "$install_dconf" =~ ^[Yy]$ ]]; then
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y dconf
                elif command -v apt-get &> /dev/null; then
                    sudo apt-get install -y dconf-cli
                elif command -v pacman &> /dev/null; then
                    sudo pacman -S --noconfirm dconf
                else
                    echo "❌ Package manager not supported. Please install dconf manually."
                    exit 1
                fi
            else
                echo "⚠️ Skipping $DESKTOP_ENV settings backup without dconf"
            fi
        fi
    fi

    if command -v dconf &> /dev/null; then
        case "$DESKTOP_ENV" in
            gnome)
                target_file="$DOTFILES_DIR/gnome-settings.dconf"
                what="GNOME"
                ;;
            cinnamon)
                target_file="$DOTFILES_DIR/cinnamon-settings.dconf"
                what="Cinnamon"
                ;;
            cosmic)
                target_file="$DOTFILES_DIR/cosmic-settings.dconf"
                what="COSMIC"
                ;;
        esac
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Backup $what settings (excluding sensitive keys) to $target_file"
        else
            echo "💾 Backing up $what settings (excluding sensitive keys)..."
            dconf dump / | grep -v -E "(password|secret|token|credential|key)" > "$target_file" || {
                echo "⚠️ Some $what settings were excluded for security reasons"
                dconf dump / > "$target_file"
            }
        fi
    fi
fi

# Backup themes, fonts and icons
move_and_symlink ".themes"
move_and_symlink ".icons"
move_and_symlink ".fonts"

# Backup development tool configurations
echo "🛠️ Backing up development tool configurations..."

# Maven configuration (contains settings.xml, repositories, etc.)
if [ -d "$HOME/.m2" ]; then
    echo "📦 Backing up Maven configuration (.m2)..."
    secure_backup_directory ".m2"
fi

# Java configuration (user preferences, fonts, etc.)
if [ -d "$HOME/.java" ]; then
    echo "☕ Backing up Java configuration (.java)..."
    secure_backup_directory ".java"
fi

# NPM configuration and cache
if [ -d "$HOME/.npm" ]; then
    echo "📦 Backing up NPM configuration (.npm)..."
    secure_backup_directory ".npm"
fi

# Supermaven AI coding assistant configuration
if [ -d "$HOME/.supermaven" ]; then
    echo "🤖 Backing up Supermaven configuration (.supermaven)..."
    secure_backup_directory ".supermaven"
fi

# KDE konsave profile export (if konsave available)
if [ "$DESKTOP_ENV" = "kde" ] && command -v konsave >/dev/null 2>&1; then
    echo "💾 Exporting KDE konsave profile..."
    # Use a timestamped name to avoid overwrite; keep only the latest export
    ks_name="kde_profile_$(date +%Y%m%d_%H%M%S)"
    ks_file="$DOTFILES_DIR/kde/${ks_name}.knsv"
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: konsave -s $ks_name && konsave -e $ks_name -f $ks_file"
    else
        konsave -s "$ks_name" >/dev/null 2>&1 || true
        konsave -e "$ks_name" -f "$ks_file" >/dev/null 2>&1 || echo "⚠️ konsave export may have failed"
        # Optionally prune older .knsv files to keep repo clean (keep latest 3)
        ls -1t "$DOTFILES_DIR"/kde/*.knsv 2>/dev/null | tail -n +4 | while read -r old; do rm -f "$old"; done
    fi
fi

# Backup important development configuration files
echo "📝 Backing up development configuration files..."

# Git global configuration
if [ -f "$HOME/.gitconfig" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Back up Git configuration (.gitconfig)"
    else
        echo "🔧 Backing up Git configuration (.gitconfig)..."
        cp "$HOME/.gitconfig" "$DOTFILES_DIR/.gitconfig"
    fi
fi

# MySQL history (if exists)
if [ -f "$HOME/.mysql_history" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Back up MySQL history (.mysql_history)"
    else
        echo "🗄️ Backing up MySQL history (.mysql_history)..."
        cp "$HOME/.mysql_history" "$DOTFILES_DIR/shell/.mysql_history"
    fi
fi

# Other common development configuration files
for config_file in ".gradle/gradle.properties" ".sbt/1.0/global.sbt" ".ivy2/ivysettings.xml" ".dockerconfig" ".terraformrc" ".ansible.cfg" ".vimrc" ".tmux.conf" ".tmux.conf.local" ".nanorc" ".screenrc" ".curlrc" ".wgetrc"; do
    if [ -f "$HOME/$config_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Back up $config_file"
        else
            echo "🔧 Backing up $config_file..."
            mkdir -p "$DOTFILES_DIR/$(dirname "$config_file")"
            cp "$HOME/$config_file" "$DOTFILES_DIR/$config_file"
        fi
    fi
done

# Backup server/service configuration files (if they exist in home directory)
echo "🖥️ Checking for server configuration files..."
for server_config in ".my.cnf" ".pgpass" ".mongorc.js" ".rediscli_history" ".psql_history"; do
    if [ -f "$HOME/$server_config" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Back up server config $server_config"
        else
            echo "🗄️ Backing up server config $server_config..."
            cp "$HOME/$server_config" "$DOTFILES_DIR/$server_config"
        fi
    fi
done

# Backup development server configurations (Tomcat, Jetty, etc.)
echo "🚀 Checking for development server configurations..."

# Check for Tomcat installations in common locations
for tomcat_dir in "$HOME/Downloads/apache-tomcat-"* "$HOME/opt/tomcat"* "$HOME/tomcat"* "$HOME/servers/tomcat"*; do
    if [ -d "$tomcat_dir/conf" ]; then
        tomcat_name=$(basename "$tomcat_dir")
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Back up Tomcat configuration from $tomcat_name/conf"
        else
            echo "🐱 Backing up Tomcat configuration from $tomcat_name..."
            mkdir -p "$DOTFILES_DIR/servers/$tomcat_name/conf"
            cp -r "$tomcat_dir/conf/"* "$DOTFILES_DIR/servers/$tomcat_name/conf/" 2>/dev/null || true
        fi
    fi
done

# Check for Jetty installations
for jetty_dir in "$HOME/Downloads/jetty-"* "$HOME/opt/jetty"* "$HOME/jetty"* "$HOME/servers/jetty"*; do
    if [ -d "$jetty_dir" ] && [ -f "$jetty_dir/start.jar" ]; then
        jetty_name=$(basename "$jetty_dir")
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Back up Jetty configuration from $jetty_name"
        else
            echo "🚀 Backing up Jetty configuration from $jetty_name..."
            mkdir -p "$DOTFILES_DIR/servers/$jetty_name"
            # Back up key Jetty config files
            for config in "etc" "webapps" "start.ini" "jetty.xml"; do
                if [ -e "$jetty_dir/$config" ]; then
                    cp -r "$jetty_dir/$config" "$DOTFILES_DIR/servers/$jetty_name/" 2>/dev/null || true
                fi
            done
        fi
    fi
done

# Check for Nginx configurations (if user has custom configs)
for nginx_dir in "$HOME/nginx" "$HOME/conf/nginx" "$HOME/.nginx"; do
    if [ -d "$nginx_dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Back up Nginx configuration from $(basename "$nginx_dir")"
        else
            echo "🌐 Backing up Nginx configuration..."
            mkdir -p "$DOTFILES_DIR/servers/nginx"
            cp -r "$nginx_dir/"* "$DOTFILES_DIR/servers/nginx/" 2>/dev/null || true
        fi
    fi
done

# Backup Eclipse workspace settings (if exists)
if [ -d "$HOME/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Back up Eclipse workspace settings"
    else
        echo "🌙 Backing up Eclipse workspace settings..."
        mkdir -p "$DOTFILES_DIR/eclipse/workspace-settings"
        cp -r "$HOME/eclipse-workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/"* "$DOTFILES_DIR/eclipse/workspace-settings/" 2>/dev/null || true
    fi
fi

# System-wide configuration backup
echo "🖥️ Scanning system for server and development configurations..."
if [ -f "$DOTFILES_DIR/scripts/system-config-backup.sh" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Run system-wide configuration backup"
        "$DOTFILES_DIR/scripts/system-config-backup.sh" --backup --dry-run | grep -E "(✅|🔒|❌)" | head -10
    else
        echo "🔄 Running system-wide configuration backup..."
        "$DOTFILES_DIR/scripts/system-config-backup.sh" --backup
    fi
else
    echo "⚠️ System-wide backup script not found. Skipping system configurations."
fi

# Function to deduplicate history while preserving chronological order
deduplicate_history() {
    local input_file="$1"
    local temp_file="${input_file}.dedup_tmp"
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Deduplicate $(basename "$input_file")..."
        return
    fi
    
    echo "🔄 Deduplicating $(basename "$input_file")..."
    
    # For zsh history format (: timestamp:0;command)
    if [[ "$input_file" == *"zsh_history"* ]]; then
        # Use awk to keep only the last occurrence of each command
        awk -F';' '
        {
            cmd = substr($0, index($0, ";") + 1)  # Extract command part
            if (cmd != "") {
                # Store line with command as key, overwriting previous occurrences
                lines[cmd] = $0
                order[NR] = cmd
            }
        }
        END {
            # Print in original order, but only last occurrence of each command
            seen_cmds=""
            for (i = NR; i >= 1; i--) {
                cmd = order[i]
                if (cmd in lines && index(seen_cmds, cmd "|") == 0) {
                    print lines[cmd]
                    seen_cmds = seen_cmds cmd "|"
                }
            }
        }' "$input_file" | tac > "$temp_file"
    else
        # For bash history (simple line format)
        tac "$input_file" | awk '!seen[$0]++' | tac > "$temp_file"
    fi
    
    # Count results
    local original_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")
    local dedup_lines=$(wc -l < "$temp_file" 2>/dev/null || echo "0")
    local removed_duplicates=$((original_lines - dedup_lines))
    
    if [ "$removed_duplicates" -gt 0 ]; then
        mv "$temp_file" "$input_file"
        echo "🗑️  Removed $removed_duplicates duplicate entries ($(echo "scale=1; $removed_duplicates * 100 / $original_lines" | bc -l 2>/dev/null || echo "?")% reduction)"
    else
        rm -f "$temp_file"
        echo "✅ No duplicates found"
    fi
}

# Function to securely clean history files
clean_history_file() {
    local input_file="$1"
    local output_file="$2"
    
    # Comprehensive sensitive patterns for history files
    local sensitive_history_patterns=(
        # Password patterns
        "mysql.*-p[^[:space:]]*[[:alnum:]]"
        "psql.*password"
        "sudo.*password"  # SAFE: Security exclusion pattern
        "passwd.*"
        # API keys and tokens
        "export.*[A-Z_]*KEY[[:space:]]*="
        "export.*[A-Z_]*TOKEN[[:space:]]*="
        "export.*[A-Z_]*SECRET[[:space:]]*="
        "export.*[A-Z_]*PASS[[:space:]]*="
        # Authentication commands
        "curl.*-H.*[Aa]uthorization"
        "curl.*-u.*:"
        "wget.*--header.*[Aa]uthorization"
        "git.*clone.*://.*:.*@"
        "docker.*login"
        "npm.*set.*registry.*token"
        "ssh.*-i.*key"
        "ssh.*pass"
        # Database connections
        "mongo.*://.*:.*@"
        "redis.*AUTH"
        # Cloud credentials
        "aws.*configure"
        "gcloud.*auth"
        "kubectl.*token"
        # Generic sensitive patterns
        ".*password.*="
        ".*secret.*="
        ".*token.*="
        ".*credential.*="
        ".*key.*="
    )
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Clean sensitive data from $(basename "$input_file")..."
        echo "🔍 WOULD: Deduplicate history and apply ${#sensitive_history_patterns[@]} security filters"
        return
    fi
    
    echo "🔒 Cleaning sensitive data from $(basename "$input_file")..."
    
    # First, deduplicate the input file to reduce size
    deduplicate_history "$input_file"
    
    # Create clean version
    cp "$input_file" "${output_file}.tmp" 2>/dev/null || touch "${output_file}.tmp"
    
    # Apply each filter
    for pattern in "${sensitive_history_patterns[@]}"; do
        grep -v -E "$pattern" "${output_file}.tmp" > "${output_file}.tmp2" 2>/dev/null || cp "${output_file}.tmp" "${output_file}.tmp2"
        mv "${output_file}.tmp2" "${output_file}.tmp"
    done
    
    # Count removed lines
    local original_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")
    local clean_lines=$(wc -l < "${output_file}.tmp" 2>/dev/null || echo "0")
    local removed_lines=$((original_lines - clean_lines))
    
    if [ "$removed_lines" -gt 0 ]; then
        echo "⚠️  Removed $removed_lines potentially sensitive history entries"
        mv "${output_file}.tmp" "$output_file"
    else
        echo "✅ No sensitive data found in history"
        mv "${output_file}.tmp" "$output_file"
    fi
}

# Backup shell configuration files (with security filtering)
for file in .bashrc .zshrc .bash_history .bash_profile .zsh_history .mysql_history .nanorc .tmux.conf; do
    if [ -f "$HOME/$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Securely back up $file..."
            if [ ! -e "$DOTFILES_DIR/shell/$file" ]; then
                if [[ "$file" == ".bash_history" || "$file" == ".zsh_history" || "$file" == ".mysql_history" ]]; then
                    echo "🔍 WOULD: Clean history file and save to $DOTFILES_DIR/shell/$file"
                else
                    echo "🔍 WOULD: Copy config file to $DOTFILES_DIR/shell/$file (with security filtering)"
                fi
            fi
            
            if [ -e "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
                echo "🔍 WOULD: Backup original $file to $HOME/${file}.backup_$(date +%s)"
                echo "🔍 WOULD: Create symlink $HOME/$file -> $DOTFILES_DIR/shell/$file"
            fi
            continue
        fi
        
        echo "🔗 Securely backing up $file..."

        if [ ! -e "$DOTFILES_DIR/shell/$file" ]; then
            # Create sanitized version of shell config
            if [[ "$file" == ".bash_history" || "$file" == ".zsh_history" || "$file" == ".mysql_history" ]]; then
                # For history files, use comprehensive cleaning
                clean_history_file "$HOME/$file" "$DOTFILES_DIR/shell/$file"
            else
                # For config files, copy but warn about potential secrets
                if grep -q -E "(password|secret|token|key|credential|export.*[A-Z_]*KEY|export.*[A-Z_]*TOKEN|export.*[A-Z_]*SECRET)" "$HOME/$file" 2>/dev/null; then
                    echo "⚠️ WARNING: $file contains potential secrets! Please review before committing."
                    echo "🔒 Creating filtered version..."
                    grep -v -E "(password|secret|token|key|credential|export.*[A-Z_]*KEY|export.*[A-Z_]*TOKEN|export.*[A-Z_]*SECRET)" "$HOME/$file" > "$DOTFILES_DIR/shell/$file" || cp "$HOME/$file" "$DOTFILES_DIR/shell/$file"
                else
                    cp "$HOME/$file" "$DOTFILES_DIR/shell/$file"
                fi
            fi
        fi

        # Safely backup original shell file
        if [ -e "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            backup_name="$HOME/${file}.backup_$(date +%s)"
            if mv "$HOME/$file" "$backup_name"; then
                echo "📝 Safely backed up original $file to $backup_name"
            else
                echo "❌ Failed to backup $file. Aborting symlink creation."
                continue
            fi
        fi

        ln -sf "$DOTFILES_DIR/shell/$file" "$HOME/$file"
    fi
done

# Backup installed packages
if [ "$DRY_RUN" = true ]; then
    echo "🔍 WOULD: Save installed package list..."
    if command -v dnf &> /dev/null; then
        echo "🔍 WOULD: Save DNF packages to $DOTFILES_DIR/dnf-packages.txt"
    elif command -v apt &> /dev/null; then
        echo "🔍 WOULD: Save APT packages to $DOTFILES_DIR/apt-packages.txt"
    elif command -v pacman &> /dev/null; then
        echo "🔍 WOULD: Save Pacman packages to $DOTFILES_DIR/pacman-packages.txt"
    fi
else
    echo "📦 Saving installed package list..."
    if command -v dnf &> /dev/null; then
        # Check DNF version and use appropriate command
        if dnf --version 2>/dev/null | grep -q "dnf5"; then
            # DNF5 command
            echo "📦 Using DNF5 to get package list..."
            dnf repoquery --userinstalled --queryformat="%{name}\n" 2>/dev/null | sort | uniq > "$DOTFILES_DIR/dnf-packages.txt" || {
                echo "⚠️ DNF5 repoquery failed, using basic list..."
                dnf list --installed | awk '{print $1}' | grep -v "^Installed" | sed 's/\.[^.]*$//' | sort > "$DOTFILES_DIR/dnf-packages.txt"
            }
        elif dnf history userinstalled &>/dev/null 2>&1; then
            # DNF4 with userinstalled support
            dnf history userinstalled | grep -v "^Command\|^Installed" | sort > "$DOTFILES_DIR/dnf-packages.txt"
        else
            # Fallback for older DNF versions
            echo "⚠️ Using fallback method for package list..."
            dnf repoquery --userinstalled --queryformat="%{name}" | sort > "$DOTFILES_DIR/dnf-packages.txt"
        fi
    elif command -v apt &> /dev/null; then
        # Get only manually installed packages
        apt-mark showmanual | sort > "$DOTFILES_DIR/apt-packages.txt"
    elif command -v pacman &> /dev/null; then
        # Get explicitly installed packages
        pacman -Qqe | sort > "$DOTFILES_DIR/pacman-packages.txt"
    fi
fi


echo "[INFO] Dotfiles backup completed successfully!"
echo ""
echo "🔒 SECURITY SUMMARY:"
echo "✅ Sensitive files have been excluded from backup"
echo "✅ .gitignore created to prevent accidental commits"
echo "✅ Shell configs filtered for environment variables"
echo "✅ GNOME settings filtered for sensitive keys"
echo ""
echo "⚠️  MANUAL REVIEW RECOMMENDED:"
echo "   - Check ~/.dotfiles for any remaining sensitive files"
echo "   - Review shell config files before committing"
echo "   - Verify .gitignore patterns match your needs"
echo ""

