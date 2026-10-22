-- WindVim's shaded W, swept by orbiting wind. Rendering uses native text only.
local M = {}
local WIDTH, HEIGHT, INTERVAL, FRAMES = 42, 13, 120, 48
local ns = vim.api.nvim_create_namespace("windvim_logo")
local active, timer
local step = 0
local focused = true
local shades = { "·", "░", "▒", "▓", "█" }
local COLOR_BANDS = 12
-- A cool-to-warm material runs along the W; lighting preserves its volume.
local palette = { { 103, 232, 208 }, { 116, 185, 245 }, { 181, 156, 248 }, { 241, 168, 216 } }
local background = { 30, 30, 46 }

local function material(band, shade)
  local position = (band - 1) / (COLOR_BANDS - 1) * (#palette - 1)
  local index = math.min(#palette - 1, math.floor(position) + 1)
  local fraction = position - (index - 1)
  local rgb = {}
  for channel = 1, 3 do
    local value = palette[index][channel] * (1 - fraction) + palette[index + 1][channel] * fraction
    if shade <= 3 then
      local light = 0.56 + shade * 0.12
      value = background[channel] + (value - background[channel]) * light
    else
      value = value + (255 - value) * (shade - 3) * 0.13
    end
    rgb[channel] = math.floor(value + 0.5)
  end
  return ("#%02x%02x%02x"):format(unpack(rgb))
end
local points = { { -1, -0.62 }, { -0.5, 0.62 }, { 0, -0.12 }, { 0.5, 0.62 }, { 1, -0.62 } }

local function highlights()
  for band = 1, COLOR_BANDS do
    for shade = 1, #shades do
      vim.api.nvim_set_hl(0, "WindVimLogo" .. band .. "_" .. shade, { fg = material(band, shade) })
    end
  end
  for name, color in pairs({
    WindVimWind = "#7099ce",
    WindVimOrbit = "#a18bc7",
    WindVimSpark = "#f4d58d",
    WindVimWordmark = "#dce4f5",
  }) do
    vim.api.nvim_set_hl(0, name, { fg = color })
  end
end

-- A small z-buffer gives the wind trails and tubular W a shared sense of depth.
function M.frame(frame)
  local cells, depth = {}, {}
  local phase = (frame % FRAMES) * math.pi * 2 / FRAMES
  local yaw = math.sin(phase) * 0.28
  local cy, sy = math.cos(yaw), math.sin(yaw)
  local function plot(x, y, z, char, hl)
    local rx, rz = x * cy + z * sy, z * cy - x * sy
    local col = math.floor(WIDTH / 2 + rx * 13.5 + 0.5)
    local row = math.floor(HEIGHT / 2 + (y * 0.94 - rz * 0.34) * 5 + 0.5)
    if col < 1 or col > WIDTH or row < 1 or row > HEIGHT then
      return
    end
    local index = (row - 1) * WIDTH + col
    local body = hl:match("^WindVimLogo")
    local previous_body = cells[index] and cells[index][2]:match("^WindVimLogo")
    if not depth[index] or (body and not previous_body) or (rz >= depth[index] and (body or not previous_body)) then
      depth[index], cells[index] = rz, { char, hl }
    end
  end
  -- Two broken orbital streams flow in opposing directions around the mark.
  for band = 0, 1 do
    for i = 0, 160 do
      local angle = i * math.pi / 80
      local travel = (angle - phase * (band == 0 and 1 or -1)) % (math.pi * 2)
      if travel < 4.8 then
        local x = 1.4 * math.cos(angle)
        local y = math.sin(angle) * 0.38 + (band == 0 and -0.12 or 0.12)
        local z = math.sin(angle) * (band == 0 and 0.85 or -0.85)
        plot(x, y, z, travel < 0.22 and "•" or "·", band == 0 and "WindVimWind" or "WindVimOrbit")
      end
    end
  end
  for segment = 1, #points - 1 do
    local a, b = points[segment], points[segment + 1]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local length = math.sqrt(dx * dx + dy * dy)
    for i = 0, 48 do
      local t = i / 48
      for side = 0, 15 do
        local angle = side * math.pi / 8
        local nx, ny, nz = -dy / length * math.cos(angle), dx / length * math.cos(angle), math.sin(angle)
        local light = math.max(0, math.min(1, (nz * 0.65 - ny * 0.45 - nx * 0.2 + 1) / 2))
        local shade = math.min(5, math.floor(light * 4) + 1)
        local x = a[1] + dx * t + nx * 0.13
        local band = math.max(1, math.min(COLOR_BANDS, math.floor((x + 1) / 2 * COLOR_BANDS) + 1))
        plot(x, a[2] + dy * t + ny * 0.13, nz * 0.13, shades[shade], "WindVimLogo" .. band .. "_" .. shade)
      end
    end
  end
  -- Small moving particles follow the wind, keeping the silhouette readable.
  for i = 0, 3 do
    local angle = phase + i * math.pi / 2
    plot(math.cos(angle) * 1.45, math.sin(angle) * 0.75, math.sin(angle) * 0.4, "*", "WindVimSpark")
  end
  local lines = {}
  for row = 1, HEIGHT do
    local chunks = {}
    for col = 1, WIDTH do
      local cell = cells[(row - 1) * WIDTH + col] or { " ", "WindVimWind" }
      local last = chunks[#chunks]
      if last and last[2] == cell[2] then
        last[1] = last[1] .. cell[1]
      else
        chunks[#chunks + 1] = { cell[1], cell[2] }
      end
    end
    lines[row] = chunks
  end
  lines[#lines + 1] = { { (" "):rep(WIDTH), "WindVimWordmark" } }
  local title = "W I N D V I M"
  lines[#lines + 1] = {
    {
      (" "):rep(math.floor((WIDTH - #title) / 2)) .. title .. (" "):rep(math.ceil((WIDTH - #title) / 2)),
      "WindVimWordmark",
    },
  }
  return lines
end

local function stop()
  if timer and not timer:is_closing() then
    timer:stop()
  end
end

local function visible()
  if not active or not vim.api.nvim_buf_is_valid(active.dashboard.buf) then
    return false
  end
  local d = active.dashboard
  return focused
    and vim.api.nvim_win_is_valid(d.win)
    and vim.api.nvim_get_current_win() == d.win
    and vim.api.nvim_win_get_buf(d.win) == d.buf
    and vim.api.nvim_win_get_width(d.win) >= 46
    and vim.api.nvim_win_get_height(d.win) >= 34
    and vim.fn.mode() == "n"
end

local function paint()
  if not visible() then
    stop()
    return
  end
  local d = active.dashboard
  vim.api.nvim_buf_clear_namespace(d.buf, ns, 0, -1)
  for i, chunks in ipairs(M.frame(step)) do
    vim.api.nvim_buf_set_extmark(d.buf, ns, active.row + i - 1, active.col, {
      virt_text = chunks,
      virt_text_pos = "overlay",
      hl_mode = "replace",
      priority = 200,
    })
  end
end

local function refresh()
  if not timer or timer:is_closing() then
    return
  end
  stop()
  if not visible() then
    return
  end
  paint()
  if vim.env.WINDVIM_ANIMATION == "0" or vim.env.NO_COLOR ~= nil or #vim.api.nvim_list_uis() == 0 then
    return
  end
  timer:start(
    INTERVAL,
    INTERVAL,
    vim.schedule_wrap(function()
      if not visible() then
        stop()
        return
      end
      step = (step + 1) % FRAMES
      paint()
    end)
  )
end

function M.section(dashboard)
  vim.api.nvim_buf_clear_namespace(dashboard.buf, ns, 0, -1)
  active = nil
  stop()
  if vim.api.nvim_win_get_width(dashboard.win) < 46 or vim.api.nvim_win_get_height(dashboard.win) < 34 then
    return { header = "W I N D V I M", padding = { 1, 0 } }
  end
  local text = {}
  for i, chunks in ipairs(M.frame(0)) do
    for _, chunk in ipairs(chunks) do
      text[#text + 1] = { chunk[1], hl = chunk[2] }
    end
    if i < HEIGHT + 2 then
      text[#text + 1] = { "\n" }
    end
  end
  return {
    text = text,
    align = "center",
    padding = { 1, 0 },
    render = function(d, pos)
      active = {
        dashboard = d,
        row = pos[1] - 1,
        col = math.max(0, math.floor(d.col) + math.floor((d.opts.width - WIDTH) / 2)),
      }
    end,
  }
end

function M.setup()
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
  timer = assert(vim.uv.new_timer())
  highlights()
  local group = vim.api.nvim_create_augroup("windvim_logo", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "SnacksDashboardUpdatePost", callback = refresh })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "WinClosed", "TabEnter", "ModeChanged", "VimResized" }, {
    group = group,
    callback = function()
      vim.schedule(refresh)
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    callback = function()
      focused = false
      stop()
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      focused = true
      refresh()
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      stop()
      timer:close()
    end,
  })
end

return M
