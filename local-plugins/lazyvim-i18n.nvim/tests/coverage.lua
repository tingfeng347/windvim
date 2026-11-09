-- Audit labels supplied by the installed, enabled plugins, including lazy specs.
-- This catches new upstream wording without duplicating the translation table.
return function(i18n)
  local missing, seen, count = {}, {}, 0
  local function check(domain, label, origin)
    if type(label) ~= "string" or not label:find("%a") then
      return
    end
    -- Literal commands, API snippets and which-key's hidden trigger IDs are
    -- source material, not natural-language descriptions.
    if label:match("^:") or label:match("^vim%.[%w_%.]+%(%)$") or label:match("^which[_%-]key") then
      return
    end
    local content = label:gsub("^%+", "")
    local translated = i18n.translate(content, domain)
    for _, scope in ipairs({ "Root Dir", "root dir", "cwd" }) do
      local suffix = " (" .. scope .. ")"
      if content:sub(-#suffix) == suffix then
        content = content:sub(1, -#suffix - 1)
        translated = translated:gsub("（.-）$", "")
        break
      end
    end
    local key = domain .. ":" .. content
    if seen[key] then
      return
    end
    seen[key] = true
    count = count + 1
    if translated == content then
      missing[#missing + 1] = origin .. ": " .. label
    end
  end

  for _, mode in ipairs({ "n", "x", "o", "i", "t" }) do
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      check("keymaps", map.desc, mode .. " " .. map.lhs)
    end
  end
  -- Lazy resolves quoted strings, helper results and function-valued keys.
  -- Inspect that data instead of trying to parse Lua with a text regexp.
  local plugins = require("lazy.core.config").plugins
  local plugin_values = require("lazy.core.plugin").values
  for name, plugin in pairs(plugins) do
    for _, map in ipairs(plugin_values(plugin, "keys", true)) do
      check("keymaps", type(map) == "table" and map.desc or nil, name)
    end
  end
  local lsp = plugins["nvim-lspconfig"]
  if lsp then
    for name, server in pairs(plugin_values(lsp, "opts", false).servers or {}) do
      if type(server) == "table" then
        for _, map in ipairs(server.keys or {}) do
          check("keymaps", map.desc, "LSP " .. name)
        end
      end
    end
  end
  -- which-key consumes/mutates its preset tables on setup. Read a fresh copy.
  local presets = assert(loadfile(vim.loader.find("which-key.plugins.presets")[1].modpath))()
  for _, group in pairs(presets) do
    if type(group) == "table" then
      for _, map in ipairs(group) do
        check("keymaps", map.desc or map.group, "which-key presets")
      end
    end
  end
  -- Expand fixed register/mark labels using deterministic data. Dynamic
  -- values are supplied as input, never treated as translation candidates.
  local getreg, getmarks = vim.fn.getreg, vim.fn.getmarklist
  local clipboard_provider = vim.g.loaded_clipboard_provider
  local ok, err = xpcall(function()
    vim.fn.getreg = function()
      return "i18n coverage content"
    end
    vim.g.loaded_clipboard_provider = 2
    vim.fn.getmarklist = function(buf)
      if not buf then
        return {}
      end
      local marks = {}
      for _, key in ipairs({ "^", ".", '"', "0", "'", "`", "[", "]", "<", ">" }) do
        marks[#marks + 1] = { mark = "'" .. key, pos = { buf, 1, 1, 0 } }
      end
      return marks
    end
    for _, name in ipairs({ "registers", "marks" }) do
      local plugin = require("which-key.plugins." .. name)
      for _, map in ipairs(plugin.mappings) do
        check("keymaps", map.desc, "which-key " .. name)
      end
      for _, item in ipairs(plugin.expand()) do
        check("keymaps", item.desc, "which-key " .. name)
      end
    end
  end, debug.traceback)
  vim.fn.getreg, vim.fn.getmarklist = getreg, getmarks
  vim.g.loaded_clipboard_provider = clipboard_provider
  assert(ok, err)
  for source, opts in pairs(require("snacks.picker.config.sources")) do
    check("picker", opts.title or require("snacks.picker.util").title(source), "picker " .. source)
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    for _, mode in ipairs({ "n", "x", "o", "i", "t" }) do
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
        check("keymaps", map.desc, "buffer " .. buf .. " " .. map.lhs)
      end
    end
  end
  table.sort(missing)
  assert(#missing == 0, "Untranslated UI descriptions:\n" .. table.concat(missing, "\n"))
  assert(count >= 300, "coverage audit did not reach the configured UI labels")
  return count
end
