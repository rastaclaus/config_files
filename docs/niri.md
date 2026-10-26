# niri

**niri** — scrollable-tiling Wayland-композитор: окна живут в колонках на
бесконечной горизонтальной ленте, а не в сетке. Конфиг —
`niri/config.kdl` + `hosts/<host>/config/niri/config.d/`; апстрим —
<https://niri-wm.github.io/niri/>. Выбор композитора (`wm niri`) и общая
Wayland-обвязка — в [README](../README.md), тема и обои — в
[theme.md](theme.md).

`niri validate` проверяет конфиг без запуска, `-c ./config.kdl` — конкретный
файл. Правки применяются на лету при сохранении; `output`/порты требуют
перезапуска сессии.

## Модель окон

| термин | что это |
|---|---|
| **колонка** | столбец окон; окна внутри прижаты друг к другу сверху вниз |
| **лента** | бесконечный ряд колонок, листается фокусом и перемещением |
| **workspace** | динамическое рабочее пространство на монитор, создаётся по нужде |
| **overview** | уменьшенная картинка всех workspace |
| **floating** | плавающее окно поверх тайлинга |
| **tabbed** | колонка, где окна показаны вкладками |

Отличие от sway: `Mod+H`/`Mod+L` ходят **по колонкам**,
`Mod+Page_Up`/`Mod+Page_Down` — **по окнам внутри колонки**, `Mod+J`/`Mod+K` —
по workspace. `Mod+Home`/`Mod+End` — начало/конец ленты.

## Клавиши

`Mod` = **Super**. Полный оверлей подсказок — `Mod+Shift+/`. Ниже — набор из
`config.kdl` (синхронизирован со sway там, где у niri есть аналог).

| клавиши | действие |
|---|---|
| `Mod+Return` / `Mod+Shift+Return` | ghostty / alacritty (fallback) |
| `Mod+D` | rofi combi; `Alt+Tab` — переключатель окон |
| `Mod+Shift+U` / `Mod+Shift+S` | rofi: юникод / эмодзи |
| `Mod+N` | networkmanager-dmenu |
| `Mod+T` | сменить обои (в пределах текущей темы) |
| `Ctrl+Alt+L` | заблокировать (swaylock) |
| `Mod+Shift+E` / `Ctrl+Alt+BackSpace` | выйти из niri |
| `Mod+Shift+Q` | закрыть окно |
| `Mod+Shift+/` | оверлей подсказок |

| клавиши | действие |
|---|---|
| `Mod+H` / `Mod+L` (или `←/→`) | фокус: колонка влево / вправо |
| `Mod+Page_Up` / `Page_Down` (или `↑/↓`) | фокус: окно вверх / вниз |
| `Mod+Shift+H/L` | переместить колонку влево / вправо |
| `Mod+Shift+Page_Up/Page_Down` | переместить окно вверх / вниз в колонке |
| `Mod+Ctrl+H/J/K/L` | фокус на другой монитор |
| `Mod+Ctrl+Shift+H/J/K/L` | переместить колонку на другой монитор |
| `Mod+Home` / `Mod+End` | первая / последняя колонка |
| `Mod+Ctrl+Home` / `Mod+Ctrl+End` | переместить колонку в начало / конец |

| клавиши | действие |
|---|---|
| `Mod+J` / `Mod+K` | workspace вниз / вверх |
| `Mod+Shift+J` / `Mod+Shift+K` | переместить колонку в workspace вниз / вверх |
| `Mod+1` … `Mod+0` | перейти на workspace 1…10 |
| `Mod+Shift+1` … `Mod+Shift+0` | переместить колонку на workspace 1…10 |
| `Mod+Ctrl+Page_Up/Page_Down` | переместить колонку в workspace вверх / вниз |
| `Mod+Wheel ↑/↓`, `Mod+Ctrl+Wheel ↑/↓` | листать workspace / тащить колонку колесом |
| `Mod+Wheel ←/→` | фокус по колонкам колесом |

`Mod+1..0` — переход на *конкретный* workspace, нумерация динамическая (в
отличие от номеров рабочих столов в sway).

| клавиши | действие |
|---|---|
| `Mod+O` | overview |
| `Mod+BracketLeft` / `BracketRight` | вытащить окно из колонки / задвинуть |
| `Mod+,` / `Mod+.` | вставить окно в колонку / вынуть из неё |
| `Mod+R` / `Mod+Shift+R` | следующая / предыдущая ширина колонки (пресеты) |
| `Mod+Minus` / `Equal`, `Mod+Shift+Minus` / `Equal` | ширина −10% / +10%, высота −10% / +10% |
| `Mod+W` | колонка в режиме вкладок |
| `Mod+F`, `Mod+Shift+F`, `Mod+M`, `Mod+E` | fullscreen, maximize колонки, окно до краёв, колонка на всю ширину |
| `Mod+C` / `Mod+Ctrl+C` | центрировать колонку / видимые колонки |
| `Mod+V` (или `Mod+Shift+Space`) | toggle плавающего окна |
| `Mod+Space` (или `Mod+Shift+V`) | переключить фокус между плавающим и тайлингом |

| клавиши | действие |
|---|---|
| `Print` / `Ctrl+Print` / `Alt+Print` | область / весь экран / окно → `~/screenshots/` |
| `Mod+Shift+P` | выключить мониторы |
| `Mod+Escape` | обход блокировки хоткеев (VM/RDP) |
| `XF86Audio*` | громкость (pactl), работает и на локскрине |
| `XF86MonBrightness*` / `XF86TouchpadToggle` | яркость (brightnessctl) / тачпад |

## Визуальные настройки

```kdl
prefer-no-csd              // приложения прячут свои декорации
layout {
    gaps 0                 // без отступов, окна вплотную
    focus-ring { width 2; active-color "#7fc8ff"; inactive-color "#505050" }
}
```

`prefer-no-csd` делает окна прямоугольными, рамку рисует niri; минус — у части
окон пропадают ручки ресайза за край, тогда тянуть за границу с зажатым
`Mod`+ЛКМ. `layout { border { … } }` добавит рамку вокруг **всех** окон,
`layout { gaps 16 }` вернёт отступы.

Рамка (`focus-ring`) рисуется **залитым прямоугольником за окном**, а не
обводкой, поэтому у полупрозрачного терминала она просвечивает через фон и
красит его (0.8·`#282828` + 0.2·`#7fc8ff` ≈ `#394853`). Лечится правилом,
которое уже в конфиге — рисовать контур даже при клиентских CSD:

```kdl
window-rule {
    match app-id=r#"^(com\.mitchellh\.ghostty|Alacritty)$"#
    draw-border-with-background false
}
```

## Хостовые настройки

```kdl
include "config.d/10-outputs.kdl"                  // мониторы
include "config.d/20-inputs.kdl"                   // ввод
include "config.d/50-touchpad.kdl" optional=true   // создаётся toggletouch.sh
```

Файлы приходят из `hosts/<host>/config/niri/config.d/`. Примеры: **desktop** —
`HDMI-A-1` (2560×1440, x=0) + `DP-1` (2560×1440, x=2560); **ambb** — `eDP-1`
3072×1920@120 со `scale 1.4`. Посмотреть рантайм: `niri msg outputs`.

## niri msg

```sh
niri msg workspaces|windows|outputs     # списки
niri msg action <action>                # toggle-overview, power-off-monitors, toggle-touchpad
niri msg --json workspaces | jq .       # машиночитаемо
niri msg action --help                  # полный список действий
```

## Автозапуск

Из `config.kdl` поднимаются `swaync` (уведомления), `gammastep` (Москва,
55.817521/37.695987), `nm-applet` (через `wayland/wait-sni.sh`) и
`swayidle -w`: блокировка через 5 мин, гашение экрана через 10, suspend через 30
(`before-sleep` тоже лочит). Обои отдельной строкой не запускаются — их ставит
`theme-sync`. Портал — `niri-portals.conf` (GNOME screencast backend).

## Диагностика

- **Обои не ставятся, в логе `Unable to connect to …/sway-ipc…sock`** — в
  systemd-окружении пользователя застрял `SWAYSOCK` от прошлой sway-сессии
  (`niri-session` затягивает его обратно через `import-environment`).
  Проверить: `~/.config/wayland/wallpapers.sh` (при успехе молчит),
  `pgrep -a awww-daemon`, `awww query`, `cat "$XDG_RUNTIME_DIR/wallpapers.log"`,
  `cat ~/.local/state/dotfiles/background-mode`. Убрать:
  `systemctl --user unset-environment SWAYSOCK`.
- **Конфиг не применился** — `niri validate`; `output` и порты ждут перезапуска
  сессии, остальное применяется на лету.
- **`niri msg` не отвечает** — пустой `NIRI_SOCKET`: команда работает только
  внутри сессии.
