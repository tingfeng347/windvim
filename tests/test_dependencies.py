"""Mock package managers and downloads; never install packages on the test host."""
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CORE = 'git rsync curl rg fd cc make unzip tar gzip sha256sum'


class DependencyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='windvim-deps-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name) / 'paths with spaces'
        self.base.mkdir()
        self.env = dict(os.environ, TEST_BASE=str(self.base), DEP_SCRIPT=str(ROOT / 'scripts/dependencies.sh'))
        self.prelude = '''
set -euo pipefail
. "$DEP_SCRIPT"
fail() { printf 'windvim: %s\\n' "$*" >&2; exit 1; }
TOOLS_DIR="$TEST_BASE/tools"
BIN_DIR="$TEST_BASE/bin"
MANAGED_NVIM="$TOOLS_DIR/neovim/bin/nvim"
NVIM_BIN=nvim
NVIM_EXPLICIT=0
INSTALL_DEPS=1
available="git rsync curl rg fd cc make unzip tar gzip sha256sum"
nvim_ok=1
platform=apt
has_command() { [[ " $available " = *" $1 "* ]]; }
neovim_works() {
    if [ "$1" = "$MANAGED_NVIM" ] || [[ "$1" = *'/bin/nvim' ]]; then
        [ -x "$1" ]
    else
        [ "$nvim_ok" = 1 ]
    fi
}
dependency_platform() { printf '%s\\n' "$platform"; }
'''

    def run_shell(self, body, success=True, prelude=None):
        result = subprocess.run(['bash', '-c', (self.prelude if prelude is None else prelude) + body],
                                env=self.env, text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_complete_environment_does_not_call_package_manager(self):
        self.run_shell('install_packages() { exit 99; }; ensure_dependencies')

    def test_platform_package_names(self):
        for manager, expected in [
            ('apt', 'build-essential'), ('brew', 'cc'), ('pacman', 'gcc'),
            ('dnf', 'gcc'), ('yum', 'gcc'), ('zypper', 'gcc'), ('apk', 'build-base'),
        ]:
            with self.subTest(manager=manager):
                # macOS compiler availability is tested separately below.
                available = 'cc' if manager == 'brew' else ''
                result = self.run_shell(f'''
platform={manager}
available="{available}"
install_packages() {{ printf 'PACKAGES %s\\n' "$*"; available="{CORE}"; }}
ensure_dependencies
''')
                packages = result.stdout.split('PACKAGES ')[1].splitlines()[0].split()
                self.assertEqual(packages[0], manager)
                self.assertIn('ripgrep', packages)
                self.assertIn('fd-find' if manager in ('apt', 'dnf', 'yum') else 'fd', packages)
                if manager != 'brew':
                    self.assertIn(expected, packages)
                    self.assertIn('ca-certificates', packages)

    def test_debian_old_or_missing_neovim_uses_official_binary(self):
        result = self.run_shell('''
nvim_ok=0
install_packages() { exit 99; }
install_neovim_binary() { printf 'OFFICIAL\\n'; mkdir -p "$(dirname "$MANAGED_NVIM")"; touch "$MANAGED_NVIM"; chmod +x "$MANAGED_NVIM"; }
ensure_dependencies
printf 'SELECTED %s\\n' "$NVIM_BIN"
''')
        self.assertIn('OFFICIAL', result.stdout)
        self.assertIn(str(self.base / 'tools/neovim/bin/nvim'), result.stdout)

    def test_other_platforms_install_repository_neovim_and_verify(self):
        for manager in ('brew', 'pacman', 'dnf', 'yum', 'zypper', 'apk'):
            with self.subTest(manager=manager):
                result = self.run_shell(f'''
platform={manager}
nvim_ok=0
install_packages() {{ printf '%s\\n' "$*"; nvim_ok=1; }}
install_neovim_binary() {{ exit 99; }}
ensure_dependencies
''')
                self.assertIn(f'{manager} neovim', result.stdout)
        result = self.run_shell('''
platform=apk
nvim_ok=0
install_packages() { :; }
ensure_dependencies
''', success=False)
        self.assertIn('repository version may be too old', result.stderr)

    def test_no_deps_and_explicit_nvim_never_install(self):
        for settings in ('INSTALL_DEPS=0; nvim_ok=0', 'NVIM_EXPLICIT=1; nvim_ok=0'):
            result = self.run_shell(settings + '\navailable="$available nvim"\ninstall_packages() { exit 99; }; ensure_dependencies', success=False)
            self.assertIn('Neovim >= 0.11.2', result.stderr)

    def test_unknown_platform_fails_only_when_dependencies_missing(self):
        self.run_shell('platform=unknown; ensure_dependencies')
        result = self.run_shell('platform=unknown; available=""; ensure_dependencies', success=False)
        self.assertIn('no automatic installer', result.stderr)

    def test_fdfind_link_preserves_existing_files(self):
        for existing in (False, True):
            with self.subTest(existing=existing):
                bin_dir = self.base / 'bin'
                bin_dir.mkdir(exist_ok=True)
                link = bin_dir / 'fd'
                if link.is_symlink() or link.exists():
                    link.unlink()
                if existing:
                    link.write_text('user file')
                self.run_shell('''
available="git rsync curl rg fdfind cc make unzip tar gzip sha256sum"
fdfind() { :; }
install_packages() { exit 99; }
ensure_dependencies
''')
                if existing:
                    self.assertEqual(link.read_text(), 'user file')
                else:
                    self.assertTrue(link.is_symlink())

    def test_real_manager_commands_are_noninteractive(self):
        expected = {
            'apt': ['apt-get update', 'env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git'],
            'pacman': ['pacman -Syu --needed --noconfirm git'],
            'dnf': ['dnf install -y git'], 'yum': ['yum install -y git'],
            'zypper': ['zypper --non-interactive install git'], 'apk': ['apk add --no-cache git'],
            'brew': ['brew install git'],
        }
        for manager, commands in expected.items():
            with self.subTest(manager=manager):
                result = self.run_shell(f'''
set -euo pipefail
. "$DEP_SCRIPT"
run_as_root() {{ printf 'CMD %s\\n' "$*"; }}
has_command() {{ return 0; }}
id() {{ printf '1000\\n'; }}
brew() {{ printf 'CMD brew %s\\n' "$*"; }}
install_packages {manager} git
''', prelude='')
                self.assertEqual([s[4:] for s in result.stdout.splitlines() if s.startswith('CMD ')], commands)

    def test_privilege_selection(self):
        for uid, sudo, expected in [(0, False, 'direct'), (1000, True, 'sudo -- probe'), (1000, False, None)]:
            with self.subTest(uid=uid, sudo=sudo):
                result = self.run_shell(f'''
id() {{ printf '{uid}\\n'; }}
has_command() {{ {'return 0' if sudo else 'return 1'}; }}
probe() {{ printf 'direct\\n'; }}
sudo() {{ printf 'sudo %s\\n' "$*"; }}
run_as_root probe
''', success=expected is not None)
                if expected:
                    self.assertEqual(result.stdout.strip(), expected)
                else:
                    self.assertIn('requires root or sudo', result.stderr)

    def test_macos_missing_homebrew_and_compiler(self):
        result = self.run_shell('''
fail() { printf '%s\\n' "$*" >&2; exit 1; }
has_command() { return 1; }
install_packages brew git
''', success=False)
        self.assertIn('https://brew.sh', result.stderr)
        result = self.run_shell('''
platform=brew
available="git rsync curl rg fd make unzip tar gzip sha256sum"
xcode-select() { printf 'XCODE %s\\n' "$*"; }
ensure_dependencies
''', success=False)
        self.assertIn('XCODE --install', result.stdout)
        self.assertIn('Finish installing Xcode', result.stderr)

    def test_linux_download_architecture_integrity_and_failure(self):
        # Use a local archive; curl/sha256sum mocks never touch the network.
        for arch, asset, digest in [
            ('x86_64', 'nvim-linux-x86_64', 'b2f91117be5b5ea39edd7297156dc2a4a8df4add6c95a90809a8df19e7ab6f52'),
            ('aarch64', 'nvim-linux-arm64', 'ea4f9a31b11cc1477ff014aebb7b207684e7280f94ffa97abdab6cacd9b98519'),
        ]:
            payload = self.base / asset / 'bin/nvim'
            payload.parent.mkdir(parents=True)
            payload.write_text('#!/bin/sh\nexit 0\n')
            payload.chmod(0o755)
            archive = self.base / f'{arch}.tar.gz'
            with tarfile.open(archive, 'w:gz') as tar:
                tar.add(payload.parent.parent, arcname=asset)
            for mode in ('ok', 'checksum', 'download', 'incompatible'):
                with self.subTest(arch=arch, mode=mode):
                    result = self.run_shell(f'''
uname() {{ printf '{arch}\\n'; }}
curl() {{ printf 'URL %s\\n' "$*"; {'return 22' if mode == 'download' else f'cp "$TEST_BASE/{arch}.tar.gz" "${{@: -1}}"'}; }}
sha256sum() {{ printf '%s  archive\\n' {'bad' if mode == 'checksum' else digest}; }}
{'neovim_works() { return 1; }' if mode == 'incompatible' else ''}
install_neovim_binary
''', success=mode == 'ok')
                    self.assertIn(f'v0.11.5/{asset}.tar.gz', result.stdout)
                    if mode == 'ok':
                        self.assertTrue((self.base / 'tools/neovim/bin/nvim').is_file())
                    else:
                        self.assertIn({'checksum': 'checksum mismatch', 'download': 'download failed',
                                       'incompatible': 'cannot run here'}[mode], result.stderr)
                    self.assertFalse(list((self.base / 'tools').glob('.neovim-download.*')))
        result = self.run_shell('uname() { echo riscv64; }; install_neovim_binary', success=False)
        self.assertIn('x86_64/arm64', result.stderr)

    def test_platform_detection(self):
        # Keep the actual detector and substitute only system information.
        for os_name, distro, like, expected in [
            ('Darwin', '', '', 'brew'), ('FreeBSD', '', '', 'unknown'),
            ('Linux', 'ubuntu', 'debian', 'apt'), ('Linux', 'debian', '', 'apt'),
            ('Linux', 'arch', '', 'pacman'), ('Linux', 'manjaro', 'arch', 'pacman'),
            ('Linux', 'fedora', '', 'dnf'), ('Linux', 'rocky', 'rhel centos fedora', 'dnf'),
            ('Linux', 'opensuse-tumbleweed', 'opensuse suse', 'zypper'),
            ('Linux', 'alpine', '', 'apk'), ('Linux', 'other', '', 'unknown'),
        ]:
            with self.subTest(os_name=os_name, distro=distro):
                # Rewrite only the os-release input path, never the host file.
                release = self.base / 'os-release'
                release.write_text(f'ID={distro}\nID_LIKE="{like}"\n')
                script = (ROOT / 'scripts/dependencies.sh').read_text().replace('/etc/os-release', str(release))
                # Paths in this fixture have spaces: quote the substituted path.
                script = script.replace(str(release), '"' + str(release) + '"')
                result = self.run_shell(script + f'\nuname() {{ echo {os_name}; }}\nhas_command() {{ return 0; }}\ndependency_platform', prelude='')
                self.assertEqual(result.stdout.strip(), expected)


if __name__ == '__main__':
    unittest.main()
