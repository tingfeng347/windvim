return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.completion = opts.completion or {}
      opts.completion.menu = opts.completion.menu or {}

      local function below_cmdline()
        local pos
        if vim.g.ui_cmdline_pos ~= nil then
          pos = { vim.g.ui_cmdline_pos[1] - 1, vim.g.ui_cmdline_pos[2] }
        else
          local height = (vim.o.cmdheight == 0) and 1 or vim.o.cmdheight
          pos = { vim.o.lines - height, 0 }
        end
        pos[1] = pos[1] + 1
        return pos
      end

      opts.completion.menu.cmdline_position = below_cmdline
      opts.cmdline = opts.cmdline or {}
      opts.cmdline.completion = opts.cmdline.completion or {}
      opts.cmdline.completion.menu = opts.cmdline.completion.menu or {}
      opts.cmdline.completion.menu.cmdline_position = below_cmdline
    end,
  },
}
