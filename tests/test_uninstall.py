"""Exercise uninstall and purge only in disposable XDG directories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class UninstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='windvim-uninstall-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name) / 'paths with spaces'
        self.homes = {name: self.base / name for name in ('config', 'data', 'cache', 'state')}
        self.bin = self.base / 'bin'
        self.env = dict(os.environ, WINDVIM_BIN_DIR=str(self.bin))
        self.env.update({f'XDG_{name.upper()}_HOME': str(path) for name, path in self.homes.items()})
        for home in self.homes.values():
            for app in ('windvim', 'nvim', 'lazyvim'):
                (home / app).mkdir(parents=True)
                (home / app / 'marker').write_text(app)
        self.bin.mkdir()
        self.launcher = self.bin / 'windvim'
        self.launcher.write_text('#!/usr/bin/env sh\nexport NVIM_APPNAME=\'windvim\'\nexec "${NVIM_BIN:-nvim}" "$@"\n')

    def uninstall(self, *args, success=True, env=None):
        result = subprocess.run(['bash', str(ROOT / 'uninstall.sh'), *args],
                                env=env or self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def assert_other_apps(self):
        for home in self.homes.values():
            for app in ('nvim', 'lazyvim'):
                self.assertEqual((home / app / 'marker').read_text(), app)

    def test_default_backs_up_config_and_launcher_retains_data_and_is_repeatable(self):
        original = self.launcher.read_bytes()
        self.uninstall()
        self.assertFalse((self.homes['config'] / 'windvim').exists())
        backup, = self.homes['config'].glob('windvim.backup.*')
        self.assertEqual((backup / 'marker').read_text(), 'windvim')
        launcher_backup, = self.bin.glob('windvim.backup.*')
        self.assertEqual(launcher_backup.read_bytes(), original)
        self.assertFalse(self.launcher.exists())
        for name in ('data', 'cache', 'state'):
            self.assertTrue((self.homes[name] / 'windvim/marker').is_file())
        self.uninstall()
        self.assertEqual(len(list(self.homes['config'].glob('windvim.backup.*'))), 1)
        self.assert_other_apps()

    def test_purge_cleans_all_xdg_data_and_keeps_backups(self):
        self.uninstall('--purge')
        for home in self.homes.values():
            self.assertFalse((home / 'windvim').exists())
        backup, = self.homes['config'].glob('windvim.backup.*')
        self.assertTrue((backup / 'marker').is_file())
        self.assert_other_apps()

    def test_custom_appname_keeps_default_install_and_launcher(self):
        for home in self.homes.values():
            (home / 'my-windvim').mkdir()
        self.uninstall('--appname', 'my-windvim', '--purge')
        for home in self.homes.values():
            self.assertFalse((home / 'my-windvim').exists())
            self.assertTrue((home / 'windvim/marker').is_file())
        self.assertTrue(self.launcher.is_file())

    def test_no_launcher_and_unrelated_launchers_are_preserved(self):
        self.uninstall('--no-launcher')
        self.assertTrue(self.launcher.is_file())
        self.launcher.write_text('user launcher')
        self.uninstall()
        self.assertEqual(self.launcher.read_text(), 'user launcher')

    def test_symlinks_do_not_remove_shared_files(self):
        shared = self.base / 'shared'
        shared.mkdir()
        (shared / 'marker').write_text('shared data')
        for home in self.homes.values():
            shutil.rmtree(home / 'windvim')
            (home / 'windvim').symlink_to(shared, target_is_directory=True)
        self.launcher.unlink()
        self.launcher.symlink_to(shared / 'marker')
        self.uninstall('--purge')
        self.assertEqual((shared / 'marker').read_text(), 'shared data')
        backup, = self.homes['config'].glob('windvim.backup.*')
        self.assertTrue(backup.is_symlink())
        self.assertTrue(self.launcher.is_symlink())
        for name in ('data', 'cache', 'state'):
            self.assertFalse((self.homes[name] / 'windvim').is_symlink())

    def test_invalid_options_and_paths_fail_before_mutation(self):
        for args in [('--appname', '../nvim'), ('--appname', ''), ('--appname',), ('--unknown',)]:
            self.uninstall(*args, success=False)
        for var in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'WINDVIM_BIN_DIR'):
            self.uninstall('--purge', env=dict(self.env, **{var: 'relative'}), success=False)
        self.assertTrue((self.homes['config'] / 'windvim/marker').is_file())
        self.assertTrue(self.launcher.is_file())

    def test_source_checkout_is_protected_even_via_parent_symlink(self):
        alias = self.base / 'checkout-parent'
        alias.symlink_to(ROOT.parent, target_is_directory=True)
        result = self.uninstall('--purge', success=False,
                                env=dict(self.env, XDG_DATA_HOME=str(alias)))
        self.assertIn('Source is inside the uninstall target', result.stderr)
        self.assertTrue((self.homes['config'] / 'windvim/marker').is_file())
        self.assertTrue((ROOT / 'uninstall.sh').is_file())

    @unittest.skipUnless(shutil.which('nvim') and shutil.which('rsync'), 'requires nvim and rsync')
    def test_removes_launcher_from_actual_installer(self):
        result = subprocess.run(['bash', str(ROOT / 'install.sh'), '--force', '--no-path'], env=self.env,
                                text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.uninstall()
        self.assertFalse(self.launcher.exists())
        self.assertFalse((self.homes['config'] / 'windvim').exists())
        self.assert_other_apps()


if __name__ == '__main__':
    unittest.main()
