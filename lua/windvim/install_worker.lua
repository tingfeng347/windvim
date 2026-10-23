-- Run with the same binary and XDG environment, without loading init.lua.
local config = vim.fn.stdpath("config")
vim.opt.rtp:prepend(config)
vim.o.loadplugins = true -- -u NONE disables this; lazy.setup requires it.
vim.g.windvim_install_worker = true
vim.env.GIT_TERMINAL_PROMPT = "0"
local state = require("windvim.install_state")
local result_path = assert(arg[1], "Missing installer result path")
local pending_path = vim.fn.stdpath("state") .. "/install-pending-builds.json"
local pending = state.read(pending_path) or {}
local timer = assert(vim.uv.new_timer())
local reporting = true

local function progress()
  local c = package.loaded["lazy.core.config"]
  local value = { total = 0, installed = 0, failed = {}, dirs = {}, builds = {} }
  for name, plugin in pairs(c and c.plugins or {}) do
    value.total = value.total + 1
    value.dirs[#value.dirs + 1] = plugin.dir
    local ready = plugin._.installed and not plugin._.build and not plugin._.working
    for _, task in ipairs(plugin._.tasks or {}) do
      if task:has_errors() then
        ready = false
        value.failed[#value.failed + 1] = name .. " / " .. task.name .. ": " .. task:output(vim.log.levels.ERROR)
        if task.name == "build" then
          value.builds[#value.builds + 1] = name
        end
      elseif task:running() then
        value.task = name .. " / " .. task.name
        if task.name == "build" then
          value.builds[#value.builds + 1] = name
        end
      end
    end
    if ready then
      value.installed = value.installed + 1
    end
  end
  return value
end

timer:start(
  0,
  200,
  vim.schedule_wrap(function()
    if not reporting then
      return
    end
    local value = progress()
    state.write(result_path .. ".progress", value)
    for _, name in ipairs(value.builds) do
      if not vim.tbl_contains(pending, name) then
        pending[#pending + 1] = name
      end
    end
    state.write(pending_path, pending)
  end)
)

-- SIGTERM must also stop lazy.nvim's running Git/build subprocesses.
local signal = assert(vim.uv.new_signal())
signal:start(
  "sigterm",
  vim.schedule_wrap(function()
    local processes = package.loaded["lazy.manage.process"]
    if processes then
      processes.abort()
      vim.wait(1500, function()
        return next(processes.running) == nil
      end, 50)
    end
    vim.cmd("cquit 1")
  end)
)

local ok, err = xpcall(function()
  require("config.lazy")
  local c = require("lazy.core.config")
  -- lazy.nvim remembers a cloned directory across restarts, but not a failed
  -- build task. Keep that work explicitly until a later worker completes it.
  local builds = {}
  for _, name in ipairs(pending) do
    if c.plugins[name] then
      builds[#builds + 1] = name
    end
  end
  if #builds > 0 then
    require("lazy.manage").build({ plugins = builds, wait = true, show = false })
  end
  local value = progress()
  for _, notif in ipairs(c.spec.notifs or {}) do
    if notif.level >= vim.log.levels.ERROR then
      value.failed[#value.failed + 1] = notif.msg
    end
  end
  for name, plugin in pairs(c.plugins) do
    if not plugin._.installed or plugin._.build or plugin._.working then
      value.failed[#value.failed + 1] = name .. ": installation/build incomplete"
    end
  end
  value.ok = #value.failed == 0 and value.total > 0
  value.version = state.version
  state.write(pending_path, value.builds)
  state.write(result_path, value)
end, debug.traceback)
reporting = false
timer:stop()
timer:close()
signal:stop()
signal:close()
if not ok then
  local value = progress()
  for _, name in ipairs(value.builds) do
    pending[#pending + 1] = name
  end
  state.write(pending_path, pending)
  value.ok = false
  value.failed[#value.failed + 1] = tostring(err)
  state.write(result_path, value)
end
local result = state.read(result_path)
vim.cmd(result and result.ok and "qa!" or "cquit 1")
