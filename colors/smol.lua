-- smol: the smol office palette (lua/smol/palette.lua) for every group nvim and this
-- config's windows show. Code reads as white with lavender structure, grey punctuation
-- and yellow literals; each meaning colour keeps smo's one meaning: red a failure or a
-- removal, yellow a warning, a change or code, green ok or an addition, cyan headings,
-- magenta only the note id. The accent is a background, a border or the start screen's
-- large header, never body text: on bg it reads at under 3:1.

local p = require("smol.palette")
local b = require("smol.blend").named

vim.cmd("highlight clear")
if vim.g.syntax_on then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.g.colors_name = "smol"

local groups = {}

-- Every name in `names` gets `spec`.
local function set(names, spec)
  for _, name in ipairs(names) do
    groups[name] = spec
  end
end

-- Syntax. Normal has no background: the terminal's shows through.
set({ "Normal", "NormalNC" }, { fg = p.fg })
set({ "Identifier", "@variable", "@variable.parameter", "@variable.member", "Operator", "@operator", "@property" }, {
  fg = p.fg,
})
set({
  "Comment",
  "@comment",
  "SpecialComment",
  "Delimiter",
  "@punctuation.delimiter",
  "@punctuation.bracket",
  "@punctuation.special",
  "@tag.delimiter",
}, { fg = p.dim })
set({
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
  "@type",
  "@type.builtin",
  "@type.definition",
  "@variable.builtin",
  "@constant.builtin",
  "@function.builtin",
}, { fg = p.accent_soft })
set({ "Function", "@function", "@function.method", "@constructor" }, { fg = p.fg, bold = true })
set({ "@function.call", "@function.method.call" }, { fg = p.fg })
-- Literals are yellow: a syntax use of code, the one hue in code besides the brand.
set({
  "String",
  "@string",
  "Character",
  "@character",
  "Number",
  "@number",
  "Boolean",
  "@boolean",
  "Float",
  "@number.float",
  "Constant",
  "@constant",
  "@string.regexp",
}, { fg = p.warn })
set({ "Special", "SpecialChar", "@string.escape", "@string.special", "@character.special" }, { fg = p.accent_soft })
set({ "Todo", "@comment.todo", "@comment.note" }, { fg = p.dim, bold = true })
set({ "@comment.warning" }, { fg = p.warn })
set({ "@comment.error" }, { fg = p.error })

-- Markdown: headings cyan and bold on no band, inline code yellow like smo's, in no box.
local headings = { "@markup.heading" }
for i = 1, 6 do
  table.insert(headings, "@markup.heading." .. i)
  table.insert(headings, "@markup.heading." .. i .. ".markdown")
end
set(headings, { fg = p.info, bold = true })
set({ "@markup.heading.1.delimiter.vimdoc", "@markup.heading.2.delimiter.vimdoc" }, { fg = p.dim })
set({ "@markup.raw", "@markup.raw.markdown_inline" }, { fg = p.warn })
set({ "@markup.link.url", "Underlined" }, { fg = p.net, underline = true })
set({ "@markup.link", "@markup.link.label" }, { fg = p.net })
set({ "@markup.strong" }, { bold = true })
set({ "@markup.italic" }, { italic = true })
set({ "@markup.strikethrough" }, { strikethrough = true })
set({ "@markup.quote", "@markup.list", "@markup.list.checked", "@markup.list.unchecked" }, { fg = p.dim })
-- A note's frontmatter fence (`---`) is punctuation, not a keyword.
set({ "@keyword.directive.markdown" }, { fg = p.dim })

-- Diffs: the meanings as text, blended into bg behind a hunk.
set({ "Added", "@diff.plus" }, { fg = p.ok })
set({ "Changed", "@diff.delta" }, { fg = p.warn })
set({ "Removed", "@diff.minus" }, { fg = p.error })
-- Vim's diff syntax groups; nvim leaves them empty, diffview's file panel links to them.
groups.diffAdded = { link = "Added" }
groups.diffChanged = { link = "Changed" }
groups.diffRemoved = { link = "Removed" }
groups.DiffAdd = { bg = b.diff_add }
groups.DiffChange = { bg = b.diff_change }
groups.DiffDelete = { bg = b.diff_delete }
groups.DiffText = { bg = b.diff_text }

-- LSP tokens keep nvim's links to the captures above.
groups["@lsp.mod.deprecated"] = { strikethrough = true }

-- The frame.
groups.Visual = { bg = p.selection, fg = p.fg }
set({ "NormalFloat", "Pmenu" }, { bg = p.surface, fg = p.fg })
set({ "FloatBorder", "FloatTitle" }, { bg = p.surface, fg = p.accent })
groups.FloatFooter = { link = "FloatTitle" }
groups.PmenuSel = { bg = p.accent, fg = p.fg }
groups.PmenuSbar = { bg = p.surface }
groups.PmenuThumb = { bg = p.dim }
set({ "PmenuKind", "PmenuExtra" }, { bg = p.surface, fg = p.dim })
groups.PmenuMatch = { bg = p.surface, fg = p.accent_soft, bold = true }
groups.PmenuMatchSel = { bg = p.accent, fg = p.fg, bold = true }
groups.StatusLine = { bg = p.surface, fg = p.fg }
groups.StatusLineNC = { bg = p.surface, fg = p.dim }
set({ "StatusLineTerm" }, { link = "StatusLine" })
set({ "StatusLineTermNC" }, { link = "StatusLineNC" })
groups.TabLine = { bg = p.surface, fg = p.dim }
groups.TabLineFill = { bg = p.surface }
groups.TabLineSel = { bg = p.surface, fg = p.fg, bold = true }
groups.WinBar = { fg = p.fg }
groups.WinBarNC = { fg = p.dim }
set({ "CursorLine", "ColorColumn", "CursorColumn" }, { bg = p.surface })
groups.LineNr = { fg = p.dim }
groups.CursorLineNr = { fg = p.fg, bold = true }
set({ "SignColumn", "FoldColumn" }, {})
groups.Folded = { fg = p.dim, bg = p.surface }
set({ "Cursor", "CursorIM", "TermCursor", "lCursor" }, { bg = p.cursor, fg = p.bg })
groups.Search = { bg = b.search, fg = p.fg }
set({ "IncSearch", "CurSearch", "Substitute" }, { bg = p.accent, fg = p.fg })
groups.MatchParen = { fg = p.accent_soft, bold = true }
set({ "LspReferenceText", "LspReferenceRead", "LspReferenceWrite" }, { bg = p.surface })
set({ "WinSeparator", "VertSplit" }, { fg = p.surface })
-- The `~` past the end of a buffer, hidden.
groups.EndOfBuffer = { fg = p.bg }
set({ "NonText", "Whitespace", "SpecialKey", "Conceal" }, { fg = p.dim })
groups.QuickFixLine = { bg = p.surface, bold = true }

-- Messages.
set({ "ErrorMsg", "Error", "NvimInternalError" }, { fg = p.error })
groups.WarningMsg = { fg = p.warn }
set({ "MoreMsg", "Question", "OkMsg" }, { fg = p.ok })
set({ "ModeMsg", "MsgArea" }, { fg = p.fg })
groups.Directory = { fg = p.accent_soft }
groups.Title = { fg = p.info, bold = true }

-- Diagnostics: a hint is quiet, the rest their meaning.
for name, colour in pairs({ Error = p.error, Warn = p.warn, Info = p.info, Hint = p.dim, Ok = p.ok }) do
  set({
    "Diagnostic" .. name,
    "DiagnosticVirtualText" .. name,
    "DiagnosticSign" .. name,
    "DiagnosticFloating" .. name,
  }, { fg = colour })
  groups["DiagnosticUnderline" .. name] = { sp = colour, undercurl = true }
end
groups.DiagnosticUnnecessary = { fg = p.dim }
groups.DiagnosticDeprecated = { strikethrough = true }

-- Spelling: an undercurl only, the text keeps its colour.
groups.SpellBad = { sp = p.error, undercurl = true }
groups.SpellCap = { sp = p.warn, undercurl = true }
set({ "SpellLocal", "SpellRare" }, { sp = p.info, undercurl = true })

-- This config's own groups: the statusline's note id and marks, the keys float (␣?).
groups.SmolNoteId = { fg = p.id }
-- Unsaved changes.
groups.SmolDirty = { fg = p.warn }
-- A read-only buffer: there, not a warning.
groups.SmolReadonly = { fg = p.dim }
groups.SmolKey = { fg = p.fg, bold = true }

-- The start screen: keys bold and what they do plain, as in smo; the header in the accent.
groups.SnacksDashboardHeader = { fg = p.accent }
groups.SnacksDashboardKey = { fg = p.fg, bold = true }
set({ "SnacksDashboardDesc", "SnacksDashboardIcon" }, { fg = p.fg })

-- Frames that link elsewhere (blink's to Pmenu and NormalFloat, snacks' input to
-- DiagnosticInfo) take the float's border and title.
set({ "BlinkCmpMenuBorder", "BlinkCmpDocBorder", "BlinkCmpSignatureHelpBorder", "SnacksInputBorder" }, {
  link = "FloatBorder",
})
groups.SnacksInputTitle = { link = "FloatTitle" }

-- fzf-lua names some colours (BlanchedAlmond, Brown1, ...) where it does not link; its
-- frame links to Normal, here the float's.
set({ "FzfLuaNormal", "FzfLuaPreviewNormal" }, { bg = p.surface, fg = p.fg })
set({ "FzfLuaBorder", "FzfLuaPreviewBorder" }, { bg = p.surface, fg = p.accent })
set({
  "FzfLuaHeaderText",
  "FzfLuaHeaderBind",
  "FzfLuaTabTitle",
  "FzfLuaTabMarker",
  "FzfLuaBufFlagCur",
  "FzfLuaBufFlagAlt",
  "FzfLuaLivePrompt",
  "FzfLuaLiveSym",
}, { fg = p.accent_soft })
set({ "FzfLuaPathLineNr", "FzfLuaPathColNr", "FzfLuaBufNr" }, { fg = p.dim })

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end
