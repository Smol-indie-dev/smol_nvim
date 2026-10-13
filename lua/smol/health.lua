-- :checkhealth smol: what this config needs from the system.
-- A needed tool missing is an error; an optional one a warning with its Arch package.
-- The formatters are read from formatting.lua; tests/health.lua keeps the servers equal
-- to what lsp.lua enables, and `packages` equal to both.

local M = {}

-- Arch packages of the optional tools. (AUR) marks a package not in the official repos.
M.packages = {
  cargo = "rustup",
  -- Servers (lsp.lua)
  ["rust-analyzer"] = "rust-analyzer",
  ["lua-language-server"] = "lua-language-server",
  vtsls = "vtsls (AUR)",
  ["vscode-html-language-server"] = "vscode-langservers-extracted (AUR)",
  ["vscode-css-language-server"] = "vscode-langservers-extracted (AUR)",
  ["vscode-json-language-server"] = "vscode-langservers-extracted (AUR)",
  ["astro-ls"] = "no package: npm's @astrojs/language-server",
  -- Formatters (formatting.lua)
  rustfmt = "rustup",
  biome = "biome",
  prettierd = "prettierd (AUR)",
  yamlfmt = "yamlfmt",
  taplo = "taplo-cli",
  stylua = "stylua",
  shfmt = "shfmt",
}

local TREE_SITTER = "0.26.1"

-- The servers lsp.lua enables and their commands. lspconfig's `cmd` is a function for
-- some (html, cssls, jsonls, astro), so the command cannot be read from the config;
-- tests/health.lua keeps this table equal to the enabled configs.
M.servers = {
  rust_analyzer = "rust-analyzer",
  lua_ls = "lua-language-server",
  vtsls = "vtsls",
  html = "vscode-html-language-server",
  cssls = "vscode-css-language-server",
  jsonls = "vscode-json-language-server",
  astro = "astro-ls",
}

-- The formatters formatting.lua names. Its entries are functions of the buffer (none
-- under the notes path), asked here about a scratch buffer.
function M.formatters()
  local formatters = {}
  local buf = vim.api.nvim_create_buf(false, true)
  for _, names in pairs(require("conform").formatters_by_ft) do
    if type(names) == "function" then
      names = names(buf)
    end
    for _, name in ipairs(names) do
      formatters[name] = true
    end
  end
  vim.api.nvim_buf_delete(buf, { force = true })
  return formatters
end

local function have(tool)
  return vim.fn.executable(tool) == 1
end

local function needed(tool, package, why)
  if have(tool) then
    vim.health.ok(tool)
  else
    vim.health.error(tool .. " not found (" .. why .. ")", "Install " .. package)
  end
end

local function optional(tool, why)
  if have(tool) then
    vim.health.ok(tool)
  else
    vim.health.warn(tool .. " not found (" .. why .. ")", "Install " .. M.packages[tool])
  end
end

local function sorted(set)
  local list = vim.tbl_keys(set)
  table.sort(list)
  return list
end

local function tree_sitter()
  if not have("tree-sitter") then
    vim.health.error("tree-sitter not found (nvim-treesitter builds the parsers with it)", "Install tree-sitter-cli")
    return
  end
  local out = vim.system({ "tree-sitter", "--version" }, { text = true }):wait().stdout or ""
  local version = vim.version.parse(out:match("%d+%.%d+%.%d+") or "")
  if version and vim.version.ge(version, TREE_SITTER) then
    vim.health.ok("tree-sitter " .. tostring(version))
  else
    vim.health.error(
      "tree-sitter "
        .. (version and tostring(version) or "of unknown version")
        .. ", "
        .. TREE_SITTER
        .. " or newer needed",
      "Install tree-sitter-cli"
    )
  end
end

function M.check()
  vim.health.start("Neovim")
  vim.health.ok("Neovim " .. tostring(vim.version()))

  vim.health.start("Needed")
  needed("git", "git", "vim.pack installs the plugins with it")
  needed("rg", "ripgrep", "fzf-lua's text search")
  needed("fd", "fd", "fzf-lua's file search")
  needed("fzf", "fzf", "fzf-lua's pickers")
  if have("cc") or have("gcc") or have("clang") then
    vim.health.ok("a C compiler")
  else
    vim.health.error("no C compiler (cc, gcc or clang; tree-sitter compiles the parsers)", "Install gcc")
  end
  tree_sitter()

  vim.health.start("Optional")
  optional("cargo", "builds blink.cmp's Rust fuzzy matcher")
  local ok, cmp = pcall(require, "blink.cmp")
  if ok and cmp.library_available() then
    vim.health.ok("blink.cmp's Rust matcher is built")
  else
    vim.health.warn(
      "blink.cmp's Rust matcher is not built: completion uses the Lua one",
      "With cargo installed: :lua require('blink.cmp').build({ force = true }):wait(), then restart"
    )
  end
  for _, name in ipairs(sorted(M.servers)) do
    optional(M.servers[name], "the language server " .. name)
  end
  for _, tool in ipairs(sorted(M.formatters())) do
    optional(tool, "a formatter formatting.lua names")
  end
end

return M
