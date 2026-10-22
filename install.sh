#!/usr/bin/env bash
# WindVim installer. Copies config only; Neovim installs plugins on first launch.
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
APPNAME=windvim
FORCE=0
LAUNCHER=1
NVIM_BIN="${NVIM_BIN:-nvim}"

usage() {
    cat <<'HELP'
Usage: ./install.sh [--appname NAME] [--force] [--no-launcher]

  --appname NAME   Isolated Neovim config name (default: windvim)
  --force          Back up an existing config/launcher before replacing it
  --no-launcher    Do not create ~/.local/bin/windvim

Honors XDG_CONFIG_HOME, WINDVIM_BIN_DIR and NVIM_BIN. No sudo required.
Plugins are downloaded on first launch; this script never updates plugins.
HELP
}
fail() { printf 'windvim: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --appname) [ "$#" -ge 2 ] || fail '--appname requires a name'; APPNAME="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --no-launcher) LAUNCHER=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
[[ "$APPNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || fail 'App name must contain only letters, digits, _ or -'
for tool in "$NVIM_BIN" rsync git; do
    command -v "$tool" >/dev/null 2>&1 || fail "Missing dependency: $tool (see README.md)"
done
"$NVIM_BIN" --clean --headless -i NONE \
    '+lua if vim.fn.has("nvim-0.11.2") == 0 or not jit then vim.cmd("cquit 1") end' +qa \
    || fail 'Neovim >= 0.11.2 with LuaJIT is required'
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="${WINDVIM_BIN_DIR:-$HOME/.local/bin}"
[[ "$CONFIG_HOME" = /* && "$BIN_DIR" = /* ]] || fail 'Config and bin paths must be absolute'
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
exec "\${NVIM_BIN:-nvim}" "\$@"
LAUNCH
    chmod +x "$LAUNCHER_PATH"
fi
printf 'Installed WindVim: %s\n' "$DEST"
printf 'Start: NVIM_APPNAME=%s %s\n' "$APPNAME" "$NVIM_BIN"
if [ "$LAUNCHER" -eq 1 ]; then
    printf 'Or run: %s (add %s to PATH)\n' "$LAUNCHER_PATH" "$BIN_DIR"
fi
