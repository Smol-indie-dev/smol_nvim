-- ␣? opens the keys float inside the editor (the start screen has no cheat sheet). Its
-- rows are read from the real keymaps, not from a hand-kept list: the config's own
-- normal-mode maps, the buffer's own maps with a description (gitsigns, LSP) and nvim's
-- LSP defaults, then the config's visual-mode maps, each with its description in lower
-- case.

local keys = require("config.keys")

vim.o.columns, vim.o.lines = 170, 50

-- A buffer in this repo, with buffer-local maps like the ones gitsigns and LSP set.
vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
local file = vim.api.nvim_get_current_buf()
vim.keymap.set("n", "]x", "<Nop>", { buffer = file, desc = "Next thing" })
vim.keymap.set("n", "K", "<Nop>", { buffer = file, desc = "vim.lsp.buf.hover()" })
vim.keymap.set("n", "zq", "<Nop>", { buffer = file }) -- no description: not shown
vim.keymap.set("n", "<leader>fh", "<Nop>", { buffer = file, desc = "Help here" }) -- wins over the global ␣fh

-- 1. ␣? is mapped and opens the float.
local map = vim.fn.maparg("<leader>?", "n", false, true)
assert(map.desc == "Keys", "␣? desc: " .. vim.inspect(map.desc))
map.callback()
local win = vim.api.nvim_get_current_win()
local cfg = vim.api.nvim_win_get_config(win)
assert(cfg.relative ~= "", "␣? did not open a float")
local buf = vim.api.nvim_win_get_buf(win)
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local text = table.concat(lines, "\n")

-- The rows the float draws, as { key, desc }.
local rows = keys.rows(file)
local function row(key, desc)
  for _, r in ipairs(rows) do
    if r[1] == key and r[2]:find(desc, 1, true) then
      return true
    end
  end
  return false
end
local function shown(key)
  for _, r in ipairs(rows) do
    if r[1] == key then
      return true
    end
  end
  return false
end
for _, r in ipairs(rows) do
  assert(text:find(vim.pesc(r[1]) .. "%s+" .. vim.pesc(r[2])), "row not drawn: " .. r[1] .. " " .. r[2] .. "\n" .. text)
end

-- 2. Every one of the config's own normal-mode leader maps, leader drawn as ␣, label lower case.
local own = 0
for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
  if m.lhs:sub(1, 1) == " " and m.desc then
    own = own + 1
    local key = "␣ " .. m.lhs:sub(2)
    local desc = m.lhs == " fh" and "help here" or m.desc:lower()
    assert(row(key, desc), "missing row " .. key .. " " .. desc .. " in:\n" .. text)
  end
end
assert(own >= 12, "only " .. own .. " leader maps")
for _, want in ipairs({ { "␣ ff", "find files" }, { "␣ gg", "neogit status" }, { "<C-H>", "move focus" } }) do
  assert(row(want[1], want[2]), "missing row " .. want[1] .. " in:\n" .. text)
end

-- 3. The buffer's own maps with a description; nvim's LSP maps by what they do.
assert(row("]x", "next thing"), "buffer-local ]x not shown:\n" .. text)
assert(row("K", "hover"), "K not shown as hover:\n" .. text)
assert(row("grr", "references"), "grr not shown as references:\n" .. text)
assert(row("gra", "code action"), "gra not shown as code action:\n" .. text)
assert(not text:find("vim%.lsp"), "raw vim.lsp desc shown:\n" .. text)
assert(not shown("zq"), "a map without a description is shown")

-- 4. nvim's other defaults stay out: they are not the keys used most.
for _, lhs in ipairs({ "gcc", "[q", "]b", "gx", "<C-W>d", "Y" }) do
  assert(not shown(lhs), lhs .. " shown")
end

-- 5. Every label is lower case.
for _, r in ipairs(rows) do
  assert(r[2] == r[2]:lower(), "label not lower case: " .. r[2])
end

-- 6. The frame: square, titled `keys`, keys in bold.
assert(cfg.border[1] == "┌", "border: " .. vim.inspect(cfg.border))
assert(cfg.title and cfg.title[1][1]:find("keys"), "title: " .. vim.inspect(cfg.title))
local bold = false
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
  if mark[4].hl_group == "SmolKey" then
    bold = true
  end
end
assert(bold, "no SmolKey highlight in the float")
assert(vim.api.nvim_get_hl(0, { name = "SmolKey", link = false }).bold, "SmolKey not bold")

-- 7. Read when opened, not kept: a new map shows up the next time.
vim.cmd.close()
assert(vim.api.nvim_get_current_buf() == file, "q/close did not return to the file")
vim.keymap.set("n", "<leader>zz", "<Nop>", { desc = "Brand new" })
keys.open()
text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(text:find("brand new"), "a map set later is not shown:\n" .. text)

-- 8. The config's visual-mode maps, after the normal ones, the key marked `v`.
assert(row("v J", "move selection down"), "visual J not shown:\n" .. text)
assert(row("v K", "move selection up"), "visual K not shown:\n" .. text)
local first_visual
for i, r in ipairs(rows) do
  if r[1]:find("^v ") then
    first_visual = first_visual or i
  else
    assert(not first_visual, "a normal row after the visual ones: " .. r[1])
  end
end
-- nvim's own visual defaults stay out.
for _, lhs in ipairs({ "v gc", "v *", "v #", "v gx" }) do
  assert(not shown(lhs), lhs .. " shown")
end

-- 9. q closes it.
local float = vim.api.nvim_get_current_win()
vim.api.nvim_feedkeys("q", "x", false)
assert(not vim.api.nvim_win_is_valid(float), "q did not close the float")
