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

# --------------------------------------------------------------- 2. симлинки
if [[ -L "$HOME/.config/helix/runtime" ]]; then
    ok "helix runtime link -> $(readlink "$HOME/.config/helix/runtime")"
else
    bad "~/.config/helix/runtime is not a symlink"
fi

if [[ -x "$HOME/.local/share/darkman/theme" ]]; then
    ok "darkman hook"
else
    bad "darkman hook missing or not executable: ~/.local/share/darkman/theme"
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

for f in fish/config.fish fish/conf.d/theme.fish fish/fish_plugins helix/config.toml; do
    t="$HOME/.config/$f"
    if [[ -L "$t" && "$(readlink -f "$t")" == "$REPO/$f" ]]; then
        ok "~/.config/$f -> repo"
    else
        bad "~/.config/$f is not a symlink into the repo"
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
before="$(git -C "$REPO" status --porcelain)"
[[ -z "$before" ]] || warn "repo has uncommitted changes; checking they stay unchanged"

for m in dark light; do
    THEME_SYNC_NO_RELOAD=1 "$REPO/wayland/theme-sync" "$m"
    after="$(git -C "$REPO" status --porcelain)"
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
"$REPO/wayland/theme-sync" "$cur"
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
