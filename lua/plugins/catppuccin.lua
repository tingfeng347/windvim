-- Make LazyVim use the same colorscheme and code highlighting as nvim.
-- Reference: ~/.config/nvim/lua/modules/configs/ui/catppuccin.lua
return {
  -- Use catppuccin (mocha), the same theme nvim uses.
  -- Load the plugin's lua module directly instead of `:colorscheme catppuccin`,
  -- because a system-installed catppuccin.vim on the nvim runtimepath would
  -- otherwise hijack the colorscheme command (so the plugin's styles and
  -- highlight_overrides below would never apply).
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        require("catppuccin").load()
      end,
    },
  },
  -- Mirror nvim's catppuccin setup for code highlighting only.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = function(_, opts)
      opts.background = { light = "latte", dark = "mocha" }
      opts.flavour = "mocha"
      opts.styles = {
        comments = { "italic" },
        functions = { "bold" },
        keywords = { "italic" },
        operators = { "bold" },
        conditionals = { "bold" },
        loops = { "bold" },
        booleans = { "bold", "italic" },
        numbers = {},
        types = {},
        strings = {},
        variables = {},
        properties = {},
      }
      opts.integrations = vim.tbl_deep_extend("force", opts.integrations or {}, {
        semantic_tokens = true,
      })
      opts.highlight_overrides = {
        all = function(cp)
          -- nvim runs an older catppuccin whose treesitter/syntax mappings
          -- differ from this newer version. Pin every code group that differs
          -- to nvim's exact colors and attributes.
          return {
            Identifier = { fg = cp.text },
            Keyword = { fg = cp.maroon, style = { "italic" } },
            Delimiter = { fg = cp.teal },

            ["@keyword.return"] = { fg = cp.pink, style = {} },
            ["@error.c"] = { fg = cp.none, style = {} },
            ["@error.cpp"] = { fg = cp.none, style = {} },

            ["@keyword"] = { fg = cp.maroon, style = { "italic" } },
            ["@keyword.function"] = { fg = cp.maroon, style = { "italic" } },
            ["@keyword.type"] = { fg = cp.maroon, style = { "italic" } },
            ["@keyword.operator"] = { fg = cp.sky, style = { "bold" } },
            ["@keyword.import"] = { fg = cp.teal, style = { "italic" } },
            ["@keyword.exception"] = { fg = cp.peach, style = { "italic" } },

            ["@function.macro"] = { fg = cp.peach, style = {} },

            ["@label"] = { fg = cp.rosewater },
            ["@namespace"] = { fg = cp.rosewater, style = {} },
            ["@module"] = { fg = cp.rosewater, style = {} },
            ["@parameter"] = { fg = cp.rosewater },
            ["@property"] = { fg = cp.rosewater },
            ["@field"] = { fg = cp.rosewater },
            ["@variable.member"] = { fg = cp.rosewater },
            ["@variable.parameter"] = { fg = cp.rosewater },

            ["@punctuation"] = { fg = cp.teal },
            ["@punctuation.delimiter"] = { fg = cp.teal },

            ["@type.builtin"] = { fg = cp.yellow },
            ["@constant.builtin"] = { fg = cp.lavender, style = {} },
            ["@constant.macro"] = { fg = cp.peach },
            ["@constructor"] = { fg = cp.sapphire },

            ["@tag"] = { fg = cp.mauve },
            ["@tag.delimiter"] = { fg = cp.sky },
            ["@tag.attribute"] = { fg = cp.teal, style = { "italic" } },

            ["@include"] = { fg = cp.teal, style = { "italic" } },
            ["@exception"] = { fg = cp.peach, style = { "italic" } },
            ["@storageclass"] = { fg = cp.maroon, style = { "italic" } },
            ["@storageclass.lifetime"] = { fg = cp.maroon, style = { "italic" } },

            ["@string.regex"] = { fg = cp.peach, style = {} },
          }
        end,
      }
      return opts
    end,
  },
}
