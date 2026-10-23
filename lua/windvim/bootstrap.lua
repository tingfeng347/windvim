local M = {}

local function installed(path)
  return vim.fn.filereadable(path .. "/lua/lazy/init.lua") == 1
end

local function show(screen, message, highlight)
  vim.api.nvim_echo({ { message, highlight or "MoreMsg" } }, true, {})
  -- Startup messages can be deferred by the TUI, so draw actual buffer text too.
  if #vim.api.nvim_list_uis() > 0 and vim.o.columns > 12 and vim.o.lines > 6 then
    local lines = vim.split(message, "\n", { plain = true })
    if not screen.buf then
      screen.buf = vim.api.nvim_create_buf(false, true)
      vim.bo[screen.buf].bufhidden = "wipe"
      vim.bo[screen.buf].swapfile = false
      screen.win = vim.api.nvim_open_win(screen.buf, false, {
        relative = "editor", row = 1, col = 2,
        width = math.max(8, vim.o.columns - 6),
        height = math.max(1, math.min(10, vim.o.lines - 5)),
        style = "minimal", border = "rounded",
      })
    end
    vim.api.nvim_buf_set_lines(screen.buf, 0, -1, false, lines)
  end
  vim.cmd("redraw")
end

local function close(screen)
  if screen.win and vim.api.nvim_win_is_valid(screen.win) then
    vim.api.nvim_win_close(screen.win, true)
  end
end

-- First startup runs before the plugin manager can display its own progress UI.
function M.ensure(path)
  if installed(path) then
    return true
  end

  local seconds = tonumber(vim.env.WINDVIM_BOOTSTRAP_TIMEOUT) or 120
  if seconds <= 0 or seconds ~= seconds or seconds == math.huge then
    seconds = 120
  end
  local staging = path .. ".install-" .. vim.fn.getpid()
  local screen = {}
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  show(screen, ("WindVim: first launch - downloading lazy.nvim from GitHub (timeout %gs)..."):format(seconds))

  local ok, result = pcall(function()
    return vim.system({
      "git",
      "-c", "http.lowSpeedLimit=1",
      "-c", "http.lowSpeedTime=30",
      "clone", "--filter=blob:none", "--single-branch", "--branch=stable",
      "https://github.com/folke/lazy.nvim.git", staging,
    }, { text = true, env = { GIT_TERMINAL_PROMPT = "0" } }):wait(math.max(1, math.floor(seconds * 1000)))
  end)

  local reason
  if not ok then
    reason = tostring(result)
  elseif not result or result.code == 124 then
    reason = ("GitHub download timed out after %gs."):format(seconds)
  elseif result.code ~= 0 then
    reason = (result.stderr or "") .. (result.stdout or "")
    if reason == "" then
      reason = "Git exited with code " .. result.code
    end
  elseif not installed(staging) then
    reason = "Git finished without a complete lazy.nvim installation."
  end

  if not reason then
    -- Another startup may have completed while this download was running.
    if installed(path) then
      vim.fn.delete(staging, "rf")
      close(screen)
      return true
    end
    local backup
    if (vim.uv or vim.loop).fs_lstat(path) then
      backup = path .. ".incomplete-" .. os.date("%Y%m%d-%H%M%S") .. "." .. vim.fn.getpid()
      if vim.fn.rename(path, backup) ~= 0 then
        reason = "Cannot back up the incomplete lazy.nvim directory: " .. path
      end
    end
    if not reason and vim.fn.rename(staging, path) ~= 0 then
      if backup then
        vim.fn.rename(backup, path)
      end
      reason = "Cannot move the downloaded lazy.nvim into: " .. path
    end
  end

  if reason then
    vim.fn.delete(staging, "rf")
    local state = vim.fn.stdpath("state")
    vim.fn.mkdir(state, "p")
    local log = state .. "/bootstrap.log"
    local message = "WindVim: startup download failed.\n"
      .. reason .. "\nCheck GitHub access, then run windvim again.\nLog: " .. log
    vim.fn.writefile(vim.split(message, "\n", { plain = true }), log)
    show(screen, message .. "\nPress any key to exit.", "ErrorMsg")
    if #vim.api.nvim_list_uis() > 0 then
      pcall(vim.fn.getchar)
    end
    close(screen)
    vim.cmd("cquit 1")
    return false
  end

  show(screen, "WindVim: lazy.nvim ready. Installing plugins; first launch may take a few minutes...")
  close(screen)
  return true
end

return M
