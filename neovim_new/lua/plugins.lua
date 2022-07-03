require('packer').startup(function(use)
    use 'wbthomason/packer.nvim' -- packer self

    -- colorschemes
    use 'danilo-augusto/vim-afterglow'
    use {"adisen99/codeschool.nvim", requires = {"rktjmp/lush.nvim"}}
    use {'tomasiser/vim-code-dark'}
    use {'marko-cerovac/material.nvim'}
    use {'fenetikm/falcon'}
    use {'sainnhe/everforest'}
    use {'sainnhe/gruvbox-material'}




    use {
        'nvim-neo-tree/neo-tree.nvim',
        branch = 'v2.x',
        requires = {
            'nvim-lua/plenary.nvim',
            'kyazdani42/nvim-web-devicons', -- not strictly required, but recommended
            'MunifTanjim/nui.nvim',
        }
    }

    use 'tpope/vim-fugitive'
    use {
        'lewis6991/gitsigns.nvim',
        requires = {
            'nvim-lua/plenary.nvim'
        }
    } -- Add git related info in the signs columns and popups
    use 'nvim-lualine/lualine.nvim' -- Fancier statusline
    use 'numToStr/Comment.nvim'
    use 'lukas-reineke/indent-blankline.nvim'
    use 'tpope/vim-sleuth'


    use 'neovim/nvim-lspconfig' -- Collection of configurations for built-in LSP client
    use 'williamboman/nvim-lsp-installer' -- Automatically install language servers to stdpath
    use { 'hrsh7th/nvim-cmp', requires = { 'hrsh7th/cmp-nvim-lsp' } } -- Autocompletion
    use { 'L3MON4D3/LuaSnip', requires = { 'saadparwaiz1/cmp_luasnip' } } -- Snippet Engine and Snippet Expansion
    use { 'nvim-telescope/telescope.nvim', requires = { 'nvim-lua/plenary.nvim', } } -- Fuzzy Finder (files, lsp, etc)

    use 'Vimjas/vim-python-pep8-indent'
    use 'jiangmiao/auto-pairs'
    use 'tpope/vim-surround'

    use { -- markdown preview plugin
        'iamcco/markdown-preview.nvim',
        run = function() vim.fn['mkdp#util#install']() end,
        ft = { 'markdown' },
        setup = function()
            vim.g.mkdp_open_to_the_world = 1
            vim.g.mkdp_echo_preview_url = 1
        end,
    }
    use {
        'nvim-treesitter/nvim-treesitter',
        requires = {
            "p00f/nvim-ts-rainbow"
        }
    }

    if is_bootstrap then
        require('packer').sync()
    end
end)

if is_bootstrap then
    print '=================================='
    print '    Plugins are being installed'
    print '    Wait until Packer completes,'
    print '       then restart nvim'
    print '=================================='
    return
end
