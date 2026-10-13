-- The statusline: the mode as a word, the file's path in its project or the note, the
-- branch, and the error and warning counts, in smo's glyphs and colours. Each line is
-- drawn through 'statusline' itself (nvim_eval_statusline), so the text and the colours
-- are what a window shows. Every fixture lives in a temp dir.

local glyphs = require("smol.glyphs")
local palette = require("smol.palette")

assert(vim.o.statusline:find("config.statusline", 1, true), "'statusline' is not this config's: " .. vim.o.statusline)

-- Resolved, so the paths compare equal even when the temp dir is behind a symlink.
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
tmp = assert(vim.uv.fs_realpath(tmp))
assert(not vim.fs.root(tmp, ".git"), "the temp dir is inside a git repo: " .. tmp)

local function git(...)
  local result = vim.system({ "git", ... }):wait()
  assert(result.code == 0, ("git %s: %s"):format(table.concat({ ... }, " "), result.stderr))
end

local function put(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local file = assert(io.open(path, "wb"))
  file:write(text or "")
  file:close()
  return path
end

local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

-- The line of a window (the current one by default), wide enough that nothing is cut.
local function draw(win)
  return vim.api.nvim_eval_statusline(vim.o.statusline, { winid = win or 0, highlights = true, maxwidth = 300 })
end

-- The 0-based byte where `text` starts in the line; fails when it is not there.
local function at(line, text)
  local from = line.str:find(text, 1, true)
  assert(from, ("no %q in %q"):format(text, line.str))
  return from - 1
end

local function lacks(line, text, why)
  assert(not line.str:find(text, 1, true), ("%s: %q in %q"):format(why, text, line.str))
end

-- The highlight group at a byte of the line, and its foreground colour.
local function colour(line, byte)
  local group
  for _, hl in ipairs(line.highlights) do
    if hl.start <= byte then
      group = hl.group
    end
  end
  local fg = vim.api.nvim_get_hl(0, { name = group, link = false }).fg
  return fg and ("#%06x"):format(fg), group
end

local function expect(what, got, want)
  assert(got == want, ("%s: want %s, got %s"):format(what, vim.inspect(want), vim.inspect(got)))
end

local repo = vim.fs.joinpath(tmp, "repo")
local worktree = vim.fs.joinpath(tmp, "worktree")
local plain = vim.fs.joinpath(tmp, "plain")
local elsewhere = vim.fs.joinpath(tmp, "elsewhere")

git("init", "-q", "-b", "trunk", repo)
-- A real linked worktree, as `smo work` makes them: its `.git` is a file.
git("-C", repo, "worktree", "add", "-q", "--orphan", "-b", "work", worktree)

local in_repo = put(vim.fs.joinpath(repo, "src", "deep", "a.lua"))
local percent = put(vim.fs.joinpath(repo, "100%.lua"))
local in_worktree = put(vim.fs.joinpath(worktree, "src", "b.lua"))
local in_plain = put(vim.fs.joinpath(plain, "sub", "c.lua"))

-- nvim's cwd is none of the projects, as when the dash's `e` starts it from ~.
vim.fn.mkdir(elsewhere, "p")
vim.cmd.cd(vim.fn.fnameescape(elsewhere))

-- The mode is on the line once: nvim's `-- INSERT --` under it is off.
expect("'showmode'", vim.o.showmode, false)

-- 5. The mode is a lower-case word, and the line starts with it.
edit(in_repo)
local line = draw()
expect("the line starts with the mode", at(line, " normal · "), 0)

-- <Cmd> runs in the mode the keys before it entered; the `x` flag leaves it afterwards.
local function mode_after(keys)
  local read = "<Cmd>lua _G.smol_line = vim.api.nvim_eval_statusline(vim.o.statusline, {}).str<CR>"
  _G.smol_line = nil
  vim.api.nvim_feedkeys(vim.keycode(keys .. read .. "<C-c>"), "mx", false)
  return assert(_G.smol_line, "no line drawn after " .. keys):match("^ (.-) · ")
end

for keys, word in pairs({
  i = "insert",
  v = "visual",
  V = "visual line",
  ["<C-v>"] = "visual block",
  R = "replace",
  [":"] = "command",
}) do
  expect("the mode after " .. keys, mode_after(keys), word)
end
expect("back in normal mode", vim.fn.mode(), "n")

-- 1. A file in a repo: its path from the root, then the branch.
line = draw()
at(line, " · src/deep/a.lua · " .. glyphs.branch .. " trunk")

-- A `%` in a name is text, not a statusline item.
edit(percent)
at(draw(), " · 100%.lua · " .. glyphs.branch .. " trunk")

-- A worktree is its own project, on its own branch.
edit(in_worktree)
at(draw(), " · src/b.lua · " .. glyphs.branch .. " work")

-- Outside a repo there is no branch, and the path is the whole one unless nvim's cwd
-- holds the file.
local whole = vim.fn.fnamemodify(in_plain, ":~")
edit(in_plain)
line = draw()
at(line, " · " .. whole)
lacks(line, glyphs.branch, "a file outside a repo")

vim.cmd.cd(vim.fn.fnameescape(plain))
line = draw()
at(line, " · sub/c.lua")
lacks(line, glyphs.branch, "a file outside a repo, below nvim's cwd")

-- nvim's cwd being a repo gives a file outside it no branch.
vim.cmd.cd(vim.fn.fnameescape(repo))
line = draw()
at(line, " · " .. whole)
lacks(line, glyphs.branch, "a file outside the repo nvim's cwd is in")
vim.cmd.cd(vim.fn.fnameescape(elsewhere))

-- A buffer without a file.
vim.cmd.enew()
line = draw()
at(line, " normal · [no name]")
lacks(line, glyphs.branch, "an unnamed buffer")

-- 2. A modified buffer shows the dirty mark in yellow; a saved one shows none.
edit(in_repo)
lacks(draw(), glyphs.dirty, "an unmodified buffer")
vim.bo.modified = true
line = draw()
at(line, " · src/deep/a.lua " .. glyphs.dirty .. " · " .. glyphs.branch .. " trunk")
expect("the dirty mark's colour", colour(line, at(line, glyphs.dirty)), palette.warn)
vim.bo.modified = false

-- A read-only buffer shows the lock after the name, dim; one that cannot be changed too.
lacks(draw(), glyphs.lock, "a buffer that can be written")
vim.bo.readonly = true
line = draw()
at(line, " · src/deep/a.lua " .. glyphs.lock .. " · " .. glyphs.branch .. " trunk")
expect("the lock's colour", colour(line, at(line, glyphs.lock)), palette.dim)
vim.bo.readonly = false
vim.bo.modifiable = false
at(draw(), " · src/deep/a.lua " .. glyphs.lock .. " · ")
vim.bo.modifiable = true
lacks(draw(), glyphs.lock, "a buffer made writable again")

-- 3. Diagnostics: smo's failed mark and the count in red, its warning mark and the count
-- in yellow. Counts stay numbers; info and hints are not counted.
local ns = vim.api.nvim_create_namespace("smol_statusline_test")
local severity = vim.diagnostic.severity
local function diagnostics(...)
  local list = {}
  for _, s in ipairs({ ... }) do
    list[#list + 1] = { lnum = 0, col = 0, severity = s, message = "x" }
  end
  vim.diagnostic.set(ns, 0, list)
end
local signs = { glyphs.failed, glyphs.warning, glyphs.info, glyphs.hint }

for _, sign in ipairs(signs) do
  lacks(draw(), sign, "no diagnostics")
end

diagnostics(severity.ERROR)
line = draw()
at(line, " trunk · " .. glyphs.failed .. " 1")
expect("the failed mark's colour", colour(line, at(line, glyphs.failed)), palette.error)
expect("the error count's colour", colour(line, at(line, glyphs.failed .. " 1") + #glyphs.failed + 1), palette.error)
lacks(line, glyphs.warning, "one error")

diagnostics(severity.WARN, severity.ERROR, severity.WARN, severity.INFO, severity.HINT)
line = draw()
at(line, " trunk · " .. glyphs.failed .. " 1 " .. glyphs.warning .. " 2")
expect("the warning mark's colour", colour(line, at(line, glyphs.warning)), palette.warn)
expect("the warning count's colour", colour(line, at(line, glyphs.warning .. " 2") + #glyphs.warning + 1), palette.warn)
lacks(line, glyphs.info, "an info diagnostic")
lacks(line, glyphs.hint, "a hint")

diagnostics(severity.INFO, severity.HINT)
for _, sign in ipairs(signs) do
  lacks(draw(), sign, "only an info and a hint")
end
diagnostics()

-- An inactive window: the path and the dirty mark, no mode, no colour of its own.
vim.bo.modified = true
local repo_win = vim.api.nvim_get_current_win()
vim.cmd.split(vim.fn.fnameescape(in_worktree))
line = draw(repo_win)
at(line, " src/deep/a.lua " .. glyphs.dirty)
expect("an inactive window starts with the path", at(line, " src/deep/a.lua "), 0)
lacks(line, "normal", "an inactive window")
for _, hl in ipairs(line.highlights) do
  expect("an inactive window's highlight", hl.group, "StatusLineNC")
end
at(draw(), " normal · src/b.lua · ")
vim.cmd.close()
vim.bo.modified = false

-- A detached HEAD, in smo's words.
local commit = { "-C", repo, "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false" }
vim.list_extend(commit, { "-c", "core.hooksPath=/dev/null", "commit", "-q", "--allow-empty", "-m", "x" })
git(unpack(commit))
git("-C", repo, "checkout", "-q", "--detach")
at(draw(), " · src/deep/a.lua · " .. glyphs.branch .. " detached HEAD")
git("-C", repo, "checkout", "-q", "trunk")
at(draw(), " · src/deep/a.lua · " .. glyphs.branch .. " trunk")

-- 4. A note: its kind's glyph, @project, the short id in the note id's colour and the
-- slug from its file's name, in place of the path. smo's config is a temp file.
local notes = vim.fs.joinpath(tmp, "smol_office-notes")
vim.env.SMO_CONFIG = put(vim.fs.joinpath(tmp, "smo.toml"), ("notes_dir = %q\n"):format(notes))
git("init", "-q", "-b", "main", notes)

local function note(id, fields)
  local text = ("---\nid: %s\n%s\ncreated: 2026-10-01T21:56:00+03:00\n---\n\n# A note\n"):format(id, fields)
  return put(vim.fs.joinpath(notes, "inbox", id .. "-a-note.md"), text)
end

edit(note("20261001T2156-host-c6myiynr", "kind: todo\nproject: nvim\nstatus: open"))
assert(vim.b.smo_note, "the fixture is not a note to notes.lua")
line = draw()
local note_at = at(line, " normal · " .. glyphs.todo .. " @nvim c6myiynr a-note · " .. glyphs.branch .. " main")
lacks(line, "inbox", "a note")
local id_at = at(line, "c6myiynr")
local id_fg, id_group = colour(line, id_at)
expect("the short id's group", id_group, "SmolNoteId")
expect("the short id's colour", id_fg, palette.id)
for byte = note_at, id_at - 1 do
  local _, group = colour(line, byte)
  assert(group ~= "SmolNoteId", "magenta before the id, at byte " .. byte)
end
local _, after = colour(line, id_at + #"c6myiynr")
assert(after ~= "SmolNoteId", "magenta after the id")

vim.bo.modified = true
at(draw(), " @nvim c6myiynr a-note " .. glyphs.dirty .. " · ")
vim.bo.modified = false

-- A note without a project, and one of a kind the glyph table does not have: the word.
edit(note("20261002T0900-host-abcd2345", "kind: idea\nstatus: open"))
at(draw(), " normal · " .. glyphs.idea .. " abcd2345 a-note · ")
edit(note("20261002T0901-host-efgh6789", "kind: question\nproject: office\nstatus: open"))
at(draw(), " normal · question @office efgh6789 a-note · ")

-- A note whose file is named by its id alone has no slug to show.
local bare = "---\nid: 20261002T0902-host-ijkm2345\nkind: fix\nstatus: open\n---\n"
edit(put(vim.fs.joinpath(notes, "inbox", "20261002T0902-host-ijkm2345.md"), bare))
assert(vim.b.smo_note, "the bare fixture is not a note to notes.lua")
at(draw(), " normal · " .. glyphs.fix .. " ijkm2345 · ")

-- Markdown that is no note keeps its path.
edit(put(vim.fs.joinpath(notes, "README.md"), "# Notes\n"))
assert(not vim.b.smo_note, "the README is a note to notes.lua")
at(draw(), " normal · README.md · " .. glyphs.branch .. " main")

-- A buffer that is no file says what it is: help with its file, others their filetype.
vim.cmd.help("help")
at(draw(), " normal · help · helphelp.txt")
vim.cmd.close()

vim.cmd.enew()
vim.bo.buftype = "nofile"
vim.bo.filetype = "NeogitStatus"
line = draw()
at(line, " normal · neogitstatus")
lacks(line, glyphs.branch, "a buffer that is no file")
-- Such a buffer has no position worth showing; the explorer's window (a snacks layout
-- box) is called what it is.
expect("a buffer that is no file ends after its name", vim.trim(line.str), "normal · neogitstatus")
vim.bo.filetype = "snacks_layout_box"
expect("the explorer's window", vim.trim(draw().str), "normal · explorer")

-- A window too narrow for the line: the branch gives way first, from its left (its end
-- tells branches apart), and the counts keep clear of the position.
local function narrow(path, width)
  vim.cmd("silent! only")
  edit(path)
  vim.cmd.vsplit()
  vim.cmd(("vertical resize %d"):format(width))
  expect("the window's width", vim.api.nvim_win_get_width(0), width)
  local got = vim.api.nvim_eval_statusline(vim.o.statusline, { highlights = true })
  expect("the narrow line's width", got.width, width)
  return got
end

-- A `smo work` branch is named as the dash names its note: smo/ and the short id.
git("-C", repo, "checkout", "-q", "-b", "smo/20261001T2156-host-name-c6myiynr")
edit(in_repo)
line = draw()
at(line, " · src/deep/a.lua · " .. glyphs.branch .. " smo/c6myiynr")
lacks(line, "20261001T2156", "a smo work branch")
-- Another branch under smo/ keeps its whole name.
git("-C", repo, "checkout", "-q", "-b", "smo/not-a-note")
at(draw(), " · src/deep/a.lua · " .. glyphs.branch .. " smo/not-a-note")

vim.o.columns = 200
git("-C", repo, "checkout", "-q", "-b", "a-long-feature-branch-with-a-long-name-c6myiynr")
edit(in_repo)
diagnostics(severity.ERROR)
line = narrow(in_repo, 60)
at(line, " normal · src/deep/a.lua · " .. glyphs.branch .. " <")
at(line, "c6myiynr · " .. glyphs.failed .. " 1 ")
assert(line.str:match(" 1 +%d+:%d+ $"), "the count runs into the position: " .. line.str)
diagnostics()

-- A path that fills the window alone loses its start, never the file's name, and the
-- branch is left out.
local long = ("a-long-directory-name/"):rep(4) .. "the-file.lua"
line = narrow(put(vim.fs.joinpath(repo, long)), 60)
at(line, " normal · <")
at(line, "/the-file.lua ")
lacks(line, glyphs.branch, "a path wider than the window")
lacks(line, ">", "a path wider than the window")
vim.cmd("silent! only")
git("-C", repo, "checkout", "-q", "trunk")

vim.fn.delete(tmp, "rf")
