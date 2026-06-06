#!/usr/bin/env bash
# Play the M8: run the audio monitor in the background and m8c in front.
# Ctrl+C (or quitting m8c) stops both -- no more juggling two terminal tabs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MON_PID=""
cleanup() { [[ -n "$MON_PID" ]] && kill "$MON_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# Start the audio loopback in the background. monitor.sh retries until the M8
# audio source registers, so it's fine to launch it before m8c.
"$SCRIPT_DIR/monitor.sh" &
MON_PID=$!

# Run m8c in the foreground (run.sh installs the config + waits for the serial
# device, then execs m8c). As a plain subprocess, when m8c exits we fall
# through to the EXIT trap and the background loopback is torn down.
"$SCRIPT_DIR/run.sh"
