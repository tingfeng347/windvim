-- Avante's Copilot provider reads the credential files created by
-- `:Copilot auth`.  Do not load Avante until that one-time login exists:
-- otherwise its startup configuration raises an error before LazyVim opens.
local config_home = vim.env.XDG_CONFIG_HOME
if not config_home or config_home == "" then config_home = vim.fn.expand("~/.config") end

local copilot_config = config_home .. "/github-copilot"
local function copilot_is_authenticated()
  return vim.uv.fs_stat(copilot_config .. "/hosts.json") ~= nil
    or vim.uv.fs_stat(copilot_config .. "/apps.json") ~= nil
end

return {
  {
    "yetone/avante.nvim",
    enabled = copilot_is_authenticated,
  },
}
