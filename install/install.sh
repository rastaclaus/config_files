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
#   --dry-run         print what would happen, change nothing
#   -h, --help
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="$REPO/install"

HOST=""
PROFILE=""
DO_PACKAGES=1
DO_LINKS=1
DRY_RUN=0

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m warn \033[0m%s\n' "$*" >&2; }
die()  { printf '\033[1;31merror \033[0m%s\n' "$*" >&2; exit 1; }

run() {
  if [[ $DRY_RUN -eq 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}

usage() {
  sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)   HOST="${2:-}";    shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --no-packages) DO_PACKAGES=0; shift ;;
    --no-links)    DO_LINKS=0;    shift ;;
    --dry-run)     DRY_RUN=1;     shift ;;
    -h|--help)     usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

HOSTS_CONF="$INSTALL_DIR/hosts.conf"

# ---------------------------------------------------------------- host resolve
detect_hostname() {
  local hn=""
  hn="$(hostnamectl --static 2>/dev/null || true)"
  [[ -n "$hn" ]] || hn="$(cat /etc/hostname 2>/dev/null || true)"
  printf '%s' "${hn:-unknown}"
}

if [[ -z "$HOST" ]]; then
  HN="$(detect_hostname)"
  while read -r name dir prof _; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    if [[ "$name" == "$HN" ]]; then HOST="$dir"; PROFILE="$prof"; break; fi
  done < "$HOSTS_CONF"
  [[ -n "$HOST" ]] || die "cannot detect host for hostname '$HN'; pass --host <name>"
  info "detected hostname '$HN' -> host '$HOST'"
fi

if [[ -z "$PROFILE" ]]; then
  PROFILE="$(awk -v d="$HOST" '!/^#/ && $2==d {print $3; exit}' "$HOSTS_CONF")"
  PROFILE="${PROFILE:-gui}"
fi

HOST_DIR="$REPO/hosts/$HOST"
[[ -d "$HOST_DIR" ]] || die "unknown host dir: hosts/$HOST (see install/hosts.conf)"

log "host=$HOST profile=$PROFILE repo=$REPO"

# ------------------------------------------------------------------ list files
read_list() { # file -> one entry per line (comments/blanks stripped)
  [[ -f "$1" ]] || return 0
  sed -e 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^[[:space:]]*$' || true
}

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

if [[ $DO_PACKAGES -eq 1 ]]; then
  install_yay

  official=()
  aur=()
  official+=( $(read_list "$INSTALL_DIR/packages/base.txt") )
  aur+=(      $(read_list "$INSTALL_DIR/packages/aur/base.txt") )
  official+=( $(read_list "$HOST_DIR/packages.txt") )
  aur+=(      $(read_list "$HOST_DIR/packages-aur.txt") )
  if [[ "$PROFILE" == "gui" ]]; then
    official+=( $(read_list "$INSTALL_DIR/packages/gui.txt") )
    aur+=(      $(read_list "$INSTALL_DIR/packages/aur/gui.txt") )
  fi

  if [[ ${#official[@]} -gt 0 ]]; then
    log "installing official packages (${#official[@]})"
    run yay -S --needed --noconfirm "${official[@]}"
  fi
  if [[ ${#aur[@]} -gt 0 ]]; then
    log "installing AUR packages (${#aur[@]})"
    run yay -S --needed --noconfirm "${aur[@]}"
  fi

  mapfile -t npms < <(read_list "$INSTALL_DIR/npm.txt")
  if [[ ${#npms[@]} -gt 0 ]]; then
    if command -v npm >/dev/null 2>&1 || [[ $DRY_RUN -eq 1 ]]; then
      log "installing npm globals (${#npms[@]})"
      run npm install -g "${npms[@]}"
    else
      warn "npm not found; skipping npm globals"
    fi
  fi

  if command -v uv >/dev/null 2>&1 || [[ $DRY_RUN -eq 1 ]]; then
    while read -r tool; do
      [[ -z "$tool" ]] && continue
      log "uv tool install $tool"
      run uv tool install "$tool"
    done < <(read_list "$INSTALL_DIR/uv-tools.txt")
  else
    warn "uv not found; skipping uv tools"
  fi

  if command -v fish >/dev/null 2>&1 || [[ $DRY_RUN -eq 1 ]]; then
    if ! fish -c 'type -q fisher' 2>/dev/null; then
      log "installing fisher"
      run fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
    fi
    while read -r plugin; do
      [[ -z "$plugin" ]] && continue
      log "fisher install $plugin"
      run fish -c "fisher install $plugin"
    done < <(read_list "$REPO/fish/fish_plugins")
  fi
else
  log "skipping packages (--no-packages)"
fi

# ----------------------------------------------------------------------- links
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

backup_path() { # move an existing path out of the way
  local p="$1"
  mkdir -p "$BACKUP"
  local base dest; base="$(basename "$p")"; dest="$BACKUP/$base"
  local i=1
  while [[ -e "$dest" || -L "$dest" ]]; do dest="$BACKUP/${base}.$i"; i=$((i+1)); done
  run mv "$p" "$dest"
  info "backed up $p -> $dest"
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

merge_dir() { # merge_dir <common-dir> <host-dir> <target-dir>
  local common="$1" host="$2" target="$3"
  # target must be a real directory
  if [[ -L "$target" ]]; then backup_path "$target"; run rm -f "$target"; fi
  if [[ -e "$target" && ! -d "$target" ]]; then backup_path "$target"; run rm -f "$target"; fi
  run mkdir -p "$target"

  local names name c h
  names="$( { ls -A "$common" 2>/dev/null || true; ls -A "$host" 2>/dev/null || true; } | sort -u )"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    c="$common/$name"; h="$host/$name"
    if [[ -e "$h" || -L "$h" ]]; then
      if [[ -d "$h" ]]; then
        merge_dir "$([[ -d "$c" ]] && printf '%s' "$c" || printf '/nonexistent')" "$h" "$target/$name"
      else
        ensure_link "$h" "$target/$name"
      fi
    else
      ensure_link "$c" "$target/$name"
    fi
  done <<< "$names"
}

if [[ $DO_LINKS -eq 1 ]]; then
  log "setting up symlinks"
  while read -r src target tag _; do
    [[ -z "$src" || "$src" == \#* ]] && continue
    if [[ "$tag" == "gui" && "$PROFILE" != "gui" ]]; then
      continue
    fi
    src_abs="$REPO/$src"
    target_abs="${target/#\~/$HOME}"
    [[ -e "$src_abs" ]] || { warn "missing source: $src"; continue; }
    host_src="$(host_source_for "$target_abs")"
    if [[ -d "$host_src" ]]; then
      info "merging host override for $target_abs"
      merge_dir "$src_abs" "$host_src" "$target_abs"
    else
      ensure_link "$src_abs" "$target_abs"
    fi
  done < "$INSTALL_DIR/symlinks.conf"
else
  log "skipping symlinks (--no-links)"
fi

if [[ -d "$BACKUP" ]]; then
  log "backups saved in $BACKUP"
fi
log "done."
