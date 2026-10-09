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

CONFIG_FILE="$HOME/.config/opencode/opencode.json"
BACKUP_FILE="$CONFIG_FILE.backup"
PROVIDERS_TO_UPDATE=()

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

# Обновление конфига для одного провайдера
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

    # Генерация секции models
    local models_section
    models_section=$(echo "$models_json" | jq '.data | map({(.id): {name: .id}}) | add')
    
    if [ -z "$models_section" ] || [ "$models_section" = "null" ]; then
        log_error "Ошибка при обработке моделей $provider"
        return 1
    fi

    # Обновление конфига
    local config_content
    config_content=$(cat "$CONFIG_FILE")
    
    local updated_config
    updated_config=$(echo "$config_content" | jq --argjson models "$models_section" \
        --arg provider "$provider" \
        '.provider[$provider].models = $models')
    
    if [ -z "$updated_config" ] || [ "$updated_config" = "null" ]; then
        log_error "Ошибка при обновлении конфига для $provider"
        return 1
    fi

    # Запись обновленного конфига
    echo "$updated_config" > "$CONFIG_FILE" || {
        log_error "Ошибка при записи конфига для $provider"
        return 1
    }

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
