-- The buffer's project: its git root, or nvim's own cwd outside a repo. The pickers and
-- the explorer open there, so nvim started from ~ by the dash's `e` searches the note's
-- repo, and a `smo work` worktree (where `.git` is a file) is its own project.

local M = {}

---@param buf integer a buffer, 0 for the current one
---@return string
function M.get(buf)
  return vim.fs.root(buf, ".git") or assert(vim.uv.cwd())
end

return M
