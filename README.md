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
  lib.sh             # shared helpers (host resolution, manifests)
  cleanup.sh         # removes packages that are not in the manifests
  install_vpn.sh     # VPN profile installer (ntech)
  hosts.conf         # hostname -> host dir + profile
  symlinks.conf      # src -> target map (+ gui/merge tags)
  volatile.conf      # runtime files copied into merge dirs, not linked
  protected.txt      # system packages cleanup.sh never removes
  cleanup-paths.conf # leftover config/state paths per package
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

Host-specific exceptions for cleanup live in `hosts/<host>/keep.txt` (see
**Cleanup** below).

`base` holds everything that must exist on **every** host, including the
headless one — that is why `docker`, `docker-buildx`, `docker-compose` and
`kubectl` live there: their dependency closure (79 packages, ~600 MiB) contains
no GUI libraries. Everything that pulls Chromium, GTK, Mesa or OpenCV stays in
`gui.txt`: `chromium` (used by the wrapper entries in `applications/`),
`mermaid-cli` (depends on `chromium`) and `ueberzugpp` (depends on
`opencv`/`ffmpeg`). Keeping those in `base` used to drag 163 extra packages
(~1.5 GiB) into a headless install.

Common configs live at the repo root; a host only ships the files it overrides.

Host override path mapping (used by the installer):

| target                | host file                          |
|-----------------------|------------------------------------|
| `~/.config/<x>`       | `hosts/<host>/config/<x>`          |
| `~/.local/share/<x>`  | `hosts/<host>/local-share/<x>`     |
| `~/<x>`               | `hosts/<host>/home/<x>`            |

If a host override exists, `~/.config/<x>` becomes a real directory whose
entries are symlinks into the repo (common first, host wins on conflicts).
Three entries carry the `merge` tag and are always laid out that way
(`~/.config/fish`, `~/.config/helix`, `~/.config/opencode`): applications must be
able to write next to the tracked files (fisher installs plugins, fish rewrites
`fish_variables`, helix may add runtime files, OpenCode runs `bun install` for
plugin dependencies in its config directory). Everything else is a single
symlink. Files listed in `install/volatile.conf` are copied into a merge
directory instead of being linked, so writes never reach the repo.

## Hosts

| host    | hostname | profile  | notes                          |
|---------|----------|----------|--------------------------------|
| desktop | adesk    | gui      | Sway/niri workstation          |
| ambb    | ambb     | gui      | laptop                         |
| alen    | alen     | gui      | laptop                         |
| work    | awdesk   | headless | SSH only, no GUI               |

## Compositors (sway / niri)

Both compositors are installed for the `gui` profile. On a TTY (tty1) fish
starts the compositor named in `~/.local/state/dotfiles/compositor` (`sway`,
`niri` or `none`). The value is written by the installer from the `compositor`
column of `install/hosts.conf`, and from then on `wm` owns it — so editing that
column does not move an already configured host. `none` means "no compositor"
and is forced for the `headless` profile. niri runs through `niri-session`:

```sh
wm niri    # switch for the next login
wm sway
wm none    # console-only: do not start a compositor on tty1
```

If the chosen compositor is not installed (or the state file holds garbage),
fish prints a message and leaves a working shell instead of ending the session.
The file is the single source of truth: the old `WAYLAND_COMPOSITOR` universal
variable is gone, and the installer erases it (plus its copy in the `systemd
--user` environment) when it finds one.

Layering mirrors the rest of the repo:

- `sway/config`            — shared sway config (`include`s the host `config.d/`).
- `niri/config.kdl`        — shared niri config, with `include "config.d/..."`.
- `hosts/<host>/config/{sway,niri}/config.d/` — per-host outputs/inputs.

Shared Wayland helpers (compositor-agnostic, detected at runtime) live in
`wayland/` (`theme-switch` lives in `applications/`, since it also works on
headless hosts):

- `compositor-env.sh` — sourceable helper that finds a **live** compositor
  socket. `darkman.service` outlives the compositor, so the `NIRI_SOCKET` /
  `SWAYSOCK` it passes on can point at a socket from a previous niri/sway run;
  the helper falls back to the newest `$XDG_RUNTIME_DIR/niri.wayland-*.sock` /
  `sway-ipc.*.sock` and validates it with a real IPC request, exporting the
  working value for child processes. `theme-sync` re-resolves on every switch,
  which is what makes wallpapers and Mattermost follow `darkman toggle` even
  after niri was restarted.
- `wallpapers.sh` — wallpaper via `awww` (falls back to `swaybg`) on every
  active output; picks only `*_dark.*` or `*_light.*` files to match the
  current theme (see `Runtime state`), and caches the halves of a panoramic
  picture in `~/Wallpapers/.slices/<layout>/` so they are reused instead of
  being re-sliced. Each change also pops a notification with the source file
  name (`WALLPAPER_NO_NOTIFY=1` silences it).
- `toggletouch.sh` — touchpad toggle (`niri msg action toggle-touchpad` or
  `swaymsg input ... events`).
- `mattermost-theme <mode>` — chat and window theme for Mattermost Desktop,
  called from `theme-sync` (see **Runtime state** below).
- `./applications/theme-switch [dark|light]` — manual theme switch; a wrapper
  over `theme-sync` (also works on headless, see **Runtime state**).

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

The repository is a **read-only configuration source**: no application writes
into it. Merge directories (`fish`, `helix`, `opencode`) give applications a
real directory to write next to the tracked files, so runtime state stays
outside the tree. Everything that changes at runtime lives in one fixed
directory:

```
~/.local/state/dotfiles/
  background-mode                      # "dark" or "light"
  alacritty.toml                       # [general] import of the palette
  rofi.rasi                            # @theme for rofi
  helix/runtime/themes/dotfiles.toml   # theme "dotfiles" (inherits gruvbox_*)
  ironbar/colors.css                   # @define-color palette
  ironbar/style.css                    # wrapper: colors.css + repo style.css
  mattermost.log                       # лог wayland/mattermost-theme (если есть)
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
- tells running Neovim to `set background=...` via `nvim-ctrl`;
- forces the theme of a running tmux server (`tmux set -s theme dark|light`),
  because alacritty answers `OSC 11` but does not implement `DECSET 2031`, so an
  attached client never learns about a runtime palette change on its own;
- re-runs `wayland/wallpapers.sh` in the background, so the wallpaper switches
  to a picture of the matching mode (`THEME_SYNC_NO_WALLPAPER=1` opts out).

**Mattermost.** `wayland/mattermost-theme <mode>` runs from the reload branch
of `theme-sync` when `~/.config/Mattermost/config.json` exists and there is a
live graphical session (a wayland or X11 socket — no compositor IPC needed,
since the app is only restarted into that session):

- the chat theme is **not** stored locally: it is a server-side user preference
  (category `theme`, value is the whole JSON of the preset, not its name), so
  the script writes `theme/{dark,light}/mattermost.json` — Onyx and Quartz from
  Mattermost v10.10.1 — through `PUT /api/v4/users/<id>/preferences` for every
  server listed in `config.json`. The session token and user id are read
  read-only from `~/.config/Mattermost/Cookies` and are never copied anywhere;
- the window chrome follows `darkMode` in `config.json` (Electron tab bar, tray
  icon, title-bar overlay), and `themeSyncing` is left alone: at its default
  `false` the desktop app keeps `nativeTheme.themeSource = "system"`, i.e. it
  follows the GTK colour scheme that `theme-sync` already sets above. Turning
  `themeSyncing` on instead makes the window take the server chat theme, which
  also works — the script does not overwrite that choice;
- `config.json` is only read at startup, and Electron rewrites it when it
  quits, so the order is `kill → API + config.json → start`. The app is
  restarted (`SIGTERM`, then `SIGKILL` after 5 s) only if it was running;
- network or session failures are logged to `~/.local/state/dotfiles/mattermost.log`
  and never break the switch. `MATTERMOST_THEME_NO_RESTART=1` writes the
  preference and the config without touching the processes,
  `THEME_SYNC_NO_MATTERMOST=1` skips the script from `theme-sync`, and
  `THEME_SYNC_NO_RELOAD=1` skips the whole reload branch (so `verify.sh` stays
  side-effect free). The app is restarted only when `background-mode` really
  changes, so `theme-sync` calls with the current mode are a no-op for it.

**Manual switch.** `theme-switch [dark|light]` (`applications/theme-switch`,
linked into `~/.local/bin`) is a thin wrapper over `theme-sync`; without an
argument it inverts the mode recorded in `background-mode`. It works on the
`headless` profile too: `theme-sync` writes the state files and skips the GUI
reloads on its own. It does **not** repaint a terminal emulator running on the
SSH client — the client's foreground/background palette is outside the server's
control; only the text colours that applications emit (fish syntax, helix, tmux)
follow the theme.

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
`fish/conf.d/theme.fish` applies the theme from `background-mode` on the prompt
(`fish/themes/dark.theme` / `light.theme`, gruvbox palettes with explicit hex
colours), so the old universal `background_mode` variable is gone and prompt
colours change without relying on the terminal's ANSI palette. `wm` writes
`~/.local/state/dotfiles/compositor` — the same file the installer seeds — and
no longer touches universal variables.

**Tmux.** `.tmux.conf` keeps both palettes inline as `dark-theme-*` /
`light-theme-*` (values taken from the gruvbox alacritty themes), and the styles
use the `theme*` names, so tmux recolours itself when the client theme changes.
This needs tmux >= 3.8 (`theme`, `theme*` and `client-light-theme` /
`client-dark-theme` hooks); older versions fall through `%if` to the previous
static Solarized palette. There is no state file and no `source-file`: `theme` is
a server option, and `theme-sync` only runs `tmux set -s theme <mode>` when a
server is already running. tmux does not detect the change by itself — alacritty
answers `OSC 11` but does not implement `DECSET 2031`, so the server has to be
told explicitly. Note that `theme` is server-wide, so every client attached to
the same server shares one mode.

**Waybar.** It does not take part in switching and stays in rollback mode with
its static palette. To bring it back, do the same thing: generate a wrapper in
the state dir, run `waybar -s <state>/waybar/style.css`, and `@import` the
palette.

**Checks.** `./install/verify.sh` validates that the state files match the
current mode, that the merge directories and symlinks are laid out correctly,
that there are no dangling links or legacy hooks, and that switching the theme
leaves `git status` unchanged (it is read-only and restores the current mode).
It also checks that `~/.local/bin/theme-switch` points into the repo and that
the legacy `background_mode` universal variable is not set.

**Limitations.** `XDG_STATE_HOME` must stay at its default. fish applies the new
theme on the next prompt, helix on `SIGUSR1` (new helix windows pick it up
immediately), rofi on its next launch, tmux on `theme-sync` (a running server is
updated in place, a server started later picks the mode up on attach).

## OpenCode / MCP

`opencode/` is a merge directory (like `fish/` and `helix/`): `opencode.jsonc`,
`cli.json`, `AGENTS.md`, `plugins/` and `sync-models.sh` are symlinks into the
repo, while what OpenCode writes next to its config — `package.json`,
`bun.lock`, `node_modules/`, `service.json` — stays a real local file and never
enters the working tree. The MCP servers are declared under `mcp.servers` in
`opencode/opencode.jsonc`:

| server     | transport | purpose                                                                   |
|------------|-----------|---------------------------------------------------------------------------|
| `vision`   | local     | `analyze_image` through any multimodal model (`mcp-vision-bridge`)        |
| `web-docs` | local     | API/library docs: `lib_docs`, `search_docs`, `fetch_url`, `web_search`, `list_docs` |
| `deepwiki` | remote    | `read_wiki_structure`, `read_wiki_contents`, `ask_wiki_question` for public GitHub repos |
| `docs`     | remote    | internal documentation MCP                                               |

`web-docs` is not published on npm, so the installer clones
[web-docs-mcp](https://github.com/Aleksandrr/web-docs-mcp) into
`~/.local/share/web-docs-mcp` (override with `WEB_DOCS_MCP_DIR` or
`LOCAL_PREFIX`), installs its runtime dependencies and patches one upstream bug:
its zod v3-era schema converter leaves every `enum` empty under zod v4, which
made `ecosystem`, `target` and `subdir` unusable (the patch only touches those
two files and is restored before `git pull`, then reapplied). Fetched markdown
goes to `~/.local/share/web-docs-mcp/docs`, the TTL cache to
`~/.cache/web-docs-mcp` — outside both the clone and the dotfiles repo, so
updates never touch saved docs and the configs stay read-only.

`deepwiki` is the official free remote server (`https://mcp.deepwiki.com/mcp`,
no authentication, `oauth: false`). It only accepts `owner/repo`; the
package-name → repository mapping comes from `web-docs` (`lib_docs` returns a
`repository` field).

The split is codified in `opencode/AGENTS.md`: `web-docs` for API facts,
`deepwiki` for architecture and deeper analysis, and only then the sources.

### Models per agent

`default_agent` is `plan` and the root `model` is
`routerai/~deepseek/deepseek-v4-pro-latest`, so a new session starts on the
plan model. `agents.plan` repeats that model, `agents.build` sets
`routerai/~deepseek/deepseek-v4-flash-latest#low`, and `agents.compaction` keeps
a cheap flash model.

V2 resolves a session's model once (the stored session model, else the catalog
default) and does not reconsult `agents.<id>.model` when the agent changes, so
plan → build alone leaves the old model in place. `opencode/plugins/agent-model-sync.ts`
closes that gap: on prompt admission, i.e. before model resolution, it switches
the session to the active agent's model when the agent changed or the session
has no model yet. A model picked by hand for the session survives until the next
agent switch. Plugin sources are cached by path, so after editing the file run
`opencode service restart` (a plain `opencode reload` can keep serving the old
build; renaming the file always forces a fresh one).

## Install

```sh
./install/install.sh                 # auto-detect host
./install/install.sh --host desktop  # explicit host
./install/install.sh --dry-run       # show actions only
./install/install.sh --no-packages   # only (re)link configs
./install/install.sh --no-links      # only install packages
./install/install.sh --no-shell      # keep the current login shell
./install/install.sh --no-nvim       # skip plugin/parser provisioning
```

The installer:
1. installs `yay` if missing,
2. `yay -S --needed` from `packages/base.txt` (+ `packages/dev.txt` unless
   profile is `headless`, + `packages/gui.txt` for GUI, + `hosts/<host>/packages.txt`),
3. `npm install -g --prefix ~/.local` from `npm.txt` (npm's default prefix is
   the root-owned `/usr`), `uv tool install` from `uv-tools.txt`, and clones
   `web-docs-mcp` into `~/.local/share/web-docs-mcp` with its runtime deps and
   the zod-4 enum patch (the `web-docs` MCP server; no npm package exists),
4. lays out symlinks per `symlinks.conf` — merge directories are expanded into
   real dirs with per-file links, volatile files are copied — backing up
   anything it replaces to `~/.dotfiles-backup-<timestamp>/`,
5. creates `~/.local/state/dotfiles/`, links `~/.config/helix/runtime` to it,
   and writes `compositor` (see [Compositors](#compositors-sway--niri)) —
   seeded once from an existing `WAYLAND_COMPOSITOR`, then owned by `wm`,
6. makes fish the login shell (`sudo chsh`; skip with `--no-shell`) — the whole
   GUI path starts from `fish/config.fish`, so a bash login leaves a black TTY,
7. installs fisher + the plugins from `fish/fish_plugins` into `~/.config/fish`
   (after the links; skipped for `headless` and with `--no-fisher`),
8. applies the current darkman mode via `wayland/theme-sync`
   (`--no-packages` still performs steps 4–8),
9. provisions Neovim plugins and treesitter parsers by running
   `nvim --headless` once (`NVIM_TS_INSTALL_SYNC=1`, so parsers are built
   during the install instead of the first interactive start; skip with
   `--no-nvim`). Plugins are not pacman packages: `vim.pack.add()` in
   `nvim/lua/plugins.lua` manages them, pinned by `nvim/nvim-pack-lock.json`.
   Git-ревью (хунки, stage, diff перед коммитом) — см. `nvim/README.md`.

The `headless` profile installs only the base set plus fish/opencode/editors
and their dependencies — no GUI, no Sway. Dev/DevOps tooling can be opted in
per host via `hosts/<host>/packages.txt`.

Installing a package does not start it: after a fresh install enable the Docker
daemon and add yourself to its group (relogin required):

```sh
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

## Cleanup (packages not in the manifests)

`install/cleanup.sh` is the counterpart of the installer: it removes packages
that are explicitly installed but absent from the manifests, and optionally
cleans up what they leave behind (configs, state, caches, services). It uses
the same `install/lib.sh` and the same host/profile resolution, so the
"install" and "keep" sets can never drift apart.

```sh
./install/cleanup.sh                     # dry-run: таблица кандидатов
./install/cleanup.sh --check             # exit 0 — drift-free, 2 — drift
./install/cleanup.sh --apply             # ask once, then remove
./install/cleanup.sh --apply --purge-configs --purge-caches
./install/cleanup.sh --apply --interactive   # ask per package
./install/cleanup.sh --init-keep         # draft hosts/<host>/keep.txt
```

The candidate set is `pacman -Qqe` minus:

1. **desired** — the manifests for the current host/profile (base, +dev unless
   `headless`, +gui, +host extras);
2. **protected** — `install/protected.txt`: kernel, bootloader, firmware, init,
   auth, network stack, `yay`. Nothing here is ever removed;
3. **keep** — `hosts/<host>/keep.txt` (personal applications) plus `--keep <pkg>`.
   The format is one name per line; everything after `#` is ignored, so the
   draft from `--init-keep` (`# pkg  # 12.8 MiB`) can be uncommented as is;
4. packages that something remaining depends on. This is evaluated to a fixed
   point over `pacman -Qi → Required By` (which includes provides-based
   dependencies, e.g. `fuse2 ← ntfs-3g`), then verified by pacman itself with
   `pacman -Rs --print`; anything it refuses is reported under "остаются в
   системе" with the reason.

`--apply` disables the removed packages' systemd units first (their unit files
vanish with the package), then runs one `pacman -Rns` transaction (falling back
to per-package removals), removes the dependencies that just became orphans
(`pacman -Qtdq`, disable with `--no-orphans`), and deletes dangling `*.wants`
symlinks.

Nothing is deleted outright. `--purge-configs` and `--purge-system` **move**
the leftover paths into a quarantine directory and never touch anything managed
by the dotfiles repo (symlinks into the repo, `symlinks.conf` targets, the state
dir) or shipped by a still-installed package (`pacman -Qo`). Paths come from
`install/cleanup-paths.conf` plus a heuristic that matches top-level
`~/.config`, `~/.local/share`, `~/.local/state`, `~/.cache` entries by package
name ignoring case and separators (`Code` ~ `code`). The heuristic backs off when
a directory could belong to a package that stays (`~/.config/Mattermost` is left
alone while only the `mattermost` server is removed but `mattermost-desktop`
stays).

The `--purge-*` flags take effect only together with `--apply`; in dry-run they
print what would move and how large it is. They work on the union of the current
candidate set and the `removed.txt` of **all** previous runs, so leftovers can be
purged after the packages are already gone — `cleanup.sh --apply --purge-configs`
is valid even when it reports "удалять нечего".

`--purge-caches` cleans package caches and rebuildable data (`paccache -r -k3`,
`yay -Sc`, journal → 500 MiB, npm/uv/pip caches, thumbnails, fontconfig,
`web-docs-mcp` cache); `--purge-modcache` additionally drops the Go module cache
and the Cargo registry cache (both re-download on next build); `--purge-tools`
removes npm globals, `uv tool`s and fisher plugins that are not listed in
`npm.txt`, `uv-tools.txt` and `fish/fish_plugins`.

Every applied run leaves `~/.local/state/dotfiles/cleanup/<timestamp>/` with
`removed.txt`, `orphans.txt`, `log.txt`, `report.md`, an executable
`restore.sh` (`yay -S --needed …`) and the quarantine itself:

```sh
~/.local/state/dotfiles/cleanup/20261017-180000/
  removed.txt  orphans.txt  log.txt  report.md  restore.sh
  quarantine/home/.config/Code/...      # moved, not deleted
  quarantine/root/var/lib/...           # --purge-system only
```

`restore.sh` is created only when the run actually removed packages; a
purge-only run leaves an empty `removed.txt` and reports «в этом прогоне
удаления не было».

`CLEANUP_CHECK=1 ./install/verify.sh` additionally reports package drift as a
warning (it is not fatal: a personal machine is expected to carry extra apps).

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
