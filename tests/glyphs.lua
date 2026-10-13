-- One glyph table, smo's meanings.

local glyphs = require("smol.glyphs")

local function codepoint(s)
  return vim.fn.char2nr(s)
end

local function u(cp)
  return string.format("U+%04X", cp)
end

-- The Nerd Font entries are the table's strings; `phase` holds plain Unicode marks.
local nerd = {}
for name, value in pairs(glyphs) do
  if type(value) == "string" then
    nerd[name] = value
  else
    assert(name == "phase", "glyphs." .. name .. " is neither a glyph nor the phase marks")
  end
end

-- smo's meanings that nvim shows: they have to be here whatever else the table holds.
local shared = { "branch", "clean", "dirty", "failed", "warning", "idea", "fix", "plan", "todo", "log" }
local phases = { "done", "now", "todo", "dropped", "unknown" } -- glyph.rs's order
for _, name in ipairs(shared) do
  assert(nerd[name], "glyphs." .. name .. " is missing")
end
for _, name in ipairs(phases) do
  assert(type(glyphs.phase[name]) == "string", "glyphs.phase." .. name .. " is missing")
end
for _, name in ipairs({ "folder", "info", "hint" }) do
  assert(nerd[name], "glyphs." .. name .. " is missing")
end

-- 2. Every Nerd Font entry is one nf-fa codepoint (U+F000 to U+F2E0), one cell wide, as
-- glyph.rs's own test checks. Callers add the space; smo's strings carry it.
for name, glyph in pairs(nerd) do
  assert(vim.fn.strchars(glyph) == 1, "glyphs." .. name .. " is not a single character")
  local cp = codepoint(glyph)
  assert(cp >= 0xf000 and cp <= 0xf2e0, string.format("glyphs.%s is %s: not nf-fa", name, u(cp)))
  assert(vim.fn.strdisplaywidth(glyph) == 1, "glyphs." .. name .. " is not one cell wide")
end
for name, mark in pairs(glyphs.phase) do
  assert(vim.fn.strchars(mark) == 1, "glyphs.phase." .. name .. " is not a single character")
  assert(vim.fn.strdisplaywidth(mark) == 1, "glyphs.phase." .. name .. " is not one cell wide")
end

-- One glyph, one meaning, inside the table too.
local owner = {}
for name, glyph in pairs(nerd) do
  assert(
    not owner[glyph],
    string.format("glyphs.%s and glyphs.%s share %s", name, tostring(owner[glyph]), u(codepoint(glyph)))
  )
  owner[glyph] = name
end

-- The explorer's folder is not smo's worktree mark (U+F07C).
assert(codepoint(nerd.folder) == 0xf07b, "glyphs.folder is " .. u(codepoint(nerd.folder)) .. ", want U+F07B")

-- 1. Drift: every entry smo also has is smo's codepoint, and no nvim-only entry takes one
-- of smo's. Parsed from NERD in glyph.rs; skipped without smol_office.
local path = vim.env.HOME .. "/dev/smol_office/src/dash/glyph.rs"
if vim.fn.filereadable(path) == 1 then
  local smo, smo_phase, inside = {}, nil, false
  for _, line in ipairs(vim.fn.readfile(path)) do
    if line:find("^pub const NERD: Glyphs") then
      inside = true
    elseif inside and line:find("^};") then
      break
    elseif inside then
      local name, hex = line:match('^%s*([%w_]+):%s*"\\u{(%x+)}')
      if name then
        smo[name] = tonumber(hex, 16)
      elseif line:find("^%s*phase:") then
        smo_phase = {}
        for mark in line:gmatch('"([^"]*)"') do
          table.insert(smo_phase, codepoint(mark))
        end
      end
    end
  end

  -- A glyph.rs this parser no longer reads must fail, not pass with nothing compared.
  for _, name in ipairs(shared) do
    assert(smo[name], "NERD." .. name .. " not found in " .. path)
  end
  assert(smo_phase and #smo_phase == #phases, "NERD.phase not found in " .. path)

  local smo_owner = {}
  for name, cp in pairs(smo) do
    smo_owner[cp] = name
  end
  for name, glyph in pairs(nerd) do
    local cp = codepoint(glyph)
    if smo[name] then
      assert(cp == smo[name], string.format("glyphs.%s is %s, smo's is %s", name, u(cp), u(smo[name])))
    else
      assert(not smo_owner[cp], string.format("glyphs.%s reuses %s, smo's %s", name, u(cp), tostring(smo_owner[cp])))
    end
  end
  for i, name in ipairs(phases) do
    local cp = codepoint(glyphs.phase[name])
    assert(cp == smo_phase[i], string.format("glyphs.phase.%s is %s, smo's is %s", name, u(cp), u(smo_phase[i])))
  end
end

-- 3. Diagnostic signs: an error is smo's failed mark, a warning its warning mark.
local severity = vim.diagnostic.severity
local signs = vim.diagnostic.config().signs
assert(type(signs) == "table" and type(signs.text) == "table", "vim.diagnostic.config().signs.text is not set")
assert(signs.text[severity.ERROR] == glyphs.failed, "the ERROR sign is not glyphs.failed")
assert(signs.text[severity.WARN] == glyphs.warning, "the WARN sign is not glyphs.warning")
-- smo has no info or hint mark, so these two are nvim's own entries, not a smo meaning.
assert(signs.text[severity.INFO] == glyphs.info, "the INFO sign is not glyphs.info")
assert(signs.text[severity.HINT] == glyphs.hint, "the HINT sign is not glyphs.hint")

-- And that is what lands in the sign column of a buffer with an error and a warning.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two" })
vim.api.nvim_set_current_buf(buf)
local ns = vim.api.nvim_create_namespace("smol_glyphs_test")
vim.diagnostic.set(ns, buf, {
  { lnum = 0, col = 0, message = "an error", severity = severity.ERROR },
  { lnum = 1, col = 0, message = "a warning", severity = severity.WARN },
})
local placed = {}
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true, type = "sign" })) do
  placed[mark[2]] = vim.trim(mark[4].sign_text or "")
end
assert(placed[0] == glyphs.failed, "line 1's sign is " .. vim.inspect(placed[0]) .. ", want glyphs.failed")
assert(placed[1] == glyphs.warning, "line 2's sign is " .. vim.inspect(placed[1]) .. ", want glyphs.warning")
