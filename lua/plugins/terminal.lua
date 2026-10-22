-- A tmux-popup style shell.
--
-- snacks picks the terminal window from whether a command was given
-- (snacks/terminal.lua):
--     position = cmd and "float" or "bottom"
-- so LazyVim's <C-/> / <leader>ft / <leader>fT (no command) always open a
-- bottom split. The panel below passes an explicit `win`, which is resolved
-- last and therefore wins. snacks keys terminals by (cmd, cwd, env, count), so
-- `count` is used to keep this float separate from the bottom terminal.
--
-- The right-hand Codex sidebar is not here anymore; it is served by
-- folke/sidekick.nvim (see plugins/sidekick.lua).
return {
  {
    "folke/snacks.nvim",
    keys = {
      -- A tmux-popup style terminal: a centered floating shell.
      {
        "<leader>tp",
        function()
          Snacks.terminal.focus(nil, {
            cwd = LazyVim.root(),
            -- separate id, otherwise the float would reuse the bottom terminal
            count = 2,
            win = {
              position = "float",
              -- snacks only draws a border when this is set explicitly
              -- (`vim.o.winborder` is not picked up on its own), and the
              -- terminal float has no border by default. Keep it consistent
              -- with the other floating windows (Snacks picker, LazyGit).
              border = "rounded",
              width = 0.85,
              height = 0.85,
            },
          })
        end,
        desc = "Terminal (float, centered)",
      },
    },
  },
}
