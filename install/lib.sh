#!/usr/bin/env bash
#
# Общие помощники для install.sh и cleanup.sh. Файл подключается через
# `source` и сам по себе ничего не выполняет.
#
# Выставляет переменные:
#   REPO          корень репозитория dotfiles
#   INSTALL_DIR   $REPO/install
#   STATE_DIR     ~/.local/state/dotfiles (рантайм-состояние, вне репозитория)
#   LOCAL_PREFIX  префикс пользовательских установок (~/.local)
#   HOST, HOST_DIR, PROFILE   заполняет resolve_host
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

# resolve_host [<host>] [<profile>] -> HOST, PROFILE, HOST_DIR
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
