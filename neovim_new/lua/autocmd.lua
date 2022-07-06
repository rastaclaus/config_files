vim.api.nvim_create_autocmd(
  {"BufEnter", "BufWritePost"},
  { command = "lua require('lint').try_lint()" }
)
