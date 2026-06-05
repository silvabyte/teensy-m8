#!/usr/bin/env bash
# Convert a directory of audio files to M8-friendly WAV (44.1 kHz, 16-bit PCM).
# Use this when pulling samples from outside the community pack (freesound,
# Splice, your own recordings, etc.). Writes converted files alongside originals
# with a .m8.wav suffix; originals are left untouched.

set -euo pipefail

command -v ffmpeg >/dev/null || { echo "Missing: ffmpeg (pacman -S ffmpeg)"; exit 1; }

SRC="${1:-}"
if [[ -z "$SRC" || ! -d "$SRC" ]]; then
    echo "Usage: $0 <directory>"; exit 1
fi

shopt -s nullglob globstar nocaseglob
for f in "$SRC"/**/*.{wav,aif,aiff,flac,mp3,ogg}; do
    [[ "$f" == *.m8.wav ]] && continue
    out="${f%.*}.m8.wav"
    [[ -f "$out" && "$out" -nt "$f" ]] && continue
    echo ">> $f"
    ffmpeg -hide_banner -loglevel error -y -i "$f" -ar 44100 -ac 2 -c:a pcm_s16le "$out"
done

echo "Done. Converted files end in .m8.wav -- copy those to /Samples/ on the SD."
