# config_files

Personal dotfiles. One branch, host-specific bits under `hosts/`.

## Layout

```
fish/ helix/ nvim/ opencode/ direnv/ alacritty/ rofi/ darkman/
networkmanager-dmenu/ xdg-desktop-portal/ applications/
sway/ niri/ ironbar/ waybar/ wayland/                 # Wayland sessions (gui)
theme/dark/ theme/light/                              # color palettes
darkman/theme                                         # single darkman hook
.tmux.conf .ruff.toml                                 # common (base)
vpn/                                                  # VPN profile skeleton (see below)
hosts/
  desktop/  ambb/  alen/  work/                       # host-specific overrides
install/
  install.sh         # installer
  install_vpn.sh     # VPN profile installer (ntech)
  hosts.conf         # hostname -> host dir + profile
  symlinks.conf      # src -> target map (+ gui/merge tags)
  volatile.conf      # runtime files copied into merge dirs, not linked
  verify.sh          # read-only sanity checks
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
Two entries carry the `merge` tag and are always laid out that way
(`~/.config/fish`, `~/.config/helix`): applications must be able to write next
to the tracked files (fisher installs plugins, fish rewrites `fish_variables`,
helix may add runtime files). Everything else is a single symlink. Files listed
in `install/volatile.conf` are copied into a merge directory instead of being
linked, so writes never reach the repo.

## Hosts

| host    | hostname | profile  | notes                          |
|---------|----------|----------|--------------------------------|
| desktop | adesk    | gui      | Sway/niri workstation          |
| ambb    | ambb     | gui      | laptop                         |
| alen    | alen     | gui      | laptop                         |
| work    | awdesk   | headless | SSH only, no GUI               |

## Compositors (sway / niri)

Both compositors are installed for the `gui` profile. On a TTY (tty1) fish
starts the one selected by the `WAYLAND_COMPOSITOR` universal variable
(default `sway`, stored locally in `fish_variables`); niri runs through
`niri-session`:

```sh
wm niri    # switch for the next login
wm sway
```

Layering mirrors the rest of the repo:

- `sway/config`            — shared sway config (`include`s the host `config.d/`).
- `niri/config.kdl`        — shared niri config, with `include "config.d/..."`.
- `hosts/<host>/config/{sway,niri}/config.d/` — per-host outputs/inputs.

Shared Wayland helpers (compositor-agnostic, detected at runtime) live in
`wayland/`:

- `wallpapers.sh` — random wallpaper via `awww` (falls back to `swaybg`) on
  every active output.
- `toggletouch.sh` — touchpad toggle (`niri msg action toggle-touchpad` or
  `swaymsg input ... events`).

The status bar is **ironbar** on both compositors. A single `ironbar/config.yaml`
works for sway and niri alike — the `workspaces` and `focused` modules detect the
compositor at runtime, so there is no per-compositor split. `ironbar/style.css`
in the repo contains only the layout; the palette arrives through a generated
wrapper in `~/.local/state/dotfiles/ironbar/style.css`, so both compositors
launch it with `ironbar -t <state>/ironbar/style.css` (see `Runtime state`
below). Ironbar watches the wrapper and hot-reloads on theme changes. The
`battery` module is hidden via `show_if` on hosts without a battery, and it
depends on **upower** (unlike waybar, which read sysfs directly). Weather comes
from the shared `waybar/weather.py` script, called with `--plain` (the default
output is still waybar's JSON).

The previous **waybar** setup is kept intact in `waybar/` and the launch lines in
`sway/config` / `niri/config.kdl` are left commented out, so switching back is a
one-line change. `install/packages/gui.txt` and `install/symlinks.conf` still
carry both bars.

Portals: sway keeps `xdg-desktop-portal-wlr`, niri uses `niri-portals.conf`
(GNOME screencast backend).

Dark/light switching is driven by **darkman**: a single hook
`~/.local/share/darkman/theme` (symlink to `darkman/theme`) sends a notification
and runs `wayland/theme-sync`, which rewrites the runtime state and reloads the
running applications (see `Runtime state` below). Qt apps follow the GTK theme
through Qt's GTK platform theme, which is read from the environment — a one-time
manual step, since the repo does not manage `/etc/environment`:

```sh
sudo sed -i '/^QT_QPA_PLATFORMTHEME=/d' /etc/environment
echo 'QT_QPA_PLATFORMTHEME=gtk3' | sudo tee -a /etc/environment
```

No Qt style engine (Kvantum) is used: it was the only package pulling the Qt
stack into the GUI list, and its darkman hook could not work anyway — hooks run
as child processes, so an `export` inside them never reaches the session.

Key bindings are kept in sync between `sway/config` and `niri/config.kdl`
(`Mod`+h/j/k/l, workspace `Mod`+1..0, terminal/launcher, screenshots, media
keys). sway-only features that niri has no equivalent for (splits, stacking,
focus-parent, scratchpad, a resize mode) stay in `sway/config`.

## Runtime state и переключение темы

The repository is a **read-only configuration source**: applications never
write into it. Everything that changes at runtime lives in one fixed directory:

```
~/.local/state/dotfiles/
  background-mode                      # "dark" or "light"
  alacritty.toml                       # [general] import of the palette
  rofi.rasi                            # @theme for rofi
  helix/runtime/themes/dotfiles.toml   # theme "dotfiles" (inherits gruvbox_*)
  ironbar/colors.css                   # @define-color palette
  ironbar/style.css                    # wrapper: colors.css + repo style.css
```

The path is hard-coded (not `$XDG_STATE_HOME`): alacritty and rofi do not expand
environment variables in `import`/`?import` paths.

**Switching.** darkman calls `~/.local/share/darkman/theme` with `dark|light`;
the hook shows a notification and runs `wayland/theme-sync <mode>`, which
rewrites the files above and then:

- updates GTK (`gsettings`): `adw-gtk3-dark` / `adw-gtk3` + color-scheme;
- pushes the new palette and opacity to **running** alacritty instances via
  `alacritty msg config` (`live_config_reload` watches only the main config,
  not imported files); new windows read the state import themselves;
- sends `SIGUSR1` to helix (it reloads config and theme);
- tells running Neovim to `set background=...` via `nvim-ctrl`.

rofi picks the theme up on its next launch, fish applies it on the next prompt,
and ironbar hot-reloads because the generated wrapper changed. No application
has to be restarted.

**Merge directories.** `~/.config/fish` and `~/.config/helix` are real
directories whose files are symlinks into the repo (tag `merge` in
`symlinks.conf`). Files listed in `install/volatile.conf` (`fish_variables`,
fish's `fish_frozen_*.fish`, fisher-managed files) are copied instead: the
local copy is never overwritten, and an old symlink into the repo is replaced
by a copy on the first install. Add a new runtime file there if an application
needs to write next to a tracked one; `*` globs are supported.

**Helix.** `~/.config/helix/runtime` is a symlink to the state directory, and
`helix/config.toml` sets `theme = "dotfiles"`. Helix looks themes up in
`$XDG_CONFIG_HOME/helix/runtime/themes` without needing `HELIX_RUNTIME`, so the
theme works however helix is started (desktop entry, terminal, another WM).

**Ironbar.** It always runs with `-t <state>/ironbar/style.css`; the palette is
in `colors.css`, while the repo keeps only the layout in `ironbar/style.css`
without any `@define-color`. The watcher follows the wrapper, so after editing
the repo stylesheet, re-run `theme-sync` (or touch the wrapper) to reload.

**Fish.** `fish_variables` and the fisher plugins are local to `~/.config/fish`
and not in git; the declarative plugin list stays in `fish/fish_plugins`.
`fish/conf.d/theme.fish` applies the theme from `background-mode` on the prompt,
so the old universal `background_mode` variable is gone. `wm` still writes
`WAYLAND_COMPOSITOR` as a universal variable — locally, which is intended.

**Waybar.** It does not take part in switching and stays in rollback mode with
its static palette. To bring it back, do the same thing: generate a wrapper in
the state dir, run `waybar -s <state>/waybar/style.css`, and `@import` the
palette.

**Checks.** `./install/verify.sh` validates that the state files match the
current mode, that the merge directories and symlinks are laid out correctly,
that there are no dangling links or legacy hooks, and that switching the theme
leaves `git status` unchanged (it is read-only and restores the current mode).

**Limitations.** `XDG_STATE_HOME` must stay at its default. fish applies the new
theme on the next prompt, helix on `SIGUSR1` (new helix windows pick it up
immediately), rofi on its next launch.

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
3. `npm install -g --prefix ~/.local` from `npm.txt` (npm's default prefix is
   the root-owned `/usr`), `uv tool install` from `uv-tools.txt`,
4. lays out symlinks per `symlinks.conf` — merge directories are expanded into
   real dirs with per-file links, volatile files are copied — backing up
   anything it replaces to `~/.dotfiles-backup-<timestamp>/`,
5. creates `~/.local/state/dotfiles/` and links `~/.config/helix/runtime` to it,
6. installs fisher + the plugins from `fish/fish_plugins` into `~/.config/fish`
   (after the links; skipped for `headless` and with `--no-fisher`),
7. applies the current darkman mode via `wayland/theme-sync`
   (`--no-packages` still performs steps 4–7).

The `headless` profile installs only the base set plus fish/opencode/editors
and their dependencies — no GUI, no Sway. Dev/DevOps tooling can be opted in
per host via `hosts/<host>/packages.txt`.

## VPN

The `ntech` OpenVPN/NetworkManager profile lives in the repo as a **secret-free
skeleton** (`vpn/ntech.nmconnection.in`). Certificates/keys stay in `~/vpn`, the
password stays in the keyring, and local login/endpoints come from the
gitignored `vpn/local.env`. See `vpn/README.md` for details.

```sh
cp vpn/local.env.example vpn/local.env   # then edit
./install/install_vpn.sh --check
./install/install_vpn.sh
```
