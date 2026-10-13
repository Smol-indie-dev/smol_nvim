-- Notes belong to smo. A note opened from the notes repo gets `b:smo_note = { id, kind,
-- project, status }` for display; formatting.lua leaves everything under the notes path
-- alone. This file never writes a note.

local M = {}

-- smo's own lookup (smol_office `src/paths.rs`, `src/config.rs`): `$SMO_CONFIG`, else
-- `$XDG_CONFIG_HOME/smol_office/config.toml`; its top-level `notes_dir`, else the default.
local default_dir = "~/dev/smol_office-notes"

local function config_file()
  if vim.env.SMO_CONFIG and vim.env.SMO_CONFIG ~= "" then
    return vim.env.SMO_CONFIG
  end
  local base = vim.env.XDG_CONFIG_HOME
  if not base or base == "" then
    base = vim.fs.normalize("~/.config")
  end
  return vim.fs.joinpath(base, "smol_office", "config.toml")
end

-- The notes repo's absolute path, read on every call: the config is a few lines.
function M.dir()
  local dir = default_dir
  local file = io.open(config_file(), "r")
  if file then
    for line in file:lines() do
      if line:match("^%s*%[") then
        break -- top-level keys come before the first table
      end
      local value = line:match('^%s*notes_dir%s*=%s*"([^"]*)"') or line:match("^%s*notes_dir%s*=%s*'([^']*)'")
      if value then
        dir = value
      end
    end
    file:close()
  end
  return vim.fs.normalize(dir)
end

-- Whether `path` is the notes repo or under it.
function M.owns(path)
  return path ~= "" and vim.fs.relpath(M.dir(), vim.fs.normalize(path)) ~= nil
end

-- A value YAML reads as a plain string and nothing else: no quotes, comments, flow or
-- block forms, anchors, tags, nested mappings, nulls, booleans or numbers.
local function plain(value)
  if value == "" or value:find("^[%-?:,%[%]{}#&*!|>'\"%%@`]") then
    return nil
  end
  if value:find(" #", 1, true) or value:find(": ", 1, true) or value:find(":$") then
    return nil
  end
  local lower = value:lower()
  if lower == "~" or lower == "null" or lower == "true" or lower == "false" or tonumber(value) then
    return nil
  end
  return value
end

local fields = { id = true, kind = true, project = true, status = true }

-- Best effort, for display only: the first `---` block, and of it only `id`, `kind`,
-- `project` and `status` as plain `key: value` lines. Anything else about those four keys
-- means nil: nothing is guessed. smo itself parses real YAML.
function M.read(lines)
  if (lines[1] or ""):gsub("\r$", "") ~= "---" then
    return nil
  end
  local note = {}
  local last -- the key on the line before, to catch a continued value
  for i = 2, #lines do
    local line = lines[i]:gsub("\r$", "")
    if line == "---" then
      if not (note.id and note.kind and note.status) then
        return nil
      end
      return note
    end
    if last and line:find("^%s+%S") then
      return nil -- the value goes on below its key
    end
    last = nil
    local key, rest = line:match("^(%w+):(.*)$")
    if key and fields[key] then
      local value = plain(vim.trim(rest))
      if note[key] or not value or not rest:find("^ ") then
        return nil
      end
      note[key] = value
      last = key
    end
  end
  return nil -- no closing `---`
end

local function note_file(path)
  local rel = vim.fs.relpath(M.dir(), vim.fs.normalize(path))
  return rel and (rel:find("^inbox/[^/]+%.md$") or rel:find("^runs/[^/]+/[^/]+%.md$")) ~= nil
end

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("smol_notes", { clear = true }),
  pattern = "*.md",
  callback = function(ev)
    if note_file(ev.match) then
      vim.b[ev.buf].smo_note = M.read(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false))
    end
  end,
})

return M
