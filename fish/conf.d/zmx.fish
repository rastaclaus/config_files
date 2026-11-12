# Интеграция с zmx (session persistence, ставится на headless-хосты).
# Сессия zmx фиксирует окружение в момент создания; при переподключении с новой
# SSH-сессии переменные клиента (SSH_AUTH_SOCK, DISPLAY, KITTY_*) протухают.
# Официальный fish-хук: на каждый промпт обновляем трекаемые переменные из
# `zmx print-env` (unset-переменные приходят строками "-NAME").
# Вне сессии (ZMX_SESSION пуст) хук ничего не делает.
function _zmx_env_hook --on-event fish_prompt
    if set -q ZMX_SESSION
        for line in (zmx print-env . 2>/dev/null)
            if string match -q -- "-*" $line
                set -e (string sub -s 2 -- $line)
            else
                set -gx (string split -m 1 "=" -- $line)
            end
        end
    end
end
