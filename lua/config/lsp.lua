vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      -- nvim runs LuaJIT, where `unpack` is not deprecated; snacks and mini.icons set
      -- their globals on setup.
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim", "Snacks", "MiniIcons" } },
      workspace = { checkThirdParty = false },
    },
  },
})

-- vtsls covers ts/tsx/js/jsx; html/cssls/jsonls come from
-- vscode-langservers-extracted (AUR). astro-language-server has no
-- pacman/AUR package or cargo/go equivalent — the one deliberate npm
-- exception, installed in its own directory under
-- ~/.local/share/astro-language-server, `astro-ls` symlinked onto PATH
-- via ~/.local/bin rather than a per-project node_modules install.
vim.lsp.enable({
  "rust_analyzer",
  "lua_ls",
  "vtsls",
  "html",
  "cssls",
  "jsonls",
  "astro",
})

-- The signs are smo's marks: an error is its failed mark, a warning its warning mark
-- (lua/smol/glyphs.lua).
local glyphs = require("smol.glyphs")
local severity = vim.diagnostic.severity

vim.diagnostic.config({
  virtual_text = true,
  signs = {
    text = {
      [severity.ERROR] = glyphs.failed,
      [severity.WARN] = glyphs.warning,
      [severity.INFO] = glyphs.info,
      [severity.HINT] = glyphs.hint,
    },
  },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
