"""Native context menus must cover the editor beneath them."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = os.environ.get("NVIM_BIN", "nvim")


@unittest.skipUnless(shutil.which(NVIM), "Neovim is required")
class PopupTest(unittest.TestCase):
    def test_native_popup_stays_opaque_after_theme_and_window_events(self):
        script = r'''
vim.o.pumblend = 10 -- LazyVim's default
dofile("lua/plugins/transparent.lua")
local function check()
  local menu = vim.api.nvim_get_hl(0, { name = "Pmenu", link = false })
  assert(menu.bg, "Pmenu has no background: editor text bleeds through the context menu")
  assert(vim.o.pumblend == 0, "pumblend blends editor text into the context menu")
  for _, name in ipairs({"Pmenu", "PmenuSel", "PmenuKind", "PmenuKindSel",
    "PmenuExtra", "PmenuExtraSel", "PmenuSbar", "PmenuThumb", "PmenuBorder"}) do
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    assert(hl.bg and (hl.blend or 0) == 0, name .. " must have an opaque surface")
  end
  assert(not vim.api.nvim_get_hl(0, {name="Normal", link=false}).bg,
    "editor background must remain transparent")
  assert(not vim.api.nvim_get_hl(0, {name="BlinkCmpMenu", link=false}).bg,
    "completion appearance must remain unchanged")
end
check()
for _, theme in ipairs({"habamax", "default"}) do
  vim.cmd.colorscheme(theme)
  check()
end
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
vim.api.nvim_exec_autocmds("WinNew", {})
vim.wait(100, function() return false end)
check()
print("PASS: context menu opaque after theme/window events; editor and Blink remain transparent")
'''
        with tempfile.TemporaryDirectory(prefix="windvim-popup-") as tmp:
            path = Path(tmp) / "check.lua"
            path.write_text(script)
            result = subprocess.run(
                [NVIM, "--clean", "--headless", "-i", "NONE", "-l", str(path)],
                cwd=ROOT, text=True, capture_output=True, timeout=15,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
