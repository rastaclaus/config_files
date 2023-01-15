require("keys/alias")

nm("K", "<cmd>lua vim.lsp.buf.hover()<CR>")

-- LSP (все горячие клавиши начинаются с g), кроме ховера
nm("K", "<cmd>lua vim.lsp.buf.hover()<CR>") -- Ховер для объекта
nm("<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>") -- Signature documentation

nm("gd", "<cmd>Telescope lsp_definitions<CR>") -- Объявления в LSP
nm("gD", "<cmd>Telescope lsp_declarations<CR>") -- Object declaration
nm("gi", "<cmd>Telescope lsp_implementations<CR>") -- Object implementation
nm("gr", "<cmd>Telescope lsp_references<CR>")

nm("<leader>pf", "<cmd>Telescope oldfiles<CR>") -- Просмотр недавних файлов
nm("<leader>go", "<cmd>Telescope git_files<CR>") -- Поиск файлов
nm("<leader>gB", "<cmd>Telescope git_branches<CR>") -- Ветки в Git
nm("<leader>sg", "<cmd>Telescope live_grep<CR>") -- Поиск строки
nm("<leader>sf", "<cmd>Telescope find_files<CR>") -- Буфферы
nm("<leader>sb", "<cmd>Telescope buffers<CR>") -- Буфферы

nm('<leader>gb', '<cmd>Git blame<CR>')

nm("<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>") -- Действия с кодом
nm("<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>") -- Переименовать объект

-- Отркыть NvimTree
nm("<F2>", "<cmd>NeoTreeRevealToggle<CR>")

-- Форматировать файл
nm("<F5>", "<cmd>Neoformat<CR>")
