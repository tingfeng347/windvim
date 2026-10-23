"""Exercise first startup through a real terminal with isolated plugin data."""
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import tempfile
import termios
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('nvim'), 'requires nvim')
class StartupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='windvim-startup-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        config = self.base / 'config'
        config.mkdir()
        (config / 'windvim').symlink_to(ROOT, target_is_directory=True)
        bin_dir = self.base / 'bin'
        bin_dir.mkdir()
        self.git = bin_dir / 'git'
        self.env = dict(os.environ, HOME=str(self.base), NVIM_APPNAME='windvim',
                        XDG_CONFIG_HOME=str(config), XDG_DATA_HOME=str(self.base / 'data'),
                        XDG_STATE_HOME=str(self.base / 'state'), XDG_CACHE_HOME=str(self.base / 'cache'),
                        PATH=str(bin_dir) + os.pathsep + os.environ['PATH'], TERM='xterm-256color')
        self.nvim = os.environ.get('NVIM_BIN', 'nvim')
        self.lazy = self.base / 'data/windvim/lazy/lazy.nvim'

    def fake_git(self, body):
        self.git.write_text('#!/bin/sh\ntouch "$HOME/clone-started"\n' + body + '\n')
        self.git.chmod(0o755)

    def headless(self, success=True):
        result = subprocess.run([self.nvim, '--headless', '-i', 'NONE', '+qa'], env=self.env,
                                text=True, capture_output=True, timeout=8)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        return result

    def successful_git(self):
        # A tiny lazy.nvim fixture stops before real plugin downloads; bootstrap is real.
        self.fake_git('''
for target do :; done
mkdir -p "$target/lua/lazy"
printf '%s\n' 'return { setup = function() end }' > "$target/lua/lazy/init.lua"
''')

    def test_slow_first_download_shows_progress_instead_of_blank_terminal(self):
        self.fake_git('exec sleep 30')
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 100, 0, 0))
        child = subprocess.Popen([self.nvim, '-i', 'NONE'], env=self.env,
                                 stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
        os.close(slave)
        output = bytearray()
        try:
            until = time.monotonic() + 2
            while time.monotonic() < until:
                if select.select([master], [], [], 0.05)[0]:
                    output.extend(os.read(master, 65536))
            self.assertTrue((self.base / 'clone-started').exists(), 'bootstrap never reached Git')
            # Newer TUIs may position individual cells with escape sequences.
            text = re.sub(rb'\x1b\[[0-?]*[ -/]*[@-~]', b'', output)
            self.assertIn(b'WindVim: first launch', text,
                          'First download left a blank terminal without any startup progress')
        finally:
            os.killpg(child.pid, signal.SIGTERM)
            child.wait(timeout=5)
            os.close(master)

    def test_timeout_exits_and_logs_instead_of_waiting_forever(self):
        self.fake_git('exec sleep 30')
        self.env['WINDVIM_BOOTSTRAP_TIMEOUT'] = '0.1'
        result = self.headless(success=False)
        self.assertIn('timed out', result.stderr)
        log = self.base / 'state/windvim/bootstrap.log'
        self.assertIn('GitHub download timed out', log.read_text())
        self.assertFalse(self.lazy.exists())
        self.assertFalse(list(self.lazy.parent.glob('lazy.nvim.install-*')))

    def test_failed_download_cleans_partial_files_and_next_start_can_retry(self):
        self.fake_git('''
for target do :; done
mkdir -p "$target"
echo partial > "$target/unfinished"
echo 'fatal: simulated network failure' >&2
exit 128
''')
        self.headless(success=False)
        self.assertIn('simulated network failure', (self.base / 'state/windvim/bootstrap.log').read_text())
        self.assertFalse(self.lazy.exists())
        self.assertFalse(list(self.lazy.parent.glob('lazy.nvim.install-*')))
        self.successful_git()
        self.headless()
        self.assertTrue((self.lazy / 'lua/lazy/init.lua').is_file())

    def test_incomplete_existing_directory_is_backed_up_and_repaired(self):
        self.lazy.mkdir(parents=True)
        (self.lazy / 'unfinished').write_text('partial download')
        self.successful_git()
        self.headless()
        self.assertTrue((self.lazy / 'lua/lazy/init.lua').is_file())
        backups = list(self.lazy.parent.glob('lazy.nvim.incomplete-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / 'unfinished').read_text(), 'partial download')

    def test_existing_plugin_manager_does_not_download_again(self):
        (self.lazy / 'lua/lazy').mkdir(parents=True)
        (self.lazy / 'lua/lazy/init.lua').write_text('return { setup = function() end }')
        self.fake_git('exit 99')
        result = self.headless()
        self.assertFalse((self.base / 'clone-started').exists())
        self.assertNotIn('first launch', result.stderr)


if __name__ == '__main__':
    unittest.main()
