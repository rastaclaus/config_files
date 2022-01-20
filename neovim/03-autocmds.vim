autocmd BufNewFile,BufRead *.docker set filetype=dockerfile
autocmd FileType * set tabstop=2 | set shiftwidth=2
autocmd FileType python set tabstop=4 | set shiftwidth=4 | set completeopt+=noinsert | set completeopt-=preview
