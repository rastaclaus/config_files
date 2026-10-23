#!/usr/bin/env bash
#
# preflight.sh — проверки перед запуском песочницы. Меняет только состояние
# самого ocbox: инициализирует среду текущего проекта (как это сделал бы
# `ocbox shell`) и удаляет созданные им же пробные файлы.
#
#   bash opencode/sandbox/preflight.sh [--with-mcp] [--backend docker|vm]
#
# Проверяет:
#   docker: docker без sudo, seccomp, образ, glibc, версии, монтирования,
#           изоляцию в реальном контейнере;
#   vm:     limactl/qemu, KVM (или предупреждение про TCG), VM проекта,
#           монтирования в госте, изоляцию внутри VM;
#   с --with-mcp: opencode mcp list внутри песочницы.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=opencode/sandbox/env.sh
source "$SELF_DIR/env.sh"

WITH_MCP=0
BACKEND=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-mcp) WITH_MCP=1; shift ;;
        --backend)  BACKEND="${2:-}"; shift 2 ;;
        --backend=*) BACKEND="${1#*=}"; shift ;;
        *) shift ;;
    esac
done
[[ -n "$BACKEND" ]] && export OCBOX_BACKEND="$BACKEND"
BACKEND="$(ocbox_backend)"

fail=0
ok()   { printf '\033[1;32mok\033[0m    %s\n' "$*"; }
bad()  { printf '\033[1;31mFAIL\033[0m  %s\n' "$*" >&2; fail=1; }
warn() { printf '\033[1;33mwarn\033[0m  %s\n' "$*" >&2; }
section() { printf '\n\033[1;34m%s\033[0m\n' "$*"; }

section "бэкэнд"
ok "выбран backend=$BACKEND (конфиг: $OCBOX_CONFIG_FILE)"

# =============================================================== docker ====
preflight_docker() {
    section "docker"
    if ! command -v docker >/dev/null 2>&1; then
        bad "docker не найден в PATH"
        exit 1
    fi
    if docker info >/dev/null 2>&1; then
        ok "docker доступен без sudo"
    else
        bad "docker не отвечает (демон не запущен или нет прав)"
        exit 1
    fi
    if docker info --format '{{.SecurityOptions}}' | grep -q 'seccomp'; then
        ok "seccomp включён (профиль по умолчанию)"
    else
        warn "seccomp не включён — контейнер будет слабее"
    fi

    # ----------------------------------------------------------------- image
    section "образ"
    if docker image inspect "$OCBOX_IMAGE" >/dev/null 2>&1; then
        ok "образ $OCBOX_IMAGE собран"
    else
        bad "образ $OCBOX_IMAGE не собран: ocbox build"
        exit 1
    fi

    host_glibc="$(ldd --version | head -1 | grep -oE '[0-9]+\.[0-9]+$')"
    img_glibc="$(docker run --rm --entrypoint ldd "$OCBOX_IMAGE" --version 2>/dev/null \
        | head -1 | grep -oE '[0-9]+\.[0-9]+$')"
    if [[ -z "$host_glibc" || -z "$img_glibc" ]]; then
        warn "не удалось определить glibc (хост='$host_glibc', образ='$img_glibc')"
    else
        newest="$(printf '%s\n%s\n' "$host_glibc" "$img_glibc" | sort -V | tail -1)"
        if [[ "$newest" == "$img_glibc" ]]; then
            ok "glibc: образ $img_glibc >= хост $host_glibc"
        else
            bad "glibc образа $img_glibc СТАРЕЕ хостовой $host_glibc — хостовые python/uv/rustc упадут"
            warn "пересоберите образ: ocbox build"
        fi
    fi

    # ------------------------------------------------------ хостовые пути
    section "хостовые пути"
    mapfile -d '' -t PROBE_ENV  < <(ocbox_env_args)
    PROBE_RO=()
    for p in "${OCBOX_RO_DIRS[@]}" "${OCBOX_RO_FILES[@]}"; do
        [[ -e "$p" ]] && PROBE_RO+=( -v "$p:$p:ro" )
    done

    for p in "${OCBOX_RO_DIRS[@]}"; do
        if [[ -d "$p" ]]; then ok "ro  $p"; else warn "пропущен (нет каталога): $p"; fi
    done
    for p in "${OCBOX_RO_FILES[@]}"; do
        if [[ -f "$p" ]]; then ok "ro  $p"; else warn "пропущен (нет файла): $p"; fi
    done
    for p in "${OCBOX_RW_DIRS[@]}"; do
        if [[ -d "$p" ]]; then ok "rw  $p"; else warn "пропущен (нет каталога): $p"; fi
    done
    if [[ "${OCBOX_STRICT_CACHE:-0}" == "1" ]]; then
        warn "OCBOX_STRICT_CACHE=1: кэши сборки не монтируются"
    else
        for p in "${OCBOX_CACHE_DIRS[@]}"; do
            if [[ -d "$p" ]]; then ok "rw  $p"; else warn "пропущен (нет каталога): $p"; fi
        done
    fi

    denied_leak=0
    for d in "${OCBOX_DENY[@]}"; do
        for m in "${OCBOX_RO_DIRS[@]}" "${OCBOX_RO_FILES[@]}" \
                 "${OCBOX_RW_DIRS[@]}" "${OCBOX_CACHE_DIRS[@]}"; do
            if [[ "$d" == "$m" || "$d" == "$m"/* ]]; then
                bad "запрещённый путь $d попадает внутрь монтирования $m"
                denied_leak=1
            fi
        done
    done
    [[ $denied_leak -eq 0 ]] \
        && ok "ssh, gnupg, gh, uv-credentials, opencode.db и docker.sock не монтируются"

    # --------------------------------------------------------------- versions
    section "версии (хост / образ)"
    probe() { # <label> <host-cmd> <container-cmd>
        local label="$1" host_cmd="$2" cont_cmd="$3" h c
        h="$(eval "$host_cmd" 2>/dev/null | head -1)"
        c="$(docker run --rm "${PROBE_ENV[@]}" "${PROBE_RO[@]}" \
                --entrypoint sh "$OCBOX_IMAGE" -c "$cont_cmd" 2>/dev/null | head -1)"
        if [[ -z "$h" ]]; then
            warn "$label: на хосте не найдено (образ: ${c:-?})"
        elif [[ "$h" == "$c" ]]; then
            ok "$label: $h"
        else
            warn "$label: хост '$h' != образ '${c:-?}'"
        fi
    }
    probe opencode "opencode --version" "opencode --version"
    probe go       "go version"        "go version"
    probe node     "node -v"           "node -v"
    probe uv       "uv --version"      "uv --version"
    probe rustc    "rustc --version"   "rustc --version"
    probe pyenv    "pyenv --version"   "pyenv --version"

    # ------------------------------------------------------------------ probe
    section "изоляция (пробный контейнер, проект $PWD)"
    proj="$(realpath "${OCBOX_PROBE_PROJECT:-$PWD}")"
    [[ -d "$proj" ]] || proj="$HOME"
    vol="$(ocbox_volume_name "$proj")"

    if "$SELF_DIR/ocbox" sync-config "$proj" >/dev/null 2>&1; then
        ok "volume $vol инициализирован (конфиг + точки монтирования)"
    else
        bad "не удалось подготовить volume: ocbox sync-config $proj"
    fi

    mapfile -d '' -t mnts < <(ocbox_mount_args "$proj")
    IFS=$'\n' read -r -d '' probe_script <<'EOS'
set -u
rc=0
for p in "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.config/gh" \
         "$HOME/.local/share/uv/credentials" /var/run/docker.sock; do
    if [ -e "$p" ]; then echo "VISIBLE $p"; rc=1; fi
done
# Хостовая БД OpenCode не должна быть видна. Путь $HOME/.local/share/opencode
# существует и внутри (это своя БД песочницы в volume), поэтому сравниваем
# не наличие, а идентичность inode: у volume другой device.
if [ -e "$HOME/.local/share/opencode" ]; then
    echo "SANDBOX_DB_ID $(stat -c %d:%i "$HOME/.local/share/opencode")"
fi
if ( : > /usr/ocbox-probe ) 2>/dev/null; then echo "WRITABLE /usr"; rc=1; fi
if ! ( : > "$HOME/.ocbox-probe" ) 2>/dev/null; then echo "HOME NOT WRITABLE"; rc=1; fi
rm -f "$HOME/.ocbox-probe"
if ! ( : > "$OCBOX_PROJECT/.ocbox-probe" ) 2>/dev/null; then echo "PROJECT NOT WRITABLE"; rc=1; fi
rm -f "$OCBOX_PROJECT/.ocbox-probe"
if [ -x "$HOME/.pyenv/shims/python3" ] && ! "$HOME/.pyenv/shims/python3" -c 'import sys' 2>/dev/null; then
    echo "PYENV SHIM BROKEN"; rc=1
fi
exit $rc
EOS

    out="$(docker run --rm \
        --read-only --tmpfs /tmp:exec --tmpfs /run --shm-size=256m \
        --cap-drop=ALL --security-opt=no-new-privileges \
        --user "$OCBOX_UID:$OCBOX_GID" -e "OCBOX_PROJECT=$proj" \
        -v "$vol:$OCBOX_HOME" \
        "${PROBE_ENV[@]}" "${mnts[@]}" \
        "$OCBOX_IMAGE" sh -c "$probe_script" 2>&1)" && probe_ok=1 || probe_ok=0

    if [[ $probe_ok -eq 1 ]]; then
        ok "корень read-only, \$HOME и проект записываемы, запрещённые пути не видны"
        # Своя БД песочницы в volume — это нормально; важно, что это НЕ хостовая.
        sb_db="$(printf '%s\n' "$out" | sed -n 's/^SANDBOX_DB_ID //p')"
        host_db=""
        [[ -d "$HOME/.local/share/opencode" ]] \
            && host_db="$(stat -c %d:%i "$HOME/.local/share/opencode")"
        if [[ -n "$sb_db" && -n "$host_db" && "$sb_db" == "$host_db" ]]; then
            bad "\$HOME/.local/share/opencode внутри — это хостовая БД OpenCode"
        else
            ok "хостовая БД OpenCode (\$HOME/.local/share/opencode) не смонтирована"
        fi
    else
        printf '%s\n' "$out" | sed 's/^/      /' >&2
        bad "проверка изоляции не прошла"
    fi

    # -------------------------------------------------------------------- mcp
    if [[ $WITH_MCP -eq 1 ]]; then
        section "MCP (нужны сеть и ключи провайдеров)"
        # Серверный процесс поднимает MCP-соединения асинхронно: первые секунды
        # `mcp list` честно отвечает "No MCP servers configured", а через
        # 10-20 с все серверы connected. Поэтому опрашиваем, а не читаем один раз.
        mcp_script='
set -u
out=""
for _ in $(seq 1 24); do
    out="$(opencode mcp list 2>&1)"
    if printf "%s" "$out" | grep -q "connected" \
       && ! printf "%s" "$out" | grep -qE "connecting|failed|error|No MCP"; then
        printf "%s\n" "$out"
        exit 0
    fi
    sleep 5
done
printf "%s\n" "$out"
exit 1
'
        docker run --rm \
            --read-only --tmpfs /tmp:exec --tmpfs /run --shm-size=512m \
            --cap-drop=ALL --security-opt=no-new-privileges \
            --user "$OCBOX_UID:$OCBOX_GID" \
            -v "$vol:$OCBOX_HOME" \
            "${PROBE_ENV[@]}" "${mnts[@]}" \
            "$OCBOX_IMAGE" bash -c "$mcp_script" 2>&1 | sed 's/^/      /'
        if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
            ok "MCP-серверы подключились"
        else
            bad "MCP-серверы не подключились (см. вывод выше)"
        fi
    fi
}

# =================================================================== vm ====
preflight_vm() {
    section "lima / qemu"
    if ! command -v limactl >/dev/null 2>&1; then
        bad "limactl не найден: yay -S lima"
        exit 1
    fi
    ok "limactl $(limactl --version 2>/dev/null | head -1)"

    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        bad "нет qemu-system-x86_64 (pacman -S qemu-system-x86)"
        exit 1
    fi
    ok "qemu-system-x86_64 найден"

    if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
        ok "KVM доступен (/dev/kvm) — аппаратная виртуализация"
    else
        warn "KVM недоступен (/dev/kvm): QEMU работает в TCG (программная эмуляция)"
        warn "VM-режим будет заметно медленнее; включите SVM/AMD-V в BIOS для KVM"
    fi
    if command -v virtiofsd >/dev/null 2>&1; then
        ok "virtiofsd найден (альтернативный mountType)"
    fi

    # ------------------------------------------------------------------ vm
    section "VM проекта"
    local proj inst
    proj="$(realpath "${OCBOX_PROBE_PROJECT:-$PWD}")"
    [[ -d "$proj" ]] || proj="$HOME"
    inst="$(ocbox_vm_name "$proj")"

    if ! limactl list --quiet 2>/dev/null | grep -qx "$inst"; then
        bad "VM $inst не создана: ocbox build \"$proj\""
        exit 1
    fi
    if [[ "$(limactl list --format '{{.Status}}' "$inst" 2>/dev/null | head -1)" == "Running" ]]; then
        ok "VM $inst запущена"
    else
        bad "VM $inst остановлена: ocbox build \"$proj\" или ocbox shell \"$proj\""
        exit 1
    fi

    # ------------------------------------------------------------ монтирования
    section "монтирования в госте"
    local -a expected=()
    expected+=( "$proj" )
    for p in "${OCBOX_RO_DIRS[@]}" "${OCBOX_RW_DIRS[@]}"; do
        [[ -d "$p" ]] && expected+=( "$p" )
    done
    if [[ "${OCBOX_STRICT_CACHE:-0}" != "1" ]]; then
        for p in "${OCBOX_CACHE_DIRS[@]}"; do
            [[ -d "$p" ]] && expected+=( "$p" )
        done
    fi

    local mount_out p
    # Первое поле findmnt — точка монтирования; сравниваем по нему, а не по
    # подстроке: у самой длинной точки нет выравнивающих пробелов справа.
    mount_out="$(limactl shell --workdir "$OCBOX_HOME" "$inst" \
        bash -lc 'findmnt -lno TARGET' 2>/dev/null)"
    for p in "${expected[@]}"; do
        if printf '%s\n' "$mount_out" | awk -v t="$p" '$1==t{found=1} END{exit !found}'; then
            ok "смонтирован $p"
        else
            bad "не смонтирован $p"
        fi
    done

    # --------------------------------------------------------------- versions
    section "версии (хост / гость)"
    local vh vg
    for pair in "opencode:opencode --version" "go:go version" "node:node -v" \
                "uv:uv --version" "rustc:rustc --version" "pyenv:pyenv --version"; do
        local label="${pair%%:*}" cmd="${pair#*:}"
        vh="$(eval "$cmd" 2>/dev/null | head -1)"
        vg="$(limactl shell --workdir "$OCBOX_HOME" "$inst" bash -lc "$cmd" 2>/dev/null | head -1)"
        if [[ -z "$vh" ]]; then
            warn "$label: на хосте не найдено (гость: ${vg:-?})"
        elif [[ "$vh" == "$vg" ]]; then
            ok "$label: $vh"
        else
            warn "$label: хост '$vh' != гость '${vg:-?}'"
        fi
    done

    # ------------------------------------------------------------------ probe
    section "изоляция (внутри VM)"
    local probe_script out
    probe_script='
set -u
rc=0
# В госте есть собственный ~/.ssh (authorized_keys от Lima) — это нормально.
# Утечкой считается только путь, который ЛЕЖИТ НА ХОСТОВОМ МОНТИРОВАНИИ:
# mountType 9p даёт отдельный device, а корень гостя — свой.
rootdev="$(stat -c %d /)"
same_dev_as_root() { [ "$(stat -c %d "$1" 2>/dev/null)" = "$rootdev" ]; }
for p in "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.config/gh" \
         "$HOME/.local/share/uv/credentials" /var/run/docker.sock; do
    if [ -e "$p" ] && ! same_dev_as_root "$p"; then echo "LEAKED $p"; rc=1; fi
done
# Дополнительно: хостовый authorized_keys отличается от гостевого.
if [ -f "$HOME/.ssh/authorized_keys" ] && ! same_dev_as_root "$HOME/.ssh/authorized_keys"; then
    echo "LEAKED $HOME/.ssh/authorized_keys"; rc=1
fi
if ( : > /usr/ocbox-probe ) 2>/dev/null; then echo "WRITABLE /usr"; rc=1; fi
if ! ( : > "$HOME/.ocbox-probe" ) 2>/dev/null; then echo "HOME NOT WRITABLE"; rc=1; fi
rm -f "$HOME/.ocbox-probe"
if ! ( : > "$OCBOX_PROJECT/.ocbox-probe" ) 2>/dev/null; then echo "PROJECT NOT WRITABLE"; rc=1; fi
rm -f "$OCBOX_PROJECT/.ocbox-probe"
if [ -x "$HOME/.pyenv/shims/python3" ] && ! "$HOME/.pyenv/shims/python3" -c "import sys" 2>/dev/null; then
    echo "PYENV SHIM BROKEN"; rc=1
fi
echo "GUEST_ROOT_DEV $(stat -c %d /)"
echo "GUEST_HOME_DEV $(stat -c %d "$HOME")"
echo "GUEST_PROJECT_DEV $(stat -c %d "$OCBOX_PROJECT")"
exit $rc
'
    out="$(limactl shell --workdir "$OCBOX_HOME" "$inst" \
        env "OCBOX_PROJECT=$proj" bash -lc "$probe_script" 2>&1)" && probe_ok=1 || probe_ok=0
    if [[ $probe_ok -eq 1 ]]; then
        ok "\$HOME и проект записываемы, запрещённые пути не видны"
        local root_dev project_dev
        root_dev="$(printf '%s\n' "$out" | sed -n 's/^GUEST_ROOT_DEV //p')"
        project_dev="$(printf '%s\n' "$out" | sed -n 's/^GUEST_PROJECT_DEV //p')"
        if [[ -n "$root_dev" && -n "$project_dev" && "$root_dev" != "$project_dev" ]]; then
            ok "корень гостя и проект — разные файловые системы (mount, а не копия)"
        else
            warn "не удалось различить корень гостя и проект (dev=$root_dev/$project_dev)"
        fi
    else
        printf '%s\n' "$out" | sed 's/^/      /' >&2
        bad "проверка изоляции в VM не прошла"
    fi

    # -------------------------------------------------------------------- mcp
    if [[ $WITH_MCP -eq 1 ]]; then
        section "MCP (нужны сеть и ключи провайдеров)"
        local mcp_script
        mcp_script='
set -u
out=""
for _ in $(seq 1 24); do
    out="$(opencode mcp list 2>&1)"
    if printf "%s" "$out" | grep -q "connected" \
       && ! printf "%s" "$out" | grep -qE "connecting|failed|error|No MCP"; then
        printf "%s\n" "$out"
        exit 0
    fi
    sleep 5
done
printf "%s\n" "$out"
exit 1
'
        limactl shell --workdir "$OCBOX_HOME" "$inst" bash -lc "$mcp_script" 2>&1 | sed 's/^/      /'
        if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
            ok "MCP-серверы подключились"
        else
            bad "MCP-серверы не подключились (см. вывод выше)"
        fi
    fi
}

case "$BACKEND" in
    docker) preflight_docker ;;
    vm)     preflight_vm ;;
    *)      bad "неизвестный backend='$BACKEND'"; exit 1 ;;
esac

section "итог"
if [[ $fail -eq 0 ]]; then
    ok "всё готово: ocbox shell"
    exit 0
fi
bad "есть проблемы — см. FAIL выше"
exit 1
