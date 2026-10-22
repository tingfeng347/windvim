local M = {}
local options, locale, started
local dictionary = require("lazyvim_i18n.dictionary")

function M.get_locale()
  return locale or "en"
end

-- Unknown messages stay intact. Translation is restricted to adapter UI fields.
function M.translate(text, domain)
  return dictionary.translate(text, M.get_locale(), domain, options and options.translations)
end

local function state_path()
  return options.state_file or (vim.fn.stdpath("state") .. "/lazyvim-i18n/locale")
end

function M.refresh()
  local view = package.loaded["lazy.view"]
  if view and view.visible() then
    view.view:update()
  end
  local wk = package.loaded["which-key.view"]
  if wk and wk.view and wk.view:valid() then
    wk.show()
  end
  local picker = package.loaded["snacks.picker.core.picker"]
  if picker then
    for _, active in ipairs(picker.get()) do
      active:update_titles()
    end
  end
  local dashboard = package.loaded["snacks.dashboard"]
  if dashboard then
    dashboard.update()
  end
end

function M.set_locale(value, opts)
  assert(value == "en" or value == "zh_CN", "LazyVimLanguage: expected en or zh_CN")
  opts = opts or {}
  if options.persist and opts.persist ~= false then
    local path = state_path()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    local ok = vim.fn.writefile({ value }, path)
    if ok ~= 0 then
      error("LazyVimLanguage: could not save " .. path)
    end
  end
  locale = value
  M.refresh()
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyVimLanguageChanged", data = { locale = value } })
  return value
end

function M.toggle()
  return M.set_locale(locale == "zh_CN" and "en" or "zh_CN")
end

function M.setup(opts)
  if started then
    M.teardown()
  end
  options = vim.tbl_deep_extend("force", { locale = "zh_CN", persist = true, keymap = "<leader>uH" }, opts or {})
  locale = vim.env.LAZYVIM_LANGUAGE or options.locale
  if not vim.env.LAZYVIM_LANGUAGE and options.persist and vim.fn.filereadable(state_path()) == 1 then
    local saved = vim.fn.readfile(state_path())[1]
    if saved == "en" or saved == "zh_CN" then
      locale = saved
    else
      vim.notify("i18n: invalid saved locale; using configured default", vim.log.levels.WARN)
    end
  end
  assert(locale == "en" or locale == "zh_CN", "i18n: locale must be en or zh_CN")
  started = true
  require("lazyvim_i18n.hooks").start()
  require("lazyvim_i18n.adapters").setup(M)
  vim.api.nvim_create_user_command("LazyVimLanguage", function(args)
    if args.args == "" then
      vim.notify("LazyVim language: " .. locale)
    elseif args.args == "toggle" then
      M.toggle()
    else
      M.set_locale(args.args)
    end
  end, {
    nargs = "?",
    desc = "Set interface language (zh_CN/en/toggle)",
    complete = function()
      return { "zh_CN", "en", "toggle" }
    end,
  })
  if options.keymap then
    -- Respect an existing mapping rather than silently overwriting it.
    if vim.fn.maparg(options.keymap, "n") == "" then
      vim.keymap.set("n", options.keymap, M.toggle, { desc = "Switch UI Language (中文/English)" })
      M._mapped = true
    else
      vim.notify("i18n: keymap already in use: " .. options.keymap .. "; use :LazyVimLanguage", vim.log.levels.WARN)
    end
  end
  M.refresh()
end

function M.teardown()
  if not started then
    return
  end
  require("lazyvim_i18n.hooks").stop()
  vim.api.nvim_del_user_command("LazyVimLanguage")
  if M._mapped then
    vim.keymap.del("n", options.keymap)
    M._mapped = nil
  end
  locale = "en"
  started = false
  M.refresh()
end

return M
