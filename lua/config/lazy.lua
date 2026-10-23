local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not require("windvim.bootstrap").ensure(lazypath) then
  return
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- Also supports existing stable-tag clones that have no origin/HEAD ref.
    -- lazy.nvim's update pipeline will fetch this branch when it is missing.
    { "folke/lazy.nvim", branch = "main" },
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "catppuccin", "tokyonight", "habamax" } },
  headless = { colors = false }, -- keep background installer logs readable
  ui = {
    border = "rounded",
    backdrop = false,
  },
  checker = {
    enabled = not vim.g.windvim_install_worker, -- no update checks during initial installation
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  change_detection = { enabled = not vim.g.windvim_install_worker },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
