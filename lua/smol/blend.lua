-- Colours the palette has no role for (diff backgrounds, the search match, Neogit's
-- backgrounds): a role mixed into bg by a named amount, so each stays one of smol's.

local palette = require("smol.palette")

local M = {}

-- `color` mixed into `base`: 0 is the base, 1 the colour.
function M.mix(color, base, amount)
  local out = {}
  for i = 1, 3 do
    local c = tonumber(color:sub(2 * i, 2 * i + 1), 16)
    local b = tonumber(base:sub(2 * i, 2 * i + 1), 16)
    out[i] = math.floor(b + (c - b) * amount + 0.5)
  end
  return string.format("#%02x%02x%02x", out[1], out[2], out[3])
end

local function into_bg(role, amount)
  return M.mix(palette[role], palette.bg, amount)
end

M.named = {
  diff_add = into_bg("ok", 0.15),
  diff_change = into_bg("warn", 0.15),
  diff_delete = into_bg("error", 0.15),
  -- The changed words inside a changed line.
  diff_text = into_bg("warn", 0.3),
  search = into_bg("accent", 0.4),
  -- Backgrounds a step above bg each, for Neogit's sections and cursor line.
  bg1 = into_bg("fg", 0.04),
  bg2 = into_bg("fg", 0.08),
  bg3 = into_bg("fg", 0.14),
}

return M
