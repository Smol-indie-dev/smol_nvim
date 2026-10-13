-- Format on save follows the repo: a formatter runs only when one of its config files is
-- in the file's directory or an ancestor, up to the buffer's git root. rustfmt always
-- runs. Every fixture lives in a temp dir.

local conform = require("conform")

-- The real language servers stay out of this: whether one would format on save is
-- tested at the end, with a server that answers at once.
for _, config in ipairs(vim.lsp.get_configs({ enabled = true })) do
  vim.lsp.enable(config.name, false)
end

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

-- A fresh dir under the temp dir holding `files` (relative path → content).
local count = 0
local function tree(files)
  count = count + 1
  local dir = vim.fs.joinpath(tmp, tostring(count))
  for rel, text in pairs(files) do
    put(vim.fs.joinpath(dir, rel), text)
  end
  return dir
end

local function git_init(dir)
  vim.fn.mkdir(dir, "p")
  local result = vim.system({ "git", "init", "-q", dir }):wait()
  assert(result.code == 0, "git init: " .. result.stderr)
end

-- `:w` on the file; returns its bytes before and after.
local function save(path)
  local before = bytes(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.cmd.write()
  vim.cmd.bwipeout()
  return before, bytes(path)
end

local function untouched(path, why)
  local before, after = save(path)
  assert(after == before, ("%s: %s was rewritten:\n%s"):format(why, path, after))
end

local function formatted(path, why)
  local before, after = save(path)
  assert(after ~= before, ("%s: %s was not formatted"):format(why, path))
  return after
end

local function has(text, part, why)
  assert(text:find(part, 1, true), ("%s: expected %q in:\n%s"):format(why, part, text))
end

-- One file per formatter, each written so that its formatter would change it. The note
-- has the shape of a smol office note: prettier indents the tags and pads the table.
local note = table.concat({
  "---",
  "id: 20261001T0000-host-abcd1234",
  "created: 2026-10-01T00:00:00+03:00",
  "kind: todo",
  "tags:",
  "- one",
  "- two",
  "status: open",
  "---",
  "A note.",
  "",
  "| a | b |",
  "|---|---|",
  "| longer cell | x |",
  "",
}, "\n")
local sloppy = {
  ["x.md"] = note,
  ["x.css"] = "a{color:red}\n",
  ["x.html"] = "<div>\n<p>x</p>\n</div>\n",
  ["x.lua"] = "local x   =   1\nif x then\nreturn x\nend\n",
  ["x.ts"] = "const x   =  1\n",
  ["x.json"] = '{"a":1,   "b":[1,2]}\n',
  ["x.astro"] = "---\nconst x   =  1\n---\n<p>hi</p>\n",
  ["x.toml"] = "a   =   1\nlonger = 2\n",
  ["x.yaml"] = "b:\n- x\n",
  ["x.sh"] = "if true; then\necho hi\nfi\n",
}

-- Every formatter's config, each with one setting that is not the tool's default, to
-- show that the config found is the config used.
local stylua_2 = 'indent_type = "Spaces"\nindent_width = 2\n'
local stylua_4 = 'indent_type = "Spaces"\nindent_width = 4\n'
local taplo_aligned = "[formatting]\nalign_entries = true\n"
local configs = {
  [".prettierrc"] = "{}\n",
  ["biome.json"] = "{}\n",
  ["stylua.toml"] = stylua_2,
  ["taplo.toml"] = taplo_aligned,
  [".yamlfmt"] = "formatter:\n  type: basic\n  indent: 6\n",
  [".editorconfig"] = "root = true\n\n[*.sh]\nindent_style = space\nindent_size = 3\n",
}

local function with_prefix(prefix, files)
  local out = {}
  for rel, text in pairs(files) do
    out[prefix .. rel] = text
  end
  return out
end

-- Plan test 1: a note, laid out as in the notes repo, keeps its bytes.
do
  local dir = tree({ ["smol_office-notes/inbox/20261001T0000-host-abcd1234-x.md"] = note })
  git_init(dir .. "/smol_office-notes")
  untouched(dir .. "/smol_office-notes/inbox/20261001T0000-host-abcd1234-x.md", "a note")
end

-- Plan tests 2-5 and 7, a repo without any formatter config: nothing is rewritten,
-- except Rust.
do
  local dir = tree(vim.tbl_extend("error", { ["x.rs"] = "fn main(){let x=1;}\n" }, sloppy))
  git_init(dir)
  for rel in pairs(sloppy) do
    untouched(vim.fs.joinpath(dir, rel), "repo without configs")
  end
  has(formatted(dir .. "/x.rs", "rustfmt always runs"), "fn main() {\n    let x = 1;\n}", "rustfmt")

  -- A formatter that does not run here is the rule, not something to warn about.
  local messages = vim.api.nvim_exec2("messages", { output = true }).output
  assert(not messages:find("Formatters unavailable"), "saving warned:\n" .. messages)
end

-- Plan tests 2-5 and 6, configs at the git root and the files several dirs below:
-- everything is formatted, with the settings of the config found.
do
  local dir = tree(vim.tbl_extend("error", with_prefix("a/b/", sloppy), configs))
  git_init(dir)
  local out = {}
  for rel in pairs(sloppy) do
    out[rel] = formatted(vim.fs.joinpath(dir, "a/b", rel), "config at the git root")
  end
  has(out["x.md"], "tags:\n  - one\n", "prettierd on Markdown")
  has(out["x.lua"], "\n  return x\n", "stylua.toml's indent")
  has(out["x.ts"], "const x = 1;", "biome on TypeScript")
  has(out["x.astro"], "const x = 1;", "biome on Astro")
  has(out["x.toml"], "a      = 1\nlonger = 2\n", "taplo.toml's align_entries")
  has(out["x.yaml"], "b:\n      - x\n", ".yamlfmt's indent")
  has(out["x.sh"], "\n   echo hi\n", "a parent .editorconfig's indent for shfmt")
end

-- Plan test 6, configs above the git root: they do not count.
do
  local dir = tree(vim.tbl_extend("error", with_prefix("repo/", sloppy), configs))
  git_init(dir .. "/repo")
  for rel in pairs(sloppy) do
    untouched(vim.fs.joinpath(dir, "repo", rel), "config above the git root")
  end
end

-- A config in the repo counts even when a config with a different name sits above the
-- git root.
do
  local dir = tree({
    ["stylua.toml"] = stylua_4,
    ["repo/.stylua.toml"] = stylua_2,
    ["repo/x.lua"] = sloppy["x.lua"],
  })
  git_init(dir .. "/repo")
  has(formatted(dir .. "/repo/x.lua", ".stylua.toml in the repo"), "\n  return x\n", "the repo's .stylua.toml")
end

-- Plan test 6, a nested package with its own config: the nearest one is used.
do
  local dir = tree({
    ["stylua.toml"] = stylua_2,
    ["taplo.toml"] = "",
    ["x.lua"] = sloppy["x.lua"],
    ["x.toml"] = sloppy["x.toml"],
    ["pkg/stylua.toml"] = stylua_4,
    ["pkg/taplo.toml"] = taplo_aligned,
    ["pkg/src/x.lua"] = sloppy["x.lua"],
    ["pkg/src/x.toml"] = sloppy["x.toml"],
  })
  git_init(dir)
  has(formatted(dir .. "/x.lua", "root config"), "\n  return x\n", "the root's stylua.toml")
  has(formatted(dir .. "/pkg/src/x.lua", "nested config"), "\n    return x\n", "the package's stylua.toml")
  has(formatted(dir .. "/x.toml", "root config"), "a = 1\nlonger = 2\n", "the root's taplo.toml")
  has(formatted(dir .. "/pkg/src/x.toml", "nested config"), "a      = 1\n", "the package's taplo.toml")
end

-- Outside a repo only the file's own directory counts.
do
  local dir = tree({
    ["stylua.toml"] = stylua_2,
    ["x.lua"] = sloppy["x.lua"],
    ["sub/x.lua"] = sloppy["x.lua"],
  })
  formatted(dir .. "/x.lua", "no repo, config beside the file")
  untouched(dir .. "/sub/x.lua", "no repo, config in a parent")
end

-- Plan test 3: `:w` on this repo's own Lua files changes nothing (on copies).
do
  local config = vim.fn.stdpath("config")
  local files = { ["stylua.toml"] = bytes(config .. "/stylua.toml") }
  local lua = { "init.lua" }
  for _, pattern in ipairs({ "lua/**/*.lua", "tests/*.lua" }) do
    for _, path in ipairs(vim.fn.globpath(config, pattern, false, true)) do
      table.insert(lua, assert(vim.fs.relpath(config, path)))
    end
  end
  for _, rel in ipairs(lua) do
    files[rel] = bytes(vim.fs.joinpath(config, rel))
  end
  assert(#lua > 10, "found only " .. #lua .. " Lua files in " .. config)
  local dir = tree(files)
  git_init(dir)
  for _, rel in ipairs(lua) do
    untouched(vim.fs.joinpath(dir, rel), "this repo's own Lua")
  end
end

-- A language server that can format is no way around the rule: with no formatter to
-- run, saving does not fall back to it.
do
  local dir = tree({ ["x.lua"] = sloppy["x.lua"] })
  git_init(dir)
  local path = dir .. "/x.lua"
  local stamp = "-- formatted by the server\n"
  local top = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } }
  local function server()
    local id = 0
    return {
      request = function(method, _, callback)
        id = id + 1
        local result = vim.NIL
        if method == "initialize" then
          result = { capabilities = { documentFormattingProvider = true } }
        elseif method == "textDocument/formatting" then
          result = { { range = top, newText = stamp } }
        end
        vim.schedule(function()
          callback(nil, result)
        end)
        return true, id
      end,
      notify = function()
        return true
      end,
      is_closing = function()
        return false
      end,
      terminate = function() end,
    }
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  vim.lsp.start({ name = "fake-formatter", cmd = server, root_dir = dir }, { bufnr = buf })
  local function attached()
    return #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/formatting" }) > 0
  end
  assert(vim.wait(2000, attached), "the fake server did not attach")

  vim.cmd.write()
  assert(bytes(path) == sloppy["x.lua"], "saving fell back to the language server:\n" .. bytes(path))

  -- Control: asked to, conform does format through this server.
  conform.format({ bufnr = buf, lsp_format = "fallback" })
  assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] .. "\n" == stamp, "control: the fake server cannot format")
  vim.cmd.bwipeout({ bang = true })
end
