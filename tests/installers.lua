-- Test mode never calls the installers: a child nvim starts with stubs for
-- vim.pack.add and nvim-treesitter's install() that record every call.

local record = vim.fn.tempname()

-- Runs with --cmd, before init.lua. The vim.pack.add stub still packadds, so that the
-- control run below gets as far as treesitter.lua.
local stubs = string.format(
  [[
_G.calls = {}
vim.pack = {
  add = function(specs)
    table.insert(_G.calls, "vim.pack.add")
    vim.opt.packpath:prepend(vim.env.NVIM_SMOL_SITE)
    vim.opt.runtimepath:prepend(vim.env.NVIM_SMOL_SITE)
    for _, spec in ipairs(specs) do
      local src = type(spec) == "table" and spec.src or spec
      vim.cmd.packadd(src:match("[^/]+$"))
    end
  end,
}
package.loaded["nvim-treesitter"] = {
  install = function()
    table.insert(_G.calls, "nvim-treesitter.install")
  end,
}
_G.write_calls = function()
  vim.fn.writefile({ table.concat(_G.calls, ",") }, %q)
end
]],
  record
)

local function calls(test_mode)
  local env = { NVIM_SMOL_TEST = test_mode and "1" or "" }
  local result = vim
    .system({ "nvim", "--headless", "--cmd", "lua " .. stubs, "+lua write_calls()", "+qall!" }, { env = env })
    :wait()
  assert(result.code == 0, "child nvim exited " .. result.code .. ": " .. result.stderr)
  return vim.fn.readfile(record)[1]
end

-- Control: without test mode the stubs see both installers, so they do catch them.
assert(calls(false) == "vim.pack.add,nvim-treesitter.install", "control run: " .. calls(false))
assert(calls(true) == "", "test mode called: " .. calls(true))
