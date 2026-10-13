-- Below 0.12 (vim.pack, vim.lsp.config, blink.cmp v2) nothing here works: say so in one
-- line and load nothing.
if vim.fn.has("nvim-0.12") == 0 then
  local v = vim.version()
  vim.api.nvim_echo({
    {
      string.format(
        "This config needs Neovim 0.12 or newer; this is %d.%d.%d. Nothing of it was loaded.",
        v.major,
        v.minor,
        v.patch
      ),
      "WarningMsg",
    },
  }, true, {})
  return
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")

-- Build blink.cmp's Rust fuzzy matcher from source on install/update, when cargo is
-- there; without it blink uses its Lua matcher, and :checkhealth smol says so.
-- If the build cannot run, warn rather than throw: an error here aborts the whole
-- PackChanged callback.
local function build_matcher()
  local ok, err = pcall(function()
    require("blink.cmp").build({ force = true }):pwait()
  end)
  if not ok then
    vim.notify("blink.cmp matcher build skipped: " .. tostring(err), vim.log.levels.WARN)
  end
end

-- Set by an "install": vim.pack.add installs in parallel and fires PackChanged per
-- plugin, before loading it, so blink.lib may not be on disk yet. A failed require
-- would also leave blink.cmp unloadable for the session (LuaJIT keeps the failed
-- module's sentinel), and completion.lua with it. The build runs after vim.pack.add.
local build_after_add = false

-- Must be registered before vim.pack.add.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "blink.cmp" and (ev.data.kind == "install" or ev.data.kind == "update") then
      -- No cargo, no build: one warning, and completion.lua falls back to blink's Lua
      -- matcher (blink's own build would report the failed `cargo build` as an error).
      if vim.fn.executable("cargo") ~= 1 then
        vim.notify(
          "blink.cmp: cargo not found, the Rust fuzzy matcher is not built; completion uses the Lua one",
          vim.log.levels.WARN
        )
      elseif ev.data.active then
        build_matcher()
      else
        build_after_add = true
      end
    end
  end,
})

local plugins = {
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/saghen/blink.lib",
  "https://github.com/saghen/blink.cmp",
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/sindrets/diffview.nvim",
  "https://github.com/NeogitOrg/neogit",
  "https://github.com/nvim-mini/mini.icons",
  "https://github.com/folke/snacks.nvim",
}

if vim.env.NVIM_SMOL_TEST == "1" then
  -- Test mode (tests/run): never call vim.pack, whose lock sync installs, removes and
  -- re-pins plugins. Load them from the real site dir, which tests/run passes as
  -- NVIM_SMOL_SITE, and never write there.
  vim.opt.packpath:prepend(vim.env.NVIM_SMOL_SITE)
  vim.opt.runtimepath:prepend(vim.env.NVIM_SMOL_SITE)
  for _, plugin in ipairs(plugins) do
    local src = type(plugin) == "table" and plugin.src or plugin
    vim.cmd.packadd(src:match("[^/]+$"))
  end
else
  vim.pack.add(plugins)
  if build_after_add then
    build_matcher()
  end
end

vim.cmd.colorscheme("smol")
require("config.statusline")

require("config.icons")

require("config.completion")
require("config.lsp")
require("config.treesitter")
require("config.fzf")
require("config.gitsigns")
require("config.notes")
require("config.formatting")
require("config.git")
require("config.snacks")
-- Last: ␣? lists the maps the files above set.
require("config.keys")
