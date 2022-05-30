"syntax
Plug 'neoclide/coc.nvim', {'branch': 'master', 'do': 'yarn install --frozen-lockfile'}
Plug 'fatih/vim-go'

" apperance
Plug 'xolox/vim-misc'
Plug 'xolox/vim-colorscheme-switcher'
Plug 'rafi/awesome-vim-colorschemes'
Plug 'rainglow/vim'

" functional
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'preservim/nerdtree'
Plug 'iamcco/markdown-preview.nvim', {'do': 'cd app && yarn install'}

" behavior
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'jiangmiao/auto-pairs'
Plug 'rking/ag.vim'
Plug 'Vimjas/vim-python-pep8-indent'
Plug 'alvan/vim-closetag'
