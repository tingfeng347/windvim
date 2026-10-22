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
os.chdir(os.environ.get("I18N_TEST_CWD", root))
output = Path(os.environ.get("I18N_SCREENSHOT_DIR", root / ".tests/i18n")).resolve()
output.mkdir(parents=True, exist_ok=True)
font_candidates = [
    os.environ.get("I18N_TEST_FONT", ""),
    "/usr/share/fonts/TTF/JetBrains-Maple-Mono-NF-XX-XX/JetBrainsMapleMono-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/System/Library/Fonts/PingFang.ttc",
]
font_path = next((path for path in font_candidates if path and Path(path).is_file()), None)
if not font_path:
    raise SystemExit("Set I18N_TEST_FONT to a font with Chinese and Nerd Font glyphs")
font = ImageFont.truetype(font_path, 18)
# Terminals use font fallback for Braille art; emulate it when available.
braille_path = os.environ.get("I18N_BRAILLE_FONT", "/usr/share/fonts/TTF/DejaVuSans.ttf")
braille_font = ImageFont.truetype(braille_path, 18) if Path(braille_path).is_file() else font
grids, colors = {}, {0: {}}
animation_frames = {}
glyph_masks = {}
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
        rows = args[1] if len(args) > 1 else grids[1]
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
                cell_font = braille_font if char and 0x2800 <= ord(char[0]) <= 0x28FF else font
                if char.strip():
                    key = (char, cell_font is braille_font)
                    if key not in glyph_masks:
                        mask = Image.new("L", (33, 25))
                        ImageDraw.Draw(mask).text((0, 0), char, font=cell_font, fill=255)
                        glyph_masks[key] = mask
                    image.paste(fg, (x * 11, y * 25, x * 11 + 33, y * 25 + 25), glyph_masks[key])
        if args[0] in {"dashboard-animation", "dashboard-animation-en"}:
            frames = animation_frames.setdefault(args[0], [])
            frames.append(image.convert("P", palette=Image.Palette.ADAPTIVE, colors=64))
            if len(frames) % 12 == 0:
                print(f"Captured {args[0]}: {len(frames)} frames", flush=True)
        else:
            image.save(output / f"{args[0]}.png")


with tempfile.TemporaryDirectory(prefix="windvim-i18n-test-") as tmp:
    result = Path(tmp) / "result"
    os.environ.setdefault("NVIM_APPNAME", "windvim")
    os.environ["LAZYVIM_LANGUAGE"] = "zh_CN"
    os.environ["I18N_TEST_RESULT"] = str(result)
    # Disable only the automatic checker in this test process, before VeryLazy.
    # Otherwise its background git tasks can race the idle-screen assertions.
    disable_checker = (
        'lua vim.api.nvim_create_autocmd("User", {pattern="LazyDone", once=true, '
        'callback=function() require("lazy.core.config").options.checker.enabled=false end})'
    )
    nvim = pynvim.attach(
        "child", argv=[os.environ.get("NVIM_BIN", "nvim"), "--embed", "-i", "NONE", "--cmd", disable_checker]
    )
    nvim.ui_attach(int(os.environ.get("I18N_UI_WIDTH", "140")),
                   int(os.environ.get("I18N_UI_HEIGHT", "45")), rgb=True, ext_linegrid=True)
    nvim.vars["i18n_test_channel"] = nvim.channel_id
    test_script = os.environ.get("I18N_TEST_SCRIPT", "local-plugins/lazyvim-i18n.nvim/tests/integration.lua")
    nvim.exec_lua("dofile(...)", test_script)
    def request(method, args):
        if method != "i18n_snapshot":
            raise RuntimeError(f"Unexpected Neovim request: {method}")
        notification(method, args)
        return True

    try:
        nvim.run_loop(request, notification)
    except EOFError:
        pass
    report = result.read_text() if result.exists() else "FAIL: Neovim exited without a result"
    for name, frames in animation_frames.items():
        frames[0].save(output / f"{name}.gif", save_all=True,
                       append_images=frames[1:], duration=120, loop=0, disposal=2)
    print(report)
    raise SystemExit(0 if report.startswith("PASS") else 1)
