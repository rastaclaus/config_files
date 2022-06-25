require('packer').startup(function(use)
    use 'wbthomason/packer.nvim' -- packer self
    use 'danilo-augusto/vim-afterglow' -- colorscheme

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
    }  -- Add git related info in the signs columns and popups
    use 'nvim-lualine/lualine.nvim'   -- Fancier statusline
    use 'numToStr/Comment.nvim'
    use 'lukas-reineke/indent-blankline.nvim'
    use 'tpope/vim-sleuth'

    use 'nvim-treesitter/nvim-treesitter'   -- Highlight, edit, and navigate code
    use 'nvim-treesitter/nvim-treesitter-textobjects' --  Additional textobjects for treesitter

    use 'neovim/nvim-lspconfig'                                                     -- Collection of configurations for built-in LSP client
    use 'williamboman/nvim-lsp-installer'                                           -- Automatically install language servers to stdpath
    use { 'hrsh7th/nvim-cmp', requires = { 'hrsh7th/cmp-nvim-lsp' } }               -- Autocompletion
    use { 'L3MON4D3/LuaSnip', requires = { 'saadparwaiz1/cmp_luasnip' } }           -- Snippet Engine and Snippet Expansion
    use { 'nvim-telescope/telescope.nvim', requires = { 'nvim-lua/plenary.nvim' } } -- Fuzzy Finder (files, lsp, etc)




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

