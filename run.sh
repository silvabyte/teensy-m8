#!/usr/bin/env bash
# Launch M8: start the sc-controller daemon (so the Steam Controller looks
# like an XInput gamepad) and run m8c with the tuned config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/m8c-config.ini"
CONFIG_DST="${XDG_DATA_HOME:-$HOME/.local/share}/m8c/config.ini"

for bin in m8c scc-daemon; do
    command -v "$bin" >/dev/null || { echo "Missing: $bin (run ./setup.sh first)"; exit 1; }
done

# Install/refresh m8c config if ours is newer or destination is missing.
mkdir -p "$(dirname "$CONFIG_DST")"
if [[ ! -f "$CONFIG_DST" ]] || [[ "$CONFIG_SRC" -nt "$CONFIG_DST" ]]; then
    echo ">> Installing m8c gamepad config -> $CONFIG_DST"
    cp "$CONFIG_SRC" "$CONFIG_DST"
fi

# Wait for the M8 (PJRC 16c0:0489) to appear as a serial device.
echo ">> Looking for M8 serial device..."
for _ in {1..10}; do
    if compgen -G "/dev/serial/by-id/*Teensyduino*" >/dev/null \
       || compgen -G "/dev/ttyACM*" >/dev/null; then
        break
    fi
    sleep 1
done
if ! { compgen -G "/dev/serial/by-id/*Teensyduino*" >/dev/null \
       || compgen -G "/dev/ttyACM*" >/dev/null; }; then
    echo "   No /dev/ttyACM* found. Plug in the M8 (flashed Teensy) first."
    exit 1
fi

# Start the sc-controller daemon if it isn't already running.
if ! pgrep -f scc-daemon >/dev/null; then
    echo ">> Starting sc-controller daemon..."
    scc-daemon start
    sleep 1
else
    echo ">> sc-controller daemon already running"
fi

# SCC starts controllers with profile=None — physical buttons then leak through
# as desktop kbd/mouse events instead of XInput. Pin the XBox profile so
# m8c-config.ini's gamepad bindings actually receive button events.
SCC_PROFILE="XBox Controller"
echo ">> Setting SCC profile: $SCC_PROFILE"
for _ in {1..5}; do
    if scc info 2>/dev/null | grep -q 'Controller Count: [1-9]'; then
        scc set-profile "$SCC_PROFILE" || true
        break
    fi
    sleep 1
done

echo ">> Launching m8c..."
exec m8c
