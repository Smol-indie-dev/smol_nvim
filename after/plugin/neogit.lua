-- :Neogit in the buffer's project, as ␣gg in config/git.lua: neogit's own command opens
-- nvim's cwd, so from ~ (the dash's `e`) it asks to init a repo there.
-- Here and not in config/git.lua: at startup vim.pack.add loads like `packadd!`, so
-- neogit's plugin/neogit.lua, which defines the command, runs after init.lua.
-- after/plugin runs even when init.lua's 0.12 guard returned: nothing loads there either.
if vim.fn.has("nvim-0.12") == 0 then
  return
end
local neogit = require("neogit")

vim.api.nvim_create_user_command("Neogit", function(o)
  local opts = require("neogit.lib.util").parse_command_args(o.fargs)
  opts.cwd = opts.cwd or require("smol.root").get(0)
  neogit.open(opts)
end, {
  nargs = "*",
  desc = "Open Neogit in the buffer's project",
  complete = neogit.complete,
})
