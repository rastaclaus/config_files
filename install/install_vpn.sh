#!/usr/bin/env bash
#
# VPN (ntech / OpenVPN over NetworkManager) provisioning.
#
# Renders vpn/ntech.nmconnection.in and installs it as a system
# NetworkManager connection in /etc/NetworkManager/system-connections/.
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

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO/vpn/ntech.nmconnection.in"
LOCAL_ENV="$REPO/vpn/local.env"
TARGET_DIR="/etc/NetworkManager/system-connections"
TARGET="$TARGET_DIR/ntech.nmconnection"
CONN_ID="ntech"
CONN_UUID="266c4ebc-5eb0-4976-b821-4c0941bd1947"

CHECK=0
DRY_RUN=0

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok \033[0m%s\n' "$*"; }
warn() { printf '\033[1;33m warn \033[0m%s\n' "$*" >&2; }
die()  { printf '\033[1;31merror \033[0m%s\n' "$*" >&2; exit 1; }

run() {
  if [[ $DRY_RUN -eq 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}

usage() { sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

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

VPN_USER="${VPN_USER:-}"
VPN_REMOTE="${VPN_REMOTE:-}"
VPN_CERT_DIR="${VPN_CERT_DIR:-$HOME/vpn/nm-openvpn}"

missing=0
if [[ -z "$VPN_USER" || "$VPN_USER" == "CHANGE_ME" ]]; then
  warn "VPN_USER is not set; copy vpn/local.env.example -> vpn/local.env"
  missing=1
fi
if [[ -z "$VPN_REMOTE" || "$VPN_REMOTE" == *example.com* ]]; then
  warn "VPN_REMOTE is not set; copy vpn/local.env.example -> vpn/local.env"
  missing=1
fi

PEM_NAMES=(ashestopalov-ca.pem ashestopalov-cert.pem ashestopalov-key.pem ashestopalov-tls-auth.pem)
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

# ------------------------------------------------------------------- check mode
if [[ $CHECK -eq 1 ]]; then
  log "checking VPN prerequisites"
  info "template   : $TEMPLATE"
  info "local.env  : $LOCAL_ENV $([[ -f "$LOCAL_ENV" ]] && echo '(found)' || echo '(missing)')"
  info "cert dir   : $VPN_CERT_DIR"
  info "user       : ${VPN_USER:-<unset>}"
  info "remote     : ${VPN_REMOTE:-<unset>}"
  if [[ $missing -eq 0 && $pem_missing -eq 0 && $plugin_missing -eq 0 ]]; then
    ok "all prerequisites satisfied; run without --check to install"
    exit 0
  fi
  die "prerequisites missing (see warnings above)"
fi

# ------------------------------------------------------------------- render
esc() { printf '%s' "$1" | sed -e 's/[&\\|]/\\&/g'; }

render() {
  sed -e "s|@CERTDIR@|$(esc "$VPN_CERT_DIR")|g" \
      -e "s|@USER@|$(esc "$VPN_USER")|g" \
      -e "s|@REMOTE@|$(esc "$VPN_REMOTE")|g" \
      "$TEMPLATE"
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
render > "$TMP"

# --------------------------------------------------------------- existing files
# Any on-disk profile with our id/uuid (incl. the legacy "ntech (openvpn).nmconnection").
mapfile -t existing < <(sudo grep -rlE "^id=${CONN_ID}$|^uuid=${CONN_UUID}$" "$TARGET_DIR" 2>/dev/null || true)

BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
backup_count=0
for f in "${existing[@]:-}"; do
  [[ -z "$f" ]] && continue
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
  if nmcli -t -f NAME connection show 2>/dev/null | grep -qx "$CONN_ID"; then
    ok "connection '$CONN_ID' is available"
  else
    warn "connection '$CONN_ID' not listed; check $(basename "$TARGET")"
  fi
fi

if [[ $backup_count -gt 0 ]]; then
  log "previous profiles backed up in $BACKUP"
fi
log "done."
