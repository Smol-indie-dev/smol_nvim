-- Start screen and file explorer from snacks.nvim, the same modules LazyVim used, so
-- `nvim` with no file opens the dashboard and <leader>e toggles the sidebar explorer.
-- Only these two modules are enabled; picking stays on fzf-lua (the dashboard's
-- default picker auto-detects it).
-- In smo's voice: lower-case labels, a `keys` heading, icons
-- from lua/smol/glyphs.lua; the colours are in colors/smol.lua.

local glyphs = require("smol.glyphs")

local header = [[
███████╗███╗   ███╗ ██████╗ ██╗     
██╔════╝████╗ ████║██╔═══██╗██║     
███████╗██╔████╔██║██║   ██║██║     
╚════██║██║╚██╔╝██║██║   ██║██║     
███████║██║ ╚═╝ ██║╚██████╔╝███████╗
╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚══════╝

██╗███╗   ██╗██████╗ ██╗███████╗  ██████╗ ███████╗██╗   ██╗
██║████╗  ██║██╔══██╗██║██╔════╝  ██╔══██╗██╔════╝██║   ██║
██║██╔██╗ ██║██║  ██║██║█████╗    ██║  ██║█████╗  ██║   ██║
██║██║╚██╗██║██║  ██║██║██╔══╝    ██║  ██║██╔══╝  ╚██╗ ██╔╝
██║██║ ╚████║██████╔╝██║███████╗  ██████╔╝███████╗ ╚████╔╝ 
╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝╚══════╝  ╚═════╝ ╚══════╝  ╚═══╝  
]]

-- One centred column of start keys under the header, smol's pick in a live look: two
-- panes left the header off centre (snacks centres it over the first pane only), and the
-- cheat sheet made the screen too full. Each row is a glyph from lua/smol/glyphs.lua, the
-- key in bold, then what it does, as in smo's key help; every row has the same width, so
-- centring keeps the columns.
local width = { icon = 3, key = 4, desc = 16 }

local function start(glyph, key, desc, action)
  return {
    key = key,
    action = action,
    align = "center",
    text = {
      { glyphs[glyph], hl = "icon", width = width.icon },
      { key, hl = "key", width = width.key },
      { desc, hl = "desc", width = width.desc },
    },
  }
end

require("snacks").setup({
  dashboard = {
    enabled = true,
    preset = { header = header },
    sections = {
      { section = "header" },
      {
        gap = 1,
        padding = 1,
        start("search", "f", "find file", ":lua Snacks.dashboard.pick('files')"),
        start("folder", "e", "explorer", ":lua Snacks.explorer()"),
        start("file", "n", "new file", ":ene | startinsert"),
        start("text", "g", "find text", ":lua Snacks.dashboard.pick('live_grep')"),
        start("recent", "r", "recent files", ":lua Snacks.dashboard.pick('oldfiles')"),
        start("branch", "G", "git", ":lua require('neogit').open()"),
        start("config", "c", "config", ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})"),
        start("update", "u", "update plugins", ":lua vim.pack.update()"),
        start("quit", "q", "quit", ":qa"),
      },
    },
  },
  explorer = { enabled = true },
})

-- The explorer opens at the buffer's project, like the pickers.
vim.keymap.set("n", "<leader>e", function()
  Snacks.explorer({ cwd = require("smol.root").get(0) })
end, { desc = "File explorer" })
