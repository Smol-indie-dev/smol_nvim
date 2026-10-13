-- ␣? opens the keys float: the keymaps used most, inside the editor (the start screen has
-- no cheat sheet). Read from the real keymaps when it opens, so nothing here is kept by
-- hand: every leader map, the config's other normal-mode maps, the buffer's own maps with
-- a description (gitsigns' hunks, LSP's K) and nvim's LSP defaults (grr, gra, ...); then
-- the config's visual-mode maps, the key marked `v`. nvim's other defaults (gcc, [q, gx,
-- ...) stay out.

local M = {}

-- The config's maps carry the script id of the file that sourced it (init.lua), read back
-- from ␣? itself below. nvim's own defaults are Lua's (a negative id): never the config's.
local config_sid

-- `vim.lsp.buf.code_action()` -> `code action`.
local function label(desc)
  local lsp = desc:match("^vim%.lsp%.(.-)%(%)$")
  if lsp then
    desc = lsp:gsub("^buf%.", ""):gsub("[._]", " ")
  end
  return desc:lower()
end

local function shown(m)
  if not m.desc then
    return false
  end
  return m.lhs:sub(1, 1) == " " or m.buffer == 1 or m.sid == config_sid or m.desc:find("^vim%.lsp%.") ~= nil
end

local function key(lhs)
  if lhs:sub(1, 1) == " " then
    return "␣ " .. lhs:sub(2)
  end
  return lhs
end

local function by_key(a, b)
  return a[1] < b[1]
end

-- The rows for `buf`, as { key, desc }: the leader maps first, then the rest, each sorted;
-- a buffer's own map wins over a global one with the same keys.
local function rows(buf, mode)
  local by_lhs = {}
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    by_lhs[m.lhs] = m
  end
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    by_lhs[m.lhs] = m
  end
  local leader, other = {}, {}
  for lhs, m in pairs(by_lhs) do
    if shown(m) then
      table.insert(lhs:sub(1, 1) == " " and leader or other, { key(lhs), label(m.desc) })
    end
  end
  table.sort(leader, by_key)
  table.sort(other, by_key)
  return vim.list_extend(leader, other)
end

-- Normal mode's rows, then visual mode's with `v ` before the key.
function M.rows(buf)
  local all = rows(buf, "n")
  for _, r in ipairs(rows(buf, "v")) do
    all[#all + 1] = { "v " .. r[1], r[2] }
  end
  return all
end

function M.open()
  local rows = M.rows(vim.api.nvim_get_current_buf())
  local key_w, desc_w = 0, 0
  for _, r in ipairs(rows) do
    key_w = math.max(key_w, vim.fn.strdisplaywidth(r[1]))
    desc_w = math.max(desc_w, vim.fn.strdisplaywidth(r[2]))
  end
  local cell = 1 + key_w + 2 + desc_w + 1
  -- As many columns as the rows need to fit the screen's height.
  local max_h = math.max(vim.o.lines - 6, 1)
  local cols = math.min(math.ceil(#rows / max_h), math.max(math.floor((vim.o.columns - 4) / cell), 1))
  local height = math.ceil(#rows / cols)

  local lines, marks = {}, {}
  for i = 1, height do
    local line = ""
    for c = 0, cols - 1 do
      local r = rows[c * height + i]
      if r then
        local k = r[1] .. string.rep(" ", key_w - vim.fn.strdisplaywidth(r[1]))
        local d = r[2] .. string.rep(" ", desc_w - vim.fn.strdisplaywidth(r[2]))
        table.insert(marks, { i - 1, #line + 1, #line + 1 + #r[1] })
        line = line .. " " .. k .. "  " .. d .. " "
      end
    end
    lines[i] = line
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ns = vim.api.nvim_create_namespace("smol_keys")
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = "SmolKey" })
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "smol_keys"

  local width = math.min(cell * cols, vim.o.columns - 2)
  height = math.min(height, max_h)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    title = " keys ",
    title_pos = "center",
  })
  for _, lhs in ipairs({ "q", "<Esc>", "<leader>?" }) do
    vim.keymap.set("n", lhs, function()
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, nowait = true })
  end
end

vim.keymap.set("n", "<leader>?", M.open, { desc = "Keys" })
config_sid = vim.fn.maparg("<leader>?", "n", false, true).sid
if config_sid <= 0 then
  config_sid = nil
end

return M
