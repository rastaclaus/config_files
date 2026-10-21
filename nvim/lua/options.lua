-- Basic settings
vim.opt.number = true                              -- Line numbers
vim.opt.relativenumber = true                      -- Relative line numbers
vim.opt.wrap = false                               -- Don't wrap lines
vim.opt.scrolloff = 10                             -- Keep 10 lines above/below cursor
vim.opt.sidescrolloff = 8                          -- Keep 8 columns left/right of cursor

-- Indentation
vim.opt.tabstop = 2                                -- Tab width
vim.opt.shiftwidth = 2                             -- Indent width
vim.opt.softtabstop = 2                            -- Soft tab stop
vim.opt.expandtab = true                           -- Use spaces instead of tabs
vim.opt.smartindent = true                         -- Smart auto-indenting

-- Search settings
vim.opt.ignorecase = true                          -- Case insensitive search
vim.opt.smartcase = true                           -- Case sensitive if uppercase in search
vim.opt.hlsearch = false                           -- Don't highlight search results

-- Visual settings
vim.opt.termguicolors = true                       -- Enable 24-bit colors
vim.opt.signcolumn = "yes"                         -- Always show sign column
vim.opt.winborder = "rounded"
vim.opt.showmatch = true                           -- Highlight matching brackets
vim.opt.matchtime = 2                              -- How long to show matching bracket
vim.opt.pumheight = 10                             -- Popup menu height
vim.opt.pumblend = 10                              -- Popup menu transparency
vim.opt.synmaxcol = 300                            -- Syntax highlighting limit

-- Completion: the menu opens while typing ('autocomplete') in LSP buffers only,
-- see lsp_config.lua. 'noselect' comes implicitly with 'autocomplete': nothing is
-- preselected, <Tab>/<C-n> picks, <C-y> accepts, <C-e> closes.
-- Buffer words stay manual: <C-x><C-n> in LSP buffers, <C-Space>/<C-n> otherwise.
vim.opt.completeopt = "menuone,fuzzy,noselect,popup"
vim.opt.complete = ".^5,b^5,o"                     -- buffer words + 'omnifunc' (LSP)
vim.opt.autocomplete = false                       -- off globally, on per LSP buffer
vim.opt.autocompletedelay = 10                     -- ms before the menu appears
vim.opt.wildoptions = "pum"                        -- cmdline autocompletion popup
vim.opt.wildmode = "noselect:lastused,full"

-- File handling
vim.opt.writebackup = false                        -- Don't create backup before writing
vim.opt.swapfile = false                           -- Don't create swap files
vim.opt.undofile = true                            -- Persistent undo
vim.opt.undodir = vim.fn.expand("~/.nvim/undodir") -- Undo directory
vim.opt.updatetime = 300                           -- Faster completion
vim.opt.timeoutlen = 500                           -- Key timeout duration
vim.opt.ttimeoutlen = 0                            -- Key code timeout

-- Behavior settings
vim.opt.iskeyword:append("-")                      -- Treat dash as part of word
vim.opt.path:append("**")                          -- include subdirectories in search
vim.opt.selection = "exclusive"                    -- Selection behavior
vim.opt.mouse = ""                                 -- Disable mouse
vim.opt.clipboard:append("unnamedplus")            -- Use system clipboard

-- Clipboard
local function paste()
	return {
		vim.fn.split(vim.fn.getreg(""), "\n"),
		vim.fn.getregtype(""),
	}
end

if vim.env.SSH_TTY then
	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = require("vim.ui.clipboard.osc52").copy("+"),
			["*"] = require("vim.ui.clipboard.osc52").copy("*"),
		},
		paste = {
			["+"] = paste,
			["*"] = paste,
		},
	}
end

-- Folding settings
vim.opt.foldmethod = "expr"                             -- Use expression for folding
vim.opt.foldexpr = vim.treesitter.foldexpr              -- Treesitter folds (global, inherited by new windows)
vim.opt.foldlevel = 99                                  -- Start with all folds open

-- Split behavior
vim.opt.splitbelow = true                          -- Horizontal splits go below
vim.opt.splitright = true                          -- Vertical splits go right

-- List Options
vim.opt.list = true
vim.opt.listchars = { tab = "->", trail = "-", nbsp = "+" }
