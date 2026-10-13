-- The start screen speaks smo's voice: lower-case labels, no cheat sheet, bold keys
-- with plain descriptions, the header in the accent, and icons from lua/smol/glyphs.lua.
-- Opens Snacks.dashboard headless and reads its buffer and extmarks.

local glyphs = require("smol.glyphs")
local palette = require("smol.palette")

vim.o.columns, vim.o.lines = 170, 50
Snacks.dashboard.open()
local buf = vim.api.nvim_get_current_buf()
assert(vim.bo[buf].filetype == "snacks_dashboard", "dashboard did not open: " .. vim.bo[buf].filetype)
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

-- Each highlighted span on the screen, by group.
local spans = {}
local ns = vim.api.nvim_get_namespaces().snacks_dashboard
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
  local row, col, d = mark[2], mark[3], mark[4]
  if d.hl_group and d.end_row == row then
    local text = lines[row + 1]:sub(col + 1, d.end_col)
    spans[d.hl_group] = spans[d.hl_group] or {}
    table.insert(spans[d.hl_group], vim.trim(text))
  end
end
for _, group in ipairs({ "SnacksDashboardKey", "SnacksDashboardDesc", "SnacksDashboardHeader" }) do
  assert(spans[group] and #spans[group] > 0, "no text drawn in " .. group)
end

-- 1. Every description is lower case.
for _, desc in ipairs(spans.SnacksDashboardDesc) do
  assert(desc == desc:lower(), "description not lower case: " .. desc)
end
local descs = table.concat(spans.SnacksDashboardDesc, "|")
for _, want in ipairs({
  "find file",
  "explorer",
  "new file",
  "find text",
  "recent files",
  "git",
  "config",
  "update plugins",
  "quit",
}) do
  assert(vim.tbl_contains(spans.SnacksDashboardDesc, want), "no key labelled " .. want .. " in " .. descs)
end

-- 2. No cheat sheet (smol, in a live look: too full): only the nine start keys, no title.
assert(#spans.SnacksDashboardKey == 9, "keys drawn: " .. table.concat(spans.SnacksDashboardKey, " "))
assert(not spans.SnacksDashboardTitle, "a title is drawn: " .. vim.inspect(spans.SnacksDashboardTitle))

-- 3. Keys bold, descriptions plain, the header in the accent.
local function hl(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end
assert(hl("SnacksDashboardKey").bold, "SnacksDashboardKey is not bold")
assert(not hl("SnacksDashboardDesc").bold, "SnacksDashboardDesc is bold")
assert(hl("SnacksDashboardDesc").fg == hl("Normal").fg, "SnacksDashboardDesc is not Normal's colour")
local header = hl("SnacksDashboardHeader").fg
assert(header and string.format("#%06x", header) == palette.accent, "header fg: " .. tostring(header))

-- 4. Each key's row shows its glyph from the table; Neogit's is smo's branch.
local rows = {
  ["find file"] = glyphs.search,
  explorer = glyphs.folder,
  ["new file"] = glyphs.file,
  ["find text"] = glyphs.text,
  ["recent files"] = glyphs.recent,
  git = glyphs.branch,
  config = glyphs.config,
  ["update plugins"] = glyphs.update,
  quit = glyphs.quit,
}
for desc, glyph in pairs(rows) do
  local found = false
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if vim.startswith(trimmed, glyph .. " ") and vim.endswith(trimmed, " " .. desc) then
      found = true
    end
  end
  assert(found, string.format("no row %q with glyph U+%04X", desc, vim.fn.char2nr(glyph)))
end

-- 5. No inline codes left in snacks.lua.
local path = vim.fn.stdpath("config") .. "/lua/config/snacks.lua"
local source = table.concat(vim.fn.readfile(path), "\n")
assert(not source:find("\\u{", 1, true), "snacks.lua still has an inline \\u{...}")
