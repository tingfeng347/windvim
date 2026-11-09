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
  for _, name in ipairs(require("lazy.core.config").spec.modules) do
    require("lazy.core.util").lsmod(name, function(_, path)
      for _, line in ipairs(vim.fn.readfile(path)) do
        -- Extra-module metadata is not a mapping description.
        if not line:match("^  desc%s*=") then
          local label = line:match('desc%s*=%s*"([^"]+)"')
          check("keymaps", label, name)
        end
      end
    end)
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
  for source, opts in pairs(require("snacks.picker.config.sources")) do
    check("picker", opts.title or require("snacks.picker.util").title(source), "picker " .. source)
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    for _, mode in ipairs({ "n", "i" }) do
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
