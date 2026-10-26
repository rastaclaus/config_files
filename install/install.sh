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
#   --no-shell        do not change the login shell to fish
#   --no-nvim         skip Neovim plugin/parser provisioning
#   --dry-run         print what would happen, change nothing
#   -h, --help
#
# OpenCode настраивает отдельный скрипт: install/install_opencode.sh.
#
# Runtime state (themes, fish universal vars) is written to
# ~/.local/state/dotfiles and ~/.config/fish*, never into this repo.
#
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

HOST=""
PROFILE=""
DO_PACKAGES=1
DO_LINKS=1
DO_SHELL=1
DO_NVIM=1
DRY_RUN=0

usage() {
  sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)   HOST="${2:-}";    shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --no-packages) DO_PACKAGES=0; shift ;;
    --no-links)    DO_LINKS=0;    shift ;;
    --no-shell)    DO_SHELL=0;    shift ;;
    --no-nvim)     DO_NVIM=0;     shift ;;
    --submodules)  die "--submodules is gone: ocbox lives in its own repository with its own installer" ;;
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

  # В --dry-run ничего не клонируем и не собираем: run() только печатает
  # команды, поэтому следующий `cd` уходил в несуществующий каталог, а set -e
  # завершал весь прогон — ровно на той чистой машине, где dry-run и нужен.
  if [[ $DRY_RUN -eq 1 ]]; then
    log "bootstrap: installing yay (dry-run)"
    info "[dry-run] git clone https://aur.archlinux.org/yay.git <tmp>/yay"
    info "[dry-run] (cd <tmp>/yay && makepkg -si --noconfirm)"
    return 0
  fi

  command -v git     >/dev/null 2>&1 || die "git is required to bootstrap yay"
  command -v makepkg >/dev/null 2>&1 || die "makepkg is required to bootstrap yay (install base-devel)"

  log "bootstrap: installing yay"
  local tmp; tmp="$(mktemp -d)"
  if ! run git clone https://aur.archlinux.org/yay.git "$tmp/yay"; then
    rm -rf "$tmp"
    die "failed to clone the yay repository"
  fi
  if ! ( cd "$tmp/yay" && run makepkg -si --noconfirm ); then
    rm -rf "$tmp"
    die "failed to build yay"
  fi
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

# web-docs-mcp (opencode MCP "web-docs") is provisioned by install/install_opencode.sh:
# OpenCode is set up by its own script, packages stay in the manifests.

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

write_compositor() {
  local f="$STATE_DIR/compositor" cur="" want=""
  [[ -f "$f" ]] && cur="$(tr -d '[:space:]' < "$f")"

  if [[ "$PROFILE" == "headless" ]]; then
    # headless — всегда none, даже если state приехал с другой машины.
    want=none
    [[ -n "$cur" && "$cur" != "none" ]] &&
      warn "compositor=$cur на headless-хосте; ставлю none"
  elif [[ "$cur" == "sway" || "$cur" == "niri" || "$cur" == "none" ]]; then
    # Уже сделанный выбор (установщик или `wm`) не перетираем: hosts.conf —
    # это дефолт для новой машины, а не приказ уже настроенной.
    return 0
  else
    [[ -n "$cur" ]] && warn "битое значение compositor '$cur' в $f; перезаписываю"
    # Миграция: раньше выбор жил в universal-переменной fish и оттуда попадал
    # в окружение, поэтому читаем и env, и universal-скоуп.
    case "${WAYLAND_COMPOSITOR:-}" in sway|niri|none) want="$WAYLAND_COMPOSITOR" ;; esac
    if [[ -z "$want" ]] && command -v fish >/dev/null 2>&1; then
      local legacy
      legacy="$(fish -c 'echo -- $WAYLAND_COMPOSITOR' 2>/dev/null || true)"
      case "$legacy" in sway|niri|none) want="$legacy" ;; esac
    fi
    want="${want:-$COMPOSITOR}"
  fi

  run mkdir -p "$STATE_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] write $f = $want"
  else
    printf '%s\n' "$want" > "$f.tmp"
    mv "$f.tmp" "$f"
    info "compositor: $want"
  fi
}

cleanup_legacy_ocbox() {
  # ocbox сюда больше не входит: песочница OpenCode — отдельный проект со своим
  # установщиком. Здесь только одноразовая уборка того, что осталось от старой
  # раскладки, и только если это ссылки внутрь $REPO.
  local d="$HOME/.config/opencode/sandbox" e ours=1 link

  # 1. Бывший merge-подкаталог ~/.config/opencode/sandbox (до сабмодуля).
  if [[ -d "$d" && ! -L "$d" ]]; then
    if [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
      run rmdir "$d" && info "removed empty legacy merge dir $d"
    else
      for e in "$d"/*; do
        if [[ ! -L "$e" ]]; then ours=0; break; fi
        case "$(readlink "$e")" in
          "$REPO"/opencode/sandbox/*) ;;
          *) ours=0; break ;;
        esac
      done
      if [[ $ours -eq 1 ]]; then
        run rm -rf "$d"
        info "removed legacy merge dir $d"
      else
        warn "legacy ocbox dir $d has local files; left in place, check manually"
      fi
    fi
  fi

  # 2. Симлинки ocbox на бывший сабмодуль `ocbox/` в этом дереве.
  for e in "$HOME/.config/opencode-sandbox" "$LOCAL_PREFIX/bin/ocbox"; do
    [[ -L "$e" ]] || continue
    link="$(readlink "$e" 2>/dev/null || true)"
    case "$link" in
      "$REPO"/ocbox|"$REPO"/ocbox/*)
        run rm -f "$e"
        info "removed legacy ocbox link $e"
        ;;
    esac
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
      if [[ ! -e "$src_abs" ]]; then
        warn "missing source: $src"
        continue
      fi
      ensure_link "$src_abs" "$target_abs"
    fi
  done < "$INSTALL_DIR/symlinks.conf"

  # Тема и helix-тема живут в state; see wayland/theme-sync.
  log "preparing runtime state in $STATE_DIR"
  run mkdir -p "$STATE_DIR/alacritty" "$STATE_DIR/helix/runtime/themes" "$STATE_DIR/ironbar"
  ensure_link "$STATE_DIR/helix/runtime" "$HOME/.config/helix/runtime"
  write_compositor

  cleanup_legacy_hooks
  cleanup_legacy_ocbox
else
  log "skipping symlinks (--no-links)"
fi

# ---------------------------------------------------------------- login shell
# Вся графика стартует из fish/config.fish (exec на tty1), поэтому fish должен
# быть login shell. В инструкции этого шага не было: после установки ambb
# человек логинился в bash, композитор не поднимался, и диагностировать это
# на чёрном экране нечем.
setup_login_shell() {
  local fish_bin cur user="${USER:-$(id -un)}"
  fish_bin="$(command -v fish 2>/dev/null || true)"
  [[ -n "$fish_bin" ]] || { warn "fish не установлен; login shell не меняю"; return 0; }
  cur="$(getent passwd "$user" | cut -d: -f7)"
  if [[ "$cur" == "$fish_bin" ]]; then
    info "login shell уже $fish_bin"
    return 0
  fi
  grep -qx "$fish_bin" /etc/shells 2>/dev/null ||
    warn "$fish_bin нет в /etc/shells; chsh может отказать"
  log "login shell: ${cur:-?} -> $fish_bin"
  # chsh спрашивает пароль: в неинтерактивном прогоне это не должно валить
  # установку симлинков, поэтому warn, а не die.
  run sudo chsh -s "$fish_bin" "$user" || warn "не удалось сменить shell; выполните: chsh -s $fish_bin"
}

if [[ $DO_SHELL -eq 1 ]]; then
  setup_login_shell
else
  log "skipping login shell (--no-shell)"
fi

# ----------------------------------------------- legacy compositor variable
# Раньше выбор композитора жил в universal-переменной fish и оттуда
# экспортировался в системное окружение (systemd --user), поэтому одной
# `set -e -U` мало: значение продолжает приходить из окружения сессии.
# Источник истины теперь state-файл — переменную убираем везде, где можем.
drop_legacy_compositor_var() {
  command -v fish >/dev/null 2>&1 || return 0
  # Без state-файла переменную не трогаем: она ещё единственный носитель
  # выбора (например, при --no-links).
  [[ -f "$STATE_DIR/compositor" ]] || return 0

  local changed=0
  # Только universal-скоуп: `set -q WAYLAND_COMPOSITOR` был бы истинным и для
  # значения, унаследованного из окружения, и `set -e -U` тогда «падает»,
  # хотя стирать нечего.
  if fish -c 'set -q -U WAYLAND_COMPOSITOR' 2>/dev/null; then
    log "removing legacy WAYLAND_COMPOSITOR universal variable"
    run fish -c 'set -e -U WAYLAND_COMPOSITOR' || warn "could not erase WAYLAND_COMPOSITOR"
    changed=1
  fi
  # Уже после переезда в state переменная могла остаться в окружении
  # systemd --user (её туда импортировали из экспортированной fish).
  if command -v systemctl >/dev/null 2>&1 &&
     systemctl --user show-environment 2>/dev/null | grep -q '^WAYLAND_COMPOSITOR='; then
    log "unsetting WAYLAND_COMPOSITOR in the systemd user environment"
    run systemctl --user unset-environment WAYLAND_COMPOSITOR ||
      warn "could not unset WAYLAND_COMPOSITOR in the user manager"
    changed=1
  fi
  (( changed )) || info "legacy WAYLAND_COMPOSITOR not set"
}

drop_legacy_compositor_var

# ------------------------------------------------ legacy theme variable
# Тема теперь живёт только в state-файле background-mode: его пишет
# wayland/theme-sync (установщик, darkman и applications/theme-switch).
# Универсальную переменную background_mode раньше переключал старый
# ~/.local/bin/theme-switch; fish её больше не читает, поэтому она только
# создаёт иллюзию переключения.
drop_legacy_theme_var() {
  command -v fish >/dev/null 2>&1 || return 0
  # Без state-файла не трогаем: при --no-links он ещё не создан.
  [[ -f "$STATE_DIR/background-mode" ]] || return 0
  if fish -c 'set -q -U background_mode' 2>/dev/null; then
    log "removing legacy background_mode universal variable"
    run fish -c 'set -e -U background_mode' || warn "could not erase background_mode"
  else
    info "legacy background_mode not set"
  fi
}

drop_legacy_theme_var

# -------------------------------------------------- fish: legacy fisher cleanup
# Плагинов fisher в репозитории больше нет: fzf.fish заменён двумя функциями в
# fish/functions (поиск по git status/log), остальное закрывает нативный fish.
# Здесь только снимаем то, что fisher успел поставить в ~/.config/fish на уже
# настроенных хостах, — иначе его `conf.d/fzf.fish` продолжит перебивать ctrl-r.
cleanup_legacy_fisher() {
  command -v fish >/dev/null 2>&1 || return 0

  # Штатный путь: fisher сам знает, какие файлы его плагинов надо снять.
  if fish -c 'type -q fisher' 2>/dev/null; then
    log "removing fisher plugins (fisher is no longer used)"
    while read -r plugin; do
      [[ -z "$plugin" ]] && continue
      run fish -c "fisher remove $plugin" || warn "fisher remove $plugin failed"
    done < <(fish -c 'fisher list' 2>/dev/null || true)
  fi

  # Остатки: сам fisher, его комплишены и файлы плагинов, если `fisher remove`
  # не сработал (например, битый state). Глоб разворачивает уже bash.
  local f
  for f in "$HOME/.config/fish/functions/fisher.fish" \
           "$HOME/.config/fish/completions/fisher.fish" \
           "$HOME/.config/fish/completions/fzf_configure_bindings.fish" \
           "$HOME/.config/fish/conf.d/fzf.fish" \
           "$HOME/.config/fish/functions/fzf_configure_bindings.fish" \
           "$HOME"/.config/fish/functions/_fzf_*.fish; do
    [[ -e "$f" || -L "$f" ]] || continue
    # Не трогаем файлы из репозитория: сюда попадают наши собственные функции,
    # разложенные merge-каталогом как симлинки (в т.ч. _fzf_git_status_preview).
    if [[ -L "$f" && "$(readlink -f "$f")" == "$REPO"/* ]]; then
      continue
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
      info "[dry-run] would remove $f"
    else
      run rm -f "$f"
      info "removed legacy $f"
    fi
  done

  # universal-переменные вида _fisher_plugins/_fisher_<owner>_<repo>_files.
  local vars
  vars="$(fish -c 'set -n | string match "_fisher_*" | string join " "' 2>/dev/null || true)"
  if [[ -n "$vars" ]]; then
    # shellcheck disable=SC2086 # имена переменных без пробелов, нужен word-split
    run fish -c "set -e -U $vars" || warn "could not erase legacy _fisher_* variables"
  fi
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

if [[ $DO_LINKS -eq 1 ]]; then
  # На headless fisher тоже вычищается: конфиг fish там тот же, и старый
  # conf.d/fzf.fish иначе молча перебивает ctrl-r.
  cleanup_legacy_fisher
fi

# ----------------------------------------------------------------- neovim
# Плагины и treesitter-парсеры ставятся не пакетным менеджером, а самим
# Neovim через vim.pack на старте. Без этого шага они появляются только при
# первом интерактивном запуске (нужна сеть + подтверждение в UI), а до тех пор
# нет ни LSP-конфигов, ни подсветки. Запускаем ровно один раз здесь.
provision_nvim() {
  if ! command -v nvim >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
      info "[dry-run] nvim not found; skipping plugin provisioning"
      return 0
    fi
    warn "nvim not found; skipping plugin provisioning"
    return 0
  fi

  # Ошибки плагинов не должны валить установку: конфиг остаётся рабочим и
  # доберёт недостающее при следующем запуске. vim.pack.add() в plugins.lua
  # синхронный, а NVIM_TS_INSTALL_SYNC=1 заставляет дождаться сборки парсеров.
  log "provisioning neovim plugins and treesitter parsers"
  run env NVIM_TS_INSTALL_SYNC=1 nvim --headless -c 'qa!' ||
    warn "neovim provisioning failed (open nvim once to retry)"
}

if [[ $DO_NVIM -eq 1 && $DO_LINKS -eq 1 ]]; then
  provision_nvim
elif [[ $DO_NVIM -eq 0 ]]; then
  log "skipping neovim provisioning (--no-nvim)"
fi

if [[ -d "$BACKUP" ]]; then
  log "backups saved in $BACKUP"
fi
log "done."
