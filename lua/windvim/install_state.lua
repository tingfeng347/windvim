-- On-disk protocol shared by the UI and the isolated installer process.
local M = { version = 1 }

function M.read(path)
  local ok, value = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  return ok and type(value) == "table" and value or nil
end

function M.write(path, value)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local tmp = path .. ".tmp-" .. vim.fn.getpid()
  vim.fn.writefile({ vim.json.encode(value) }, tmp)
  assert(vim.fn.rename(tmp, path) == 0, "Cannot save installation state: " .. path)
end

function M.ready()
  local value = M.read(vim.fn.stdpath("data") .. "/first-run.json")
  if not value or value.version ~= M.version or type(value.dirs) ~= "table" or #value.dirs == 0 then
    return false
  end
  if vim.fn.filereadable(vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy/init.lua") ~= 1 then
    return false
  end
  for _, dir in ipairs(value.dirs) do
    if type(dir) ~= "string" or vim.fn.isdirectory(dir) ~= 1 then
      return false
    end
  end
  return true
end

return M
