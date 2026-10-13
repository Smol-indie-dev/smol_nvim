-- README.md: its Keys table is what ␣? shows on a plain buffer, and it holds no comment
-- but the two blocks, smo readme's panel and the keys: the template's comments and
-- example lines never reach the README.

local path = vim.fn.stdpath("config") .. "/README.md"
local file = io.open(path, "r")
assert(file, "no README.md at " .. path)
local text = file:read("*a")
file:close()

-- 1. One hud block, one keys block, and no other comment.
local function count(s)
  local n = 0
  for _ in text:gmatch(vim.pesc(s)) do
    n = n + 1
  end
  return n
end
for _, marker in ipairs({
  "<!-- smol:readme hud -->",
  "<!-- /smol:readme -->",
  "<!-- nvim:keys -->",
  "<!-- /nvim:keys -->",
}) do
  assert(count(marker) == 1, marker .. " found " .. count(marker) .. " times, want 1")
end
assert(count("<!--") == 4, "a comment besides the hud and keys blocks: " .. count("<!--") .. " `<!--`, want 4")
assert(
  text:find("<!-- smol:readme hud -->", 1, true) < text:find("<!-- /smol:readme -->", 1, true),
  "the hud block's end comes before its start"
)

-- 2. The keys block is the float's rows on a plain buffer, as a table.
vim.cmd.enew()
local rows = { "| Key | What |", "|---|---|" }
for _, r in ipairs(require("config.keys").rows(0)) do
  assert(not (r[1] .. r[2]):find("[|`]"), "a row the table cannot hold: " .. r[1] .. " " .. r[2])
  rows[#rows + 1] = ("| `%s` | %s |"):format(r[1], r[2])
end
local want = table.concat(rows, "\n")

local got = text:match("<!%-%- nvim:keys %-%->\n(.-)\n<!%-%- /nvim:keys %-%->")
assert(got, "the keys block's markers are not on lines of their own, start before end")
assert(got == want, "README.md's keys block differs from ␣?; it should read:\n" .. want .. "\n\nit reads:\n" .. got)
