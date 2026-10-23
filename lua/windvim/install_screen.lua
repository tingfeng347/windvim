-- Plugin-independent first-run homepage. No network or lazy.nvim calls here.
local M = {}
local logo = require("windvim.logo")
local ns = vim.api.nvim_create_namespace("windvim_install")
local buf, win, timer, group, logbuf
local status, frame = {}, 0
local focused = true
local saved_options

local function render()
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local width, height = vim.o.columns, math.max(1, vim.o.lines - vim.o.cmdheight)
  vim.api.nvim_win_set_config(win, { width = width, height = height })
  local rows = {}
  local function add(text, hl)
    rows[#rows + 1] = { { text, hl or "WindVimInstallText" } }
  end
  if width >= 46 and height >= 27 then
    for _, row in ipairs(logo.frame(frame)) do
      rows[#rows + 1] = row
    end
    add("")
  else
    add("W I N D V I M", "WindVimWordmark")
    add("")
  end
  add(status.message or "正在准备 WindVim", status.stopped and "WindVimInstallError" or "WindVimInstallTitle")
  if height >= 12 then
    add("首次启动 · 完成后自动进入，无需重启")
    add("")
  end
  if (status.total or 0) > 0 then
    add(("插件就绪 %d / %d · 第 %d 次尝试"):format(status.installed or 0, status.total, status.attempt or 1))
  elseif not status.stopped then
    add("正在下载插件管理器，请稍候…")
  end
  if height >= 12 then
    add(
      status.stopped and "按 l 查看完整日志，网络恢复后可继续安装"
        or status.task
        or "GitHub 下载速度取决于当前网络",
      "WindVimInstallMuted"
    )
  end
  if status.failed and #status.failed > 0 and height >= 12 then
    add(status.failed[1]:match("[^\n\r]+") or "请查看安装日志", "WindVimInstallError")
  end
  add("")
  add(
    status.retry == false and "l 查看日志    q 退出" or "l 查看日志    r 重试    q 退出",
    "WindVimInstallKey"
  )
  local lines, marks = {}, {}
  local top = math.max(0, math.floor((height - #rows) / 2))
  for _ = 1, top do
    lines[#lines + 1] = ""
  end
  for _, chunks in ipairs(rows) do
    if #lines >= height then
      break
    end
    local text = ""
    for _, chunk in ipairs(chunks) do
      text = text .. chunk[1]
    end
    -- Truncate by display cells, preserving Chinese and multibyte logo glyphs.
    while vim.fn.strdisplaywidth(text) > width - 2 and #text > 0 do
      text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
    end
    local padding = (" "):rep(math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2)))
    lines[#lines + 1] = padding .. text
    local col = #padding
    for _, chunk in ipairs(chunks) do
      local finish = math.min(#lines[#lines], col + #chunk[1])
      if finish > col then
        marks[#marks + 1] = { #lines - 1, col, finish, chunk[2] }
      end
      col = col + #chunk[1]
    end
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, mark[1], mark[2], { end_col = mark[3], hl_group = mark[4] })
  end
  vim.bo[buf].modifiable = false
  if logbuf and vim.api.nvim_buf_is_valid(logbuf) then
    local path = vim.b[logbuf].windvim_log
    local content = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path, "", -300) or { "等待安装日志…" }
    vim.bo[logbuf].modifiable = true
    vim.api.nvim_buf_set_lines(logbuf, 0, -1, false, content)
    vim.bo[logbuf].modifiable = false
  end
end

function M.update(value)
  status = value
  render()
end

function M.open(log, retry)
  saved_options = {}
  for name, value in pairs({ laststatus = 0, showtabline = 0, ruler = false, showmode = false }) do
    saved_options[name] = vim.o[name]
    vim.o[name] = value
  end
  logo.highlights()
  for name, opts in pairs({
    WindVimInstallNormal = { fg = "#cdd6f4", bg = "#1e1e2e" },
    WindVimInstallTitle = { fg = "#a6e3a1", bold = true },
    WindVimInstallText = { fg = "#cdd6f4" },
    WindVimInstallMuted = { fg = "#a6adc8" },
    WindVimInstallKey = { fg = "#89b4fa" },
    WindVimInstallError = { fg = "#f38ba8" },
  }) do
    vim.api.nvim_set_hl(0, name, opts)
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "windvim-install"
  win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = math.max(1, vim.o.lines - vim.o.cmdheight),
    style = "minimal",
    border = "none",
    zindex = 60,
  })
  vim.wo[win].winhighlight = "Normal:WindVimInstallNormal,EndOfBuffer:WindVimInstallNormal"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.keymap.set("n", "q", "<cmd>qa<cr>", { buffer = buf })
  vim.keymap.set("n", "r", function()
    if retry then
      retry()
    end
  end, { buffer = buf })
  vim.keymap.set("n", "l", function()
    if logbuf and vim.api.nvim_buf_is_valid(logbuf) then
      return
    end
    logbuf = vim.api.nvim_create_buf(false, true)
    vim.bo[logbuf].bufhidden = "wipe"
    vim.b[logbuf].windvim_log = log
    local logwin = vim.api.nvim_open_win(logbuf, true, {
      relative = "editor",
      row = 1,
      col = 1,
      width = math.max(1, vim.o.columns - 4),
      height = math.max(1, vim.o.lines - 5),
      style = "minimal",
      border = "rounded",
      title = " 安装日志 · q 返回 ",
      zindex = 70,
    })
    vim.keymap.set("n", "q", function()
      vim.api.nvim_win_close(logwin, true)
    end, { buffer = logbuf })
    render()
  end, { buffer = buf })
  group = vim.api.nvim_create_augroup("windvim_install_screen", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", { group = group, callback = render })
  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    callback = function()
      focused = false
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      focused = true
    end,
  })
  timer = assert(vim.uv.new_timer())
  timer:start(
    120,
    120,
    vim.schedule_wrap(function()
      if M.on_tick then
        M.on_tick()
      end
      if focused and vim.env.WINDVIM_ANIMATION ~= "0" and vim.env.NO_COLOR == nil then
        frame = frame + 1
      end
      render()
    end)
  )
  render()
end

function M.close()
  for name, value in pairs(saved_options or {}) do
    vim.o[name] = value
  end
  saved_options = nil
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  if group then
    vim.api.nvim_del_augroup_by_id(group)
    group = nil
  end
  if logbuf and vim.api.nvim_buf_is_valid(logbuf) then
    vim.api.nvim_buf_delete(logbuf, { force = true })
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  win, buf, M.on_tick = nil, nil, nil
end

return M
