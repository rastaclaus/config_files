# WezTerm

Второй терминал (`Shift`+`Mod`+`Return` в niri/sway; kitty остаётся на
`Mod`+`Return`). Конфиг почти дефолтный: шрифт, прямоугольное окно и
авто-тема. `~/.config/wezterm` — симлинк на `wezterm/`; конфиг — единственный
файл `wezterm.lua`. Тема — в [theme.md](theme.md).

## Тема: авто-переключение light/dark

В wezterm это встроено и работает из коробки: он читает
`org.freedesktop.appearance color-scheme` через xdg-desktop-portal (на этом
десктопе значение отдаёт darkman, см. `xdg-desktop-portal/niri-portals.conf`),
а на смену схемы **сам перечитывает конфиг** — `wezterm.gui.get_appearance()`
вызывается при каждом reload. Отдельный хук в `wayland/theme-hooks.d/`, в
отличие от kitty, не нужен вовсе.

```lua
local function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then return 'GruvboxDark' else return 'GruvboxLight' end
end
```

- Палитры — **встроенные схемы** wezterm (`GruvboxDark`/`GruvboxLight`), а не
  копия палитр kitty: оттенки слегка отличаются от
  `kitty/{dark,light}-theme.auto.conf`.
- `wezterm.gui` недоступен в mux-сервере (даemons и т.п.): перед чтением
  appearance проверка `if wezterm.gui`, в fallback — тёмная схема. Рецепт из
  документации `wezterm.gui.get_appearance()`.

## Клавиши

Стоковые плюс два своих маппинга:

| клавиши | действие |
|---|---|
| `alt+h` / `alt+l` | предыдущая / следующая вкладка wezterm (свой `keys`) |
| `ctrl+shift+h` | copy mode (свой `keys`; дефолтный `ctrl+shift+x` тоже остался) |
| `ctrl+shift+t` | новая вкладка в cwd активной панели (**дефолт** wezterm) |
| `ctrl+shift+w` | закрыть вкладку (дефолт) |
| таб-бар | снизу, ретро-стиль (моно-шрифт), скрыт при одной вкладке, палитра kitty — см. [Таб-бар](#таб-бар) |

- `alt+h`/`alt+l` работают и на русской раскладке: биндинг задан с префиксом
  `phys:` — wezterm мапит по физической позиции клавиши ANSI-US, а не по
  символу раскладки (у kitty так же: маппинг по «латинской букве»). Побочный
  эффект как у kitty: `alt+h/l` больше не доходят до TUI-программ (mc, htop).
  `ctrl+shift+h` задан так же (`phys:h`).
- Наследование cwd в новой вкладке у wezterm **штатное** (`SpawnCommandInNewTab`
  без `cwd`): каталог берётся из OSC 7 (fish печатает сам) или из `/proc`
  лидера группы процессов. Kitty-маппинга `new_tab_with_cwd` не нужно;
  внутри ssh — только через OSC 7 (shell-интеграция на удалённом хосте),
  внутри tmux cwd не прокидывается — как и в kitty.

## Окно

`window_decorations = "NONE"` — полностью без декораций: ни заголовка, ни
клиентской рамки. На Wayland ресайз тайлового окна делает композитор
(`xdg_toplevel.resize`), которому клиентская рамка не нужна; документация
предупреждает, что `NONE` ломает ресайз **за клиентскую рамку** — на этом
десктопе он и не нужен. В режиме `RESIZE` wezterm рисует собственную рамку
(FallbackFrame) — она выглядела как лишняя полоса у тайлового окна. Дополнительно
в `niri/config.kdl` есть window-rule `draw-border-with-background false` для
`org.wezfurlong.wezterm` — как у kitty: фокус-рамка niri рисуется контуром, а не
залитым прямоугольником за окном (не критично при непрозрачном wezterm, но
держит визуал одинаковым). Запускается нативно на Wayland (socket `wayland-1`,
app-id `org.wezfurlong.wezterm`), xwayland не нужен; геометрия тайла совпадает
с kitty, под ironbar окно не заезжает.

## Таб-бар

Как в kitty: снизу, текстовый, скрыт при одной вкладке.

| опция | значение | kitty-аналог |
|---|---|---|
| `tab_bar_at_bottom` | `true` | `tab_bar_edge bottom` |
| `use_fancy_tab_bar` | `false` (ретро: моно-шрифт терминала) | kitty рисует таб-бар тем же шрифтом |
| `hide_tab_bar_if_only_one_tab` | `true` | `tab_bar_min_tabs 2` |
| `show_new_tab_button_in_tab_bar` / `show_close_tab_button_in_tabs` | `false` | `tab_bar_hide_buttons`-подобное поведение kitty не рисует кнопок в fade-стиле |

Цвета — из kitty-палитр (`{dark,light}-theme.auto.conf`): полоса
`#1d2021`/`#ebdbb2`, активный таб `#504945`/`#d5c4a1`, неактивный
`#3c3836`/`#ebdbb2`. Ключи задаются вложенно в `config.colors.tab_bar.*`
(не в корне `colors` — иначе `active_tab is not a valid Palette field`).
Проверено пиксельно (тёмная тема): полоса `#1d2021`, табы `#3c3836`/`#504945`.
Формат таба — дефолтный ретро `N: title`; кнопки «+»/«×» погашены: вкладки
создаются `ctrl+shift+t`, закрываются `ctrl+shift+w`.

## SSH и персистентные сессии

Два режима, оба читают `~/.ssh/config` (`Host`, `HostName`, `User`, `Port`,
`IdentityFile`, `ProxyCommand`, …; `Match` и `Include` игнорируются).

### Ad-hoc: `wezterm ssh`

```sh
wezterm ssh work          # вкладка wezterm с ssh-сессией внутрь
```

Встроенный libssh2-клиент, без конфига. Новые вкладки и сплиты в этом окне
(`ctrl+shift+t`, `ctrl+shift+d`) — новые каналы **той же сессии**: второй раз
логиниться не нужно. Минус: сессия не переживает обрыв сети — все вкладки
умирают вместе с соединением.

### Персистентный mux-домен: `wezterm connect`

```sh
wezterm connect SSHMUX:work            # окно, приатченное к mux-серверу на work
wezterm connect SSHMUX:work --new-tab  # вкладкой в уже открытое окно wezterm
```

wezterm по SSH поднимает на удалённой стороне `wezterm-mux-server` и держит
вкладки в его домене: обрыв соединения рвёт только канал, пере`connect` — и
вкладки на месте (аналог tmux attach). Требования и особенности:

- **wezterm должен быть установлен на удалённом хосте** (на `work` он есть —
  пакет в extra, ставится манифестом).
- С версии 20230408 домены авто-наследуются из `~/.ssh/config`: каждому хосту
  — пара `SSH:<имя>` (ad-hoc) и `SSHMUX:<имя>` (персистентный mux). Имя — как
  в `Host`-строке; чтобы домен назывался `work`, в ssh-config нужна запись
  `Host work` + `HostName …`.
- Имя берётся из `Host`-паттерна **буквально**: опечатка вида `Host work:`
  рождает домены `SSH:work:`/`SSHMUX:work:` (с двоеточием), и
  `wezterm connect SSH:work` падает с `desired default domain … was not
  found in mux!?; terminating` — GUI не находит домен с точным именем. Сам
  OpenSSH этот блок тоже не применяет (паттерны матчатся буквально), лечится
  правкой ssh-config; посмотреть, какие домены получились, можно, выполнив
  `wezterm.default_ssh_domains()` в конфиге (лог через `wezterm.log_info`).
- Вкладки/сплиты внутри домена спавнятся штатными клавишами — они попадают в
  домен текущей вкладки, переключение то же (`alt+h`/`alt+l`).
- terminfo проливается сам (в отличие от kitty, `infocmp | ssh tic` не нужен);
  cwd-наследование новых вкладок — через OSC 7, т.е. нужна shell-интеграция на
  удалённом хосте, иначе вкладка откроется в `$HOME`.

### Соотношение с shpool и tmux

На `work` уже живёт **shpool** (attach-сессии для голого ssh из любого
клиента, см. README). Мыzterm-домен — самостоятельная альтернатива для окон
wezterm; смешивать не стоит: mux поверх shpool-сессии — двойное
мультиплексирование. Локально tmux остаётся; локальная персистентность самого
wezterm (unix-домены, `wezterm gui-server`) —
[unix-domains](https://wezterm.org/config/lua/config/unix_domains.html), здесь
не используется.

## CLI

```sh
wezterm --config-file repo/wezterm/wezterm.lua show-keys   # парсер конфига + биндинги
wezterm show-keys                                          # биндинги живого конфига
```

Отдельного CLI-валидатора lua-конфига у wezterm нет: `show-keys` загружает
конфиг и падает с traceback в stderr при ошибке — им и пользуется
`install/verify.sh` (блок 4c-bis). terminfo: сессия приезжает как
`TERM=wezterm`; запись ставится пакетом (`ncurses`, optional-зависимость
wezterm) — на удалённый хост проливается тем же `infocmp | ssh host tic -x`
без kitty-специфики.
