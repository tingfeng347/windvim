-- A real project journey: dashboard + tree, editing, navigation and code preview.
vim.defer_fn(function()
  local ok, err = xpcall(function()
    local project = vim.fn.getcwd()
    local source = project .. "/lua/windvim/logo.lua"
    local function wait(ms)
      vim.wait(ms or 350)
    end
    local function snapshot(name)
      vim.cmd("redraw!")
      wait(60)
      local screen = {}
      for row = 1, vim.o.lines do
        screen[row] = {}
        for col = 1, vim.o.columns do
          screen[row][col] = { vim.fn.screenstring(row, col), vim.fn.screenattr(row, col) }
        end
      end
      vim.rpcrequest(vim.g.i18n_test_channel, "i18n_snapshot", name, screen)
    end
    local function text(buf)
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
    vim.cmd("Noice disable")
    Snacks.notifier.hide()
    local main = vim.api.nvim_get_current_win()
    assert(vim.bo.filetype == "snacks_dashboard", "initial dashboard is not ready")
    -- Let the project and its language tools settle before recording the home view.
    vim.cmd.edit(vim.fn.fnameescape(project .. "/lua/config/lazy.lua"))
    vim.cmd.edit(vim.fn.fnameescape(source))
    local explorer = Snacks.explorer({ cwd = project, layout = { preset = "sidebar", layout = { width = 29 } } })
    wait(1000)
    vim.wait(20000, function()
      return vim.lsp.status() == ""
    end, 100)
    wait(400)
    Snacks.explorer.reveal({ file = source })
    wait(350)
    vim.api.nvim_set_current_win(main)
    vim.cmd("Noice dismiss")
    Snacks.notifier.hide()
    assert(text(explorer.list.win.buf):find("windvim", 1, true), "project tree did not open")
    Snacks.dashboard.open({ win = main })
    wait(400)
    vim.cmd("Noice dismiss")
    Snacks.notifier.hide()
    wait(100)
    assert(text(vim.api.nvim_get_current_buf()):find("W I N D V I M", 1, true), "project dashboard missing")
    snapshot("dashboard-zh")
    for _ = 1, 48 do
      wait(120)
      snapshot("dashboard-animation")
    end
    require("lazyvim_i18n").set_locale("en")
    wait(180)
    snapshot("dashboard-en")
    require("lazyvim_i18n").set_locale("zh_CN")

    -- Return to the source buffer without reinitializing the project.
    vim.cmd.edit(vim.fn.fnameescape(source))
    wait(350)
    Snacks.explorer.reveal({ file = source })
    wait(250)
    vim.api.nvim_set_current_win(main)
    vim.cmd("normal! gg")
    vim.cmd("Noice dismiss")
    Snacks.notifier.hide()
    assert(vim.api.nvim_buf_get_name(0) == source, "code view did not open the project source")
    snapshot("project-code")

    -- Show the focused file-navigation group over the editing workspace.
    require("lazy").load({ plugins = { "which-key.nvim" } })
    local capture_error
    vim.defer_fn(function()
      local success, failure = pcall(function()
        assert(require("which-key.view").view:valid(), "which-key did not open")
        snapshot("which-key-zh")
      end)
      capture_error = not success and failure or nil
      vim.api.nvim_input("<Esc>")
    end, 180)
    require("which-key").show({ keys = "<leader>f", mode = "n" })
    assert(not capture_error, capture_error)
    wait(180)

    local picker = Snacks.picker.files({
      cwd = project,
      pattern = "lua/",
      layout = {
        preset = "telescope",
        layout = { width = 0.94, height = 0.88 },
      },
    })
    assert(
      vim.wait(2500, function()
        return picker:count() > 10
      end),
      "project files were not found"
    )
    wait(350)
    local found
    for index, item in ipairs(picker:items()) do
      if item.file == source or item.file == "lua/windvim/logo.lua" then
        picker.list:move(picker.list.reverse and (picker.list:count() - index + 1) or index, true, true)
        picker:show_preview()
        found = true
        break
      end
    end
    assert(found, "logo source is absent from search results")
    wait(350)
    assert(picker:current().file:find("logo.lua", 1, true), "wrong file selected for preview")
    vim.bo[picker.preview.win.buf].filetype = "lua"
    vim.bo[picker.preview.win.buf].syntax = "lua"
    vim.treesitter.start(picker.preview.win.buf, "lua")
    wait(200)
    snapshot("picker-zh")
    picker:close()
    wait(150)
    vim.cmd("Lazy")
    wait(250)
    snapshot("lazy-zh")
    require("lazy.view").view:close()
    assert(vim.v.errmsg == "", vim.v.errmsg)
  end, debug.traceback)
  vim.fn.writefile({ ok and "PASS" or "FAIL", err or "Project gallery captured" }, vim.env.I18N_TEST_RESULT)
  vim.cmd(ok and "qa!" or "cquit 1")
end, 250)
