require("neo-tree").setup(
    {
        filesystem = {
            filtered_items = {
                visible = false, -- when true, they will just be displayed differently than normal items
                hide_dotfiles = true,
                hide_gitignored = true,
                hide_hidden = true -- only works on Windows for hidden files/directories
            }
        }
    }
)
