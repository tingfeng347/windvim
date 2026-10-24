local logo = require("windvim.logo")

local function startup()
  local stats = require("lazy.stats").stats()
  local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
  return {
    padding = { 0, 2 },
    align = "center",
    text = {
      { "⚡ WindVim 已加载 ", hl = "footer" },
      { stats.loaded .. "/" .. stats.count, hl = "special" },
      { " 个插件，用时 ", hl = "footer" },
      { ms .. "ms", hl = "special" },
    },
  }
end

return {
  {
    "folke/snacks.nvim",
    config = function(_, opts)
      logo.setup()
      require("snacks").setup(opts)

      local D = require("snacks.dashboard").Dashboard

      -- snacks.nvim (checked at 882c996) reaches into the dashboard window
      -- from its WinResized handler and from D:update without checking that the
      -- window is still valid and still shows the dashboard buffer. Resizing
      -- after the dashboard has been replaced (e.g. by opening a file) then
      -- throws "Invalid window id". Fix it here instead of editing the plugin
      -- source, so `:Lazy update` keeps working.
      local function dashboard_active(self)
        return self.win
          and vim.api.nvim_win_is_valid(self.win)
          and vim.api.nvim_win_get_buf(self.win) == self.buf
      end

      local orig_size = D.size
      function D.size(self)
        if not dashboard_active(self) then
          return self._size or { width = 0, height = 0 }
        end
        return orig_size(self)
      end

      -- Window ids the dashboard has rendered into. Used by the cursor guard
      -- below to tell "a window that used to show the dashboard" apart from
      -- "a window id that has nothing to do with us".
      local dash_wins = {} ---@type table<integer, boolean>

      -- Cursor guard, installed once per session.
      --
      -- snacks restores the dashboard cursor from two places - a buffer-local
      -- CursorMoved handler and D:update (both in update_cursor) - without
      -- checking that the window it remembers still exists, nor that the
      -- remembered position still fits the buffer. The handler keeps firing
      -- from its autocmd after the dashboard window is gone (closing a split
      -- that was taken away from the dashboard does that, e.g. `/exit` in the
      -- Codex panel), which is the "Lua callback: ... nvim_win_set_cursor:
      -- Invalid window id" popup.
      --
      -- A patch around a single render cannot catch that call, so the guard
      -- stays installed for the session:
      --   * a stale dashboard window is a no-op instead of an error
      --     (only ids the dashboard actually used are swallowed, so real
      --     "invalid window" bugs elsewhere still surface)
      --   * positions for a dashboard buffer are clamped, which also fixes
      --     the "Invalid cursor line: out of range" seen on VimResized
      if not vim.g.windvim_dashboard_cursor_guard then
        vim.g.windvim_dashboard_cursor_guard = true
        local set_cursor = vim.api.nvim_win_set_cursor
        ---@param win integer
        ---@param pos [integer, integer]
        vim.api.nvim_win_set_cursor = function(win, pos)
          if not vim.api.nvim_win_is_valid(win) then
            if dash_wins[win] then
              return
            end
            return set_cursor(win, pos)
          end
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.b[buf].snacks_main then
            local row = math.min(math.max(pos[1], 1), vim.api.nvim_buf_line_count(buf))
            local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
            pos = { row, math.min(math.max(pos[2], 0), #line) }
          end
          return set_cursor(win, pos)
        end
      end

      -- Adaptive width: shrink the dashboard content so it fits narrow
      -- windows without clipping. Every render recomputes the width from the
      -- current editor width.
      local orig_update = D.update
      function D.update(self)
        if not dashboard_active(self) then
          return
        end
        dash_wins[self.win] = true
        self.opts.width = math.max(8, math.min(46, vim.o.columns - 2))
        return orig_update(self)
      end
    end,
    opts = {
      dashboard = {
        width = 46,
        -- Keep a single centered column like nvim's alpha dashboard. Snacks
        -- normally splits the keys into extra panes on wide windows, which
        -- shoves the logo into the left pane (looking like a left shift).
        -- A very large pane gap means only one pane can ever fit.
        pane_gap = 1000,
        sections = {
          -- Spacer so the logo does not touch the top edge.
          { padding = { 0, 1 } },
          -- Custom header section so the logo sits tight against the menu
          -- (the stock header section adds two blank rows of its own).
          logo.section,
          -- Keep a little extra space above and below the menu. Since the
          -- dashboard is vertically centred, the logo and footer spread
          -- gently toward the top and bottom without loosening each row.
          { section = "keys", gap = 0, padding = { 2, 2 } },
          startup,
        },
        preset = {
          header = "W I N D V I M",
          keys = {
            { icon = " ", key = "f", desc = "查找文件", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "新建文件", action = ":ene | startinsert" },
            { icon = "󰙨 ", key = "p", desc = "项目", action = ":lua Snacks.picker.projects()" },
            { icon = " ", key = "g", desc = "查找文本", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "最近文件", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            {
              icon = " ",
              key = "c",
              desc = "配置",
              action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
            },
            { icon = " ", key = "x", desc = "扩展管理", action = ":LazyExtras" },
            { icon = "󰒲 ", key = "l", desc = "插件管理", action = ":Lazy" },
            { icon = " ", key = "q", desc = "退出", action = ":qa" },
          },
        },
      },
    },
  },
}
