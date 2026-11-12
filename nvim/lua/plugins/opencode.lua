-- https://github.com/sudo-tee/opencode.nvim
-- Neovim frontend для OpenCode: чат-панель, diff-ревью, сессии.
-- Требует CLI `opencode` на PATH (V2). Клавиши: <leader>o… (см. :checkhealth opencode)
require("opencode").setup({
	preferred_picker = "fzf-lua", -- используется установленный fzf-lua
})
