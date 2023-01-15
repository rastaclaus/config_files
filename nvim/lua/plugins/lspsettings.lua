local lspconfig = require"lspconfig"
local util = lspconfig.util

local python_root_files = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "PipFile"
}

lspconfig.pyright.setup {
     handlers = {
        ["textDocument/publishDiagnostics"] = function(...)
        end
    },

    root_dir = util.root_pattern(python_root_files.unpack),

    single_file_suport = true,
    settings = {
        pyright = {
            analisys = {
                autoSearchPaths = false,
                typeCheckingMode = "off"
            }
        }
    }
}
