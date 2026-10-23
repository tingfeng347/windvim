# Sourced by install.sh. System packages are installed only when needed.
has_command() { command -v "$1" >/dev/null 2>&1; }

neovim_works() {
    has_command "$1" && "$1" --clean --headless -i NONE \
        '+lua if vim.fn.has("nvim-0.11.2") == 0 or not jit then vim.cmd("cquit 1") end' +qa >/dev/null 2>&1
}

dependency_platform() {
    local ID='' ID_LIKE=''
    case "$(uname -s)" in
        Darwin) printf 'brew\n'; return ;;
        Linux)
            [ ! -f /etc/os-release ] || . /etc/os-release
            case " $ID $ID_LIKE " in
                *' alpine '*) printf 'apk\n' ;;
                *' debian '*|*' ubuntu '*) printf 'apt\n' ;;
                *' arch '*|*' manjaro '*) printf 'pacman\n' ;;
                *' fedora '*|*' rhel '*|*' centos '*)
                    if has_command dnf; then printf 'dnf\n'; else printf 'yum\n'; fi ;;
                *' suse '*|*' opensuse '*|*' opensuse-tumbleweed '*|*' opensuse-leap '*) printf 'zypper\n' ;;
                *) printf 'unknown\n' ;;
            esac
            ;;
        *) printf 'unknown\n' ;;
    esac
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif has_command sudo; then
        sudo -- "$@"
    else
        fail 'Installing missing system packages requires root or sudo. Install dependencies manually, then use --no-deps (see docs/USAGE.md).'
    fi
}

install_packages() {
    local manager="$1"
    shift
    printf 'Installing dependencies (%s): %s\n' "$manager" "$*"
    case "$manager" in
        apt)
            run_as_root apt-get update
            run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
            ;;
        pacman)
            # Keep Arch repositories and installed libraries in sync (no partial upgrade).
            run_as_root pacman -Syu --needed --noconfirm "$@"
            ;;
        dnf|yum) run_as_root "$manager" install -y "$@" ;;
        zypper) run_as_root zypper --non-interactive install "$@" ;;
        apk) run_as_root apk add --no-cache "$@" ;;
        brew)
            has_command brew || fail 'Homebrew is required on macOS. Install it from https://brew.sh, then rerun ./install.sh.'
            [ "$(id -u)" -ne 0 ] || fail 'Run the macOS installer as your normal user; Homebrew does not support root.'
            brew install "$@"
            ;;
    esac
}

# Pin official assets and hashes: https://github.com/neovim/neovim/releases/tag/v0.11.5
# Never replace /usr/bin/nvim or a user-owned nvim command.
install_neovim_binary() (
    local asset checksum work actual
    case "$(uname -m)" in
        x86_64|amd64)
            asset=nvim-linux-x86_64
            checksum=b2f91117be5b5ea39edd7297156dc2a4a8df4add6c95a90809a8df19e7ab6f52
            ;;
        aarch64|arm64)
            asset=nvim-linux-arm64
            checksum=ea4f9a31b11cc1477ff014aebb7b207684e7280f94ffa97abdab6cacd9b98519
            ;;
        *) fail 'Official Neovim binaries support Linux x86_64/arm64. Install Neovim >= 0.11.2 with LuaJIT manually, then use --no-deps.' ;;
    esac
    mkdir -p "$TOOLS_DIR"
    work="$(mktemp -d "$TOOLS_DIR/.neovim-download.XXXXXX")"
    trap 'rm -rf "$work"' EXIT
    printf 'Downloading official Neovim v0.11.5 (%s)...\n' "$asset"
    curl --fail --location --retry 3 --connect-timeout 15 \
        "https://github.com/neovim/neovim/releases/download/v0.11.5/$asset.tar.gz" -o "$work/nvim.tar.gz" \
        || fail 'Neovim download failed. Check access to GitHub and rerun ./install.sh.'
    actual="$(sha256sum < "$work/nvim.tar.gz")"
    [ "${actual%% *}" = "$checksum" ] || fail 'Neovim archive checksum mismatch; refusing to extract it.'
    tar -xzf "$work/nvim.tar.gz" -C "$work"
    neovim_works "$work/$asset/bin/nvim" \
        || fail 'The official Neovim binary cannot run here (requires compatible glibc). Install Neovim >= 0.11.2 with LuaJIT manually and use --no-deps.'
    if [ -e "$TOOLS_DIR/neovim" ] || [ -L "$TOOLS_DIR/neovim" ]; then
        mv "$TOOLS_DIR/neovim" "$TOOLS_DIR/neovim.backup.$(date +%Y%m%d-%H%M%S).$$"
    fi
    mv "$work/$asset" "$TOOLS_DIR/neovim"
    printf 'Neovim installed: %s\n' "$MANAGED_NVIM"
)

ensure_dependencies() {
    local manager tool package need_nvim=0
    local packages=()
    # Reuse the managed binary on later installs, including with --no-deps.
    if [ "$NVIM_EXPLICIT" -eq 0 ] && neovim_works "$MANAGED_NVIM"; then
        NVIM_BIN="$MANAGED_NVIM"
    fi
    if ! neovim_works "$NVIM_BIN"; then
        [ "$NVIM_EXPLICIT" -eq 0 ] || fail "NVIM_BIN=$NVIM_BIN is unavailable or incompatible. Choose Neovim >= 0.11.2 with LuaJIT, or unset NVIM_BIN for automatic installation."
        need_nvim=1
    fi
    if [ "$INSTALL_DEPS" -eq 0 ]; then
        for tool in "$NVIM_BIN" rsync git; do
            has_command "$tool" || fail "Missing dependency: $tool (--no-deps disables automatic installation)"
        done
        [ "$need_nvim" -eq 0 ] || fail 'Neovim >= 0.11.2 with LuaJIT is required (--no-deps disables automatic installation)'
        return
    fi

    manager="$(dependency_platform)"
    for tool in git rsync curl rg fd cc make unzip tar gzip; do
        has_command "$tool" && continue
        # Debian calls fd "fdfind"; the launcher PATH receives a compatibility link.
        [ "$tool" != fd ] || ! has_command fdfind || continue
        [ "$manager" != unknown ] || fail "Missing dependency: $tool. This platform has no automatic installer; install dependencies manually and use --no-deps."
        package="$tool"
        case "$tool" in
            rg) package=ripgrep ;;
            fd)
                case "$manager" in apt|dnf|yum) package=fd-find ;; esac ;;
            cc)
                case "$manager" in
                    apt) package=build-essential ;;
                    apk) package=build-base ;;
                    brew)
                        xcode-select --install || true
                        fail 'Finish installing Xcode Command Line Tools, then rerun ./install.sh.' ;;
                    *) package=gcc ;;
                esac
                ;;
        esac
        packages+=("$package")
    done
    # Debian-family Neovim packages may be too old; use official glibc binaries.
    if [ "$need_nvim" -eq 1 ]; then
        [ "$manager" != unknown ] || fail 'Install Neovim >= 0.11.2 with LuaJIT manually on this platform, then use --no-deps.'
        if [ "$manager" != apt ]; then
            packages+=(neovim)
        elif ! has_command sha256sum; then
            packages+=(coreutils)
        fi
    fi
    if [ "${#packages[@]}" -gt 0 ]; then
        # Certificates are needed for plugin and Neovim downloads on minimal VMs.
        [ "$manager" = brew ] || packages+=(ca-certificates)
        install_packages "$manager" "${packages[@]}"
    fi
    if [ "$need_nvim" -eq 1 ] && [ "$manager" = apt ]; then
        install_neovim_binary
        NVIM_BIN="$MANAGED_NVIM"
    fi
    for tool in git rsync curl rg cc make unzip tar gzip; do
        has_command "$tool" || fail "Dependency installation did not provide $tool; see docs/USAGE.md."
    done
    if ! has_command fd; then
        has_command fdfind || fail 'Dependency installation did not provide fd/fdfind; see docs/USAGE.md.'
        mkdir -p "$BIN_DIR"
        # Do not overwrite an existing file, including dangling symlinks.
        if [ ! -e "$BIN_DIR/fd" ] && [ ! -L "$BIN_DIR/fd" ]; then
            ln -s "$(command -v fdfind)" "$BIN_DIR/fd"
        fi
    fi
    neovim_works "$NVIM_BIN" || fail 'Neovim >= 0.11.2 with LuaJIT is still required. Your repository version may be too old; install a supported build and set NVIM_BIN (see docs/USAGE.md).'
}
