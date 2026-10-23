"""Exercise the installer in temporary XDG paths; never touch the user's config."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('nvim') and shutil.which('rsync'), 'requires nvim and rsync')
class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='windvim-install-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name) / 'paths with spaces'
        self.config = self.base / 'config'
        self.bin = self.base / 'bin'
        self.home = self.base / 'home'
        self.home.mkdir(parents=True)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.config), WINDVIM_BIN_DIR=str(self.bin),
                        XDG_DATA_HOME=str(self.base / 'data'), HOME=str(self.home), SHELL='/bin/bash')
        self.env.pop('ZDOTDIR', None)
        self.env['NVIM_BIN'] = shutil.which('nvim')
        (self.config / 'nvim').mkdir(parents=True)
        (self.config / 'nvim/user.lua').write_text('existing nvim config')
        (self.config / 'lazyvim').mkdir()
        (self.config / 'lazyvim/user.lua').write_text('existing lazyvim config')

    def install(self, *args, success=True, env=None):
        result = subprocess.run(['bash', str(ROOT / 'install.sh'), '--no-deps', *args], env=env or self.env,
                                text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def assert_existing_configs(self):
        self.assertEqual((self.config / 'nvim/user.lua').read_text(), 'existing nvim config')
        self.assertEqual((self.config / 'lazyvim/user.lua').read_text(), 'existing lazyvim config')

    def test_install_and_launcher_isolation_and_argument_forwarding(self):
        self.install()
        target = self.config / 'windvim'
        self.assertEqual((target / 'init.lua').read_bytes(), (ROOT / 'init.lua').read_bytes())
        self.assertTrue((target / 'local-plugins/lazyvim-i18n.nvim/lua/lazyvim_i18n/init.lua').is_file())
        self.assertFalse((target / '.git').exists())
        self.assertFalse((target / 'docs').exists())
        self.assertFalse((target / 'install.sh').exists())
        probe = self.base / 'nvim probe'
        probe.write_text('#!/usr/bin/env python3\nimport os, json, sys\nprint(json.dumps([os.environ["NVIM_APPNAME"], sys.argv[1:]]))\n')
        probe.chmod(0o755)
        output = subprocess.check_output([str(self.bin / 'windvim'), 'file name.lua', '+set nu'],
                                         env=dict(self.env, NVIM_BIN=str(probe)), text=True)
        self.assertEqual(json.loads(output), ['windvim', ['file name.lua', '+set nu']])
        self.assert_existing_configs()

    def test_existing_config_refused_and_force_preserves_backup(self):
        target = self.config / 'windvim'
        target.mkdir()
        (target / 'mine.lua').write_text('local changes')
        self.install(success=False)
        self.assertEqual((target / 'mine.lua').read_text(), 'local changes')
        self.assertFalse((self.bin / 'windvim').exists())
        self.install('--force')
        backups = list(self.config.glob('windvim.backup.*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / 'mine.lua').read_text(), 'local changes')
        self.assertFalse((target / 'mine.lua').exists())
        self.assertTrue((target / 'init.lua').is_file())
        self.assert_existing_configs()

    def test_existing_launcher_refused_before_install_then_backed_up(self):
        self.bin.mkdir(parents=True)
        (self.bin / 'windvim').write_text('my old launcher')
        self.install(success=False)
        self.assertFalse((self.config / 'windvim').exists())
        self.install('--force')
        backup, = self.bin.glob('windvim.backup.*')
        self.assertEqual(backup.read_text(), 'my old launcher')

    def test_custom_appname_without_launcher(self):
        self.install('--appname', 'windvim-test', '--no-launcher')
        self.assertTrue((self.config / 'windvim-test/init.lua').is_file())
        self.assertFalse((self.config / 'windvim').exists())
        self.assertFalse(self.bin.exists())
        self.assertFalse((self.home / '.bashrc').exists())
        self.assert_existing_configs()

    def test_invalid_names_rejected_without_writing_config(self):
        for name in ['../nvim', '/tmp/nvim', '', '.']:
            self.install('--appname', name, success=False)
        self.assertFalse((self.config / 'windvim').exists())
        self.assert_existing_configs()

    def test_in_place_source_is_not_moved(self):
        env = dict(self.env, XDG_CONFIG_HOME=str(ROOT.parent))
        result = self.install('--force', '--no-launcher', env=env, success=False)
        self.assertIn('Source is inside the install target', result.stderr)
        self.assertTrue((ROOT / 'install.sh').is_file())

    def test_neovim_version_failure_preserves_existing_files(self):
        self.base.mkdir(parents=True, exist_ok=True)
        old_nvim = self.base / 'old-nvim'
        old_nvim.write_text('#!/bin/sh\nexit 1\n')
        old_nvim.chmod(0o755)
        self.install(env=dict(self.env, NVIM_BIN=str(old_nvim)), success=False)
        self.assertFalse((self.config / 'windvim').exists())
        self.assert_existing_configs()

    def test_managed_neovim_is_used_by_installer_and_launcher(self):
        managed = self.base / 'data/windvim-tools/neovim/bin/nvim'
        managed.parent.mkdir(parents=True)
        managed.write_text('#!/bin/sh\nif [ "$1" != --clean ]; then printf "%s\\n" "$NVIM_APPNAME" "$@"; fi\n')
        managed.chmod(0o755)
        env = dict(self.env)
        env.pop('NVIM_BIN')
        self.install(env=env)
        output = subprocess.check_output([str(self.bin / 'windvim'), 'file name.lua'], env=env, text=True)
        self.assertEqual(output.splitlines(), ['windvim', 'file name.lua'])

    def test_relative_data_path_is_rejected(self):
        self.install(env=dict(self.env, XDG_DATA_HOME='relative'), success=False)
        self.assertFalse((self.config / 'windvim').exists())

    def test_bash_path_persists_without_duplicates_and_preserves_shell_config(self):
        rc = self.home / '.bashrc'
        rc.write_text('# user settings\nexport WINDVIM_TEST_SETTING=kept\n')
        self.install()
        backup, = self.home.glob('.bashrc.backup.*')
        self.assertEqual(backup.read_text(), '# user settings\nexport WINDVIM_TEST_SETTING=kept\n')
        original = rc.read_text()
        self.install('--force')
        self.assertEqual(rc.read_text(), original)
        self.assertEqual(len(list(self.home.glob('.bashrc.backup.*'))), 1)
        for file in (rc, self.home / '.profile'):
            output = subprocess.check_output(
                ['bash', '--noprofile', '--norc', '-c', '. "$1"; . "$1"; command -v windvim', '_', str(file)],
                env=self.env, text=True)
            self.assertEqual(output.strip(), str(self.bin / 'windvim'))

    def test_no_path_leaves_shell_configs_untouched(self):
        self.install('--no-path')
        self.assertTrue((self.bin / 'windvim').is_file())
        self.assertFalse((self.home / '.bashrc').exists())
        self.assertFalse((self.home / '.profile').exists())

    def test_bash_existing_login_profile_is_used(self):
        profile = self.home / '.bash_profile'
        profile.write_text('# custom login\n')
        self.install()
        self.assertIn('WindVim launcher PATH', profile.read_text())
        self.assertFalse((self.home / '.profile').exists())

    @unittest.skipUnless(shutil.which('zsh'), 'requires zsh')
    def test_zsh_honors_zdotdir_and_resolves_launcher(self):
        zdotdir = self.base / 'zsh settings'
        env = dict(self.env, SHELL=shutil.which('zsh'), ZDOTDIR=str(zdotdir))
        self.install(env=env)
        self.assertTrue((zdotdir / '.zprofile').is_file())
        output = subprocess.check_output(['zsh', '-i', '-c', 'command -v windvim'], env=env, text=True)
        self.assertEqual(output.strip(), str(self.bin / 'windvim'))

    @unittest.skipUnless(shutil.which('fish'), 'requires fish')
    def test_fish_new_shell_resolves_launcher(self):
        env = dict(self.env, SHELL=shutil.which('fish'))
        self.install(env=env)
        rc = self.config / 'fish/conf.d/windvim-path.fish'
        self.assertTrue(rc.is_file())
        output = subprocess.check_output(['fish', '-c', 'command -v windvim'], env=env, text=True)
        self.assertEqual(output.strip(), str(self.bin / 'windvim'))

    def test_shell_metacharacters_in_bin_directory_are_literal(self):
        bin_dir = self.base / "bin ' quote $dollar `backtick` \\ slash"
        for shell in ('bash', 'zsh', 'fish'):
            executable = shutil.which(shell)
            if not executable:
                continue
            with self.subTest(shell=shell):
                env = dict(self.env, SHELL=executable, WINDVIM_BIN_DIR=str(bin_dir))
                self.install('--force', env=env)
                if shell == 'bash':
                    cmd = [executable, '--noprofile', '--norc', '-c', '. "$HOME/.bashrc"; command -v windvim']
                elif shell == 'zsh':
                    cmd = [executable, '-i', '-c', 'command -v windvim']
                else:
                    cmd = [executable, '-c', 'command -v windvim']
                output = subprocess.check_output(cmd, env=env, text=True)
                self.assertEqual(output.strip(), str(bin_dir / 'windvim'))


if __name__ == '__main__':
    unittest.main()
