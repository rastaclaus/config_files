# Тема и runtime state

Репозиторий — **read-only источник конфигов**: приложения в него не пишут.
Merge-каталоги (`fish`, `helix`) дают приложению реальную папку для
записи рядом с трекнутыми файлами, а всё изменяемое в рантайме живёт в одном
каталоге:

```
~/.local/state/dotfiles/
  background-mode                      # "dark" или "light"
  alacritty.toml                       # [general] import палитры
  rofi.rasi                            # @theme для rofi
  helix/runtime/themes/dotfiles.toml   # тема "dotfiles" (наследует gruvbox_*)
  ironbar/colors.css                   # @define-color палитра
  ironbar/style.css                    # обёртка: colors.css + стили из репо
  mattermost.log                       # лог wayland/mattermost-theme
  theme-hooks.log                      # вывод хуков и коды возврата
```

Путь **захардкожен** (не `$XDG_STATE_HOME`): alacritty и rofi не раскрывают
переменные окружения в `import`/`?import`.

## Как переключается

darkman вызывает хук `~/.local/share/darkman/theme` с `dark|light`; хук
показывает уведомление и запускает `wayland/theme-sync <mode>`. `theme-sync`
только пишет state-файлы и раздаёт хуки — про приложения он не знает. Каждый
файл `wayland/theme-hooks.d/` вызывается как `<NN>-<app>.sh <dark|light>` с
`THEME_STATE`, `THEME_HOOK_LOG`, `THEME_PREV_MODE`, `THEME_GUI` в окружении, под
`timeout 15`. Хук сам решает, применим ли он (нет приложения или процесса —
`exit 0`, это не ошибка), никогда не пишет в репозиторий, а его падение только
логируется в `theme-hooks.log` и переключение не ломает. Новая программа — новый
файл в каталоге, `theme-sync` не трогается.

| хук | что делает |
|---|---|
| `10-gtk.sh` | `gsettings`: `adw-gtk3(-dark)` + `color-scheme` — сигнал для всех libadwaita-приложений |
| `20-ghostty.sh` | `SIGUSR2` запущенному ghostty (перечитывает конфиг, цвета применяются на живую) |
| `25-alacritty.sh` | `alacritty msg config` — палитра и прозрачность fallback-терминала |
| `30-helix.sh` | `SIGUSR1` — helix перечитывает конфиг и тему |
| `40-tmux.sh` | `tmux set -s theme` запущенному серверу + обновление статус-строки |
| `50-fish.sh` | `SIGWINCH` fish, чтобы нарисованный промпт перекрасился сразу |
| `60-redraw.sh` | `SIGWINCH` ANSI-TUI (`htop`, `less`, `ncdu`; список расширяется `DOTFILES_THEME_REDRAW`) |
| `90-mattermost.sh` | перезапуск Mattermost, только если `THEME_PREV_MODE` реально другой |

Общие помощники — `wayland/theme-hook-lib.sh` (`theme_have`, `theme_running`,
`theme_gui`, `theme_log`, `theme_state_dir`). У Neovim хука нет намеренно: он
сам следит за state-файлом.

После хуков `theme-sync` в фоне перезапускает `wayland/wallpapers.sh`, так что
обои меняются вместе с темой (`THEME_SYNC_NO_WALLPAPER=1` отключает).

## Ручное переключение

`theme-switch [dark|light]` (`applications/theme-switch` → `~/.local/bin`) —
обёртка над `theme-sync`; без аргумента инвертирует `background-mode`. Работает и
на headless: `theme-sync` пишет state-файлы, а GUI-перезагрузки пропускает сам.
Терминал на стороне SSH-клиента он не перекрасит — палитра клиента вне контроля
сервера, меняются только цвета, которые печатают приложения (fish, helix, tmux).
rofi подхватит тему при следующем запуске, fish — на следующем промпте, ironbar —
по hot-reload обёртки; перезапускать ничего не нужно.

## Mattermost

Хук работает, только если есть `~/.config/Mattermost/config.json` и живая
графическая сессия, и только при реальной смене режима (иначе `verify.sh` и
повторный `theme-sync` перезапускали бы приложение).

- Тема чата **не локальная**, а серверная настройка пользователя: скрипт шлёт
  `theme/{dark,light}/mattermost.json` (Onyx и Quartz из v10.10.1) через
  `PUT /api/v4/users/<id>/preferences` для каждого сервера из `config.json`.
  Токен и id читаются только на чтение из `~/.config/Mattermost/Cookies`.
- Оформление окна идёт от `darkMode`, иконка трея — от `trayIconTheme`;
  `themeSyncing` не трогается: при `false` приложение следует GTK-схеме, которую
  уже ставит `theme-sync`.
- Имена вариантов иконки перевёрнуты: `"light"` — белая (для тёмной панели),
  поэтому для тёмной темы пишется `light` и наоборот. Явно, а не `"use_system"`:
  на Linux в 6.3.1 `getAppsUseLightTheme()` всегда возвращает `true`, так что
  `use_system` схлопывается в `"dark"`.
- `config.json` читается только при старте, поэтому порядок
  `kill → API + config.json → start` (`SIGTERM`, затем `SIGKILL` через 5 с),
  и только если приложение было запущено.

Ошибки уходят в `mattermost.log` и переключение не ломают.
`MATTERMOST_THEME_NO_RESTART=1` — записать без перезапуска,
`THEME_SYNC_NO_MATTERMOST=1` — пропустить хук, `THEME_SYNC_NO_RELOAD=1` —
пропустить все перезагрузки и хуки (так `verify.sh` остаётся без побочных
эффектов).

## Обои

`wayland/wallpapers.sh` читает режим из `background-mode` и берёт только файлы
`*_dark.*` / `*_light.*` (если под режим ничего нет, берутся все обои и в stderr
уходит одна строка). Рисует через `awww` (демон поднимается сам), fallback —
`swaybg`. Панорама, чей aspect совпадает с общим боксом мониторов (±1%), режется
по выходам, половинки кэшируются в `~/Wallpapers/.slices/<layout>/` и
переиспользуются, пока раскладка не изменилась (`rm -rf ~/Wallpapers/.slices` —
сбросить). Каждая смена показывает уведомление с именем исходного файла.

Переменные: `WALLPAPER_MODE`, `WALLPAPER_IMAGE`, `WALLPAPER_NO_SLICES=1`,
`WALLPAPER_NO_NOTIFY=1`, `WALLPAPER_DIR`, `WALLPAPER_BG`.

## Merge-каталоги

`~/.config/fish` и `~/.config/helix` — настоящие каталоги, файлы в них симлинки
в репозиторий (тег `merge` в `symlinks.conf`). Файлы из `install/volatile.conf`
(`fish_variables`, `fish_frozen_*.fish`) **копируются**: локальная копия не
перезаписывается, а старый симлинк в репозиторий заменяется копией при первой
установке. Нужен новый рантайм-файл — добавь его туда, поддерживаются `*`.

## Что делает каждое приложение

- **Helix.** `~/.config/helix/runtime` — симлинк на state-каталог,
  `theme = "dotfiles"` в конфиге. Helix ищет темы в
  `$XDG_CONFIG_HOME/helix/runtime/themes` без `HELIX_RUNTIME`, поэтому тема
  работает при любом способе запуска.
- **Ironbar.** Всегда запускается с `-t <state>/ironbar/style.css`: палитра в
  `colors.css`, в репозитории только раскладка без `@define-color`. Вотчер следит
  за обёрткой, поэтому после правки репозиторного CSS нужен `theme-sync`.
- **Ghostty.** Только тема: `theme = light:gruvbox-light,dark:gruvbox-dark`,
  файлы `ghostty/themes/gruvbox-{dark,light}` без расширения. Ghostty сам следит
  за `gsettings color-scheme` через libadwaita и перекрашивается без хука;
  `20-ghostty.sh` нужен для правленых палитр и как страховка. Шрифт, паддинги и
  прозрачность подогнаны под alacritty: `Noto Sans Mono` 11.25 с `JetBrains Mono`
  в fallback, `window-padding-x/y = 0` (у ghostty дефолт 2),
  `background-opacity-cells = true` (alacritty гасит всё окно композитором).
  Цвета выделения закреплены в темах, курсор — инверсия по умолчанию, как в
  alacritty; `verify.sh` сверяет hex с темами alacritty.
- **Neovim.** `nvim/lua/theme.lua` следит за `~/.local/state/dotfiles` через
  `vim.uv.new_fs_event` (дебаунс 80 мс, fallback на `new_fs_poll`), поэтому уже
  открытые редакторы переключаются без внешних бинарей и RPC-сокета. На
  изменение ставит `vim.o.background` и заново `:colorscheme`: gruvbox.nvim
  читает `background` только в `load()` и не слушает `OptionSet`.
- **Fish.** `fish_variables` локален и не в git. Fisher-плагинов нет: `ctrl-r` —
  нативный history pager, поведение одинаково на десктопе и headless. Из fzf.fish
  остались два поиска без нативного аналога:
  `fish/functions/fzf-git-status.fish` (`ctrl-alt-s`) и `fzf-git-log.fish`
  (`ctrl-alt-l`). `fish/conf.d/theme.fish` красит промпт из `background-mode`
  (`fish/themes/{dark,light}.theme`), так что универсальная переменная
  `background_mode` больше не нужна, а цвета не зависят от ANSI-палитры
  терминала. Там же `fish_handle_reflow 1`: без него fish 4.x игнорирует
  `SIGWINCH` в терминалах с reflow, и нарисованный промпт держит старую тему до
  `Enter` — цена в перерисовке промпта на каждый ресайз.
- **Tmux.** `.tmux.conf` держит обе палитры inline (`dark-theme-*` /
  `light-theme-*`, значения из gruvbox-тем alacritty), стили используют имена
  `theme*`. Нужен tmux >= 3.8 (`theme`, `theme*`, хуки
  `client-light-theme`/`client-dark-theme`), старее — `%if` откатывает на
  статичный Solarized. State-файла нет: `theme` — серверная опция, `40-tmux.sh`
  лишь делает `tmux set -s theme <mode>`, если сервер уже запущен. Сама tmux
  смену не замечает (alacritty отвечает на `OSC 11`, но не реализует
  `DECSET 2031`), поэтому сказать ей нужно явно. Режим общий для всех
  клиентов.
- **Waybar.** В переключении не участвует, живёт в rollback-режиме со статичной
  палитрой. Вернуть в тему — сгенерировать обёртку в state-каталоге, запускать
  `waybar -s <state>/waybar/style.css` и `@import` палитру.

## Проверки и ограничения

`./install/verify.sh` сверяет state-файлы с текущим режимом, раскладку
merge-каталогов и симлинков, отсутствие битых ссылок и легаси-хуков, проверяет,
что переключение темы не меняет `git status` (он read-only и возвращает текущий
режим), что `~/.local/bin/theme-switch` указывает в репозиторий, что легаси
`background_mode` не выставлена, что хуки исполняемые и синтаксически
валидны, что палитры ghostty совпадают с alacritty и что хуки
последнего переключения вышли с кодом 0.

`XDG_STATE_HOME` должен оставаться дефолтным. Кто как подхватывает: fish —
`SIGWINCH`, helix — `SIGUSR1` (новые окна видят сразу), neovim — свой вотчер,
ghostty — `SIGUSR2`, rofi — при следующем запуске, tmux — на `theme-sync`
(запущенный сервер обновляется на месте, новый подхватит режим при attach).
