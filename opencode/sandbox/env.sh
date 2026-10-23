# shellcheck shell=bash
#
# Единый источник путей, монтирований и переменных окружения для ocbox и
# preflight.sh. Файл только объявляет переменные и функции, ничего не выполняет.
#
# Модель: внутри контейнера повторяются хостовые абсолютные пути. Это не
# косметика — pyenv-шимы содержат зашитый PYENV_ROOT и путь к libexec/pyenv,
# а ~/.local/bin/* (uv tools) — абсолютные симлинки на ~/.local/share/uv/tools.
# Поэтому хостовые каталоги монтируются в те же самые точки, и .venv,
# созданные в песочнице, продолжают работать на хосте.

OCBOX_IMAGE="${OCBOX_IMAGE:-ocbox/opencode:1}"
OCBOX_USER="${OCBOX_USER:-${USER:-ashestopalov}}"
OCBOX_UID="${OCBOX_UID:-$(id -u)}"
OCBOX_GID="${OCBOX_GID:-$(id -g)}"
# Домашний каталог внутри контейнера — ровно хостовый $HOME: пути к тулчейнам
# и к проекту должны совпадать, иначе pyenv-шимы и симлинки uv tools ломаются.
OCBOX_HOME="${OCBOX_HOME:-$HOME}"

# Образцы для проектов: имя контейнера и volume выводятся из пути проекта.
ocbox_slug() { # <path> -> короткий детерминированный slug
    printf '%s' "$1" | sha1sum | cut -c1-8
}
ocbox_container_name() { # <path>
    local base slug
    base="$(basename "$1" | tr -c 'a-zA-Z0-9_.-' '-' | cut -c1-24)"
    base="${base#-}"; base="${base%-}"
    printf 'ocbox-%s-%s' "${base:-proj}" "$(ocbox_slug "$1")"
}
ocbox_volume_name() { # <path>
    printf 'ocbox-%s-home' "$(ocbox_slug "$1")"
}

# --- хостовые каталоги, монтируемые read-only -----------------------------
# Только листовые пути: ~ и ~/.local целиком не монтируются никогда, иначе
# внутрь уедут ~/.ssh, ~/.gnupg, ~/.config/gh, credentials uv/cargo и БД opencode.
OCBOX_RO_DIRS=(
    "$HOME/.pyenv"                                    # CPython'ы, собранные на хосте
    "$HOME/.rustup"                                   # rustup-тулчейны
    "$HOME/.cargo/bin"                                # cargo/rustup-шимы (если есть)
    "$HOME/.local/bin"                                # шимы uv tools и прочие user-bin
    "$HOME/.local/share/uv/python"                    # uv-managed интерпретаторы
    "$HOME/.local/share/uv/tools"                     # uv tool install
    "$HOME/.local/lib/node_modules/mcp-vision-bridge" # MCP vision
)
OCBOX_RO_FILES=(
    "$HOME/.gitconfig"                                # identity, без токенов (проверено)
)

# --- хостовые каталоги rw, кроме проекта ----------------------------------
OCBOX_RW_DIRS=(
    "$HOME/.local/share/web-docs-mcp"                 # MCP web-docs: docs/ + build/
)

# --- общие кэши сборки (rw, отключаются OCBOX_STRICT_CACHE=1) --------------
OCBOX_CACHE_DIRS=(
    "$HOME/.cargo/registry"
    "$HOME/go/pkg/mod"
    "$HOME/.cache/uv"
    "$HOME/.cache/go-build"
)

# --- что не должно попасть в контейнер ни при каких условиях --------------
OCBOX_DENY=(
    "$HOME/.ssh"
    "$HOME/.gnupg"
    "$HOME/.config/gh"
    "$HOME/.local/share/uv/credentials"
    "$HOME/.local/share/opencode"      # хостевая sqlite-БД opencode
    "/var/run/docker.sock"
)

# --- переменные окружения контейнера --------------------------------------
# Ключи провайдеров не пишем в образ: ~/.config/opencode/opencode.jsonc
# подставляет их через {env:...}, а auth list на хосте показывает источник
# "environment" для всех четырёх провайдеров.
OCBOX_PASSTHROUGH_ENV=(
    ROUTERAI_API_KEY
    OPENAI_API_KEY
    BOTHUB_API_KEY
    NTECH_API_KEY
)

ocbox_env_args() {
    local v
    printf -- '-e\0HOME=%s\0' "$OCBOX_HOME"
    printf -- '-e\0SHELL=/bin/bash\0'
    printf -- '-e\0LOCAL_PREFIX=%s/.local\0' "$OCBOX_HOME"
    printf -- '-e\0WEB_DOCS_MCP_DIR=%s/.local/share/web-docs-mcp\0' "$OCBOX_HOME"
    printf -- '-e\0PYENV_ROOT=%s/.pyenv\0' "$OCBOX_HOME"
    printf -- '-e\0CARGO_HOME=%s/.cargo\0' "$OCBOX_HOME"
    printf -- '-e\0RUSTUP_HOME=%s/.rustup\0' "$OCBOX_HOME"
    printf -- '-e\0UV_TOOL_DIR=%s/.local/share/uv/tools\0' "$OCBOX_HOME"
    printf -- '-e\0UV_TOOL_BIN_DIR=%s/.local/bin\0' "$OCBOX_HOME"
    printf -- '-e\0UV_PYTHON_INSTALL_DIR=%s/.local/share/uv/python\0' "$OCBOX_HOME"
    printf -- '-e\0GOROOT=/usr/lib/go\0'
    printf -- '-e\0GOMODCACHE=%s/go/pkg/mod\0' "$OCBOX_HOME"
    printf -- '-e\0GOPATH=%s/go\0' "$OCBOX_HOME"
    printf -- '-e\0PATH=%s/.pyenv/shims:%s/.local/bin:%s/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\0' \
        "$OCBOX_HOME" "$OCBOX_HOME" "$OCBOX_HOME"

    # docker сам подставит значение из окружения хоста, если оно задано.
    for v in "${OCBOX_PASSTHROUGH_ENV[@]}"; do
        [[ -n "${!v:-}" ]] || continue
        printf -- '-e\0%s\0' "$v"
    done
}

# mount-аргументы: проект (rw), конфиг-кэш (rw), ro-тулчейны, кэши.
# Отсутствующие пути пропускаются: на headless-хосте может не быть, например,
# ~/.cargo/bin, и это не повод не запускать песочницу.
ocbox_mount_args() {
    local project="$1" p
    printf -- '-v\0%s:%s\0' "$project" "$project"

    for p in "${OCBOX_RO_DIRS[@]}"; do
        [[ -d "$p" ]] && printf -- '-v\0%s:%s:ro\0' "$p" "$p"
    done
    for p in "${OCBOX_RO_FILES[@]}"; do
        [[ -f "$p" ]] && printf -- '-v\0%s:%s:ro\0' "$p" "$p"
    done
    for p in "${OCBOX_RW_DIRS[@]}"; do
        [[ -d "$p" ]] && printf -- '-v\0%s:%s\0' "$p" "$p"
    done
    if [[ "${OCBOX_STRICT_CACHE:-0}" != "1" ]]; then
        for p in "${OCBOX_CACHE_DIRS[@]}"; do
            [[ -d "$p" ]] && printf -- '-v\0%s:%s\0' "$p" "$p"
        done
    fi
}

# Куда складывать состояние песочницы на хосте (логи, экспорт сессий).
OCBOX_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ocbox"
