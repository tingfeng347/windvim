-- Exercise the review findings through the actual plugin entry points.
return function(i18n, snapshot)
  local failures = {}
  local view = require("which-key.view")
  local audit = dofile(vim.fn.stdpath("config") .. "/local-plugins/lazyvim-i18n.nvim/tests/coverage.lua")
  local function check(name, run, cleanup)
    local ok, err = xpcall(run, debug.traceback)
    if cleanup then
      cleanup()
    end
    if not ok then
      failures[#failures + 1] = name .. ": " .. err
    end
  end

  check("command column", function()
    local executed
    vim.api.nvim_create_user_command("Visual", function(args)
      executed = args.args
    end, { nargs = "*" })
    vim.keymap.set("n", "<F12>", "<cmd>Visual selection or word<cr>", { desc = "Visual selection or word" })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<F12>", true, false, true), "xt", false)
    assert(executed == "selection or word", "custom command did not run")
    local map = vim.fn.maparg("<F12>", "n", false, true)
    local chunks = require("snacks.picker.format").keymap(
      { item = map },
      { opts = { icons = { keymaps = { nowait = "!" } } } }
    )
    local row = {}
    for _, chunk in ipairs(chunks) do
      row[#row + 1] = chunk[1]
    end
    row = table.concat(row)
    assert(row:find("<cmd>Visual selection or word<CR>", 1, true), "command column was translated: " .. row)
    assert(row:find("搜索选中文本或光标下单词", 1, true), "description was not translated")
    assert(map.rhs == "<cmd>Visual selection or word<cr>", "mapping was modified")
  end, function()
    vim.keymap.del("n", "<F12>")
    vim.api.nvim_del_user_command("Visual")
  end)

  local active
  check("bilingual keymap search", function()
    for _, locale in ipairs({ "zh_CN", "en" }) do
      i18n.set_locale(locale, { persist = false })
      for _, pattern in ipairs({ "查找文件", "Find Files" }) do
        active = Snacks.picker.keymaps({ pattern = pattern, show_empty = true })
        assert(
          vim.wait(1500, function()
            return not active.finder.task:running() and not active.matcher.task:running()
          end),
          "keymap matcher did not finish"
        )
        local found = false
        for _, item in ipairs(active:items()) do
          if item.item.desc == "Find Files (Root Dir)" then
            found = true
          end
        end
        assert(found, locale .. " could not find the file mapping with " .. pattern)
        if snapshot and locale == "zh_CN" and pattern == "查找文件" then
          active:show()
          active.list:update({ force = true })
          vim.wait(50)
          snapshot("keymaps-chinese-search-zh")
        end
        active:close()
        active = nil
      end
    end
  end, function()
    if active then
      active:close()
    end
    i18n.set_locale("zh_CN", { persist = false })
  end)

  check("Git file mappings", function()
    -- Exercise editor mappings without starting an unrelated AI server download.
    local copilot = require("lazy.core.config").plugins["copilot.lua"]
    if copilot and not copilot._.loaded then
      copilot.config = function() end
    end
    vim.cmd.edit(vim.fn.getcwd() .. "/lua/config/options.lua")
    assert(
      vim.wait(3000, function()
        return vim.fn.maparg("ih", "x", false, true).desc == "GitSigns Select Hunk"
      end),
      "Gitsigns did not attach to the tracked file"
    )
    for _, mode in ipairs({ "x", "o" }) do
      local map = vim.fn.maparg("ih", mode, false, true)
      assert(view.replace("desc", map.desc) == "选择 Git 差异块", "Git hunk text object remains untranslated")
    end
  end)

  local code_buf, mark_buf
  check("register and mark labels", function()
    local content = "Find Files /tmp/Preview.md"
    vim.fn.setreg("0", content)
    local found = false
    for _, item in ipairs(require("which-key.plugins.registers").expand()) do
      if item.key == "0" then
        found = true
        assert(view.replace("desc", item.desc) == "上次复制的内容", "register label remains untranslated")
        assert(item.value == content, "register content was translated")
      end
    end
    assert(found, "register 0 did not expand")
    local menu_error
    vim.defer_fn(function()
      local ok, err = xpcall(function()
        local text = table.concat(vim.api.nvim_buf_get_lines(view.view.buf, 0, -1, false), "\n")
        assert(text:find("上次复制的内容", 1, true), "register menu was not translated")
        assert(text:find(content, 1, true), "register content changed in the menu")
        if snapshot then
          snapshot("which-key-registers-zh")
        end
      end, debug.traceback)
      menu_error = not ok and err or nil
      vim.api.nvim_input("<Esc>")
    end, 100)
    require("which-key").show({ keys = '"', mode = "n" })
    assert(not menu_error, menu_error)
    code_buf = vim.api.nvim_get_current_buf()
    mark_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(mark_buf)
    vim.api.nvim_buf_set_lines(mark_buf, 0, -1, false, { content })
    found = false
    for _, item in ipairs(require("which-key.plugins.marks").expand()) do
      if item.key == "." then
        found = true
        assert(
          view.replace("desc", item.desc) == "当前缓冲区上次修改的位置",
          "mark label remains untranslated"
        )
      end
    end
    assert(found, "last-change mark did not expand")
  end, function()
    if code_buf then
      vim.api.nvim_set_current_buf(code_buf)
    end
    if mark_buf then
      vim.api.nvim_buf_delete(mark_buf, { force = true })
    end
  end)

  local config = require("lazy.core.config")
  check("resolved lazy key declarations", function()
    for _, code in ipairs({
      [[return { { '<F12>', desc = 'Untranslated review fixture' } }]],
      [[return { { '<F12>', desc = "Untranslated review fixture" } }]],
      [[return function() return { { '<F12>', desc = 'Untranslated ' .. 'review fixture' } } end]],
    }) do
      config.plugins["i18n-review-fixture"] = {
        name = "i18n-review-fixture",
        keys = assert(loadstring(code))(),
        _ = {},
      }
      local ok, err = pcall(audit, i18n)
      assert(not ok and tostring(err):find("Untranslated review fixture", 1, true), "lazy declaration escaped coverage")
    end
  end, function()
    config.plugins["i18n-review-fixture"] = nil
  end)

  check("clipboard register coverage", function()
    local ok, err = pcall(audit, {
      translate = function(label, domain)
        if label == "synchronized with the system clipboard" then
          return label
        end
        return i18n.translate(label, domain)
      end,
    })
    assert(
      not ok and tostring(err):find("synchronized with the system clipboard", 1, true),
      "clipboard register escaped coverage"
    )
  end)

  check("visual and operator buffer coverage", function()
    for _, mode in ipairs({ "x", "o" }) do
      vim.keymap.set(mode, "<F12>", "<Nop>", { buffer = 0, desc = "Untranslated buffer fixture" })
      local ok, err = pcall(audit, i18n)
      vim.keymap.del(mode, "<F12>", { buffer = 0 })
      assert(not ok and tostring(err):find("Untranslated buffer fixture", 1, true), mode .. " escaped coverage")
    end
  end)

  assert(#failures == 0, table.concat(failures, "\n\n"))
end
