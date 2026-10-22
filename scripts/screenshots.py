"""Capture WindVim itself in a temporary installation and a disposable project clone.

uv run --with pynvim --with pillow python scripts/screenshots.py
WINDVIM_DEMO_DATA can point to a compatible, already installed plugin cache.
"""
from pathlib import Path
import os
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
data_home = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
cache = Path(os.environ.get('WINDVIM_DEMO_DATA', data_home / 'windvim')).expanduser().resolve()
if not (cache / 'lazy/lazy.nvim').is_dir():
    raise SystemExit('Start WindVim to install plugins first, or set WINDVIM_DEMO_DATA to an existing data directory')
with tempfile.TemporaryDirectory(prefix='windvim-screenshots-') as tmp:
    base = Path(tmp)
    project = base / 'project/windvim'
    subprocess.run(['git', 'clone', '--quiet', '--shared', str(root), str(project)], check=True)
    env = dict(os.environ, XDG_CONFIG_HOME=str(base / 'config'), XDG_DATA_HOME=str(base / 'data'),
               XDG_STATE_HOME=str(base / 'state'), XDG_CACHE_HOME=str(base / 'cache'),
               UV_CACHE_DIR=str(Path(os.environ.get('UV_CACHE_DIR', Path.home() / '.cache/uv'))),
               NVIM_APPNAME='windvim', I18N_TEST_CWD=str(project),
               I18N_TEST_SCRIPT=str(root / 'scripts/screenshots.lua'),
               I18N_SCREENSHOT_DIR=str(root / 'docs/screenshots'), I18N_UI_WIDTH='144', I18N_UI_HEIGHT='38')
    env.pop('NO_COLOR', None)
    subprocess.run(['bash', str(root / 'install.sh'), '--no-launcher'], env=env, check=True)
    data = base / 'data/windvim'
    data.mkdir(parents=True)
    for name in ['lazy', 'site', 'mason']:
        if (cache / name).is_dir():
            (data / name).symlink_to(cache / name, target_is_directory=True)
    started = time.time()
    subprocess.run([os.sys.executable, str(root / 'local-plugins/lazyvim-i18n.nvim/tests/run.py')],
                   env=env, check=True, timeout=120)
    for name in ['dashboard-zh.png', 'dashboard-en.png', 'dashboard-animation.gif', 'project-code.png',
                 'which-key-zh.png', 'picker-zh.png', 'lazy-zh.png']:
        path = root / 'docs/screenshots' / name
        if not path.is_file() or path.stat().st_mtime < started:
            raise RuntimeError(f'Screenshot was not refreshed: {name}')
