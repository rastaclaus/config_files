-- Включаем подсветку синтаксиса
require "nvim-treesitter.configs".setup {
    -- Нужные парсеры
    ensure_installed = {"c", "cpp", "lua", "python", "yaml", "go"},
    -- Устанавливать парсеры синхронно
    sync_install = false,
    -- Подсветка
    highlight = {
        -- Включить расшируение
        enable = true,
        disable = {}
    },
    indent = {
        -- Включить indent
        enable = false,
        disable = {}
    }
}
