#!/bin/bash
# sync-bothub-models.sh - обновление списка моделей BotHub в конфиге OpenCode

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_info() { echo -e "${YELLOW}→${NC} $1"; }

# Конфигурация
API_BASE_URL="https://openai.bothub.chat/v1"
CONFIG_FILE="$HOME/.config/opencode/opencode.json"
BACKUP_FILE="$CONFIG_FILE.backup"
PROVIDER_ID="bothub"

# 1. Проверка jq
if ! command -v jq &> /dev/null; then
    log_error "jq не установлен. Установите: sudo apt install jq"
    exit 1
fi
log_success "jq найден"

# 2. Проверка переменной окружения
if [ -z "${BOTHUB_API_KEY:-}" ]; then
    log_error "Переменная BOTHUB_API_KEY не установлена"
    log_info "Использование: export BOTHUB_API_KEY='your-api-key'"
    exit 1
fi
log_success "BOTHUB_API_KEY установлен"

# 3. Проверка существования конфига
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Конфиг OpenCode не найден: $CONFIG_FILE"
    log_info "Создайте конфиг или запустите opencode"
    exit 1
fi

# 4. Backup текущего конфига
cp "$CONFIG_FILE" "$BACKUP_FILE"
log_success "Backup создан: $BACKUP_FILE"

# 5. Запрос к API
log_info "Запрос списка моделей от BotHub API..."
MODELS_JSON=$(curl -s -X GET "$API_BASE_URL/models" \
    -H "Authorization: Bearer $BOTHUB_API_KEY" \
    -H "Content-Type: application/json")

if [ $? -ne 0 ]; then
    log_error "Ошибка запроса к API"
    rm "$BACKUP_FILE"
    exit 1
fi

# Проверка валидности ответа
if ! echo "$MODELS_JSON" | jq -e '.data' > /dev/null 2>&1; then
    log_error "Неверный формат ответа API"
    log_info "Ответ: $(echo "$MODELS_JSON" | head -c 200)"
    rm "$BACKUP_FILE"
    exit 1
fi

# 6. Извлечение списка моделей
MODEL_COUNT=$(echo "$MODELS_JSON" | jq '.data | length')
log_success "Получено $MODEL_COUNT моделей от BotHub API"

# 7. Генерация секции models
MODELS_SECTION=$(echo "$MODELS_JSON" | jq -r '
  .data | 
  map({(.id): {name: .id}}) | 
  add
')

# 8. Merge с существующим конфигом
# Читаем текущий конфиг и обновляем только модели для провайдера bothub
UPDATED_CONFIG=$(jq --argjson models "$MODELS_SECTION" \
    --arg provider "$PROVIDER_ID" '
    .provider[$provider].models = $models
' "$CONFIG_FILE")

# 9. Запись обновленного конфига
echo "$UPDATED_CONFIG" | jq '.' > "$CONFIG_FILE"
log_success "Конфигурация обновлена: $CONFIG_FILE"

# Вывод информации
log_info "Обновлено моделей: $MODEL_COUNT"
log_info "Провайдер: $PROVIDER_ID"
echo ""
log_info "Примеры моделей:"
echo "$MODELS_JSON" | jq -r '.data[:5][].id' | sed 's/^/  - /'

echo ""
log_success "Готово! Перезапустите opencode для применения изменений"
