-- WezTerm. Симлинк: ~/.config/wezterm -> repo/wezterm (см. install/symlinks.conf).
-- Запуск: Shift+Mod+Return в niri/sway (kitty остаётся на Mod+Return).
--
-- Конфиг почти дефолтный: шрифт, прямоугольное окно и авто-тема. Палитры —
-- встроенные схемы wezterm ('GruvboxDark'/'GruvboxLight'); wezterm сам следит
-- за схемой ОС через xdg-desktop-portal (org.freedesktop.appearance; на этом
-- десктопе значение отдаёт darkman) и на смену схемы сам перечитывает конфиг:
-- get_appearance() вызывается при каждом reload, а wezterm reload'ит конфиг на
-- смену appearance. Отдельный хук в wayland/theme-hooks.d/ не нужен.
--
-- Подробности — docs/wezterm.md.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ------------------------------------------------------------------ тема
-- wezterm.gui недоступен в mux-сервере (wezterm start --daemon и т.п.), там
-- берём тёмную схему как безопасный дефолт — рецепт из документации
-- wezterm.gui.get_appearance().
local function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'GruvboxDark'
  else
    return 'GruvboxLight'
  end
end

function scheme_for_gui()
  if wezterm.gui then
    return scheme_for_appearance(wezterm.gui.get_appearance())
  end
  return 'GruvboxDark'
end

config.color_scheme = scheme_for_gui()

-- Цвета таб-бара: те же gruvbox-значения, что в файлах авто-темы kitty
-- ({dark,light}-theme.auto.conf: active_tab_*, inactive_tab_*, tab_bar_background).
-- Встроенные схемы wezterm таб-бар не красят — дефолты серо-синие, выделяются из
-- интерфейса; тут палитра полностью совпадает с kitty. Вложенность —
-- config.colors.tab_bar.{background,active_tab,...} (не корень colors).
local function tab_colors_for(scheme)
  local dark = scheme == 'GruvboxDark'
  return {
    tab_bar = {
      background = dark and '#1d2021' or '#ebdbb2',
      active_tab = dark
        and { fg_color = '#ebdbb2', bg_color = '#504945' }
        or { fg_color = '#fbf1c7', bg_color = '#d5c4a1' },
      inactive_tab = dark
        and { fg_color = '#a89984', bg_color = '#3c3836' }
        or { fg_color = '#7c6f64', bg_color = '#ebdbb2' },
      inactive_tab_hover = dark
        and { fg_color = '#ebdbb2', bg_color = '#504945', italic = false }
        or { fg_color = '#fbf1c7', bg_color = '#d5c4a1', italic = false },
      new_tab = dark
        and { fg_color = '#a89984', bg_color = '#1d2021' }
        or { fg_color = '#7c6f64', bg_color = '#ebdbb2' },
      new_tab_hover = dark
        and { fg_color = '#ebdbb2', bg_color = '#504945', italic = false }
        or { fg_color = '#fbf1c7', bg_color = '#d5c4a1', italic = false },
    },
  }
end

config.colors = tab_colors_for(config.color_scheme)

-- ------------------------------------------------------------------ шрифт
-- Тот же, что в kitty: fontconfig-«monospace» (Noto Sans Mono) 11.25.
config.font = wezterm.font_with_fallback {
  { family = 'Noto Sans Mono' },
  'JetBrains Mono',
}
config.font_size = 11.25

-- --------------------------------------------------------------- окно
-- Полностью без декораций: ни заголовка, ни клиентской рамки. На Wayland под
-- тайловым композитором ресайз делает сам композитор (xdg_toplevel.resize),
-- которому рамка клиента не нужна; в режиме RESIZE wezterm рисует собственную
-- рамку (FallbackFrame) — она выглядела как лишняя полоса у тайлового окна.
config.window_decorations = 'NONE'

-- ------------------------------------------------------------- таб-бар
-- Как в kitty: снизу (tab_bar_edge bottom), текстовый (kitty рисует таб-бар
-- тем же шрифтом терминала — в wezterm это ретро-стиль use_fancy_tab_bar=false,
-- fancy-вариант рисует пропорциональным шрифтом и выделяется из интерфейса),
-- скрыт при единственной вкладке (kitty tab_bar_min_tabs=2). Кнопку «+» и
-- крестик гасим: вкладки создаются ctrl+shift+t и закрываются ctrl+shift+w.
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false

-- ---------------------------------------------------------------- клавиши
-- Переключение вкладок на alt+h / alt+l, как в kitty. Префикс phys: мапит по
-- физической позиции клавиши ANSI-US, а не по символу раскладки — поэтому
-- работает и на ru (у kitty так же: маппинг по «латинской букве»). Mod+H/L в
-- niri заняты фокусом колонок.
--
-- Copy mode — на ctrl+shift+h вместо дефолтного ctrl+shift+x: та же рука, что
-- alt+h/l, и буква «h» мнемонична (в copy mode это движение влево). Дефолтный
-- ctrl+shift+x не гасим. Ctrl+shift+h в wezterm свободен (нет в default-keys),
-- в niri H занят только с Mod (move-column-left).
config.keys = {
  { key = 'phys:h', mods = 'ALT', action = wezterm.action.ActivateTabRelative(-1) },
  { key = 'phys:l', mods = 'ALT', action = wezterm.action.ActivateTabRelative(1) },
  { key = 'phys:h', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCopyMode },
}

-- Новая вкладка: дефолтный ctrl+shift+t (SpawnCommandInNewTab) уже наследует
-- cwd активной панели — wezterm берёт каталог из OSC 7 (fish печатает сам) или
-- из /proc лидера группы процессов. Отдельный маппинг, как kitty
-- new_tab_with_cwd, не нужен.

return config
