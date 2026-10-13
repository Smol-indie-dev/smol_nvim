-- Startup in test mode is clean: no errors, and every lua/config module loaded.

local messages = vim.api.nvim_exec2("messages", { output = true }).output
for line in messages:gmatch("[^\n]+") do
  assert(not line:match("E%d+:") and not line:match("Error"), "startup message: " .. line)
end

assert(vim.v.errmsg == "", "v:errmsg: " .. vim.v.errmsg)

local dir = vim.fn.stdpath("config") .. "/lua/config"
for _, path in ipairs(vim.fn.glob(dir .. "/*.lua", false, true)) do
  local module = "config." .. vim.fn.fnamemodify(path, ":t:r")
  assert(package.loaded[module], module .. " not loaded")
end
