#!/usr/bin/env bash
# Explicitly update/install plugins for an already installed WindVim config.
set -euo pipefail
APPNAME="${NVIM_APPNAME:-windvim}"
NVIM_BIN="${NVIM_BIN:-nvim}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
[ -f "$CONFIG/init.lua" ] || { printf 'Install WindVim first: ./install.sh\n' >&2; exit 1; }
export NVIM_APPNAME="$APPNAME"
exec "$NVIM_BIN" --headless '+Lazy! sync' +qa
