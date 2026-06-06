#!/usr/bin/env bash
# Download a curated set of classic drum-machine sample packs (808/909/CR-78/
# LinnDrum/606/707/727/Oberheim/SP1200/Simmons/...) and stage them M8-ready.
#
# Source: archive.org "drum-machines-collection" (one zip per machine).
# The M8 only plays 16-bit PCM WAV, so any 24/32-bit samples are transcoded to
# 44.1 kHz / 16-bit; already-16-bit files are copied untouched.
#
# Output: ./content/drums/<Machine>/...  -- copy that into /Samples/ on the SD:
#     cp -r ./content/drums/* /run/media/$USER/<CARD>/Samples/
#
# Usage: ./fetch-drums.sh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="$SCRIPT_DIR/content/.cache/drum-machines"
EXTRACT="$SCRIPT_DIR/content/.cache/drum-extract"
OUT="$SCRIPT_DIR/content/drums"
BASE="https://archive.org/download/drum-machines-collection"

for bin in curl ffmpeg ffprobe; do
    command -v "$bin" >/dev/null || { echo "Missing: $bin (pacman -S curl ffmpeg)"; exit 1; }
done
# Either 7z or bsdtar can unpack the .zip archives.
if command -v 7z >/dev/null; then UNZIP=(7z x -y -o); EXTRACT_STYLE=7z
elif command -v bsdtar >/dev/null; then EXTRACT_STYLE=bsdtar
else echo "Missing: need 7z (p7zip) or bsdtar (libarchive)"; exit 1; fi

# zip name on archive.org  =>  clean folder name on the card
MACHINES=(
    "Roland TR808.zip|TR-808"
    "Roland TR-909.zip|TR-909"
    "Roland CR78.zip|CR-78"
    "Roland TR606.zip|TR-606"
    "Roland TR707.zip|TR-707"
    "Roland TR727.zip|TR-727"
    "Linn Linndrum.zip|LinnDrum"
    "Linn LM-1.zip|Linn-LM-1"
    "Oberheim DMX.zip|Oberheim-DMX"
    "Oberheim DX.zip|Oberheim-DX"
    "EMU SP1200.zip|EMU-SP1200"
    "EMU Drumulator.zip|EMU-Drumulator"
    "Sequential Circuits Drumtraks.zip|Drumtraks"
    "Casio RZ-1.zip|Casio-RZ1"
    "Simmons SDS5.zip|Simmons-SDS5"
)

mkdir -p "$CACHE" "$EXTRACT" "$OUT"

urlencode() { printf '%s' "$1" | sed 's/ /%20/g'; }

# Descend through redundant single-subdir wrappers left by the zips.
content_root() {
    local d="$1"
    while :; do
        local subs=() ; local has_wav=0 e
        for e in "$d"/*; do
            [[ -e "$e" ]] || continue
            [[ -d "$e" ]] && subs+=("$e")
            [[ "${e,,}" == *.wav ]] && has_wav=1
        done
        if [[ ${#subs[@]} -eq 1 && $has_wav -eq 0 ]]; then d="${subs[0]}"; else break; fi
    done
    printf '%s' "$d"
}

for entry in "${MACHINES[@]}"; do
    zip="${entry%%|*}"; clean="${entry##*|}"
    cache_zip="$CACHE/$zip"

    if [[ ! -f "$cache_zip" ]]; then
        echo ">> Downloading $zip ..."
        curl -fL --retry 3 --max-time 600 "$BASE/$(urlencode "$zip")" -o "$cache_zip"
    fi

    ex="$EXTRACT/$clean"
    if [[ ! -d "$ex" ]]; then
        echo ">> Extracting $clean ..."
        mkdir -p "$ex"
        if [[ "$EXTRACT_STYLE" == 7z ]]; then
            7z x -y -o"$ex" "$cache_zip" >/dev/null
        else
            bsdtar -xf "$cache_zip" -C "$ex"
        fi
    fi

    root="$(content_root "$ex")"
    echo ">> Staging $clean ..."
    while IFS= read -r -d '' src; do
        rel="${src#"$root"/}"                       # path within the machine
        dest="$OUT/$clean/$rel"
        mkdir -p "$(dirname "$dest")"
        bits="$(ffprobe -v error -select_streams a:0 \
                 -show_entries stream=bits_per_sample \
                 -of default=noprint_wrappers=1:nokey=1 "$src" 2>/dev/null)"
        if [[ "$bits" == "16" ]]; then
            cp "$src" "$dest"
        else
            ffmpeg -y -hide_banner -loglevel error -i "$src" \
                   -ar 44100 -c:a pcm_s16le "$dest"
        fi
    done < <(find "$root" -iname '*.wav' -print0)
done

count=$(find "$OUT" -iname '*.wav' | wc -l)
cat <<EOF

Done. $count drum samples staged (44.1 kHz / 16-bit) under:
  $OUT/

Copy onto the SD card (keeps the per-machine folders):
  cp -r "$OUT"/* /run/media/\$USER/<CARD>/Samples/
EOF
