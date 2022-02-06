autocmd FileType * set tabstop=2 | set shiftwidth=2
autocmd FileType python set tabstop=4 | set shiftwidth=4 | set completeopt+=noinsert | set completeopt-=preview
autocmd FileType python map <buffer> <F9> :w<CR>:exec '!python' shellescape(@%, 1)<CR>
autocmd FileType python imap <buffer> <F9> <esc>:w<CR>:exec '!python' shellescape(@%, 1)<CR>

" autocmd CompleteDone * if !pumvisible() | pclose | endif

" Save session on quitting Vim
autocmd VimLeave * mksession! ~/.session.vim
