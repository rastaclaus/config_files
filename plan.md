# План: единая ветка + hosts/ + установщик для dotfiles

Репозиторий: `/home/artems/config_files`. Цель — одна ветка (`master`), хост-зависимые
конфиги в подкаталогах `hosts/<host>/`, скрипт установки зависимостей (yay/npm/uv) и
раскладки симлинков, отдельный headless-профиль для рабочей машины.

## Принятые решения

- **Единая ветка:** `master`. Прочие ветки (`desktop`, `ambb`, `alen`, `work`) —
  архивными тегами (`archive/*`), затем удалить; `master` force-push в origin.
- **База:** текущее (почищенное) дерево `desktop` — эталон и для конфигов, и для
  зависимостей, и для общего набора юнитов.
- **Выпиливаем** всё, чего нет в `desktop`, среди хост-зависимых конфигов.
- **Шелл:** только `fish` (zsh удалён на desktop).
- **Профиль work (headless):** fish + opencode + helix + nvim (с зависимостями).
- **darkman:** локация единая для всех — `lat 55.817521, lng 37.695987`, `portal: true`.
- **Хост-deltas:** минимум — `sway` (outputs) и `fish` (headless для work).

## 1. Удаляем из репозитория

- WM/бар прочих хостов: `i3/`, `i3blocks/`, `hypr/`, `waybar/`, `waypaper/`,
  `dunst/`, `mako/`, `picom.conf`, `00-keyboard.conf`.
- Терминалы/шеллы: `kitty/`, `ranger/`, `.zshrc`, `.zshenv`, `mh.zsh-theme`,
  `af-magic.zsh-theme`.
- Прочее: `lemonade.toml`, `teams-for-linux.*`, `surfingkeys.js`, `pyproject.toml`,
  `pyrightconfig.json`, `openconnect-sso/`, `fonts.list`, `pkglist.txt`.
- В desktop-дереве: битый симлинк `~/.oh-my-zsh/themes/mh.zsh-theme`; комментарий
  `#set $term kitty` в `sway/config`; переписать `sway/*.sh` с `#!/bin/zsh` на `sh`
  (`togglewaybar.sh` удалить — waybar нет).

## 2. Структура

```
config_files/                      # ветка master
├── fish/ helix/ nvim/ opencode/ direnv/ alacritty/ rofi/ darkman/
│   networkmanager-dmenu/ xdg-desktop-portal/ applications/
│   dark-mode.d/ light-mode.d/ .tmux.conf .ruff.toml        ← ОБЩЕЕ (база desktop)
├── hosts/
│   ├── desktop/  ambb/  alen/  work/
│   └── (внутри: config/** → ~/.config/**, home/** → ~/**, local-share/** → ~/.local/share/**)
├── install/
│   ├── install.sh
│   ├── packages/{base,gui}.txt
│   ├── packages/aur/{base,gui}.txt
│   ├── npm.txt
│   ├── uv-tools.txt
│   ├── symlinks.conf
│   └── hosts.conf
└── plan.md  README.md
```

## 3. Хост-deltas (содержимое hosts/)

- `hosts/<h>/config/sway/config.d/10-outputs.conf` — outputs/мониторы (разное железо).
  Общий `sway/config` — без хардкода outputs.
- `hosts/work/config/fish/config.fish` — headless: без `exec sway` и без darkman-темы.
- Прочее (darkman, rofi, alacritty, nvim, helix, opencode, ...) — единое, из корня.

## 4. Установщик `install/install.sh`

- CLI: `./install.sh [--host <h>] [--profile gui|headless] [--no-packages] [--no-links] [--dry-run]`.
- Без `--host` — определяет по `hostname` через `hosts.conf`.
- Ставит `yay` (git clone + makepkg), если нет.
- `yay -S --needed` из `base.txt` (+`gui.txt` если GUI) + `hosts/<h>/packages.txt`.
- `npm i -g` из `npm.txt`; `uv tool install` из `uv-tools.txt`; fisher + `fish_plugins`.
- Раскладка симлинков по `symlinks.conf`: сначала общее, поверх — host-override;
  существующие `~/.config/*` → в бэкап; идемпотентно.
- headless (work): `base` + fish/opencode/helix/nvim и их зависимости, без GUI и `sway`.

## 5. Зависимости (черновик, уточняется)

- `packages/base.txt`: base base-devel git fish tmux fzf fd ripgrep less man-db tree
  wget curl openssh rsync jq htop unzip direnv neovim helix opencode uv nodejs npm go
  rustup clang gcc make pkgconf shfmt lua-language-server rust-analyzer gopls marksman
  selene stylua tombi
- `packages/gui.txt`: sway swaybg swayidle swaylock swaync gammastep networkmanager
  network-manager-applet rofi rofi-emoji rofi-unicode alacritty darkman
  xdg-desktop-portal-gtk kvantum arc-gtk-theme
- `packages/aur/base.txt`: pyenv-virtualenv revdiff
- `packages/aur/gui.txt`: networkmanager-dmenu-git rofi-unicode sway-interactive-screenshot
- `npm.txt`: bash-language-server dockerfile-language-server vscode-json-languageserver
  yaml-language-server fish-lsp prettier @mermaid-js/mermaid-cli
- `uv-tools.txt`: ruff ty basedpyright pre-commit pyproject-fmt twine tox grip aider-chat
- `packages/hosts/<h>.txt`: хост-специфичные пакеты (напр. amd-ucode на ноутах).

## 6. Порядок работ

1. `git checkout -B master desktop`; архивировать прочие ветки тегами `archive/*`.
2. Удалить лишнее (§1), переписать `sway/*.sh`.
3. Создать `hosts/`, `install/` + скрипты, перенести хост-deltas, README.
4. Единые значения (darkman 55.817521/37.695987/portal true).
5. Переключить симлинки `~/.config` на новые пути (общие — как есть; host-deltas — по файлам).
6. Закоммитить; force-push `master`; удалить старые ветки.

## 7. Открытые/уточняемые детали

- Точный состав `packages/*` и разделение base/gui.
- Способ раскладки симлинков при общих каталогах с per-file override (real dir + пофайловые симлинки).
- Оставить ли `~/.config/opencode/service.json` вне git (секрет) — да, уже в `.gitignore`.
