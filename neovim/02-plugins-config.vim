"NerdTree
"autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

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

"NERDTree
let NERDTreeIgnore = ['\.pyc$', '__pycache__', ".git$", ".mypy_cache", ".pytest_cache"]
let NERDTreeWinSize = 51
