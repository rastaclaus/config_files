#!/usr/bin/env bash
#
# Уборка хоста: удаляет пакеты, которых нет в манифестах установки, и чистит
# то, что остаётся после них — конфиги, state-хранилища, кэши, службы.
#
# Набор «что должно стоять» берётся из тех же манифестов и по той же логике
# host/profile, что у install.sh (общий install/lib.sh), поэтому установка и
# уборка не могут разъехаться.
#
# Ничего не удаляется без --apply. Конфиги и state не стираются, а переносятся
# в карантин в ~/.local/state/dotfiles/cleanup/<дата>/ (там же restore.sh).
#
#   ./install/cleanup.sh [options]
#
# Options:
#   --apply           выполнить удаление (без флага — только отчёт, dry-run)
#   --yes             не спрашивать подтверждения
#   --interactive     спрашивать по каждому пакету
#   --purge-configs   конфиги/state/cache удалённых пакетов -> карантин
#   --purge-system    /etc, /var/lib, /var/cache, /var/log -> карантин (sudo)
#   --purge-caches    кэши pacman/yay/journal/npm/uv/pip/thumbnails
#   --purge-modcache  дополнительно go/cargo modcache (скачивается заново)
#   --purge-tools     npm/uv сверх манифестов
#   --no-orphans      не удалять осиротевшие зависимости
#   --keep <pkg>      дополнительно защитить пакет (можно несколько раз)
#   --init-keep       создать черновик hosts/<host>/keep.txt (не перезаписывает)
#   --check           только код выхода: 0 — дрейфа нет, 2 — есть
#   --host <name>     host id: desktop|ambb|alen|work (по умолчанию — hostname)
#   --profile <p>     gui|headless (по умолчанию — из install/hosts.conf)
#   -h, --help
#
# Флаги --purge-* действуют только вместе с --apply: сначала удаление, затем
# уборка остатков. Карантин можно удалить вручную, когда всё проверено.
#
set -euo pipefail

# shellcheck source=install/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

APPLY=0
YES=0
INTERACTIVE=0
PURGE_CONFIGS=0
PURGE_SYSTEM=0
PURGE_CACHES=0
PURGE_MODCACHE=0
PURGE_TOOLS=0
KEEP_ORPHANS=0
INIT_KEEP=0
CHECK_ONLY=0
HOST_ARG=""
PROFILE_ARG=""
RUN_DIR=""
EXTRA_KEEP=()

usage() {
  sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)          APPLY=1; shift ;;
    --yes)            YES=1; shift ;;
    --interactive)    INTERACTIVE=1; shift ;;
    --purge-configs)  PURGE_CONFIGS=1; shift ;;
    --purge-system)   PURGE_SYSTEM=1; shift ;;
    --purge-caches)   PURGE_CACHES=1; shift ;;
    --purge-modcache) PURGE_MODCACHE=1; shift ;;
    --purge-tools)    PURGE_TOOLS=1; shift ;;
    --no-orphans)     KEEP_ORPHANS=1; shift ;;
    --init-keep)      INIT_KEEP=1; shift ;;
    --check)          CHECK_ONLY=1; shift ;;
    --keep)           EXTRA_KEEP+=("${2:-}"); shift 2 ;;
    --host)           HOST_ARG="${2:-}"; shift 2 ;;
    --profile)        PROFILE_ARG="${2:-}"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

[[ $EUID -eq 0 ]] && die "не запускайте от root: скрипт работает с \$HOME и сам вызывает sudo"

# --check годится для скриптов: только итоговая строка и код выхода.
if [[ $CHECK_ONLY -eq 1 ]]; then
  log()  { :; }
  info() { :; }
fi

human() { # human <bytes>
  awk -v b="${1:-0}" 'BEGIN{u="B KiB MiB GiB TiB"; split(u,a," "); i=1
    while (b>=1024 && i<5) {b/=1024; i++}
    printf "%.1f %s", b, a[i]}'
}

du_h() { du -sh "$@" 2>/dev/null | awk '{print $1}' || true; }

journal_size() { journalctl --disk-usage 2>/dev/null | sed -n 's/.*take up \([^ ]*\) .*/\1/p'; }

norm() { printf '%s' "${1,,}" | tr -d -- '-_. ' ; }

# --------------------------------------------------------- helpers: purge
cache_sizes() { # текущие размеры кэшей
  printf '    %-18s %s\n' "pacman (pkg)"   "$(du_h /var/cache/pacman/pkg)"
  printf '    %-18s %s\n' "yay"            "$(du_h "$HOME/.cache/yay")"
  printf '    %-18s %s\n' "journal"        "$(journal_size)"
  printf '    %-18s %s\n' "npm"            "$(du_h "$HOME/.npm")"
  printf '    %-18s %s\n' "uv"             "$(du_h "$HOME/.cache/uv")"
  printf '    %-18s %s\n' "pip"            "$(du_h "$HOME/.cache/pip")"
  printf '    %-18s %s\n' "thumbnails"     "$(du_h "$HOME/.cache/thumbnails")"
}

modcache_sizes() {
  printf '    %-18s %s\n' "go modcache"    "$(du_h "$HOME/go/pkg/mod")"
  printf '    %-18s %s\n' "cargo registry" "$(du_h "$HOME/.cargo/registry")"
}

# Инструменты, установленные пользователем сверх манифестов: "<вид>\t<имя>".
tools_extra() {
  local t
  if command -v npm >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    mapfile -t want_npm < <(read_list "$INSTALL_DIR/npm.txt")
    while IFS= read -r t; do
      [[ -n "$t" ]] || continue
      [[ " ${want_npm[*]-} " == *" $t "* ]] && continue
      printf 'npm\t%s\n' "$t"
    done < <(npm ls -g --prefix "$LOCAL_PREFIX" --depth=0 --json 2>/dev/null |
      jq -r '.dependencies // {} | keys[]' 2>/dev/null || true)
  fi

  if command -v uv >/dev/null 2>&1; then
    mapfile -t want_uv < <(read_list "$INSTALL_DIR/uv-tools.txt")
    while IFS= read -r t; do
      [[ -n "$t" ]] || continue
      [[ " ${want_uv[*]-} " == *" $t "* ]] && continue
      printf 'uv\t%s\n' "$t"
    done < <(uv tool list 2>/dev/null | awk 'NF && $0 !~ /^-/ && $0 !~ /^[[:space:]]/ {print $1}' || true)
  fi
}

# ------------------------------------------------------- пути и карантин
# Цели из symlinks.conf — то, чем управляет install.sh: их не переносим.
MANAGED_TARGETS=()
while read -r src tgt _tags _; do
  [[ -z "$src" || "$src" == \#* ]] && continue
  MANAGED_TARGETS+=("${tgt/#\~/$HOME}")
done < "$INSTALL_DIR/symlinks.conf"

is_managed_path() { # пути, которыми управляет install.sh или сам cleanup.sh
  local p="$1" t target
  if [[ -L "$p" ]]; then
    t="$(readlink -f "$p" 2>/dev/null || true)"
    [[ "$t" == "$REPO"/* ]] && return 0
  fi
  case "$p" in
    "$STATE_DIR"|"$STATE_DIR"/*) return 0 ;;
  esac
  for target in "${MANAGED_TARGETS[@]}"; do
    [[ "$p" == "$target" || "$p" == "$target"/* ]] && return 0
  done
  return 1
}

expand_path() { # ~ -> $HOME, глобы раскрываются
  local p="${1/#\~/$HOME}"
  if [[ "$p" == *'*'* ]]; then compgen -G "$p" || true; else printf '%s\n' "$p"; fi
}

# Пакет, которому может принадлежать каталог, среди остающихся
# (desired/protected/keep): сравнение нормализованных имён с учётом вложенности
# (каталог Mattermost ~ mattermost, но и mattermost-desktop).
kept_owner_of() { # <norm-name> -> имя пакета, rc=0 | rc=1
  local n="$1" p pn
  for p in "${!DESIRED[@]}" "${!KEEP[@]}" "${!PROTECTED[@]}"; do
    pn="$(norm "$p")"
    if [[ "$pn" == "$n" || "$pn" == "$n"* || "$n" == "$pn"* ]]; then
      printf '%s' "$p"
      return 0
    fi
  done
  return 1
}

user_paths_for() { # pkg -> пути в $HOME
  local p="$1" line pkg path base cand owner
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    read -r pkg path <<< "$line"
    [[ "$pkg" == "$p" ]] || continue
    expand_path "$path"
  done < "$INSTALL_DIR/cleanup-paths.conf"
  # Эвристика: каталог верхнего уровня, имя которого совпадает с именем пакета
  # без учёта регистра и разделителей (Code ~ code, TelegramDesktop ~
  # telegram-desktop).
  for base in "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state" "$HOME/.cache"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r cand; do
      [[ -n "$cand" ]] || continue
      [[ "$(norm "$(basename "$cand")")" == "$(norm "$p")" ]] || continue
      # Каталог может принадлежать и удаляемому пакету, и остающемуся
      # (Mattermost ~ mattermost vs mattermost-desktop) — тогда не трогаем.
      if owner="$(kept_owner_of "$(norm "$(basename "$cand")")")"; then
        warn "не трогаю $cand: может принадлежать остающемуся пакету $owner"
        continue
      fi
      printf '%s\n' "$cand"
    done < <(compgen -G "$base/*" || true)
  done
}

system_paths_for() { # pkg -> пути вне $HOME
  local p="$1" line pkg path base
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    read -r pkg path <<< "$line"
    [[ "$pkg" == "$p" ]] || continue
    [[ "$path" == /* ]] && expand_path "$path"
  done < "$INSTALL_DIR/cleanup-paths.conf"
  for base in /etc /var/lib /var/cache /var/log; do
    [[ -e "$base/$p" ]] && printf '%s\n' "$base/$p"
  done
}

# Базы пакетного менеджера и чужие state-хранилища не трогаем: их потеря
# не связана с удалением конкретного пакета.
CRITICAL_STATE='^(pacman|systemd|dbus|dbus-broker|polkit|shadow|openssh|cups|docker|containerd|libvirt|samba|flatpak|snapd|nfs-utils)$'
is_critical_system_path() {
  case "$1" in
    /var/lib/pacman*|/var/lib/systemd*|/var/lib/dbus*|\
    /var/lib/docker*|/var/lib/containers*|/var/lib/libvirt*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------- host / sets
resolve_host "$HOST_ARG" "$PROFILE_ARG"

# Ручной --profile, расходящийся с hosts.conf, — почти всегда опечатка,
# а цена ошибки высокая: от профиля зависит набор «что должно стоять».
if [[ -n "$PROFILE_ARG" ]]; then
  conf_profile="$(conf_profile_for "$HOST")"
  if [[ -n "$conf_profile" && "$conf_profile" != "$PROFILE_ARG" ]]; then
    warn "profile=$PROFILE_ARG не совпадает с hosts.conf ($conf_profile) для host=$HOST"
  fi
fi

official=(); aur=()
collect_packages "$PROFILE" "$HOST_DIR" official aur

declare -A DESIRED=() PROTECTED=() KEEP=()
for p in "${official[@]}" "${aur[@]}"; do DESIRED[$p]=1; done
while read -r p; do [[ -n "$p" ]] && PROTECTED[$p]=1; done < <(read_names "$INSTALL_DIR/protected.txt")

KEEP_FILE="$HOST_DIR/keep.txt"
if [[ -f "$KEEP_FILE" ]]; then
  while read -r p; do [[ -n "$p" ]] && KEEP[$p]=1; done < <(read_names "$KEEP_FILE")
fi
for p in "${EXTRA_KEEP[@]}"; do [[ -n "$p" ]] && KEEP[$p]=1; done

log "host=$HOST profile=$PROFILE"
info "желаемое: ${#DESIRED[@]} пакет(ов) из манифестов; protected: ${#PROTECTED[@]}; keep: ${#KEEP[@]}"

# --------------------------------------------------------------- package db
# Один вызов pacman -Qi на весь список установленного: имя, размер в байтах,
# «Required By» (pacman учитывает там и зависимости по provides).
declare -A PKG_BYTES=() PKG_REQ=()
load_pkg_db() {
  local name bytes req
  while IFS=$'\t' read -r name bytes req; do
    [[ -n "$name" ]] || continue
    PKG_BYTES[$name]="${bytes:-0}"
    [[ "$req" == "None" ]] && req=""
    PKG_REQ[$name]="$req"
  done < <(pacman -Qi | awk '
      function tobytes(s,  a, v, u) {
        split(s, a, " "); v = a[1] + 0; u = a[2]
        if (u == "KiB") return v * 1024
        if (u == "MiB") return v * 1048576
        if (u == "GiB") return v * 1073741824
        if (u == "TiB") return v * 1099511627776
        return v
      }
      /^Name[ \t]*:/           { name = $3 }
      /^Required By[ \t]*:/    { r = $0; sub(/^Required By[ \t]*:[ \t]*/, "", r); req[name] = r }
      /^Installed Size[ \t]*:/ { s = $0; sub(/^Installed Size[ \t]*:[ \t]*/, "", s); bytes[name] = tobytes(s) }
      END { for (n in bytes) printf "%s\t%d\t%s\n", n, bytes[n], req[n] }')
}
load_pkg_db

declare -A FOREIGN=()
while read -r p; do [[ -n "$p" ]] && FOREIGN[$p]=1; done < <(pacman -Qqm 2>/dev/null || true)

# ---------------------------------------------------------------- candidates
# Явно установленные пакеты минус desired / protected / keep.
declare -A CAND=()
declare -a BLOCKED=()
while read -r p; do
  [[ -n "$p" ]] || continue
  [[ -n "${PKG_BYTES[$p]+x}" ]] || continue   # не установлен
  [[ -n "${DESIRED[$p]+x}" ]] && continue
  [[ -n "${PROTECTED[$p]+x}" ]] && continue
  [[ -n "${KEEP[$p]+x}" ]] && continue
  CAND[$p]=1
done < <(pacman -Qqe)

# Пакет нельзя снять, если от него зависит что-то остающееся.
filter_required() {
  local p q changed=1
  while [[ $changed -eq 1 ]]; do
    changed=0
    for p in "${!CAND[@]}"; do
      for q in ${PKG_REQ[$p]:-}; do
        if [[ -z "${CAND[$q]+x}" ]]; then
          BLOCKED+=("$p|нужен пакету $q")
          unset 'CAND[$p]'
          changed=1
          break
        fi
      done
    done
  done
}
filter_required

final_list() {
  [[ ${#CAND[@]} -eq 0 ]] && return 0
  printf '%s\n' "${!CAND[@]}" | sort
}

# Контрольная проверка резолвером pacman: он видит provides и версии. Если
# транзакция невозможна, вытаскиваем виновника из сообщения и выбрасываем.
preflight() {
  local -a list
  local err p round=0 dropped
  while :; do
    mapfile -t list < <(final_list)
    [[ ${#list[@]} -eq 0 || -z "${list[0]:-}" ]] && return 0
    if err="$(pacman -Rs --print --print-format '%n' "${list[@]}" 2>&1 >/dev/null)"; then
      return 0
    fi
    round=$((round + 1))
    if [[ $round -gt 5 ]]; then
      warn "pacman не подтвердил транзакцию; оставляю набор как есть:"
      printf '%s\n' "$err" >&2
      return 0
    fi
    dropped=0
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      [[ -n "${CAND[$p]+x}" ]] || continue
      BLOCKED+=("$p|$(grep -m1 -F "removing $p breaks" <<< "$err" | sed 's/^:: //')")
      unset 'CAND[$p]'
      dropped=1
    done < <(sed -n 's/^:: removing \([^ ]*\) breaks dependency.*/\1/p' <<< "$err" | sort -u)
    if [[ $dropped -eq 0 ]]; then
      warn "не удалось разобрать ответ pacman; оставляю набор как есть:"
      printf '%s\n' "$err" >&2
      return 0
    fi
  done
}
preflight

declare -a FINAL=()
while IFS= read -r p; do [[ -n "$p" ]] && FINAL+=("$p"); done < <(final_list)

total_bytes=0
for p in "${FINAL[@]}"; do total_bytes=$((total_bytes + ${PKG_BYTES[$p]:-0})); done

PURGE_WANTED=0
[[ $PURGE_CONFIGS -eq 1 || $PURGE_SYSTEM -eq 1 || $PURGE_CACHES -eq 1 || \
   $PURGE_MODCACHE -eq 1 || $PURGE_TOOLS -eq 1 ]] && PURGE_WANTED=1

# Пакеты, чьи остатки убираем: текущий набор плюс всё, что снимали прошлые
# прогоны (их removed.txt лежит рядом, в state-каталоге). Иначе --purge-* не
# работал бы после того, как пакеты уже удалены.
purge_pkgs() {
  {
    printf '%s\n' "${FINAL[@]}"
    for d in "$STATE_DIR"/cleanup/*/removed.txt; do
      [[ -f "$d" ]] && cat "$d"
    done
  } | grep -v '^$' | sort -u
}

# ------------------------------------------------------------------- отчёт
if [[ ${#FINAL[@]} -eq 0 ]]; then
  if [[ $CHECK_ONLY -eq 1 ]]; then
    printf 'cleanup: дрейфа нет\n'
    exit 0
  fi
  if [[ ${#BLOCKED[@]} -gt 0 ]]; then
    log "удалять нечего: ${#BLOCKED[@]} пакет(ов) остаются, т.к. нужны другим"
    printf '%s\n' "${BLOCKED[@]}" | sort | awk -F'|' '{printf "    %-28s %s\n", $1, $2}'
    printf '\n'
  else
    log "дрейфа нет: все явно установленные пакеты есть в манифестах/protected/keep"
  fi
  if [[ $PURGE_WANTED -eq 0 ]]; then
    exit 0
  fi
  log "убираю остатки прошлых удалений"
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
  printf 'cleanup: дрейф — %d пакет(ов), %s\n' "${#FINAL[@]}" "$(human "$total_bytes")"
  exit 2
fi

if [[ $INIT_KEEP -eq 1 ]]; then
  [[ -f "$KEEP_FILE" ]] && die "$KEEP_FILE уже существует; отредактируйте его вручную"
  mkdir -p "$HOST_DIR"
  {
    printf '# Пакеты, которые cleanup.sh не должен трогать на host=%s.\n' "$HOST"
    printf '# Формат: одно имя пакета на строку; всё после «#» игнорируется.\n'
    printf '#\n'
    printf '# Черновик создан cleanup.sh --init-keep. Все строки закомментированы,\n'
    printf '# чтобы поведение не изменилось; раскомментируйте нужное.\n'
    printf '\n'
    width=6
    for p in "${FINAL[@]}"; do (( ${#p} > width )) && width=${#p}; done
    for p in "${FINAL[@]}"; do
      printf '# %-*s  # %s\n' "$width" "$p" "$(human "${PKG_BYTES[$p]:-0}")"
    done
  } > "$KEEP_FILE"
  log "создан черновик $KEEP_FILE (${#FINAL[@]} пакет(ов), все закомментированы)"
  exit 0
fi

if [[ ${#FINAL[@]} -gt 0 ]]; then
  log "кандидаты на удаление: ${#FINAL[@]}, $(human "$total_bytes")"
  printf '\n'
  width=6
  for p in "${FINAL[@]}"; do (( ${#p} > width )) && width=${#p}; done
  width=$((width + 2))
  printf "%-${width}s %10s  %s\n" "ПАКЕТ" "РАЗМЕР" "ПРИМЕЧАНИЕ"
  for p in "${FINAL[@]}"; do
    note=""
    [[ -n "${FOREIGN[$p]+x}" ]] && note="AUR"
    printf "%-${width}s %10s  %s\n" "$p" "$(human "${PKG_BYTES[$p]:-0}")" "$note"
  done
  printf '\n'
fi

if [[ ${#FINAL[@]} -gt 0 && ${#BLOCKED[@]} -gt 0 ]]; then
  bw=6
  for b in "${BLOCKED[@]}"; do n="${b%%|*}"; (( ${#n} > bw )) && bw=${#n}; done
  log "остаются в системе (нужны другим пакетам): ${#BLOCKED[@]}"
  printf '%s\n' "${BLOCKED[@]}" | sort | awk -F'|' -v w="$bw" '{printf "    %-"w"s %s\n", $1, $2}'
  printf '\n'
fi

# Транзакция целиком: pacman сам добавит зависимости, которые осиротеют.
if [[ ${#FINAL[@]} -gt 0 ]]; then
  cascade="$(pacman -Rs --print --print-format '%n' "${FINAL[@]}" 2>/dev/null | sort -u || true)"
  if [[ -n "$cascade" ]]; then
    info "с зависимостями, которые осиротеют: $(wc -l <<< "$cascade") пакет(ов)"
    comm -13 <(printf '%s\n' "${FINAL[@]}" | sort) <(printf '%s\n' "$cascade") | sed 's/^/    + /'
    printf '\n'
  fi
fi

if [[ $APPLY -eq 0 ]]; then
  if [[ $PURGE_CONFIGS -eq 1 ]]; then
    log "предпросмотр --purge-configs: что уйдёт в карантин"
    while read -r p; do
      while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        [[ -e "$path" || -L "$path" ]] || continue
        if is_managed_path "$path"; then
          info "пропуск (управляется dotfiles): $path"
        else
          info "$p -> $path ($(du_h "$path"))"
        fi
      done < <(user_paths_for "$p" | sort -u)
    done < <(purge_pkgs)
    printf '\n'
  fi
  if [[ $PURGE_SYSTEM -eq 1 ]]; then
    log "предпросмотр --purge-system: что уйдёт в карантин"
    while read -r p; do
      if [[ "$p" =~ $CRITICAL_STATE ]]; then
        info "пропуск каталогов $p (критичные данные)"
        continue
      fi
      while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        [[ -e "$path" || -L "$path" ]] || continue
        if is_critical_system_path "$path"; then
          info "пропуск $path"
        else
          info "$p -> $path ($(du_h "$path"))"
        fi
      done < <(system_paths_for "$p" | sort -u)
    done < <(purge_pkgs)
    printf '\n'
  fi
  if [[ $PURGE_CACHES -eq 1 ]]; then
    log "предпросмотр --purge-caches: текущие размеры"
    cache_sizes
    printf '\n'
  fi
  if [[ $PURGE_MODCACHE -eq 1 ]]; then
    log "предпросмотр --purge-modcache: текущие размеры"
    modcache_sizes
    printf '\n'
  fi
  if [[ $PURGE_TOOLS -eq 1 ]]; then
    log "предпросмотр --purge-tools: сверх манифестов"
    extra="$(tools_extra)"
    if [[ -n "$extra" ]]; then
      printf '%s\n' "$extra" | awk -F'\t' '{printf "    %-8s %s\n", $1, $2}'
    else
      info "лишних инструментов нет"
    fi
    printf '\n'
  fi
  log "dry-run: ничего не изменено"
  info "удалить: --apply [--purge-configs|--purge-system|--purge-caches|--purge-tools]"
  exit 0
fi

# -------------------------------------------------------------------- consent
if [[ ${#FINAL[@]} -gt 0 ]]; then
  if [[ $INTERACTIVE -eq 1 ]]; then
    declare -a picked=()
    ans=""
    for p in "${FINAL[@]}"; do
      printf '  удалить %-28s %10s ? [y/N/q] ' "$p" "$(human "${PKG_BYTES[$p]:-0}")"
      read -r ans || ans="q"
      case "$ans" in
        y|Y) picked+=("$p") ;;
        q|Q) break ;;
        *)   ;;
      esac
    done
    FINAL=("${picked[@]}")
    if [[ ${#FINAL[@]} -eq 0 ]]; then
      if [[ $PURGE_WANTED -eq 0 ]]; then log "ничего не выбрано"; exit 0; fi
      log "ничего не выбрано; остаётся только уборка остатков"
    fi
  elif [[ $YES -eq 0 ]]; then
    [[ -t 0 ]] || die "нет tty для подтверждения; используйте --yes"
    printf 'Удалить %d пакет(ов) на %s (%s)? Напишите yes: ' "${#FINAL[@]}" "$(human "$total_bytes")" "$HOST"
    read -r ans
    [[ "$ans" == "yes" ]] || die "отменено"
  fi
fi

# После интерактивного выбора в FINAL могла остаться лишь часть пакетов.
total_bytes=0
for p in "${FINAL[@]}"; do total_bytes=$((total_bytes + ${PKG_BYTES[$p]:-0})); done

sudo -v || die "без sudo удаление и уборка невозможны"

ts="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$STATE_DIR/cleanup/$ts"
mkdir -p "$RUN_DIR/quarantine"
if [[ ${#FINAL[@]} -gt 0 ]]; then
  printf '%s\n' "${FINAL[@]}" | sort > "$RUN_DIR/removed.txt"
else
  : > "$RUN_DIR/removed.txt"
fi

# Всё дальнейшее — и на экран, и в лог.
exec > >(tee -a "$RUN_DIR/log.txt") 2>&1
log "run dir: $RUN_DIR"

# ----------------------------------------------------- службы до удаления
# Файлы юнитов исчезнут вместе с пакетом, поэтому выключаем заранее.
units_for() { # pkg -> "system<TAB>/path" | "user<TAB>/path"
  pacman -Ql "$1" 2>/dev/null | awk '
    $2 ~ /^\/usr\/lib\/systemd\/system\/[^\/]+\.(service|socket|timer|path)$/ { print "system\t" $2 }
    $2 ~ /^\/usr\/lib\/systemd\/user\/[^\/]+\.(service|socket|timer|path)$/   { print "user\t" $2 }'
}

declare -a unit_scope=() unit_name=()
if [[ ${#FINAL[@]} -gt 0 ]]; then
  for p in "${FINAL[@]}"; do
    while IFS=$'\t' read -r scope path; do
      [[ -n "${path:-}" ]] || continue
      unit_scope+=("$scope")
      unit_name+=("$(basename "$path")")
    done < <(units_for "$p")
  done
fi

for i in "${!unit_name[@]}"; do
  u="${unit_name[$i]}"; scope="${unit_scope[$i]}"
  if [[ "$scope" == "system" ]]; then
    if systemctl is-enabled --quiet "$u" 2>/dev/null; then
      log "disable $u"
      sudo systemctl disable --now "$u" || warn "не удалось выключить $u"
    fi
  elif systemctl --user is-enabled --quiet "$u" 2>/dev/null; then
    log "disable --user $u"
    systemctl --user disable --now "$u" || warn "не удалось выключить user-юнит $u"
  fi
done

# ------------------------------------------------------------------ удаление
if [[ ${#FINAL[@]} -gt 0 ]]; then
  if sudo pacman -Rns --noconfirm "${FINAL[@]}"; then
    :
  else
    warn "транзакция целиком не прошла; удаляю по одному"
    : > "$RUN_DIR/removed.txt"
    for p in "${FINAL[@]}"; do
      if sudo pacman -Rns --noconfirm "$p"; then
        echo "$p" >> "$RUN_DIR/removed.txt"
      else
        warn "не удалось удалить $p"
        BLOCKED+=("$p|pacman отказал при удалении")
      fi
    done
  fi
fi

sudo systemctl daemon-reload || true
sudo systemctl reset-failed || true
systemctl --user daemon-reload 2>/dev/null || true

# Битые ссылки в wants/ и прочих каталогах юнитов, оставшиеся от снятых пакетов.
while IFS= read -r l; do
  [[ -n "$l" ]] || continue
  log "rm dangling $l"
  sudo rm -f "$l"
done < <(sudo find /etc/systemd/system /etc/systemd/user -xtype l 2>/dev/null || true)

# ------------------------------------------------------- осиротевшие пакеты
if [[ $KEEP_ORPHANS -eq 0 ]]; then
  mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
  if [[ ${#orphans[@]} -gt 0 ]]; then
    printf '%s\n' "${orphans[@]}" | sort > "$RUN_DIR/orphans.txt"
    log "осиротевшие зависимости: ${#orphans[@]}"
    info "$(tr '\n' ' ' < "$RUN_DIR/orphans.txt")"
    sudo pacman -Rns --noconfirm "${orphans[@]}" || warn "часть осиротевших пакетов удалить не удалось"
  fi
fi

# ------------------------------------------------------------------ карантин
qmove() { # qmove <путь> — перенести в карантин (без sudo)
  local p="$1" rel dest
  [[ -e "$p" || -L "$p" ]] || return 0
  if is_managed_path "$p"; then
    info "пропуск (управляется dotfiles): $p"
    return 0
  fi
  if pacman -Qo -- "$p" >/dev/null 2>&1; then
    info "пропуск (принадлежит установленному пакету): $p"
    return 0
  fi
  case "$p" in
    "$HOME"/*) rel="home/${p#"$HOME"/}" ;;
    *)         rel="other/$p" ;;
  esac
  dest="$RUN_DIR/quarantine/$rel"
  mkdir -p "$(dirname "$dest")"
  if mv "$p" "$dest" 2>/dev/null; then
    info "карантин: $p"
  else
    warn "не удалось перенести $p"
  fi
}

qmove_root() { # qmove_root <путь> — то же, но через sudo
  local p="$1" dest
  [[ -e "$p" || -L "$p" ]] || return 0
  if pacman -Qo -- "$p" >/dev/null 2>&1; then
    info "пропуск (принадлежит установленному пакету): $p"
    return 0
  fi
  dest="$RUN_DIR/quarantine/root$p"
  sudo mkdir -p "$(dirname "$dest")"
  if sudo mv "$p" "$dest" 2>/dev/null; then
    info "карантин: $p"
  else
    warn "не удалось перенести $p"
  fi
}

if [[ $PURGE_CONFIGS -eq 1 ]]; then
  log "конфиги/state/cache -> карантин"
  while read -r p; do
    [[ -n "$p" ]] || continue
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      qmove "$path"
    done < <(user_paths_for "$p" | sort -u)
  done < <(purge_pkgs)
fi

if [[ $PURGE_SYSTEM -eq 1 ]]; then
  log "системные каталоги -> карантин"
  while read -r p; do
    [[ -n "$p" ]] || continue
    if [[ "$p" =~ $CRITICAL_STATE ]]; then
      info "пропуск каталогов $p (критичные данные)"
      continue
    fi
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      if is_critical_system_path "$path"; then
        info "пропуск $path"; continue
      fi
      qmove_root "$path"
    done < <(system_paths_for "$p" | sort -u)
  done < <(purge_pkgs)

  # .pacsave/.pacorig — штатные резервные копии конфигов: только показываем.
  mapfile -t pacsaves < <(sudo find /etc \( -name '*.pacsave' -o -name '*.pacorig' \) 2>/dev/null | sort)
  if [[ ${#pacsaves[@]} -gt 0 ]]; then
    info "резервные копии конфигов (*.pacsave), не тронуты:"
    printf '    %s\n' "${pacsaves[@]}"
  fi
fi

if [[ $PURGE_CACHES -eq 1 ]]; then
  log "кэши"
  if command -v paccache >/dev/null 2>&1; then
    b="$(du_h /var/cache/pacman/pkg)"
    sudo paccache -r -k3
    info "pacman: ${b:-0} -> $(du_h /var/cache/pacman/pkg)"
  else
    warn "paccache не найден (пакет pacman-contrib); кэш pacman не тронут"
  fi

  if command -v yay >/dev/null 2>&1; then
    b="$(du_h "$HOME/.cache/yay")"
    yay -Sc --noconfirm || warn "yay -Sc завершился с ошибкой"
    find "$HOME/.cache/yay" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
    info "yay: ${b:-0} -> $(du_h "$HOME/.cache/yay")"
  fi

  b="$(journal_size)"
  sudo journalctl --vacuum-size=500M || warn "не удалось урезать journal"
  info "journal: ${b:-?} -> $(journal_size)"

  command -v npm >/dev/null 2>&1 && npm cache clean --force || true
  command -v uv  >/dev/null 2>&1 && uv cache clean || true
  command -v python >/dev/null 2>&1 && python -m pip cache purge || true

  rm -rf "$HOME"/.cache/thumbnails/* 2>/dev/null || true
  rm -rf "$HOME"/.cache/fontconfig 2>/dev/null || true
  rm -rf "$HOME"/.cache/mesa_shader_cache* 2>/dev/null || true
  rm -rf "$HOME"/.cache/web-docs-mcp 2>/dev/null || true
fi

if [[ $PURGE_MODCACHE -eq 1 ]]; then
  log "modcache (скачивается заново при следующей сборке)"
  b="$(du_h "$HOME/go/pkg/mod")"
  command -v go >/dev/null 2>&1 && go clean -modcache || true
  info "go: ${b:-0} -> $(du_h "$HOME/go/pkg/mod")"
  b="$(du_h "$HOME/.cargo/registry")"
  rm -rf "$HOME"/.cargo/registry/cache "$HOME"/.cargo/git/db 2>/dev/null || true
  info "cargo: ${b:-0} -> $(du_h "$HOME/.cargo/registry")"
fi

if [[ $PURGE_TOOLS -eq 1 ]]; then
  log "пользовательские инструменты сверх манифестов"
  extra="$(tools_extra)"
  if [[ -z "$extra" ]]; then
    info "лишних инструментов нет"
  else
    while IFS=$'\t' read -r kind name; do
      [[ -n "$name" ]] || continue
      case "$kind" in
        npm)    log "npm rm -g $name"
                npm uninstall -g --prefix "$LOCAL_PREFIX" "$name" || warn "npm: не удалось удалить $name" ;;
        uv)     log "uv tool uninstall $name"
                uv tool uninstall "$name" || warn "uv: не удалось удалить $name" ;;
      esac
    done <<< "$extra"
  fi
fi

# ------------------------------------------------------- битые .desktop
# Пакетные ярлыки уходят вместе с пакетом, а вот собственные ярлыки и
# autostart-записи остаются и молча перестают работать: Exec указывает на
# удалённый бинарник. Только показываем — решение за человеком.
desktop_entries() {
  local dir f cmdline exe w
  for dir in "$HOME/.local/share/applications" "$HOME/.config/autostart"; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*.desktop; do
      [[ -f "$f" ]] || continue
      cmdline="$(sed -n 's/^Exec=//p' "$f" | head -1)"
      [[ -n "$cmdline" ]] || continue
      # Первый токен; кавычки и env-присваивания отбрасываем.
      exe="${cmdline%% *}"
      exe="${exe#\"}"; exe="${exe%\"}"
      if [[ "$exe" == "env" ]]; then
        for w in $cmdline; do
          [[ "$w" == "env" || "$w" == *=* ]] && continue
          exe="${w#\"}"; exe="${w%\"}"; break
        done
      fi
      [[ -n "$exe" ]] || continue
      case "$exe" in
        /*) [[ -x "$exe" ]] || printf '%s\t%s\n' "$f" "$exe" ;;
        *)  command -v "$exe" >/dev/null 2>&1 || printf '%s\t%s\n' "$f" "$exe" ;;
      esac
    done
  done
}

broken_desktop="$(desktop_entries)"
if [[ -n "$broken_desktop" ]]; then
  printf '%s\n' "$broken_desktop" > "$RUN_DIR/broken-desktop.txt"
  warn "ярлыки с отсутствующим Exec (не тронуты):"
  printf '%s\n' "$broken_desktop" | awk -F'\t' '{printf "    %s -> %s\n", $1, $2}'
fi

# ------------------------------------------------------------ restore + отчёт
if [[ -s "$RUN_DIR/removed.txt" ]]; then
  {
    printf '#!/usr/bin/env bash\n'
    printf '# Восстановление пакетов, удалённых cleanup.sh %s (host=%s).\n' "$ts" "$HOST"
    printf '# Конфиги из карантина возвращаются вручную (пути видны в report.md).\n'
    printf 'set -euo pipefail\n\n'
    printf 'yay -S --needed --noconfirm'
    while read -r p; do [[ -n "$p" ]] && printf ' %q' "$p"; done < "$RUN_DIR/removed.txt"
    printf '\n'
  } > "$RUN_DIR/restore.sh"
  chmod +x "$RUN_DIR/restore.sh"
fi

quarantine_size="$(du -sh "$RUN_DIR/quarantine" 2>/dev/null | awk '{print $1}' || true)"

{
  printf '# cleanup.sh %s\n\n' "$ts"
  printf -- '- host: `%s` (profile `%s`)\n' "$HOST" "$PROFILE"
  printf -- '- удалено явных пакетов: %d (%s)\n' \
    "$(wc -l < "$RUN_DIR/removed.txt")" "$(human "$total_bytes")"
  if [[ -f "$RUN_DIR/orphans.txt" ]]; then
    printf -- '- осиротевших зависимостей: %d\n' "$(wc -l < "$RUN_DIR/orphans.txt")"
  fi
  printf -- '- карантин: `%s` (%s)\n' "$RUN_DIR/quarantine" "${quarantine_size:-0}"
  printf '\n## Удалённые пакеты\n\n'
  if [[ -s "$RUN_DIR/removed.txt" ]]; then
    printf '```\n'
    cat "$RUN_DIR/removed.txt"
    printf '```\n'
  else
    printf '_в этом прогоне удаления не было_\n'
  fi
  if [[ -f "$RUN_DIR/orphans.txt" ]]; then
    printf '\n## Осиротевшие зависимости\n\n```\n'
    cat "$RUN_DIR/orphans.txt"
    printf '```\n'
  fi
  if [[ -f "$RUN_DIR/broken-desktop.txt" ]]; then
    printf '\n## Ярлыки с отсутствующим Exec\n\n'
    awk -F'\t' '{printf "- `%s` -> `%s`\n", $1, $2}' "$RUN_DIR/broken-desktop.txt"
  fi
  if [[ ${#BLOCKED[@]} -gt 0 ]]; then
    printf '\n## Оставлены\n\n'
    printf '%s\n' "${BLOCKED[@]}" | sort -u | awk -F'|' '{printf "- `%s` — %s\n", $1, $2}'
  fi
} > "$RUN_DIR/report.md"

log "готово"
info "лог и отчёт: $RUN_DIR/report.md"
if [[ -x "$RUN_DIR/restore.sh" ]]; then
  info "восстановить пакеты: $RUN_DIR/restore.sh"
fi
[[ -n "$quarantine_size" ]] && info "удалить карантин, когда всё проверено: rm -rf $RUN_DIR/quarantine"
exit 0
