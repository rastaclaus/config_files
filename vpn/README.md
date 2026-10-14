# VPN (ntech / OpenVPN over NetworkManager)

This directory holds the **non-secret skeleton** of the `ntech` VPN profile.
All sensitive material stays outside the repo:

| item                                   | where it lives                    | committed? |
|----------------------------------------|-----------------------------------|------------|
| connection profile template            | `vpn/ntech.nmconnection.in`       | yes        |
| local params (login/endpoints/paths)   | `vpn/local.env`                   | no (gitignored) |
| `ca/cert/key/tls-auth` PEM files       | `~/vpn/nm-openvpn/`               | no         |
| OpenVPN password                       | system secret agent (keyring)     | no         |

The installed NetworkManager profile stores **no secrets**:

* `password-flags=1` — the account password is kept by the secret agent
  (keyring) and typed on first connect, never written into the profile;
* `cert-pass-flags=0` — the client key is not passphrase-protected;
* `ca`/`cert`/`key`/`ta` are only *paths* into `~/vpn/nm-openvpn/`.

## Setup

1. Put the PEM files in place (copied from a machine that has them):

   ```
   ~/vpn/nm-openvpn/ashestopalov-ca.pem
   ~/vpn/nm-openvpn/ashestopalov-cert.pem
   ~/vpn/nm-openvpn/ashestopalov-key.pem
   ~/vpn/nm-openvpn/ashestopalov-tls-auth.pem
   ```

2. Create your local, non-committed parameters:

   ```
   cp vpn/local.env.example vpn/local.env
   $EDITOR vpn/local.env   # VPN_USER, VPN_REMOTE, optional VPN_CERT_DIR
   ```

3. Verify and install:

   ```
   ./install/install_vpn.sh --check
   ./install/install_vpn.sh            # writes /etc/NetworkManager/system-connections/ntech.nmconnection
   ```

   The installer replaces any existing profile with the same `id`/`uuid`
   (including the legacy `ntech (openvpn).nmconnection`) and backs it up to
   `~/.dotfiles-backup-<timestamp>/` first.

Connect with `nmcli connection up ntech`.

## Rotating certificates

Replace the PEM files in `~/vpn/nm-openvpn/` and re-run
`./install/install_vpn.sh`. Certificate *paths* in the profile stay the same,
so no profile changes are needed.
