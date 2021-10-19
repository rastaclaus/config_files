"Начало <Раскладка>
set keymap=russian-jcukenwin
set iminsert=0 " по умолчанию - латинская раскладка
set imsearch=0 " по умолчанию - латинская раскладка при поиске

nmap <silent> <F2> :CocCommand explorer<CR>
nmap <silent> <F5> :Format<CR>
nmap <silent> <F6> :NextColorScheme<CR>
nmap <silent> <F7> :PrevColorScheme<CR>

nnoremap qe :Files %:p:h<CR>
nnoremap qE :Files<CR>
nnoremap ed :Buffers<CR>

inoremap <silent><expr> <c-space> coc#refresh()


"silent! call repeat#set("\<Plug>MyWonderfulMap", v:count)
