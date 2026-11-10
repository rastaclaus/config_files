# Kitty

Третий терминал (`Mod`+`Ctrl`+`Return` в niri, `$term_kitty` в sway) с конфигом,
зеркалящим ghostty: тот же шрифт и паддинги, те же палитры, тот же модальный
scroll-mode на `ctrl+shift+space`. `~/.config/kitty` — симлинк на `kitty/`;
палитры лежат рядом с конфигом в `{dark,light}-theme.auto.conf` — это файлы
авто-темы kitty (0.38+), а не отдельный каталог themes/. Проверено на **0.49.2**:
опции версионно-зависимы, сверяйся с `/usr/share/doc/kitty/html` и `kitty +runpy`.
Тема — в [theme.md](theme.md).

## Чего в kitty нет (в отличие от ghostty)

| возможность в ghostty | что в kitty |
|---|---|
| встроенный поиск `ctrl+shift+f` | нет: `search_scrollback` открывает весь скроллбек в less, `/` ищет там |
| `write_screen_file` (дамп в файл + xdg-open) | `launch --stdin-source=@screen_scrollback` отдаёт текст сразу программе — nvim-дамп без файла-посредника |
| vi-курсора нет ни там, ни там | выделение с клавиатуры — только kitten hints (см. ниже) |
| `ssh-terminfo` из shell integration | ssh kitten (`kitten ssh`) проливает terminfo сам; для штатного `ssh` — разовый `infocmp -a xterm-kitty \| ssh host tic -x -o ~/.terminfo /dev/stdin` |

## Тема: авто-переключение light/dark

В kitty это встроено и работает через **файлы авто-темы** в каталоге конфига:
`dark-theme.auto.conf` и `light-theme.auto.conf`. На старте и на смену схемы ОС
kitty читает `org.freedesktop.appearance color-scheme` через xdg-desktop-portal —
на этом десктопе значение отдаёт darkman (см. `xdg-desktop-portal/niri-portals.conf`)
— и перекрашивает уже открытые окна без перезапуска и без хука. Файл
`no-preference-theme.auto.conf` включает светлую палитру (`include
light-theme.auto.conf`): darkman на этом десктопе всегда отдаёт light или dark,
но GNOME-портал без тёмного стиля отвечает no-preference, и без файла kitty
остался бы на дефолтных цветах.

- Файл темы принимает **только цветовые ключи** (палитра, выделение, курсор,
  таб-бар, `transparent_background_colors`, `background_image`) плюс `include`
  (резолвится относительно каталога kitty); `font_family` или
  `background_opacity` в нём молча не сработают.
- **Прозрачность в файл темы не влезает**: у kitty `background_opacity` не
  цветовой ключ. Базовые `0.8` заданы в `kitty.conf` (тёмная тема — как в
  ghostty), а светлая глушит прозрачность через
  `transparent_background_colors #fbf1c7@1.0`: клетки с дефолтным фоном
  рисуются непрозрачными. Расхождение с ghostty: клетки с присвоенным цветом
  (статус-бары TUI) в light остаются `0.8`, у ghostty они непрозрачны.
- Хук `22-kitty.sh` шлёт `SIGUSR1` (перечитать конфиг + заново применить
  авто-тему) — для правок файлов тем в открытых окнах и как страховка без
  портала. Обычное переключение схемы kitty делает сам.
- `window-theme = system` из ghostty не нужен: декорации скрыты, а kitty без
  CSD вообще не рисует заголовок; хром окна следует палитре темы.
- Для отладки: `map` на `simulate_color_scheme_preference_change toggle`
  переключает тему принудительно; `kitty --debug-rendering` пишет, какая тема
  применена.

## Клавиши

| клавиши | действие |
|---|---|
| `ctrl+shift+c` / `ctrl+shift+v` | копировать / вставить CLIPBOARD (стоковые) |
| `ctrl+shift+s` / `shift+insert` | вставить PRIMARY (стоковые) |
| `ctrl+shift+y` | **наше**: экран + история в CLIPBOARD как plain text |
| `ctrl+alt+o` | **наше**: экран + история в nvim поверх окна |
| `ctrl+shift+space` | **наше**: режим `scroll-mode` |
| `ctrl+shift+f5` | перечитать конфиг (и так работает `auto_reload_config`) |

## Модальный scroll-mode

`ctrl+shift+space` входит в keyboard mode `scroll-mode` — kitty-аналог key
table из ghostty. В mode клавиша срабатывает и режим **остаётся** включённым;
`q` / `escape` выходят.

| клавиша | действие |
|---|---|
| `j` / `k` | строка вниз / вверх |
| `ctrl+d` / `ctrl+u` | полстраницы вниз / вверх (`remote_control scroll-window 15l[−]`) |
| `space`, `ctrl+f` / `ctrl+b` | страница вниз / вверх |
| `g` / `shift+g` | начало / конец скроллбека |
| `]` / `[` | следующий / предыдущий промпт (`scroll_to_prompt`, fish ставит OSC 133-метки сам) |
| `/` | скроллбек в less (поиск — `/`, `n`/`N` внутри него) |
| `y` / `shift+y` | экран + история в CLIPBOARD / PRIMARY, plain text |
| `w` | экран + история в nvim (overlay, `nvim -`) |
| `u` / `p` / `o` | hints: URL / путь / строка → в CLIPBOARD |
| `q`, `escape` | выйти |

Четыре ловушки при правке режима:

- `--on-unknown ignore` обязателен: дефолт для незнакомой клавиши в режиме —
  **beep**, а утечки букв в шелл ghostty-стиля `catch_all` в kitty нет.
- `--allow-fallback=shifted,ascii` нужен на каждой буквенной привязке: дефолт
  для кастомных `map` — только shifted, и на русской раскладке «о» не нашла бы
  физическую `j`. Стоковые шорткаты получают оба fallback автоматически.
- `scroll_line_down`/`scroll_page_down` не принимают счётчик (аргумент только
  `smooth`); полстраницы и страницы считаются через
  `remote_control scroll-window` — из `map` он работает без
  `allow_remote_control`.
- В alt-screen (htop, vim, less) `scroll_*` — no-op: режим входит, но не листает
  (там скроллит приложение; в tmux — его copy-mode, `prefix [`).

## Выделение и копирование без мыши

Vi-курсора по скроллбеку в kitty нет и не будет: issue #719 закрыт со ссылкой
на пейджер. Рабочие замены:

- **hints kitten** (`kitten hints`) — точное mouseless-выделение: kitty
  подсвечивает кандидатов, буква выбирает совпадение. В scroll-mode:
  `u` — URL, `p` — путь, `o` — строка; `--program=@` копирует в CLIPBOARD,
  `*` — в PRIMARY. Глобально на `ctrl+shift+e` открывается URL (стоковая).
- **`y` / `ctrl+shift+y`** — весь экран + история одним нажатием:
  `launch --type=clipboard --stdin-source=@screen_scrollback`. Это аналог
  ghostty-шного `select_all + copy_to_clipboard:plain`, включая отсутствие
  проблемы `write_scrollback_file` — `@screen_scrollback` всегда берёт историю
  **плюс** видимый экран.
- **`w` / `ctrl+alt+o`** — то же в nvim поверх окна
  (`launch --type=overlay ... nvim -`); файла-посредника, как у ghostty через
  xdg-open shim, не нужно. В alt-screen `@screen_scrollback` отдаёт сетку
  alt-screen — как `write_screen_file` у ghostty.
- Мышь кладёт выделение в **PRIMARY** (дефолт Linux-kitty, `copy_on_select`
  не включён — ровно как `copy-on-select = primary` в ghostty); `ctrl+shift+v`
  вставляет CLIPBOARD, `shift+insert` — PRIMARY.
- Цвета выделения закреплены в темах (dark `#3c3836`, light `#d5c4a1`) — как в
  ghostty и alacritty; `verify.sh` сверяет hex по всем трём терминалам. Курсор
  в kitty не инвертирует клетку сам, поэтому цвета заданы явно (fg на bg).

## OSC 52 и SSH

`clipboard_control write-clipboard write-primary read-clipboard read-primary` —
аналог ghostty-шного `clipboard-read = allow`: чтение клипборда удалённым
`"+p` без запросов, тот же компромисс (любой процесс на сервере читает
локальный буфер). Запись и так разрешена по умолчанию — tmux `set-clipboard on`
работает без настроек.

terminfo на сервере: из kitty сессия приезжает как `TERM=xterm-kitty`; системная
запись содержит `Tc` и `setrgbf`, так что локальный tmux ничего не требует.
На удалённом хосте записи нет — tmux не стартует; решение — ssh kitten
(`kitten ssh host`: сам проливает terminfo и включит shell integration) или
разовый `infocmp -a xterm-kitty | ssh host tic -x -o ~/.terminfo /dev/stdin`.

## tmux

Всё как у ghostty: внутри tmux вьюпорт терминала почти пуст, скроллится сам
tmux — `prefix [` (copy-mode, vi-клавиши), `y`/`Enter` копируют через
`wl-copy`, `prefix e` — история панели в nvim. `scroll-mode` kitty внутри tmux
не нужен, но и не мешает: `scroll_*` в main-screen листают пустой вьюпорт.

## CLI

```sh
kitty --debug-rendering           # в лог уйдёт, какая авто-тема применена
kitty +runpy 'from kitty.config import load_config; load_config("kitty.conf")'   # парсер конфига (его же зовёт verify.sh)
kitten themes                     # браузер тем (пишет в kitty.conf — не использовать,
                                  # тема у нас в *-theme.auto.conf)
kitten hints --type=path          # выделение пути с клавиатуры
kitten ssh host                   # ssh с автопроливом terminfo
```

`verify.sh` проверяет симлинк, парсит конфиг через kitty, сверяет палитры,
выделение и прозрачность с alacritty/ghostty.
