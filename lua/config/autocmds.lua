-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- LazyVim enables spell checking for Markdown by default. Keep Markdown's
-- wrapping behavior, but disable the red spell-underlines when a Markdown
-- buffer is opened.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "markdown.mdx" },
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- The native right-click PopUp menu inserts two `<Nop>` separator entries.
-- They render as blank rows, which is distracting with a transparent menu.
for _, separator in ipairs({ "PopUp.-1-", "PopUp.-2-" }) do
  pcall(vim.cmd, "aunmenu " .. separator)
end
