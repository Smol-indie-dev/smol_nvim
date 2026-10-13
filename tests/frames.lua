-- Framed floats are square, like smo's TUI. Config values only: the real windows (fzf,
-- blink, Neogit popups) need a live look.

local single = { "┌", "─", "┐", "│", "┘", "─", "└", "│" }

local function expect_single(what, border)
  assert(vim.deep_equal(border, single), string.format("%s: want single, got %s", what, vim.inspect(border)))
end

-- 1. winborder, and a float opened without a border.
assert(vim.o.winborder == "single", "winborder: want single, got " .. vim.inspect(vim.o.winborder))
local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_open_win(buf, false, { relative = "editor", row = 1, col = 1, width = 10, height = 2 })
expect_single("nvim_open_win", vim.api.nvim_win_get_config(win).border)
vim.api.nvim_win_close(win, true)

-- 2. An LSP-style float.
local _, lsp_win = vim.lsp.util.open_floating_preview({ "hover" }, "markdown", {})
expect_single("open_floating_preview", vim.api.nvim_win_get_config(lsp_win).border)
vim.api.nvim_win_close(lsp_win, true)

-- 3. Resolved plugin settings.
local fzf = require("fzf-lua.config").globals.winopts
assert(fzf.border == "single", "fzf-lua winopts.border: " .. vim.inspect(fzf.border))
assert(fzf.preview.border == "single", "fzf-lua winopts.preview.border: " .. vim.inspect(fzf.preview.border))

local neogit = require("neogit.config").values.floating
assert(neogit.border == "single", "neogit floating.border: " .. vim.inspect(neogit.border))

-- blink leaves border nil and falls back to winborder (blink lib/window/utils.lua).
local blink = require("blink.cmp.config")
local pick = require("blink.cmp.lib.window.utils").pick_border
for what, border in pairs({
  ["completion.menu"] = blink.completion.menu.border,
  ["completion.documentation"] = blink.completion.documentation.window.border,
  ["signature"] = blink.signature.window.border,
}) do
  local got = pick(border, "padded")
  assert(got == "single", string.format("blink %s.border: want single, got %s", what, vim.inspect(got)))
end
