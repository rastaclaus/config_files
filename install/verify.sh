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
# (скрипт срабатывает только на реальной смене режима).
THEME_SYNC_NO_MATTERMOST=1 "$REPO/wayland/theme-sync" "$cur"
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
