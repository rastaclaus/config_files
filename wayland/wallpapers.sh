#!/usr/bin/env bash
#
# Set a random wallpaper on every active output.
#
# Works under both sway (via swaymsg) and niri (via niri msg). Wallpapers are
# drawn with swaybg, which runs on both compositors.
#
# On a multi-monitor setup with a matching aspect ratio, a single image is
# sliced across the outputs so the picture spans them seamlessly (no
# duplication, no distortion). For anything else the image is shown per output.
#
# Override the directory with WALLPAPER_DIR=<path>.
# Override the letterbox/gap colour with WALLPAPER_BG=<rrggbb>.
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Wallpapers}"
WALLPAPER_BG="${WALLPAPER_BG:-000000}"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "wallpapers: no such directory: $WALLPAPER_DIR" >&2
    exit 1
fi

mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

if (( ${#images[@]} == 0 )); then
    echo "wallpapers: no images found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Detect the running compositor and collect the geometry of its active outputs.
#
# Do not trust the mere presence of SWAYSOCK/NIRI_SOCKET: a stale SWAYSOCK can
# linger in the systemd user environment after a sway session (sway imports it
# and never unsets it; niri-session's `import-environment` then pulls it back
# in), which would make us pick the wrong compositor and print a scary
# "Unable to connect" error at startup. Require the socket to actually exist.
#
# Each line is: name x y width height phys_width phys_height, where x/y/width/
# height are logical coordinates (used for layout) and phys_* are the physical
# pixels of the current mode (used as the render target size).
if [[ -n "${NIRI_SOCKET:-}" && -S "${NIRI_SOCKET}" ]]; then
    # niri reports an output as active when it is mapped to a logical output;
    # an unmapped/disabled output has "logical": null (there is no "active" key).
    mapfile -t geom < <(niri msg --json outputs | jq -r '
        to_entries[]
        | select(.value.logical != null)
        | .value as $o
        | .value.logical as $l
        | .value.modes[.value.current_mode] as $m
        | [$o.name, $l.x, $l.y, $l.width, $l.height, $m.width, $m.height]
        | map(tostring) | join(" ")')
elif [[ -n "${SWAYSOCK:-}" && -S "${SWAYSOCK}" ]]; then
    mapfile -t geom < <(swaymsg -t get_outputs | jq -r '
        .[]
        | select(.active)
        | [.name, .rect.x, .rect.y, .rect.width, .rect.height,
           .current_mode.width, .current_mode.height]
        | map(tostring) | join(" ")')
else
    echo "wallpapers: neither sway nor niri is running" >&2
    exit 1
fi

if (( ${#geom[@]} == 0 )); then
    echo "wallpapers: no active outputs" >&2
    exit 1
fi

names=() xs=() ys=() ws=() hs=() pws=() phs=()
for line in "${geom[@]}"; do
    read -r n x y w h pw ph <<<"$line"
    names+=("$n"); xs+=("$x"); ys+=("$y"); ws+=("$w"); hs+=("$h")
    pws+=("$pw"); phs+=("$ph")
done

# Bounding box of the whole desktop in logical coordinates.
X0="${xs[0]}"; Y0="${ys[0]}"
X1=$(( xs[0] + ws[0] )); Y1=$(( ys[0] + hs[0] ))
for i in "${!names[@]}"; do
    if (( xs[i] < X0 )); then X0="${xs[i]}"; fi
    if (( ys[i] < Y0 )); then Y0="${ys[i]}"; fi
    if (( xs[i] + ws[i] > X1 )); then X1=$(( xs[i] + ws[i] )); fi
    if (( ys[i] + hs[i] > Y1 )); then Y1=$(( ys[i] + hs[i] )); fi
done
W=$(( X1 - X0 ))
H=$(( Y1 - Y0 ))

image="${images[RANDOM % ${#images[@]}]}"

# Decide whether the picture can span all outputs without distortion: only when
# its aspect ratio matches the desktop bounding box (1% tolerance) and we have
# something to slice it with.
span=0
IW=0; IH=0
if (( ${#names[@]} >= 2 )) && command -v magick >/dev/null 2>&1; then
    if read -r IW IH < <(identify -format '%w %h\n' "$image" 2>/dev/null) \
        && [[ -n "$IW" && -n "$IH" ]]; then
        if awk -v iw="$IW" -v ih="$IH" -v w="$W" -v h="$H" \
            'BEGIN { d = (iw/ih) / (w/h); if (d < 1) d = 1/d; exit !(d <= 1.01) }'; then
            span=1
        fi
    fi
fi

pkill -x swaybg 2>/dev/null || true

# swaybg's chatter is captured so it does not flash across the console at
# login; it is shown only if swaybg fails to come up.
log="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/wallpapers.log"

if (( span )); then
    # Slice the picture by the outputs' layout, resize each slice to the exact
    # physical size of its output, then hand every slice to its own output with
    # a single swaybg process. Each slice is already at the target resolution,
    # so --mode stretch introduces no distortion.
    tmp="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/wallpapers.d"
    rm -rf "$tmp"
    mkdir -p "$tmp"

    args=(-m stretch -c "$WALLPAPER_BG")
    for i in "${!names[@]}"; do
        read -r cx cw cy ch < <(awk -v x="${xs[i]}" -v y="${ys[i]}" \
            -v ox="$X0" -v oy="$Y0" -v W="$W" -v H="$H" \
            -v IW="$IW" -v IH="$IH" -v w="${ws[i]}" -v h="${hs[i]}" 'BEGIN {
                cx = int((x - ox) * IW / W + 0.5);
                cy = int((y - oy) * IH / H + 0.5);
                cw = int(w * IW / W + 0.5);
                ch = int(h * IH / H + 0.5);
                if (cx < 0) cx = 0;
                if (cy < 0) cy = 0;
                if (cw < 1) cw = 1;
                if (ch < 1) ch = 1;
                if (cx + cw > IW) cw = IW - cx;
                if (cy + ch > IH) ch = IH - cy;
                printf "%d %d %d %d\n", cx, cw, cy, ch;
            }')
        out="$tmp/${names[i]}.png"
        magick "$image" -crop "${cw}x${ch}+${cx}+${cy}" +repage \
            -resize "${pws[i]}x${phs[i]}!" "$out"
        args+=(-o "${names[i]}" -i "$out")
    done

    swaybg "${args[@]}" >"$log" 2>&1 &
else
    # A single swaybg with no -o applies the image to every output (including
    # ones plugged in later). Unlike one process per output, it does not log
    # "Could not find config for output ..." for the outputs it was not told
    # about.
    rm -rf "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/wallpapers.d"
    swaybg -i "$image" --mode fill >"$log" 2>&1 &
fi
sbg=$!

sleep 0.3
if ! kill -0 "$sbg" 2>/dev/null; then
    cat "$log" >&2
    exit 1
fi
