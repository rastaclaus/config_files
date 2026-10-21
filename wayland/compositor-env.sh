#!/usr/bin/env bash
#
# Живой сокет композитора для скриптов темы.
#
# Зачем: theme-sync вызывает darkman, а darkman.service живёт дольше сессии
# композитора. При перезапуске niri/sway переменные NIRI_SOCKET/SWAYSOCK в
# окружении сервиса остаются от прошлого запуска и указывают на несуществующий
# (или мёртвый) сокет. Проверка `-S "$NIRI_SOCKET"` тогда ложно говорит
# "композитора нет", и тема переключается не полностью (обои, Mattermost).
#
# Поэтому: сначала доверяем переменной, только если сокет реально существует,
# иначе ищем самый свежий сокет в $XDG_RUNTIME_DIR и проверяем его живым
# запросом. Найденное экспортируем, чтобы дочерние процессы (wallpapers.sh,
# mattermost-theme) унаследовали рабочее значение.
#
# Использование:
#   . "$(dirname "$0")/compositor-env.sh"
#   theme_compositor_resolve   # 0 — найден и экспортирован, 1 — не найден
#
# shellcheck shell=bash

theme_runtime_dir() {
    printf '%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
}

# Живой niri: NIRI_SOCKET из окружения или самый свежий niri.wayland-*.sock,
# который отвечает на IPC.
theme_resolve_niri() {
    local dir sock
    dir="$(theme_runtime_dir)"

    command -v niri >/dev/null 2>&1 || {
        unset NIRI_SOCKET
        return 1
    }

    # Живой сокет проверяем реальным IPC-запросом: файл может остаться от
    # упавшего процесса, а `-S` этого не покажет.
    for sock in "${NIRI_SOCKET:-}" "$dir"/niri.wayland-*.sock; do
        [[ -n "$sock" && -S "$sock" ]] || continue
        if NIRI_SOCKET="$sock" niri msg --json outputs >/dev/null 2>&1; then
            export NIRI_SOCKET="$sock"
            return 0
        fi
    done

    unset NIRI_SOCKET
    return 1
}

# Живой sway: та же логика для sway-ipc.*.sock.
theme_resolve_sway() {
    local dir sock
    dir="$(theme_runtime_dir)"

    command -v swaymsg >/dev/null 2>&1 || {
        unset SWAYSOCK
        return 1
    }

    for sock in "${SWAYSOCK:-}" "$dir"/sway-ipc.*.sock; do
        [[ -n "$sock" && -S "$sock" ]] || continue
        if SWAYSOCK="$sock" swaymsg -t get_outputs >/dev/null 2>&1; then
            export SWAYSOCK="$sock"
            return 0
        fi
    done

    unset SWAYSOCK
    return 1
}

theme_compositor_resolve() {
    theme_resolve_niri && return 0
    theme_resolve_sway && return 0
    return 1
}

# Есть ли живая графическая сессия. Для перезапуска GUI-приложения IPC
# композитора не нужен — достаточно существующего wayland-сокета или X11.
theme_display_alive() {
    local dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [[ -n "${WAYLAND_DISPLAY:-}" && -S "$dir/${WAYLAND_DISPLAY}" ]]; then
        return 0
    fi
    [[ -n "${DISPLAY:-}" ]] && return 0
    return 1
}
