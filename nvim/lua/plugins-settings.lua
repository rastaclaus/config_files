require("lualine").setup {
    options = {
        icons_enabled = true,
        theme = "auto",
        component_separators = {left = "", right = ""},
        section_separators = {left = "", right = ""},
        disabled_filetypes = {},
        always_divide_middle = true,
        globalstatus = true
    },
    sections = {
        lualine_a = {"mode"},
        lualine_b = {"branch", "diff", "diagnostics"},
        lualine_c = {
            {
                "filename",
                path = 3,
                shorting_target = 40
            }
        },
        lualine_x = {"encoding", "fileformat", "filetype"},
        lualine_y = {"progress"},
        lualine_z = {"location"}
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {"filename"},
        lualine_x = {"location"},
        lualine_y = {},
        lualine_z = {}
    },
    tabline = {},
    extensions = {}
}

require("Comment").setup()

require("indent_blankline").setup {
    char = "⁝",
    show_trailing_blankline_indent = false
}

local cmp = require "cmp"
local luasnip = require "luasnip"

cmp.setup {
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end
    },
    mapping = cmp.mapping.preset.insert {
        ["<C-d>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete({}),
        ["<CR>"] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true
        },
        ["<Tab>"] = cmp.mapping(
            function(fallback)
                if cmp.visible() then
                    cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                else
                    fallback()
                end
            end,
            {"i", "s"}
        ),
        ["<S-Tab>"] = cmp.mapping(
            function(fallback)
                if cmp.visible() then
                    cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                else
                    fallback()
                end
            end,
            {"i", "s"}
        )
    },
    sources = {
        {name = "nvim_lsp"},
        {name = "luasnip"},
        {name = "cmp_tabnine"}
    }
}

require("telescope").setup {
    defaults = {
        borderchars = {"─", "│", "─", "│", "┌", "┐", "┘", "└"},
        mappings = {
            i = {
                ["<C-u>"] = false,
                ["<C-d>"] = false,
                ["<C-k>"] = "move_selection_previous",
                ["<C-j>"] = "move_selection_next",
                ["<Esc>"] = "close"
            }
        }
    }
}

pcall(require("telescope").load_extension, "fzf")

require("lint").linters_by_ft = {
    python = {"pylint", "pycodestyle"},
    yaml = {"yamllint"}
}

vim.diagnostic.config(
    {
        virtual_text = {
            source = "always",
            format = function(diagnostic)
                if diagnostic.user_data.lsp.code ~= nil then
                    return string.format("%s: %s", diagnostic.user_data.lsp.code, diagnostic.message)
                end
                return diagnostic.message
            end
        }
    }
)

vim.g.neoformat_enabled_python = {"black", "isort"}
vim.g.neoformat_enabled_sql = {"pg_format"}
vim.g.neoformat_run_all_formatters = 1

require('nvim-treesitter.configs').setup {
  ensure_installed = { 'c', 'cpp', 'lua', 'python', "yaml", "go" },

  rainbow = {
    enable = true,
    extended_mode = true,
  },

  highlight = {
    enable = true,
  },

  indent = {
    enable = false,
    -- disable = {'python', 'yaml'}
  },

  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    }
  }
}
