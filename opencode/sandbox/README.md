# ocbox — OpenCode в одноразовой песочнице (docker или VM)

Песочница для `opencode`: агент видит только текущий проект, хостовые
`~/.ssh`, `~/.gnupg`, gh-креды, БД OpenCode и docker-сокет ему недоступны.
Тулчейны (pyenv, rustup, uv tools, MCP-серверы) берутся с хоста read-only,
системные Go/Node/Rust/opencode стоят в образе.

Два взаимозаменяемых бэкэнда:

| бэкэнд | изоляция | скорость | команда |
|---|---|---|---|
| `docker` | namespaces + cgroups + seccomp, **ядро общее с хостом** | быстрый | `ocbox --backend docker …` |
| `vm` | QEMU/Lima, **своё ядро и rootfs** | медленнее, без KVM — сильно медленнее | `ocbox --backend vm …` |

```sh
ocbox build            # собрать образ / создать VM проекта
ocbox doctor           # preflight: тулчейны, монтирования, изоляция
ocbox doctor --with-mcp # то же + проверка, что MCP-серверы подключаются
ocbox shell            # TUI opencode в песочнице (текущий каталог = проект)
ocbox run "…"          # opencode run без TUI (для CI и скриптов)
ocbox serve            # headless-сервер + ссылка для браузера
ocbox pair             # одноразовая ссылка входа (живёт 5 минут)
ocbox logs / ocbox stop
ocbox export           # выгрузить сессию в ~/.local/state/ocbox/
ocbox status           # что запущено для проекта
ocbox destroy          # удалить среду проекта вместе с её состоянием
ocbox config           # показать настройки (~/.config/ocbox/config)
```

Первый аргумент-каталог опционален: по умолчанию берётся `$PWD`
(`ocbox shell ~/src/proj` — работать в другом проекте).

## Выбор бэкэнда

Выбор хранится в `~/.config/ocbox/config` (один файл `key=value`):

```sh
ocbox --backend vm shell      # переключиться на VM и запомнить выбор
ocbox --backend docker shell  # вернуться к docker
ocbox config get backend      # docker | vm
ocbox config set backend vm   # то же, но без запуска песочницы
```

Приоритет: `--backend` (он же `OCBOX_BACKEND`) → конфиг → `docker`.
`ocbox config path` печатает путь к файлу.

**Одна среда на проект.** Для docker это контейнер + volume
(`ocbox-<hash>-home`), для VM — отдельный экземпляр Lima
(`ocbox-<slug>-vm`) со своим диском. Проекты не делят состояние и могут
работать параллельно.

## Почему docker, а не VM (по умолчанию)

На этом хосте SVM/AMD-V выключен в BIOS (`/dev/kvm` отсутствует), поэтому
QEMU работает в режиме TCG — программной эмуляции. VM-бэкэнд полностью
рабочий, но медленный: `ocbox doctor` в режиме `vm` предупреждает об этом, а
`ocbox build` печатает то же предупреждение. После включения SVM в BIOS VM
заработает на KVM без изменений в конфигурации.

Модель угроз:

| Сценарий | docker | vm |
|---|---|---|
| Агент меняет файлы вне проекта | нет: запись только в проект, `$HOME` и кэши | нет: то же (9p-монтирования) |
| Чтение `~/.ssh`, gpg, gh-токенов, хостовой БД сессий | нет: не монтируются | нет: не монтируются |
| `npm install` / `cargo build` из сети | код исполняется в контейнере, ядро общее | код исполняется в госте, своё ядро |
| Побег через 0day ядра | **возможен**: контейнер — не граница против эксплойта ядра | **нет**: эксплойт остаётся в госте |
| Компрометация самой песочницы | пересоздать контейнер (state в volume) | пересоздать VM (`ocbox build`) |
| fork-bomb / утечка памяти | `--pids-limit`, `--memory`, `--cpus` | `cpus`/`memory` из конфига VM |
| Случайная публикация сервера в сеть | порт только на `127.0.0.1` | portForward только на `127.0.0.1` |

В госте VM пользователь имеет passwordless sudo и записываемый rootfs —
это осознанный компромисс: граница безопасности проходит по гипервизору, а
не по правам внутри гостя. Скомпрометированную VM пересоздают: `ocbox build`.

Ключей и git-токенов внутри нет, `git push` делается с хоста; секреты
провайдеров приходят только через env (`ROUTERAI_API_KEY` и т. п.).

## Что монтируется

| Хост | Режим | Зачем |
|---|---|---|
| каталог проекта | rw | единственный рабочий каталог |
| `$HOME` песочницы | rw | БД сессий, кэши opencode, state |
| `~/.pyenv` | ro | CPython'ы и шимы |
| `~/.rustup` | ro | rustup-тулчейны |
| `~/.cargo/bin` | ro | cargo-шимы (если есть) |
| `~/.local/bin` | ro | шимы uv tools |
| `~/.local/share/uv/{python,tools}` | ro | uv-managed Python и инструменты |
| `~/.local/lib/node_modules/mcp-vision-bridge` | ro | MCP `vision` |
| `~/.gitconfig` | ro | identity (без токенов) |
| `~/.local/share/web-docs-mcp` | rw | MCP `web-docs`: `docs/` общий с хостом |
| `~/.cache/uv`, `~/.cache/go-build`, `~/.cargo/registry`, `~/go/pkg/mod` | rw | общие кэши сборки |

Не монтируется никогда: `~` целиком, `~/.ssh`, `~/.gnupg`, `~/.config/gh`,
`~/.local/share/uv/credentials`, `~/.local/share/opencode`,
`/var/run/docker.sock`. Список — в `env.sh` (`OCBOX_DENY`), его проверяет
`preflight.sh` для обоих бэкэндов.

Кэши можно отключить: `OCBOX_STRICT_CACHE=1 ocbox shell` — тогда сборка идёт
внутрь `$HOME` песочницы, хост-кэши не трогаются.

Отличия VM от docker в монтированиях:

- `~/.gitconfig` — файл, а Lima монтирует только каталоги, поэтому он
  **копируется** в home гостя при `sync-config` (только если копии ещё нет);
- `$HOME` песочницы в VM — это каталог на диске гостя (`/home/<user>`),
  а не отдельный хостовый каталог. Диск Lima переживает `stop`/`start` и
  удаляется только вместе с VM. Поэтому хостовые каталоги тулчейнов
  монтируются *внутрь* этого home — ровно как в docker;
- тип монтирования — `9p` (`securityModel: none`), поэтому владелец файлов в
  проекте совпадает с гостевым UID = хостовым UID.

## Почему пути совпадают с хостовыми

`~/.pyenv/shims/*` — скрипты с зашитым `PYENV_ROOT=/home/<user>/.pyenv` и
`exec /usr/share/pyenv/libexec/pyenv`, а `~/.local/bin/*` — абсолютные
симлинки на `~/.local/share/uv/tools/*`. Поэтому хостовые каталоги
монтируются в те же абсолютные пути, а не в `/mnt/host/...`. Побочный плюс:
`.venv`, созданный в песочнице, продолжает работать на хосте.

`rustc`/`cargo` в образе — это rustup-шимы; реальные тулчейны берутся из
смонтированного `~/.rustup`, поэтому версия Rust всегда совпадает с хостовой.

## Конфиг OpenCode

`~/.config/opencode` — merge-каталог симлинков в этот репозиторий. При каждом
запуске `ocbox` раскрывает его на хосте (`cp -aL` в staging-каталог) и
копирует в песочницу: в docker — в volume проекта, в VM — в home гостя.
Хост остаётся источником истины; `service.json` хоста не переносится — у
песочницы свой пароль web-сервиса, он сохраняется между запусками. После
правки конфига: `ocbox sync-config` (или новый `ocbox shell`).

## После обновления хоста

Хостовые `~/.pyenv/versions/*/bin/python` собраны под glibc хоста. Если образ
(или гость VM) отстал, они падают с `GLIBC_2.xx not found`:

```sh
ocbox build && ocbox doctor
```

В docker `build` пересобирает образ, в VM — прогоняет `pacman -Syu` внутри
гостя (маркер `/var/lib/ocbox-provisioned` снимается, VM перезапускается).
`ocbox doctor` сравнивает `ldd --version` хоста и песочницы, версии
opencode/go/node/uv/rustc/pyenv и проверяет изоляцию в реальной среде.

Для VM нужны `limactl` (в Arch — `yay -S lima`), `qemu-system-x86` и,
желательно, `virtiofsd`. Lima генерирует гостя из шаблона `archlinux` —
это важно: гость обязан быть на glibc не старее хостовой.

## Сессии

История живёт в `$HOME` песочницы (docker: volume `ocbox-<hash>-home`,
VM: диск гостя), хостовая БД не затрагивается. Перенос в хостовый OpenCode:

```sh
ocbox export           # ~/.local/state/ocbox/<proj>-session-<ts>.json
opencode session import ~/.local/state/ocbox/<proj>-session-<ts>.json
```

## Headless / браузер

```sh
ocbox serve            # фоновый сервер, порт 127.0.0.1:4938x
ocbox pair             # одноразовая ссылка для браузера (5 минут)
```

Свободный хост-порт выбирается при первом запуске (49380+) и сохраняется за
проектом. Сменить его можно через `OCBOX_SERVE_PORT=… ocbox serve`: в docker
это новый `-p`, в VM — правка `portForwards` через `limactl edit` (VM на это
время гасится и поднимается обратно). В обоих случаях публикуется только
`127.0.0.1`.

## MCP

Внутри песочницы те же 4 сервера (`vision`, `web-docs`, `deepwiki`, `docs`).
Серверный процесс поднимает соединения асинхронно, поэтому сразу после старта
`opencode mcp list` может ответить `No MCP servers configured` — через
10-20 секунд все четыре `connected`. `ocbox doctor --with-mcp` опрашивает
`mcp list` до готовности и падает, только если серверы так и не поднялись.

## Требования

- docker без sudo, seccomp включён (для `docker`);
- `limactl` (`yay -S lima`), `qemu-system-x86` (для `vm`); KVM желателен, но
  не обязателен; ресурсы VM — `OCBOX_CPUS` (6), `OCBOX_MEMORY` (12g),
  `OCBOX_VM_DISK` (100 GiB), применяются при создании VM;
- пользователь в песочнице совпадает с хостовым по UID/GID;
- сеть из песочницы до провайдеров и до MCP `docs` (LAN).

## Что проверено вживую

- `go build`, `cargo build` (rustc 1.74 из хостового `~/.rustup`), `uv run`,
  pyenv-shim `python3` 3.14 — работают внутри песочницы;
- `ocbox run` реально обращается к модели и возвращает ответ; сессия
  экспортируется через `ocbox export` и импортируется на хосте;
- `ocbox serve` + `ocbox pair` выдают рабочую одноразовую ссылку входа
  (`/auth/connect/<token>`);
- внутри песочницы: `/` read-only (docker), `~/.ssh`, `~/.gnupg`,
  `~/.config/gh`, `/var/run/docker.sock` отсутствуют, хостовая БД OpenCode
  не смонтирована;
- все 4 MCP-сервера — `connected`.

## Ограничения

- Порт web-сервера публикуется в `127.0.0.1`, наружу не выставляется;
- `ocbox shell` без терминала (не TTY) отказывается запускать TUI —
  используйте `ocbox run` или `ocbox shell <dir> <команда>`;
- docker-бэкэнд не защищает от эксплойта ядра — для этого нужен `vm`;
- без KVM VM-бэкэнд работает в TCG и заметно медленнее (особенно сборки
  и первый запуск: скачивание образа + `pacman -Syu`).
