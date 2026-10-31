-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Keep terminal actions together under <leader>t.
vim.keymap.del("n", "<leader>ft")
vim.keymap.del("n", "<leader>fT")
vim.keymap.set("n", "<leader>tt", function()
  Snacks.terminal(nil, { cwd = LazyVim.root() })
end, { desc = "Bottom Terminal (Root Dir)" })
vim.keymap.set("n", "<leader>tT", function()
  Snacks.terminal()
end, { desc = "Bottom Terminal (cwd)" })
