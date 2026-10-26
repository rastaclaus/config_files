# VPN (OpenVPN через NetworkManager)

Каталог — **несекретный скелет** OpenVPN-подключения под NetworkManager.
Шаблон в репозитории нейтральный: всё, что идентифицирует подключение, приходит
из gitignored-файла.

| что | где | в git |
|---|---|---|
| шаблон профиля | `vpn/profile.nmconnection.in` | да |
| локальные параметры (id, логин, эндпоинты, DNS/маршруты, имена PEM) | `vpn/local.env` | нет |
| `ca/cert/key/tls-auth` | `~/vpn/nm-openvpn/` | нет |
| пароль OpenVPN | секрет-агент (keyring) | нет |

В установленном профиле секретов нет: `password-flags=1` (пароль хранит
keyring, вводится при первом подключении), `cert-pass-flags=0` (ключ без
парольной фразы), `ca`/`cert`/`key`/`ta` — только **пути**.

## Установка

1. Положить PEM-файлы (по умолчанию `ca.pem`, `cert.pem`, `key.pem`, `ta.key`;
   другие имена — через `VPN_CA`/`VPN_CERT`/`VPN_KEY`/`VPN_TA`):

   ```
   ~/vpn/nm-openvpn/{ca.pem,cert.pem,key.pem,ta.key}
   ```

2. Завести локальные параметры:

   ```
   cp vpn/local.env.example vpn/local.env
   chmod 600 vpn/local.env
   $EDITOR vpn/local.env   # VPN_USER, VPN_REMOTE, остальное по желанию
   ```

3. Проверить и установить (профиль с тем же `id`/`uuid` заменяется, старая
   копия уходит в `~/.dotfiles-backup-<timestamp>/`):

   ```
   ./install/install_vpn.sh --check
   ./install/install_vpn.sh
   ```

Подключение: `nmcli connection up work-vpn` (или свой `VPN_CONN_ID`).

## Переменные `vpn/local.env`

| переменная | по умолчанию | смысл |
|---|---|---|
| `VPN_CONN_ID` | `work-vpn` | id подключения = имя файла профиля = аргумент `nmcli connection up` |
| `VPN_USER` | — (нужна) | логин OpenVPN (`username=`) |
| `VPN_REMOTE` | — (нужна) | эндпоинты `host:port` через запятую |
| `VPN_UUID` | генерируется один раз | UUID профиля, кэш в `~/.local/state/dotfiles/vpn-<id>.uuid` |
| `VPN_CERT_DIR` | `$HOME/vpn/nm-openvpn` | каталог с PEM |
| `VPN_CA`/`_CERT`/`_KEY`/`_TA` | `ca.pem`/`cert.pem`/`key.pem`/`ta.key` | имена файлов внутри каталога |
| `VPN_DNS` | — | DNS через `;`, пушатся профилем (ставит `dns-priority=-100`) |
| `VPN_ROUTES` | — | маршруты `network/prefix,gateway[,metric]` через пробел |
| `VPN_NEVER_DEFAULT` | `true` | не делать VPN маршрутом по умолчанию |
| `VPN_IGNORE_AUTO_DNS` | `true` | игнорировать DNS от сервера |
| `VPN_LEGACY_ID`/`_UUID` | — | старое подключение: забэкапить и удалить |
| `VPN_TARGET_DIR` | `/etc/NetworkManager/system-connections` | переопределение для тестов |

Пример:

```
VPN_DNS="10.0.0.53;10.0.0.54"
VPN_ROUTES="10.0.0.0/8,10.10.0.1,50 192.0.2.0/24,10.10.0.1,50"
#VPN_NEVER_DEFAULT="false"     # пустить VPN дефолтным маршрутом
```

Без `VPN_DNS` и `VPN_ROUTES` в профиле остаётся только то, что пушит сервер.

## UUID, keyring и замена профиля

Пароль NetworkManager хранит в секрет-агенте по UUID профиля, поэтому установщик
генерирует UUID один раз и кэширует в `~/.local/state/dotfiles/vpn-<id>.uuid`:
смена id или удаление файла — пароль придётся ввести заново (`VPN_UUID` пинит
его явно).

Если в системе остался профиль из более ранней версии этого скелета, укажи его
`VPN_LEGACY_ID`/`VPN_LEGACY_UUID` (`nmcli -f NAME,UUID connection show`
покажет оба) — установщик забэкапит и удалит его. Прочие OpenVPN-профили в
целевом каталоге только перечисляются, их он не трогает.

Ротация сертификатов: заменить PEM в `~/vpn/nm-openvpn/` и перезапустить
`./install/install_vpn.sh` — пути в профиле не меняются.
