-- The statusline in smo's voice: the mode as a word, the note or the file's path in its
-- project, the branch (a `smo work` one as smo/<short id>), the error and warning counts,
-- joined by smo's ` · `. The marks are lua/smol/glyphs.lua's, the colours colors/smol.lua's.
-- A window that is not the current one shows only what it holds, in StatusLineNC.

local glyphs = require("smol.glyphs")
local root = require("smol.root")

local M = {}

local modes = {
  n = "normal",
  i = "insert",
  v = "visual",
  V = "visual line",
  ["\22"] = "visual block",
  s = "select",
  S = "select line",
  ["\19"] = "select block",
  R = "replace",
  c = "command",
  r = "prompt",
  ["!"] = "shell",
  t = "terminal",
}

-- smo's note kinds; another kind is shown as its word.
local kinds = { idea = glyphs.idea, fix = glyphs.fix, plan = glyphs.plan, todo = glyphs.todo, log = glyphs.log }

-- A `%` in a name is text, not the start of a statusline item.
local function text(s)
  return (s:gsub("%%", "%%%%"))
end

local function first_line(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local line = file:read("*l")
  file:close()
  return line
end

-- The branch checked out in `dir`, read from HEAD on every draw (two small files), so a
-- checkout made anywhere shows at once. In a worktree `.git` is a file naming the git dir.
local function branch(dir)
  local git = vim.fs.joinpath(dir, ".git")
  local gitdir = (first_line(git) or ""):match("^gitdir: (.+)$")
  if gitdir then
    git = gitdir:find("^/") and gitdir or vim.fs.joinpath(dir, gitdir)
  end
  local head = first_line(vim.fs.joinpath(git, "HEAD"))
  local name = head and (head:match("^ref: refs/heads/(.+)$") or "detached HEAD")
  -- `smo work`'s smo/<note id>, as the dash names the note: its short id.
  local short = name and name:match("^smo/%d%d%d%d%d%d%d%dT%d%d%d%d%-.+%-(%w+)$")
  return short and "smo/" .. short or name
end

-- A note as the dash names it: the kind's glyph, @project and the short id, then the slug
-- its file's name carries after the id. It stands in for the path.
local function note_name(note, path, hl)
  local words = { kinds[note.kind] or text(note.kind) }
  if note.project then
    words[#words + 1] = "@" .. text(note.project)
  end
  words[#words + 1] = hl("SmolNoteId", text(note.id:match("[^-]*$")))
  local slug = vim.fs.basename(path):match("^" .. vim.pesc(note.id) .. "%-(.+)%.md$")
  words[#words + 1] = slug and text(slug)
  return table.concat(words, " ")
end

-- What the window holds, and the project directory when it is a file in one.
local function name(buf, hl)
  local bo = vim.bo[buf]
  local path = vim.api.nvim_buf_get_name(buf)
  if bo.buftype == "help" then
    return "help · " .. text(vim.fs.basename(path))
  elseif bo.buftype ~= "" then
    -- Neogit and the like are told apart by filetype; the explorer's window is a
    -- snacks layout box.
    local by_filetype = bo.buftype == "nofile" and bo.filetype ~= ""
    local what = by_filetype and bo.filetype or bo.buftype
    return what == "snacks_layout_box" and "explorer" or text(what:lower())
  end
  local dirty = bo.modified and " " .. hl("SmolDirty", glyphs.dirty) or ""
  if bo.readonly or not bo.modifiable then
    dirty = dirty .. " " .. hl("SmolReadonly", glyphs.lock)
  end
  if path == "" then
    return "[no name]" .. dirty
  end
  local dir = root.get(buf)
  local rel = vim.fs.relpath(dir, path)
  local note = vim.b[buf].smo_note
  local shown = note and note_name(note, path, hl) or text(rel or vim.fn.fnamemodify(path, ":~"))
  return shown .. dirty, rel and dir
end

-- Errors and warnings as smo's marks, each with its count.
local function diagnostics(buf, hl)
  local count = vim.diagnostic.count(buf)
  local severity = vim.diagnostic.severity
  local marks = {}
  if count[severity.ERROR] then
    marks[#marks + 1] = hl("DiagnosticError", glyphs.failed .. " " .. count[severity.ERROR])
  end
  if count[severity.WARN] then
    marks[#marks + 1] = hl("DiagnosticWarn", glyphs.warning .. " " .. count[severity.WARN])
  end
  return #marks > 0 and table.concat(marks, " ") or nil
end

function M.render()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local active = win == vim.api.nvim_get_current_win()
  local function hl(group, s)
    return active and ("%%#%s#%s%%*"):format(group, s) or s
  end

  local shown, dir = name(buf, hl)
  -- A buffer that is no text to move in (the explorer, Neogit) has no position to show.
  local where = vim.bo[buf].buftype == "nofile" and "" or "%l:%c "
  if not active then
    return " " .. shown .. "%= " .. where
  end
  local left = " " .. (modes[vim.fn.mode()] or vim.fn.mode():lower()) .. " · "
  local parts = { shown }
  -- A window too narrow is cut in one place (`%<`): at the branch, from its left, while
  -- the path leaves 16 cells for some of it and the position; else the path loses its
  -- start, never the file's name, and the branch is left out.
  local head = dir and branch(dir)
  local used = head and vim.api.nvim_eval_statusline(left .. shown, { winid = win }).width
  if used and used + 16 <= vim.api.nvim_win_get_width(win) then
    parts[#parts + 1] = glyphs.branch .. " %<" .. text(head)
  else
    left = left .. "%<"
  end
  parts[#parts + 1] = diagnostics(buf, hl)
  -- LSP progress, as nvim's own statusline shows it.
  return left .. table.concat(parts, " · ") .. "%= " .. vim.ui.progress_status() .. where
end

vim.o.statusline = "%!v:lua.require'config.statusline'.render()"

return M
