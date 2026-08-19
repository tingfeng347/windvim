-- Keep the LazyVim UI transparent while preserving each colorscheme's
-- foreground colors and other styling.
local transparent_groups = {
  "Normal",
  "NormalNC",
  "CursorLine",
  "SignColumn",
  "EndOfBuffer",
  "MsgArea",
  "Folded",
  "FoldColumn",
  "NormalFloat",
  "FloatBorder",
  "FloatTitle",
  "StatusLine",
  "StatusLineNC",
  -- The dashboard uses this otherwise-empty lualine component. Explicitly
  -- clearing its background prevents StatusLine from filling the whole row.
  "lualine_transparent",
  -- Ty's inferred type and parameter hints are virtual text. Keep the hint
  -- text, but do not render its rectangular background.
  "LspInlayHint",
  "TabLine",
  "TabLineFill",
  "TabLineSel",
  "WinBar",
  "WinBarNC",
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "TelescopeNormal",
  "TelescopeBorder",
  "TelescopePromptNormal",
  "TelescopePromptBorder",
  "TelescopeResultsNormal",
  "TelescopePreviewNormal",
  -- which-key maps its popup's Normal group to WhichKeyNormal.
  "WhichKeyNormal",
  "WhichKeyFloat",
  "MasonNormal",
  "LazyNormal",
  "NoicePopup",
  "NoiceCmdlinePopup",
  -- Snacks uses level-specific Normal groups for its status notifications.
  "SnacksNotifierError",
  "SnacksNotifierWarn",
  "SnacksNotifierInfo",
  "SnacksNotifierDebug",
  "SnacksNotifierTrace",
  "SnacksNotifierMinimal",
  "SnacksNotifierHistory",
  -- Keep diagnostic text visible, but do not render an opaque background
  -- behind virtual-text messages at the right edge of the editor.
  "DiagnosticVirtualTextError",
  "DiagnosticVirtualTextWarn",
  "DiagnosticVirtualTextInfo",
  "DiagnosticVirtualTextHint",
  "DiagnosticVirtualTextOk",
  -- Do not clear RenderMarkdown* groups here. They intentionally retain the
  -- same title bands and code-block surface used by the separate nvim setup.
  -- Treesitter can apply these Markdown groups directly, independently of
  -- render-markdown's RenderMarkdown* extmarks.
  "@markup.heading.1.markdown",
  "@markup.heading.2.markdown",
  "@markup.heading.3.markdown",
  "@markup.heading.4.markdown",
  "@markup.heading.5.markdown",
  "@markup.heading.6.markdown",
  "@markup.raw.markdown_inline",
  "@markup.raw.block.markdown",
  "markdownH1",
  "markdownH2",
  "markdownH3",
  "markdownH4",
  "markdownH5",
  "markdownH6",
  "markdownCode",
  "markdownCodeBlock",
  -- Snacks Explorer is rendered by the Snacks picker rather than Neo-tree.
  -- These groups are created when the picker opens, so they need explicit
  -- coverage in addition to NormalFloat.
  "SnacksPicker",
  "SnacksPickerInput",
  "SnacksPickerList",
  "SnacksPickerPreview",
  "SnacksPickerBox",
  -- Each picker window remaps Border, Title, and Footer to a
  -- surface-specific group.
  "SnacksPickerBorder",
  "SnacksPickerInputBorder",
  "SnacksPickerListBorder",
  "SnacksPickerPreviewBorder",
  "SnacksPickerBoxBorder",
  "SnacksPickerTitle",
  "SnacksPickerInputTitle",
  "SnacksPickerListTitle",
  "SnacksPickerPreviewTitle",
  "SnacksPickerBoxTitle",
  "SnacksPickerFooter",
  "SnacksPickerInputFooter",
  "SnacksPickerListFooter",
  "SnacksPickerPreviewFooter",
  "SnacksPickerBoxFooter",
}

-- Keep picker cursor lines transparent, including the active Explorer row.
local selection_groups = {
  "SnacksPickerInputCursorLine",
  "SnacksPickerPreviewCursorLine",
  "SnacksPickerBoxCursorLine",
}

-- Use a calm blue accent for Snacks Explorer / Picker frames instead of the
-- colorscheme's warm orange, while preserving transparent popup surfaces.
local picker_accent_groups = {
  "SnacksPickerBorder",
  "SnacksPickerInputBorder",
  "SnacksPickerListBorder",
  "SnacksPickerPreviewBorder",
  "SnacksPickerBoxBorder",
  "SnacksPickerTitle",
  "SnacksPickerInputTitle",
  "SnacksPickerListTitle",
  "SnacksPickerPreviewTitle",
  "SnacksPickerBoxTitle",
}

local picker_border_groups = {
  "SnacksPickerBorder",
  "SnacksPickerInputBorder",
  "SnacksPickerListBorder",
  "SnacksPickerPreviewBorder",
  "SnacksPickerBoxBorder",
}

-- Snacks links untracked files (including their filenames) to NonText by
-- default. NonText is intentionally very dim in this colorscheme, which makes
-- new files and their trailing "?" status hard to read on a transparent pane.
local readable_groups = {
  SnacksPickerGitStatusUntracked = "DiagnosticInfo",
  -- Explorer's right-aligned item count (for example, "4/4") should match
  -- regular file text instead of the colorscheme's dim picker metadata.
  SnacksPickerTotals = "Normal",
  SnacksPickerPathHidden = "SnacksPickerFile",
  SnacksPickerPathIgnored = "SnacksPickerFile",
}

-- Match the nvim-tree foregrounds used by the separate nvim configuration.
-- Git state still appears through its icon/status marker on the right;
-- disabling only `git_status_hl` below prevents that marker from recoloring
-- the filename itself.
local explorer_filename_groups = {
  SnacksPickerFile = "#CDD6F5",
  SnacksPickerDirectory = "#89B4FB",
  SnacksPickerDir = "#89B4FB",
}

-- The colorscheme deliberately dims relative line numbers too far for a
-- transparent, image-backed terminal. Increase only their foreground contrast.
local line_number_groups = {
  "LineNr",
  "LineNrAbove",
  "LineNrBelow",
}

-- Exact six-level heading foregrounds from the separate nvim configuration.
-- Backgrounds are deliberately left transparent below.
local markdown_heading_colors = {
  "#F38BA9",
  "#FAB388",
  "#F9E2B0",
  "#A6E3A2",
  "#74C7ED",
  "#B4BEFF",
}

local function set_flash_label_highlight()
  -- Flash's labels are shown after pressing `s`. Use red rather than the
  -- colorscheme's green label colour, while retaining their contrast surface.
  vim.api.nvim_set_hl(0, "FlashLabel", { fg = "#F38BA8", bg = "#1E1E2F", bold = true })
end

local dim_statusline_foregrounds = {
  [tonumber("181826", 16)] = true, -- Catppuccin mantle
  [tonumber("1E1E2F", 16)] = true, -- terminal dark text
  [tonumber("313245", 16)] = true, -- Lualine transition surface
  [tonumber("45475B", 16)] = true, -- Catppuccin surface1
}

local function clear_statusline_group(group)
  local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
  -- Preserve each component's semantic colour. Only near-black foregrounds
  -- become unreadable once their dark background is removed.
  vim.cmd("highlight " .. group .. " guibg=NONE ctermbg=NONE")
  if highlight.fg and dim_statusline_foregrounds[highlight.fg] then
    vim.cmd("highlight " .. group .. " guifg=#BAC2DE")
  end
end

local function clear_lualine_backgrounds()
  -- Lualine creates extra diagnostic, Diff and transition groups at runtime;
  -- clearing only its six base sections leaves opaque islands behind.
  for _, group in ipairs(vim.fn.getcompletion("lualine_", "highlight")) do
    clear_statusline_group(group)
  end
  clear_statusline_group("StatusLine")
  clear_statusline_group("StatusLineNC")
end

-- Load the exact nvim-web-devicons version and palette used by the separate
-- nvim configuration. This is scoped to Explorer formatting; LazyVim's other
-- MiniIcons-based surfaces stay untouched.
local nvim_devicons
local function get_nvim_devicons()
  if nvim_devicons then
    return nvim_devicons
  end
  local root = vim.fn.expand("~/.local/share/nvim/site/lazy/nvim-web-devicons")
  vim.opt.rtp:append(root)
  nvim_devicons = assert(loadfile(root .. "/lua/nvim-web-devicons.lua"))()
  nvim_devicons.setup()
  return nvim_devicons
end

-- Match the local nvim-tree presentation without changing Snacks Explorer's
-- behavior: use the same chevrons and folder glyphs, and replace Snacks'
-- connector drawing (│├└) with indentation only.
local function nvim_tree_format(item, picker)
  local ret = Snacks.picker.format.file(item, picker)
  for _, part in ipairs(ret) do
    if part.virtual and part[1] ~= " " then
      if item.dir then
        part[1] = item.open and " " or " "
        part[2] = "SnacksPickerDirectory"
      else
        local name = vim.fn.fnamemodify(item.file, ":t")
        local icon, hl = get_nvim_devicons().get_icon(name, nil, { default = true })
        part[1] = icon .. " "
        part[2] = hl
      end
      break
    end
  end
  if not item.parent then
    return ret
  end

  local depth = 0
  local parent = item.parent
  while parent and parent.parent do
    depth = depth + 1
    parent = parent.parent
  end

  local prefix = string.rep("  ", depth)
  if item.dir then
    prefix = prefix .. (item.open and " " or " ")
  else
    prefix = prefix .. "  "
  end
  ret[1] = { prefix, "SnacksPickerTree" }
  return ret
end

local function make_transparent()
  for _, group in ipairs(transparent_groups) do
    -- :highlight changes only the background attributes here, so the
    -- colorscheme's foreground and font attributes remain intact.
    vim.cmd("highlight " .. group .. " guibg=NONE ctermbg=NONE")
  end
  -- Default Neovim floats such as Mason inherit FloatBorder. Keep their
  -- content transparent but give the outer frame the same blue-grey treatment
  -- as the LazyGit window.
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#5FA8D3", bg = "NONE", blend = 45 })
  -- Native popup menus are also used for the right-click PopUp menu. Match
  -- the separate nvim config: all non-selected menu cells are genuinely
  -- transparent, including the border and extra-text groups. Leaving either
  -- group with a background causes isolated dark blocks over the wallpaper.
  vim.api.nvim_set_hl(0, "Pmenu", { fg = "#9399B3", bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuSel", { fg = "#1E1E2F", bg = "#A6E3A2", bold = true })
  vim.api.nvim_set_hl(0, "PmenuKind", { fg = "#9399B3", bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuKindSel", { fg = "#1E1E2F", bg = "#A6E3A2", bold = true })
  vim.api.nvim_set_hl(0, "PmenuExtra", { fg = "#6C7087", bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuExtraSel", { fg = "#6C7087", bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuMatch", { bold = true, bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuMatchSel", { bold = true, bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuBorder", { fg = "#45475B", bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuSbar", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuThumb", { bg = "NONE" })
  for _, group in ipairs(selection_groups) do
    vim.api.nvim_set_hl(0, group, { link = "CursorLine" })
  end
  -- Snacks Explorer renders its file rows through SnacksPickerListCursorLine.
  -- Link it to the transparent CursorLine so the selected row has no fill.
  vim.api.nvim_set_hl(0, "SnacksPickerListCursorLine", { link = "CursorLine" })
  for _, group in ipairs(picker_accent_groups) do
    vim.api.nvim_set_hl(0, group, { fg = "#5FA8D3", bg = "NONE" })
  end
  -- Keep the blue Explorer frame, but soften it against the transparent
  -- terminal background without dimming the title text.
  for _, group in ipairs(picker_border_groups) do
    vim.api.nvim_set_hl(0, group, { fg = "#5FA8D3", bg = "NONE", blend = 45 })
  end
  -- Explorer keeps its hidden input slot above the file list. Hide only that
  -- slot's unused border/title so no rectangular cap appears above the
  -- sidebar separator.
  vim.api.nvim_set_hl(0, "SnacksPickerInputBorder", { fg = "NONE", bg = "NONE" })
  vim.api.nvim_set_hl(0, "SnacksPickerInputTitle", { fg = "NONE", bg = "NONE" })
  -- The Explorer's right-hand separator is the list border. Use a neutral
  -- grey with blending so it stays visible over the wallpaper without
  -- becoming a solid dark rule.
  vim.api.nvim_set_hl(0, "SnacksPickerListBorder", { fg = "#A6ADC8", bg = "NONE", blend = 65 })
  -- Match the separate nvim configuration's one-cell sidebar separator.
  -- Snacks maps its Explorer separator through SnacksWinSeparator.
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#45475B", bg = "NONE" })
  vim.api.nvim_set_hl(0, "SnacksWinSeparator", { fg = "#45475B", bg = "NONE" })
  -- LazyGit remains transparent, but receives its own visible outer frame.
  vim.api.nvim_set_hl(0, "SnacksLazyGitBorder", { fg = "#5FA8D3", bg = "NONE", blend = 45 })
  for group, target in pairs(readable_groups) do
    vim.api.nvim_set_hl(0, group, { link = target })
  end
  for group, fg in pairs(explorer_filename_groups) do
    vim.api.nvim_set_hl(0, group, { fg = fg, bg = "NONE" })
  end
  vim.api.nvim_set_hl(0, "SnacksPickerTree", { fg = "#585B71", bg = "NONE" })
  for _, group in ipairs(line_number_groups) do
    vim.api.nvim_set_hl(0, group, { fg = "#7F96BD", bg = "NONE" })
  end
  set_flash_label_highlight()
  clear_lualine_backgrounds()
  -- Match nvim's visual-selection treatment: muted slate rather than the
  -- colorscheme's brighter blue, with the selected text kept bold.
  vim.api.nvim_set_hl(0, "Visual", { bg = "#45475B", bold = true })
  vim.api.nvim_set_hl(0, "VisualNOS", { bg = "#45475B", bold = true })
  for level, color in ipairs(markdown_heading_colors) do
    -- Keep six-level title text and source syntax colours without rendering a
    -- coloured title strip.
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level, { fg = color })
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level .. "Bg", { bg = "NONE" })
    vim.api.nvim_set_hl(0, "@markup.heading." .. level .. ".markdown", { fg = color, bg = "NONE" })
    vim.api.nvim_set_hl(0, "markdownH" .. level, { fg = color, bg = "NONE" })
  end
  vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "RenderMarkdownIndent", { fg = "#45475B", bg = "NONE" })
end

local transparent_group = vim.api.nvim_create_augroup("lazyvim_transparent_background", { clear = true })

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = transparent_group,
  callback = make_transparent,
})

vim.api.nvim_create_autocmd("User", {
  group = transparent_group,
  pattern = "VeryLazy",
  callback = function()
    make_transparent()
    -- Lualine is also loaded by VeryLazy and can define its segment groups
    -- after this event callback. Reapply once those groups exist.
    vim.defer_fn(make_transparent, 50)
  end,
})

-- Snacks defines the window-specific groups while opening a picker. Reapply
-- after each newly created window so its CursorLine cannot restore a solid
-- selection background.
vim.api.nvim_create_autocmd("WinNew", {
  group = transparent_group,
  callback = function()
    vim.schedule(make_transparent)
  end,
})

-- LSP clients can define their inlay-hint highlight group after startup.
-- Reapply once Ty attaches so inferred type hints remain transparent.
vim.api.nvim_create_autocmd("LspAttach", {
  group = transparent_group,
  callback = function()
    vim.schedule(make_transparent)
  end,
})

-- Lualine may create a mode-specific group when switching modes. Clear only
-- the background again after that group exists, preserving its text colours.
vim.api.nvim_create_autocmd("ModeChanged", {
  group = transparent_group,
  callback = function()
    vim.schedule(clear_lualine_backgrounds)
  end,
})

-- render-markdown is loaded for Markdown buffers and creates its highlight
-- groups after startup. Apply again once that filetype finishes loading.
vim.api.nvim_create_autocmd("FileType", {
  group = transparent_group,
  pattern = "markdown",
  callback = function()
    vim.schedule(make_transparent)
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = transparent_group,
  callback = function(args)
    if vim.bo[args.buf].filetype == "markdown" then
      -- render-markdown attaches asynchronously after the buffer is entered.
      vim.defer_fn(make_transparent, 50)
    end
  end,
})

-- Apply once in case this file is sourced after the colorscheme has loaded.
make_transparent()

return {
  {
    "folke/flash.nvim",
    opts = function(_, opts)
      -- Flash creates its default highlights when the plugin loads, after the
      -- global colorscheme hooks above. Reapply this one scoped override then.
      vim.schedule(set_flash_label_highlight)
      return opts
    end,
  },
  {
    "folke/snacks.nvim",
    init = function()
      -- nvim-tree's default "name" sorter compares with :lower() (case-
      -- insensitive). Snacks' explorer tree walk sorts case-sensitively, so
      -- patch its walk to ignore case and match the nvim setup exactly:
      -- folders first, then files in case-insensitive alphabetical order.
      local Tree = require("snacks.explorer.tree")
      local orig_walk = Tree.walk
      function Tree:walk(node, fn, opts)
        local abort = fn(node)
        if abort ~= nil then
          return abort
        end
        local children = vim.tbl_values(node.children)
        table.sort(children, function(a, b)
          if a.dir ~= b.dir then
            return a.dir
          end
          return a.name:lower() < b.name:lower()
        end)
        for c, child in ipairs(children) do
          child.last = c == #children
          abort = false
          if child.dir and (child.open or (opts and opts.all)) then
            abort = self:walk(child, fn, opts)
          else
            abort = fn(child)
          end
          if abort then
            return true
          end
        end
        return false
      end
    end,
    opts = {
      picker = {
        icons = {
          files = {
            dir = " ",
            dir_open = " ",
          },
        },
        sources = {
          explorer = {
            format = nvim_tree_format,
            layout = {
              preset = "sidebar",
              preview = false,
              hidden = { "input" },
              layout = {
                width = 30,
                min_width = 30,
              },
            },
          },
        },
        formatters = {
          file = {
            -- Keep Git decorations, but do not use them as the filename's
            -- highlight. This makes the Explorer text match Normal.
            git_status_hl = false,
          },
        },
      },
      notifier = {
        -- The compact renderer still draws a boxed notification surface in
        -- this UI. Minimal removes that surface entirely.
        style = "minimal",
      },
      styles = {
        -- Dashboard keeps its own window highlight mapping. Map its empty
        -- statusline row to Normal so the homepage does not inherit the
        -- opaque global StatusLine background.
        dashboard = {
          wo = {
            winhighlight = "Normal:SnacksDashboardNormal,NormalFloat:SnacksDashboardNormal,StatusLine:Normal,StatusLineNC:Normal",
          },
        },
        notification = {
          -- winblend is a transparency percentage: 100 makes the notification
          -- surface fully transparent while its text and border stay visible.
          wo = { winblend = 100 },
        },
        lazygit = {
          -- Frame only the outer floating terminal. LazyGit's own panes stay
          -- transparent and continue to use its generated colours.
          border = "rounded",
          backdrop = false,
          wo = {
            winhighlight = table.concat({
              "Normal:SnacksNormal",
              "NormalNC:SnacksNormalNC",
              "WinBar:SnacksWinBar",
              "WinBarNC:SnacksWinBarNC",
              "FloatTitle:SnacksTitle",
              "FloatFooter:SnacksFooter",
              "WinSeparator:SnacksWinSeparator",
              "FloatBorder:SnacksLazyGitBorder",
            }, ","),
          },
        },
      },
    },
  },
}
