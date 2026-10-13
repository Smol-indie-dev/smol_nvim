-- File-type icons for the snacks explorer and dashboard and for fzf-lua, which all look
-- for mini.icons first. The nvim-web-devicons mock covers plugins that only know that
-- one (diffview's file panel), so it doesn't need installing too.
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()
