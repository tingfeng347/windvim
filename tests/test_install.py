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
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.config), WINDVIM_BIN_DIR=str(self.bin))
        self.env['NVIM_BIN'] = shutil.which('nvim')
        (self.config / 'nvim').mkdir(parents=True)
        (self.config / 'nvim/user.lua').write_text('existing nvim config')
        (self.config / 'lazyvim').mkdir()
        (self.config / 'lazyvim/user.lua').write_text('existing lazyvim config')

    def install(self, *args, success=True, env=None):
        result = subprocess.run(['bash', str(ROOT / 'install.sh'), *args], env=env or self.env,
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


if __name__ == '__main__':
    unittest.main()
