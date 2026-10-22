-- Observe only explicitly registered Lua modules, without loading them early.
local M = {}
local targets, undo = {}, {}
local searcher

function M.wrap(module, key, make, fallback)
  local original = module[key] or fallback
  local own = rawget(module, key)
  assert(type(original) == "function", "i18n: unsupported adapter method " .. key)
  local wrapper = make(original)
  module[key] = wrapper
  undo[#undo + 1] = function()
    if module[key] == wrapper then
      module[key] = own
    end
  end
end

function M.watch(name, callback)
  if package.loaded[name] then
    callback(package.loaded[name])
  else
    targets[name] = callback
  end
end

function M.start()
  searcher = function(name)
    if not targets[name] then
      return
    end
    local after = false
    for _, loader_searcher in ipairs(package.loaders) do
      if loader_searcher == searcher then
        after = true
      elseif after then
        local loader, path = loader_searcher(name)
        if type(loader) == "function" then
          return function(...)
            local module = loader(...)
            local callback = targets[name]
            targets[name] = nil
            callback(module or package.loaded[name])
            return module
          end,
            path
        end
      end
    end
  end
  table.insert(package.loaders, 1, searcher)
end

function M.stop()
  for i = #undo, 1, -1 do
    undo[i]()
  end
  for i, loader in ipairs(package.loaders) do
    if loader == searcher then
      table.remove(package.loaders, i)
      break
    end
  end
  targets, undo = {}, {}
  searcher = nil
end

return M
