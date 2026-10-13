local languages = {
  "rust",
  "lua",
  "toml",
  "markdown",
  "markdown_inline",
  "bash",
  "json",
  "yaml",
  "typescript",
  "tsx",
  "astro",
  "vim",
  "vimdoc",
  "query",
}

-- Not in test mode (tests/run): install() builds missing parsers into
-- stdpath("data")/site. The parsers come from the real site dir there.
if vim.env.NVIM_SMOL_TEST ~= "1" then
  require("nvim-treesitter").install(languages)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
    if vim.treesitter.language.add(lang) then
      vim.treesitter.start(ev.buf, lang)
    end
  end,
})

-- `install()` only fills in missing parsers, it never updates ones already
-- present. Run this by hand after `:PackUpdate` to pick up grammar changes.
vim.api.nvim_create_user_command("TSUpdateParsers", function()
  require("nvim-treesitter").update()
end, { desc = "Update all installed treesitter parsers" })
