# VPN (OpenVPN over NetworkManager)

This directory holds the **non-secret skeleton** of an OpenVPN connection
managed by NetworkManager. The template in the repository is neutral: every
value that identifies the connection comes from a gitignored local file.

| item                                   | where it lives                    | committed? |
|----------------------------------------|-----------------------------------|------------|
| connection profile template            | `vpn/profile.nmconnection.in`     | yes        |
| local params (id, login, endpoints, DNS/routes, PEM names) | `vpn/local.env` | no (gitignored) |
| `ca/cert/key/tls-auth` PEM files       | `~/vpn/nm-openvpn/`               | no         |
| OpenVPN password                       | system secret agent (keyring)     | no         |

The installed profile stores **no secrets**:

* `password-flags=1` — the account password is kept by the secret agent
  (keyring) and typed on first connect, never written into the profile;
* `cert-pass-flags=0` — the client key is not passphrase-protected;
* `ca`/`cert`/`key`/`ta` are only *paths* into the certificate directory.

## Setup

1. Put the PEM files in place (copied from a machine that has them). The
   default names are `ca.pem`, `cert.pem`, `key.pem`, `ta.key`; any other names
   work too, point `VPN_CA`/`VPN_CERT`/`VPN_KEY`/`VPN_TA` at them:

   ```
   ~/vpn/nm-openvpn/ca.pem
   ~/vpn/nm-openvpn/cert.pem
   ~/vpn/nm-openvpn/key.pem
   ~/vpn/nm-openvpn/ta.key
   ```

2. Create your local, non-committed parameters:

   ```
   cp vpn/local.env.example vpn/local.env
   chmod 600 vpn/local.env
   $EDITOR vpn/local.env   # VPN_USER, VPN_REMOTE, optionally the rest
   ```

3. Verify and install:

   ```
   ./install/install_vpn.sh --check
   ./install/install_vpn.sh            # writes /etc/NetworkManager/system-connections/<id>.nmconnection
   ```

   The installer replaces any existing profile with the same `id`/`uuid` and
   backs it up to `~/.dotfiles-backup-<timestamp>/` first.

Connect with `nmcli connection up work-vpn` (or whatever `VPN_CONN_ID` is).

## What comes from `vpn/local.env`

| variable            | default                     | meaning |
|---------------------|-----------------------------|---------|
| `VPN_CONN_ID`       | `work-vpn`                  | connection id, profile file name, `nmcli connection up <id>` |
| `VPN_USER`          | — (required)                | OpenVPN account name (`username=`) |
| `VPN_REMOTE`        | — (required)                | comma-separated `host:port` endpoints |
| `VPN_UUID`          | generated once              | profile UUID, cached in `~/.local/state/dotfiles/vpn-<id>.uuid` |
| `VPN_CERT_DIR`      | `$HOME/vpn/nm-openvpn`      | directory with the PEM files |
| `VPN_CA`/`_CERT`/`_KEY`/`_TA` | `ca.pem`/`cert.pem`/`key.pem`/`ta.key` | PEM file names inside that directory |
| `VPN_DNS`           | —                           | `;`-separated DNS servers pushed by the profile |
| `VPN_ROUTES`        | —                           | space-separated `network/prefix,gateway[,metric]` routes |
| `VPN_NEVER_DEFAULT` | `true`                      | keep the VPN off the default route |
| `VPN_IGNORE_AUTO_DNS` | `true`                    | ignore DNS servers offered by the VPN server |
| `VPN_LEGACY_ID`/`_UUID` | —                       | an older profile to back up and remove |
| `VPN_TARGET_DIR`    | `/etc/NetworkManager/system-connections` | override for tests |

## DNS and routes

`VPN_DNS` and `VPN_ROUTES` are rendered into the `[ipv4]` section. With both
unset the profile only carries what the server pushes. Example:

```
VPN_DNS="10.0.0.53;10.0.0.54"
VPN_ROUTES="10.0.0.0/8,10.10.0.1,50 192.0.2.0/24,10.10.0.1,50"
#VPN_NEVER_DEFAULT="false"     # let the VPN become the default route
```

A DNS list also sets `dns-priority=-100`, so these resolvers win over the ones
handed out by DHCP.

## Profile id, UUID and the keyring

NetworkManager stores the saved OpenVPN password in the secret agent keyed by
the profile UUID. The installer therefore generates a UUID once and caches it in
`~/.local/state/dotfiles/vpn-<id>.uuid`; changing the id or deleting that file
means typing the password again. `VPN_UUID` pins it explicitly.

## Replacing a profile installed from an older template

If a connection from an earlier version of this skeleton is still installed,
the installer does not know about it. Set its identifiers in `vpn/local.env`:

```
VPN_LEGACY_ID="<old id>"
VPN_LEGACY_UUID="<old uuid>"
```

`nmcli -f NAME,UUID connection show` lists both. The installer backs the old
profile up and removes it, so the machine does not accumulate dead connections.
Other OpenVPN profiles found in the target directory are only reported, never
touched.

## Rotating certificates

Replace the PEM files in `~/vpn/nm-openvpn/` and re-run
`./install/install_vpn.sh`. Certificate *paths* in the profile stay the same,
so no profile changes are needed.
