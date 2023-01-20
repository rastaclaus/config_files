require("lualine").setup {
    options = {
        icons_enabled = true,
        theme = "auto",
        component_separators = {left = "", right = ""},
        section_separators = {left = "", right = ""},
        disabled_filetypes = {},
        always_divide_middle = true,
        globalstatus = false
    },
    sections = {
        lualine_c = {
            {
                "filename",
                newfile_status = true,
                path = 3,
                symbols = {
                    modified = '[+]',
                    readonly = '[-]',
                    unnamed = '[No Name]',
                    newfile = '[New]',
                }
            }
        },
        lualine_y = {"progress"},
        lualine_z = {"location"}
    }
}
