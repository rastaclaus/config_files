# config_files

Personal dotfiles. One branch, host-specific bits under `hosts/`.

## Layout

```
fish/ helix/ nvim/ opencode/ direnv/ alacritty/ rofi/ darkman/
networkmanager-dmenu/ xdg-desktop-portal/ applications/
dark-mode.d/ light-mode.d/ .tmux.conf .ruff.toml      # common (base)
hosts/
  desktop/  ambb/  alen/  work/                       # host-specific overrides
install/
  install.sh         # installer
  hosts.conf         # hostname -> host dir + profile
  symlinks.conf      # src -> target map
  packages/*.txt     # pacman / AUR lists (see below)
  npm.txt            # global npm packages
  uv-tools.txt       # uv tool install list
```

Package manifests (official repo + its AUR counterpart):

| file                       | installed on                       |
|----------------------------|------------------------------------|
| `packages/base.txt`        | every host (incl. headless)        |
| `packages/dev.txt`         | profile `gui` (opt-in on headless) |
| `packages/gui.txt`         | profile `gui` only                 |
| `packages/aur/base.txt`    | AUR version of `base.txt`          |
| `packages/aur/dev.txt`     | AUR version of `dev.txt`           |
| `packages/aur/gui.txt`     | AUR version of `gui.txt`           |
| `hosts/<host>/packages.txt`| extra official packages for a host    |
| `hosts/<host>/packages-aur.txt`| extra AUR packages for a host    |

Common configs live at the repo root; a host only ships the files it overrides.

Host override path mapping (used by the installer):

| target                | host file                          |
|-----------------------|------------------------------------|
| `~/.config/<x>`       | `hosts/<host>/config/<x>`          |
| `~/.local/share/<x>`  | `hosts/<host>/local-share/<x>`     |
| `~/<x>`               | `hosts/<host>/home/<x>`            |

If a host override exists, `~/.config/<x>` becomes a real directory whose
entries are symlinks into the repo (common first, host wins on conflicts).
Otherwise the whole directory is a single symlink.

## Hosts

| host    | hostname | profile  | notes                          |
|---------|----------|----------|--------------------------------|
| desktop | adesk    | gui      | Sway workstation               |
| ambb    | ambb     | gui      | laptop                         |
| alen    | alen     | gui      | laptop                         |
| work    | awdesk   | headless | SSH only, no GUI               |

## Install

```sh
./install/install.sh                 # auto-detect host
./install/install.sh --host desktop  # explicit host
./install/install.sh --dry-run       # show actions only
./install/install.sh --no-packages   # only (re)link configs
./install/install.sh --no-links      # only install packages
```

The installer:
1. installs `yay` if missing,
2. `yay -S --needed` from `packages/base.txt` (+ `packages/dev.txt` unless
   profile is `headless`, + `packages/gui.txt` for GUI, + `hosts/<host>/packages.txt`),
3. `npm install -g` from `npm.txt`, `uv tool install` from `uv-tools.txt`,
4. installs fisher + fish plugins,
5. lays out symlinks per `symlinks.conf`, backing up anything it replaces to
   `~/.dotfiles-backup-<timestamp>/`.

The `headless` profile installs only the base set plus fish/opencode/editors
and their dependencies — no GUI, no Sway. Dev/DevOps tooling can be opted in
per host via `hosts/<host>/packages.txt`.
