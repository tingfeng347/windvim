local M = {}
local state = require("windvim.install_state")

function M.start()
  -- Automation retains normal synchronous/headless lazy.nvim semantics.
  for _, arg in ipairs(vim.v.argv) do
    if arg == "--headless" or arg == "-es" or arg == "-Es" then
      return false
    end
  end
  if state.ready() then
    return false
  end
  vim.opt.shortmess:append("I")
  vim.o.termguicolors = true
  vim.g.windvim_installing = true
  local screen = require("windvim.install_screen")
  local log = vim.fn.stdpath("state") .. "/install.log"
  vim.fn.mkdir(vim.fn.fnamemodify(log, ":h"), "p")
  local job, attempt, closed, failed = nil, 0, false, false
  local result_path = vim.fn.stdpath("state") .. "/install-" .. vim.fn.getpid() .. ".json"
  local group = vim.api.nvim_create_augroup("windvim_first_run", { clear = true })
  local run

  local function append(lines)
    vim.fn.writefile(lines, log, "a")
  end
  local function clean_result()
    vim.fn.delete(result_path)
    vim.fn.delete(result_path .. ".progress")
  end

  local function finish(result)
    screen.close()
    local ok, err = pcall(require, "config.lazy")
    if not ok then
      append({ tostring(err) })
      screen.open(log)
      screen.update({
        message = "配置加载失败，请查看日志",
        stopped = true,
        retry = false,
        failed = { tostring(err) },
      })
      return
    end
    state.write(vim.fn.stdpath("data") .. "/first-run.json", result)
    vim.g.windvim_installing = false
    closed = true
    vim.api.nvim_del_augroup_by_id(group)
    clean_result()
    -- VimEnter already happened while downloading; do not replay user commands.
    vim.schedule(function()
      if vim.fn.argc(-1) == 0 and vim.api.nvim_buf_get_name(0) == "" and not vim.bo.modified then
        if _G.Snacks and not Snacks.dashboard.status.opened then
          Snacks.dashboard()
        end
      elseif vim.api.nvim_buf_get_name(0) ~= "" then
        vim.api.nvim_exec_autocmds("BufReadPost", { buffer = 0, modeline = false })
        vim.cmd("filetype detect")
      end
    end)
  end

  run = function()
    if closed or job then
      return
    end
    failed = false
    attempt = attempt + 1
    clean_result()
    append({ "", ("=== WindVim install attempt %d · %s ==="):format(attempt, os.date("%Y-%m-%d %H:%M:%S")) })
    screen.update({ message = "正在准备 WindVim", attempt = attempt, failed = {} })
    -- Job callbacks may split a single line between several chunks.
    local streams = { stdout = "", stderr = "" }
    local function receive(stream, lines)
      if closed then
        return
      end
      lines[1] = streams[stream] .. lines[1]
      streams[stream] = table.remove(lines)
      if #lines > 0 then
        append(lines)
      end
    end
    job = vim.fn.jobstart({
      vim.v.progpath,
      "--headless",
      "-u",
      "NONE",
      "-i",
      "NONE",
      "-n",
      "-l",
      vim.fn.stdpath("config") .. "/lua/windvim/install_worker.lua",
      result_path,
    }, {
      on_stdout = function(_, lines)
        receive("stdout", lines)
      end,
      on_stderr = function(_, lines)
        receive("stderr", lines)
      end,
      on_exit = function(_, code)
        job = nil
        if closed then
          return
        end
        for _, line in pairs(streams) do
          if line ~= "" then
            append({ line })
          end
        end
        local result = state.read(result_path)
        if not result then
          local bootstrap_log = vim.fn.stdpath("state") .. "/bootstrap.log"
          local lines = vim.fn.filereadable(bootstrap_log) == 1 and vim.fn.readfile(bootstrap_log) or {}
          result = { ok = false, failed = { lines[2] or ("安装进程退出：" .. code .. "，按 l 查看日志") } }
        end
        for _, error in ipairs(result and result.failed or {}) do
          append(vim.split(error, "\n", { plain = true }))
        end
        if code == 0 and result and result.ok then
          finish(result)
        elseif attempt < 3 then
          screen.update({
            message = "部分下载未完成，正在自动重试…",
            attempt = attempt,
            failed = result and result.failed or {},
          })
          vim.defer_fn(run, 1000)
        else
          failed = true
          screen.update({
            message = "安装未完成，请检查网络后按 r 重试",
            stopped = true,
            attempt = attempt,
            failed = result and result.failed or { "下载进程未完成，详情见日志" },
          })
        end
      end,
    })
    if job <= 0 then
      job, failed = nil, true
      screen.update({
        message = "无法启动安装进程，按 r 重试",
        stopped = true,
        failed = { "Neovim jobstart failed" },
      })
    end
  end

  local function begin()
    screen.open(log, function()
      if failed then
        attempt = 0
        run()
      end
    end)
    -- Flush the first colored frame before the child starts network work.
    vim.defer_fn(run, 80)
    screen.on_tick = function()
      if job then
        local progress = state.read(result_path .. ".progress")
        if progress then
          progress.message = progress.total > 0 and "正在自动安装插件" or "正在准备 WindVim"
          progress.attempt = attempt
          screen.update(progress)
        end
      end
    end
  end
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      closed = true
      screen.close()
      if job then
        vim.fn.jobstop(job)
      end
      clean_result()
    end,
  })
  if vim.v.vim_did_enter == 1 then
    vim.schedule(begin)
  else
    vim.api.nvim_create_autocmd("VimEnter", { group = group, once = true, callback = begin })
  end
  return true
end

return M
