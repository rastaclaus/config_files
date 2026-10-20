#!/usr/bin/env bash
#
# Run a tray applet only once a StatusNotifier host is available.
#
#   wait-sni.sh nm-applet --indicator
#   wait-sni.sh blueman-applet
#
# Why: both nm-applet (libappindicator) and blueman decide their icon backend
# once, at startup. When no StatusNotifierWatcher on the session bus answers,
# libappindicator falls back to a legacy GtkStatusIcon and blueman raises
# IndicatorNotAvailable and drops to the same GtkStatusIcon fallback (priority
# 0). Neither re-registers later, and a GtkStatusIcon is an XEmbed icon that
# nothing can display on Wayland — so the applet keeps running with no icon
# anywhere.
#
# The bar (ironbar, or waybar after a rollback) claims org.kde.StatusNotifierWatcher
# a moment after being spawned, so a plain "spawn at startup" races it and
# usually loses. Waiting here makes the order irrelevant.
#
# The wait is bounded: after ~10s the applet starts anyway, so a missing or
# broken bar never blocks startup.
set -u

for _ in $(seq 100); do
    busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
    sleep 0.1
done

exec "$@"
