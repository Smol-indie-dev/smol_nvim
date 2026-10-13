-- Pickers and the explorer follow the buffer's project: the root is the buffer's git
-- root, a worktree's included, and nvim's own cwd outside a repo. ␣ff, ␣fg, ␣fr and ␣e
-- pass it as `cwd`, and so do ␣gg, ␣gl and :Neogit. Every fixture lives in a temp dir;
-- the real pickers need a live look.

local root = require("smol.root")

-- Resolved, so the roots compare equal even when the temp dir is behind a symlink.
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
tmp = assert(vim.uv.fs_realpath(tmp))
assert(not vim.fs.root(tmp, ".git"), "the temp dir is inside a git repo: " .. tmp)

local function git(...)
  local result = vim.system({ "git", ... }):wait()
  assert(result.code == 0, ("git %s: %s"):format(table.concat({ ... }, " "), result.stderr))
end

local function put(path)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  assert(io.open(path, "wb")):close()
  return path
end

local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function expect(what, got, want)
  assert(got == want, ("%s: want %s, got %s"):format(what, want, vim.inspect(got)))
end

local repo = vim.fs.joinpath(tmp, "repo")
local worktree = vim.fs.joinpath(tmp, "worktree")
local plain = vim.fs.joinpath(tmp, "plain")
local elsewhere = vim.fs.joinpath(tmp, "elsewhere")

git("init", "-q", repo)
-- A real linked worktree, as `smo work` makes them: its `.git` is a file.
git("-C", repo, "worktree", "add", "-q", "--orphan", "-b", "work", worktree)
expect(".git in the worktree", vim.uv.fs_stat(vim.fs.joinpath(worktree, ".git")).type, "file")

local in_repo = put(vim.fs.joinpath(repo, "src", "deep", "a.lua"))
local in_worktree = put(vim.fs.joinpath(worktree, "src", "b.lua"))
local in_plain = put(vim.fs.joinpath(plain, "sub", "c.lua"))

-- nvim's cwd is none of the projects, as when the dash's `e` starts it from ~.
vim.fn.mkdir(elsewhere, "p")
vim.cmd.cd(vim.fn.fnameescape(elsewhere))

-- 1. A file in a repo, and in a worktree: the git root, whatever the cwd.
edit(in_repo)
expect("root in a repo", root.get(0), repo)
local repo_buf = vim.api.nvim_get_current_buf()

edit(in_worktree)
expect("root in a worktree", root.get(0), worktree)
expect("root of another buffer", root.get(repo_buf), repo)

-- 3. Outside a repo: nvim's own cwd, not the file's directory.
edit(in_plain)
expect("root outside a repo", root.get(0), elsewhere)

-- A buffer with no file has no project of its own either.
vim.cmd.enew()
expect("root of an unnamed buffer", root.get(0), elsewhere)

-- 2. The keys pass that root as `cwd`. The pickers are stubbed to capture their
-- options: headless nvim cannot open them.
local fzf = require("fzf-lua")
local calls = {}
local function capture(name)
  return function(opts)
    calls[#calls + 1] = { name = name, opts = opts }
  end
end
fzf.files = capture("files")
fzf.live_grep = capture("live_grep")
fzf.oldfiles = capture("oldfiles")
Snacks.explorer = capture("explorer")

local keys = {
  { "<leader>ff", "files" },
  { "<leader>fg", "live_grep" },
  { "<leader>fr", "oldfiles" },
  { "<leader>e", "explorer" },
}

local function press(lhs)
  calls = {}
  vim.api.nvim_feedkeys(vim.keycode(lhs), "mx", false)
  return calls
end

for _, case in ipairs({
  { in_repo, repo, "in a repo" },
  { in_worktree, worktree, "in a worktree" },
  { in_plain, elsewhere, "outside a repo" },
}) do
  local file, want, where = case[1], case[2], case[3]
  edit(file)
  for _, key in ipairs(keys) do
    local lhs, name = key[1], key[2]
    local what = ("%s %s"):format(lhs, where)
    local got = press(lhs)
    assert(#got == 1, ("%s: want one call, got %s"):format(what, vim.inspect(got)))
    expect(what .. " calls", got[1].name, name)
    assert(type(got[1].opts) == "table", what .. ": called without options")
    expect(what .. " cwd", got[1].opts.cwd, want)
  end
end

-- Neogit too: left to itself it opens nvim's cwd, and from ~ asks to init a repo there.
-- Its open() is stubbed; :Neogit is called the way smol types it.
local neogit = require("neogit")
neogit.open = capture("neogit")

local function run(cmd)
  calls = {}
  vim.cmd(cmd)
  return calls
end

for _, case in ipairs({
  { in_repo, repo, "in a repo" },
  { in_worktree, worktree, "in a worktree" },
  { in_plain, elsewhere, "outside a repo" },
}) do
  local file, want, where = case[1], case[2], case[3]
  edit(file)
  for _, step in ipairs({
    { "<leader>gg", press },
    { "<leader>gl", press, "log" },
    { "Neogit", run },
    { "Neogit log", run, "log" },
    { "Neogit kind=split", run, nil, "split" },
  }) do
    local what = ("%s %s"):format(step[1], where)
    local got = step[2](step[1])
    assert(#got == 1, ("%s: want one call, got %s"):format(what, vim.inspect(got)))
    local opts = got[1].opts
    assert(type(opts) == "table", what .. ": called without options")
    expect(what .. " cwd", opts.cwd, want)
    expect(what .. " popup", opts[1], step[3])
    expect(what .. " kind", opts.kind, step[4])
  end
end

-- An explicit cwd= still wins.
edit(in_repo)
local got = run("Neogit cwd=" .. worktree)
expect(":Neogit cwd= cwd", got[1].opts.cwd, worktree)

vim.fn.delete(tmp, "rf")
