#!/usr/bin/env bash
#
# Общие помощники для install.sh, install_opencode.sh и cleanup.sh. Файл
# подключается через `source` и сам по себе ничего не выполняет.
#
# Выставляет переменные:
#   REPO          корень репозитория dotfiles
#   INSTALL_DIR   $REPO/install
#   STATE_DIR     ~/.local/state/dotfiles (рантайм-состояние, вне репозитория)
#   LOCAL_PREFIX  префикс пользовательских установок (~/.local)
#   BACKUP        каталог бэкапов на текущий прогон установщика
#   DRY_RUN       1 — run() только печатает команды
#   HOST, HOST_DIR, PROFILE, COMPOSITOR   заполняет resolve_host
#
# Раскладка симлинков (ensure_link, merge_dir, copy_volatile) тоже здесь: её
# делят install.sh и install_opencode.sh, иначе merge-логика разъедется.
#
# shellcheck shell=bash

# Путь считается от самого lib.sh: он лежит в install/, репозиторий — выше.
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$_LIB_DIR/.." && pwd)}"
INSTALL_DIR="$_LIB_DIR"

STATE_DIR="${STATE_DIR:-$HOME/.local/state/dotfiles}"

# User-level install prefix for tooling that has no pacman/AUR package.
# npm's global prefix defaults to /usr (node is packaged system-wide), which is
# root-owned, so 'npm install -g' fails with EACCES for a normal user.
# Installing into $HOME/.local puts bins in ~/.local/bin and modules in
# ~/.local/lib/node_modules.
LOCAL_PREFIX="${LOCAL_PREFIX:-$HOME/.local}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m warn \033[0m%s\n' "$*" >&2; }
die()  { printf '\033[1;31merror \033[0m%s\n' "$*" >&2; exit 1; }

# DRY_RUN=1 заставляет run() только печатать команды. Установщики выставляют
# его из --dry-run; значение по умолчанию — реальное выполнение.
DRY_RUN="${DRY_RUN:-0}"

run() {
  if [[ $DRY_RUN -eq 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}

# Куда складывать всё, что установщик заменяет: старые симлинки, чужие файлы.
# Каталог создаётся лениво, только при первом реальном бэкапе.
BACKUP="${BACKUP:-$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)}"

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
      # приложения (fish, helix) пишут рядом, а файлы остаются ссылками.
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

# $LOCAL_PREFIX/bin is added to PATH by fish (fish_user_paths), not by bash, so
# checking $PATH alone reports a false negative. Consult fish too.
have_local_bin_in_path() {
  case ":$PATH:" in *":$LOCAL_PREFIX/bin:"*) return 0 ;; esac
  if command -v fish >/dev/null 2>&1; then
    fish -c 'contains -- $argv[1] $fish_user_paths' "$LOCAL_PREFIX/bin" >/dev/null 2>&1 && return 0
  fi
  return 1
}

read_list() { # file -> one entry per line (comments/blanks stripped)
  [[ -f "$1" ]] || return 0
  sed -e 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^[[:space:]]*$' || true
}

# Как read_list, но берёт из строки только первое слово. Нужен для списков,
# которые человек правит руками: в keep.txt рядом с именем можно оставить
# пояснение или размер, и оно не превратится в «пакет».
read_names() { # file -> first whitespace-separated field of each line
  [[ -f "$1" ]] || return 0
  sed -e 's/#.*//' "$1" | awk 'NF {print $1}'
}

detect_hostname() {
  local hn=""
  hn="$(hostnamectl --static 2>/dev/null || true)"
  [[ -n "$hn" ]] || hn="$(cat /etc/hostname 2>/dev/null || true)"
  printf '%s' "${hn:-unknown}"
}

conf_profile_for() { # conf_profile_for <host-dir> -> profile from hosts.conf
  awk -v d="$1" '!/^#/ && $2==d {print $3; exit}' "$INSTALL_DIR/hosts.conf"
}

conf_compositor_for() { # conf_compositor_for <host-dir> -> compositor from hosts.conf
  awk -v d="$1" '!/^#/ && $2==d {print $4; exit}' "$INSTALL_DIR/hosts.conf"
}

# resolve_host [<host>] [<profile>] -> HOST, PROFILE, HOST_DIR, COMPOSITOR
# An explicit <host> disables hostname detection; an explicit <profile>
# overrides the one from hosts.conf.
resolve_host() {
  local want_host="${1:-}" want_profile="${2:-}" hn name dir prof _
  if [[ -z "$want_host" ]]; then
    hn="$(detect_hostname)"
    while read -r name dir prof _; do
      [[ -z "$name" || "$name" == \#* ]] && continue
      if [[ "$name" == "$hn" ]]; then HOST="$dir"; PROFILE="$prof"; break; fi
    done < "$INSTALL_DIR/hosts.conf"
    [[ -n "${HOST:-}" ]] || die "cannot detect host for hostname '$hn'; pass --host <name>"
    info "detected hostname '$hn' -> host '$HOST'"
  else
    HOST="$want_host"
  fi

  if [[ -n "$want_profile" ]]; then
    PROFILE="$want_profile"
  else
    PROFILE="$(conf_profile_for "$HOST")"
    PROFILE="${PROFILE:-gui}"
  fi

  HOST_DIR="$REPO/hosts/$HOST"
  [[ -d "$HOST_DIR" ]] || die "unknown host dir: hosts/$HOST (see install/hosts.conf)"

  COMPOSITOR="$(conf_compositor_for "$HOST")"
  # headless — это «графики нет по определению»: даже если в hosts.conf по
  # ошибке написано sway, композитор там не поднимается.
  if [[ "$PROFILE" == "headless" ]]; then
    COMPOSITOR=none
  else
    case "${COMPOSITOR:-sway}" in
      sway|niri|none) COMPOSITOR="${COMPOSITOR:-sway}" ;;
      *) warn "hosts.conf: unknown compositor '${COMPOSITOR}' for $HOST; using sway"
         COMPOSITOR=sway ;;
    esac
  fi
}

# collect_packages <profile> <host-dir> <official-array> <aur-array>
# Fills the two arrays with the manifests that apply to the given profile.
# Shared by install.sh (what to install) and cleanup.sh (what to keep), so the
# install and cleanup sets can never drift apart.
collect_packages() {
  local profile="$1" host_dir="$2"
  local -n _official="$3" _aur="$4"
  _official=(); _aur=()

  mapfile -t -O "${#_official[@]}" _official < <(read_list "$INSTALL_DIR/packages/base.txt")
  mapfile -t -O "${#_aur[@]}"      _aur      < <(read_list "$INSTALL_DIR/packages/aur/base.txt")

  if [[ "$profile" != "headless" ]]; then
    mapfile -t -O "${#_official[@]}" _official < <(read_list "$INSTALL_DIR/packages/dev.txt")
    mapfile -t -O "${#_aur[@]}"      _aur      < <(read_list "$INSTALL_DIR/packages/aur/dev.txt")
  fi
  if [[ "$profile" == "gui" ]]; then
    mapfile -t -O "${#_official[@]}" _official < <(read_list "$INSTALL_DIR/packages/gui.txt")
    mapfile -t -O "${#_aur[@]}"      _aur      < <(read_list "$INSTALL_DIR/packages/aur/gui.txt")
  fi

  mapfile -t -O "${#_official[@]}" _official < <(read_list "$host_dir/packages.txt")
  mapfile -t -O "${#_aur[@]}"      _aur      < <(read_list "$host_dir/packages-aur.txt")
}
