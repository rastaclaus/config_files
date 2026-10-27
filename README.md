# config_files

Личные dotfiles: одна ветка, всё host-специфичное — в `hosts/`. Репозиторий
работает как **read-only источник конфигов**: приложения в него не пишут, всё
изменяемое в рантайме живёт в `~/.local/state/dotfiles` (см.
[docs/theme.md](docs/theme.md)).

## Быстрый старт

```sh
./install/install.sh                 # автоопределение хоста
./install/install.sh --host desktop  # явный хост, --dry-run — только показать
./install/verify.sh                  # read-only проверки раскладки и темы
./install/cleanup.sh                 # dry-run: пакеты вне манифестов
./install/install_vpn.sh --check     # VPN-профиль, см. vpn/README.md
```

## Структура

```
fish/ helix/ nvim/ direnv/ ghostty/ alacritty/ rofi/ darkman/
networkmanager-dmenu/ xdg-desktop-portal/ applications/ autostart/
sway/ niri/ ironbar/ waybar/ wayland/          # Wayland-сессия (профиль gui)
theme/dark/ theme/light/                       # палитры gruvbox
darkman/theme                                  # единственный хук darkman
.tmux.conf .ruff.toml                          # общее для всех хостов
vpn/                                           # несекретный скелет VPN
docs/                                          # разборы подсистем
hosts/                                         # per-host оверрайды
  desktop/  ambb/  alen/  work/
install/
  install.sh          # установщик пакетов и симлинков
  install_vpn.sh      # профиль OpenVPN под NetworkManager
  lib.sh              # общие помощники: хост, манифесты, линковка
  cleanup.sh          # удаление пакетов вне манифестов
  verify.sh           # проверки только на чтение
  hosts.conf          # hostname → каталог хоста + профиль
  symlinks.conf       # src → target (+ теги gui/merge)
  volatile.conf       # рантайм-файлы, которые копируются, а не линкуются
  protected.txt cleanup-paths.conf   # что не удалять / где искать хвосты
  instructions/       # заметки по установке Arch на конкретные хосты
  packages/*.txt      # манифесты pacman/AUR
  npm.txt uv-tools.txt
```

Манифесты: `packages/base.txt` ставится на **любой** хост, включая headless —
поэтому `docker`, `kubectl` и их 79 зависимостей (~600 MiB) лежат там, GUI у них
нет. Всё, что тянет Chromium, GTK, Mesa или OpenCV (163 пакета, ~1.5 GiB), — в
`gui.txt`: `chromium` (нужен обёрткам из `applications/`), `mermaid-cli`,
`ueberzugpp`.

| файл | куда ставится |
|---|---|
| `packages/base.txt` | каждый хост |
| `packages/dev.txt` | профиль `gui` (на headless — по желанию) |
| `packages/gui.txt` | только профиль `gui` |
| `packages/aur/{base,dev,gui}.txt` | AUR-версии тех же списков |
| `hosts/<host>/packages.txt` | доп. пакеты хоста из репозитория |
| `hosts/<host>/packages-aur.txt` | доп. AUR-пакеты хоста |
| `hosts/<host>/keep.txt` | исключения для cleanup (см. [Cleanup](#cleanup)) |

## Хосты

| хост | hostname | профиль | композитор | что это |
|---|---|---|---|---|
| desktop | adesk | gui | niri | рабочая станция |
| ambb | ambb | gui | sway | ноутбук |
| alen | alen | gui | sway | ноутбук |
| work | awdesk | headless | none | только SSH, без GUI |

## Как раскладываются конфиги

| цель | файл в репозитории |
|---|---|
| `~/.config/<x>` | `hosts/<host>/config/<x>` |
| `~/.local/share/<x>` | `hosts/<host>/local-share/<x>` |
| `~/<x>` | `hosts/<host>/home/<x>` |

Если оверрайд хоста есть, `~/.config/<x>` становится реальным каталогом, а его
записи — симлинками в репозиторий (общее первым, хост побеждает при конфликте).
Две записи с тегом `merge` всегда раскладываются так — `~/.config/fish` и
`~/.config/helix`: приложения должны писать рядом с трекнутыми файлами.
Остальное — один симлинк. Файлы из `volatile.conf` копируются в merge-каталог,
а не линкуются. Всё заменяемое установщик бэкапит в
`~/.dotfiles-backup-<timestamp>/`.

## Композиторы и Wayland

Оба композитора ставятся для профиля `gui`. На TTY (tty1) fish запускает тот,
что записан в `~/.local/state/dotfiles/compositor`; значение пишет установщик из
колонки `compositor` в `install/hosts.conf`, дальше им владеет `wm` — правка
колонки уже настроенный хост не переносит. niri стартует через `niri-session`:

```sh
wm niri    # переключить на следующем логине
wm sway
wm none    # консоль без композитора
```

Если выбранного композитора нет (или в файле мусор), fish печатает сообщение и
оставляет рабочий шелл. Старая универсальная `WAYLAND_COMPOSITOR` не
используется: установщик стирает её вместе с копией в `systemd --user`.

Слои одинаковы у обоих: `sway/config` и `niri/config.kdl` — общее, хостовые
`config.d/` подключаются через `include`. Помощники в `wayland/` определяют
композитор в рантайме:

- `compositor-env.sh` — ищет **живой** сокет: `darkman.service` живёт дольше
  композитора, и `NIRI_SOCKET`/`SWAYSOCK` могут указывать на прошлый запуск;
  берёт самый новый сокет и проверяет его реальным IPC-запросом.
- `wallpapers.sh` — обои через `awww` (fallback `swaybg`) на всех выходах, только
  файлы текущего режима, с кэшем половин панорамы (см. [docs/theme.md](docs/theme.md)).
- `toggletouch.sh` — тачпад (`niri msg action toggle-touchpad` / `swaymsg input`);
  пишет `niri/config.d/50-touchpad.kdl` на релизах niri без встроенного действия.
- `wait-sni.sh` — ждёт StatusNotifier-хост (ironbar), прежде чем поднять
  `nm-applet` или `blueman-applet`: обе утилиты выбирают бэкенд иконки один раз
  при старте, и без хоста навсегда остаются с `GtkStatusIcon`, который Wayland
  показать не может. Пакетную autostart-запись гасит
  `autostart/nm-applet.desktop` (`Hidden=true`).
- `mattermost-theme`, `applications/theme-switch` — тема Mattermost и ручное
  переключение (см. [docs/theme.md](docs/theme.md)).

Статусбар — **ironbar** на обоих: один `ironbar/config.yaml`, модули
`workspaces`/`focused` определяют композитор в рантайме. В репозитории только
раскладка (`style.css` без `@define-color`), палитра — из обёртки в state-каталоге;
`battery` скрыт через `show_if` там, где батареи нет, и требует **upower**;
погода — общий `waybar/weather.py --plain`. Старый **waybar** оставлен для
отката (запуск закомментирован, оба бара есть в `gui.txt` и `symlinks.conf`).
Порталы: `xdg-desktop-portal/` — `sway-portals.conf` (wlr для screencast и
скриншотов) и `niri-portals.conf` (GNOME-бэкенд: wlr поддерживает только
wlroots-композиторы), в обоих `Settings=darkman` и `Inhibit=none`.

Тема: хук darkman `~/.local/share/darkman/theme` → `wayland/theme-sync`, который
переписывает state и раздаёт хуки из `theme-hooks.d/`; подробности и ручной шаг
для Qt — в разделе [Тема и обои](#тема-и-обои).

Биндинги синхронизированы между `sway/config` и `niri/config.kdl`
(`Mod`+h/j/k/l, workspace `Mod`+1..0, терминал, лаунчер, скриншоты, медиа);
`Mod`+`Return` — ghostty, `Mod`+`Shift`+`Return` — alacritty. Особенности sway без
аналога в niri (splits, stacking, focus-parent, scratchpad, resize mode) остаются
только в `sway/config`. Обёртки в `applications/`: `chromium-wayland` добавляет
Ozone/Wayland-флаги, `chromium-proxy` — ещё `socks5://localhost:2080` и отдельный
профиль.

## Терминал

Основной — **ghostty** (`Mod`+`Return`), alacritty остаётся на
`Mod`+`Shift`+`Return` как fallback. `~/.config/ghostty` — симлинк на `ghostty/`,
конфиг `config.ghostty`, палитры `ghostty/themes/gruvbox-{dark,light}`; проверено
на 1.3.1, опции версионно-зависимы. tmux сверху держит историю на панель и
переживает окно терминала.

Клавиши, scroll-mode, дампы экрана, SSH-клипборд и связка с tmux —
[docs/ghostty.md](docs/ghostty.md).

## Тема и обои

`theme-switch [dark|light]` (без аргумента — инвертировать) правит файлы в
`~/.local/state/dotfiles` и запускает хуки; работает и на headless. Палитры
gruvbox синхронизированы между alacritty, ghostty, fish, helix, tmux и rofi,
`verify.sh` сверяет hex. Обои подбираются под режим (`*_dark.*` / `*_light.*`) и
меняются вместе с темой; `Mod`+`T` — сменить вручную.

Qt-приложения следуют GTK-теме через переменную окружения — разовый ручной шаг,
репозиторий `/etc/environment` не трогает:

```sh
sudo sed -i '/^QT_QPA_PLATFORMTHEME=/d' /etc/environment
echo 'QT_QPA_PLATFORMTHEME=gtk3' | sudo tee -a /etc/environment
```

Состояние, контракт хуков, Mattermost, обои и особенности каждого приложения —
[docs/theme.md](docs/theme.md).

## Установка

```sh
./install/install.sh                 # автоопределение хоста
./install/install.sh --host desktop  # явный хост
./install/install.sh --dry-run       # только показать
./install/install.sh --no-packages   # только (пере)линковать конфиги
./install/install.sh --no-links      # только поставить пакеты
./install/install.sh --no-shell      # не менять login shell
./install/install.sh --no-nvim       # без плагинов и парсеров
```

Что делает установщик:

1. ставит `yay`, при необходимости `rustup default stable` (иначе AUR-пакеты на
   cargo падают на шимах) и включает fallback Nerd Font symbols;
2. `yay -S --needed` по `base.txt` (+ `dev.txt`, если профиль не `headless`,
   + `gui.txt` для GUI, + `hosts/<host>/packages.txt`) и по AUR-спискам, затем
   npm-глобалы в `~/.local` (дефолтный префикс npm — `/usr` под root) и `uv tool`;
3. раскладывает симлинки по `symlinks.conf` (merge-каталоги — реальные папки с
   файловыми ссылками, volatile-файлы копируются), заменяемое уходит в
   `~/.dotfiles-backup-<timestamp>/`;
4. создаёт `~/.local/state/dotfiles/`, линкует `~/.config/helix/runtime` и пишет
   `compositor` (сеется из `WAYLAND_COMPOSITOR` один раз, дальше владеет `wm`);
5. делает fish login shell (`--no-shell` отключает) — GUI стартует из
   `fish/config.fish`, bash-login оставит чёрный TTY; убирает легаси
   fisher-плагины и переменные `WAYLAND_COMPOSITOR`/`background_mode`;
6. применяет текущий режим darkman (`--no-packages` всё равно делает шаги 3-6);
7. один раз запускает `nvim --headless`, чтобы собрать плагины и
   treesitter-парсеры (`NVIM_TS_INSTALL_SYNC=1`; `--no-nvim` — пропустить).
   Плагинами управляет `vim.pack.add()` в `nvim/lua/plugins.lua`, версии пинятся
   в `nvim/nvim-pack-lock.json` (не в git) — см. [docs/nvim.md](docs/nvim.md).

Профиль `headless` ставит только base + fish/редакторы: без GUI и Sway.
Dev/DevOps-пакеты включаются на хост через `hosts/<host>/packages.txt`.

Пакет поставлен — не значит запущен: на свежей системе включи Docker и добавь
себя в группу (нужен релогин):

```sh
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Установка Arch на конкретные хосты — `install/instructions/`.

## Cleanup

`install/cleanup.sh` — обратная операция к установщику: удаляет явно
установленные пакеты вне манифестов и по желанию вычищает их следы. Те же
`lib.sh` и разрешение хоста/профиля, поэтому наборы «ставить» и «оставить» не
расходятся.

```sh
./install/cleanup.sh                     # dry-run: таблица кандидатов
./install/cleanup.sh --check             # 0 — дрейфа нет, 2 — есть
./install/cleanup.sh --apply             # спросить один раз и удалить
./install/cleanup.sh --apply --purge-configs --purge-caches
./install/cleanup.sh --apply --interactive   # спрашивать по пакету
./install/cleanup.sh --init-keep         # черновик hosts/<host>/keep.txt
```

Кандидаты — `pacman -Qqe` минус **desired** (манифесты хоста и профиля),
**protected** (`install/protected.txt`: ядро, загрузчик, прошивки, init, auth,
сеть, `yay` — не удаляется никогда), **keep** (`hosts/<host>/keep.txt` и
`--keep <pkg>`; `#` — комментарий, так что черновик `--init-keep`
раскомментируется как есть) и всё, от чего зависит оставшееся: считается до
неподвижной точки по `pacman -Qi → Required By` (включая provides, например
`fuse2 ← ntfs-3g`) и проверяется самим pacman через `pacman -Rs --print`; отказы
попадают в «остаются в системе» с причиной.

`--apply` гасит systemd-юниты удаляемых пакетов, делает одну транзакцию
`pacman -Rns` (с откатом на поштучное удаление), убирает осиротевшие зависимости
(`pacman -Qtdq`, отключается `--no-orphans`) и битые `*.wants`.

Ничего не удаляется безвозвратно: `--purge-configs` и `--purge-system`
**переносят** хвосты в карантин и не трогают ни файлы этого репозитория
(симлинки, цели `symlinks.conf`, state-каталог), ни пути установленных пакетов
(`pacman -Qo`). Пути — из `cleanup-paths.conf` плюс эвристика по имени пакета без
регистра и разделителей (`Code` ~ `code`); если каталог может принадлежать
остающемуся пакету, эвристика отступает (`~/.config/Mattermost` выживает, когда
удаляют только сервер, а `mattermost-desktop` остаётся).

`--purge-*` работают только с `--apply` (в dry-run печатают, что и сколько
переедет) и смотрят на объединение текущих кандидатов и `removed.txt` **всех**
прошлых прогонов, поэтому чистка возможна и после удаления пакетов.

`--purge-caches` чистит восстановимое (`paccache -r -k3`, `yay -Sc`, journal до
500 MiB, npm/uv/pip, миниатюры, fontconfig, кэш `web-docs-mcp`);
`--purge-modcache` добавляет Go module и Cargo registry; `--purge-tools` удаляет
npm-глобалы и `uv tool` вне `npm.txt`/`uv-tools.txt`.

Каждый применённый прогон оставляет `~/.local/state/dotfiles/cleanup/<timestamp>/`
с `removed.txt`, `orphans.txt`, `log.txt`, `report.md`, `restore.sh`
(`yay -S --needed …`, только если пакеты реально удалялись) и самим карантином:

```
cleanup/20261017-180000/
  removed.txt  orphans.txt  log.txt  report.md  restore.sh
  quarantine/home/.config/Code/...      # перенесено, не удалено
  quarantine/root/var/lib/...           # только с --purge-system
```

`CLEANUP_CHECK=1 ./install/verify.sh` дополнительно сообщает дрейф как
предупреждение (не фатально: личная машина вправе иметь лишние приложения).

## VPN

`vpn/` — **несекретный скелет** OpenVPN под NetworkManager: шаблон профиля
нейтрален, id, логин, эндпоинты, DNS/маршруты и имена PEM приходят из
gitignored `vpn/local.env`; сертификаты лежат в `~/vpn`, пароль — в keyring.

```sh
cp vpn/local.env.example vpn/local.env   # заполнить, chmod 600
./install/install_vpn.sh --check
./install/install_vpn.sh                 # nmcli connection up work-vpn
```

Подробности — [vpn/README.md](vpn/README.md).

## Документация

| файл | о чём |
|---|---|
| [docs/ghostty.md](docs/ghostty.md) | терминал: клавиши, scroll-mode, дампы, tmux, SSH |
| [docs/theme.md](docs/theme.md) | state-каталог, хуки, Mattermost, обои, per-app поведение |
| [docs/niri.md](docs/niri.md) | шпаргалка niri: модель окон, биндинги, визуал, диагностика |
| [docs/nvim.md](docs/nvim.md) | git-ревью и автодополнение в редакторе |
| [vpn/README.md](vpn/README.md) | скелет OpenVPN и его переменные |

`alacritty/themes/` — вендорнутая копия [alacritty-theme](https://github.com/alacritty/alacritty-theme)
(там свой README, `images/`, `print_colors.sh`); править её не нужно, репозиторий
использует только `themes/gruvbox_{dark,light}.toml`.
