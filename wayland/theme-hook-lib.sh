#!/usr/bin/env bash
#
# Общие помощники для wayland/theme-hooks.d/*.sh.
#
# Хуки вызываются из wayland/theme-sync после записи state-файлов:
#
#   <hook> <dark|light>
#
# Окружение, которое выставляет theme-sync:
#   THEME_STATE         каталог рантайм-состояния (~/.local/state/dotfiles)
#   THEME_HOOK_LOG      файл лога (туда же пишут сами хуки)
#   THEME_PREV_MODE     режим до текущего переключения (может быть пустым)
#   THEME_GUI           1 — есть живая графическая сессия (wayland/X11)
#
# Контракт хука:
#   - сам решает, применим ли он (нет приложения — exit 0, это не ошибка);
#   - не пишет в репозиторий, только в $THEME_STATE;
#   - идемпотентен и быстрый (theme-sync даёт timeout 15 с);
#   - любой ненулевой код только логируется и не валит переключение темы.
#
# shellcheck shell=bash

theme_state_dir() {
    printf '%s\n' "${THEME_STATE:-$HOME/.local/state/dotfiles}"
}

theme_log() {
    local log="${THEME_HOOK_LOG:-$(theme_state_dir)/theme-hooks.log}"
    [[ -d ${log%/*} ]] || mkdir -p "${log%/*}"
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$log" 2>/dev/null || true
}

theme_have() {
    command -v "$1" >/dev/null 2>&1
}

theme_gui() {
    [[ ${THEME_GUI:-0} == 1 ]]
}

# Есть ли уже запущенный процесс (иначе нечего перезагружать).
theme_running() {
    pgrep -u "$(id -u)" -x "$1" >/dev/null 2>&1
}
