#!/usr/bin/env bash
# WindVim installer. Bootstraps dependencies; plugins install on first launch.
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
APPNAME=windvim
FORCE=0
LAUNCHER=1
SETUP_PATH=1
INSTALL_DEPS=1
NVIM_EXPLICIT=0
[ -z "${NVIM_BIN:-}" ] || NVIM_EXPLICIT=1
NVIM_BIN="${NVIM_BIN:-nvim}"

usage() {
    cat <<'HELP'
Usage: ./install.sh [--appname NAME] [--force] [--no-launcher] [--no-path] [--no-deps]

  --appname NAME   Isolated Neovim config name (default: windvim)
  --force          Back up an existing config/launcher before replacing it
  --no-launcher    Do not create ~/.local/bin/windvim
  --no-path        Do not update shell startup files
  --no-deps        Only check core dependencies; do not install missing tools

Adds the launcher directory to PATH for Bash, Zsh or Fish on new terminals.
Honors XDG_CONFIG_HOME, XDG_DATA_HOME, WINDVIM_BIN_DIR, NVIM_BIN, SHELL and ZDOTDIR.
Missing system packages are installed using root/sudo or Homebrew on macOS.
Ubuntu/Debian use a verified official Neovim binary in the user's data directory.
Plugins are downloaded on first launch; this script never updates plugins.
HELP
}
fail() { printf 'windvim: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --appname) [ "$#" -ge 2 ] || fail '--appname requires a name'; APPNAME="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --no-launcher) LAUNCHER=0; shift ;;
        --no-path) SETUP_PATH=0; shift ;;
        --no-deps) INSTALL_DEPS=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
[[ "$APPNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || fail 'App name must contain only letters, digits, _ or -'
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="${WINDVIM_BIN_DIR:-$HOME/.local/bin}"
TOOLS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/windvim-tools"
MANAGED_NVIM="$TOOLS_DIR/neovim/bin/nvim"
[[ "$CONFIG_HOME" = /* && "$BIN_DIR" = /* && "$TOOLS_DIR" = /* ]] || fail 'Config, data and bin paths must be absolute'
mkdir -p "$CONFIG_HOME"
CONFIG_HOME="$(cd "$CONFIG_HOME" && pwd -P)"
DEST="$CONFIG_HOME/$APPNAME"
LAUNCHER_PATH="$BIN_DIR/windvim"
# Moving an installed clone would move this installer and its source with it.
[[ "$SOURCE_DIR/" != "$DEST/"* ]] || fail 'Source is inside the install target; use git pull here, or install from another directory'
if [ "$FORCE" -eq 0 ]; then
    [ ! -e "$DEST" ] && [ ! -L "$DEST" ] || fail "Config already exists: $DEST (use --force to back it up)"
    if [ "$LAUNCHER" -eq 1 ]; then
        [ ! -e "$LAUNCHER_PATH" ] && [ ! -L "$LAUNCHER_PATH" ] || fail "Launcher already exists: $LAUNCHER_PATH (use --force to back it up)"
    fi
fi
# Refuse conflicting destinations before installing any packages.
. "$SOURCE_DIR/scripts/dependencies.sh"
ensure_dependencies
STAGING="$(mktemp -d "$CONFIG_HOME/.windvim-install.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
# An allowlist keeps docs, screenshots, Git metadata and development artifacts out.
rsync -a --exclude='__pycache__/' --exclude='*.pyc' \
    "$SOURCE_DIR/lua" "$SOURCE_DIR/local-plugins" "$STAGING/"
for file in init.lua lazy-lock.json lazyvim.json .neoconf.json stylua.toml LICENSE NOTICE; do
    cp "$SOURCE_DIR/$file" "$STAGING/"
done
STAMP="$(date +%Y%m%d-%H%M%S).$$"
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
    mv "$DEST" "$DEST.backup.$STAMP"
    printf 'Config backup: %s\n' "$DEST.backup.$STAMP"
fi
mv "$STAGING" "$DEST"
if [ "$LAUNCHER" -eq 1 ]; then
    mkdir -p "$BIN_DIR"
    if [ -e "$LAUNCHER_PATH" ] || [ -L "$LAUNCHER_PATH" ]; then
        mv "$LAUNCHER_PATH" "$LAUNCHER_PATH.backup.$STAMP"
        printf 'Launcher backup: %s\n' "$LAUNCHER_PATH.backup.$STAMP"
    fi
    cat > "$LAUNCHER_PATH" <<LAUNCH
#!/usr/bin/env sh
export NVIM_APPNAME='$APPNAME'
if [ -z "\${NVIM_BIN:-}" ] && [ -x "\${XDG_DATA_HOME:-\$HOME/.local/share}/windvim-tools/neovim/bin/nvim" ]; then
    NVIM_BIN="\${XDG_DATA_HOME:-\$HOME/.local/share}/windvim-tools/neovim/bin/nvim"
fi
exec "\${NVIM_BIN:-nvim}" "\$@"
LAUNCH
    chmod +x "$LAUNCHER_PATH"
fi
setup_path() {
    local shell_name="${SHELL##*/}" quoted block file content login_file
    local files=()
    case "$shell_name" in
        bash|zsh)
            quoted="${BIN_DIR//\'/\'\\\'\'}"
            quoted="'$quoted'"
            block="$(cat <<PATH_BLOCK
# WindVim launcher PATH
case ":\$PATH:" in
    *:$quoted:*) ;;
    *) export PATH=$quoted:"\$PATH" ;;
esac
PATH_BLOCK
)"
            if [ "$shell_name" = bash ]; then
                login_file="$HOME/.profile"
                if [ -f "$HOME/.bash_profile" ]; then
                    login_file="$HOME/.bash_profile"
                elif [ -f "$HOME/.bash_login" ]; then
                    login_file="$HOME/.bash_login"
                fi
                files=("$HOME/.bashrc" "$login_file")
            else
                files=("${ZDOTDIR:-$HOME}/.zshrc" "${ZDOTDIR:-$HOME}/.zprofile")
            fi
            ;;
        fish)
            quoted="${BIN_DIR//\\/\\\\}"
            quoted="${quoted//\'/\\\'}"
            block="$(cat <<PATH_BLOCK
# WindVim launcher PATH
if not contains -- '$quoted' \$PATH
    set -gx PATH '$quoted' \$PATH
end
PATH_BLOCK
)"
            files=("$CONFIG_HOME/fish/conf.d/windvim-path.fish")
            ;;
        *)
            printf 'Shell PATH setup skipped for %s. Add %s to PATH manually.\n' "${SHELL:-unknown shell}" "$BIN_DIR"
            return
            ;;
    esac
    for file in "${files[@]}"; do
        content=""
        [ ! -f "$file" ] || content="$(cat "$file")"
        if [[ "$content" != *"$block"* ]]; then
            mkdir -p "$(dirname "$file")"
            if [ -e "$file" ]; then
                cp -p -- "$file" "$file.backup.$STAMP"
                printf 'Shell config backup: %s\n' "$file.backup.$STAMP"
            fi
            printf '\n%s\n' "$block" >> "$file"
            printf 'PATH configured: %s\n' "$file"
        fi
    done
    printf 'Open a new terminal, then run: windvim\n'
    printf 'In this terminal, run directly: %s\n' "$LAUNCHER_PATH"
}
if [ "$LAUNCHER" -eq 1 ] && [ "$SETUP_PATH" -eq 1 ]; then
    setup_path
fi
printf 'Installed WindVim: %s\n' "$DEST"
printf 'Start: NVIM_APPNAME=%s %q\n' "$APPNAME" "$NVIM_BIN"
if [ "$LAUNCHER" -eq 1 ]; then
    printf 'Launcher: %s\n' "$LAUNCHER_PATH"
fi
