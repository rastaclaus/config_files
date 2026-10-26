#!/usr/bin/env bash
#
# VPN (OpenVPN over NetworkManager) provisioning.
#
# Renders vpn/profile.nmconnection.in and installs it as a system
# NetworkManager connection in /etc/NetworkManager/system-connections/.
#
# Everything that identifies the connection — profile id, uuid, login,
# endpoints, DNS, routes and the PEM file names — comes from the gitignored
# vpn/local.env. The template in the repository is a neutral skeleton.
#
# The installed profile contains NO secrets:
#   * the OpenVPN password is not stored (password-flags=1 -> secret agent/keyring),
#   * the client key is not encrypted (cert-pass-flags=0),
#   * ca/cert/key/tls-auth live in ~/vpn (see vpn/README.md) and are only
#     referenced by path.
#
#   ./install/install_vpn.sh [options]
#
# Options:
#   --check       verify prerequisites only, make no changes
#   --dry-run     print actions, change nothing
#   -h, --help
#
set -euo pipefail

# Общие помощники (log/info/warn/die) и пути REPO/STATE_DIR.
# shellcheck source=install/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TEMPLATE="$REPO/vpn/profile.nmconnection.in"
LOCAL_ENV="$REPO/vpn/local.env"
DEFAULT_TARGET_DIR="/etc/NetworkManager/system-connections"

ok()   { printf '\033[1;32m  ok \033[0m%s\n' "$*"; }

CHECK=0
DRY_RUN=0

# Пароль OpenVPN в профиль не попадает: держим его в keyring, чтобы файл
# /etc/NetworkManager/system-connections/*.nmconnection оставался без секретов.
OPENVPN_SERVICE="org.freedesktop.NetworkManager.openvpn"

run() {
  if [[ $DRY_RUN -eq 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}

usage() { sed -n '3,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)   CHECK=1;   shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

[[ -f "$TEMPLATE" ]] || die "template not found: $TEMPLATE"

# ------------------------------------------------------------ local parameters
if [[ -f "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi

CONN_ID="${VPN_CONN_ID:-work-vpn}"
VPN_USER="${VPN_USER:-}"
VPN_REMOTE="${VPN_REMOTE:-}"
VPN_UUID="${VPN_UUID:-}"
VPN_CERT_DIR="${VPN_CERT_DIR:-$HOME/vpn/nm-openvpn}"
VPN_CA="${VPN_CA:-ca.pem}"
VPN_CERT="${VPN_CERT:-cert.pem}"
VPN_KEY="${VPN_KEY:-key.pem}"
VPN_TA="${VPN_TA:-ta.key}"
VPN_DNS="${VPN_DNS:-}"
VPN_ROUTES="${VPN_ROUTES:-}"
VPN_NEVER_DEFAULT="${VPN_NEVER_DEFAULT:-true}"
VPN_IGNORE_AUTO_DNS="${VPN_IGNORE_AUTO_DNS:-true}"
VPN_LEGACY_ID="${VPN_LEGACY_ID:-}"
VPN_LEGACY_UUID="${VPN_LEGACY_UUID:-}"

TARGET_DIR="${VPN_TARGET_DIR:-$DEFAULT_TARGET_DIR}"
UUID_STATE="$STATE_DIR/vpn-$CONN_ID.uuid"

[[ "$CONN_ID" =~ ^[A-Za-z0-9._-]+$ ]] ||
  die "VPN_CONN_ID='$CONN_ID' is not a safe connection id (letters, digits, . _ -)"
if [[ -n "$VPN_UUID" && ! "$VPN_UUID" =~ ^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$ ]]; then
  die "VPN_UUID='$VPN_UUID' is not a UUID"
fi

missing=0
if [[ -z "$VPN_USER" || "$VPN_USER" == "CHANGE_ME" ]]; then
  warn "VPN_USER is not set; copy vpn/local.env.example -> vpn/local.env"
  missing=1
fi
if [[ -z "$VPN_REMOTE" || "$VPN_REMOTE" == *example.com* ]]; then
  warn "VPN_REMOTE is not set; copy vpn/local.env.example -> vpn/local.env"
  missing=1
fi

PEM_NAMES=("$VPN_CA" "$VPN_CERT" "$VPN_KEY" "$VPN_TA")
pem_missing=0
for n in "${PEM_NAMES[@]}"; do
  if [[ ! -f "$VPN_CERT_DIR/$n" ]]; then
    warn "missing PEM: $VPN_CERT_DIR/$n"
    pem_missing=1
  fi
done

plugin_missing=0
if command -v nmcli >/dev/null 2>&1; then
  if ! pacman -Qq networkmanager-openvpn >/dev/null 2>&1; then
    warn "package 'networkmanager-openvpn' not installed"
    plugin_missing=1
  fi
  if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
    warn "NetworkManager service is not active"
  fi
else
  warn "nmcli not found (is NetworkManager installed?)"
  plugin_missing=1
fi

# --------------------------------------------------------------------- uuid
# UUID уже установленного профиля менять нельзя без последствий: секрет-агент
# NetworkManager хранит пароль привязкой к uuid. Поэтому генерируем один раз и
# кэшируем в state-каталоге (вне репозитория).
uuid_from_state=0
if [[ -z "$VPN_UUID" && -f "$UUID_STATE" ]]; then
  VPN_UUID="$(tr -d '[:space:]' < "$UUID_STATE")"
  uuid_from_state=1
  [[ -n "$VPN_UUID" ]] || die "empty uuid cache: $UUID_STATE"
fi

generate_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    cat /proc/sys/kernel/random/uuid
  fi
}

# ------------------------------------------------------------------- check mode
if [[ $CHECK -eq 1 ]]; then
  log "checking VPN prerequisites"
  info "template   : $TEMPLATE"
  info "local.env  : $LOCAL_ENV $([[ -f "$LOCAL_ENV" ]] && echo '(found)' || echo '(missing)')"
  info "connection : $CONN_ID"
  info "profile    : $TARGET_DIR/$CONN_ID.nmconnection"
  info "cert dir   : $VPN_CERT_DIR ($VPN_CA, $VPN_CERT, $VPN_KEY, $VPN_TA)"
  info "user       : ${VPN_USER:-<unset>}"
  info "remote     : ${VPN_REMOTE:-<unset>}"
  if [[ -n "$VPN_UUID" ]]; then
    info "uuid       : $VPN_UUID$( [[ $uuid_from_state -eq 1 ]] && echo ' (cached)' )"
  else
    info "uuid       : will be generated once and cached in $UUID_STATE"
  fi
  info "dns        : ${VPN_DNS:-<none>}"
  info "routes     : ${VPN_ROUTES:-<none>}"
  if [[ $missing -eq 0 && $pem_missing -eq 0 && $plugin_missing -eq 0 ]]; then
    ok "all prerequisites satisfied; run without --check to install"
    exit 0
  fi
  die "prerequisites missing (see warnings above)"
fi

# ------------------------------------------------------------------- render
if [[ -z "$VPN_UUID" ]]; then
  VPN_UUID="$(generate_uuid)"
  [[ -n "$VPN_UUID" ]] || die "could not generate a UUID"
  if [[ $DRY_RUN -eq 0 ]]; then
    run mkdir -p "$STATE_DIR"
    ( umask 077; printf '%s\n' "$VPN_UUID" > "$UUID_STATE" )
    info "generated uuid $VPN_UUID (cached in $UUID_STATE)"
  else
    info "[dry-run] would generate uuid and cache it in $UUID_STATE"
  fi
fi

ipv4_extra=""
if [[ -n "$VPN_DNS" ]]; then
  ipv4_extra+="dns=$VPN_DNS"$'\n'
  # dhcp-серверы не должны перебивать внутренние DNS из профиля
  ipv4_extra+="dns-priority=-100"$'\n'
fi
[[ "$VPN_IGNORE_AUTO_DNS" == "true" ]] && ipv4_extra+="ignore-auto-dns=true"$'\n'
[[ "$VPN_NEVER_DEFAULT" == "true" ]] && ipv4_extra+="never-default=true"$'\n'
route_no=0
for route in $VPN_ROUTES; do
  [[ "$route" == *,* ]] || die "VPN_ROUTES entry '$route' is not <network/prefix>,<gateway>[,<metric>]"
  route_no=$((route_no + 1))
  ipv4_extra+="route$route_no=$route"$'\n'
done

render() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "@IPV4_EXTRA@" ]]; then
      printf '%s' "$ipv4_extra"
      continue
    fi
    line="${line//@CONN_ID@/$CONN_ID}"
    line="${line//@UUID@/$VPN_UUID}"
    line="${line//@USER@/$VPN_USER}"
    line="${line//@REMOTE@/$VPN_REMOTE}"
    line="${line//@CERTDIR@/$VPN_CERT_DIR}"
    line="${line//@CA@/$VPN_CA}"
    line="${line//@CERT@/$VPN_CERT}"
    line="${line//@KEY@/$VPN_KEY}"
    line="${line//@TA@/$VPN_TA}"
    printf '%s\n' "$line"
  done < "$TEMPLATE"
}

TARGET="$TARGET_DIR/$CONN_ID.nmconnection"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
render > "$TMP"

# --------------------------------------------------------------- existing files
# Профили, которые считаются «нашими»: совпадение по id/uuid, плюс явно
# указанный старый профиль из local.env (VPN_LEGACY_ID/VPN_LEGACY_UUID).
esc_re() { printf '%s' "$1" | sed 's/[][\\.^$*+?(){}|]/\\&/g'; }

patterns=("^id=$(esc_re "$CONN_ID")$" "^uuid=$(esc_re "$VPN_UUID")$")
[[ -n "$VPN_LEGACY_ID" ]] && patterns+=("^id=$(esc_re "$VPN_LEGACY_ID")$")
[[ -n "$VPN_LEGACY_UUID" ]] && patterns+=("^uuid=$(esc_re "$VPN_LEGACY_UUID")$")

grep_args=()
for p in "${patterns[@]}"; do grep_args+=(-e "$p"); done

mapfile -t existing < <(sudo grep -lE "${grep_args[@]}" "$TARGET_DIR"/* 2>/dev/null || true)

# Старые OpenVPN-профили с другими id: не трогаем, но подсказываем, как снести.
mapfile -t other_vpn < <(sudo grep -lF "service-type=$OPENVPN_SERVICE" \
  "$TARGET_DIR"/*.nmconnection 2>/dev/null || true)
foreign=()
for f in "${other_vpn[@]:-}"; do
  [[ -n "$f" ]] || continue
  ours=0
  for e in "${existing[@]:-}"; do [[ "$f" == "$e" ]] && ours=1; done
  [[ $ours -eq 1 ]] || foreign+=("$f")
done
if [[ ${#foreign[@]} -gt 0 ]]; then
  warn "other OpenVPN profiles are installed; they are left alone:"
  for f in "${foreign[@]}"; do
    info "  ${f##*/} (id=$(sudo awk -F= '/^id=/{print $2; exit}' "$f" 2>/dev/null || echo '?'))"
  done
  info "  to replace one, set VPN_LEGACY_ID/VPN_LEGACY_UUID in vpn/local.env"
fi

BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
backup_count=0
for f in "${existing[@]:-}"; do
  [[ -n "$f" ]] || continue
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '    [dry-run] backup %s -> %s/\n' "$f" "$BACKUP"
  else
    mkdir -p "$BACKUP"
    # redirect runs as the user, so the backup ends up user-owned
    sudo cat "$f" > "$BACKUP/$(basename "$f")"
    info "backed up $f -> $BACKUP/$(basename "$f")"
  fi
  run sudo rm -f "$f"
  backup_count=$((backup_count + 1))
done

# ------------------------------------------------------------------- install
log "installing $TARGET"
run sudo install -m 600 -o root -g root "$TMP" "$TARGET"

if [[ $DRY_RUN -eq 1 ]]; then
  info "would reload NetworkManager connections"
else
  log "reloading NetworkManager"
  sudo nmcli connection reload || warn "nmcli connection reload failed"
  if nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$CONN_ID"; then
    ok "connection '$CONN_ID' is available"
  else
    warn "connection '$CONN_ID' not listed; check $(basename "$TARGET")"
  fi
fi

if [[ $backup_count -gt 0 ]]; then
  log "previous profiles backed up in $BACKUP"
fi
log "done."
