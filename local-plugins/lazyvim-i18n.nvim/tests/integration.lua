-- Run via tests/run.py, which attaches a real Neovim UI.
vim.defer_fn(function()
  local ok, err = xpcall(function()
    local i18n = require("lazyvim_i18n")
    assert(
      require("lazy.core.config").plugins["lazyvim-i18n.nvim"].dir
        == vim.fn.stdpath("config") .. "/local-plugins/lazyvim-i18n.nvim",
      "local translation plugin must resolve inside the active standalone config"
    )
    assert(vim.fn.maparg("<leader>uH", "n", false, true).desc == "Switch UI Language (中文/English)")
    assert(vim.fn.maparg("<leader>uL", "n", false, true).desc == "Toggle Relative Number")
    assert(vim.fn.maparg("<leader>uC", "n", false, true).desc == "Colorschemes")
    local saved_env = vim.env.LAZYVIM_LANGUAGE
    vim.env.LAZYVIM_LANGUAGE = nil
    local state = vim.fn.tempname() .. "/locale"
    i18n.setup({ locale = "zh_CN", persist = true, state_file = state, keymap = false })
    local function eq(expected, actual)
      assert(expected == actual, ("expected %q, got %q"):format(tostring(expected), tostring(actual)))
    end
    local function contains(text, value)
      assert(text:find(value, 1, true), "missing " .. value .. " in:\n" .. text)
    end
    local function buffer(buf)
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
    local function snapshot(name)
      vim.cmd("redraw!")
      if vim.g.i18n_test_channel then
        vim.rpcnotify(vim.g.i18n_test_channel, "i18n_snapshot", name)
      end
    end

    eq("zh_CN", i18n.get_locale())
    eq("文件浏览器 (Snacks)（项目根目录）", i18n.translate("Explorer Snacks (root dir)", "keymaps"))
    eq("查找文件（项目根目录）", i18n.translate("Find Files (Root Dir)", "keymaps"))
    eq("uncharted UI label", i18n.translate("uncharted UI label", "keymaps"))
    eq("feat: Update Chinese.md", i18n.translate("feat: Update Chinese.md", "keymaps"))

    vim.cmd("Lazy")
    local lazy = require("lazy.view")
    assert(
      vim.wait(500, function()
        return lazy.visible()
      end),
      "Lazy did not open"
    )
    vim.wait(200)
    local render = lazy.view.render
    contains(buffer(lazy.view.buf), "安装 (I)")
    contains(buffer(lazy.view.buf), "总计：")
    contains(buffer(lazy.view.buf), "个插件")
    snapshot("lazy-zh")
    local get_plugin = render:get_plugin(render.locations[1].from)
    assert(get_plugin and get_plugin.name == render.locations[1].name, "plugin row navigation broke")
    -- A plugin/commit may be named exactly like an English UI word.
    render._lines = {}
    render:append("Update"):append("Help", "LazyDimmed"):append("/tmp/Files.md", "LazyDir")
    eq("Update", render._lines[1][1].str)
    eq("Help", render._lines[1][2].str)
    eq("/tmp/Files.md", render._lines[1][3].str)
    lazy.view:update()
    local diag = { message = "updates available" }
    render:diagnostic(diag)
    eq("有可用更新", render._diagnostics[#render._diagnostics].message)
    eq("updates available", diag.message)
    for _, width in ipairs({ 50, 80, 140 }) do
      vim.o.columns = width
      vim.o.lines = 45
      lazy.view:layout()
      vim.api.nvim_win_set_config(lazy.view.win, lazy.view.win_opts)
      render:update()
      for _, line in ipairs(vim.api.nvim_buf_get_lines(lazy.view.buf, 0, 6, false)) do
        assert(vim.fn.strdisplaywidth(line) <= lazy.view.win_opts.width, "translated header overflow")
      end
    end
    vim.cmd("Lazy help")
    vim.wait(100)
    contains(buffer(lazy.view.buf), "插件快捷键")
    contains(buffer(lazy.view.buf), "安装缺失的插件")
    vim.cmd("LazyVimLanguage en")
    vim.wait(100)
    contains(buffer(lazy.view.buf), "Keyboard Shortcuts")
    vim.cmd("LazyVimLanguage zh_CN")
    vim.wait(100)
    contains(buffer(lazy.view.buf), "插件快捷键")
    lazy.view:close()

    vim.o.columns = 140
    vim.o.lines = 45
    require("lazy").load({ plugins = { "which-key.nvim" } })
    vim.wait(100)
    local view = require("which-key.view")
    eq("缓冲区", view.replace("desc", "buffer"))
    eq("查找文件（项目根目录）", view.replace("desc", "Find Files (Root Dir)"))
    -- Real which-key state, layout, footer and highlights.
    local wk_error
    vim.defer_fn(function()
      local success, failure = xpcall(function()
        assert(view.view and view.view:valid(), "which-key did not open")
        local wk_text = buffer(view.view.buf)
        contains(wk_text, "搜索")
        contains(wk_text, "插件管理")
        contains(buffer(view.footer.buf), "关闭")
        snapshot("which-key-zh")
        local mapping = vim.fn.maparg("<leader>ff", "n", false, true)
        eq("Find Files (Root Dir)", mapping.desc)
        i18n.set_locale("en")
        contains(buffer(view.view.buf), "file/find")
        contains(buffer(view.footer.buf), "close")
        i18n.set_locale("zh_CN")
        contains(buffer(view.view.buf), "文件/查找")
      end, debug.traceback)
      wk_error = not success and failure or nil
      vim.api.nvim_input("<Esc>")
    end, 100)
    require("which-key").show({ keys = "<leader>", mode = "n" })
    assert(not wk_error, wk_error)

    local picker = Snacks.picker.files({ cwd = vim.fn.stdpath("config"), layout = "telescope" })
    vim.wait(200)
    local function titles()
      local ret = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local title = vim.api.nvim_win_get_config(win).title
        if type(title) == "table" then
          for _, chunk in ipairs(title) do
            ret[#ret + 1] = chunk[1]
          end
        end
      end
      return table.concat(ret)
    end
    contains(titles(), "文件")
    contains(titles(), "结果")
    snapshot("picker-zh")
    i18n.set_locale("en")
    contains(titles(), "Files")
    contains(titles(), "Results")
    i18n.set_locale("zh_CN")
    contains(titles(), "文件")
    picker:close()
    local util = require("snacks.picker.util")
    eq(
      "/tmp/Preview.md",
      util.tpl("{preview}", { title = "Files", source = "Files", preview = "/tmp/Preview.md", live = "" })
    )
    eq("Update = Help", util.tpl("{code}", { code = "Update = Help" }))

    local dashboard = require("snacks.dashboard")
    Snacks.dashboard.open()
    vim.wait(100)
    local dash_buf = vim.api.nvim_get_current_buf()
    contains(buffer(dash_buf), "查找文件")
    contains(buffer(dash_buf), "WindVim 已加载")
    snapshot("dashboard-zh")
    local logo_ns = vim.api.nvim_get_namespaces().windvim_logo
    local function logo_marks()
      return vim.inspect(vim.api.nvim_buf_get_extmarks(dash_buf, logo_ns, 0, -1, { details = true }))
    end
    local before = logo_marks()
    local changedtick = vim.api.nvim_buf_get_changedtick(dash_buf)
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.wait(400)
    local motion = vim.env.WINDVIM_ANIMATION ~= "0" and vim.env.NO_COLOR == nil
    if motion then
      assert(before ~= logo_marks(), "logo should animate while dashboard is focused")
    else
      eq(before, logo_marks())
    end
    eq(changedtick, vim.api.nvim_buf_get_changedtick(dash_buf))
    assert(vim.deep_equal(cursor, vim.api.nvim_win_get_cursor(0)), "animation must not move menu cursor")
    if motion and vim.env.WINDVIM_CAPTURE_ANIMATION == "1" then
      for _ = 1, 48 do
        vim.wait(120)
        snapshot("dashboard-animation")
      end
    end
    vim.cmd("Lazy")
    vim.wait(100)
    before = logo_marks()
    vim.wait(300)
    eq(before, logo_marks())
    require("lazy.view").view:close()
    vim.wait(300)
    if motion then
      assert(before ~= logo_marks(), "logo should resume after closing an overlay")
    else
      eq(before, logo_marks())
    end
    i18n.set_locale("en")
    vim.wait(100)
    contains(buffer(dash_buf), "Find File")
    contains(buffer(dash_buf), "WindVim loaded")
    contains(buffer(dash_buf), "plugins in")
    snapshot("dashboard-en")

    -- Motion must pause when hidden, reduced, or too large for the window.
    if motion then
      vim.api.nvim_exec_autocmds("FocusLost", {})
      before = logo_marks()
      vim.wait(250)
      eq(before, logo_marks())
      vim.api.nvim_exec_autocmds("FocusGained", {})
      vim.wait(250)
      assert(before ~= logo_marks(), "focus should resume motion")
    end
    local old_motion = vim.env.WINDVIM_ANIMATION
    vim.env.WINDVIM_ANIMATION = "0"
    dashboard.update()
    before = logo_marks()
    vim.wait(250)
    eq(before, logo_marks())
    vim.env.WINDVIM_ANIMATION = old_motion
    vim.o.columns = 40
    dashboard.update()
    vim.wait(150)
    contains(buffer(dash_buf), "W I N D V I M")
    eq(0, #vim.api.nvim_buf_get_extmarks(dash_buf, logo_ns, 0, -1, {}))
    snapshot("dashboard-compact")
    vim.o.columns = 140
    vim.o.lines = 28
    dashboard.update()
    eq(0, #vim.api.nvim_buf_get_extmarks(dash_buf, logo_ns, 0, -1, {}))
    vim.o.lines = 45
    dashboard.update()

    -- Persist to a temporary state file, then emulate a new plugin setup.
    eq("en", vim.fn.readfile(state)[1])
    i18n.setup({ state_file = state, keymap = false })
    eq("en", i18n.get_locale())
    i18n.toggle()
    eq("zh_CN", vim.fn.readfile(state)[1])
    i18n.setup({ state_file = state, keymap = false })
    eq("zh_CN", i18n.get_locale())
    local success = pcall(i18n.set_locale, "bogus")
    eq(false, success)
    eq("zh_CN", i18n.get_locale())
    i18n.setup({
      state_file = state,
      keymap = false,
      translations = { keymaps = { ["Find Files"] = "自定义查找" } },
    })
    eq("自定义查找", view.replace("desc", "Find Files"))

    i18n.teardown()
    eq("file/find", view.replace("desc", "file/find"))
    eq(0, vim.fn.exists(":LazyVimLanguage"))
    -- setup/teardown must restore inherited methods without leaving shadows.
    eq(nil, rawget(require("lazy.view.render"), "append"))
    eq(nil, rawget(require("lazy.view.render"), "col"))
    vim.fn.delete(vim.fn.fnamemodify(state, ":h"), "rf")
    vim.env.LAZYVIM_LANGUAGE = saved_env
    print("PASS: real Lazy, which-key, picker, dashboard; live switching, persistence, fallback, teardown")
  end, debug.traceback)
  if not ok then
    vim.fn.writefile({ "FAIL", err }, vim.env.I18N_TEST_RESULT)
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
  else
    vim.fn.writefile({ "PASS" }, vim.env.I18N_TEST_RESULT)
    vim.cmd("qa!")
  end
end, 100)
