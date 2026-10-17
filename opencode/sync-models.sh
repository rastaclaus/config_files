#!/bin/bash
# sync-models.sh - обновление списка моделей BotHub и RouterAI в конфиге OpenCode

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_info() { echo -e "${YELLOW}→${NC} $1"; }
log_debug() { echo -e "${BLUE}ℹ${NC} $1"; }

# Конфигурация провайдеров
declare -A PROVIDERS=(
    [bothub]="https://openai.bothub.chat/v1"
    [routerai]="https://routerai.ru/api/v1"
)

declare -A API_KEYS=(
    [bothub]="BOTHUB_API_KEY"
    [routerai]="ROUTERAI_API_KEY"
)

# V2-конфиг OpenCode: opencode.jsonc (JSONC — разрешены // и /* */ комментарии).
# Каталог ~/.config/opencode — merge-каталог (см. install/symlinks.conf): файлы
# конфига — симлинки в репозиторий, рантайм (package.json, bun.lock,
# node_modules, service.json) живёт там же обычными файлами и в git не попадает.
# jq не умеет парсить JSONC, поэтому чтение/запись конфига делает python3 (функция write_provider_models).
CONFIG_FILE="$HOME/.config/opencode/opencode.jsonc"
# Бэкап — вне репозитория: состояние OpenCode не должно попадать в рабочее дерево.
BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/opencode"
BACKUP_FILE="$BACKUP_DIR/opencode.jsonc.$(date +%Y%m%d-%H%M%S)"
PROVIDERS_TO_UPDATE=()

# Vision-модели: к id, совпадающим с этим regexp (регистронезависимо), добавляется attachment:true
# описания: -vl- / -vl$ -> qwen/vl-*  | glm-[0-9]…v -> glm-4.5v/4.6v/5v-turbo
# ^google/gemini, ^openai/gpt-4o|gpt-4.1|gpt-5, ^anthropic/claude, ^x-ai/grok-[0-9]
# исключаются (не vision): ...|embed|tts|image|claude-fable — см. jq-фильтр в update_provider
VISION_REGEX='-vl-|-vl$|glm-[0-9][0-9a-z.-]*v($|-)|^google/gemini|^openai/gpt-4o|^openai/gpt-4\.1|^openai/gpt-5|^anthropic/claude|^x-ai/grok-[0-9]'

# Парсинг аргументов
parse_args() {
    if [ $# -eq 0 ]; then
        PROVIDERS_TO_UPDATE=("bothub" "routerai")
    else
        while [ $# -gt 0 ]; do
            case $1 in
                --bothub)
                    PROVIDERS_TO_UPDATE+=("bothub")
                    shift
                    ;;
                --routerai)
                    PROVIDERS_TO_UPDATE+=("routerai")
                    shift
                    ;;
                --help)
                    print_help
                    exit 0
                    ;;
                *)
                    log_error "Неизвестный аргумент: $1"
                    print_help
                    exit 1
                    ;;
            esac
        done
    fi

    # Удаление дубликатов
    PROVIDERS_TO_UPDATE=($(printf '%s\n' "${PROVIDERS_TO_UPDATE[@]}" | sort -u))
}

print_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Обновляет список моделей для провайдеров BotHub и RouterAI в конфиге OpenCode

ОПЦИИ:
    --bothub        Обновить только BotHub
    --routerai      Обновить только RouterAI
    --help          Показать эту справку

ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ:
    BOTHUB_API_KEY      API ключ для BotHub
    ROUTERAI_API_KEY    API ключ для RouterAI

ПРИМЕРЫ:
    $0                              # Обновить оба провайдера
    $0 --bothub                    # Обновить только BotHub
    $0 --routerai                  # Обновить только RouterAI
EOF
}

# Проверка зависимостей
check_dependencies() {
    log_debug "Проверка зависимостей..."

    if ! command -v jq &> /dev/null; then
        log_error "jq не установлен. Установите: sudo apt install jq"
        exit 1
    fi
    log_success "jq найден"

    if ! command -v curl &> /dev/null; then
        log_error "curl не установлен. Установите: sudo apt install curl"
        exit 1
    fi
    log_success "curl найден"

    if ! command -v python3 &> /dev/null; then
        log_error "python3 не установлен. Установите: sudo apt install python3"
        exit 1
    fi
    log_success "python3 найден"
}

# Проверка конфига
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Конфиг OpenCode не найден: $CONFIG_FILE"
        log_info "Создайте конфиг или запустите opencode"
        exit 1
    fi
    log_success "Конфиг найден: $CONFIG_FILE"
}

# Создание backup
create_backup() {
    mkdir -p "$BACKUP_DIR"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    log_success "Backup создан: $BACKUP_FILE"
}

# Проверка API ключа для провайдера
check_api_key() {
    local provider=$1
    local env_var=${API_KEYS[$provider]}
    local key_value="${!env_var:-}"

    if [ -z "$key_value" ]; then
        log_error "Переменная окружения $env_var не установлена для провайдера '$provider'"
        return 1
    fi
    log_debug "API ключ для $provider найден"
    return 0
}

# Получение моделей от API (возвращает только JSON)
fetch_models() {
    local provider=$1
    local api_url="${PROVIDERS[$provider]}"
    local env_var=${API_KEYS[$provider]}
    local api_key="${!env_var}"

    # Выводим логирование в stderr чтобы не загрязнять вывод JSON
    log_info "Запрос моделей от $provider: $api_url/models" >&2

    curl -s -X GET "$api_url/models" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json"
}

# Обновление конфига для одного провайdera
update_provider() {
    local provider=$1

    log_debug "Обновление провайдера: $provider"

    # Проверка API ключа
    if ! check_api_key "$provider"; then
        return 1
    fi

    # Получение моделей
    local models_json
    models_json=$(fetch_models "$provider")

    # Проверка, что ответ не пустой
    if [ -z "$models_json" ]; then
        log_error "Пустой ответ от API $provider"
        return 1
    fi

    # Проверка валидности JSON
    if ! echo "$models_json" | jq empty 2>/dev/null; then
        log_error "Неверный формат ответа от $provider API (не валидный JSON)"
        log_debug "Первые 300 символов: $(echo "$models_json" | head -c 300)"
        return 1
    fi

    # Проверка наличия поля data
    if ! echo "$models_json" | jq -e '.data' > /dev/null 2>&1; then
        log_error "API $provider не вернул поле 'data'"
        log_debug "Структура ответа: $(echo "$models_json" | jq 'keys' 2>/dev/null || echo "$models_json" | head -c 300)"
        return 1
    fi

    # Извлечение списка моделей
    local model_count
    model_count=$(echo "$models_json" | jq '.data | length') || {
        log_error "Ошибка при подсчете моделей $provider"
        return 1
    }

    log_success "Получено $model_count моделей от $provider API"

    # Генерация секции models: vision-моделям добавляется attachment:true
    # (исключаются embed/tts/image/claude-fable — генеративные, embed- и аудио-модели)
    local models_section
    models_section=$(echo "$models_json" | jq --arg vr "$VISION_REGEX" '
      .data | map(
        {(.id): {name: .id} + (
          if (.id | test($vr; "i"))
             and (.id | test("embed"; "i") | not)
             and (.id | test("tts"; "i") | not)
             and (.id | test("image"; "i") | not)
             and (.id | test("claude-fable"; "i") | not)
          then {attachment: true} else {} end
        )}
      ) | add')

    if [ -z "$models_section" ] || [ "$models_section" = "null" ]; then
        log_error "Ошибка при обработке моделей $provider"
        return 1
    fi

    # Запись секции models в конфиг.
    # Конфиг — JSONC (opencode.jsonc), jq его не парсит, поэтому правит python3.
    # Касательно V2: моделям провайдера ставим .providers[$provider].models, не трогая остальные
    # поля (name, env, package, settings).
    local models_file
    models_file=$(mktemp)
    printf '%s' "$models_section" > "$models_file"

    log_info "Запись моделей в $CONFIG_FILE"
    if ! python3 - "$CONFIG_FILE" "$provider" "$models_file" <<'PY'
import sys, json, os, tempfile

def load_jsonc(text):
    # 1) Убираем // и /* */ комментарии, не трогая содержимое строок.
    out, i, n = [], 0, len(text)
    in_str = esc = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    no_comments = ''.join(out)

    # 2) Убираем завершающие запятые перед } или ].
    o2, i, n = [], 0, len(no_comments)
    in_str = esc = False
    while i < n:
        c = no_comments[i]
        if in_str:
            o2.append(c)
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            o2.append(c)
            i += 1
            continue
        if c == ',':
            j = i + 1
            while j < n and no_comments[j] in ' \t\r\n':
                j += 1
            if j < n and no_comments[j] in '}]':
                i += 1
                continue
        o2.append(c)
        i += 1

    return json.loads(''.join(o2))

path, provider, models_file = sys.argv[1], sys.argv[2], sys.argv[3]
# ~/.config/opencode/opencode.jsonc — симлинк в репозиторий (merge-каталог).
# Пишем по реальному пути и через temp+rename: иначе os.replace заменил бы сам
# симлинк обычным файлом, и конфиг разъехался бы с репозиторием.
path = os.path.realpath(path)
with open(models_file) as f:
    models = json.load(f)

try:
    with open(path) as f:
        cfg = load_jsonc(f.read())
except FileNotFoundError:
    cfg = {}

cfg.setdefault('providers', {})
cur = cfg['providers'].get(provider) or {}
cur['models'] = models
cfg['providers'][provider] = cur

# Атомарная запись: обрыв посреди json.dump не должен оставить битый конфиг.
dir_ = os.path.dirname(path) or '.'
fd, tmp = tempfile.mkstemp(dir=dir_, prefix='.opencode.jsonc.', suffix='.tmp')
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
        f.write('\n')
    # mkstemp создаёт 0600; у конфига в репозитории права 0644.
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)
except BaseException:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
print('ok')
PY
    then
        rm -f "$models_file"
        log_error "Ошибка при записи конфига для $provider"
        return 1
    fi
    rm -f "$models_file"

    log_success "Конфиг обновлен для провайдера: $provider ($model_count моделей)"

    # Вывод примеров
    log_debug "Примеры моделей $provider:"
    echo "$models_json" | jq -r '.data[:3][].id' 2>/dev/null | sed 's/^/    - /'

    echo ""
}

# Основная логика
main() {
    log_info "Модернизированный скрипт синхронизации моделей"
    echo ""

    # Парсинг аргументов
    parse_args "$@"

    # Проверки
    check_dependencies
    check_config

    if [ ${#PROVIDERS_TO_UPDATE[@]} -eq 0 ]; then
        log_error "Не указаны провайдеры для обновления"
        print_help
        exit 1
    fi

    # Backup
    create_backup

    # Обновление провайдеров
    local failed_providers=()
    for provider in "${PROVIDERS_TO_UPDATE[@]}"; do
        if ! update_provider "$provider"; then
            failed_providers+=("$provider")
        fi
    done

    echo ""

    # Результаты
    if [ ${#failed_providers[@]} -eq 0 ]; then
        log_success "Все провайдеры успешно обновлены!"
        log_info "Перезапустите opencode для применения изменений"
        exit 0
    else
        log_error "Ошибки при обновлении следующих провайдеров:"
        printf '  - %s\n' "${failed_providers[@]}"
        log_info "Backup сохранен в: $BACKUP_FILE"
        exit 1
    fi
}

main "$@"