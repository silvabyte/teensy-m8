#!/usr/bin/env bash
# Launch M8: install the keyboard-mapped m8c config and run m8c.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/m8c-config.ini"
CONFIG_DST="${XDG_DATA_HOME:-$HOME/.local/share}/m8c/config.ini"

command -v m8c >/dev/null || { echo "Missing: m8c (run ./setup.sh first)"; exit 1; }

# Install/refresh m8c config if ours is newer or destination is missing.
mkdir -p "$(dirname "$CONFIG_DST")"
if [[ ! -f "$CONFIG_DST" ]] || [[ "$CONFIG_SRC" -nt "$CONFIG_DST" ]]; then
    echo ">> Installing m8c keyboard config -> $CONFIG_DST"
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

echo ">> Launching m8c..."
exec m8c
