#!/usr/bin/env bash
# Convert one media file to an M8-ready WAV and copy it to the M8 microSD card.

set -euo pipefail

usage() {
    echo "Usage: $0 <input-file> <sample-name> [sd-mount]"
    echo "Example: $0 ~/Videos/snare.mkv 'Big Snare'"
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

command -v ffmpeg >/dev/null || {
    echo "Missing: ffmpeg (pacman -S ffmpeg)"
    exit 1
}

INPUT=$1
SAMPLE_NAME=$2
SD_MOUNT=${3:-}

if [[ ! -f "$INPUT" ]]; then
    echo "Input file not found: $INPUT"
    exit 1
fi

if [[ "${SAMPLE_NAME,,}" == *.wav ]]; then
    SAMPLE_NAME=${SAMPLE_NAME:0:${#SAMPLE_NAME}-4}
fi

if [[ -z "$SAMPLE_NAME" || "$SAMPLE_NAME" == "." || "$SAMPLE_NAME" == ".." \
    || "$SAMPLE_NAME" == *['<>:"/\|?*']* ]]; then
    echo "Invalid sample name: $2"
    echo 'Do not use / \ < > : " | ? or * in the name.'
    exit 1
fi

if [[ -z "$SD_MOUNT" ]]; then
    shopt -s nullglob
    candidates=()

    for root in "/run/media/$USER" "/media/$USER"; do
        [[ -d "$root" ]] || continue
        for mount in "$root"/*; do
            [[ -d "$mount/Samples" ]] && candidates+=("$mount")
        done
    done

    if (( ${#candidates[@]} == 0 )); then
        echo "Could not find a mounted M8 microSD card."
        echo "Mount the card, or pass its mount point as the third argument."
        exit 1
    elif (( ${#candidates[@]} > 1 )); then
        echo "More than one possible M8 microSD card was found:"
        printf '  %s\n' "${candidates[@]}"
        echo "Pass the correct mount point as the third argument."
        exit 1
    fi

    SD_MOUNT=${candidates[0]}
fi

SD_MOUNT=${SD_MOUNT%/}
if [[ ! -d "$SD_MOUNT/Samples" ]]; then
    echo "Samples directory not found: $SD_MOUNT/Samples"
    exit 1
fi

DESTINATION="$SD_MOUNT/Samples/$SAMPLE_NAME.wav"
if [[ -e "$DESTINATION" ]]; then
    echo "Sample already exists: $DESTINATION"
    echo "Remove it first if you want to replace it."
    exit 1
fi

TEMP_FILE=$(mktemp --suffix=.wav)
trap 'rm -f "$TEMP_FILE"' EXIT

echo ">> Converting: $INPUT"
ffmpeg -hide_banner -loglevel error -y -i "$INPUT" \
    -map 0:a:0 -vn -ar 44100 -ac 2 -c:a pcm_s16le "$TEMP_FILE"

echo ">> Copying: $DESTINATION"
cp -- "$TEMP_FILE" "$DESTINATION"
sync "$DESTINATION"

echo "Sample ready: $DESTINATION"
