"""Run against the user's installed plugins with an actual Neovim UI.

uv run --with pynvim --with pillow python local-plugins/lazyvim-i18n.nvim/tests/run.py
Screenshots in .tests/i18n are reconstructed from Neovim's real UI grid events.
"""
from pathlib import Path
import os
import tempfile

import pynvim
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[3]
os.chdir(root)
output = root / ".tests/i18n"
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype(
    "/usr/share/fonts/TTF/JetBrains-Maple-Mono-NF-XX-XX/JetBrainsMapleMono-Regular.ttf", 18
)
grids, colors = {}, {0: {}}
default_fg, default_bg = "#cdd6f4", "#1e1e2e"


def color(value, fallback):
    return f"#{value:06x}" if value is not None and value >= 0 else fallback


def notification(method, args):
    global default_fg, default_bg
    if method == "redraw":
        for event in args:
            for data in event[1:]:
                if event[0] == "grid_resize":
                    grid, width, height = data
                    grids[grid] = [[(" ", 0)] * width for _ in range(height)]
                elif event[0] == "default_colors_set":
                    default_fg = color(data[0], default_fg)
                    default_bg = color(data[1], default_bg)
                elif event[0] == "hl_attr_define":
                    colors[data[0]] = data[1]
                elif event[0] == "grid_clear" and data[0] in grids:
                    rows = grids[data[0]]
                    grids[data[0]] = [[(" ", 0)] * len(rows[0]) for _ in rows]
                elif event[0] == "grid_scroll":
                    grid, top, bottom, left, right, row_delta, col_delta = data
                    before = [row[:] for row in grids[grid]]
                    for row in range(top, bottom):
                        for col in range(left, right):
                            source_row, source_col = row + row_delta, col + col_delta
                            grids[grid][row][col] = (
                                before[source_row][source_col]
                                if top <= source_row < bottom and left <= source_col < right
                                else (" ", 0)
                            )
                elif event[0] == "grid_line":
                    grid, row, col, cells = data[:4]
                    hl = 0
                    for cell in cells:
                        hl = cell[1] if len(cell) > 1 else hl
                        for _ in range(cell[2] if len(cell) > 2 else 1):
                            grids[grid][row][col] = (cell[0], hl)
                            col += 1
    elif method == "i18n_snapshot":
        rows = grids[1]
        image = Image.new("RGB", (len(rows[0]) * 11, len(rows) * 25), default_bg)
        draw = ImageDraw.Draw(image)
        for y, row in enumerate(rows):
            for x, (char, hl) in enumerate(row):
                attrs = colors.get(hl, {})
                fg = color(attrs.get("foreground"), default_fg)
                bg = color(attrs.get("background"), default_bg)
                if attrs.get("reverse"):
                    fg, bg = bg, fg
                draw.rectangle((x * 11, y * 25, (x + 1) * 11, (y + 1) * 25), fill=bg)
            for x, (char, hl) in enumerate(row):
                attrs = colors.get(hl, {})
                fg = color(attrs.get("background" if attrs.get("reverse") else "foreground"), default_fg)
                draw.text((x * 11, y * 25), char, font=font, fill=fg)
        image.save(output / f"{args[0]}.png")


with tempfile.TemporaryDirectory(prefix="lazyvim-i18n-test-") as tmp:
    result = Path(tmp) / "result"
    os.environ["NVIM_APPNAME"] = "lazyvim"
    os.environ["LAZYVIM_LANGUAGE"] = "zh_CN"
    os.environ["I18N_TEST_RESULT"] = str(result)
    # Disable only the automatic checker in this test process, before VeryLazy.
    # Otherwise its background git tasks can race the idle-screen assertions.
    disable_checker = (
        'lua vim.api.nvim_create_autocmd("User", {pattern="LazyDone", once=true, '
        'callback=function() require("lazy.core.config").options.checker.enabled=false end})'
    )
    nvim = pynvim.attach(
        "child", argv=["nvim", "--embed", "-i", "NONE", "--cmd", disable_checker]
    )
    nvim.ui_attach(140, 45, rgb=True, ext_linegrid=True)
    nvim.vars["i18n_test_channel"] = nvim.channel_id
    nvim.exec_lua('dofile("local-plugins/lazyvim-i18n.nvim/tests/integration.lua")')
    try:
        nvim.run_loop(None, notification)
    except EOFError:
        pass
    report = result.read_text() if result.exists() else "FAIL: Neovim exited without a result"
    print(report)
    raise SystemExit(0 if report.startswith("PASS") else 1)
