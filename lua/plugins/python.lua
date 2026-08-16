return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Pyright currently exits immediately in this environment.
        pyright = { enabled = false },
        -- ty is installed by Mason and provides Python definition lookup.
        ty = {},
        jedi_language_server = { enabled = false },
      },
    },
  },
}
