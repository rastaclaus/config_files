require("packer").startup(
    function(use)
        use("wbthomason/packer.nvim") -- packer self
        use("sainnhe/gruvbox-material") -- colorschems

        use(
            {
                -- file tree plugin
                "nvim-neo-tree/neo-tree.nvim",
                branch = "v2.x",
                requires = {
                    "nvim-lua/plenary.nvim",
                    "kyazdani42/nvim-web-devicons", -- not strictly required, but recommended
                    "MunifTanjim/nui.nvim"
                }
            }
        )

        use( -- statusline
            {
                "nvim-lualine/lualine.nvim",
                requires = {"kyazdani42/nvim-web-devicons", opt = true}
            }
        )
        use("tpope/vim-fugitive") -- git integrations plugin
        use("numToStr/Comment.nvim") -- easy comment selected lines
        use("lukas-reineke/indent-blankline.nvim") -- indent visualization


        use 'tpope/vim-sleuth'
        use("Vimjas/vim-python-pep8-indent")

        use("jiangmiao/auto-pairs")
        use("tpope/vim-surround")

        use {
            "nvim-treesitter/nvim-treesitter",
            requires = {
                "p00f/nvim-ts-rainbow"
            }
        }

        use {"nvim-telescope/telescope.nvim", requires = {"nvim-lua/plenary.nvim"}} -- Fuzzy Finder (files, lsp, etc)
        use("neovim/nvim-lspconfig") -- Collection of configurations for built-in LSP client
        use("williamboman/nvim-lsp-installer") -- Automatically install language servers to stdpath
        use( -- Autocompletion
            {
                "hrsh7th/nvim-cmp",
                requires = {
                    "hrsh7th/cmp-nvim-lsp",
                    "hrsh7th/cmp-buffer",
                    "hrsh7th/cmp-path",
                    "hrsh7th/cmp-cmdline",
                    "hrsh7th/nvim-cmp"
                }
            }
        )

        use({"L3MON4D3/LuaSnip", requires = {"saadparwaiz1/cmp_luasnip"}}) -- Snippet Engine and Snippet Expansion
        use({"tzachar/cmp-tabnine", run = "./install.sh", requires = "hrsh7th/nvim-cmp"}) -- tabnine

        use("mfussenegger/nvim-lint") -- linter
        use("sbdchd/neoformat") -- formatter
    end
)
