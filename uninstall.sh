#!/usr/bin/env bash
# Remove an isolated WindVim installation while keeping configuration backups.
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
APPNAME=windvim
PURGE=0
LAUNCHER=1

usage() {
    cat <<'HELP'
Usage: ./uninstall.sh [--appname NAME] [--purge] [--no-launcher]

  --appname NAME   Isolated Neovim config name (default: windvim)
  --purge          Also delete this app's plugin data, cache and state
  --no-launcher    Leave the windvim launcher untouched

Config and matching launcher are moved to timestamped backups.
Honors XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME, XDG_STATE_HOME
and WINDVIM_BIN_DIR. Close WindVim before uninstalling. No sudo required.
HELP
}
fail() { printf 'windvim: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --appname) [ "$#" -ge 2 ] || fail '--appname requires a name'; APPNAME="$2"; shift 2 ;;
        --purge) PURGE=1; shift ;;
        --no-launcher) LAUNCHER=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
[[ "$APPNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || fail 'App name must contain only letters, digits, _ or -'
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BIN_DIR="${WINDVIM_BIN_DIR:-$HOME/.local/bin}"

# Validate every target before moving or deleting anything. Never traverse a
# target symlink, or remove the checkout containing this script.
check_target() {
    local base="$1" path
    [[ "$base" = /* ]] || fail "Path must be absolute: $base"
    path="${base%/}/$2"
    if [ -d "$path" ] && [ ! -L "$path" ]; then
        path="$(cd "$path" && pwd -P)"
        [[ "$SOURCE_DIR/" != "$path/"* ]] || fail "Source is inside the uninstall target: $path"
    fi
}
check_target "$CONFIG_HOME" "$APPNAME"
if [ "$PURGE" -eq 1 ]; then
    check_target "$DATA_HOME" "$APPNAME"
    check_target "$CACHE_HOME" "$APPNAME"
    check_target "$STATE_HOME" "$APPNAME"
fi
if [ "$LAUNCHER" -eq 1 ]; then
    check_target "$BIN_DIR" windvim
fi

STAMP="$(date +%Y%m%d-%H%M%S).$$"
backup() {
    local path="$1"
    if [ -e "$path" ] || [ -L "$path" ]; then
        mv -- "$path" "$path.backup.$STAMP"
        printf 'Backup: %s\n' "$path.backup.$STAMP"
    fi
}
backup "${CONFIG_HOME%/}/$APPNAME"
if [ "$LAUNCHER" -eq 1 ]; then
    LAUNCHER_PATH="${BIN_DIR%/}/windvim"
    LEGACY_EXPECTED="$(cat <<LAUNCH
#!/usr/bin/env sh
export NVIM_APPNAME='$APPNAME'
exec "\${NVIM_BIN:-nvim}" "\$@"
LAUNCH
)"
    EXPECTED="$(cat <<LAUNCH
#!/usr/bin/env sh
export NVIM_APPNAME='$APPNAME'
if [ -z "\${NVIM_BIN:-}" ] && [ -x "\${XDG_DATA_HOME:-\$HOME/.local/share}/windvim-tools/neovim/bin/nvim" ]; then
    NVIM_BIN="\${XDG_DATA_HOME:-\$HOME/.local/share}/windvim-tools/neovim/bin/nvim"
fi
exec "\${NVIM_BIN:-nvim}" "\$@"
LAUNCH
)"
    if [ -f "$LAUNCHER_PATH" ] && [ ! -L "$LAUNCHER_PATH" ] && { [ "$(cat "$LAUNCHER_PATH")" = "$EXPECTED" ] || [ "$(cat "$LAUNCHER_PATH")" = "$LEGACY_EXPECTED" ]; }; then
        backup "$LAUNCHER_PATH"
    elif [ -e "$LAUNCHER_PATH" ] || [ -L "$LAUNCHER_PATH" ]; then
        printf 'Kept unrelated launcher: %s\n' "$LAUNCHER_PATH"
    fi
fi
if [ "$PURGE" -eq 1 ]; then
    for base in "$DATA_HOME" "$CACHE_HOME" "$STATE_HOME"; do
        path="${base%/}/$APPNAME"
        if [ -e "$path" ] || [ -L "$path" ]; then
            rm -rf -- "$path"
            printf 'Removed: %s\n' "$path"
        fi
    done
fi
printf 'Uninstalled WindVim: %s (configuration backups retained)\n' "$APPNAME"
