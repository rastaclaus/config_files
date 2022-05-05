"Поведение
scriptencoding utf-8
set noexrc
set pyxversion=3
set secure
set shell=/bin/zsh
set nobackup "Не создавать резервных копий файлов
set noswapfile "Не использовать swap-файл
set number "Нумеровать строки
set numberwidth=4 "Ширина поля нумерации строк
set splitright
set splitbelow
set nocp

"Поддержка truecolor
set termguicolors

"Настройки поиска
set nohlsearch "Подсветка результатов поиска
set incsearch "Поиск фрагмента текста во время набора

"статусная строка
set statusline=%F%m%r%h%w\ [POS=%04l,%04v][%p%%]\ [LEN=%L]\ [%{&fenc}]\ [%{&enc}]

" кодировки
set ffs=unix,dos,mac
set fencs=utf-8,cp1251,koi8-r,ucs-2,cp866

"заменить пробелами табы
set expandtab
"Включить подсветку табуляции и пробелов в конце строки
set list
"Установить символы которыми будет осуществляться подсветка
set listchars=tab:->,trail:-

" поддержка python и ruby
let g:python3_host_prog = $HOME.'/.pyenv/versions/neovim3/bin/python'
let g:python_host_prog = $HOME.'/.pyenv/versions/neovim2/bin/python'
let g:ruby_host_prog = $HOME.'/.gem/ruby/2.6.0/bin/neovim-ruby-host'

call plug#begin('~/.config/nvim/plugged')
source ~/.config/nvim/00-plugin-list.vim
call plug#end()

source ~/.config/nvim/01-keymaps.vim
source ~/.config/nvim/02-plugins-config.vim
source ~/.config/nvim/021-coc-nvim.vim
source ~/.config/nvim/03-autocmds.vim

"цвета
colors afterglow
