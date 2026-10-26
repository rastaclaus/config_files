#!/usr/bin/env bash
#
# GTK / xdg-desktop-portal: adw-gtk3 и color-scheme.
#
# color-scheme — это же сигнал для приложений, которые сами следят за системной
# темой (ghostty через libadwaita, Qt через GTK platform theme, портал).
set -euo pipefail

# shellcheck source=wayland/theme-hook-lib.sh
REPO="${REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)}"
. "$REPO/wayland/theme-hook-lib.sh"

mode="${1:?usage: $0 dark|light}"

theme_have gsettings || exit 0

if [[ $mode == dark ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
else
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
fi
