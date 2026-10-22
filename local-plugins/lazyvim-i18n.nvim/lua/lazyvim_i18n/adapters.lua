local M = {}

function M.setup(i18n)
  local hooks = require("lazyvim_i18n.hooks")
  local function tr(text, domain)
    return i18n.translate(text, domain)
  end

  hooks.watch("which-key.view", function(view)
    -- Format descriptions after which-key's own replacements. Original keymaps,
    -- descriptions and icon matching remain available to the other plugins.
    hooks.wrap(view, "replace", function(original)
      return function(field, value)
        local text = original(field, value)
        return field == "desc" and tr(text, "keymaps") or text
      end
    end)
  end)
  hooks.watch("which-key.text", function(text)
    hooks.wrap(text, "append", function(original)
      return function(self, value, opts)
        if opts == "WhichKeySeparator" and type(value) == "string" then
          value = tr(value, "which_key")
        end
        return original(self, value, opts)
      end
    end)
  end)

  hooks.watch("lazy.view.render", function(render)
    local text = require("lazy.view.text")
    -- Render.append inherits Text.append; shadow it only on this renderer.
    -- Unstyled plugin names, commit messages, paths and task output are excluded.
    local ui_highlights = { LazyH2 = true, LazyButton = true, LazyButtonActive = true, Title = true }
    hooks.wrap(render, "append", function(original)
      return function(self, text, hl, opts)
        if ui_highlights[hl] or self.view.state.mode == "help" then
          text = tr(text, "lazy")
        elseif hl == "LazyComment" and text:match("^%d+ plugins$") then
          text = tr(text, "lazy")
        end
        return original(self, text, hl, opts)
      end
    end, text.append)
    -- Width for button wrapping is screen cells; Text.render still uses bytes
    -- for extmarks, as Neovim requires.
    hooks.wrap(render, "col", function(original)
      return function(self)
        if i18n.get_locale() == "en" then
          return original(self)
        end
        local width = 0
        for _, segment in ipairs(self._lines[#self._lines] or {}) do
          width = width + vim.fn.strdisplaywidth(segment.str)
        end
        return width
      end
    end, text.col)
    hooks.wrap(render, "diagnostic", function(original)
      return function(self, diagnostic)
        local translated = vim.tbl_extend("force", {}, diagnostic)
        translated.message = tr(translated.message, "lazy")
        return original(self, translated)
      end
    end)
    hooks.wrap(render, "update", function(original)
      return function(self)
        self.wrap = vim.api.nvim_win_get_width(self.view.win)
        return original(self)
      end
    end)
  end)

  hooks.watch("snacks.picker.util", function(util)
    hooks.wrap(util, "tpl", function(original)
      return function(template, data, opts)
        -- Title template calls have these four fields. Other uses (including
        -- code/diff generation) pass through byte-for-byte.
        if type(data.title) == "string" and data.source and data.preview ~= nil and data.live ~= nil then
          data = vim.tbl_extend("force", {}, data)
          data.title = tr(data.title, "picker")
          data.source = tr(data.source, "picker")
          template = tr(template, "picker")
        end
        return original(template, data, opts)
      end
    end)
  end)

  hooks.watch("snacks.dashboard", function(dashboard)
    hooks.wrap(dashboard.Dashboard, "format", function(original)
      return function(self, item)
        local copy = vim.tbl_extend("force", {}, item)
        for _, field in ipairs({ "desc", "title", "footer" }) do
          if type(copy[field]) == "string" then
            copy[field] = tr(copy[field], "dashboard")
          end
        end
        if type(copy.text) == "table" then
          copy.text = vim.deepcopy(copy.text)
          if type(copy.text[1]) == "string" then
            copy.text[1] = tr(copy.text[1], "dashboard")
          else
            for _, chunk in ipairs(copy.text) do
              if type(chunk[1]) == "string" then
                chunk[1] = tr(chunk[1], "dashboard")
              end
            end
          end
        end
        return original(self, copy)
      end
    end)
  end)
end

return M
