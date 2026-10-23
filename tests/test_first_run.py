"""First-run UI and background installs with real Neovim/lazy.nvim, offline Git."""
import json
import os
from pathlib import Path
import pty
import select
import shutil
import struct
import subprocess
import tempfile
import termios
import fcntl
import time
import unittest

from test_lazy_lock import LAZY

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(LAZY and shutil.which('nvim'), 'requires nvim and a lazy.nvim checkout')
class FirstRunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='windvim-first-run-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.config = self.base / 'config/windvim'
        shutil.copytree(ROOT / 'lua/windvim', self.config / 'lua/windvim')
        shutil.copy(ROOT / 'init.lua', self.config / 'init.lua')
        self.origin = self.base / 'lazy-origin'
        shutil.copytree(LAZY / 'lua', self.origin / 'lua')
        (self.origin / 'doc').mkdir()
        (self.origin / 'doc/lazy.nvim.txt').write_text('*lazy.nvim* Test fixture\n')
        self.repo(self.origin)
        subprocess.run(['git', '-C', str(self.origin), 'tag', 'stable'], check=True)
        leaf = self.base / 'leaf'
        leaf.mkdir()
        (leaf / 'README').write_text('late-discovered plugin with a build step')
        self.repo(leaf)
        host = self.base / 'host'
        (host / 'lua/fixture_specs').mkdir(parents=True)
        (host / 'lua/fixture_specs/init.lua').write_text('''
return {{ url = vim.env.TEST_LEAF, name = 'leaf', lazy = true,
  build = function()
    local flag = vim.env.HOME .. '/build-first-attempt'
    if vim.env.TEST_FAIL_BUILD == '1' and vim.fn.filereadable(flag) == 0 then
      vim.fn.writefile({'failed once'}, flag)
      error('transient build failure')
    end
    vim.fn.writefile({'built'}, vim.env.HOME .. '/build-complete')
  end }}
''')
        self.repo(host)
        (self.config / 'lua/config').mkdir()
        (self.config / 'lua/config/lazy.lua').write_text('''
local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
assert(require('windvim.bootstrap').ensure(path))
vim.opt.rtp:prepend(path)
require('lazy').setup({
  spec = { { 'folke/lazy.nvim', branch = 'main' },
    { url = vim.env.TEST_HOST, name = 'host', import = 'fixture_specs', lazy = true } },
  checker = {enabled=false}, change_detection = {enabled=false},
  pkg = {enabled=false}, rocks = {enabled=false}, local_spec = false,
})
vim.g.fixture_loaded = vim.fn.getpid()
''')
        bin_dir = self.base / 'bin'
        bin_dir.mkdir()
        wrapper = bin_dir / 'git'
        wrapper.write_text('#!' + os.sys.executable + '''
import os, sys, time
args = sys.argv[1:]
if 'https://github.com/folke/lazy.nvim.git' in args:
    time.sleep(0.6)
    if os.environ.get('TEST_FAIL_GIT') == '1' and not os.path.exists(os.environ['HOME'] + '/allow-git'):
        print('fatal: simulated offline server', file=sys.stderr)
        sys.exit(128)
    args = [os.environ['TEST_LAZY_ORIGIN'] if a == 'https://github.com/folke/lazy.nvim.git' else a for a in args]
os.execv(os.environ['TEST_GIT'], ['git', *args])
''')
        wrapper.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.base), NVIM_APPNAME='windvim', TERM='xterm-256color',
                        XDG_CONFIG_HOME=str(self.base / 'config'), XDG_DATA_HOME=str(self.base / 'data'),
                        XDG_STATE_HOME=str(self.base / 'state'), XDG_CACHE_HOME=str(self.base / 'cache'),
                        PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                        TEST_GIT=shutil.which('git'), TEST_LAZY_ORIGIN=str(self.origin),
                        TEST_HOST=str(host), TEST_LEAF=str(leaf))
        self.env.pop('NO_COLOR', None)
        self.env['WINDVIM_ANIMATION'] = '1'
        self.marker = self.base / 'data/windvim/first-run.json'
        self.probe = self.base / 'probe.lua'

    def repo(self, path):
        for args in [('init', '-q', '-b', 'main'), ('add', '.'),
                     ('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')]:
            subprocess.run(['git', '-C', str(path), *args], check=True, capture_output=True)

    def launch(self, probe, extra=(), width=100, height=38):
        self.probe.write_text(probe)
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', height, width, 0, 0))
        proc = subprocess.Popen([os.environ.get('NVIM_BIN', 'nvim'), '-i', 'NONE', *extra,
                                 '-c', 'luafile ' + str(self.probe)], env=self.env,
                                stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = bytearray()
        try:
            until = time.monotonic() + 18
            while time.monotonic() < until and proc.poll() is None:
                if select.select([master], [], [], .05)[0]:
                    try:
                        output.extend(os.read(master, 65536))
                    except OSError:
                        break
            if proc.poll() is None:
                self.fail('Neovim timed out: ' + output.decode(errors='replace')[-6000:] + '\nLOG:\n' + (self.base / 'state/windvim/install.log').read_text())
            proc.wait(timeout=2)
            self.assertEqual(proc.returncode, 0, output.decode(errors='replace')[-4000:])
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            os.close(master)

    def test_animated_home_then_late_plugins_build_and_load_in_same_process(self):
        self.env['TEST_FAIL_BUILD'] = '1'
        file = self.base / 'hello.txt'
        file.write_text('preserved file argument\n')
        self.launch('''
local initial, animated, colored, saw_home = nil, false, false, false
local timer = vim.uv.new_timer()
timer:start(150, 100, vim.schedule_wrap(function()
  if vim.bo.filetype == 'windvim-install' then
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local text = table.concat(lines, '\\n')
    saw_home = saw_home or text:find('正在准备 WindVim', 1, true) ~= nil
    local art = {}
    for _, line in ipairs(lines) do
      if line:find('▓', 1, true) or line:find('█', 1, true) then art[#art + 1] = line end
    end
    art = table.concat(art, '\\n')
    animated = animated or (initial ~= nil and initial ~= art and #art > 0)
    initial = art
    local ns = vim.api.nvim_get_namespaces().windvim_install
    colored = colored or #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 20
  end
  if vim.g.windvim_installing == false then
    assert(saw_home and animated and colored, 'missing colored animated first-run homepage')
    assert(vim.g.fixture_loaded == vim.fn.getpid(), 'parent never loaded complete configuration')
    assert(vim.fn.filereadable(vim.env.HOME .. '/build-complete') == 1, 'build was not retried')
    assert(vim.fn.getline(1) == 'preserved file argument', 'file argument was lost')
    assert(require('windvim.install_state').ready(), 'installation marker not written')
    vim.cmd('qa!')
  end
end))
vim.defer_fn(function() vim.cmd('cquit 2') end, 15000)
''', extra=(str(file),))
        self.assertTrue(self.marker.is_file())
        log = (self.base / 'state/windvim/install.log').read_text()
        self.assertIn('transient build failure', log)
        self.assertIn('attempt 2', log)
        # A returning launch must go straight to the fully loaded configuration.
        self.launch("assert(vim.g.fixture_loaded == vim.fn.getpid()); assert(not vim.g.windvim_installing); vim.cmd('qa!')")

    def test_failed_download_stays_visible_then_manual_retry_in_same_window(self):
        self.env['TEST_FAIL_GIT'] = '1'
        self.env['WINDVIM_ANIMATION'] = '0'
        self.launch('''
local timer = vim.uv.new_timer()
local retried = false
timer:start(200, 100, vim.schedule_wrap(function()
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\\n')
  if not retried and text:find('安装未完成', 1, true) then
    assert(not require('windvim.install_state').ready(), 'failure was marked complete')
    local home = vim.api.nvim_get_current_buf()
    -- Invoke the actual mapping, then return from the real log window.
    local map = vim.fn.maparg('l', 'n', false, true)
    map.callback()
    assert(vim.b.windvim_log, 'log key did not open the log window')
    assert(vim.api.nvim_buf_line_count(0) > 1, 'log window was empty')
    vim.fn.maparg('q', 'n', false, true).callback()
    assert(vim.api.nvim_get_current_buf() == home, 'log did not return to homepage')
    vim.fn.writefile({'allow'}, vim.env.HOME .. '/allow-git')
    retried = true
    vim.api.nvim_input('r')
  elseif retried and vim.g.windvim_installing == false then
    assert(require('windvim.install_state').ready())
    vim.cmd('qa!')
  end
end))
vim.defer_fn(function() vim.cmd('cquit 2') end, 15000)
''', width=44, height=18)
        self.assertTrue(self.marker.is_file())

    def test_quitting_homepage_stops_the_in_progress_download(self):
        (self.base / 'bin/git').write_text('#!/bin/sh\necho $$ > "$HOME/git-pid"\nexec sleep 30\n')
        self.launch('''
local timer = vim.uv.new_timer()
timer:start(100, 100, vim.schedule_wrap(function()
  if vim.fn.filereadable(vim.env.HOME .. '/git-pid') == 1 then
    vim.api.nvim_input('q')
  end
end))
vim.defer_fn(function() vim.cmd('cquit 2') end, 3000)
''')
        pid = int((self.base / 'git-pid').read_text())
        for _ in range(40):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            time.sleep(.05)
        else:
            os.kill(pid, 9)
            self.fail('background Git download survived quitting WindVim')
        self.assertFalse(self.marker.exists())

    def test_animation_can_be_disabled_without_hiding_the_colored_homepage(self):
        self.env['WINDVIM_ANIMATION'] = '0'
        self.launch('''
vim.defer_fn(function()
  assert(vim.bo.filetype == 'windvim-install')
  local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(table.concat(before, '\\n'):find('▓', 1, true), 'logo is missing')
  vim.defer_fn(function()
    assert(vim.deep_equal(before, vim.api.nvim_buf_get_lines(0, 0, -1, false)), 'animation did not stop')
    vim.cmd('qa!')
  end, 200)
end, 200)
''')


if __name__ == '__main__':
    unittest.main()
