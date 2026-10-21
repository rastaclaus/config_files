# config_files

Personal dotfiles. One branch, host-specific bits under `hosts/`.

> Русский перевод: [`README.ru.md`](README.ru.md). При расхождении верен этот
> файл — перевод может отставать.

## Layout

```
fish/ helix/ nvim/ opencode/ direnv/ ghostty/ alacritty/ rofi/ darkman/
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
and runs `wayland/theme-sync`, which rewrites the runtime state and then runs
one script per application from `wayland/theme-hooks.d/` (see
`Runtime state` below). Qt apps follow the GTK theme
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
keys). `Mod`+`Return` starts **ghostty**, `Mod`+`Shift`+`Return` — alacritty,
which stays installed as a fallback terminal. sway-only features that niri has no equivalent for (splits, stacking,
focus-parent, scratchpad, a resize mode) stay in `sway/config`.

## Ghostty

Primary terminal (`Mod`+`Return`); alacritty stays on `Mod`+`Shift`+`Return` as
a fallback. `~/.config/ghostty` is a symlink to `ghostty/`, the config is
`config.ghostty`, the palettes are `ghostty/themes/gruvbox-{dark,light}`.
Theming, font, opacity and the ghostty↔alacritty parity checks are described in
**Runtime state** below — this section is about using the terminal.

Known-good version: **1.3.1**. Options and actions are version-specific: check
`ghostty +list-actions` / `ghostty +show-config --docs` before trusting a snippet
from the internet.

### What it has that alacritty does not

| feature                | notes                                                                |
|------------------------|----------------------------------------------------------------------|
| key tables             | modal input — this is what replaces alacritty's vi mode (below)      |
| shell integration      | OSC 133/1337 marks: prompt jumping, correct `cwd` for new tabs/splits |
| kitty keyboard protocol| apps (helix, neovim) can ask for physical keys, release events, …    |
| command palette        | `ctrl+shift+p`, fuzzy search over every action                       |
| inspector              | `ctrl+shift+i` — a TUI dump of the terminal state, screen contents included |
| built-in search        | `ctrl+shift+f` over the terminal's own screen + scrollback           |
| `reload_config`        | `ctrl+shift+,` — most options apply without restarting               |
| tabs and splits        | rendered inside one window; the compositor still sees a single tile  |

Missing on purpose / by design: no vi cursor over the scrollback (see
**Scrollback**), no Russian keyboard mappings yet (the alacritty table was not
ported; kitty-protocol apps like helix are fine because they receive physical
keys, fish/readline are not).

### Default keys worth knowing

Every binding is listed by `ghostty +list-keybinds` (`--default` for the stock
set, `--docs` with descriptions).

| keys                          | action                                            |
|-------------------------------|---------------------------------------------------|
| `ctrl+shift+c` / `ctrl+shift+v` | copy selection (as `mixed`) / paste CLIPBOARD   |
| `ctrl+insert` / `shift+insert`  | copy selection (as `mixed`) / paste PRIMARY     |
| `ctrl+shift+a`                | select all                                        |
| `ctrl+shift+y`                | **ours**: select all + copy as `plain`            |
| `ctrl+alt+o`                  | **ours**: whole scrollback → file → nvim in a new window (see **Dumping the scrollback**) |
| `ctrl+alt+shift+j`            | visible screen → file → nvim in a new window (stock binding) |
| `ctrl+shift+space`            | **ours**: enter `scroll-mode` (see below)         |
| `shift+page_up` / `shift+page_down` | scroll one page                             |
| `shift+home` / `shift+end`    | scroll to top / bottom                            |
| `ctrl+shift+page_up/down`     | jump to previous / next prompt (needs shell integration) |
| `ctrl+shift+f`, then `escape` | search, end search                                |
| `ctrl+=` / `ctrl+-` / `ctrl+0`| font size +1 / −1 / reset                         |
| `ctrl+shift+t` `ctrl+shift+n` | new tab / new window                              |
| `ctrl+shift+o` `ctrl+shift+e` | split right / split down                          |
| `ctrl+alt+arrows`             | move focus between splits                         |
| `ctrl+shift+w` `ctrl+shift+q` | close tab / quit ghostty                          |
| `ctrl+,` / `ctrl+shift+,`     | open config / reload config                       |

`ctrl+shift+space` for `scroll-mode` is not a coincidence: it is alacritty's
default `ToggleViMode` trigger, so muscle memory carries over between the two
terminals.

Minimal cheat sheet:

```text
select with mouse          → shift+insert (PRIMARY) | ctrl+shift+c → ctrl+shift+v (CLIPBOARD)
whole scrollback → clip    → ctrl+shift+space, y
whole scrollback → nvim    → ctrl+alt+o  (new ghostty window; inside a TUI — no, see below)
whole scrollback → file    → ctrl+shift+space, w  (path in clipboard → nvim ctrl+shift+v)
visible screen → nvim      → ctrl+alt+shift+j
scroll without mouse       → ctrl+shift+space, then j/k, ctrl+d/ctrl+u, g/shift+g
search                     → ctrl+shift+f  (inside scroll-mode: /, n, shift+n)
scrolling inside tmux      → prefix [  (vi keys), y/Enter copy
whole pane history in nvim → prefix e
```

### Scrollback

`scrollback-limit` is measured in **bytes**, not lines (the active screen
counts too, memory is allocated lazily, and the limit is per surface):
`20_000_000` was measured on 1.3.1 in a 1280 px wide window (~150 columns) at
~10 700 lines — roughly alacritty's `scrolling.history = 10000`. In a narrower
window more lines fit, in a wider one fewer. Scrollback is memory only: it does
not survive a restart of ghostty, and it is not written anywhere.

Reading it without a mouse — `ctrl+shift+space` enters a `scroll-mode` key table
(key tables are a 1.3 feature; there is no vi cursor, so this is scrolling, not
editing):

| key                | action                                                  |
|--------------------|---------------------------------------------------------|
| `j` / `k`          | one line down / up                                      |
| `ctrl+d` / `ctrl+u`| half a page                                             |
| `space`, `ctrl+f` / `ctrl+b` | one page                                      |
| `g` / `shift+g`    | top / bottom                                            |
| `]` / `[`          | next / previous prompt mark (`jump_to_prompt`)          |
| `/`, `n` / `shift+n` | open search, next / previous hit                      |
| `y`                | whole scrollback → clipboard as plain text              |
| `w`                | whole scrollback → file, **path** → clipboard           |
| `q`, `escape`      | leave the mode                                          |

Four things that are easy to get wrong when editing that table:

* `activate_key_table`, **not** `activate_key_table_once` — a one-shot table is
  deactivated by the first binding that fires, so `j` would scroll exactly once.
* `catch_all=ignore` is mandatory: lookup walks from the innermost table
  outward, so without it every unbound key leaks to the shell (and to a running
  TUI) instead of being swallowed by the mode.
* Uppercase letters collide under ghostty's case folding: `g` and `G` are the
  same trigger, so it must be `shift+g` (same for `shift+n`).
* Every table binding needs its own `keybind = ` prefix (a bare
  `scroll-mode/j=...` line is rejected as an unknown field), and `[` must be
  written as `scroll-mode/[=<action>`: the table parser looks for `/` before the
  first `=`, so `scroll-mode/[/jump_to_prompt:-1` is parsed as table
  `scroll-mode` with the malformed key `[/jump_to_prompt:-1`.

`jump_to_prompt` needs the OSC 133 marks from `shell-integration` (fish
integration provides them).

### Selection and copying

* Mouse selection behaves like alacritty: `copy-on-select` defaults to
  `primary` on Linux, i.e. the selection lands in **PRIMARY**, not in CLIPBOARD.
  Paste it with `shift+insert` (or middle click); `ctrl+shift+v` pastes
  CLIPBOARD instead.
* `ctrl+shift+c` puts the selection into CLIPBOARD as `mixed` (plain text +
  `text/html`); `ctrl+shift+y` and `scroll-mode/y` use `plain` on purpose —
  `mixed` would build megabytes of HTML for a whole history dump.
* The selection stays visible after copying (`selection-clear-on-copy = false`,
  the default) but is dropped as soon as you type
  (`selection-clear-on-typing = true`). To clear it manually: `escape` or a
  single click.
* There is **no keyboard action that starts a range selection**: `adjust_selection`
  (default: `shift+arrows`) only moves an already existing selection and does
  nothing without one, so `shift+arrows` on a fresh screen is a no-op. The only
  keyboard-made selection is `ctrl+shift+a` / `ctrl+shift+y` (everything); after
  that `shift+arrows` can still adjust it. For a specific range use tmux's
  copy-mode below.
* Selection colours are pinned in the theme files (dark `#3c3836`, light
  `#d5c4a1`) instead of ghostty's default cell inversion, which on the dark
  theme produced a highlight as bright as the light theme's background. The
  cursor keeps the default inversion, exactly as in alacritty. `verify.sh`
  compares both values against `[colors.selection]` in the alacritty themes.

### Dumping the scrollback

* `ctrl+shift+space`, then `y` — the **whole** scrollback to the clipboard. In
  1.3.1 `select_all` takes history, not just the visible screen (measured: 400
  lines of output → 399 newlines copied), even though the action reference
  words it as "text on the screen".
* `ctrl+shift+space`, then `w` — ghostty writes the scrollback as plain text
  (long lines unwrapped) into `/tmp/<random>/history.txt` and copies **that
  path** to the clipboard; then in nvim: `:e ` + `ctrl+shift+v`.
  `write_scrollback_file` has three modes: `copy` (used here), `paste` (types
  the path into the prompt) and `open`, which hands the path to `xdg-open` — see
  the next bullet. A `chain=text:nvim ` + `paste` shortcut is impossible: the
  config trims trailing whitespace, so `text:nvim ` arrives as `nvim` (checked
  with `od -c`).
* `ctrl+alt+o` — the **whole scrollback into nvim with one key**:
  `write_scrollback_file:open` → `xdg-open <path>` → the
  `~/.local/bin/xdg-open` shim (`applications/xdg-open`) → `ghostty +new-window
  -e nvim <path>`. A new window of the same ghostty instance (D-Bus) opens, with
  the same theme and config; `:q` returns to the terminal. The shim is the only
  way to start a process from a keybind: ghostty has no `spawn`/`exec` action,
  `new_split` takes only a direction and `new_window` takes nothing, so a
  "split with the editor" from a keybind is impossible (manually: `w` →
  `ctrl+shift+o` → `nvim ` + `ctrl+shift+v`). Why a shim instead of XDG:
  `text/plain` in `mimeapps.list` is bound to Helix, and there is no reason to
  change that association globally just for dumps — the shim intercepts exactly
  `$TMPDIR/<22-char base64url>/{history,screen,selection}.txt` and delegates
  everything else to `/usr/bin/xdg-open`.
* Only the visible screen: `ctrl+shift+j` (`write_screen_file:paste,plain`),
  `ctrl+alt+shift+j` opens it in nvim through the same shim,
  `super+ctrl+shift+j` copies the path.
* **Inside a full-screen TUI (opencode, htop, vim, less) there is no "full
  scrollback" at all**: the app runs on the alternate screen and repaints a
  single grid, so no history exists — neither in ghostty nor in tmux. For
  `loc=history` ghostty returns null on the alternate screen: no file is
  created, `xdg-open` is never called, and `ctrl+alt+o` / `w` silently do
  nothing. What does work: `ctrl+alt+shift+j` (visible screen) and the app's own
  means — `prefix e` in tmux, `/export` (`ctrl+x x`) and `ctrl+z`
  (`terminal_suspend`) in opencode.

### Ghostty + tmux

Why tmux on top: a tmux server keeps its own scrollback per pane and survives
the terminal window (detach/reattach, an SSH drop). What matters for the
terminal is that **tmux repaints the screen**, so ghostty's viewport holds only
what tmux drew — ghostty's scrollback is nearly empty inside tmux, and `j`/`k`
in `scroll-mode` or `shift+page_up` scroll almost nothing. Inside tmux:

| goal                   | how                                                     |
|------------------------|---------------------------------------------------------|
| scroll a pane          | `prefix [` — copy-mode, vi keys (`setw -g mode-keys vi`) |
| search pane history    | in copy-mode: `/` down, `?` up, `n` / `N` next/prev hit  |
| copy a range           | in copy-mode: `space` starts, `v` block mode, `y`/`Enter` copy and leave |
| copy to the system clipboard | the same — the binding pipes through `wl-copy`, so it does not need the terminal's OSC 52 support |
| whole pane history in nvim | `prefix e` (for alt-screen apps only the visible screen, see below) |
| new shell, same dir    | `prefix v` (side by side), `prefix w` (new window)       |

Note that `prefix v` is bound to `split-window -h` — a vertical divider, panes
side by side; stock tmux uses `%` and `"` for that, and both are unbound here.
`prefix h` looks like the horizontal counterpart but is **not**: it appears twice
in `.tmux.conf`, first as `split-window -v` and then as `select-pane -L`, and the
later binding wins, so `prefix h` is pane navigation. Use `prefix v` twice for a
second split, or add a distinct key (e.g. `|` and `-`) if a horizontal split is
needed.

`prefix e` is the counterpart of ghostty's `w`: it runs
`capture-pane -S -20000 -J` (the whole `history-limit`, `-J` joins wrapped
lines so the file has no mangled long lines), saves it to
`/tmp/tmux-scroll.txt` and opens it in a 90%×90% `display-popup` running
`nvim /tmp/tmux-scroll.txt`. The file is overwritten on every use, so nothing
accumulates. Alt-screen caveat: for a full-screen TUI (opencode, htop, vim) the
pane keeps only the visible grid, so "the whole history" is the main-screen
history plus the current screen; check it: `less README.md` in a pane →
`prefix e` yields ~24 lines, not 600+.

Other tmux settings that interact with the terminal: `history-limit 20000`
(matches ghostty's perspective), `set-clipboard on` (forwards OSC 52 from
applications), `escape-time 0`, `terminal-overrides alacritty:Tc` for the
fallback terminal (ghostty is truecolor-capable without an override). The tmux
palette follows the desktop theme — see **Tmux** below.

### CLI

Useful diagnostics:

```sh
ghostty +validate-config          # must be a *global* flag: --config-file=... first
ghostty +show-config --docs       # current values with the manual inline
ghostty +list-actions             # every action, with argument syntax
ghostty +list-keybinds --default --docs
ghostty +list-themes              # built-in theme names
ghostty +list-fonts
```

`+validate-config` silently returns 1 if the file is passed after the action
(`ghostty +validate-config --config-file=…` returns 1 with no diagnostics), so
always write `ghostty --config-file=… +validate-config`. It catches typos and
wrong value types (`…/b.conf:1:totally-bogus-option: unknown field`, exit 1),
so run it after every config edit — the same check `install/verify.sh` does.

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
  theme-hooks.log                      # вывод хуков + коды возврата
```

The path is hard-coded (not `$XDG_STATE_HOME`): alacritty and rofi do not expand
environment variables in `import`/`?import` paths.

**Switching.** darkman calls `~/.local/share/darkman/theme` with `dark|light`;
the hook shows a notification and runs `wayland/theme-sync <mode>`. `theme-sync`
only writes the state files above and dispatches hooks — it knows nothing about
individual applications. Each hook in `wayland/theme-hooks.d/` is called as

```
<NN>-<app>.sh <dark|light>
```

with `THEME_STATE`, `THEME_HOOK_LOG`, `THEME_PREV_MODE` and `THEME_GUI` in the
environment, under `timeout 15`. A hook decides on its own whether it applies
(application not installed or not running → `exit 0`, which is not an error),
never writes into the repo, and its failure is only logged to
`~/.local/state/dotfiles/theme-hooks.log` — it cannot break the switch. Adding an application means dropping a new file into that directory;
`theme-sync` stays untouched.

| hook               | what it does                                                        |
|--------------------|---------------------------------------------------------------------|
| `10-gtk.sh`        | `gsettings`: `adw-gtk3(-dark)` + `color-scheme` (the signal every libadwaita app follows) |
| `20-ghostty.sh`    | `SIGUSR2` to a running ghostty (config re-read; colours apply live)  |
| `25-alacritty.sh`  | `alacritty msg config` for palette + opacity (fallback terminal)     |
| `30-helix.sh`      | `SIGUSR1` (helix reloads config and theme)                           |
| `40-tmux.sh`       | `tmux set -s theme` for a running server + status-line refresh       |
| `50-fish.sh`       | `SIGWINCH` to fish, so the drawn prompt is repainted immediately      |
| `60-redraw.sh`     | `SIGWINCH` to ANSI-coloured TUIs (`htop`, `less`, `ncdu`; extend with `DOTFILES_THEME_REDRAW`) |
| `90-mattermost.sh` | Mattermost restart, only when `THEME_PREV_MODE` really differs        |

The shared helpers live in `wayland/theme-hook-lib.sh` (`theme_have`,
`theme_running`, `theme_gui`, `theme_log`, `theme_state_dir`). Neovim has no
hook on purpose: it watches the state file itself (see **Neovim** below).

After the hooks, `theme-sync` re-runs `wayland/wallpapers.sh` in the background,
so the wallpaper switches to a picture of the matching mode
(`THEME_SYNC_NO_WALLPAPER=1` opts out).

**Mattermost.** `wayland/theme-hooks.d/90-mattermost.sh` calls
`wayland/mattermost-theme <mode>` when `~/.config/Mattermost/config.json` exists
and there is a live graphical session (a wayland or X11 socket — no compositor
IPC needed, since the app is only restarted into that session). The hook is a
no-op unless `THEME_PREV_MODE` differs from the new mode, so `verify.sh` and a
repeated `theme-sync` with the current mode never restart the app:

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
  `THEME_SYNC_NO_MATTERMOST=1` skips the hook, and `THEME_SYNC_NO_RELOAD=1`
  skips state reloads and every hook (so `verify.sh` stays side-effect free).

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

**Ghostty.** Only theming is covered here — fonts, key bindings, scrollback,
selection and the tmux workflow are in the **Ghostty** section above.
`~/.config/ghostty` is a symlink to `ghostty/`, the config is `config.ghostty`
(the legacy `config` file must not exist: ghostty would load both and warn), and
the palettes are `ghostty/themes/gruvbox-{dark,light}` — plain config snippets,
the same gruvbox hex values as `alacritty/themes/themes/` (checked by
`verify.sh`).

Theme names are file names **without** an extension: ghostty looks up exactly
`$XDG_CONFIG_HOME/ghostty/themes/<name>`, so the files are
`ghostty/themes/gruvbox-dark` and `gruvbox-light` (a `.conf` suffix is silently
not found).

The config uses `theme = light:gruvbox-light,dark:gruvbox-dark`: ghostty picks
the file itself and follows `gsettings ... color-scheme` through libadwaita,
reloading on the scheme change — verified on 1.3.1, the background changes
without any hook. `20-ghostty.sh` (`SIGUSR2`) is needed for edited palette files
and as a safety net if libadwaita does not see the scheme.

Font, padding and transparency are matched to alacritty on purpose, so the two
terminals look identical: alacritty sets no font family, so it gets fontconfig's
`monospace` (on this machine `Noto Sans Mono`, size 11.25 by default) —
`font-family = Noto Sans Mono` with `JetBrains Mono` as a fallback and
`font-size = 11.25`; `window-padding-x/y = 0` because alacritty's
`window.padding` defaults to `{0,0}` while ghostty's default is 2;
`background-opacity-cells = true` because alacritty fades the whole window
through the compositor, whereas ghostty by default fades only cells without an
explicit background.

Selection colours are pinned in the theme files instead of relying on ghostty's
default cell inversion (dark `bg1` `#3c3836`, light `bg2` `#d5c4a1`; rationale in
**Ghostty → Selection and copying**), while `cursor-*` stays unset so the cursor
keeps the default inversion, exactly like alacritty. `verify.sh` checks both
selection hex values against `[colors.selection]` in the alacritty themes, so
the fallback terminal matches.

**Neovim.** `nvim/lua/theme.lua` watches `~/.local/state/dotfiles` with
`vim.uv.new_fs_event` (80 ms debounce, `new_fs_poll` fallback), so already
running editors switch without any external binary or RPC socket — the old
`nvim-ctrl` branch in `theme-sync` never worked, the binary was not installed
anywhere. On change it sets `vim.o.background` and re-runs `:colorscheme`:
gruvbox.nvim reads `background` only in `load()` and does not listen to
`OptionSet`.

**Fish.** `fish_variables` and the fisher plugins are local to `~/.config/fish`
and not in git; the declarative plugin list stays in `fish/fish_plugins`.
`fish/conf.d/theme.fish` applies the theme from `background-mode` on the prompt
(`fish/themes/dark.theme` / `light.theme`, gruvbox palettes with explicit hex
colours), so the old universal `background_mode` variable is gone and prompt
colours change without relying on the terminal's ANSI palette. `wm` writes
`~/.local/state/dotfiles/compositor` — the same file the installer seeds — and
no longer touches universal variables. `theme.fish` also sets
`fish_handle_reflow 1`: without it fish 4.x ignores `SIGWINCH` in terminals that
reflow text, and the already drawn prompt would keep the old theme until the
next `Enter`. The price is a prompt repaint on every window resize.

**Tmux.** `.tmux.conf` keeps both palettes inline as `dark-theme-*` /
`light-theme-*` (values taken from the gruvbox alacritty themes), and the styles
use the `theme*` names, so tmux recolours itself when the client theme changes.
This needs tmux >= 3.8 (`theme`, `theme*` and `client-light-theme` /
`client-dark-theme` hooks); older versions fall through `%if` to the previous
static Solarized palette. There is no state file and no `source-file`: `theme` is
a server option, and `40-tmux.sh` only runs `tmux set -s theme <mode>` when a
server is already running. tmux does not detect the change by itself — alacritty
answers `OSC 11` but does not implement `DECSET 2031`, so the server has to be
told explicitly (ghostty does implement 2031, but the hook is harmless
there). Note that `theme` is server-wide, so every client attached to the same
server shares one mode.

**Waybar.** It does not take part in switching and stays in rollback mode with
its static palette. To bring it back, do the same thing: generate a wrapper in
the state dir, run `waybar -s <state>/waybar/style.css`, and `@import` the
palette.

**Checks.** `./install/verify.sh` validates that the state files match the
current mode, that the merge directories and symlinks are laid out correctly,
that there are no dangling links or legacy hooks, and that switching the theme
leaves `git status` unchanged (it is read-only and restores the current mode).
It also checks that `~/.local/bin/theme-switch` points into the repo, that the
legacy `background_mode` universal variable is not set, that every file in
`wayland/theme-hooks.d/` is executable and syntactically valid, that the ghostty
theme files exist and their palettes still match the alacritty ones, and that
the hooks of the final switch all exited 0.

**Limitations.** `XDG_STATE_HOME` must stay at its default. fish repaints via
`SIGWINCH`, helix reloads on `SIGUSR1` (new helix windows pick it up
immediately), neovim via its own watcher, ghostty via `SIGUSR2` (already open
windows are repainted), rofi on its next launch, tmux on `theme-sync` (a running
server is updated in place, a server started later picks the mode up on
attach).

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
   Git-ревью (хуки, stage, diff перед коммитом) — см. `nvim/README.md`.

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
