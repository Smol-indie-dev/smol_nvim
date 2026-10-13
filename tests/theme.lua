-- The colour scheme, colors/smol.lua: the smol palette everywhere, each colour keeping
-- smo's meaning, syntax in white, lavender and grey with yellow literals.

local palette = require("smol.palette")
local blend = require("smol.blend")

local function hex(n)
  return n and string.format("#%06x", n)
end

-- A group as a window draws it: its links followed.
local function hl(name)
  local got = vim.api.nvim_get_hl(0, { name = name, link = false })
  got.fg, got.bg, got.sp = hex(got.fg), hex(got.bg), hex(got.sp)
  return got
end

local function expect(name, key, want)
  local got = hl(name)[key]
  assert(got == want, string.format("%s.%s: want %s, got %s", name, key, tostring(want), tostring(got)))
end

-- What the scheme itself sets: `:colorscheme smol` again, nvim_set_hl watched for calls
-- from colors/smol.lua (the ColorScheme autocmds of the plugins set theirs too).
local owned = {}
do
  local set_hl = vim.api.nvim_set_hl
  vim.api.nvim_set_hl = function(ns, name, value)
    if ns == 0 and debug.getinfo(2, "S").source:match("colors/smol%.lua$") then
      owned[name] = value
    end
    return set_hl(ns, name, value)
  end
  local ok, err = pcall(vim.cmd.colorscheme, "smol")
  vim.api.nvim_set_hl = set_hl
  assert(ok, err)
end
assert(next(owned), "colors/smol.lua set no group")

-- 1. The scheme is smol's, without a background of its own (the terminal's shows
-- through), tokyonight is gone (vim.pack.get() would sync the lock and install, so
-- the lockfile and the runtimepath are read) and the terminal buffer keeps foot's sixteen colours.
assert(vim.g.colors_name == "smol", "colors_name: " .. tostring(vim.g.colors_name))
for _, name in ipairs({ "Normal", "NormalNC" }) do
  expect(name, "bg", nil)
end
for _, dir in ipairs(vim.api.nvim_list_runtime_paths()) do
  assert(not dir:match("tokyonight"), "tokyonight is on the runtimepath: " .. dir)
end
local lock = table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/nvim-pack-lock.json"), "\n")
assert(not lock:match("tokyonight"), "nvim-pack-lock.json still pins tokyonight")
assert(not pcall(require, "tokyonight"), "tokyonight can still be required")
assert(vim.g.terminal_color_0 == nil, "g:terminal_color_0 is set: " .. tostring(vim.g.terminal_color_0))

-- 2. palette.lua holds exactly nvim's roles: the frame and the meanings.
local roles = {
  "bg",
  "fg",
  "surface",
  "dim",
  "border",
  "accent",
  "accent_soft",
  "selection",
  "cursor",
  "error",
  "warn",
  "ok",
  "info",
  "id",
  "net",
}
local want_roles, got_roles = vim.deepcopy(roles), vim.tbl_keys(palette)
table.sort(want_roles)
table.sort(got_roles)
assert(
  vim.deep_equal(got_roles, want_roles),
  "palette.lua's roles: " .. table.concat(got_roles, " ") .. "; want " .. table.concat(want_roles, " ")
)
for role, value in pairs(palette) do
  assert(value:match("^#%x%x%x%x%x%x$") and value == value:lower(), "palette." .. role .. " is not #rrggbb: " .. value)
end

-- Drift: each value against its role in smol_office's palette.toml, read by the file's
-- own grammar: a blank line, a `# comment` or `role = "#rrggbb"`. Skipped without it.
local toml = vim.env.HOME .. "/dev/smol_office/setup/config/smol/palette.toml"
if vim.fn.filereadable(toml) == 1 then
  local values = {}
  for n, line in ipairs(vim.fn.readfile(toml)) do
    if not (line:match("^%s*$") or line:match("^#")) then
      local role, value = line:match('^([%w_]+) = "(#%x%x%x%x%x%x)"$')
      assert(role, string.format('palette.toml:%d is not `role = "#rrggbb"`: %s', n, line))
      values[role] = value:lower()
    end
  end
  for _, role in ipairs(roles) do
    assert(values[role], "palette.toml has no " .. role)
    assert(
      palette[role] == values[role],
      string.format("palette.%s drifted from palette.toml: %s, want %s", role, tostring(palette[role]), values[role])
    )
  end
end

-- 3. The blend helper: a colour mixed into another by an amount, and the named blends
-- the scheme and Neogit use, each a role mixed into bg.
assert(blend.mix("#ffffff", "#000000", 0.5) == "#808080", "mix 0.5: " .. blend.mix("#ffffff", "#000000", 0.5))
assert(blend.mix("#123456", "#abcdef", 0) == "#abcdef", "mix 0 is the base")
assert(blend.mix("#123456", "#abcdef", 1) == "#123456", "mix 1 is the colour")
local blends = {
  diff_add = { "ok", 0.15, "#2e3426" },
  diff_change = { "warn", 0.15, "#372f23" },
  diff_delete = { "error", 0.15, "#372324" },
  diff_text = { "warn", 0.3, "#5b4a32" },
  search = { "accent", 0.4, "#3f0c72" },
  bg1 = { "fg", 0.04, "#1d1d1d" },
  bg2 = { "fg", 0.08, "#272727" },
  bg3 = { "fg", 0.14, "#353535" },
}
local want_names, got_names = vim.tbl_keys(blends), vim.tbl_keys(blend.named)
table.sort(want_names)
table.sort(got_names)
assert(vim.deep_equal(got_names, want_names), "blend.named: " .. table.concat(got_names, " "))
for name, b in pairs(blends) do
  local role, amount, want = unpack(b)
  local mixed = blend.mix(palette[role], palette.bg, amount)
  assert(mixed == want, string.format("%s: %s at %s into bg is %s, want %s", name, role, amount, mixed, want))
  assert(blend.named[name] == want, string.format("blend.named.%s: %s, want %s", name, blend.named[name], want))
end

-- 4. The tables, group by group: each row's groups (and the captures set the same) read
-- back as the row says. `bg = false` means no background.
local p, b = palette, blend.named
local function row(groups, want)
  for _, name in ipairs(groups) do
    local got = hl(name)
    for key, value in pairs(want) do
      if value == false then
        value = nil
      end
      assert(got[key] == value, string.format("%s.%s: want %s, got %s", name, key, tostring(value), tostring(got[key])))
    end
  end
end

local keywords = {
  "@keyword",
  "@keyword.function",
  "@keyword.operator",
  "@keyword.import",
  "@keyword.type",
  "@keyword.modifier",
  "@keyword.repeat",
  "@keyword.return",
  "@keyword.debug",
  "@keyword.exception",
  "@keyword.conditional",
  "@keyword.conditional.ternary",
  "@keyword.directive",
  "@keyword.directive.define",
  "@keyword.coroutine",
}
local types = { "@type", "@type.builtin", "@type.definition" }
local punctuation = { "@punctuation.delimiter", "@punctuation.bracket", "@punctuation.special", "@tag.delimiter" }

-- The syntax.
row({ "Normal", "NormalNC" }, { fg = p.fg, bg = false })
row(
  { "Identifier", "@variable", "@variable.parameter", "@variable.member", "Operator", "@operator", "@property" },
  { fg = p.fg, bold = false }
)
row(vim.list_extend({ "Comment", "@comment", "SpecialComment", "Delimiter" }, punctuation), { fg = p.dim })
row(
  vim.list_extend(
    vim.list_extend({
      "Statement",
      "Keyword",
      "Conditional",
      "Repeat",
      "Label",
      "Exception",
      "PreProc",
      "Include",
      "Define",
      "Macro",
      "Type",
      "StorageClass",
      "Structure",
      "Typedef",
      "Tag",
      "@module",
      "@attribute",
      "@tag",
      "@label",
    }, keywords),
    types
  ),
  { fg = p.accent_soft }
)
row({ "@variable.builtin", "@constant.builtin", "@function.builtin" }, { fg = p.accent_soft })
row({ "Function", "@function", "@function.method", "@constructor" }, { fg = p.fg, bold = true })
row({ "@function.call", "@function.method.call" }, { fg = p.fg, bold = false })
row({ "String", "@string", "Character", "@character", "Number", "@number", "Boolean", "@boolean" }, { fg = p.warn })
row({ "Float", "@number.float", "Constant", "@constant", "@string.regexp" }, { fg = p.warn })
row({ "Special", "SpecialChar", "@string.escape", "@string.special", "@character.special" }, { fg = p.accent_soft })
row({ "Todo", "@comment.todo", "@comment.note" }, { fg = p.dim, bold = true, bg = false })
row({ "@comment.warning" }, { fg = p.warn })
row({ "@comment.error" }, { fg = p.error })

-- Markdown: headings cyan bold without a band, inline code yellow without a box.
local headings = { "@markup.heading" }
for i = 1, 6 do
  headings[#headings + 1] = "@markup.heading." .. i .. ".markdown"
  headings[#headings + 1] = "@markup.heading." .. i
end
row(headings, { fg = p.info, bold = true, bg = false })
row({ "@markup.raw", "@markup.raw.markdown_inline" }, { fg = p.warn, bg = false })
row({ "@markup.link.url", "Underlined" }, { fg = p.net, underline = true })
row({ "@markup.link", "@markup.link.label" }, { fg = p.net })
row({ "@markup.strong" }, { bold = true })
row({ "@markup.italic" }, { italic = true })
row({ "@markup.strikethrough" }, { strikethrough = true })
row({ "@markup.quote", "@markup.list", "@markup.list.checked", "@markup.list.unchecked" }, { fg = p.dim })
-- A note's frontmatter fence is punctuation, not a keyword.
row({ "@keyword.directive.markdown" }, { fg = p.dim })

-- Diffs: the meanings as text, blended into bg as backgrounds.
row({ "Added", "@diff.plus" }, { fg = p.ok })
row({ "Changed", "@diff.delta" }, { fg = p.warn })
row({ "Removed", "@diff.minus" }, { fg = p.error })
-- Vim's diff syntax groups, which diffview's file panel links to.
row({ "diffAdded" }, { fg = p.ok })
row({ "diffChanged" }, { fg = p.warn })
row({ "diffRemoved" }, { fg = p.error })
row({ "DiffAdd" }, { bg = b.diff_add })
row({ "DiffChange" }, { bg = b.diff_change })
row({ "DiffDelete" }, { bg = b.diff_delete })
row({ "DiffText" }, { bg = b.diff_text })
row({ "@lsp.mod.deprecated", "DiagnosticDeprecated" }, { strikethrough = true })

-- The editor's states.
row({ "Visual" }, { bg = p.selection, fg = p.fg })
row({ "NormalFloat", "Pmenu" }, { bg = p.surface, fg = p.fg })
row({ "FloatBorder" }, { bg = p.surface, fg = p.accent })
row({ "FloatTitle" }, { bg = p.surface, fg = p.accent })
row({ "PmenuSel" }, { bg = p.accent, fg = p.fg })
row({ "StatusLine" }, { bg = p.surface, fg = p.fg })
row({ "StatusLineNC" }, { bg = p.surface, fg = p.dim })
row({ "CursorLine", "ColorColumn", "CursorColumn" }, { bg = p.surface })
row({ "LineNr" }, { fg = p.dim })
row({ "SmolNoteId" }, { fg = p.id })
row({ "SmolDirty" }, { fg = p.warn })
row({ "SmolReadonly" }, { fg = p.dim })
row({ "SmolKey", "SnacksDashboardKey" }, { fg = p.fg, bold = true })
row({ "SnacksDashboardDesc", "SnacksDashboardIcon" }, { fg = p.fg })
row({ "SnacksDashboardHeader" }, { fg = p.accent })
row({ "Cursor", "CursorIM", "TermCursor", "lCursor" }, { bg = p.cursor, fg = p.bg })
row({ "CursorLineNr" }, { fg = p.fg, bold = true })
row({ "SignColumn", "FoldColumn" }, { bg = false })
row({ "Folded" }, { fg = p.dim, bg = p.surface })
row({ "Search" }, { bg = b.search, fg = p.fg })
row({ "IncSearch", "CurSearch", "Substitute" }, { bg = p.accent, fg = p.fg })
row({ "MatchParen" }, { fg = p.accent_soft, bold = true })
row({ "LspReferenceText", "LspReferenceRead", "LspReferenceWrite" }, { bg = p.surface })
row({ "WinSeparator", "VertSplit" }, { fg = p.surface })
row({ "EndOfBuffer" }, { fg = p.bg })
row({ "NonText", "Whitespace", "SpecialKey", "Conceal" }, { fg = p.dim })
row({ "ErrorMsg", "Error", "NvimInternalError" }, { fg = p.error })
row({ "WarningMsg" }, { fg = p.warn })
row({ "MoreMsg", "Question", "OkMsg" }, { fg = p.ok })
row({ "ModeMsg", "MsgArea" }, { fg = p.fg })
row({ "Directory" }, { fg = p.accent_soft })
row({ "Title" }, { fg = p.info, bold = true })
row({ "QuickFixLine" }, { bg = p.surface, bold = true })
row({ "WinBar" }, { fg = p.fg, bg = false })
row({ "WinBarNC" }, { fg = p.dim, bg = false })

local severities = { Error = p.error, Warn = p.warn, Info = p.info, Hint = p.dim, Ok = p.ok }
for name, colour in pairs(severities) do
  row({
    "Diagnostic" .. name,
    "DiagnosticVirtualText" .. name,
    "DiagnosticSign" .. name,
    "DiagnosticFloating" .. name,
  }, { fg = colour })
  row({ "DiagnosticUnderline" .. name }, { sp = colour, undercurl = true })
end
row({ "DiagnosticUnnecessary" }, { fg = p.dim })
row({ "SpellBad" }, { sp = p.error, undercurl = true, fg = false })
row({ "SpellCap" }, { sp = p.warn, undercurl = true, fg = false })
row({ "SpellLocal", "SpellRare" }, { sp = p.info, undercurl = true, fg = false })

-- fzf-lua's groups in named colours, as its pickers show them; its frames the float's.
row({ "FzfLuaHeaderText", "FzfLuaHeaderBind", "FzfLuaTabTitle", "FzfLuaTabMarker" }, { fg = p.accent_soft })
row({ "FzfLuaPathLineNr", "FzfLuaPathColNr", "FzfLuaBufNr" }, { fg = p.dim })
row({ "FzfLuaBufFlagCur", "FzfLuaBufFlagAlt" }, { fg = p.accent_soft })
row({ "FzfLuaLivePrompt", "FzfLuaLiveSym" }, { fg = p.accent_soft })
row({ "FzfLuaNormal", "FzfLuaPreviewNormal" }, { bg = p.surface, fg = p.fg })
row({ "FzfLuaBorder", "FzfLuaPreviewBorder" }, { bg = p.surface, fg = p.accent })

-- Every frame is the float's: the accent on surface.
row(
  { "BlinkCmpMenuBorder", "BlinkCmpDocBorder", "BlinkCmpSignatureHelpBorder", "SnacksInputBorder", "SnacksInputTitle" },
  { bg = p.surface, fg = p.accent }
)

-- 5. No stray colour: every value the scheme sets is a palette role or a named blend, and
-- so is every colour the groups of this config's windows show.
local allowed = {}
for _, value in pairs(palette) do
  allowed[value] = true
end
for _, value in pairs(blend.named) do
  allowed[value] = true
end
local function only_allowed(name, value, why)
  for _, key in ipairs({ "fg", "bg", "sp" }) do
    local v = value[key]
    if type(v) == "number" then
      v = hex(v)
    end
    assert(
      v == nil or allowed[type(v) == "string" and v:lower() or v],
      string.format("%s.%s %s: %s", name, key, why, v)
    )
  end
end
for name, value in pairs(owned) do
  only_allowed(name, value, "is no palette value nor blend")
end

-- Plugin groups are defined when a plugin first draws: load what defines them.
require("snacks.picker.config.highlights")
require("snacks.input")
require("snacks.dashboard")
require("diffview.hl").setup()
local shown = {
  -- fzf-lua's picker and preview.
  "FzfLuaNormal",
  "FzfLuaBorder",
  "FzfLuaTitle",
  "FzfLuaPreviewNormal",
  "FzfLuaPreviewBorder",
  "FzfLuaPreviewTitle",
  "FzfLuaCursorLine",
  "FzfLuaSearch",
  "FzfLuaDirPart",
  "FzfLuaHeaderBind",
  "FzfLuaHeaderText",
  "FzfLuaPathLineNr",
  "FzfLuaPathColNr",
  "FzfLuaBufNr",
  "FzfLuaFzfMatch",
  "FzfLuaFzfPointer",
  "FzfLuaFzfPrompt",
  -- snacks: the explorer, the input, the start screen.
  "SnacksPickerPrompt",
  "SnacksPickerTotals",
  "SnacksPickerDir",
  "SnacksPickerFile",
  "SnacksPickerDirectory",
  "SnacksPickerTree",
  "SnacksPickerMatch",
  "SnacksPickerGitStatusModified",
  "SnacksPickerGitStatusAdded",
  "SnacksPickerGitStatusDeleted",
  "SnacksPickerGitStatusUntracked",
  "SnacksInputNormal",
  "SnacksInputBorder",
  "SnacksInputTitle",
  "SnacksDashboardHeader",
  "SnacksDashboardKey",
  "SnacksDashboardDesc",
  "SnacksDashboardIcon",
  "SnacksDashboardTitle",
  "SnacksDashboardFooter",
  -- blink's menu and docs.
  "BlinkCmpMenu",
  "BlinkCmpMenuBorder",
  "BlinkCmpMenuSelection",
  "BlinkCmpLabelDetail",
  "BlinkCmpLabelDescription",
  "BlinkCmpKind",
  "BlinkCmpSource",
  "BlinkCmpDoc",
  "BlinkCmpDocBorder",
  "BlinkCmpSignatureHelp",
  "BlinkCmpSignatureHelpBorder",
  -- gitsigns.
  "GitSignsAdd",
  "GitSignsChange",
  "GitSignsDelete",
  -- diffview.
  "DiffviewNormal",
  "DiffviewFilePanelTitle",
  "DiffviewFilePanelFileName",
  "DiffviewFolderName",
  "DiffviewStatusAdded",
  "DiffviewStatusModified",
  "DiffviewStatusDeleted",
  "DiffviewDiffAdd",
  "DiffviewDiffDelete",
}
for _, name in ipairs(shown) do
  assert(next(vim.api.nvim_get_hl(0, { name = name })), name .. " is not defined")
  only_allowed(name, hl(name), "shows a colour off the palette")
end

-- fzf's own list takes its colours from fzf-lua's groups, not from fzf's 256-colour set.
local fzf_colors = require("fzf-lua.config").globals.fzf_colors
assert(fzf_colors == true, "fzf-lua fzf_colors: " .. vim.inspect(fzf_colors))

-- Neogit computes its groups from a palette of its own: it is fed smol's.
local fed = require("neogit.config").values.highlight
for key, want in pairs({
  bg0 = p.bg,
  bg1 = b.bg1,
  bg2 = b.bg2,
  bg3 = b.bg3,
  grey = p.dim,
  white = p.fg,
  red = p.error,
  orange = p.warn,
  yellow = p.warn,
  green = p.ok,
  cyan = p.info,
  blue = p.net,
  purple = p.accent_soft,
  line_red = b.diff_delete,
  line_green = b.diff_add,
}) do
  assert(fed[key] == want, string.format("neogit highlight.%s: want %s, got %s", key, want, tostring(fed[key])))
end

-- 6. Contrast: the text groups read at 4.5:1 or more against what they are drawn on
-- (bg when they have no background of their own).
local function luminance(colour)
  local sum = 0
  for i, weight in ipairs({ 0.2126, 0.7152, 0.0722 }) do
    local c = tonumber(colour:sub(2 * i, 2 * i + 1), 16) / 255
    c = c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
    sum = sum + weight * c
  end
  return sum
end
local function contrast(a, z)
  local la, lz = luminance(a), luminance(z)
  return (math.max(la, lz) + 0.05) / (math.min(la, lz) + 0.05)
end
local text = vim.list_extend({
  "Normal",
  "Identifier",
  "Comment",
  "Delimiter",
  "Statement",
  "Keyword",
  "Type",
  "PreProc",
  "Function",
  "String",
  "Number",
  "Constant",
  "Special",
  "Todo",
  "@variable",
  "@property",
  "@function.call",
  "@comment.warning",
  "@comment.error",
  "@markup.raw.markdown_inline",
  "@markup.link.url",
  "@markup.quote",
  "Added",
  "Changed",
  "Removed",
  "ErrorMsg",
  "WarningMsg",
  "MoreMsg",
  "Question",
  "ModeMsg",
  "MsgArea",
  "Directory",
  "Title",
  "Visual",
  "Search",
  "IncSearch",
  "PmenuSel",
  "NormalFloat",
  "StatusLine",
  "StatusLineNC",
  "LineNr",
  "Folded",
}, vim.list_extend(vim.deepcopy(headings), keywords))
for _, name in ipairs(text) do
  local got = hl(name)
  local fg, bg = got.fg or p.fg, got.bg or p.bg
  local ratio = contrast(fg, bg)
  assert(ratio >= 4.5, string.format("%s: %s on %s is %.1f:1, under 4.5", name, fg, bg, ratio))
end

-- The accent is no text colour: a background, a border (a float's title and footer are
-- drawn in its border line), the start screen's large header.
local accent_fg = {
  FloatBorder = true,
  FloatTitle = true,
  FloatFooter = true,
  FzfLuaBorder = true,
  FzfLuaPreviewBorder = true,
  BlinkCmpMenuBorder = true,
  BlinkCmpDocBorder = true,
  BlinkCmpSignatureHelpBorder = true,
  SnacksInputBorder = true,
  SnacksInputTitle = true,
  SnacksDashboardHeader = true,
}
for name, value in pairs(owned) do
  if not accent_fg[name] then
    assert(hl(name).fg ~= p.accent, name .. " has the accent as its text colour")
  end
end

-- 7. The meanings: error only on a failure or a removal, the note id's colour only on
-- the note id.
local failures = {
  ErrorMsg = true,
  Error = true,
  NvimInternalError = true,
  DiagnosticError = true,
  DiagnosticVirtualTextError = true,
  DiagnosticSignError = true,
  DiagnosticFloatingError = true,
  DiagnosticUnderlineError = true,
  SpellBad = true,
  ["@comment.error"] = true,
  Removed = true,
  ["@diff.minus"] = true,
  diffRemoved = true,
}
for name in pairs(owned) do
  local got = hl(name)
  for _, key in ipairs({ "fg", "bg", "sp" }) do
    if got[key] == p.error then
      assert(failures[name], string.format("%s.%s is error's red: only a failure or a removal is", name, key))
    end
    if got[key] == p.id then
      assert(name == "SmolNoteId", string.format("%s.%s is the note id's colour: only SmolNoteId is", name, key))
    end
  end
end
