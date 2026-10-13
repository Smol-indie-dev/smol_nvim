require("blink.cmp").setup({
  keymap = { preset = "default" },
  appearance = { nerd_font_variant = "mono" },
  completion = {
    documentation = { auto_show = true },
  },
  signature = { enabled = true },
  -- The Rust matcher when init.lua's PackChanged hook could build it, else blink's Lua
  -- one. Not prefer_rust_with_warning: without cargo it warns on every start, with a
  -- lazy.nvim hint; the hook's one warning and :checkhealth smol say it instead.
  fuzzy = { implementation = "prefer_rust" },
})
