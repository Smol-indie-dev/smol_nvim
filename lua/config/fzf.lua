-- fzf-lua defaults both to rounded and ignores winborder; frames here are square.
require("fzf-lua").setup({
  winopts = { border = "single", preview = { border = "single" } },
  -- fzf draws its list in its own 256 colours (a red pointer, green matches) unless told
  -- to take them from fzf-lua's groups, which follow the colour scheme.
  fzf_colors = true,
})

local map = vim.keymap.set
local fzf = require("fzf-lua")
local root = require("smol.root")

-- A picker over files opens in the buffer's project, not in nvim's cwd. For
-- oldfiles, fzf-lua takes a `cwd` to also mean `cwd_only`: the project's recent files.
local function in_project(picker)
  return function()
    fzf[picker]({ cwd = root.get(0) })
  end
end

map("n", "<leader>ff", in_project("files"), { desc = "Find files" })
map("n", "<leader>fg", in_project("live_grep"), { desc = "Grep" })
map("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })
map("n", "<leader>fh", fzf.help_tags, { desc = "Help tags" })
map("n", "<leader>fr", in_project("oldfiles"), { desc = "Recent files" })
