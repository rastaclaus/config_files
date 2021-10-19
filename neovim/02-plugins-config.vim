"NerdTree
"autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

"YCM
"let g:ycm_global_ycm_extra_conf = '/home/artems/.config/nvim/ycm_extra_conf.py'
"let g:ycm_add_preview_to_completeopt = -1
"let g:ycm_autoclose_preview_window_after_insertion = 1

"deoplete
"let g:deoplete#enable_at_startup = 1

"set hidden

"vim-markdown-preview
let g:vim_markdown_preview_pandoc=1
let g:vim_markdown_preview_use_xdg_open=1

"neomake
function! MyOnBattery()
  if !empty(glob("/sys/class/power_supply/ACAD"))
    return readfile('/sys/class/power_supply/ACAD/online') == ['0']
  endif
endfunction

" fzf
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" vim-autoformat
let g:formatdef_tsfmt = "'tsfmt --stdin --no-tslint '.bufname('%')"
