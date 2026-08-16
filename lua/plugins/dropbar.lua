-- Breadcrumbs in the Winbar: README.md > H1 > H2 > current Markdown heading.
-- This mirrors the Dropbar setup in the separate nvim configuration.
-- Start hidden; toggle it in normal mode with <leader>uB (Space u B).
vim.g.dropbar_enabled = false

return {
  {
    "Bekaboo/dropbar.nvim",
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      {
        "<leader>uB",
        function()
          vim.g.dropbar_enabled = vim.g.dropbar_enabled == false
          local dropbar_winbar = "%{%v:lua.dropbar()%}"
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.wo[win].winbar == dropbar_winbar then
              vim.wo[win].winbar = ""
            elseif vim.g.dropbar_enabled then
              require("dropbar.utils").bar.attach(vim.api.nvim_win_get_buf(win), win)
            end
          end
        end,
        desc = "Toggle Breadcrumbs",
      },
    },
    opts = function()
      local sources = require("dropbar.sources")
      local default_bar_enable = require("dropbar.configs").opts.bar.enable

      -- Keep the breadcrumb compact: only show the current file name, not its
      -- full parent path, before the Markdown heading hierarchy.
      sources.symbols = {
        get_symbols = function(buf, win, cursor)
          local symbols = sources.path.get_symbols(buf, win, cursor)
          return symbols[#symbols] and { symbols[#symbols] } or {}
        end,
      }

      return {
        bar = {
          -- Keep Dropbar disabled after a toggle, including when entering a
          -- new buffer. The original eligibility rules still apply otherwise.
          enable = function(buf, win, info)
            return vim.g.dropbar_enabled ~= false and default_bar_enable(buf, win, info)
          end,
          hover = false,
          truncate = true,
          pick = { pivots = "etovxqpdygfblzhckisuran" },
          sources = function(buf)
            if vim.bo[buf].ft == "markdown" then
              return { sources.symbols, sources.markdown }
            end
            if vim.bo[buf].buftype == "terminal" then
              return { sources.terminal }
            end
            return {
              sources.symbols,
              require("dropbar.utils").source.fallback({ sources.lsp, sources.treesitter }),
            }
          end,
        },
      }
    end,
  },
}
