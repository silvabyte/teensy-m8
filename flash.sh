#!/usr/bin/env bash
# Download the latest M8 headless firmware and flash it to the Teensy 4.1.
# Firmware lives in https://github.com/DirtyWave/M8HeadlessFirmware/tree/main/Releases
# (it's a directory of .hex files, not GitHub Releases) -- so we hit the
# GitHub contents API to find the newest M8_*_HEADLESS.hex.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_DIR="$SCRIPT_DIR/firmware"
REPO="DirtyWave/M8HeadlessFirmware"
API="https://api.github.com/repos/$REPO/contents/Releases"

mkdir -p "$FW_DIR"

for bin in curl jq teensy_loader_cli; do
    command -v "$bin" >/dev/null || { echo "Missing: $bin (run ./setup.sh first)"; exit 1; }
done

echo ">> Querying GitHub for available firmware..."
# Sort by name desc, keep first .hex matching the headless pattern.
LATEST_JSON="$(curl -fsSL "$API")"
LATEST_NAME="$(echo "$LATEST_JSON" | jq -r '
    [.[] | select(.name | test("^M8_.*_HEADLESS\\.hex$"; "i"))]
    | sort_by(.name) | reverse | .[0].name
')"
LATEST_URL="$(echo "$LATEST_JSON" | jq -r --arg n "$LATEST_NAME" '
    .[] | select(.name == $n) | .download_url
')"

if [[ -z "$LATEST_NAME" || "$LATEST_NAME" == "null" ]]; then
    echo "Could not find a headless .hex in $API"; exit 1
fi

HEX="$FW_DIR/$LATEST_NAME"
if [[ ! -f "$HEX" ]]; then
    echo ">> Downloading $LATEST_NAME ..."
    curl -fsSL "$LATEST_URL" -o "$HEX"
else
    echo ">> Already have $LATEST_NAME (cached)"
fi

echo ""
echo "About to flash: $LATEST_NAME"
echo ""
echo "  1. Make sure your Teensy 4.1 is plugged in directly (no hub)."
echo "  2. When prompted, press the small button on the Teensy to enter the bootloader."
echo ""
read -rp "Press Enter to start flashing..."

teensy_loader_cli --mcu=TEENSY41 -w -v "$HEX"

echo ""
echo "Flash complete. Unplug & replug the Teensy. It should now enumerate as 'M8'."
echo "Verify with:  lsusb | grep -i teensy   (you should see PJRC product id 0489)"
