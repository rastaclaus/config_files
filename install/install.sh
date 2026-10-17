#!/usr/bin/env bash
#
# Dotfiles installer: packages (yay / npm / uv), fish plugins and symlinks.
#
#   ./install/install.sh [options]
#
# Options:
#   --host <name>     host id: desktop|ambb|alen|work (default: auto by hostname)
#   --profile <p>     gui|headless (default: from install/hosts.conf)
#   --no-packages     skip package installation
#   --no-links        skip symlink setup
#   --no-fisher       skip fish plugin installation (fisher)
#   --dry-run         print what would happen, change nothing
#   -h, --help
#
# Runtime state (themes, fish universal vars, fisher plugins) is written to
# ~/.local/state/dotfiles and ~/.config/fish*, never into this repo.
#
set -euo pipefail

# Общие помощники (log/info/warn/die, read_list, resolve_host,
# collect_packages) и пути REPO/INSTALL_DIR/STATE_DIR/LOCAL_PREFIX.
# shellcheck source=install/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

HOST=""
PROFILE=""
DO_PACKAGES=1
DO_LINKS=1
DO_FISHER=1
DRY_RUN=0

run() {
  if [[ $DRY_RUN -eq 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}

usage() {
  sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)   HOST="${2:-}";    shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --no-packages) DO_PACKAGES=0; shift ;;
    --no-links)    DO_LINKS=0;    shift ;;
    --no-fisher)   DO_FISHER=0;   shift ;;
    --dry-run)     DRY_RUN=1;     shift ;;
    -h|--help)     usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

# ---------------------------------------------------------------- host resolve
resolve_host "$HOST" "$PROFILE"

log "host=$HOST profile=$PROFILE repo=$REPO"

# -------------------------------------------------------------------- packages
install_yay() {
  command -v yay >/dev/null 2>&1 && return 0
  command -v git >/dev/null 2>&1 || die "git is required to bootstrap yay"
  log "bootstrap: installing yay"
  local tmp; tmp="$(mktemp -d)"
  run git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  ( cd "$tmp/yay" && run makepkg -si --noconfirm )
  rm -rf "$tmp"
}

# rustup ships rustc/cargo only as shims: without a default toolchain every
# cargo invocation fails ("rustup could not choose a version of cargo to run").
# AUR packages that build with cargo (e.g. rofi-unicode) need one, so make sure
# a default toolchain exists before the AUR phase.
setup_rustup() {
  command -v rustup >/dev/null 2>&1 || return 0
  if rustup show active-toolchain >/dev/null 2>&1; then
    return 0
  fi
  log "rustup: no default toolchain; installing stable"
  run rustup default stable || warn "rustup: failed to set default stable toolchain"
}

# ttf-nerd-fonts-symbols ships its fontconfig rule disabled; symlink it into
# conf.d so Nerd Font glyphs become a fallback for any font family (JetBrains
# Mono, Roboto, ...) instead of leaving the font unused.
setup_nerd_font_symbols() {
  local src="/usr/share/fontconfig/conf.avail/10-nerd-font-symbols.conf"
  local dst="/etc/fonts/conf.d/10-nerd-font-symbols.conf"
  [[ -f "$src" ]] || return 0
  [[ -e "$dst" || -L "$dst" ]] && return 0
  log "enabling Nerd Font symbols fallback"
  run sudo ln -s "$src" "$dst" || warn "failed to enable Nerd Font symbols fallback"
}

# $LOCAL_PREFIX/bin is added to PATH by fish (fish_user_paths), not by this bash
# script, so checking $PATH alone reports a false negative. Consult fish too.
have_local_bin_in_path() {
  case ":$PATH:" in *":$LOCAL_PREFIX/bin:"*) return 0 ;; esac
  if command -v fish >/dev/null 2>&1; then
    fish -c 'contains -- $argv[1] $fish_user_paths' "$LOCAL_PREFIX/bin" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# web-docs-mcp (opencode MCP "web-docs") is not published on npm: it is cloned
# from GitHub and runs from the pre-built build/index.js. Dependencies still
# have to be installed, so this needs git + npm (both from the base packages).
# DOCS_DIR/CACHE_DIR point outside the clone so `git pull` never touches data.
install_web_docs_mcp() {
  local dst="$LOCAL_PREFIX/share/web-docs-mcp"
  local repo="https://github.com/Aleksandrr/web-docs-mcp"

  if command -v npm >/dev/null 2>&1 || [[ $DRY_RUN -eq 1 ]]; then
    :
  else
    warn "npm not found; skipping web-docs-mcp"
    return 0
  fi

  if [[ -d "$dst/.git" ]]; then
    log "updating web-docs-mcp -> $dst"
    # The local enum patch below makes those two files dirty; restore just them
    # before pulling (never the whole tree, so saved docs are untouched). A
    # failed pull (offline, diverged) is not fatal.
    run git -C "$dst" checkout -- build/lib/zod-to-json.js src/lib/zod-to-json.ts || true
    run git -C "$dst" pull --ff-only || warn "web-docs-mcp: git pull failed, keeping current checkout"
  elif [[ -e "$dst" ]]; then
    warn "$dst exists but is not a git checkout; skipping web-docs-mcp"
    return 0
  else
    log "cloning web-docs-mcp -> $dst"
    run mkdir -p "$(dirname "$dst")"
    run git clone --depth 1 "$repo" "$dst" || { warn "web-docs-mcp: clone failed"; return 0; }
  fi

  if [[ ! -d "$dst/node_modules" ]]; then
    log "installing web-docs-mcp dependencies"
    run npm install --prefix "$dst" --omit=dev --no-audit --no-fund ||
      warn "web-docs-mcp: npm install failed"
  fi

  # Upstream ships a hand-rolled zod->JSON-Schema converter written for zod 3
  # while pinning zod 4. z.enum() stores its options in `_def.entries`, so every
  # enum reaches tools/list as `"enum": []` and calls that pass `ecosystem`,
  # `target` or `subdir` are rejected as invalid arguments. Patch the shipped
  # build (what actually runs) and the source next to it, idempotently.
  if [[ $DRY_RUN -eq 0 ]]; then
    local conv_js="$dst/build/lib/zod-to-json.js"
    local conv_ts="$dst/src/lib/zod-to-json.ts"
    if [[ -f "$conv_js" ]] && ! grep -q '_def.*entries' "$conv_js"; then
      log "patching web-docs-mcp zod v4 enum handling"
      sed -i 's/def\._def?\.values/def._def \&\& def._def.entries ? Object.keys(def._def.entries) : def._def?.values/' "$conv_js" ||
        warn "web-docs-mcp: failed to patch $conv_js"
    fi
    if [[ -f "$conv_ts" ]] && ! grep -q '_def.*entries' "$conv_ts"; then
      sed -i 's/(def as any)\._def?\.values/(def as any)._def?.entries ? Object.keys((def as any)._def.entries) : (def as any)._def?.values/' "$conv_ts" ||
        warn "web-docs-mcp: failed to patch $conv_ts"
    fi
  fi

  run mkdir -p "$dst/docs"
  if [[ $DRY_RUN -eq 0 && ! -f "$dst/build/index.js" ]]; then
    warn "web-docs-mcp: $dst/build/index.js is missing; MCP server will not start"
  fi
}

if [[ $DO_PACKAGES -eq 1 ]]; then
  install_yay

  official=()
  aur=()
  collect_packages "$PROFILE" "$HOST_DIR" official aur

  if [[ ${#official[@]} -gt 0 ]]; then
    log "installing official packages (${#official[@]})"
    run yay -S --needed --noconfirm "${official[@]}"
  fi

  setup_rustup

  if [[ ${#aur[@]} -gt 0 ]]; then
    log "installing AUR packages (${#aur[@]})"
    run yay -S --needed --noconfirm "${aur[@]}"
  fi

  if [[ "$PROFILE" == "gui" ]]; then
    setup_nerd_font_symbols
  fi

  mapfile -t npms < <(read_list "$INSTALL_DIR/npm.txt")
  if [[ ${#npms[@]} -gt 0 ]]; then
    if command -v npm >/dev/null 2>&1 || [[ $DRY_RUN -eq 1 ]]; then
      log "installing npm globals (${#npms[@]}) -> $LOCAL_PREFIX"
      run npm install -g --prefix "$LOCAL_PREFIX" "${npms[@]}" || warn "npm install failed (check npm prefix/permissions)"
      if ! have_local_bin_in_path; then
        warn "$LOCAL_PREFIX/bin is not in PATH; npm global bins will not be found"
      fi
    else
      warn "npm not found; skipping npm globals"
    fi
  fi

  install_web_docs_mcp

  if command -v uv >/dev/null 2>&1 || [[ $DRY_RUN -eq 1 ]]; then
    while read -r tool; do
      [[ -z "$tool" ]] && continue
      log "uv tool install $tool"
      run uv tool install "$tool" || warn "uv tool install $tool failed"
    done < <(read_list "$INSTALL_DIR/uv-tools.txt")
  else
    warn "uv not found; skipping uv tools"
  fi
else
  log "skipping packages (--no-packages)"
fi

# ----------------------------------------------------------------------- links
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

backup_path() { # move an existing path out of the way
  local p="$1"
  local base dest; base="$(basename "$p")"; dest="$BACKUP/$base"
  local i=1
  while [[ -e "$dest" || -L "$dest" ]]; do dest="$BACKUP/${base}.$i"; i=$((i+1)); done
  # не создаём каталог бэкапов в --dry-run: там ничего не перемещается
  [[ $DRY_RUN -eq 1 ]] || mkdir -p "$BACKUP"
  run mv "$p" "$dest"
  if [[ $DRY_RUN -eq 1 ]]; then
    info "would back up $p -> $dest"
  else
    info "backed up $p -> $dest"
  fi
}

ensure_link() { # ensure_link <src> <target>
  local src="$1" target="$2"
  if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup_path "$target"
  fi
  run mkdir -p "$(dirname "$target")"
  run ln -s "$src" "$target"
  info "link $target -> $src"
}

host_source_for() { # map a target path to its host override dir/file
  local t="$1" rel
  rel="${t#"$HOME"/}"
  case "$rel" in
    .config/*)      printf '%s' "$HOST_DIR/config/${rel#.config/}" ;;
    .local/share/*) printf '%s' "$HOST_DIR/local-share/${rel#.local/share/}" ;;
    *)              printf '%s' "$HOST_DIR/home/$rel" ;;
  esac
}

is_volatile() { # is_volatile <path relative to $REPO>; читает install/volatile.conf
  local rel="$1" pat
  while IFS= read -r pat; do
    # shellcheck disable=SC2254 # глобы в volatile.conf — намеренно
    case "$rel" in $pat) return 0 ;; esac
  done < <(read_list "$INSTALL_DIR/volatile.conf")
  return 1
}

copy_volatile() { # copy_volatile <repo-file> <target>; локальную копию не трогаем
  local src="$1" target="$2" link
  if [[ -f "$target" && ! -L "$target" ]]; then
    return 0
  fi
  if [[ -L "$target" ]]; then
    link="$(readlink "$target")"
    case "$link" in
      "$REPO"/*) run rm -f "$target" ;;   # старый симлинк в репозиторий
      *)         backup_path "$target" ;;
    esac
  elif [[ -e "$target" ]]; then
    backup_path "$target"
  fi
  run mkdir -p "$(dirname "$target")"
  run cp -a "$src" "$target"
  info "copied $target (volatile)"
}

merge_dir() { # merge_dir <common-dir> <host-dir> <target-dir> [repo-relative-prefix]
  local common="$1" host="$2" target="$3" rel="${4:-}"
  # target must be a real directory
  if [[ -L "$target" ]]; then backup_path "$target"; run rm -f "$target"; fi
  if [[ -e "$target" && ! -d "$target" ]]; then backup_path "$target"; run rm -f "$target"; fi
  run mkdir -p "$target"

  local names name c h child_rel
  names="$( { ls -A "$common" 2>/dev/null || true; ls -A "$host" 2>/dev/null || true; } | sort -u )"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    c="$common/$name"; h="$host/$name"
    child_rel="${rel:+$rel/}$name"
    if [[ -e "$h" || -L "$h" ]]; then
      if [[ -d "$h" ]]; then
        merge_dir "$([[ -d "$c" ]] && printf '%s' "$c" || printf '/nonexistent')" "$h" "$target/$name" "$child_rel"
      else
        ensure_link "$h" "$target/$name"
      fi
    elif [[ -d "$c" ]]; then
      # каталог без host-override тоже раскрываем в реальный каталог:
      # приложения (fish/fisher, helix) пишут рядом, а файлы остаются ссылками.
      merge_dir "$c" "/nonexistent" "$target/$name" "$child_rel"
    elif is_volatile "$child_rel"; then
      copy_volatile "$c" "$target/$name"
    else
      ensure_link "$c" "$target/$name"
    fi
  done <<< "$names"

  # prune links whose repo source no longer exists (removed/renamed files)
  local entry
  for entry in "$target"/*; do
    if [[ -L "$entry" && ! -e "$entry" ]]; then
      run rm -f "$entry"
      info "pruned stale link $entry"
    fi
  done
}

cleanup_legacy_hooks() { # старые хуки darkman: только симлинки внутрь $REPO
  local d link
  for d in "$HOME/.local/share/dark-mode.d" "$HOME/.local/share/light-mode.d"; do
    if [[ -L "$d" ]]; then
      link="$(readlink -f "$d" 2>/dev/null || true)"
      case "$link" in
        "$REPO"/*) run rm -f "$d"; info "removed legacy hook $d" ;;
        *) warn "legacy hook $d points outside the repo ($link); left in place" ;;
      esac
    elif [[ -e "$d" ]]; then
      warn "legacy hook dir $d is not a symlink; left in place, check manually"
    fi
  done
}

if [[ $DO_LINKS -eq 1 ]]; then
  log "setting up symlinks"
  while read -r src target tags _; do
    [[ -z "$src" || "$src" == \#* ]] && continue
    taglist=" $tags "
    if [[ "$taglist" == *" gui "* && "$PROFILE" != "gui" ]]; then
      continue
    fi
    src_abs="$REPO/$src"
    target_abs="${target/#\~/$HOME}"
    host_src="$(host_source_for "$target_abs")"
    if [[ -d "$host_src" || "$taglist" == *" merge "* ]]; then
      [[ -d "$src_abs" ]] || { warn "missing source dir: $src"; continue; }
      info "merging $target_abs"
      merge_dir "$src_abs" "$host_src" "$target_abs" "$src"
    elif [[ -f "$host_src" || -L "$host_src" ]]; then
      ensure_link "$host_src" "$target_abs"
    else
      [[ -e "$src_abs" ]] || { warn "missing source: $src"; continue; }
      ensure_link "$src_abs" "$target_abs"
    fi
  done < "$INSTALL_DIR/symlinks.conf"

  # Тема и helix-тема живут в state; see wayland/theme-sync.
  log "preparing runtime state in $STATE_DIR"
  run mkdir -p "$STATE_DIR/alacritty" "$STATE_DIR/helix/runtime/themes" "$STATE_DIR/ironbar"
  ensure_link "$STATE_DIR/helix/runtime" "$HOME/.config/helix/runtime"

  cleanup_legacy_hooks
else
  log "skipping symlinks (--no-links)"
fi

# ------------------------------------------------------------- fish plugins
# Fisher пишет в ~/.config/fish, поэтому запускается после раскладки merge-
# каталога: плагины ставятся в реальный каталог, а не в репозиторий.
install_fisher() {
  if ! command -v fish >/dev/null 2>&1 && [[ $DRY_RUN -eq 0 ]]; then
    warn "fish not found; skipping fisher"
    return 0
  fi
  if ! fish -c 'type -q fisher' 2>/dev/null; then
    log "installing fisher"
    run fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher' || warn "failed to install fisher"
  fi
  while read -r plugin; do
    [[ -z "$plugin" ]] && continue
    log "fisher install $plugin"
    run fish -c "fisher install $plugin" || warn "fisher install $plugin failed"
  done < <(read_list "$REPO/fish/fish_plugins")
}

# -------------------------------------------------------------------- theme
# Тема применяется после ссылок: theme-sync пишет state-файлы и (в gui)
# перезагружает приложения. Режим берём у darkman, иначе из state.
if [[ $DO_LINKS -eq 1 ]]; then
  mode="$(darkman get 2>/dev/null || true)"
  case "$mode" in
    dark|light) ;;
    *) mode="$(cat "$STATE_DIR/background-mode" 2>/dev/null || true)" ;;
  esac
  case "$mode" in
    dark|light) ;;
    *) mode=light ;;
  esac
  if [[ "$PROFILE" == "gui" ]]; then
    log "applying theme: $mode"
    run "$REPO/wayland/theme-sync" "$mode"
  else
    log "writing theme files: $mode (headless profile, no reload)"
    run env THEME_SYNC_NO_RELOAD=1 "$REPO/wayland/theme-sync" "$mode"
  fi
fi

if [[ $DO_LINKS -eq 1 && $DO_FISHER -eq 1 ]]; then
  if [[ "$PROFILE" == "headless" ]]; then
    log "skipping fish plugins (headless profile)"
  else
    install_fisher
  fi
elif [[ $DO_FISHER -eq 0 ]]; then
  log "skipping fish plugins (--no-fisher)"
fi

if [[ -d "$BACKUP" ]]; then
  log "backups saved in $BACKUP"
fi
log "done."
