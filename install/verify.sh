#!/usr/bin/env bash
#
# Проверяет, что переключение темы не меняет репозиторий и что раскладка
# симлинков/state на месте. Ничего не меняет, кроме state-файлов темы:
# в конце возвращает фактический режим (darkman, иначе сохранённый).
#
#   ./install/verify.sh
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$HOME/.local/state/dotfiles"
fail=0

# Общие помощники (detect_hostname и т.п.); свои bad/ok/warn определяем ниже,
# чтобы вывод verify оставался в его формате.
# shellcheck source=install/lib.sh
source "$REPO/install/lib.sh"

bad()  { printf 'FAIL: %s\n' "$*" >&2; fail=1; }
ok()   { printf 'ok: %s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }

# ------------------------------------------------------------ 1. state-файлы
for f in background-mode alacritty.toml rofi.rasi \
         helix/runtime/themes/dotfiles.toml ironbar/colors.css ironbar/style.css; do
    if [[ -f "$STATE/$f" ]]; then ok "state/$f"; else bad "missing $STATE/$f"; fi
done

mode="$(cat "$STATE/background-mode" 2>/dev/null || true)"
case "$mode" in
    dark|light) ok "background-mode=$mode" ;;
    *)          bad "bad background-mode: '$mode'" ;;
esac
orig_mode="$mode"

# Композитор и login shell: без них графика на tty1 просто не стартует.
comp="$(tr -d '[:space:]' < "$STATE/compositor" 2>/dev/null || true)"
case "$comp" in
    sway|niri|none) ok "compositor=$comp" ;;
    *)              bad "missing or invalid $STATE/compositor: '$comp'" ;;
esac

# На headless-хосте композитор не поднимается по определению.
hn="$(detect_hostname)"
declared_profile="$(awk -v n="$hn" '!/^#/ && $1==n {print $3; exit}' "$REPO/install/hosts.conf")"
if [[ "$declared_profile" == "headless" && "$comp" != "none" ]]; then
    bad "compositor=$comp on headless host '$hn'; expected none"
fi

fish_bin="$(command -v fish 2>/dev/null || true)"
login_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ -n "$fish_bin" && "$login_shell" == "$fish_bin" ]]; then
    ok "login shell is fish ($fish_bin)"
else
    bad "login shell is '${login_shell:-?}', expected fish (${fish_bin:-not installed})"
fi

# --------------------------------------------------------------- 2. симлинки
if [[ -L "$HOME/.config/helix/runtime" ]]; then
    ok "helix runtime link -> $(readlink "$HOME/.config/helix/runtime")"
else
    bad "~/.config/helix/runtime is not a symlink"
fi

if [[ "$declared_profile" == "headless" ]]; then
    # На headless darkman не ставится (gui-only) и переключать нечего:
    # тему двигает applications/theme-switch.
    ok "darkman hook not needed on headless"
elif [[ -x "$HOME/.local/share/darkman/theme" ]]; then
    ok "darkman hook"
else
    bad "darkman hook missing or not executable: ~/.local/share/darkman/theme"
fi

# darkman.service переживает перезапуск niri/sway, поэтому унаследованный
# NIRI_SOCKET/SWAYSOCK может указывать на мёртвый сокет, и обои с Mattermost
# молча пропускались. compositor-env.sh обязан найти живой сокет заново.
if env NIRI_SOCKET=/nonexistent/niri.sock SWAYSOCK=/nonexistent/sway.sock \
        bash -c '. "$1"; theme_compositor_resolve' _ "$REPO/wayland/compositor-env.sh" \
        >/dev/null 2>&1; then
    ok "compositor-env.sh resolves a live socket ignoring stale env"
elif [[ "$declared_profile" == "headless" ]]; then
    ok "no compositor to resolve (headless)"
else
    bad "compositor-env.sh could not find a live compositor socket"
fi

# merge-каталоги: реальные каталоги, файлы — ссылки внутрь репозитория
for d in fish helix opencode; do
    if [[ -L "$HOME/.config/$d" ]]; then
        bad "~/.config/$d is a symlink; expected a merge directory"
    elif [[ -d "$HOME/.config/$d" ]]; then
        ok "~/.config/$d is a merge directory"
    else
        bad "~/.config/$d missing"
    fi
done

for f in fish/config.fish fish/conf.d/theme.fish fish/fish_plugins helix/config.toml \
         opencode/opencode.jsonc opencode/cli.json opencode/AGENTS.md; do
    t="$HOME/.config/$f"
    if [[ -L "$t" && "$(readlink -f "$t")" == "$REPO/$f" ]]; then
        ok "~/.config/$f -> repo"
    else
        bad "~/.config/$f is not a symlink into the repo"
    fi
done

# theme-switch — обёртка над theme-sync; старая локальная копия не должна
# остаться: она писала universal background_mode и правила helix-config.
ts="$HOME/.local/bin/theme-switch"
if [[ -L "$ts" && "$(readlink -f "$ts")" == "$REPO/applications/theme-switch" && -x "$ts" ]]; then
    ok "~/.local/bin/theme-switch -> repo"
else
    bad "~/.local/bin/theme-switch is not a symlink to applications/theme-switch"
fi

# xdg-open — шим для ghostty (дамп скроллбека → nvim в новом окне). Должен быть
# симлинком в репозиторий и должен делегировать: `--version` не открывает ни
# одного файла, поэтому безопасен как smoke-тест.
xo="$HOME/.local/bin/xdg-open"
if [[ -L "$xo" && "$(readlink -f "$xo")" == "$REPO/applications/xdg-open" && -x "$xo" ]]; then
    ok "~/.local/bin/xdg-open -> repo"
    if "$xo" --version >/dev/null 2>&1; then
        ok "xdg-open shim delegates (/usr/bin/xdg-open --version)"
    else
        bad "xdg-open shim does not delegate (--version failed)"
    fi
    # Dump-ветка: путь той же формы, что пишет ghostty. Если ghostty нет
    # (headless), шим обязан делегировать, а не падать на `exec ghostty`.
    if ! command -v ghostty >/dev/null 2>&1; then
        tmproot="$(mktemp -d)"
        # Имя каталога ghostty — 16 случайных байт в base64url (22 символа).
        dumpdir="$tmproot/AAAAAAAAAAAAAAAAAAAAAA"
        mkdir -p "$dumpdir"
        # screen.txt — основной путь (write_screen_file), history.txt —
        # write_scrollback_file; шим должен принимать оба.
        for name in screen.txt history.txt; do
            printf 'x\n' > "$dumpdir/$name"
            if TMPDIR="$tmproot" "$xo" "$dumpdir/$name" >/dev/null 2>&1; then
                ok "xdg-open shim delegates ghostty dumps ($name) without ghostty"
            else
                bad "xdg-open shim fails on a ghostty dump path ($name) without ghostty installed"
            fi
        done
        rm -rf "$tmproot"
    fi
else
    bad "~/.local/bin/xdg-open is not a symlink to applications/xdg-open"
fi

# universal background_mode больше не читается fish (источник — state-файл).
if command -v fish >/dev/null 2>&1 && fish -c 'set -q -U background_mode' 2>/dev/null; then
    bad "legacy background_mode universal variable is still set"
else
    ok "no legacy background_mode universal variable"
fi

# Рантайм OpenCode (plugin-зависимости, пароль локального сервера) должен
# оставаться локальным файлом: если он окажется симлинком в репозиторий,
# приложение снова начнёт писать в трекаемое дерево.
if [[ -e "$HOME/.config/opencode/service.json" && -L "$HOME/.config/opencode/service.json" ]]; then
    bad "opencode/service.json is a symlink into the repo; expected a local file"
else
    ok "opencode/service.json is not linked into the repo"
fi
for f in package.json bun.lock package-lock.json; do
    t="$HOME/.config/opencode/$f"
    if [[ -L "$t" && "$(readlink -f "$t")" == "$REPO"/* ]]; then
        bad "~/.config/opencode/$f points into the repo; runtime files must stay local"
    fi
done

if [[ -L "$HOME/.config/fish/fish_variables" ]]; then
    bad "fish_variables must be a real file, not a symlink"
elif [[ -f "$HOME/.config/fish/fish_variables" ]]; then
    ok "fish_variables is a local copy"
else
    bad "~/.config/fish/fish_variables missing"
fi

dangling="$(find "$HOME/.config/fish" "$HOME/.config/helix" -xtype l -print 2>/dev/null || true)"
if [[ -n "$dangling" ]]; then
    while IFS= read -r l; do bad "dangling symlink: $l"; done <<< "$dangling"
else
    ok "no dangling symlinks in merge dirs"
fi

# --------------------------------------------------------- 3. legacy-хуки
legacy=""
for p in "$HOME/.local/share/dark-mode.d" "$HOME/.local/share/light-mode.d"; do
    [[ -e "$p" || -L "$p" ]] && legacy+=" $p"
done
if [[ -n "$legacy" ]]; then
    bad "legacy hook dir(s) still exist:$legacy"
else
    ok "legacy hook dirs removed"
fi

# ------------------------------------------- 4. state соответствует шаблонам
cmp_state() { # cmp_state <файл в theme/$mode> <файл в $STATE>
    if cmp -s "$REPO/theme/$mode/$1" "$STATE/$2"; then
        ok "state/$2 matches theme/$mode/$1"
    else
        bad "state/$2 differs from theme/$mode/$1"
    fi
}
cmp_state alacritty.toml alacritty.toml
cmp_state rofi.rasi      rofi.rasi
cmp_state helix.toml     helix/runtime/themes/dotfiles.toml
cmp_state ironbar.css    ironbar/colors.css

wrapper="$STATE/ironbar/style.css"
if grep -qF "@import url(\"$STATE/ironbar/colors.css\")" "$wrapper" 2>/dev/null &&
   grep -qF "@import url(\"$REPO/ironbar/style.css\")" "$wrapper" 2>/dev/null; then
    ok "ironbar wrapper imports palette + repo css"
else
    bad "ironbar wrapper is missing imports (expected colors.css and $REPO/ironbar/style.css)"
fi

# ------------------------------------------------- 4b. Ghostty: конфиг и темы
# ghostty читает конфиг из ~/.config/ghostty (симлинк в репозиторий), а палитры
# — из ghostty/themes/<name> по имени из `theme = light:...,dark:...`
# (имя файла без расширения: ghostty ищет ровно "<name>").
if [[ "$declared_profile" == "headless" ]]; then
    ok "ghostty config not needed on headless"
else
    if [[ -L "$HOME/.config/ghostty" && "$(readlink -f "$HOME/.config/ghostty")" == "$REPO/ghostty" ]]; then
        ok "~/.config/ghostty -> repo"
    else
        bad "~/.config/ghostty is not a symlink to $REPO/ghostty"
    fi
    # Легаси-файл `config` ghostty читает первым; вместе с config.ghostty это
    # даёт предупреждение в лог и непредсказуемый порядок настроек.
    if [[ -e "$HOME/.config/ghostty/config" ]]; then
        bad "legacy ~/.config/ghostty/config exists; only config.ghostty is supported"
    else
        ok "no legacy ghostty config file"
    fi
fi

# Содержимое конфига — свойство репозитория, а не хоста: проверяем на любом
# профиле, включая headless (там ghostty нет, но правку в репо поймать нужно).
if [[ -f "$REPO/ghostty/config.ghostty" ]]; then
    if grep -Eq '^[[:space:]]*shell-integration-features[[:space:]]*=.*\bssh-terminfo\b' \
            "$REPO/ghostty/config.ghostty"; then
        ok "ghostty shell-integration-features includes ssh-terminfo"
    else
        bad "ghostty config has no ssh-terminfo: remote TERM=xterm-ghostty will have no terminfo"
    fi

    # clipboard-read=allow убирает запрос на OSC 52 read (nvim `"+p` на сервере).
    cr="$(sed -n 's/^[[:space:]]*clipboard-read[[:space:]]*=[[:space:]]*//p' "$REPO/ghostty/config.ghostty" | head -n 1)"
    if [[ "$cr" == "allow" ]]; then
        ok "ghostty clipboard-read = allow"
    else
        warn "ghostty clipboard-read is '${cr:-<default ask>}': OSC 52 reads will prompt"
    fi
fi

# Сам конфиг должен проходить парсер ghostty: опечатка в ключе (например,
# забытый `keybind =` перед `scroll-mode/...`) видна только здесь.
if [[ "$declared_profile" != "headless" ]] && command -v ghostty >/dev/null 2>&1; then
    # --config-file — глобальный флаг, поэтому стоит ДО `+validate-config`:
    # после команды он молча возвращает rc=1 без диагностики.
    if diag="$(ghostty --config-file="$REPO/ghostty/config.ghostty" +validate-config 2>&1)"; then
        ok "ghostty +validate-config"
    else
        while IFS= read -r line; do bad "ghostty config: $line"; done <<< "$diag"
    fi
fi

# Имена тем в config.ghostty должны существовать файлами в ghostty/themes.
if [[ -f "$REPO/ghostty/config.ghostty" ]]; then
    themes_line="$(sed -n 's/^[[:space:]]*theme[[:space:]]*=[[:space:]]*//p' "$REPO/ghostty/config.ghostty" | head -n 1)"
    for t in $(tr ',:' '\n\n' <<< "$themes_line" | sed '/^\(light\|dark\)$/d' | tr -d ' '); do
        # Ghostty ищет файл темы по точному имени из `theme =`, без
        # расширения (расширение .conf молча не находится).
        if [[ -f "$REPO/ghostty/themes/$t" ]]; then
            ok "ghostty theme $t"
        else
            bad "ghostty theme '$t' from config.ghostty not found in ghostty/themes/"
        fi
    done
fi

# Палитры двух терминалов не должны разъезжаться: alacritty остаётся fallback'ом.
# Обе функции печатают строки "<слот> <hex без #>" и сортируют их, чтобы
# сравнивать diff'ом: bg/fg плюс слоты палитры 0..15.
alacritty_palette() { # <файл темы alacritty>
    awk -F"'" '
        /^\[/ { sec = "" }
        /^\[colors\.primary\]/ { sec = "primary"; next }
        /^\[colors\.normal\]/  { sec = "normal"; next }
        /^\[colors\.bright\]/  { sec = "bright"; next }
        sec != "" && /^[a-z_]+[ \t]*=/ {
            key = $1; gsub(/[ \t=]/, "", key);
            if (sec == "primary") {
                if (key == "background") { print "bg " $2; next }
                if (key == "foreground") { print "fg " $2; next }
            } else {
                order[1] = "black"; order[2] = "red"; order[3] = "green"; order[4] = "yellow";
                order[5] = "blue"; order[6] = "magenta"; order[7] = "cyan"; order[8] = "white";
                for (i = 1; i <= 8; i++) if (key == order[i])
                    printf "%d %s\n", (sec == "normal" ? i - 1 : i + 7), $2;
            }
        }
    ' "$1" | sed 's/#//g' | sort -k1,1
}

ghostty_palette() { # <файл темы ghostty>
    awk -F"=" '
        /^[[:space:]]*background[[:space:]]*=/ {
            v = $2; gsub(/[[:space:]#]/, "", v); print "bg " v
        }
        /^[[:space:]]*foreground[[:space:]]*=/ {
            v = $2; gsub(/[[:space:]#]/, "", v); print "fg " v
        }
        /^[[:space:]]*palette[[:space:]]*=/ {
            n = $2; v = $3; gsub(/[[:space:]]/, "", n); gsub(/[[:space:]#]/, "", v);
            print n " " v
        }
    ' "$1" | sort -k1,1
}

for pair in "dark:gruvbox_dark:gruvbox-dark" "light:gruvbox_light:gruvbox-light"; do
    IFS=: read -r m al gh <<< "$pair"
    al_file="$REPO/alacritty/themes/themes/$al.toml"
    gh_file="$REPO/ghostty/themes/$gh"
    if [[ ! -f "$al_file" || ! -f "$gh_file" ]]; then
        bad "palette source missing for $m ($al_file / $gh_file)"
    elif diff -u <(alacritty_palette "$al_file") <(ghostty_palette "$gh_file") >/dev/null; then
        ok "ghostty $gh palette matches alacritty $al"
    else
        bad "ghostty $gh palette drifts from alacritty $al: $(diff <(alacritty_palette "$al_file") <(ghostty_palette "$gh_file") | head -n 4 | tr '\n' ' ')"
    fi

    # Прозрачность: у alacritty она в state-фрагменте темы (theme/<mode>/
    # alacritty.toml), у ghostty — в файле темы. Значения должны совпадать,
    # иначе окна двух терминалов на одном рабочем столе выглядят по-разному.
    al_op="$(awk -F= '/^\[window\]/ { s = 1; next } /^\[/ { s = 0 }
                       s && /^[[:space:]]*opacity[[:space:]]*=/ {
                           gsub(/[[:space:]]/, "", $2); print $2; exit }' \
             "$REPO/theme/$m/alacritty.toml" 2>/dev/null)"
    gh_op="$(awk -F= '/^[[:space:]]*background-opacity[[:space:]]*=/ {
                           v = $2; gsub(/[[:space:]]/, "", v); print v; exit }' "$gh_file")"
    if [[ -z "$al_op" || -z "$gh_op" ]]; then
        bad "opacity missing: theme/$m/alacritty.toml='$al_op' ghostty/$gh='$gh_op'"
    elif [[ "$al_op" == "$gh_op" ]]; then
        ok "ghostty $gh opacity $gh_op matches alacritty $m"
    else
        bad "ghostty $gh background-opacity '$gh_op' != alacritty $m opacity '$al_op'"
    fi

    # Выделение должно совпадать у обоих терминалов: bg2 в gruvbox-раскладке
    # светлый, на тёмном фоне он читался как подсветка из светлой темы, поэтому
    # dark переведён на bg1. Курсор по-прежнему не переопределяем — дефолт
    # ghostty (инверсия клетки) совпадает с alacritty.
    if grep -qE '^[[:space:]]*cursor-(color|text)[[:space:]]*=' "$gh_file"; then
        bad "ghostty $gh overrides cursor colors; keep the ghostty default (as in alacritty)"
    else
        ok "ghostty $gh keeps default cursor colors"
    fi

    al_sel="$(awk -F"'" '
        /^\[colors\.selection\]/ { s = 1; next }
        /^\[/ { s = 0 }
        s && /^[a-z_]+[ \t]*=/ {
            key = $1; gsub(/[ \t=]/, "", key);
            col = $2; gsub(/#/, "", col);
            print key " " col
        }
    ' "$al_file" | sort)"
    gh_sel="$(awk -F= '
        /^[[:space:]]*selection-(background|foreground)[[:space:]]*=/ {
            key = $1; v = $2;
            gsub(/[[:space:]]/, "", key); gsub(/[[:space:]#]/, "", v);
            sub(/^selection-/, "", key);
            if (key == "background") key = "background";
            if (key == "foreground") key = "text";
            print key " " v
        }
    ' "$gh_file" | sort)"
    if [[ -z "$al_sel" && -z "$gh_sel" ]]; then
        ok "ghostty $gh keeps default selection colors"
    elif [[ "$al_sel" == "$gh_sel" ]]; then
        ok "ghostty $gh selection matches alacritty $al ($(tr '\n' ' ' <<< "$al_sel"))"
    else
        bad "ghostty $gh selection drifts from alacritty $al: alacritty='$(tr '\n' ' ' <<< "$al_sel")' ghostty='$(tr '\n' ' ' <<< "$gh_sel")'"
    fi
done

# ------------------------------------------- 4c-bis. niri: конфиг и рамка окон
# Синтаксис ловим до запуска сессии: кривая правка конфига роняет niri на старте.
if command -v niri >/dev/null 2>&1 && [[ -f "$REPO/niri/config.kdl" ]]; then
    if niri validate -c "$REPO/niri/config.kdl" >/dev/null 2>&1; then
        ok "niri config is valid"
    else
        bad "niri config is not valid: $(niri validate -c "$REPO/niri/config.kdl" 2>&1 | head -n 3 | tr '\n' ' ')"
    fi
fi

# Фокус-рамка niri по умолчанию рисуется как ЗАЛИТЫЙ прямоугольник за окном
# (docs: "rendered as a solid background rectangle behind windows... will show
# up through semitransparent windows"). У терминала с background-opacity < 1
# она просвечивает и красит всё окно в свой цвет. Правило
# `draw-border-with-background false` рисует её контуром ВОКРУГ окна.
if [[ -f "$REPO/niri/config.kdl" ]]; then
    if awk '
        /^[[:space:]]*window-rule[[:space:]]*\{/ { inblk = 1; app = 0; bg = 0; next }
        inblk && /ghostty/ { app = 1 }
        inblk && /draw-border-with-background[[:space:]]+false/ { bg = 1 }
        inblk && /^[[:space:]]*\}[[:space:]]*$/ { if (app && bg) found = 1; inblk = 0 }
        END { exit(found ? 0 : 1) }
    ' "$REPO/niri/config.kdl"; then
        ok "niri draws border around translucent terminals (no focus-ring bleed)"
    else
        bad "niri has no window-rule with draw-border-with-background false for ghostty"
    fi
fi

# ------------------------------------------ 4c. хуки темы: состав и синтаксис
hooks_dir="$REPO/wayland/theme-hooks.d"
hooks=()
for h in "$hooks_dir"/*.sh; do
    [[ -e "$h" ]] || continue
    hooks+=( "$h" )
done
if (( ${#hooks[@]} == 0 )); then
    bad "no theme hooks in wayland/theme-hooks.d"
else
    for h in "${hooks[@]}"; do
        name="${h##*/}"
        if [[ ! -x "$h" ]]; then
            bad "theme hook not executable: $name"
        elif ! bash -n "$h" 2>/dev/null; then
            bad "theme hook has syntax errors: $name"
        else
            ok "theme hook $name"
        fi
    done
fi
if [[ -r "$REPO/wayland/theme-hook-lib.sh" ]]; then
    ok "theme hook library"
else
    bad "missing wayland/theme-hook-lib.sh"
fi

# Mattermost: пресеты чата пишутся в серверный user preference как JSON, поэтому
# файл должен парситься jq и нести ожидаемый type (quartz/onyx).
if command -v jq >/dev/null 2>&1; then
    while read -r mm_mode mm_type; do
        f="$REPO/theme/$mm_mode/mattermost.json"
        if ! jq -e . "$f" >/dev/null 2>&1; then
            bad "theme/$mm_mode/mattermost.json is missing or not valid JSON"
        elif [[ "$(jq -r '.type // empty' "$f")" != "$mm_type" ]]; then
            bad "theme/$mm_mode/mattermost.json: expected type '$mm_type'"
        else
            ok "theme/$mm_mode/mattermost.json ($mm_type)"
        fi
    done <<'EOF'
dark Onyx
light Quartz
EOF
fi

# ------------------------------------- 5. нет хардкода домашнего пути
# Exec в .desktop не раскрывает ~/$HOME, поэтому туда легко вписать /home/<user>.
# Ловим такие пути в трекаемых файлах; документация — исключение.
hardcoded="$(git -C "$REPO" grep -nI -E '/home/[A-Za-z0-9._-]+' -- . ':(exclude)*.md' || true)"
if [[ -n "$hardcoded" ]]; then
    while IFS= read -r line; do bad "hardcoded home path: $line"; done <<< "$hardcoded"
else
    ok "no hardcoded home paths in tracked files"
fi

# ---------------------------------- 6. .desktop читается GLib (rofi/gio/drun)
# GKeyFile отвергает строковое значение с недопустимой escape-последовательностью
# (в Exec это "\$" и "\""), и тогда запись не загружается вовсе — пункт меню
# молча перестаёт работать. Поэтому в Exec не должно быть обратных слэшей.
dirty="$(grep -nHE '^Exec=.*\\' "$REPO"/applications/*.desktop || true)"
if [[ -n "$dirty" ]]; then
    while IFS= read -r line; do bad "desktop Exec has a backslash (GLib rejects such entry): $line"; done <<< "$dirty"
else
    ok "desktop Exec lines have no backslashes"
fi

# ---------------------------------------- 7. переключение не трогает репозиторий
# ignore-файлы тоже смотрим: иначе рантайм, который приложение пишет в репо
# (opencode когда-то так и делал), для проверки просто невидим.
before="$(git -C "$REPO" status --porcelain --ignored)"
[[ -z "$(git -C "$REPO" status --porcelain)" ]] ||
    warn "repo has uncommitted changes; checking they stay unchanged"

for m in dark light; do
    THEME_SYNC_NO_RELOAD=1 "$REPO/wayland/theme-sync" "$m"
    after="$(git -C "$REPO" status --porcelain --ignored)"
    if [[ "$before" == "$after" ]]; then
        ok "theme-sync $m leaves git status unchanged"
    else
        bad "git status changed after theme-sync $m"
    fi
done

# вернуть фактическую тему
cur="$(darkman get 2>/dev/null || true)"
case "$cur" in
    dark|light) ;;
    *) cur="$orig_mode" ;;
esac
case "$cur" in
    dark|light) ;;
    *) cur=light ;;
esac
# Тот же режим уже записан выше циклом, но theme-sync всё равно прогоняется,
# чтобы восстановить reload-часть; Mattermost при этом не перезапускается
# (скрипт срабатывает только на реальной смене режима). Заодно проверяем, что
# ни один хук не упал: их коды пишутся в лог рядом со строкой переключения.
hooklog="$(mktemp)"
THEME_SYNC_NO_MATTERMOST=1 THEME_HOOK_LOG="$hooklog" "$REPO/wayland/theme-sync" "$cur"
failed_hooks="$(grep -E ' rc=[1-9][0-9]*$' "$hooklog" || true)"
if [[ -n "$failed_hooks" ]]; then
    while IFS= read -r line; do bad "theme hook failed: $line"; done <<< "$failed_hooks"
else
    ok "all theme hooks exited 0 (mode $cur)"
fi
rm -f "$hooklog"
ok "restored mode: $cur"

# ------------------------------- 8. дрейф пакетов (только по CLEANUP_CHECK=1)
# Не фатально: на личной машине вне манифестов нормально живут приложения.
if [[ "${CLEANUP_CHECK:-0}" == "1" ]]; then
    if out="$("$REPO/install/cleanup.sh" --check 2>&1)"; then
        ok "no package drift"
    else
        rc=$?
        if [[ $rc -eq 2 ]]; then
            warn "package drift: $(tail -1 <<< "$out")"
        else
            warn "cleanup.sh --check failed (rc=$rc): $(tail -1 <<< "$out")"
        fi
    fi
fi

if [[ $fail -eq 0 ]]; then
    echo "verify: OK"
else
    echo "verify: FAILED" >&2
    exit 1
fi
