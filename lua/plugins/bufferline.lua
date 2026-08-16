return {
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      -- Match the separate nvim configuration. The background stays
      -- transparent; focus is differentiated by text colour and weight.
      opts.options.always_show_bufferline = true
      opts.options.close_command = function(n) Snacks.bufdelete(n) end
      opts.options.right_mouse_command = function(n) Snacks.bufdelete(n) end
      opts.options.tab_size = 20
      opts.options.separator_style = "thin"
      -- Keep Bufferline's stock tab layout, without a visible active marker.
      opts.options.indicator = { style = "none" }
      opts.options.show_buffer_icons = true
      opts.options.show_tab_indicators = true
      opts.options.show_buffer_close_icons = true
      opts.options.diagnostics = "nvim_lsp"
      opts.options.diagnostics_indicator = function(count)
        return "(" .. count .. ")"
      end
      opts.options.numbers = nil
      opts.options.max_name_length = 20
      opts.options.max_prefix_length = 13

      -- catppuccin's bufferline theme is provided as a function (lazily
      -- resolved by bufferline), not a plain table. Resolve it here and layer
      -- the overrides below on top so the custom colors always win.
      local base_highlights = opts.highlights
      opts.highlights = function()
        local base = {}
        if type(base_highlights) == "function" then
          base = vim.tbl_deep_extend("force", base, base_highlights())
        elseif base_highlights then
          base = vim.tbl_deep_extend("force", base, base_highlights)
        end
        return vim.tbl_deep_extend("force", base, {
          fill = { bg = "NONE" },
          background = { fg = "#9399B3", bg = "NONE" },
          buffer = { fg = "#9399B3", bg = "NONE" },
          buffer_visible = { fg = "#45475B", bg = "NONE" },
          buffer_selected = { fg = "#CDD6F5", bg = "NONE", bold = true, italic = true },
          separator = { fg = "#45475B", bg = "NONE" },
          separator_visible = { fg = "#45475B", bg = "NONE" },
          separator_selected = { fg = "#45475B", bg = "NONE" },
          -- Bufferline renders this cell above the Explorer split once a
          -- buffer tab exists. Its default opaque background creates a dark
          -- cap at the top of the sidebar separator.
          offset_separator = { fg = "#45475B", bg = "NONE" },
          close_button = { fg = "#45475B", bg = "NONE" },
          close_button_visible = { fg = "#45475B", bg = "NONE" },
          close_button_selected = { fg = "#F38BA9", bg = "NONE" },
          modified = { fg = "#FAB388", bg = "NONE" },
          modified_visible = { fg = "#FAB388", bg = "NONE" },
          modified_selected = { fg = "#FAB388", bg = "NONE" },
          -- When focus leaves the buffer, Bufferline renders this empty cell
          -- before the tab. Keep its background transparent.
          indicator_visible = { bg = "NONE" },
          indicator_selected = { fg = "#FAB388", bg = "NONE", bold = true, italic = true },
        })
      end
    end,
  },
}
