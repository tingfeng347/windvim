-- Run with: nvim --clean --headless -i NONE -l scripts/check.lua
local files = vim.fn.glob("**/*.lua", false, true)
local count = 0
for _, path in ipairs(files) do
  if not path:match("^%.tests/") then
    assert(loadfile(path))
    count = count + 1
  end
end
for _, path in ipairs({ "lazy-lock.json", "lazyvim.json", ".neoconf.json" }) do
  vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
end
print(("PASS: %d Lua files and 3 JSON files"):format(count))
