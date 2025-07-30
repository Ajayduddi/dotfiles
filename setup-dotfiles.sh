#!/bin/bash

set -e

# Parse command line arguments
DRY_RUN=false
FORCE_RERUN=false

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE: Will show what would be done without making changes"
            echo ""
            ;;
        --force|-f)
            FORCE_RERUN=true
            echo "⚠️  FORCE MODE: Will re-run setup even if already completed"
            echo ""
            ;;
        --help|-h)
            echo "🔧 DOTFILES SETUP SCRIPT"
            echo "========================"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run, -n    Show what would be done without making changes"
            echo "  --force, -f      Force re-run even if setup was already completed"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                    # Run full setup"
            echo "  $0 --dry-run         # Test what would happen"
            echo "  $0 --force           # Force re-run setup"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "💡 Use --help for usage information"
            exit 1
            ;;
    esac
done

# Define dotfiles directory
DOTFILES_DIR="$HOME/.dotfiles"
SETUP_MARKER="$DOTFILES_DIR/.setup_completed"

# Exit if .dotfiles folder does not exist
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "❌ Error: '$DOTFILES_DIR' directory does not exist."
    echo "➡️ Please create the .dotfiles directory before running this script."
    exit 1
fi

# Check if setup has already been completed
check_previous_setup() {
    local setup_indicators=()
    
    # Check for setup completion marker
    if [ -f "$SETUP_MARKER" ]; then
        setup_indicators+=("Setup marker file exists")
    fi
    
    # Check for existing symlinks
    local symlink_count=0
    for path in ".bashrc" ".zshrc" ".config" ".themes" ".icons" ".fonts"; do
        if [ -L "$HOME/$path" ]; then
            local link_target=$(readlink "$HOME/$path" 2>/dev/null || echo "")
            if [ "$link_target" = "$DOTFILES_DIR/shell/$path" ] || [ "$link_target" = "$DOTFILES_DIR/$path" ]; then
                ((symlink_count++))
                setup_indicators+=("$path is symlinked to dotfiles")
            fi
        fi
    done
    
    # Check for dotfiles git repo
    if [ -d "$DOTFILES_DIR/.git" ]; then
        setup_indicators+=("Git repository initialized")
    fi
    
    # Check for backed up files
    local backup_count=0
    
    # Check shell directory files
    if [ -d "$DOTFILES_DIR/shell" ]; then
        for file in "$DOTFILES_DIR/shell/"*; do
            if [ -f "$file" ]; then
                ((backup_count++))
            fi
        done
    fi
    
    # Check specific files
    if [ -f "$DOTFILES_DIR/gnome-settings.dconf" ]; then
        ((backup_count++))
    fi
    
    for file in "$DOTFILES_DIR/"*packages.txt; do
        if [ -f "$file" ] && [[ "$file" != "$DOTFILES_DIR/*packages.txt" ]]; then
            ((backup_count++))
        fi
    done
    
    if [ $backup_count -gt 0 ]; then
        setup_indicators+=("$backup_count backup files found")
    fi
    
    # If we found indicators, show them and ask for confirmation
    if [ ${#setup_indicators[@]} -gt 0 ]; then
        echo "🚨 SETUP ALREADY COMPLETED DETECTED!"
        echo "=================================="
        echo ""
        echo "Evidence of previous setup:"
        for indicator in "${setup_indicators[@]}"; do
            echo "  ✅ $indicator"
        done
        echo ""
        
        if [ "$FORCE_RERUN" = true ]; then
            echo "⚠️  FORCE MODE: Proceeding with re-setup..."
            echo "🔄 This may create duplicate backups and overwrite existing symlinks"
            echo ""
            return 0
        fi
        
        echo "⚠️  Running setup again may cause:"
        echo "   • Duplicate backup files"
        echo "   • Broken symlinks"
        echo "   • Data loss or conflicts"
        echo ""
        echo "🛠️  If you want to update your dotfiles, use:"
        echo "   ./backup-dotfiles.sh    # For incremental backups"
        echo ""
        echo "💡 To force re-run anyway, use: $0 --force"
        echo ""
        
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 DRY RUN: Would exit here to prevent re-setup"
            echo "🔍 DRY RUN: Continuing with preview mode..."
            return 0
        fi
        
        read -p "Do you really want to re-run the setup? (y/N): " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "✅ Setup cancelled to prevent conflicts"
            echo "💡 Use './backup-dotfiles.sh' for regular updates"
            exit 0
        fi
        
        echo "⚠️  Proceeding with re-setup at your own risk..."
        echo ""
    fi
    
    return 0
}

# Check for previous setup
check_previous_setup

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
fi

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
        ""
        "# Setup and maintenance files"
        ".setup_completed"
        "*.backup_*"
        "*.dedup_tmp"
        "*_tmp"
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
            
            echo "✅ Security patterns added to .gitignore"
        fi
    else
        echo "🟡 Security patterns already exist in .gitignore"
    fi
}

# Sensitive file patterns to exclude during backup
SENSITIVE_PATTERNS=(
    # Authentication and keys
    "*/.ssh/*" "*/.gnupg/*" "*/.aws/*" "*/github-copilot/*"
    "*/.docker/config.json" "*/.netrc" "*/.pgpass" "*/github-copilot/*"
    # Generic sensitive patterns
    "*password*" "*secret*" "*token*" "*credential*" "*auth*"
    "*.pem" "*.key" "*.p12"
    # Cache and temporary files
    "*/cache/*" "*/Cache/*" "*/tmp/*" "*/temp/*" "*/logs/*"
    "*session*" "*Session*"
    # Applications with built-in sync (avoid conflicts)
    "*/Code/*" "*/VSCodium/*" "*/JetBrains/*" "*/IntelliJIdea*/*"
    "*/PyCharm*/*" "*/WebStorm*/*" "*/PhpStorm*/*" "*/CLion*/*"
    "*/DataGrip*/*" "*/GoLand*/*" "*/RubyMine*/*" "*/Rider*/*"
    "*/sublime-text*/*" "*/discord/*" "*/slack/*" "*/Slack/*"
    "*/spotify/*" "*/Spotify/*" "*/steam/*" "*/Steam/*"
    "*/postman/*" "*/Postman/*" "*/insomnia/*" "*/MongoDB*/*"
    "*/docker/*" "*/Docker*/*" "*/code-*/*"
)

# Function to check if a file/directory should be excluded
is_sensitive() {
    local path="$1"
    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        if [[ "$path" == $pattern ]]; then
            return 0  # Is sensitive
        fi
    done
    return 1  # Not sensitive
}

# Enhanced secure backup function for directories
secure_backup_directory() {
    local relative_path="$1"
    local src="$HOME/$relative_path"
    local dest="$DOTFILES_DIR/$relative_path"
    
    if [ ! -d "$src" ]; then
        echo "⚠️ Directory $relative_path not found, skipping."
        return
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Securely back up $relative_path (excluding sensitive files)..."
        echo "🔍 WOULD: Create destination directory $dest"
        echo "🔍 WOULD: Copy files excluding ${#SENSITIVE_PATTERNS[@]} sensitive patterns"
        return
    fi
    
    echo "🔒 Securely backing up $relative_path (excluding sensitive files)..."
    
    # Create destination directory
    mkdir -p "$dest"
    
    # Copy files selectively, excluding sensitive patterns
    find "$src" -type f | while read -r file; do
        # Get relative path from source directory
        rel_file="${file#$src/}"
        dest_file="$dest/$rel_file"
        
        if is_sensitive "$file"; then
            echo "🔒 Excluded sensitive file: $rel_file"
        else
            # Create destination directory if needed
            mkdir -p "$(dirname "$dest_file")"
            cp "$file" "$dest_file" 2>/dev/null || echo "❌ Failed to copy: $rel_file"
        fi
    done
    
    # Copy directory structure (empty directories)
    find "$src" -type d | while read -r dir; do
        rel_dir="${dir#$src}"
        if [ -n "$rel_dir" ]; then
            mkdir -p "$dest$rel_dir"
        fi
    done
    
    echo "✅ Sensitive files have been excluded from backup"
}

# Update .gitignore first
update_gitignore

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
            
            if [ -e "$src" ] && [ ! -L "$src" ]; then
                echo "🔍 WOULD: Backup original $relative_path to ${src}.backup_$(date +%s)"
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
    fi
}

# Backup .config directory securely (excluding sensitive files)
echo "🔒 Using secure backup for .config (sensitive files will be excluded)..."
secure_backup_directory ".config"

# Backup GNOME extensions (usually safe but using secure method)
secure_backup_directory ".local/share/gnome-shell/extensions"


# Check if dconf-cli is installed
if ! command -v dconf &> /dev/null; then
    echo "❌ dconf-cli not found!"
    echo "⚠️  dconf-cli is required to backup GNOME settings."
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Attempt to install dconf-cli or skip GNOME settings backup"
    else
        # Skip interactive prompt in non-interactive mode
        if [ -t 0 ]; then
            read -p "Do you want to install dconf-cli? (y/n): " install_dconf
        else
            install_dconf="n"
            echo "Running in non-interactive mode, skipping dconf-cli installation"
        fi
        
        if [[ "$install_dconf" =~ ^[Yy]$ ]]; then
            if command -v dnf &> /dev/null; then
                sudo dnf install -y dconf-cli
            elif command -v apt &> /dev/null; then
                sudo apt-get install -y dconf-cli
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm dconf-cli
            else
                echo "❌ Package manager not supported. Please install dconf-cli manually."
                exit 1
            fi
        else
            echo "⚠️ Skipping GNOME settings backup without dconf-cli"
            echo "# GNOME settings backup skipped - dconf-cli not installed" > "$DOTFILES_DIR/gnome-settings.dconf"
        fi
    fi
fi

# Backup GNOME Settings including extension preferences (excluding sensitive keys)
if command -v dconf &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Backup GNOME Settings (excluding sensitive keys) to $DOTFILES_DIR/gnome-settings.dconf"
    else
        echo "💾 Backing up GNOME Settings (excluding sensitive keys)..."
        dconf dump / | grep -v -E "(password|secret|token|credential|key)" > "$DOTFILES_DIR/gnome-settings.dconf" || {
            echo "⚠️ Some GNOME settings were excluded for security reasons"
            dconf dump / > "$DOTFILES_DIR/gnome-settings.dconf"
        }
    fi
else
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 WOULD: Skip GNOME settings backup (dconf not available)"
    fi
fi

# Backup themes, fonts and icons
move_and_symlink ".themes"
move_and_symlink ".icons"
move_and_symlink ".fonts"

# Backup shell configuration files (with security filtering)
for file in .bashrc .zshrc .bash_history .bash_profile .zsh_history; do
    if [ -f "$HOME/$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "🔍 WOULD: Securely back up $file..."
            if [ ! -e "$DOTFILES_DIR/shell/$file" ]; then
                if [[ "$file" == ".bash_history" || "$file" == ".zsh_history" ]]; then
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
            if [[ "$file" == ".bash_history" || "$file" == ".zsh_history" ]]; then
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

# Create setup completion marker
if [ "$DRY_RUN" = true ]; then
    echo "🔍 WOULD: Create setup completion marker at $SETUP_MARKER"
else
    echo "$(date): Dotfiles setup completed successfully" > "$SETUP_MARKER"
    echo "Setup script: $0" >> "$SETUP_MARKER"
    echo "Arguments: $*" >> "$SETUP_MARKER"
    echo "User: $(whoami)" >> "$SETUP_MARKER"
    echo "Hostname: $(hostname)" >> "$SETUP_MARKER"
fi

echo "✅ Dotfiles setup completed!"
echo ""
echo "🛠️  AVAILABLE MAINTENANCE TOOLS:"
echo "   • backup-dotfiles.sh     - Enhanced backup with all security features"
echo "   • clean-history.sh       - Clean sensitive data from history"
echo "   • dedupe-history.sh      - Remove duplicate history entries"
echo "   • analyze-history.sh     - Analyze history redundancy"
echo ""
echo "🔒 SECURITY FEATURES APPLIED:"
echo "   ✅ Sensitive files excluded from backup"
echo "   ✅ History files cleaned and deduplicated"
echo "   ✅ Comprehensive .gitignore patterns added"
echo "   ✅ Applications with built-in sync excluded"
echo ""
echo "🛡️  RE-RUN PROTECTION:"
echo "   ✅ Setup completion marker created"
echo "   ✅ Script will detect and prevent accidental re-runs"
echo "   💡 Use --force flag only if you really need to re-run"

