-- folke/sidekick.nvim, enabled through the LazyVim extra `ai.sidekick`.
--
-- The CLI panel is the VS Code style sidebar: `layout = "right"` and a third
-- of the editor wide. LazyVim's extra provides the keymaps - <leader>aa
-- toggle, <leader>as select, <leader>ad detach, <leader>at/af/av send
-- context, <leader>ap prompt, <c-.> focus - and we use them as they are.
--
-- Panels are packed into columns: up to MAX_PER_COLUMN CLIs are stacked on top
-- of each other inside the sidebar column, and only when every column is full
-- does the next panel open another one next to it. Out of the box every CLI
-- opens its own column, splitting whatever window happens to be current (so a
-- second CLI could even split the first panel).

local MAX_PER_COLUMN = 3

--- Windows that currently show a sidekick CLI panel.
---@return integer[]
local function panels()
  local ret = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "sidekick_terminal" then
      ret[#ret + 1] = win
    end
  end
  return ret
end

--- Panels grouped by the screen column they sit in, each sorted top to bottom.
---@return table<integer, integer[]> screen x -> window ids
local function panel_columns()
  local cols = {}
  for _, win in ipairs(panels()) do
    local x = vim.fn.win_screenpos(win)[2]
    cols[x] = cols[x] or {}
    table.insert(cols[x], win)
  end
  for _, col in pairs(cols) do
    table.sort(col, function(a, b)
      return vim.fn.win_screenpos(a)[1] < vim.fn.win_screenpos(b)[1]
    end)
  end
  return cols
end

--- Even out the heights inside every column.
---
--- nvim only shrinks the window that is actually split, so stacking a third
--- panel onto two half height ones would end up 9/25/16 instead of 17/16/17.
--- The panels carry `winfixheight` (sidekick sets it for vertical layouts) and
--- would refuse to shrink, so switch it off while balancing.
local function balance_columns()
  for _, col in pairs(panel_columns()) do
    local total = 0
    for _, win in ipairs(col) do
      total = total + vim.api.nvim_win_get_height(win)
    end
    local per = math.floor(total / #col)
    for _, win in ipairs(col) do
      vim.wo[win].winfixheight = false
    end
    for i, win in ipairs(col) do
      -- the last panel takes the remainder, so the heights always add up
      local height = i == #col and total - per * (#col - 1) or per
      pcall(vim.api.nvim_win_set_height, win, math.max(height, 1))
    end
    for _, win in ipairs(col) do
      vim.wo[win].winfixheight = #col > 1
    end
  end
end

--- Decide where this panel goes, by adjusting `terminal.opts`, which sidekick
--- hands to `nvim_open_win` as is.
---@param terminal sidekick.cli.Terminal
local function place_panel(terminal)
  if terminal.opts.layout == "float" then
    return
  end

  local cols = panel_columns()

  -- the column that is already the fullest but still has room
  local target ---@type integer[]?
  for _, col in pairs(cols) do
    if #col < MAX_PER_COLUMN and (not target or #col > #target) then
      target = col
    end
  end

  if target then
    -- stack below the bottom-most panel of that column. width = 0 means
    -- "auto": nvim keeps the column width.
    terminal.opts.layout = "bottom"
    terminal.opts.split = {
      win = target[#target],
      width = 0,
      height = 1 / (#target + 1),
    }
    return
  end

  if next(cols) then
    -- Every column is full: open another one next to the sidebar.
    --
    -- Split the tallest window (normally the editor, or a column that still
    -- holds a single panel) so that the new column spans the full height.
    -- Splitting a panel that is part of a stack would only insert a column
    -- next to that one panel and leave the windows below it spanning both.
    -- Floats (notifications, pickers) are skipped, they can not be split.
    local candidates = vim.tbl_filter(function(win)
      return vim.api.nvim_win_get_config(win).relative == ""
    end, vim.api.nvim_list_wins())
    local function is_panel(win)
      return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "sidekick_terminal"
    end
    table.sort(candidates, function(a, b)
      local ha, hb = vim.api.nvim_win_get_height(a), vim.api.nvim_win_get_height(b)
      if ha ~= hb then
        return ha > hb
      end
      return not is_panel(a) and is_panel(b)
    end)

    -- keep the width of the existing sidebar, but never squeeze the editor
    -- below 20 columns
    local sidebar = 0
    for _, win in ipairs(panels()) do
      sidebar = math.max(sidebar, vim.api.nvim_win_get_width(win))
    end
    local width = math.max(20, math.min(sidebar, vim.o.columns - sidebar * #cols - 20))

    terminal.opts.layout = "right"
    terminal.opts.split = {
      win = candidates[1],
      width = width,
      height = 0,
    }
    return
  end
  -- No panel open yet: reset `opts` to the plugin's own configuration, giving
  -- a top level column at the right edge.
  --
  -- This has to be written out instead of left alone: `terminal.opts` is reused
  -- for the whole life of a CLI, so it still holds whatever the *previous*
  -- placement put there. Re-showing a single panel went through the "stack
  -- below itself" case before, and its now dead window id (the panel's own
  -- window, closed when the panel was hidden) was then handed to
  -- `nvim_open_win`, which raised "Invalid window id".
  local Config = require("sidekick.config")
  terminal.opts.layout = Config.cli.win.layout
  terminal.opts.split = vim.deepcopy(Config.cli.win.split or {})
end

return {
  {
    "folke/sidekick.nvim",
    init = function()
      -- sidekick opens a window for a panel on every `open_win`, also when a
      -- hidden panel is shown again. The window we split the last time is long
      -- gone by then, so the placement has to be recomputed on every open.
      -- (The official `cli.win.config` hook only runs once, on creation.)
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          local Terminal = require("sidekick.cli.terminal")
          local orig_open_win = Terminal.open_win
          function Terminal:open_win()
            -- `orig_open_win` returns early when the panel is already open or
            -- has no buffer. Placing it anyway would only rewrite `self.opts`
            -- (see the reset at the end of `place_panel`), so only place when a
            -- window is really about to be created.
            if not self:is_open() and self.buf then
              place_panel(self)
            end
            return orig_open_win(self)
          end
        end,
      })

      -- even out the heights whenever a panel is opened, shown again or hidden
      vim.api.nvim_create_autocmd({ "BufWinEnter", "WinClosed" }, {
        callback = function(ev)
          if ev.event == "BufWinEnter" and vim.bo[ev.buf].filetype ~= "sidekick_terminal" then
            return
          end
          vim.schedule(balance_columns)
        end,
      })
    end,
    opts = {
      cli = {
        win = {
          -- "right" is already the default; spelled out to make the intent
          -- (VS Code style sidebar) obvious.
          layout = "right",
          split = {
            -- width is either an absolute number of columns or, when <= 1, a
            -- fraction of `vim.o.columns` that is resolved when the window is
            -- opened (sidekick/cli/terminal.lua: open_win). The default 80
            -- columns ate ~40% of a 200 column terminal; a third is enough
            -- for a CLI TUI.
            width = 1 / 3,
          },
        },
      },
    },
  },
}
