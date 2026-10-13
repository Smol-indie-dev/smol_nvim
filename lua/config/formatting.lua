local conform = require("conform")
local prettierd = require("conform.formatters.prettierd")
local notes = require("config.notes")

conform.setup({
  formatters_by_ft = {
    -- Rust
    rust = { "rustfmt" },

    -- Modern JS/TS/config formatter
    javascript = { "biome" },
    javascriptreact = { "biome" },
    typescript = { "biome" },
    typescriptreact = { "biome" },

    -- JSON
    json = { "biome" },
    jsonc = { "biome" },

    -- Astro: an Astro site with a pinned biome runs its own version from node_modules.
    astro = { "biome" },

    -- CSS ecosystem
    css = { "prettierd" },
    scss = { "prettierd" },
    less = { "prettierd" },
    html = { "prettierd" },

    -- Config
    yaml = { "yamlfmt" },
    toml = { "taplo" },

    -- Lua
    lua = { "stylua" },

    -- Shell
    sh = { "shfmt" },
    bash = { "shfmt" },

    -- Markdown
    markdown = { "prettierd" },
  },
  -- Notes belong to smo: nothing under the notes path is formatted on save. The
  -- guard goes by path, never by the note's parsed frontmatter.
  format_on_save = function(buf)
    if notes.owns(vim.api.nvim_buf_get_name(buf)) then
      return nil
    end
    return {
      timeout_ms = 2000,
      -- No fallback to the language server: lua_ls, cssls and the others would format
      -- exactly the files the rule below leaves alone.
      lsp_format = "never",
    }
  end,
  -- A formatter that does not run in a repo without its config is the rule, not a
  -- warning. `:ConformInfo` still says why one is unavailable.
  notify_no_formatters = false,
})

-- Format on save follows the repo: a formatter runs only when one of its config files is
-- in the file's directory or an ancestor, up to the buffer's git root. Outside a repo
-- only the file's own directory counts. rustfmt is not in the table below, so it always
-- runs.

-- The directory of the nearest of `names`. They go to vim.fs.root as one inner list: in
-- a flat list the first name is searched all the way up before the second is tried.
local function nearest(names)
  return function(ctx)
    return vim.fs.root(ctx.dirname, { names })
  end
end

local config_dirs = {
  -- `.prettierrc*`, `prettier.config.*`, or a package.json with a "prettier" key.
  prettierd = function(ctx)
    return prettierd.cwd(prettierd, ctx)
  end,
  biome = nearest({ "biome.json", "biome.jsonc", ".biome.json", ".biome.jsonc" }),
  stylua = nearest({ "stylua.toml", ".stylua.toml" }),
  taplo = nearest({ "taplo.toml", ".taplo.toml" }),
  yamlfmt = nearest({ ".yamlfmt", "yamlfmt.yml", "yamlfmt.yaml", ".yamlfmt.yml", ".yamlfmt.yaml" }),
  -- shfmt reads .editorconfig by itself, and conform then passes no `-i`.
  shfmt = nearest({ ".editorconfig" }),
}

-- Under the notes path no filetype has a formatter either, so `:ConformInfo` and a
-- manual `conform.format()` agree with the save.
for ft, names in pairs(conform.formatters_by_ft) do
  conform.formatters_by_ft[ft] = function(buf)
    return notes.owns(vim.api.nvim_buf_get_name(buf)) and {} or names
  end
end

-- The config's directory is also where the formatter runs: taplo and yamlfmt look for
-- their config from the working directory, not from the file.
for name, config_dir in pairs(config_dirs) do
  conform.formatters[name] = {
    require_cwd = true,
    cwd = function(_, ctx)
      local dir = config_dir(ctx)
      local limit = vim.fs.root(ctx.dirname, ".git") or ctx.dirname
      return dir and vim.fs.relpath(limit, dir) and dir or nil
    end,
  }
end
