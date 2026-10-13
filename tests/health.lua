-- :checkhealth smol (lua/smol/health.lua): needed tools are errors, optional ones
-- warnings with their Arch package, and the optional lists are the ones lsp.lua and
-- formatting.lua use.

local health = require("smol.health")

-- 1. The servers are the configs lsp.lua enables (a table cmd's command checked too),
-- the formatters the names formatting.lua gives conform; each tool has a package, and
-- no package is left over.
local enabled = {}
for _, config in ipairs(vim.lsp.get_configs({ enabled = true })) do
  enabled[config.name] = true
  if type(config.cmd) == "table" then
    assert(health.servers[config.name] == config.cmd[1], config.name .. "'s command is " .. config.cmd[1])
  end
end
local servers = {}
for _, tool in pairs(health.servers) do
  servers[tool] = true
end
local formatters = {}
for _, names in pairs(require("conform").formatters_by_ft) do
  if type(names) == "function" then
    names = names(vim.api.nvim_create_buf(false, true))
  end
  for _, name in ipairs(names) do
    formatters[name] = true
  end
end
assert(next(enabled) and next(formatters), "no servers or formatters found")

local function keys(set)
  local list = vim.tbl_keys(set)
  table.sort(list)
  return table.concat(list, " ")
end
assert(keys(health.servers) == keys(enabled), "servers: " .. keys(health.servers) .. " vs " .. keys(enabled))
assert(
  keys(health.formatters()) == keys(formatters),
  "formatters: " .. keys(health.formatters()) .. " vs " .. keys(formatters)
)
local wanted = vim.tbl_extend("error", servers, formatters, { cargo = true })
for tool in pairs(wanted) do
  assert(health.packages[tool], "no package for " .. tool)
end
for tool in pairs(health.packages) do
  assert(wanted[tool], "package for a tool nothing uses: " .. tool)
end

-- 2. The report on a PATH of stubs. Every line of checkhealth's buffer for smol.
local real_path = vim.env.PATH
local function report(tools, tree_sitter_version)
  local bin = vim.fn.tempname()
  vim.fn.mkdir(bin, "p")
  for _, tool in ipairs(tools) do
    local body = tool == "tree-sitter" and ("echo 'tree-sitter " .. tree_sitter_version .. "'") or "exit 0"
    vim.fn.writefile({ "#!/bin/sh", body }, bin .. "/" .. tool)
    vim.fn.setfperm(bin .. "/" .. tool, "rwxr-xr-x")
  end
  -- /bin/sh itself stays reachable for the stubs through their shebang.
  vim.env.PATH = bin
  local ok, err = pcall(vim.cmd.checkhealth, "smol")
  vim.env.PATH = real_path
  assert(ok, err)
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  vim.cmd.bwipeout({ bang = true })
  return text
end

local function count(text, word)
  local n = 0
  for line in text:gmatch("[^\n]+") do
    if line:find(word, 1, true) then
      n = n + 1
    end
  end
  return n
end

local needed = { "git", "rg", "fd", "fzf", "cc", "tree-sitter" }
local everything = vim.list_extend(vim.deepcopy(needed), vim.tbl_keys(wanted))

local full = report(everything, "0.26.1")
assert(count(full, "ERROR") == 0, "errors with every tool:\n" .. full)
assert(full:find(tostring(vim.version()), 1, true), "the version is not shown:\n" .. full)
assert(full:find("matcher", 1, true), "the matcher's state is not shown:\n" .. full)

local bare = report({}, "")
assert(count(bare, "ERROR") == #needed, "errors with nothing on PATH (" .. #needed .. " wanted):\n" .. bare)
for _, tool in ipairs({ "git", "rg", "fd", "fzf", "tree-sitter" }) do
  assert(bare:find(tool, 1, true), tool .. " not named:\n" .. bare)
end
for tool in pairs(wanted) do
  assert(
    bare:find(tool, 1, true) and bare:find(health.packages[tool], 1, true),
    tool .. " or its package missing:\n" .. bare
  )
end
assert(count(bare, "WARNING") >= vim.tbl_count(wanted), "too few warnings:\n" .. bare)

local old = report(needed, "0.25.9")
assert(count(old, "ERROR") == 1 and old:find("0.26.1", 1, true), "an old tree-sitter is not an error:\n" .. old)

-- A clang alone is a C compiler too.
local clang = vim.deepcopy(needed)
clang[5] = "clang"
assert(count(report(clang, "0.26.1"), "ERROR") == 0, "clang is not taken as a C compiler")
