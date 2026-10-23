# ocbox — OpenCode в одноразовом контейнере

Песочница для `opencode`: агент видит только текущий проект, хостовые
`~/.ssh`, `~/.gnupg`, gh-креды, БД OpenCode и docker-сокет ему недоступны.
Тулчейны (pyenv, rustup, uv tools, MCP-серверы) берутся с хоста read-only,
системные Go/Node/Rust/opencode стоят в образе.

```sh
ocbox build            # собрать образ (после pacman -Syu на хосте!)
ocbox doctor           # preflight: glibc, пути, изоляция
ocbox doctor --with-mcp # то же + проверка, что MCP-серверы подключаются
ocbox shell            # TUI opencode в песочнице (текущий каталог = проект)
ocbox run "…"          # opencode run без TUI (для CI и скриптов)
ocbox serve            # headless-сервер + ссылка для браузера
ocbox pair             # одноразовая ссылка входа (живёт 5 минут)
ocbox logs / ocbox stop
ocbox export           # выгрузить сессию в ~/.local/state/ocbox/
ocbox status           # контейнер и volume проекта
ocbox destroy          # удалить контейнер и volume проекта
```

Первый аргумент-каталог опционален: по умолчанию берётся `$PWD`
(`ocbox shell ~/src/proj` — работать в другом проекте).

## Почему docker, а не VM

На этом хосте SVM/AMD-V выключен в BIOS (`kvm_amd: SVM not supported`,
`SVM disabled (by BIOS) in MSR_VM_CR`), поэтому аппаратная VM недоступна.
`systemd-nspawn` не может использовать корень хоста как дерево контейнера,
а `--ephemeral` требует btrfs — здесь ext4. Граница поэтому контейнерная:
namespaces + cgroups + seccomp + `--cap-drop=ALL` +
`--no-new-privileges` + read-only rootfs.

Модель угроз:

| Сценарий | Защита |
|---|---|
| Агент меняет файлы вне проекта | да: запись только в проект, `$HOME` (volume) и кэши |
| Чтение `~/.ssh`, gpg, gh-токенов, хостовой БД сессий | да: не монтируются |
| `npm install` / `cargo build` из сети | частично: код исполняется в контейнере, ядро общее |
| Побег через 0day ядра | **нет**: контейнер не граница против эксплойта ядра |
| fork-bomb / утечка памяти | да: `--pids-limit`, `--memory`, `--cpus` |
| Случайная публикация сервера в сеть | да: порт только на `127.0.0.1` |

Ключей и git-токенов внутри нет, `git push` делается с хоста; секреты
провайдеров приходят только через env (`ROUTERAI_API_KEY` и т. п.).

## Что монтируется

| Хост | Режим | Зачем |
|---|---|---|
| каталог проекта | rw | единственный рабочий каталог |
| volume `ocbox-<hash>-home` → `$HOME` | rw | БД сессий, кэши opencode, state |
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
`preflight.sh`.

Кэши можно отключить: `OCBOX_STRICT_CACHE=1 ocbox shell` — тогда сборка идёт
внутрь volume проекта, хост-кэши не трогаются.

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
копирует в volume проекта. Хост остаётся источником истины; `service.json`
хоста не переносится — у песочницы свой пароль web-сервиса, он сохраняется
между запусками. После правки конфига: `ocbox sync-config` (или новый `ocbox shell`).

## После обновления хоста

Хостовые `~/.pyenv/versions/*/bin/python` собраны под glibc хоста. Если образ
отстал, они падают с `GLIBC_2.xx not found`:

```sh
ocbox build && ocbox doctor
```

`ocbox doctor` сравнивает `ldd --version` хоста и образа, версии
opencode/go/node/uv/rustc/pyenv и проверяет изоляцию в реальном контейнере.

## Сессии

История живёт в volume проекта (`ocbox-<hash>-home`), хостовая БД не
затрагивается. Перенос в хостовый OpenCode:

```sh
ocbox export           # ~/.local/state/ocbox/<proj>-session-<ts>.json
opencode session import ~/.local/state/ocbox/<proj>-session-<ts>.json
```

## Headless / браузер

```sh
ocbox serve            # фоновый контейнер, порт 127.0.0.1:4938x
ocbox pair             # одноразовая ссылка для браузера (5 минут)
```

`ocbox serve` поднимает внутри контейнера управляемый сервис OpenCode
(`opencode service start`) с `hostname=0.0.0.0`, поэтому ссылка `pair`
работает. Свободный хост-порт выбирается автоматически (49380+), потому что
49374 обычно занят фоновым сервисом хоста; переопределяется через
`OCBOX_SERVE_PORT`.

## MCP

Внутри песочницы те же 4 сервера (`vision`, `web-docs`, `deepwiki`, `docs`).
Серверный процесс поднимает соединения асинхронно, поэтому сразу после старта
`opencode mcp list` может ответить `No MCP servers configured` — через
10-20 секунд все четыре `connected`. `ocbox doctor --with-mcp` опрашивает
`mcp list` до готовности и падает, только если серверы так и не поднялись.

## Требования

- Docker без sudo, seccomp включён;
- пользователь в образе совпадает с хостовым по UID/GID;
- сеть из контейнера до провайдеров и до MCP `docs` (LAN).

## Что проверено вживую

- `go build`, `cargo build` (rustc 1.74 из хостового `~/.rustup`), `uv run`,
  pyenv-shim `python3` 3.14 — работают внутри песочницы;
- `ocbox run` реально обращается к модели и возвращает ответ; сессия
  экспортируется через `ocbox export` и импортируется на хосте;
- `ocbox serve` + `ocbox pair` выдают рабочую одноразовую ссылку входа
  (`/auth/connect/<token>`);
- внутри песочницы: `/` read-only, `~/.ssh`, `~/.gnupg`, `~/.config/gh`,
  `/var/run/docker.sock` отсутствуют, хостовая БД OpenCode не смонтирована;
- все 4 MCP-сервера — `connected`.

## Ограничения

- Порт web-сервера публикуется в `127.0.0.1`, наружу не выставляется;
- `ocbox shell` без терминала (не TTY) отказывается запускать TUI —
  используйте `ocbox run` или `ocbox shell <dir> <команда>`;
- для границы сильнее контейнера нужен gVisor (`--runtime=runsc`); в `ocbox`
  это пока не инкапсулировано.
