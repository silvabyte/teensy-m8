#!/usr/bin/env bash
# Download community samples / instruments / themes into ./content/.
# Nothing here is shipped by Dirtywave -- the firmware ZIP contains only .hex
# files, so headless users have to source SD content from the community.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$SCRIPT_DIR/content"
CACHE="$DEST/.cache"

STARTER_URL="https://archive.org/download/ChipmusicResources/M8_Community_SD-card_Starter_Pack.7z"
STARTER_FILE="M8_Community_SD-card_Starter_Pack.7z"

for bin in curl 7z git; do
    command -v "$bin" >/dev/null || { echo "Missing: $bin (pacman -S p7zip git curl)"; exit 1; }
done

mkdir -p "$CACHE"

# Community starter pack (samples + instruments + songs).
if [[ ! -d "$DEST/starter-pack" ]]; then
    if [[ ! -f "$CACHE/$STARTER_FILE" ]]; then
        echo ">> Downloading community starter pack..."
        curl -fL "$STARTER_URL" -o "$CACHE/$STARTER_FILE"
    fi
    echo ">> Extracting starter pack..."
    7z x -o"$DEST/starter-pack" "$CACHE/$STARTER_FILE" >/dev/null
else
    echo ">> starter-pack already extracted (skip)"
fi

# Instrument template repos.
clone_or_pull() {
    local url="$1" dir="$2"
    if [[ -d "$dir/.git" ]]; then
        echo ">> Updating $(basename "$dir")..."
        git -C "$dir" pull --ff-only --quiet
    else
        echo ">> Cloning $(basename "$dir")..."
        git clone --depth 1 --quiet "$url" "$dir"
    fi
}

clone_or_pull https://github.com/laamaa/m8i.git                       "$DEST/instruments-laamaa"
clone_or_pull https://github.com/tobokegao/m8-tracker-instruments.git "$DEST/instruments-tobokegao"
clone_or_pull https://github.com/d-huck/m8-themes.git                 "$DEST/themes-dhuck"

cat <<EOF

Done. Content staged under: $DEST

Layout on the SD card (FAT32 / exFAT, root):
  /Samples/   <-- .wav files
  /Songs/     <-- .m8s files (instruments live inside songs)
  /Themes/    <-- .m8t files

Copy what you want from ./content/* into the matching SD directories.
EOF
