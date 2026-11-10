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
for f in background-mode rofi.rasi \
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
for d in fish helix; do
    if [[ -L "$HOME/.config/$d" ]]; then
        bad "~/.config/$d is a symlink; expected a merge directory"
    elif [[ -d "$HOME/.config/$d" ]]; then
        ok "~/.config/$d is a merge directory"
    else
        bad "~/.config/$d missing"
    fi
done

for f in fish/config.fish fish/conf.d/theme.fish helix/config.toml \
         fish/functions/fzf-git-status.fish fish/functions/fzf-git-log.fish; do
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

# universal background_mode больше не читается fish (источник — state-файл).
if command -v fish >/dev/null 2>&1 && fish -c 'set -q -U background_mode' 2>/dev/null; then
    bad "legacy background_mode universal variable is still set"
else
    ok "no legacy background_mode universal variable"
fi

if [[ -L "$HOME/.config/fish/fish_variables" ]]; then
    bad "fish_variables must be a real file, not a symlink"
elif [[ -f "$HOME/.config/fish/fish_variables" ]]; then
    ok "fish_variables is a local copy"
else
    bad "~/.config/fish/fish_variables missing"
fi

# fisher больше не используется: его conf.d/fzf.fish перебивал бы ctrl-r,
# который config.fish отдаёт нативному пейджеру истории fish.
fisher_leftovers=""
for p in "$HOME/.config/fish/conf.d/fzf.fish" \
         "$HOME/.config/fish/functions/fisher.fish" \
         "$HOME/.config/fish/functions/fzf_configure_bindings.fish" \
         "$HOME/.config/fish/completions/fisher.fish" \
         "$HOME/.config/fish/completions/fzf_configure_bindings.fish" \
         "$HOME"/.config/fish/functions/_fzf_*.fish; do
    # Файлы из репозитория — наши, они лишь совпадают по имени с плагинными.
    if [[ -L "$p" && "$(readlink -f "$p")" == "$REPO"/* ]]; then
        continue
    fi
    [[ -e "$p" || -L "$p" ]] && fisher_leftovers+=" $p"
done
if [[ -n "$fisher_leftovers" ]]; then
    bad "legacy fisher files still exist:$fisher_leftovers"
else
    ok "no legacy fisher files"
fi

if command -v fish >/dev/null 2>&1 && fish -c 'set -q _fisher_plugins' 2>/dev/null; then
    bad "legacy _fisher_* universal variables are still set"
else
    ok "no legacy _fisher_* universal variables"
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

# ------------------------------------------------- 4b. Kitty: конфиг и темы
# kitty читает конфиг из ~/.config/kitty (симлинк в репозиторий), палитры — из
# файлов авто-темы {dark,light}-theme.auto.conf в том же каталоге: kitty (0.38+)
# сам следит за схемой ОС и применяет их без хука.
if [[ "$declared_profile" == "headless" ]]; then
    ok "kitty config not needed on headless"
elif [[ -L "$HOME/.config/kitty" && "$(readlink -f "$HOME/.config/kitty")" == "$REPO/kitty" ]]; then
    ok "~/.config/kitty -> repo"
else
    bad "~/.config/kitty is not a symlink to $REPO/kitty"
fi

# Файлы авто-темы должны существовать: без них kitty при смене схемы молча
# остаётся на цветах из kitty.conf.
for f in dark-theme.auto.conf light-theme.auto.conf no-preference-theme.auto.conf; do
    if [[ -f "$REPO/kitty/$f" ]]; then
        ok "kitty theme $f"
    else
        bad "kitty auto theme missing: kitty/$f"
    fi
done

# Сам конфиг должен проходить парсер kitty: опечатка в ключе выводится в stderr
# строкой 'Ignoring unknown config key', ошибка в map — исключением. Без kitty
# (headless) проверка недоступна.
if command -v kitty >/dev/null 2>&1; then
    if diag="$(kitty +runpy "
from kitty.config import load_config
from kitty.colors import parse_colors
load_config('$REPO/kitty/kitty.conf')
for t in ('dark-theme.auto.conf', 'light-theme.auto.conf', 'no-preference-theme.auto.conf'):
    with open(f'$REPO/kitty/{t}') as f:
        parse_colors([f])
print('PARSE_OK')
" 2>&1)" && grep -q PARSE_OK <<< "$diag"; then
        if grep -qE 'Ignoring unknown config key|Error|Traceback' <<< "$diag"; then
            bad "kitty config parse warnings: $(grep -E 'Ignoring|Error|Traceback' <<< "$diag" | head -n 2 | tr '\n' ' ')"
        else
            ok "kitty +load-config parse"
        fi
    else
        bad "kitty config parse failed: $(head -n 3 <<< "$diag" | tr '\n' ' ')"
    fi
else
    ok "kitty config parse skipped (kitty not installed)"
fi

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
# up through semitransparent windows"). У полупрозрачного окна kitty она
# просвечивает и красит всё окно в свой цвет. Правило
# `draw-border-with-background false` рисует её контуром ВОКРУГ окна.
if [[ -f "$REPO/niri/config.kdl" ]]; then
    if awk '
        /^[[:space:]]*window-rule[[:space:]]*\{/ { inblk = 1; app = 0; bg = 0; next }
        inblk && /kitty/ { app = 1 }
        inblk && /draw-border-with-background[[:space:]]+false/ { bg = 1 }
        inblk && /^[[:space:]]*\}[[:space:]]*$/ { if (app && bg) found = 1; inblk = 0 }
        END { exit(found ? 0 : 1) }
    ' "$REPO/niri/config.kdl"; then
        ok "niri draws border around translucent terminals (no focus-ring bleed)"
    else
        bad "niri has no window-rule with draw-border-with-background false for kitty"
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
# ignore-файлы тоже смотрим: иначе рантайм, который приложение пишет в репо,
# для проверки просто невидим.
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
