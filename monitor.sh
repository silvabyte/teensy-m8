#!/usr/bin/env bash
# Route the M8's USB audio capture into your default PipeWire sink so you can
# hear what the tracker is playing. Runs in the foreground; Ctrl+C to stop.
#
# Implementation: pw-loopback creates a virtual capture/playback pair. We pin
# the capture side to the M8 source via target.object; the playback side stays
# unpinned so it follows whatever your default sink is (speakers / headphones /
# Bluetooth -- swap them freely while this runs).

set -euo pipefail

for bin in pw-loopback pw-cli wpctl; do
    command -v "$bin" >/dev/null || { echo "Missing: $bin (install pipewire)"; exit 1; }
done

# Find the M8 audio source node. The Teensy enumerates as a USB-audio class
# device; node.name typically looks like:
#   alsa_input.usb-Teensyduino_Teensy_MIDI_Audio-00.analog-stereo
# We match on 'teensy' or 'm8' case-insensitively and pick a Source.
find_m8_source() {
    pw-cli ls Node 2>/dev/null | awk '
        /node\.name/        { gsub(/"/, "", $3); name = $3 }
        /media\.class/      { gsub(/"/, "", $3); cls  = $3 }
        /^\s*$/             {
            if (cls == "Audio/Source" && tolower(name) ~ /teensy|m8/) print name
            name=""; cls=""
        }
    ' | head -n1
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
