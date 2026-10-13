-- Notes belong to smo: a note opened from the notes repo gets `b:smo_note` from its
-- frontmatter, read for display only, and saving it never runs a formatter. Every fixture
-- lives in a temp dir; smo's config is a temp file too.

local conform = require("conform")
local notes = require("config.notes")

local tmp = vim.fn.tempname()
assert(not vim.fs.root(tmp, ".git"), "the temp dir is inside a git repo: " .. tmp)

local function put(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local file = assert(io.open(path, "wb"))
  file:write(text)
  file:close()
end

local function bytes(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

local function git_init(dir)
  vim.fn.mkdir(dir, "p")
  local result = vim.system({ "git", "init", "-q", dir }):wait()
  assert(result.code == 0, "git init: " .. result.stderr)
end

local function eq(got, want, why)
  assert(vim.deep_equal(got, want), ("%s: expected %s, got %s"):format(why, vim.inspect(want), vim.inspect(got)))
end

-- The notes path is smo's own: `notes_dir` in `$SMO_CONFIG`, else in
-- `$XDG_CONFIG_HOME/smol_office/config.toml`, else smo's default.
do
  vim.env.SMO_CONFIG = nil
  eq(notes.dir(), vim.fs.normalize("~/dev/smol_office-notes"), "no config file: smo's default")

  put(vim.env.XDG_CONFIG_HOME .. "/smol_office/config.toml", 'notes_dir = "~/elsewhere"\n')
  eq(notes.dir(), vim.fs.normalize("~/elsewhere"), "the XDG config, tilde expanded")

  -- A `notes_dir` inside a table is some other setting.
  put(tmp .. "/other.toml", '[projects]\nnotes_dir = "/nope"\n')
  vim.env.SMO_CONFIG = tmp .. "/other.toml"
  eq(notes.dir(), vim.fs.normalize("~/dev/smol_office-notes"), "notes_dir under a table")
end

local repo = tmp .. "/smol_office-notes"
put(tmp .. "/smo.toml", ("# smo\nnotes_dir = %q # comment\n\n[projects]\nnvim = %q\n"):format(repo, tmp))
vim.env.SMO_CONFIG = tmp .. "/smo.toml"
eq(notes.dir(), repo, "SMO_CONFIG wins")
git_init(repo)
-- prettierd would format every Markdown file in the repo, notes included.
put(repo .. "/.prettierrc", "{}\n")

-- A note in smo's shape that prettier would change: it indents the tags and pads the
-- table.
local function note(fields)
  local lines = { "---" }
  vim.list_extend(lines, fields)
  vim.list_extend(lines, { "---", "A note.", "", "| a | b |", "|---|---|", "| longer cell | x |", "" })
  return table.concat(lines, "\n")
end

local plain = {
  "id: 20261001T0000-host-abcd1234",
  "created: 2026-10-01T00:00:00+03:00",
  "host: host",
  "kind: todo",
  "project: nvim",
  "tags:",
  "- one",
  "- two",
  "status: open",
}

local count = 0
local function open(rel, text)
  count = count + 1
  local path = ("%s/%s"):format(repo, rel:gsub("%%d", tostring(count)))
  put(path, text)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return path, vim.api.nvim_get_current_buf()
end

-- `:w`; the bytes must not change and conform must have nothing to run.
local function saved_as_is(path, buf, why)
  local before = bytes(path)
  eq(#conform.list_formatters_to_run(buf), 0, why .. ": formatters to run")
  vim.cmd("silent write")
  assert(bytes(path) == before, ("%s: %s was rewritten:\n%s"):format(why, path, bytes(path)))
end

local function no_messages(why)
  local messages = vim.api.nvim_exec2("messages", { output = true }).output
  eq(messages, "", why .. ": :messages")
end

-- Plan test 1: a note's frontmatter, its four fields.
do
  local _, buf = open("inbox/%d-x.md", note(plain))
  eq(
    vim.b[buf].smo_note,
    { id = "20261001T0000-host-abcd1234", kind = "todo", project = "nvim", status = "open" },
    "a note"
  )
  vim.cmd.bwipeout()

  -- `project` is the one field smo leaves out.
  local fields = vim.tbl_filter(function(line)
    return not line:find("^project:")
  end, plain)
  _, buf = open("inbox/%d-x.md", note(fields))
  eq(vim.b[buf].smo_note, { id = "20261001T0000-host-abcd1234", kind = "todo", status = "open" }, "no project")
  vim.cmd.bwipeout()

  -- CRLF line ends, which smo also reads.
  _, buf = open("inbox/%d-x.md", (note(plain):gsub("\n", "\r\n")))
  eq(vim.b[buf].smo_note and vim.b[buf].smo_note.status, "open", "CRLF")
  vim.cmd.bwipeout()
end

-- Plan test 1: a plain Markdown file gets none, in the notes repo or outside it.
do
  local path = tmp .. "/elsewhere/inbox/x.md"
  put(path, note(plain))
  vim.cmd.edit(vim.fn.fnameescape(path))
  eq(vim.b.smo_note, nil, "a note-shaped file outside the notes repo")
  vim.cmd.bwipeout()

  local _, buf = open("README.md", note(plain))
  eq(vim.b[buf].smo_note, nil, "the notes repo's README")
  vim.cmd.bwipeout()
end

-- Plan test 2: saving a note runs no formatter, though the repo has a .prettierrc.
do
  local path, buf = open("inbox/%d-x.md", note(plain))
  saved_as_is(path, buf, "a note")
  vim.cmd.bwipeout()

  -- A run record: no note fields, still smo's file.
  path, buf = open("runs/%d-note/20261001T000000-claude-ask-x.md", note({ "run_id: x", "note: y" }))
  eq(vim.b[buf].smo_note, nil, "a run record")
  saved_as_is(path, buf, "a run record")
  vim.cmd.bwipeout()

  -- Anything else under the notes path, by path alone.
  path, buf = open("README.md", note(plain))
  saved_as_is(path, buf, "the notes repo's README")
  vim.cmd.bwipeout()

  -- The control: the same note outside the notes repo is formatted, so the guard above
  -- is what kept the bytes.
  local other = tmp .. "/other-repo"
  git_init(other)
  put(other .. "/.prettierrc", "{}\n")
  put(other .. "/x.md", note(plain))
  vim.cmd.edit(vim.fn.fnameescape(other .. "/x.md"))
  assert(#conform.list_formatters_to_run(0) > 0, "control: prettierd should run outside the notes repo")
  vim.cmd.write()
  assert(bytes(other .. "/x.md") ~= note(plain), "control: the note outside the notes repo was not formatted")
  vim.cmd.bwipeout()
end

vim.cmd("messages clear")

-- Plan tests 3 and 4: frontmatter that does not parse, or a field beyond a plain scalar,
-- leaves `b:smo_note` unset, without a message; the note still saves as is.
do
  local function with(field, line)
    local out = {}
    for _, l in ipairs(plain) do
      table.insert(out, l:find("^" .. field .. ":") and line or l)
    end
    return note(out)
  end
  local broken = {
    ["no frontmatter"] = "A note.\n",
    ["unterminated"] = "---\nid: x\nkind: todo\nstatus: open\nA note.\n",
    ["not on the first line"] = "\n" .. note(plain),
    ["no id"] = with("id", "created2: x"),
    ["no status"] = with("status", "status2: x"),
    ["double quoted"] = with("kind", 'kind: "todo"'),
    ["single quoted"] = with("project", "project: 'nvim'"),
    ["a comment"] = with("status", "status: open # for now"),
    ["a flow sequence"] = with("project", "project: [nvim]"),
    ["a block scalar"] = with("kind", "kind: |"),
    ["empty"] = with("project", "project:"),
    ["null"] = with("project", "project: ~"),
    ["a boolean"] = with("status", "status: true"),
    ["an anchor"] = with("kind", "kind: &k todo"),
    ["a tag"] = with("kind", "kind: !!str todo"),
    ["a mapping"] = with("kind", "kind: a: b"),
    ["continued"] = with("kind", "kind: todo\n  more"),
    ["twice"] = with("status", "status: open\nstatus: done"),
  }
  for why, text in pairs(broken) do
    local path, buf = open("inbox/%d-x.md", text)
    eq(vim.b[buf].smo_note, nil, why)
    saved_as_is(path, buf, why)
    vim.cmd.bwipeout()
  end
  no_messages("broken frontmatter")
end
