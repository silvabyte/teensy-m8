#!/usr/bin/env bash
# Route the M8's USB audio capture into your default PipeWire sink so you can
# hear what the tracker is playing. Runs in the foreground; Ctrl+C to stop.
#
# Implementation: pw-loopback creates a virtual capture/playback pair. We pin
# the capture side to the M8 source via target.object; the playback side stays
# unpinned so it follows whatever your default sink is (speakers / headphones /
# Bluetooth -- swap them freely while this runs).

set -euo pipefail

for bin in pw-loopback pactl wpctl; do
    command -v "$bin" >/dev/null || { echo "Missing: $bin (install pipewire + pipewire-pulse)"; exit 1; }
done

# Find the M8 audio source. We match against both node.name and the friendly
# description, since the Teensy's node.name may not contain "M8" verbatim
# while the description always does ("M8 Analog Stereo").
find_m8_source() {
    pactl list sources 2>/dev/null | awk '
        /^Source #/         { name=""; desc="" }
        /^\tName: /         { name=$2 }
        /^\tDescription: /  { sub(/^\tDescription: /, ""); desc=$0 }
        /^$/                {
            if (tolower(name desc) ~ /m8|teensy/) { print name; exit }
        }
    '
}

SRC_NAME="$(find_m8_source || true)"
if [[ -z "$SRC_NAME" ]]; then
    echo "Could not find an M8 / Teensy audio source."
    echo ""
    echo "Plugged in? Try: lsusb | grep 16c0"
    echo "Available sources:"
    wpctl status | awk '/Sources:/,/Sinks:/'
    exit 1
fi

echo ">> M8 source: $SRC_NAME"
echo ">> Looping to current default sink. Ctrl+C to stop."
echo ""

# Notes on the props:
#   target.object on the capture side pins it to the M8 source.
#   No target on the playback side -> follows default sink (speakers/BT/etc).
#   node.description shows up in pavucontrol / Helvum for easy identification.
exec pw-loopback \
    --capture-props="target.object=$SRC_NAME node.name=m8-monitor-capture node.description=M8 Monitor (capture)" \
    --playback-props="node.name=m8-monitor-playback node.description=M8 Monitor (playback)"
