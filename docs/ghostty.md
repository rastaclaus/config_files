# Ghostty

Основной терминал (`Mod`+`Return`); alacritty остаётся на `Mod`+`Shift`+`Return`
как fallback. `~/.config/ghostty` — симлинк на `ghostty/`, конфиг
`config.ghostty` (файл `config` создавать нельзя: ghostty загрузит оба и
предупредит), палитры — `ghostty/themes/gruvbox-{dark,light}` (имя темы — имя
файла без расширения, с `.conf` молча не найдётся). Проверено на **1.3.1**:
опции версионно-зависимы, сверяйся с `+list-actions` и `+show-config --docs`.
Тема — в [theme.md](theme.md).

## Чего нет в alacritty

| возможность | что даёт |
|---|---|
| key tables | модальный ввод — замена vi mode |
| shell integration | OSC 133 marks: прыжки по промптам, верный `cwd` для новых табов |
| kitty keyboard protocol | приложения получают физические клавиши и release-события |
| command palette / inspector | `ctrl+shift+p` — поиск по действиям, `ctrl+shift+i` — дамп состояния |
| встроенный поиск | `ctrl+shift+f` по экрану и скроллбеку |
| табы и сплиты | внутри одного окна; композитор видит одну плитку |

Намеренно нет vi-курсора по скроллбеку (см. ниже) и русских раскладок: таблица
из alacritty не портирована — kitty-приложениям она не нужна, а fish/readline
нужна.

## Клавиши

Полный список: `ghostty +list-keybinds` (`--default` — стоковые, `--docs` — с
описаниями).

| клавиши | действие |
|---|---|
| `ctrl+shift+c` / `ctrl+shift+v` | копировать как `mixed` / вставить CLIPBOARD |
| `ctrl+insert` / `shift+insert` | копировать как `mixed` / вставить PRIMARY |
| `ctrl+shift+y` | **наше**: выделить всё и скопировать как `plain` |
| `ctrl+alt+o` | **наше**: история + экран → файл → nvim в новом окне |
| `ctrl+alt+shift+j` | видимый экран → файл → nvim (стоковая привязка) |
| `ctrl+shift+space` | **наше**: режим `scroll-mode` |
| `shift+page_up/down`, `shift+home/end` | страница вверх/вниз, в начало / в конец |
| `ctrl+shift+page_up/down` | предыдущий / следующий промпт (нужен shell integration) |
| `ctrl+=` / `ctrl+-` / `ctrl+0` | шрифт +1 / −1 / сброс |
| `ctrl+shift+t` / `ctrl+shift+n` | новый таб / окно |
| `ctrl+shift+o` / `ctrl+shift+e` | сплит вправо / вниз, `ctrl+alt+arrows` — фокус |
| `ctrl+shift+w` / `ctrl+shift+q` | закрыть таб / выйти |
| `ctrl+,` / `ctrl+shift+,` | открыть / перечитать конфиг |

`ctrl+shift+space` — не случайность: это стоковый триггер `ToggleViMode` в
alacritty, мышечная память переносится.

```text
экран в буфер   → ctrl+shift+space, y      экран в nvim → ctrl+alt+o
экран в файл    → ctrl+shift+space, w      видимый экран → ctrl+alt+shift+j
скролл без мыши → ctrl+shift+space, j/k, ctrl+d/u, g/shift+g
внутри tmux     → prefix [ (vi-клавиши), y  |  история панели в nvim → prefix e
```

## Скроллбек

`scrollback-limit` измеряется в **байтах**, не в строках (активный экран тоже
считается, лимит на поверхность): `20_000_000` — это ~10 700 строк в окне
1280 px при ~150 колонках, примерно `history = 10000` в alacritty. Скроллбек
живёт только в памяти и не переживает перезапуск.

`ctrl+shift+space` включает key table `scroll-mode`: это скролл, а не
редактирование — vi-курсора нет.

| клавиша | действие |
|---|---|
| `j` / `k` | строка вниз / вверх |
| `ctrl+d` / `ctrl+u` | полстраницы |
| `space`, `ctrl+f` / `ctrl+b` | страница |
| `g` / `shift+g` | начало / конец |
| `]` / `[` | следующий / предыдущий промпт (`jump_to_prompt`, нужны OSC 133) |
| `/`, `n` / `shift+n` | поиск, следующий / предыдущий хит |
| `y` | весь экран в буфер как plain text |
| `w` | весь экран в файл, **путь** в буфер |
| `q`, `escape` | выйти |

Четыре ловушки при правке таблицы: `activate_key_table`, а не
`activate_key_table_once` — одноразовая снимается после первого срабатывания;
`catch_all=ignore` обязателен, иначе незнакомые клавиши утекают в шелл и в TUI;
регистр не различается, поэтому `g`/`G` — один триггер и нужно `shift+g`; у
каждой привязки свой префикс `keybind =`, а `[` пишется как
`scroll-mode/[=<action>` — парсер ищет `/` до первого `=`.

## Выделение и копирование

- Мышь кладёт выделение в **PRIMARY** (`copy-on-select = primary`): вставка —
  `shift+insert` или средняя кнопка; `ctrl+shift+v` вставляет CLIPBOARD.
- `ctrl+shift+c` копирует как `mixed` (plain + `text/html`), `ctrl+shift+y` и
  `scroll-mode/y` — намеренно `plain`: иначе дамп истории строит мегабайты HTML.
- Выделение остаётся после копирования и снимается при наборе; убрать вручную —
  `escape` или клик.
- Начать выделение с клавиатуры нечем: `adjust_selection` (`shift+arrows`)
  двигает только существующее, а на пустом экране это no-op. Единственное
  выделение с клавиатуры — `ctrl+shift+a` / `ctrl+shift+y` (всё), после него
  `shift+arrows` его двигает. Для диапазона — copy-mode в tmux.
- Цвета выделения закреплены в темах (dark `#3c3836`, light `#d5c4a1`) вместо
  инверсии ячейки: на тёмной теме она давала фон ярче светлой. Курсор остаётся
  инвертированным, как в alacritty; `verify.sh` сверяет оба значения с
  `[colors.selection]` в темах alacritty.

## Закрытие окна

`confirm-close-surface = false` — диалога «закрыть поверхность?» нет ни от кнопки
окна, ни от `ctrl+shift+w` / `ctrl+shift+q`, ни от `exit` в шелле. Опция
трёхзначная: `true` (дефолт) спрашивает только при работающем процессе,
`always` — всегда. Безопасно, потому что работа живёт в tmux (сервер переживает
окно) и в nvim (swap-файлы). Применяется по `ctrl+shift+,`.

## Дамп экрана

`write_scrollback_file` (`loc=history`) **не включает видимый экран**: он идёт
до строки над вьюпортом, поэтому такой дамп всегда отстаёт на один экран — это
осознанное поведение апстрима (issue #3496). `write_screen_file` (`loc=screen`)
берёт историю **плюс** экран, поэтому все привязки используют его.

- `ctrl+shift+space`, затем `y` — весь экран в буфер.
- `ctrl+shift+space`, затем `w` — экран как plain text уходит в
  `/tmp/<random>/screen.txt`, в буфер кладётся **путь**; дальше в nvim `:e ` +
  `ctrl+shift+v`. Склейка `chain=text:nvim ` + `paste` невозможна: конфиг
  срезает хвостовой пробел.
- `ctrl+alt+o` — история + экран в nvim одним нажатием: `write_screen_file:open`
  → `xdg-open` → шим `~/.local/bin/xdg-open` (`applications/xdg-open`) →
  `ghostty +new-window -e nvim <path>`. Шим — единственный способ запустить
  процесс из привязки: у ghostty нет `spawn`/`exec`, а `new_window` не принимает
  команду. Перехватывает только
  `$TMPDIR/<22-char base64url>/{history,screen,selection}.txt`, остальное отдаёт
  `/usr/bin/xdg-open` (в `mimeapps.list` `text/plain` привязан к helix, и менять
  ассоциацию глобально ради дампов незачем).
- В полноэкранном TUI (opencode, htop, vim, less) истории нет вообще: приложение
  живёт на alternate screen и перерисовывает одну сетку, поэтому
  `write_screen_file` отдаёт эту сетку, а `loc=history` молча ничего не делает.
  Реальный транскрипт — средствами приложения: `prefix e` в tmux, `/export`
  (`ctrl+x x`) и `ctrl+z` (`terminal_suspend`) в opencode.

## tmux

Сервер tmux держит скроллбек на панель и переживает окно терминала, но
**перерисовывает экран**: скроллбек ghostty внутри tmux почти пуст, поэтому
`j`/`k` и `shift+page_up` там почти ничего не листают.

| задача | как |
|---|---|
| листать панель | `prefix [` — copy-mode, vi-клавиши |
| поиск по истории | в copy-mode: `/` вниз, `?` вверх, `n` / `N` |
| копировать диапазон | в copy-mode: `space` — начало, `v` — блок, `y`/`Enter` |
| в системный буфер | то же: через `wl-copy`, а если его нет — tmux сам шлёт OSC 52 |
| история панели в nvim | `prefix e` |
| новый шелл в том же каталоге | `prefix v` (рядом), `prefix w` (новое окно) |

`prefix v` — это `split-window -h`, панели рядом. `prefix h` выглядит
горизонтальным аналогом, но в `.tmux.conf` он объявлен дважды и побеждает
последняя привязка (`select-pane -L`), так что это навигация: для второго сплита
нажми `prefix v` ещё раз.

`prefix e` — аналог ghostty-шного `w`: `capture-pane -S -20000 -J` (весь
`history-limit`, `-J` склеивает переносы) → `/tmp/tmux-scroll.txt` → popup
90%×90% с `nvim`. Файл перезаписывается. Для alternate-screen приложений «вся
история» — история основного экрана плюс текущий экран.

Смежные настройки: `history-limit 20000`, `set-clipboard on` (проброс OSC 52),
`escape-time 0`, `terminal-overrides alacritty:Tc` для fallback-терминала.

## SSH: terminfo и клипборд

`ssh` всегда передаёт `TERM` клиента (в pty-запросе, не через `AcceptEnv`),
поэтому из ghostty сессия приходит как `TERM=xterm-ghostty`. Нет записи в
terminfo сервера — tmux не стартует (`missing or unsuitable terminal:
xterm-ghostty`); нет capability `Ms` — tmux не поставит клипборд через OSC 52.
Обе проблемы закрывает одна строка:

```
shell-integration-features = ssh-terminfo
```

Обёртка `ssh` из shell integration на первом подключении проливает встроенную
запись в `tic -x -` на удалённом хосте (`~/.terminfo/x/xterm-ghostty`, под своим
пользователем, без root), результат кэшируется в `~/.cache/ghostty`
(`ghostty +ssh-cache` очищает). Нет `tic` или домашний каталог только на
чтение — откат на `TERM=xterm-256color`. Неподнятые фичи сохраняют дефолты.
Запись `ghostty` из ncurses 6.6 не годится: в ней нет `Tc`, и tmux сообщает
`#{client_termfeatures}` без `RGB`.

| направление | путь |
|---|---|
| копирование в copy-mode | буфер tmux → OSC 52 → ghostty ставит локальный клипборд |
| копирование из приложения в панели | `set-clipboard on` принимает и пробрасывает |
| вставка в удалённый шелл | локальный `ctrl+shift+v`, bracketed paste |
| чтение локального клипборда на сервере (`"+p`) | OSC 52 на чтение, гейтится `clipboard-read` |

`clipboard-read = allow` убирает подтверждение на каждый `"+p` — осознанный
компромисс: любой процесс на сервере сможет прочитать локальный клипборд.
Headless-хосту `wl-copy` не нужен: `y` пайпит в него, если он есть, иначе пайп
молча падает, а tmux всё равно шлёт OSC 52 (проверено на `awdesk`, tmux 3.8).

## CLI

```sh
ghostty +validate-config          # только глобальным флагом, см. ниже
ghostty +show-config --docs       # текущие значения с документацией
ghostty +list-actions             # все действия с синтаксисом аргументов
ghostty +list-keybinds --default --docs
ghostty +list-themes | +list-fonts
ghostty +ssh-cache                # забыть, куда ставили terminfo
```

`+validate-config` после действия молча возвращает 1 (то есть
`ghostty +validate-config --config-file=…` «падает» без диагностики), поэтому
писать только `ghostty --config-file=… +validate-config`. Ту же проверку делает
`install/verify.sh`.
