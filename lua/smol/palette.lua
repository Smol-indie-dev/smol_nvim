-- The smol office colours nvim uses: the frame and smo's meanings. One source per value:
-- each key is its role in smol_office's setup/config/smol/palette.toml (tests/theme.lua
-- checks the list and each value for drift).
return {
  -- The frame.
  bg = "#141414",
  fg = "#ffffff",
  surface = "#202020",
  dim = "#888888",
  border = "#888888",
  accent = "#8000ff",
  accent_soft = "#d8b4fe",
  selection = "#8000ff",
  cursor = "#d8b4fe",
  -- The meanings: red a failure or a removal, yellow a warning, a change or code, green
  -- ok or an addition, cyan headings, magenta only the note id, blue a link.
  error = "#ff757f",
  warn = "#ffc777",
  ok = "#c3e88d",
  info = "#86e1fc",
  id = "#c099ff",
  net = "#82aaff",
}
