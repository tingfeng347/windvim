-- Set enabled = false (or remove this file) to unplug the translation layer.
return {
  {
    dir = vim.fn.stdpath("config") .. "/local-plugins/lazyvim-i18n.nvim",
    name = "lazyvim-i18n.nvim",
    enabled = true,
    lazy = false,
    priority = 10000,
    opts = {
      locale = "zh_CN",
      persist = true,
      keymap = "<leader>uH",
    },
    config = function(_, opts)
      require("lazyvim_i18n").setup(opts)
    end,
  },
}
