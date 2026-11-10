# Kitty

Основной терминал (`Mod`+`Return` в niri, `$term` в sway). Конфиг почти
дефолтный: шрифт, пейджер истории и файлы авто-темы. `~/.config/kitty` —
симлинк на `kitty/`;
палитры лежат рядом с конфигом в `{dark,light}-theme.auto.conf` — это файлы
авто-темы kitty (0.38+), а не отдельный каталог themes/. Проверено на
**0.49.2**: опции версионно-зависимы, сверяйся с `/usr/share/doc/kitty/html`
и `kitty +runpy`. Тема — в [theme.md](theme.md).

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
- Хук `22-kitty.sh` шлёт `SIGUSR1` (перечитать конфиг + заново применить
  авто-тему) — для правок файлов тем в открытых окнах и как страховка без
  портала. Обычное переключение схемы kitty делает сам.
- Для отладки: `map` на `simulate_color_scheme_preference_change toggle`
  переключает тему принудительно; `kitty --debug-rendering` пишет, какая тема
  применена.

## Пейджер истории

Скроллбак открывается в **nvim** в read-only режиме:

```conf
scrollback_pager nvim -R -c 'map q :qa!<CR>' -c 'map <Space> <C-f>' -c 'map b <C-b>' @placeholder
```

- `@placeholder` (kitty 0.42+) kitty заменяет на путь к временному файлу со
  скроллбаком; открытие файла даёт полноценный nvim с интерфейсом, поиском
  `/` и всей обычной навигацией. Вариант `@` (stdin) гонит данные через ex-
  режим nvim и вместо UI печатает текст в терминал — не использовать.
- Открывается по `ctrl+shift+page_up` (`show_scrollback`) и по клику мышью
  по истории (`mouse_map middle release ungrabbed mouse_show_scrollback`,
  стоковая привязка).
- `q` выходит без сохранения, `Space`/`b` — листать как в `less`. Строки,
  уехавшие за пейджер, теряются — kitty копит ограниченный буфер
  (`scrollback_lines`, дефолт 2000).

## Клавиши

Все шорткаты — стоковые. Часто используемые:

| клавиши | действие |
|---|---|
| `ctrl+shift+c` / `ctrl+shift+v` | копировать / вставить CLIPBOARD |
| `ctrl+shift+s` / `shift+insert` | вставить PRIMARY |
| `ctrl+shift+e` | открыть URL (kitten hints) |
| `ctrl+shift+f5` | перечитать конфиг (и так работает `auto_reload_config`) |

## Выделение и копирование

- Мышь кладёт выделение в **PRIMARY** (дефолт kitty); `ctrl+shift+v` вставляет
  CLIPBOARD, `shift+insert` — PRIMARY.
- **hints kitten** (`kitten hints`) — точное mouseless-выделение: kitty
  подсвечивает кандидатов, буква выбирает совпадение. Стоковая привязка
  `ctrl+shift+e` открывает URL; вручную: `kitten hints --type=path
  --program=@` копирует путь в CLIPBOARD (`@` — CLIPBOARD, `*` — PRIMARY).
- Весь экран + история одной командой:
  `launch --type=clipboard --stdin-source=@screen_scrollback cat` — то же, что
  `select_all + copy_to_clipboard`, но с историей без отставания.
- Тот же дамп в nvim поверх окна:
  `launch --type=overlay --stdin-source=@screen_scrollback nvim -`.

## OSC 52 и SSH

Дефолтный `clipboard_control` (`read-clipboard-ask`) спрашивает подтверждение
на каждое чтение клипборда удалённым приложением (nvim `"+p`). Если запросы
мешают — включи `clipboard_control write-clipboard write-primary
read-clipboard read-primary` (компромисс: любой процесс на сервере сможет
читать локальный буфер). Запись и так разрешена по умолчанию — tmux
`set-clipboard on` работает без настроек.

terminfo на сервере: из kitty сессия приезжает как `TERM=xterm-kitty`; системная
запись содержит `Tc` и `setrgbf`, так что локальный tmux ничего не требует.
На удалённом хосте записи нет — tmux не стартует; решение — ssh kitten
(`kitten ssh host`: сам проливает terminfo и включит shell integration) или
разовый `infocmp -a xterm-kitty | ssh host tic -x -o ~/.terminfo /dev/stdin`.

## tmux

Внутри tmux вьюпорт терминала почти пуст, скроллится сам tmux — `prefix [`
(copy-mode, vi-клавиши), `y`/`Enter` копируют через `wl-copy`, `prefix e` —
история панели в nvim.

## CLI

```sh
kitty --debug-rendering           # в лог уйдёт, какая авто-тема применена
kitty +runpy 'from kitty.config import load_config; load_config("kitty.conf")'   # парсер конфига
kitten hints --type=path          # выделение пути с клавиатуры
kitten ssh host                   # ssh с автопроливом terminfo
```
