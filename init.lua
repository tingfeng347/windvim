-- Draw WindVim before doing any network work on an interactive first launch.
if not require("windvim.first_run").start() then
  require("config.lazy")
end
