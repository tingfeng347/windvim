return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      -- LazyVim's Markdown extra enables markdownlint-cli2 by default.
      -- Keep Markdown LSP/navigation, but do not show style-rule diagnostics
      -- such as MD041 in the editor.
      opts.linters_by_ft.markdown = {}
      opts.linters_by_ft["markdown.mdx"] = {}
    end,
  },
}
