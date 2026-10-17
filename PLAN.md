# План: рефакторинг конфигов без рантайм-изменений в репозитории

Цель: репозиторий — read-only источник конфигов. Всё, что приложения и
скрипты переключают в рантайме (тема dark/light, universal-переменные fish,
плагины fisher), живёт вне рабочего дерева репозитория.

Принятые решения:

1. **Fish — вариант B.** `~/.config/fish` перестаёт быть симлинком на каталог
   и становится реальным каталогом с симлинками на файлы репозитория;
   рантайм-файлы рыбы (и fisher) — обычные локальные файлы, в git их нет.
2. **Helix — merge-режим без env-переменных.** `~/.config/helix` — реальный
   каталог; `runtime/` внутри него — симлинк в state-каталог, где лежит тема
   `dotfiles`.
3. **Waybar не трогаем.** Он остаётся в rollback-режиме со статической
   палитрой; в README это фиксируется.

Проверено экспериментально на живых бинарях (Context7 был недоступен —
исчерпана месячная квота, поэтому поведение сверялось по `man` и запуском
бинарников):

- Alacritty: `[general] import`, `~/` раскрывается, отсутствующие импорты
  молча пропускаются, импортирующий файл загружается **последним** (его ключи
  перебивают импорт), nested-imports работают (`man 5 alacritty`,
  `alacritty migrate --dry-run`).
- Rofi 2.0: `?import "~/..."` работает, отсутствующий файл — только warning;
  `@theme` внутри импортированного файла перекрывает более ранний `@theme`
  (`rofi -dump-theme`).
- Helix 25.07.1: таблицы `[theme] dark/light` нет (ошибка парсинга TOML);
  тема ищется в `$XDG_CONFIG_HOME/helix/runtime/themes/` без `HELIX_RUNTIME`;
  `inherits = "gruvbox_light"` работает.
- Fish 4.9.3: `fish_config theme choose` **не пишет на диск**; единственный
  постоянный писатель — `fish_variables` (universal vars). `--on-variable`
  в других процессах не срабатывает. `pkill -USR1 fish` без обработчика
  убивает шелл — сигналы для fish не используем.
- Ironbar 0.19.1: есть `-t/--theme` (env `IRONBAR_CSS`), watcher на inotify
  за основным css-файлом; GTK `@import` требует абсолютный путь (`~` не
  раскрывает).
- Darkman 2.3.1: современный хук — `$XDG_DATA_HOME/darkman/theme`, получает
  `dark|light` первым аргументом; legacy-каталоги продолжают выполняться.

---

## Этап 0. Зафиксировать текущее состояние (baseline)

Сейчас в рабочем дереве лежит «светлая» тема (рантайм-изменения), в HEAD —
«тёмная». Чтобы дальнейшие шаги были проверяемыми:

```sh
cd ~/config_files
git add alacritty/alacritty.toml fish/fish_variables helix/config.toml \
        ironbar/style.css rofi/config.rasi waybar/style.css
git commit -m "snapshot: current light theme runtime state"
```

`session.md` — рабочий экспорт, в коммит не включаем (при желании добавить
в `.gitignore` отдельным коммитом).

После этого `git status` чист, и любой последующий diff — это уже рефакторинг.

---

## Этап 1. Шаблоны тем `theme/{dark,light}/`

Новый каталог в репозитории; никуда не симлинкуется, читается только
`theme-sync`. Значения: dark — из HEAD, light — из baseline-коммита.

### `theme/dark/alacritty.toml`

```toml
# Фрагмент конфигурации Alacritty для тёмной темы.
# Копируется в ~/.local/state/dotfiles/alacritty.toml скриптом theme-sync.
[general]
import = ["~/.config/alacritty/themes/themes/gruvbox_dark.toml"]

[window]
opacity = 0.8
```

### `theme/light/alacritty.toml`

То же, но `gruvbox_light.toml` и `opacity = 1.0`.

### `theme/dark/rofi.rasi`

```rasi
@theme "gruvbox-dark-soft"
```

### `theme/light/rofi.rasi`

```rasi
@theme "gruvbox-light-soft"
```

### `theme/dark/helix.toml`

```toml
# Тема Helix: переключается только через inherits.
inherits = "gruvbox"
```

### `theme/light/helix.toml`

```toml
inherits = "gruvbox_light"
```

### `theme/dark/ironbar.css`

```css
/* Палитра ironbar для тёмной темы. Импортируется сгенерированной обёрткой. */
@define-color bar_bg #282828;
@define-color bar_fg #ebdbb2;
@define-color bar_accent #fabd2f;
@define-color bar_inactive #928374;
@define-color bar_critical #fb4934;
```

### `theme/light/ironbar.css`

```css
@define-color bar_bg #fbf1c7;
@define-color bar_fg #3c3836;
@define-color bar_accent #b57614;
@define-color bar_inactive #928374;
@define-color bar_critical #9d0006;
```

---

## Этап 2. `wayland/theme-sync` и `darkman/theme`

### `wayland/theme-sync` (новый, `chmod +x`)

```bash
#!/usr/bin/env bash
#
# Применить тему dark|light: обновить state-файлы и перезагрузить приложения.
# Репозиторий не изменяется: пишем только в ~/.local/state/dotfiles.
#
#   theme-sync dark|light
#
# THEME_SYNC_NO_RELOAD=1 — только записать файлы (используется verify.sh).
set -euo pipefail

SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
REPO="$(cd "$(dirname "$SCRIPT")/.." && pwd)"
# ВАЖНО: путь фиксирован (XDG-дефолт), потому что alacritty/rofi не умеют
# подставлять переменные окружения в import-пути. При смене XDG_STATE_HOME
# нужно править и эти конфиги.
STATE="$HOME/.local/state/dotfiles"

mode="${1:-}"
case "$mode" in
    dark|light) ;;
    *) echo "usage: $0 dark|light" >&2; exit 2 ;;
esac

mkdir -p "$STATE/alacritty" "$STATE/helix/runtime/themes" "$STATE/ironbar"

printf '%s\n' "$mode" > "$STATE/background-mode"

# cat > файл сохраняет inode (нужно для inotify-вотчеров ironbar).
copy() { # copy <src> <dst>
    [[ -f "$1" ]] || return 0
    cat "$1" > "$2"
}

copy "$REPO/theme/$mode/alacritty.toml" "$STATE/alacritty.toml"
copy "$REPO/theme/$mode/rofi.rasi"      "$STATE/rofi.rasi"
copy "$REPO/theme/$mode/helix.toml"     "$STATE/helix/runtime/themes/dotfiles.toml"

# Ironbar: палитра + обёртка. GTK не раскрывает ~ в @import, поэтому пути
# абсолютные; REPO вычисляется из расположения скрипта.
copy "$REPO/theme/$mode/ironbar.css" "$STATE/ironbar/colors.css"
{
    printf '/* generated by theme-sync: mode=%s */\n' "$mode"
    printf '@import url("%s");\n' "$STATE/ironbar/colors.css"
    printf '@import url("%s");\n' "$REPO/ironbar/style.css"
} > "$STATE/ironbar/style.css"

[[ ${THEME_SYNC_NO_RELOAD:-0} == 1 ]] && exit 0

# GTK / xdg-desktop-portal
if command -v gsettings >/dev/null 2>&1; then
    if [[ $mode == dark ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    else
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3
        gsettings set org.gnome.desktop.interface color-scheme prefer-light
    fi
fi

# Helix перечитывает конфиг и тему по SIGUSR1.
pkill -USR1 -x helix 2>/dev/null || true
pkill -USR1 -x hx 2>/dev/null || true

# Уже открытые Neovim.
if [[ -x "$HOME/.cargo/bin/nvim-ctrl" ]]; then
    "$HOME/.cargo/bin/nvim-ctrl" "set background=$mode" 2>/dev/null || true
fi

# Alacritty / rofi / fish / ironbar подхватывают изменения сами:
# alacritty — live_config_reload импортов, rofi — при следующем запуске,
# fish — на следующем промпте, ironbar — watcher обёртки.
```

### `darkman/theme` (новый, `chmod +x`)

Единственный хук вместо `dark-mode.d/` + `light-mode.d/`.

```sh
#!/bin/sh
# darkman hook: вызывается с "dark" или "light".
set -eu
case "${1:-}" in
    dark)  icon=weather-clear-night ;;
    light) icon=weather-clear ;;
    *) echo "usage: $0 dark|light" >&2; exit 2 ;;
esac
notify-send --app-name=darkman --urgency=low --icon="$icon" "switching to $1 mode" || true
exec "$(dirname "$(readlink -f "$0")")/../wayland/theme-sync" "$1"
```

---

## Этап 3. Правки конфигов приложений

### 3.1 Alacritty — `alacritty/alacritty.toml`

Убрать `[window] opacity` (иначе он, как загружаемый последним, перебьёт
state-файл). Заголовок файла:

```toml
[general]
# Цвета и прозрачность зависят от темы и приходят из state-файла.
# Порядок важен: fallback-тема загружается первой, state перекрывает её,
# а этот файл — последним (см. man 5 alacritty).
import = [
  "~/.config/alacritty/themes/themes/gruvbox_light.toml",
  "~/.local/state/dotfiles/alacritty.toml",
]
live_config_reload = true
```

Остальное (`[scrolling]`, ru-keybindings) без изменений.

### 3.2 Rofi — `rofi/config.rasi`

В конец файла:

```rasi
// Fallback, если state ещё не создан; импорт ниже имеет приоритет.
@theme "gruvbox-dark-soft"
?import "~/.local/state/dotfiles/rofi.rasi"
```

### 3.3 Helix — `helix/config.toml`

Первая строка:

```toml
# Тема лежит в ~/.config/helix/runtime/themes/dotfiles.toml (симлинк в state).
theme = "dotfiles"
```

### 3.4 Ironbar — `ironbar/style.css`

Удалить блок `@define-color` (палитра теперь в state, дублировать нельзя —
иначе неоднозначный приоритет). Обновить комментарий в шапке:

```css
/* Ironbar style for sway and niri.
 *
 * Здесь только структура. Палитра (@define-color) приходит из
 * ~/.local/state/dotfiles/ironbar/colors.css через обёртку, которую
 * генерирует wayland/theme-sync. Запуск:
 *   ironbar -t ~/.local/state/dotfiles/ironbar/style.css
 * Ironbar следит за обёрткой и перезагружает CSS вместе с импортами.
 */
```

### 3.5 Запуск ironbar

`sway/config`:

```conf
# Status Bar: ironbar. CSS собирается theme-sync; палитра — в state.
# exec --no-startup-id waybar -c ~/.config/waybar/config-sway -s ~/.config/waybar/style.css
exec --no-startup-id ironbar -t $HOME/.local/state/dotfiles/ironbar/style.css
```

`niri/config.kdl`:

```kdl
// spawn-sh-at-startup "waybar -c ~/.config/waybar/config-niri -s ~/.config/waybar/style.css"
spawn-sh-at-startup "ironbar -t \"$HOME/.local/state/dotfiles/ironbar/style.css\""
```

### 3.6 Синхронизация при входе в сессию

Добавить до запуска бара (порядок строк в конфиге = порядок запуска):

`sway/config`:

```conf
exec --no-startup-id ~/.config/wayland/theme-sync "$(darkman get 2>/dev/null || echo light)"
```

`niri/config.kdl`:

```kdl
spawn-sh-at-startup "~/.config/wayland/theme-sync \"$(darkman get 2>/dev/null || echo light)\""
```

Это лечит текущий баг «после логина состояние не совпадает с последним
переключением».

### 3.7 Fish

`fish/config.fish`:

- удалить блок с `darkman get` и `fish_config theme choose`;
- добавить:

```fish
# EDITOR раньше жил в universal-переменных fish; теперь — здесь.
set -gx EDITOR /usr/bin/helix

# Key bindings: содержимое бывшего conf.d/fish_frozen_key_bindings.fish.
set -g fish_key_bindings fish_vi_key_bindings
set -e -U fish_key_bindings 2>/dev/null
```

`WAYLAND_COMPOSITOR` оставить как есть (`set -q ...; or set -Ux` в tty-ветке) —
`wm` продолжит писать universal в локальный `fish_variables`.

Новый `fish/conf.d/theme.fish`:

```fish
# Тема fish следует за ~/.local/state/dotfiles/background-mode.
# Раньше это делал darkman через universal background_mode; universal-переменные
# больше не используем, чтобы fish не писал в репозиторий.
function __dotfiles_apply_theme --description 'Apply dark/light fish theme'
    set -l mode_file $HOME/.local/state/dotfiles/background-mode
    test -r $mode_file; or return 0
    set -l mode (string trim -- (command cat $mode_file 2>/dev/null))
    test "$mode" = "$__dotfiles_theme_mode"; and return 0
    switch $mode
        case dark
            fish_config theme choose dark
            set -g __dotfiles_theme_mode dark
        case light
            fish_config theme choose "Snow Day"
            set -g __dotfiles_theme_mode light
    end
end
```

`fish/functions/fish_prompt.fish` — первой строкой:

```fish
functions -q __dotfiles_apply_theme; and __dotfiles_apply_theme
```

Так уже открытые шеллы подхватывают смену темы на следующем промпте
(`fish_config theme choose` на диск не пишет).

Удалить:

- `fish/conf.d/update_theme.fish` (заменён на `theme.fish`);
- `fish/conf.d/fish_frozen_theme.fish` (миграционный артефакт fish 4.3;
  тема теперь выбирается в `theme.fish`);
- `fish/conf.d/fish_frozen_key_bindings.fish` (строки перенесены в `config.fish`).

### 3.8 Neovim

`nvim/lua/plugins/colorschemes.lua`:

```lua
-- Фон берём из state-файла, который пишет wayland/theme-sync.
local mode_file = vim.fn.expand("~/.local/state/dotfiles/background-mode")
local f = io.open(mode_file, "r")
if f then
	local mode = f:read("*l")
	f:close()
	if mode == "light" or mode == "dark" then
		vim.o.background = mode
	end
end

vim.cmd.colorscheme("gruvbox")
```

Хук `nvim-ctrl` в `theme-sync` остаётся для уже запущенных инстансов.

---

## Этап 4. Installer: merge-режим, volatile-файлы, state

### 4.1 `install/volatile.conf` (новый)

Список рантайм-файлов, которые в merge-каталогах копируются как обычные
файлы, а не симлинкуются:

```
# Пути относительно корня репозитория. При разворачивании merge-каталога
# такой файл копируется в target (если его там ещё нет) и дальше живёт
# локально: приложение может писать в него, репозиторий не меняется.
fish/fish_variables
fish/conf.d/fish_frozen_theme.fish
fish/conf.d/fish_frozen_key_bindings.fish
fish/conf.d/fzf.fish
fish/functions/fisher.fish
fish/functions/fzf_configure_bindings.fish
fish/functions/_fzf_*.fish
fish/completions/fisher.fish
fish/completions/fzf_configure_bindings.fish
```

(Поддержать `*` через `case`/`compgen -G`, либо перечислить файлы явно —
на момент реализации в репозитории их ещё 13 штук `_fzf_*`.)

### 4.2 `install/symlinks.conf`

- `fish` и `helix` получают тег `merge`:

```
fish                              ~/.config/fish                              merge
helix                             ~/.config/helix                             merge
```

- удалить строки `dark-mode.d` и `light-mode.d`;
- добавить хук darkman (файл, не каталог):

```
darkman/theme                     ~/.local/share/darkman/theme                gui
```

### 4.3 `install/install.sh`

1. Разбор тегов: заменить `read -r src target tag _` на
   `read -r src target tags _` и обрабатывать список тегов
   (`gui`, `merge`).
2. `merge_dir`:
   - принимать решение о merge, если есть host-override **или** тег `merge`;
   - перед `ensure_link` проверять, входит ли путь (относительно `$REPO`) в
     `install/volatile.conf`: если да — копировать (`cp -a`) при отсутствии
     файла в target и **не** создавать симлинк;
   - существующий локальный файл никогда не перезаписывать.
3. State-каталог (после раскладки ссылок):
   ```bash
   STATE_DIR="$HOME/.local/state/dotfiles"
   run mkdir -p "$STATE_DIR/alacritty" "$STATE_DIR/helix/runtime/themes" "$STATE_DIR/ironbar"
   ensure_link "$STATE_DIR/helix/runtime" "$HOME/.config/helix/runtime"
   ```
   (`ensure_link` уже делает `mkdir -p` родителя.)
4. Fisher перенести из блока `DO_PACKAGES` в конец (после ссылок), потому что
   он пишет в `~/.config/fish`: выполнять при `DO_LINKS=1`,
   `PROFILE != headless`, наличии `fish`; добавить флаг `--no-fisher`.
   Мотивация: плагины ставятся в реальный каталог, а не в репозиторий.
5. Legacy-очистка: удалить `~/.local/share/dark-mode.d` и
   `~/.local/share/light-mode.d`, только если это симлинки внутрь `$REPO`
   (иначе — бэкап/предупреждение).
6. В конце (gui): применить тему:
   ```bash
   mode="$(darkman get 2>/dev/null || true)"
   case "$mode" in dark|light) ;; *) mode="$(cat "$STATE_DIR/background-mode" 2>/dev/null || true)" ;; esac
   case "$mode" in dark|light) ;; *) mode=light ;; esac
   run "$REPO/wayland/theme-sync" "$mode"
   ```

Миграция на этой машине получается автоматической: при первом запуске
`merge_dir` скопирует `fish_variables` и fisher-файлы из репозитория в
`~/.config/fish` как локальные копии, затем `fisher install` пересоздаст
плагины уже локально.

---

## Этап 5. Убрать рантайм-файлы из git

После того как installer развернул merge-каталоги и скопировал локальные
копии (Этап 4):

```sh
cd ~/config_files

# fisher-плагины и universal-переменные больше не версионируются
git rm fish/fish_variables \
       fish/conf.d/fish_frozen_theme.fish \
       fish/conf.d/fish_frozen_key_bindings.fish \
       fish/conf.d/fzf.fish \
       fish/functions/fisher.fish \
       fish/functions/fzf_configure_bindings.fish \
       fish/functions/_fzf_*.fish \
       fish/completions/fisher.fish \
       fish/completions/fzf_configure_bindings.fish

# заменены новыми механизмами
git rm -r dark-mode.d light-mode.d
git rm fish/conf.d/update_theme.fish

# новые файлы
git add theme/ wayland/theme-sync darkman/theme install/volatile.conf \
        install/verify.sh fish/conf.d/theme.fish PLAN.md README.md
```

`.gitignore` (дополнить):

```gitignore
# fish runtime state (живёт в ~/.config/fish, не в репозитории)
fish/fish_variables
fish/conf.d/fish_frozen_*.fish
# fisher-managed plugins (ставятся локально из fish/fish_plugins)
fish/conf.d/fzf.fish
fish/functions/_fzf_*.fish
fish/functions/fzf_configure_bindings.fish
fish/functions/fisher.fish
fish/completions/fisher.fish
fish/completions/fzf_configure_bindings.fish
```

`fish/fish_plugins` остаётся в git: это декларативный список плагинов.
`fisher install` перезаписывает его тем же содержимым, поэтому diff не
появляется.

После удаления файлов повторно прогнать
`./install/install.sh --no-packages --host desktop`: `merge_dir` вычистит
висячие симлинки (prune), если они успели появиться.

---

## Этап 6. README

Добавить раздел «Runtime state и переключение темы» и обновить существующие
упоминания darkman/waybar/fish.

Содержание (обязательные пункты):

1. **Принцип.** Репозиторий read-only: приложения не пишут в него. Всё
   изменяемое — в `~/.local/state/dotfiles/` (фиксированный путь, не
   `XDG_STATE_HOME`, потому что import-пути в alacritty/rofi не раскрывают
   переменные).
2. **Раскладка state:**
   ```
   ~/.local/state/dotfiles/
     background-mode
     alacritty.toml   rofi.rasi
     helix/runtime/themes/dotfiles.toml
     ironbar/{colors.css,style.css}
   ```
3. **Как работает переключение.** darkman → `~/.local/share/darkman/theme` →
   `wayland/theme-sync`; что делает скрипт (файлы, gsettings, SIGUSR1 helix,
   nvim-ctrl); что приложения подхватывают сами (alacritty live-reload,
   rofi при запуске, fish на промпте, ironbar watcher).
4. **Merge-каталоги.** `~/.config/fish`, `~/.config/helix` — реальные каталоги
   с симлинками на файлы репо; `install/volatile.conf` — список рантайм-файлов,
   которые копируются, а не симлинкуются; как добавить новый volatile-файл.
5. **Helix.** `~/.config/helix/runtime` → state; `theme = "dotfiles"`;
   альтернатив (env `HELIX_RUNTIME`) не используем, чтобы тема работала при
   любом способе запуска.
6. **Ironbar.** Запуск только с `-t <state>/ironbar/style.css`; палитра в
   `colors.css`; в репозитории — только структура без `@define-color`;
   при правке CSS помнить, что watcher следит за обёрткой.
7. **Fish.** `fish_variables` и fisher-плагины — локальные, не в git;
   список плагинов — `fish/fish_plugins`; тема — `fish/conf.d/theme.fish`
   по state-файлу; `wm` по-прежнему пишет universal локально.
8. **Waybar.** Не участвует в переключении (rollback-режим); при возврате
   сделать по аналогии: обёртка в state + `waybar -s <state>/waybar/style.css`
   + `@import` палитры.
9. **Проверка.** `./install/verify.sh`; что именно он проверяет.
10. **Ограничения.** `XDG_STATE_HOME` должен оставаться дефолтным; fish
    подхватывает тему на следующем промпте; helix — по SIGUSR1 (новые окна —
    сразу).

Обновить также:
- дерево `Layout` (добавить `theme/`, `wayland/theme-sync`, `darkman/theme`,
  убрать `dark-mode.d/ light-mode.d/`);
- раздел про ironbar (абзац про darkman-хуки заменить);
- раздел Dark/light (заменить описание legacy-хуков).

---

## Этап 7. `install/verify.sh`

```bash
#!/usr/bin/env bash
# Проверяет, что переключение темы не меняет репозиторий и что раскладка
# симлинков/state на месте.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$HOME/.local/state/dotfiles"
fail=0

bad() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }
ok()  { printf 'ok: %s\n' "$*"; }

# 1. state-файлы
for f in background-mode alacritty.toml rofi.rasi \
         helix/runtime/themes/dotfiles.toml ironbar/colors.css ironbar/style.css; do
    [[ -f "$STATE/$f" ]] && ok "state/$f" || bad "missing $STATE/$f"
done

# 2. симлинки
[[ -L "$HOME/.config/helix/runtime" ]] && ok "helix runtime link" \
    || bad "~/.config/helix/runtime is not a symlink"
[[ -x "$HOME/.local/share/darkman/theme" ]] && ok "darkman hook" \
    || bad "darkman hook missing or not executable"
[[ -L "$HOME/.config/fish/fish_variables" ]] && bad "fish_variables must be a real file" \
    || [[ -f "$HOME/.config/fish/fish_variables" ]] && ok "fish_variables is local" \
    || bad "fish_variables missing"

# 3. legacy-хуки удалены
for p in "$HOME/.local/share/dark-mode.d" "$HOME/.local/share/light-mode.d"; do
    [[ -e "$p" || -L "$p" ]] && bad "legacy hook dir still exists: $p"
done

# 4. репозиторий не меняется при переключении
before="$(git -C "$REPO" status --porcelain)"
for m in dark light; do
    THEME_SYNC_NO_RELOAD=1 "$REPO/wayland/theme-sync" "$m"
    after="$(git -C "$REPO" status --porcelain)"
    [[ "$before" == "$after" ]] || bad "git status changed after theme-sync $m"
done

# вернуть фактическую тему
mode="$(darkman get 2>/dev/null || cat "$STATE/background-mode" 2>/dev/null || echo light)"
case "$mode" in dark|light) ;; *) mode=light ;; esac
"$REPO/wayland/theme-sync" "$mode"

[[ $fail -eq 0 ]] && echo "verify: OK" || { echo "verify: FAILED" >&2; exit 1; }
```

---

## Этап 8. Проверка на живой сессии

Порядок:

1. `./install/verify.sh` — все `ok`, `verify: OK`.
2. Открыть alacritty, helix, nvim; запустить rofi; открыть новый промпт fish.
3. `darkman set dark` — проверить:
   - alacritty сменил палитру и opacity без рестарта;
   - helix в открытом окне перекрасился (SIGUSR1);
   - ironbar перекрасился (watcher обёртки);
   - nvim в открытом окне: `background=dark`;
   - fish: цвета на следующем промпте;
   - rofi: новая тема при следующем запуске;
   - GTK-приложения: тёмные.
4. `darkman set light` — то же в обратную сторону.
5. `git -C ~/config_files status --porcelain` — пусто.
6. `fish -c 'set -U probe 1; set -e -U probe'` — `git status` пуст.
7. `fish -c 'fisher update'` — `git status` пуст (плагины локальные).
8. Перелогиниться в niri (и проверить sway по возможности): после входа тема
   соответствует `darkman get`, бар и терминал запускаются с нужной палитрой.
9. Открыть `hx` из rofi (не из fish) — тема `dotfiles` применилась.
10. `git log --oneline -3`, `git status` — рабочее дерево чистое.

---

## Этап 9. Откат

Если что-то пойдёт не так:

- вернуть старые хуки: `git revert` коммита Этапа 5 (файлы `dark-mode.d/`,
  `light-mode.d/` и строки в `symlinks.conf`), затем
  `./install/install.sh --no-packages`;
- вернуть ironbar по умолчанию: убрать `-t ...` из `sway/config` и
  `niri/config.kdl`;
- fish/helix при необходимости вернуть к симлинку на каталог: удалить
  `~/.config/fish` / `~/.config/helix` (локальные `fish_variables` и
  fisher-файлы при этом сохранить вручную) и запустить installer со старым
  `symlinks.conf`.

---

## Список изменяемых/создаваемых файлов

Новые:

- `theme/dark/{alacritty.toml,rofi.rasi,helix.toml,ironbar.css}`
- `theme/light/{...}`
- `wayland/theme-sync`
- `darkman/theme`
- `install/volatile.conf`
- `install/verify.sh`
- `fish/conf.d/theme.fish`
- `PLAN.md`

Изменяемые:

- `alacritty/alacritty.toml`
- `rofi/config.rasi`
- `helix/config.toml`
- `ironbar/style.css`
- `sway/config`
- `niri/config.kdl`
- `fish/config.fish`
- `fish/functions/fish_prompt.fish`
- `nvim/lua/plugins/colorschemes.lua`
- `install/install.sh`
- `install/symlinks.conf`
- `.gitignore`
- `README.md`

Удаляемые:

- `dark-mode.d/` (7 файлов)
- `light-mode.d/` (7 файлов)
- `fish/conf.d/update_theme.fish`
- `fish/conf.d/fish_frozen_theme.fish`
- `fish/conf.d/fish_frozen_key_bindings.fish`
- `fish/fish_variables`
- fisher-плагины (`fish/functions/_fzf_*.fish`, `functions/fisher.fish`,
  `functions/fzf_configure_bindings.fish`, `completions/fisher.fish`,
  `completions/fzf_configure_bindings.fish`, `conf.d/fzf.fish`)

Не трогаем:

- `waybar/` (rollback-режим, статическая палитра).
