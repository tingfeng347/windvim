-- Capture real CLI welcome screens; no prompt is submitted to either AI.
vim.defer_fn(function()
  local terminals = {}
  local ok, err = xpcall(function()
    local function text(buf)
      if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return ""
      end
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
    local function snapshot(name)
      vim.cmd("redraw!")
      vim.wait(100)
      local screen = {}
      for row = 1, vim.o.lines do
        screen[row] = {}
        for col = 1, vim.o.columns do
          screen[row][col] = { vim.fn.screenstring(row, col), vim.fn.screenattr(row, col) }
        end
      end
      vim.rpcrequest(vim.g.i18n_test_channel, "i18n_snapshot", name, screen)
    end

    vim.cmd("Noice disable")
    Snacks.notifier.hide()
    local main = vim.api.nvim_get_current_win()
    local dashboard = vim.api.nvim_get_current_buf()
    assert(vim.bo[dashboard].filetype == "snacks_dashboard", "dashboard is not ready")
    -- Build the split layout before opening the dashboard at its final size.
    vim.cmd.enew()
    local staging = vim.api.nvim_get_current_buf()
    local explorer = Snacks.explorer({
      cwd = vim.fn.getcwd(),
      layout = { preset = "sidebar", layout = { width = 29 } },
    })
    vim.wait(500)
    vim.api.nvim_set_current_win(main)

    require("lazy").load({ plugins = { "sidekick.nvim" } })
    require("sidekick.cli.session").setup()
    local Terminal = require("sidekick.cli.terminal")
    for _, name in ipairs({ "claude", "codex" }) do
      assert(vim.fn.executable(name) == 1, name .. " is not installed")
      local terminal = Terminal.new({ tool = name, cwd = vim.fn.getcwd() })
      terminals[#terminals + 1] = terminal
      terminal:start()
      vim.wait(1500)
    end

    -- Trust only the disposable project created by screenshots.py, if asked.
    local trusted = {}
    local ready = vim.wait(45000, function()
      local all_ready = true
      for _, terminal in ipairs(terminals) do
        local content = text(terminal.buf)
        local lower = content:lower()
        local trust = lower:find("trust this", 1, true)
          or lower:find("trust the files", 1, true)
          or lower:find("yes, i trust", 1, true)
        if trust and not trusted[terminal.tool.name] then
          local keys = terminal.tool.name == "claude" and "\27[B\r" or "\r"
          vim.api.nvim_chan_send(terminal.job, keys)
          trusted[terminal.tool.name] = true
        end
        local title = terminal.tool.name == "claude" and "Claude Code" or "OpenAI Codex"
        all_ready = all_ready and content:find(title, 1, true) ~= nil and not trust
      end
      return all_ready
    end, 250)
    -- Preserve a diagnostic capture when a CLI is waiting for setup or login.
    if not ready then
      snapshot("ai-workspace-setup")
    end
    assert(ready, "AI CLIs did not reach their welcome screens")
    vim.wait(3000)
    assert(#terminals == 2 and terminals[1]:is_running() and terminals[2]:is_running(), "AI CLI exited")
    local top, bottom = terminals[1].win, terminals[2].win
    local top_pos, bottom_pos = vim.fn.win_screenpos(top), vim.fn.win_screenpos(bottom)
    assert(top_pos[2] == bottom_pos[2] and top_pos[1] < bottom_pos[1], "AI panels are not stacked")
    assert(top_pos[2] > vim.fn.win_screenpos(main)[2], "AI panels are not on the right")
    assert(text(explorer.list.win.buf):find("windvim", 1, true), "project tree is missing")

    vim.cmd.stopinsert()
    vim.api.nvim_set_current_win(main)
    Snacks.dashboard({ win = main, buf = vim.api.nvim_create_buf(false, true) })
    vim.api.nvim_buf_delete(staging, { force = true })
    vim.wait(500)
    Snacks.notifier.hide()
    snapshot("ai-workspace-zh")
    require("lazyvim_i18n").set_locale("en")
    vim.wait(300)
    snapshot("ai-workspace-en")
  end, debug.traceback)
  if not ok then
    err = err .. "\n" .. vim.api.nvim_exec2("messages", { output = true }).output
    for _, terminal in ipairs(terminals) do
      if terminal.buf and vim.api.nvim_buf_is_valid(terminal.buf) then
        err = err .. "\n" .. terminal.tool.name .. ":\n"
          .. table.concat(vim.api.nvim_buf_get_lines(terminal.buf, 0, -1, false), "\n")
      end
    end
  end
  for _, terminal in ipairs(terminals) do
    pcall(function()
      terminal:close()
    end)
  end
  vim.fn.writefile({ ok and "PASS" or "FAIL", err or "Real Claude Code and Codex workspace captured" }, vim.env.I18N_TEST_RESULT)
  vim.cmd(ok and "qa!" or "cquit 1")
end, 500)
