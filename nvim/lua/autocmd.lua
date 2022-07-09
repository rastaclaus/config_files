local cmd = vim.cmd

cmd('au BufNewFile, BufRead * if &ft == "" | set ft=text | endif')

vim.api.nvim_create_autocmd(
  {"BufEnter", "BufWritePost"},
  { command = "lua require('lint').try_lint()" }
)
