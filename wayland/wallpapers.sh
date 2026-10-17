#!/usr/bin/env bash
#
# Set a wallpaper on every active output, chosen from the set that fits the
# current theme.
#
# Wallpapers are named desktop_<res>_<n>_<light|dark>.<ext>. The mode comes from
# ~/.local/state/dotfiles/background-mode (written by theme-sync), so a dark
# session never gets a bright picture and vice versa. Files without a _light or
# _dark suffix are ignored while a mode is known, and used as a fallback when
# nothing matches.
#
# The wallpaper is drawn with awww (awww-daemon) when it is available; swaybg
# is kept as a fallback for systems without awww.
#
# The running compositor is still detected (niri via `niri msg`, sway via
# `swaymsg`): awww only reports output names and dimensions, not their
# positions, and we need the positions to slice a wide picture seamlessly
# across monitors. awww then does the actual drawing.
#
# On a multi-monitor setup with a matching aspect ratio, a single image is
# sliced across the outputs so the picture spans them seamlessly (no
# duplication, no distortion). For anything else the image is shown per output.
# The slices are cached in <wallpaper dir>/.slices/<layout>/ as
# left_<name>.jpg / right_<name>.jpg, so the next time the same picture is
# picked for the same monitor layout the halves are used as they are, without
# touching ImageMagick again. A different layout gets its own directory and the
# slices are rebuilt.
#
# Override the directory with WALLPAPER_DIR=<path>.
# Override the letterbox/gap colour with WALLPAPER_BG=<rrggbb>.
# Force a mode with WALLPAPER_MODE=dark|light.
# Force one picture with WALLPAPER_IMAGE=<path>.
# Disable the slice cache with WALLPAPER_NO_SLICES=1.
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Wallpapers}"
WALLPAPER_BG="${WALLPAPER_BG:-000000}"
# Hard-coded like in wayland/theme-sync: alacritty/rofi cannot expand variables
# in import paths, so the state directory has a fixed location.
STATE_DIR="$HOME/.local/state/dotfiles"
SLICE_DIR="$WALLPAPER_DIR/.slices"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "wallpapers: no such directory: $WALLPAPER_DIR" >&2
    exit 1
fi

# Slices of older runs live in the same tree; they are never pick candidates.
mapfile -t all < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    ! -name 'left_*' ! -name 'right_*' | sort)

if (( ${#all[@]} == 0 )); then
    echo "wallpapers: no images found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Current theme: explicit override, then the state file theme-sync writes, then
# darkman. Anything else means "no filter".
mode="${WALLPAPER_MODE:-}"
if [[ -z $mode && -r "$STATE_DIR/background-mode" ]]; then
    mode="$(<"$STATE_DIR/background-mode")"
fi
if [[ -z $mode ]] && command -v darkman >/dev/null 2>&1; then
    mode="$(darkman get 2>/dev/null || true)"
fi
mode="${mode//[[:space:]]/}"
case "$mode" in
    dark|light) ;;
    *) mode="" ;;
esac

images=("${all[@]}")
if [[ -n $mode ]]; then
    mode_images=()
    for f in "${all[@]}"; do
        case "${f##*/}" in
            *"_${mode}".*) mode_images+=("$f") ;;
        esac
    done
    if (( ${#mode_images[@]} > 0 )); then
        images=("${mode_images[@]}")
    else
        echo "wallpapers: no *_${mode}.* wallpapers in $WALLPAPER_DIR; using all" >&2
    fi
fi

# Pick the drawing backend up front. awww needs both binaries present.
if command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
    backend=awww
else
    backend=swaybg
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

if [[ -n "${WALLPAPER_IMAGE:-}" ]]; then
    image="${WALLPAPER_IMAGE/#\~/$HOME}"
    if [[ ! -f "$image" ]]; then
        echo "wallpapers: WALLPAPER_IMAGE is not a file: $image" >&2
        exit 1
    fi
else
    image="${images[RANDOM % ${#images[@]}]}"
fi

# ---------------------------------------------------------------------------
# Slice cache
#
# The key is the exact output layout, sorted by output name so that the
# compositor's ordering does not matter: "HDMI-A-1_2560x1440+0+0~DP-1_...".
# A monitor being added, removed, moved or changing resolution produces a new
# key, so stale halves are never reused.
# ---------------------------------------------------------------------------
sig=()
for i in "${!names[@]}"; do
    sig+=("${names[i]}_${pws[i]}x${phs[i]}+${xs[i]}+${ys[i]}")
done
mapfile -t sig < <(printf '%s\n' "${sig[@]}" | sort)
layout="$(IFS='~'; printf '%s' "${sig[*]}")"

# Per-output prefix for a slice file: left/right when two outputs sit next to
# each other, otherwise the output name (left/right would be a lie).
prefixes=()
if (( ${#names[@]} == 2 )) && (( ys[0] == ys[1] && xs[0] != xs[1] )); then
    if (( xs[0] < xs[1] )); then
        prefixes[0]=left; prefixes[1]=right
    else
        prefixes[0]=right; prefixes[1]=left
    fi
else
    for i in "${!names[@]}"; do
        prefixes[i]="$(printf '%s' "${names[i]}" | tr -c 'A-Za-z0-9._-' '_')"
    done
fi

slice_path() { # slice_path <output index> -> file holding that output's half
    local base="${image##*/}"
    base="${base%.*}"
    printf '%s/%s/%s_%s.jpg' "$SLICE_DIR" "$layout" "${prefixes[$1]}" "$base"
}

slice_fresh() { # slice_fresh <file> <phys width> <phys height>
    local s=$1 pw=$2 ph=$3 got
    [[ -f $s ]] || return 1
    # A wallpapers.sh run always rewrites the source, never the slice, so this
    # only catches a picture that was replaced under the same name.
    [[ $s -nt $image ]] || return 1
    if command -v identify >/dev/null 2>&1; then
        got=$(identify -format '%wx%h' "${s}[0]" 2>/dev/null || true)
        [[ $got == "${pw}x${ph}" ]] || return 1
    fi
    return 0
}

crop_rect() { # crop_rect <output index> -> "x y w h" inside the source picture
    awk -v x="${xs[$1]}" -v y="${ys[$1]}" \
        -v ox="$X0" -v oy="$Y0" -v W="$W" -v H="$H" \
        -v IW="$IW" -v IH="$IH" -v w="${ws[$1]}" -v h="${hs[$1]}" 'BEGIN {
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
        }'
}

slices_fresh() {
    local i
    for i in "${!names[@]}"; do
        slice_fresh "$(slice_path "$i")" "${pws[i]}" "${phs[i]}" || return 1
    done
    return 0
}

make_slices() {
    local i s cx cw cy ch tmp_slice
    # Normally IW/IH are known from the aspect check; a cache file disappearing
    # between the check and this call is the only way they can be missing.
    if (( IW == 0 || IH == 0 )); then
        read -r IW IH < <(identify -format '%w %h\n' "$image" 2>/dev/null || true)
        if [[ -z "$IW" || -z "$IH" ]]; then
            echo "wallpapers: cannot read the size of $image" >&2
            exit 1
        fi
    fi
    mkdir -p "$SLICE_DIR/$layout"
    for i in "${!names[@]}"; do
        s="$(slice_path "$i")"
        if slice_fresh "$s" "${pws[i]}" "${phs[i]}"; then
            continue
        fi
        read -r cx cw cy ch < <(crop_rect "$i")
        # Crop from the original and resize to the exact physical size of the
        # output, so the slice needs no further scaling. Written under a
        # temporary name and renamed, so a killed run leaves no half file.
        tmp_slice="$s.tmp.$$"
        if ! magick "$image" -crop "${cw}x${ch}+${cx}+${cy}" +repage \
                -resize "${pws[i]}x${phs[i]}!" -strip -quality 92 "$tmp_slice"; then
            rm -f "$tmp_slice"
            echo "wallpapers: failed to slice $image for output ${names[i]}" >&2
            exit 1
        fi
        mv -f "$tmp_slice" "$s"
    done
}

# Decide whether the picture can span all outputs without distortion: only when
# its aspect ratio matches the desktop bounding box (1% tolerance). The aspect is
# only needed to *create* slices: a fresh cached pair is used as it is, so a
# machine without ImageMagick can still span and a cache hit costs nothing.
IW=0; IH=0; aspect_ok=0
if (( ${#names[@]} >= 2 )) && command -v identify >/dev/null 2>&1; then
    if read -r IW IH < <(identify -format '%w %h\n' "$image" 2>/dev/null) \
        && [[ -n "$IW" && -n "$IH" ]]; then
        if awk -v iw="$IW" -v ih="$IH" -v w="$W" -v h="$H" \
            'BEGIN { d = (iw/ih) / (w/h); if (d < 1) d = 1/d; exit !(d <= 1.01) }'; then
            aspect_ok=1
        fi
    fi
fi

slice=0
if (( ${#names[@]} >= 2 )); then
    if [[ ${WALLPAPER_NO_SLICES:-0} == 1 ]]; then
        # No cache next to the wallpapers: slice into the runtime dir, like the
        # pre-cache version did. Kept on disk on purpose — awww re-reads the
        # file when an output is reconnected.
        SLICE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/wallpapers.d"
        if (( aspect_ok )) && command -v magick >/dev/null 2>&1; then
            slice=1
            rm -rf "$SLICE_DIR/$layout"   # no cache: slice from scratch
        fi
    elif slices_fresh; then
        slice=1                      # cached halves: nothing to compute
    elif (( aspect_ok )) && command -v magick >/dev/null 2>&1; then
        slice=1                      # first time for this picture: slice it
    fi
fi

# Backend chatter is captured so it does not flash across the console at login;
# it is shown only if the backend fails to come up.
log="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/wallpapers.log"

# Make sure awww's daemon is running: the client never starts it on its own.
# A live daemon answers `awww query`; if it does not, spawn one and wait for it.
if [[ $backend == awww ]] && ! awww query >/dev/null 2>&1; then
    awww-daemon >"$log" 2>&1 &
    daemon=$!
    for (( i = 0; i < 50; i++ )); do
        awww query >/dev/null 2>&1 && break
        kill -0 "$daemon" 2>/dev/null || break
        sleep 0.1
    done
    if ! awww query >/dev/null 2>&1; then
        echo "wallpapers: awww-daemon failed to start; falling back to swaybg" >&2
        cat "$log" >&2 || true
        backend=swaybg
    fi
fi

# Drop any swaybg left over from a previous run (or from the fallback path) so
# it cannot fight awww for the background layer.
pkill -x swaybg 2>/dev/null || true

if [[ $backend == awww ]]; then
    if (( slice )); then
        make_slices
        # Every half is already at the target resolution, so --resize stretch
        # introduces no distortion.
        for i in "${!names[@]}"; do
            if ! awww img -o "${names[i]}" --resize stretch \
                --transition-type none "$(slice_path "$i")" >"$log" 2>&1; then
                echo "wallpapers: awww img failed for output ${names[i]}" >&2
                cat "$log" >&2
                exit 1
            fi
        done
    else
        # One image for every output (including ones plugged in later).
        if ! awww img "$image" --resize crop --fill-color "$WALLPAPER_BG" \
            --transition-type none >"$log" 2>&1; then
            echo "wallpapers: awww img failed" >&2
            cat "$log" >&2
            exit 1
        fi
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Fallback: swaybg, used when awww is not installed or its daemon failed.
# ---------------------------------------------------------------------------
if (( slice )); then
    make_slices
    args=(-m stretch -c "$WALLPAPER_BG")
    for i in "${!names[@]}"; do
        args+=(-o "${names[i]}" -i "$(slice_path "$i")")
    done
    swaybg "${args[@]}" >"$log" 2>&1 &
else
    # A single swaybg with no -o applies the image to every output (including
    # ones plugged in later). Unlike one process per output, it does not log
    # "Could not find config for output ..." for the outputs it was not told
    # about.
    swaybg -i "$image" --mode fill >"$log" 2>&1 &
fi
sbg=$!

sleep 0.3
if ! kill -0 "$sbg" 2>/dev/null; then
    cat "$log" >&2
    exit 1
fi
