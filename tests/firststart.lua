-- A first start a newcomer can follow: the version guard, blink's matcher with a Lua
-- fallback, and the PackChanged hook without cargo or before blink.lib is on disk.

-- 1. Below 0.12 init.lua prints one line and loads nothing. A child nvim pretends to
-- be 0.11.2 from --cmd, before init.lua runs.
local record = vim.fn.tempname()
local pretend = string.format(
  [[
local has = vim.fn.has
vim.fn.has = function(feature)
  if feature == "nvim-0.12" then
    return 0
  end
  return has(feature)
end
vim.version = function()
  return { major = 0, minor = 11, patch = 2 }
end
_G.write_state = function()
  local loaded = {}
  for name in pairs(package.loaded) do
    if name:match("^config%%.") or name:match("^smol%%.") or name:match("^blink") then
      table.insert(loaded, name)
    end
  end
  vim.fn.writefile({
    vim.json.encode({
      messages = vim.api.nvim_exec2("messages", { output = true }).output,
      loaded = loaded,
      leader = vim.g.mapleader or vim.NIL,
      packed = vim.o.runtimepath:find("blink.cmp", 1, true) ~= nil,
    }),
  }, %q)
end
]],
  record
)
local result = vim.system({ "nvim", "--headless", "--cmd", "lua " .. pretend, "+lua write_state()", "+qall!" }):wait()
assert(result.code == 0, "child nvim exited " .. result.code .. ": " .. result.stderr)
local state = vim.json.decode(vim.fn.readfile(record)[1])
local lines = vim.split(vim.trim(state.messages), "\n")
assert(#lines == 1 and lines[1] ~= "", "the guard prints one line, got: " .. state.messages)
assert(lines[1]:find("0.12", 1, true), "the line says what is needed: " .. lines[1])
assert(lines[1]:find("0.11.2", 1, true), "the line says what is running: " .. lines[1])
assert(#state.loaded == 0, "loaded below 0.12: " .. table.concat(state.loaded, ", "))
assert(state.leader == vim.NIL, "init.lua went past the guard (mapleader set)")
assert(not state.packed, "a plugin was added below 0.12")

-- 2. blink falls back to the Lua matcher when Rust's is missing, without its own warning
-- on every start (smol's call: the hook's one warning and :checkhealth smol say it
-- instead).
local implementation = require("blink.cmp.config").fuzzy.implementation
assert(implementation == "prefer_rust", "fuzzy.implementation is " .. tostring(implementation))

-- 3. The PackChanged hook builds the matcher only when cargo is executable, and says
-- so in one warning when it is not.
local cmp = require("blink.cmp")
local real_build, real_notify, real_path = cmp.build, vim.notify, vim.env.PATH
local builds, notes = 0, {}
cmp.build = function()
  builds = builds + 1
  return { pwait = function() end }
end
vim.notify = function(msg, level)
  table.insert(notes, { msg = msg, level = level })
end

local function fire(path)
  builds, notes = 0, {}
  vim.env.PATH = path
  vim.api.nvim_exec_autocmds("PackChanged", {
    data = { spec = { name = "blink.cmp" }, kind = "install", active = true, path = "" },
  })
end

local ok, err = pcall(function()
  local empty = vim.fn.tempname()
  vim.fn.mkdir(empty, "p")
  fire(empty)
  assert(builds == 0, "built without cargo")
  assert(#notes == 1, "warnings without cargo: " .. #notes)
  assert(notes[1].level == vim.log.levels.WARN, "not a warning: " .. vim.inspect(notes[1]))
  assert(notes[1].msg:find("cargo", 1, true), "the warning names cargo: " .. notes[1].msg)

  -- Control: with a cargo on PATH the hook builds and stays quiet.
  local bin = vim.fn.tempname()
  vim.fn.mkdir(bin, "p")
  vim.fn.writefile({ "#!/bin/sh" }, bin .. "/cargo")
  vim.fn.setfperm(bin .. "/cargo", "rwxr-xr-x")
  fire(bin)
  assert(builds == 1, "builds with cargo: " .. builds)
  assert(#notes == 0, "notified with cargo: " .. vim.inspect(notes))
end)
cmp.build, vim.notify, vim.env.PATH = real_build, real_notify, real_path
assert(ok, err)

-- 4. On a first start vim.pack installs in parallel and fires PackChanged per plugin:
-- blink.cmp's "install" can come before blink.lib is on disk. The build waits until
-- vim.pack.add has returned. A child nvim's vim.pack.add fires the event while no plugin
-- can be found, then adds them all; the build is recorded, never run.
local race = vim.fn.tempname()
local stubs = string.format(
  [[
vim.pack = {
  add = function(specs)
    vim.api.nvim_exec_autocmds("PackChanged", {
      data = { spec = { name = "blink.cmp" }, kind = "install", active = false, path = "" },
    })
    vim.opt.packpath:prepend(vim.env.NVIM_SMOL_SITE)
    vim.opt.runtimepath:prepend(vim.env.NVIM_SMOL_SITE)
    for _, spec in ipairs(specs) do
      local src = type(spec) == "table" and spec.src or spec
      vim.cmd.packadd(src:match("[^/]+$"))
    end
    _G.builds = 0
    require("blink.cmp").build = function()
      _G.builds = _G.builds + 1
      return { pwait = function() end }
    end
  end,
}
package.loaded["nvim-treesitter"] = { install = function() end }
_G.write_race = function()
  vim.fn.writefile({
    vim.json.encode({
      messages = vim.api.nvim_exec2("messages", { output = true }).output,
      builds = _G.builds or 0,
      completion = package.loaded["config.completion"] ~= nil,
    }),
  }, %q)
end
]],
  race
)
local bin = vim.fn.tempname()
vim.fn.mkdir(bin, "p")
vim.fn.writefile({ "#!/bin/sh" }, bin .. "/cargo")
vim.fn.setfperm(bin .. "/cargo", "rwxr-xr-x")
-- Not test mode, so that init.lua calls the vim.pack.add stub; the plugins it adds come
-- from the real site, read only.
result = vim
  .system({ "nvim", "--headless", "--cmd", "lua " .. stubs, "+lua write_race()", "+qall!" }, {
    env = { NVIM_SMOL_TEST = "", PATH = bin .. ":" .. vim.env.PATH },
  })
  :wait()
assert(result.code == 0, "child nvim exited " .. result.code .. ": " .. result.stderr)
state = vim.json.decode(vim.fn.readfile(race)[1])
assert(vim.trim(state.messages) == "", "first start messages: " .. state.messages)
assert(state.completion, "completion.lua did not load")
assert(state.builds == 1, "builds after vim.pack.add: " .. state.builds)
