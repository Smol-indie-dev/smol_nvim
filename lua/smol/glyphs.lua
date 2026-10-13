-- The glyphs nvim's own UI uses, one meaning each, smo's. All are Nerd Font `nf-fa-*`
-- codepoints (U+F000 to U+F2E0), one cell wide, as in smo.
-- A value is the bare glyph: the caller adds the space smo's strings carry.
-- tests/glyphs.lua checks the smo entries for drift and the others for reuse.
return {
  -- smo's set: smol_office src/dash/glyph.rs, NERD. Same names, same meanings.
  branch = "\u{f126}", -- nf-fa-code_fork: before a branch name
  clean = "\u{f00c}", -- nf-fa-check: a clean tree
  dirty = "\u{f040}", -- nf-fa-pencil: uncommitted or unsaved changes
  unsynced = "\u{f0ee}", -- nf-fa-cloud_upload: commits to push
  outside = "\u{f0c0}", -- nf-fa-users: an outside project
  worktree = "\u{f07c}", -- nf-fa-folder_open: a worktree
  failed = "\u{f06a}", -- nf-fa-exclamation_circle: a failure
  warning = "\u{f071}", -- nf-fa-warning: a warning
  loading = "\u{f021}", -- nf-fa-refresh: loads in flight
  running = "\u{f04b}", -- nf-fa-play: a session starting or running
  idea = "\u{f0eb}", -- nf-fa-lightbulb_o: note kind
  fix = "\u{f0ad}", -- nf-fa-wrench: note kind
  plan = "\u{f022}", -- nf-fa-list_alt: note kind
  todo = "\u{f046}", -- nf-fa-check_square_o: note kind
  log = "\u{f0f6}", -- nf-fa-file_text_o: note kind

  -- smo's plan phase marks (NERD.phase). Plain Unicode, not Nerd Font.
  phase = { done = "✓", now = "◐", todo = "○", dropped = "–", unknown = "?" },

  -- nvim only: nothing in smo has these meanings, and none is one of smo's codepoints.
  search = "\u{f002}", -- nf-fa-search: find a file
  folder = "\u{f07b}", -- nf-fa-folder: the explorer
  file = "\u{f15b}", -- nf-fa-file: a new file
  text = "\u{f036}", -- nf-fa-align_left: find text
  recent = "\u{f0c5}", -- nf-fa-files_o: recent files
  config = "\u{f013}", -- nf-fa-cog: this config
  update = "\u{f019}", -- nf-fa-download: update the plugins
  quit = "\u{f08b}", -- nf-fa-sign_out: quit
  info = "\u{f05a}", -- nf-fa-info_circle: an info diagnostic
  hint = "\u{f0e5}", -- nf-fa-comment_o: a hint diagnostic
  lock = "\u{f023}", -- nf-fa-lock: a read-only buffer
}
