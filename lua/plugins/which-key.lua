-- Labels/icons for the <leader> menu.
--
-- which-key shows a prefix that has mappings but was never declared as a group
-- as "+1 keymap". Declaring `group` replaces that placeholder with a proper name,
-- and `icon` works like the built-in labels: which-key.icons assigns icons by
-- pattern-matching an entry's description, and anything the built-in rules do
-- not cover (e.g. "Keywordprg") gets no icon unless it is set here.
--
-- These are merged into LazyVim's own spec through `opts_extend = { "spec" }`,
-- so the built-in groups keep their icons.
return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        -- Bottom terminals and the centered floating terminal.
        { "<leader>t", group = "terminal", icon = { icon = " ", color = "cyan" } },
        -- <cmd>norm! K<cr> -- run the "keyword program" on the word under cursor
        { "<leader>K", icon = { icon = "󰋗 ", color = "blue" } },
      },
    },
  },
}
