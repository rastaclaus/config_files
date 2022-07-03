vim.api.nvim_create_autocmd(
  {"BufEnter", "BufWritePost", "TextChanged", "TextChangedI"},
  {
    command = "lua require('lint').try_lint()"
  }
)
