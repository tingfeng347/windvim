"""Offline integration with real lazy.nvim code and disposable Git repositories.

Set WINDVIM_TEST_LAZY to a lazy.nvim checkout, or reuse an installed plugin cache.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DATA = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
LAZY = next((p for p in [Path(os.environ.get('WINDVIM_TEST_LAZY', '/nonexistent')),
                         *(DATA / name / 'lazy/lazy.nvim' for name in ('windvim', 'lazyvim', 'nvim'))]
             if (p / 'lua/lazy/manage/lock.lua').is_file()), None)


@unittest.skipUnless(LAZY and shutil.which('nvim') and shutil.which('git'),
                     'requires Neovim, Git and a lazy.nvim checkout (WINDVIM_TEST_LAZY)')
class LazyLockTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='windvim-lazy-lock-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.origin = self.base / 'origin'
        shutil.copytree(LAZY / 'lua', self.origin / 'lua')
        (self.origin / 'doc').mkdir()
        (self.origin / 'doc/lazy.nvim.txt').write_text('*lazy.nvim* Test fixture\n')
        self.git('init', '-q', '-b', 'main', self.origin)
        self.git('-C', self.origin, 'add', 'lua', 'doc')
        self.git('-C', self.origin, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                 'commit', '-qm', 'lazy.nvim fixture')
        self.git('-C', self.origin, 'tag', 'stable')
        config = self.base / 'config'
        config.mkdir()
        (config / 'windvim').symlink_to(ROOT, target_is_directory=True)
        self.lazy = self.base / 'data/windvim/lazy/lazy.nvim'
        self.lock = self.base / 'lazy-lock.json'
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        # Rewrite only the bootstrap remote URL; use real Git for every operation.
        wrapper = self.bin / 'git'
        wrapper.write_text('#!' + os.sys.executable + '\nimport os, sys\n'
                           'args = [os.environ["TEST_ORIGIN"] if a == '
                           '"https://github.com/folke/lazy.nvim.git" else a for a in sys.argv[1:]]\n'
                           'os.execv(os.environ["TEST_GIT"], ["git", *args])\n')
        wrapper.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.base), NVIM_APPNAME='windvim',
                        XDG_CONFIG_HOME=str(config), XDG_DATA_HOME=str(self.base / 'data'),
                        XDG_STATE_HOME=str(self.base / 'state'), XDG_CACHE_HOME=str(self.base / 'cache'),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        TEST_ORIGIN=str(self.origin), TEST_GIT=shutil.which('git'),
                        TEST_SOURCE=str(ROOT), TEST_LOCK=str(self.lock))
        self.probe_path = self.base / 'probe.lua'
        self.probe_path.write_text('''
vim.opt.rtp:prepend(vim.env.TEST_SOURCE)
local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
assert(require('windvim.bootstrap').ensure(path))
vim.opt.rtp:prepend(path)
vim.o.loadplugins = true
local lazy = require('lazy')
local setup = lazy.setup
lazy.setup = function(opts)
  -- Keep WindVim's lazy.nvim spec, while isolating unrelated plugin downloads.
  opts.spec = vim.tbl_filter(function(spec) return spec[1] == 'folke/lazy.nvim' end, opts.spec)
  opts.lockfile = vim.env.TEST_LOCK
  opts.install.missing = false
  opts.checker.enabled = false
  opts.change_detection = { enabled = false }
  opts.pkg = { enabled = false }
  opts.rocks = { enabled = false }
  opts.local_spec = false
  setup(opts)
end
dofile(vim.env.TEST_SOURCE .. '/lua/config/lazy.lua')
-- The exact upstream callback that crashed after first plugin installation.
require('lazy.manage.lock').update()
local config = require('lazy.core.config')
local plugin = config.plugins['lazy.nvim']
assert(require('lazy.manage.git').get_branch(plugin) == 'main')
-- Existing tag-only clones must also recover missing branch refs on :Lazy update.
plugin.url = vim.env.TEST_ORIGIN
require('lazy.manage').update({ plugins = { plugin }, wait = true, show = false })
assert(require('lazy.manage.git').get_commit(plugin.dir, 'main', true), 'update did not fetch main')
print('PASS: actual lazy.nvim lock update')
''')

    def git(self, *args):
        return subprocess.check_output(['git', *map(str, args)], text=True, stderr=subprocess.STDOUT)

    def probe(self):
        result = subprocess.run([os.environ.get('NVIM_BIN', 'nvim'), '--headless', '-u', 'NONE',
                                 '-i', 'NONE', '-l', str(self.probe_path)], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        lock = json.loads(self.lock.read_text())
        self.assertEqual(lock['lazy.nvim']['branch'], 'main')
        self.assertEqual(lock['lazy.nvim']['commit'], self.git('-C', self.origin, 'rev-parse', 'HEAD').strip())

    def test_existing_single_tag_clone_can_update_lock_without_redownload(self):
        self.lazy.parent.mkdir(parents=True)
        self.git('clone', '--single-branch', '--branch=stable', self.origin, self.lazy)
        # Exactly the repository state created by the broken bootstrap.
        self.assertFalse((self.lazy / '.git/refs/remotes/origin/HEAD').exists())
        self.probe()
        self.assertEqual(self.git('-C', self.lazy, 'config', '--get', 'remote.origin.url').strip(),
                         str(self.origin))

    def test_new_bootstrap_preserves_default_remote_branch_and_updates_lock(self):
        self.probe()
        self.assertEqual(self.git('-C', self.lazy, 'symbolic-ref', 'refs/remotes/origin/HEAD').strip(),
                         'refs/remotes/origin/main')


if __name__ == '__main__':
    unittest.main()
