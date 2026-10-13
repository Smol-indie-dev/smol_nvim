local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.termguicolors = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.breakindent = true
opt.wrap = false

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"

opt.signcolumn = "yes"
opt.cursorline = true
-- The statusline says the mode; no `-- INSERT --` under it.
opt.showmode = false
opt.scrolloff = 8
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Square frames, like smo's TUI.
opt.winborder = "single"

opt.splitright = true
opt.splitbelow = true

opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.confirm = true

opt.updatetime = 250
opt.timeoutlen = 300
