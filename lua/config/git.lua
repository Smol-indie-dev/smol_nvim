local palette = require("smol.palette")
local blend = require("smol.blend").named

require("neogit").setup({
  -- Neogit mixes its groups from a palette of its own, read from a few syntax groups,
  -- a hard-coded white and a grey bg when Normal has none (as here): it gets smol's.
  highlight = {
    bg0 = palette.bg,
    bg1 = blend.bg1,
    bg2 = blend.bg2,
    bg3 = blend.bg3,
    grey = palette.dim,
    white = palette.fg,
    red = palette.error,
    orange = palette.warn,
    yellow = palette.warn,
    green = palette.ok,
    cyan = palette.info,
    blue = palette.net,
    purple = palette.accent_soft,
    line_red = blend.diff_delete,
    line_green = blend.diff_add,
  },
  integrations = {
    diffview = true,
    fzf_lua = true,
  },
  -- Neogit hard-codes rounded floats; frames here are square.
  floating = { border = "single" },
})

-- In the buffer's project, not nvim's cwd; :Neogit too, in after/plugin/neogit.lua.
local root = require("smol.root")
local map = vim.keymap.set
map("n", "<leader>gg", function()
  require("neogit").open({ cwd = root.get(0) })
end, { desc = "Neogit status" })
map("n", "<leader>gl", function()
  require("neogit").open({ "log", cwd = root.get(0) })
end, { desc = "Neogit log" })
map("n", "<leader>gd", "<cmd>DiffviewOpen<CR>", { desc = "Diffview open" })
map("n", "<leader>gc", "<cmd>DiffviewClose<CR>", { desc = "Diffview close" })
