vim.cmd [[packadd packer.nvim]]

return require("packer").startup(
    function()
        -- packer itself
        use "wbthomason/packer.nvim"

        -- LSP server
        use "neovim/nvim-lspconfig"

        --autocomplete icons
        use {
            "onsails/lspkind-nvim",
            config = function()
                require("plugins/lspkind")
            end
        }

        -- lsp installer
        use {
            "williamboman/nvim-lsp-installer",
            config = function()
                require("plugins/lsp-installer")
            end
        }

        use {
            "hrsh7th/nvim-cmp",
            requires = {
                "L3MON4D3/LuaSnip",
                "saadparwaiz1/cmp_luasnip",
                "hrsh7th/cmp-nvim-lsp",
                "hrsh7th/cmp-path",
                "hrsh7th/cmp-emoji",
                "hrsh7th/cmp-nvim-lsp-signature-help",
                "hrsh7th/cmp-nvim-lua"
            },
            config = function()
                require("plugins/cmp")
            end
        }

        use "sainnhe/gruvbox-material" -- colorschems

        use {
            "numToStr/Comment.nvim",
            config = function()
                require("Comment").setup()
            end
        }

        use "lukas-reineke/indent-blankline.nvim" -- indent visualization

        use "Exafunction/codeium.vim" --codeim code helper

        use {
            "nvim-neo-tree/neo-tree.nvim",
            branch = "v2.x",
            requires = {
                "nvim-lua/plenary.nvim",
                "nvim-tree/nvim-web-devicons",
                "MunifTanjim/nui.nvim"
            },
            config = function()
                require("plugins/neo_tree")
            end
        }

        use "jiangmiao/auto-pairs"

        use "tpope/vim-surround"

        use {
            "mfussenegger/nvim-lint",
            config = function()
                require("plugins/lint")
            end
        } -- linter

        use "sbdchd/neoformat"
        require("plugins/neoformat")

        -- Статуслайн
        use {
            "nvim-lualine/lualine.nvim",
            requires = {"kyazdani42/nvim-web-devicons", opt = true},
            config = function()
                require("plugins/lualine")
            end
        }

        -- Плагин для подсветки синтаксиса
        use {
            "nvim-treesitter/nvim-treesitter",
            config = function()
                require("plugins/tree-sitter")
            end
        }

        use {
            "nvim-telescope/telescope.nvim",
            requires = {{"nvim-lua/plenary.nvim"}}
        }

        use {
            "SmiteshP/nvim-navic",
            requires = "neovim/nvim-lspconfig"
        }

        use "Vimjas/vim-python-pep8-indent"

        -- Git
        use "tpope/vim-fugitive"
        use "tpope/vim-repeat"
    end
)
