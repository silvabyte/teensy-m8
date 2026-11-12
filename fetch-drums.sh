#!/usr/bin/env bash
# Download drum-machine packs from archive.org "drum-machines-collection"
# and stage 16-bit PCM WAV for one of two devices.
#
# The machine list comes from the item metadata (every format:ZIP file),
# not a hardcoded set. Zips are cached and extracted once under
# content/.cache, so a later run for the other target does not re-download.
#
# Sources are WAV plus AIFF/FLAC/MP3/OGG. Non-WAV audio is converted to WAV
# and the staged name ends in .wav. A pack with no audio fails as
# "no audio files".
#
# Some WAVs in this archive are valid PCM that ffmpeg rejects outright:
# a zero-length LIST chunk ("too short LIST tag"), or format tag 3 (IEEE
# float) on 16-bit PCM (Korg MS-10 Crash.wav, "no decoder"). The header is
# repaired and the sample bytes are left alone. A file that still will not
# convert is skipped and named in the summary; the rest of the pack is staged.
#
# Targets (the only place device rules live is target_spec / print_target_limits):
#   m8     16-bit PCM WAV. A WAV that is already 16-bit is copied as-is.
#          Any other WAV, and AIFF/FLAC/MP3/OGG, is rewritten to 44.1 kHz.
#          --card copies into <card>/Samples/.
#   sp404  48 kHz / 16-bit linear WAV for the SP-404MKII IMPORT folder.
#          --card copies into <card>/IMPORT/ and never deletes card files.
#
# SP-404MKII sources used for that target:
#   Import formats (SD card is 16-bit linear WAV/AIFF/MP3; the unit converts
#   imports to 48 kHz / 16-bit; files under 100 ms may not import):
#   https://support.roland.com/hc/en-us/articles/4408190553883-SP-404MK2-What-audio-file-formats-can-be-imported-into-the-SP-404MK2
#   IMPORT folder, including subfolders:
#   https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/7958977178537867.html
#   Main specs (48 kHz, 16-bit linear, 2,560 samples, 16 GB, 16 min / ~185 MB):
#   https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/8010023578592395.html
#   The 16 min / ~185 MB cap also applies to SD import:
#   https://support.roland.com/hc/en-us/articles/4408196941851-SP-404MK2-Maximum-Sampling-Time
#   Filenames longer than 80 characters crashed on import before system v4.06
#   (fixed in v4.06, October 2024):
#   https://www.roland.com/global/support/by_product/sp-404mk2/updates_drivers/174cc2fc-ddb2-4128-87a0-848b882cdcea/
#   On-device sample names are at most 23 characters (RENAME). Card filenames
#   are not shortened to that:
#   https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/9038964390483339.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="$SCRIPT_DIR/content/.cache/drum-machines"
EXTRACT="$SCRIPT_DIR/content/.cache/drum-extract"
OUT="$SCRIPT_DIR/content/drums"
META_URL="https://archive.org/metadata/drum-machines-collection"
BASE="https://archive.org/download/drum-machines-collection"

# ffmpeg decodes these. AIFF is what the non-WAV packs in this archive
# actually contain; flac/mp3/ogg are accepted when a pack has them.
# is_audio_file and find_audio both use this list.
AUDIO_EXTS=(wav aif aiff flac mp3 ogg)

# Set by prepare_wav_input / transcode_wav for the file currently staging.
REPAIR_TMP=""
TRANSCODE_RC=0
TRANSCODE_ERR=""

# The previous hardcoded set, still available as --preset classics.
CLASSICS=(
    "Roland TR808.zip"
    "Roland TR-909.zip"
    "Roland CR78.zip"
    "Roland TR606.zip"
    "Roland TR707.zip"
    "Roland TR727.zip"
    "Linn Linndrum.zip"
    "Linn LM-1.zip"
    "Oberheim DMX.zip"
    "Oberheim DX.zip"
    "EMU SP1200.zip"
    "EMU Drumulator.zip"
    "Sequential Circuits Drumtraks.zip"
    "Casio RZ-1.zip"
    "Simmons SDS5.zip"
)

TARGET="m8"
PRESET="all"
JOBS=3
LIST_ONLY=0
CARD=""
INCLUDES=()
EXCLUDES=()

usage() {
    cat <<EOF
Usage: ./fetch-drums.sh [options]

Download archive.org drum-machines-collection and stage 16-bit WAV.

  --target m8|sp404   Device to stage for (default: m8)
  --preset all|classics
                      all = every ZIP in the item (default)
                      classics = the original 15 machines
  --include REGEX     Keep machines whose folder or zip name matches.
                      Repeatable; a machine is kept if any regex matches.
  --exclude REGEX     Drop machines whose folder or zip name matches.
                      Repeatable; applied after --include.
  --list              Print the selected machines and sizes, then exit
  --card PATH         Copy the staged tree onto a mounted SD card.
                      m8 -> PATH/Samples/   sp404 -> PATH/IMPORT/
                      Never deletes files already on the card.
  -j N                Parallel machine jobs (default: 3)
  -h, --help          Show this help

Output: ./content/drums/<target>/<Machine>/
Zip cache (shared by every target): ./content/.cache/drum-machines/
EOF
}

die() {
    printf '%s\n' "$*" >&2
    exit 2
}

# rate: Hz used when a file has to be rewritten
# when: non16 = copy existing 16-bit PCM as-is (M8); always = 16-bit at rate
# card: SD directory the staged tree is copied into
# label: one line for logs
target_spec() {
    case "$1:$2" in
        m8:rate) printf '%s\n' 44100 ;;
        m8:when) printf '%s\n' non16 ;;
        m8:card) printf '%s\n' Samples ;;
        m8:label) printf '%s\n' "16-bit PCM WAV (44.1 kHz when transcoding) for /Samples" ;;
        sp404:rate) printf '%s\n' 48000 ;;
        sp404:when) printf '%s\n' always ;;
        sp404:card) printf '%s\n' IMPORT ;;
        sp404:label) printf '%s\n' "48 kHz / 16-bit linear WAV for /IMPORT" ;;
        *) return 1 ;;
    esac
}

human_bytes() {
    awk -v n="${1:-0}" 'BEGIN {
        if (n < 0) n = 0
        split("B KiB MiB GiB TiB", u, " ")
        i = 1
        while (n >= 1024 && i < 5) { n /= 1024; i++ }
        if (i == 1) printf "%d %s", n, u[i]
        else printf "%.1f %s", n, u[i]
    }'
}

urlencode() {
    python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

# FAT-illegal characters only. Sample names stay readable; nothing is shortened.
sanitize_rel() {
    local rel=$1 part out=""
    while IFS= read -r -d '/' part || [[ -n "$part" ]]; do
        part=${part//\\/-}
        part=${part//:/-}
        part=${part//\*/-}
        part=${part//\?/-}
        part=${part//\"/-}
        part=${part//</-}
        part=${part//>/-}
        part=${part//|/-}
        while [[ "$part" == *" " ]]; do part=${part%" "}; done
        while [[ "$part" == *. ]]; do part=${part%.}; done
        if [[ -z "$part" || "$part" == "." || "$part" == ".." ]]; then
            part="sample"
        fi
        if [[ -z "$out" ]]; then
            out=$part
        else
            out="$out/$part"
        fi
    done < <(printf '%s/' "$rel")
    printf '%s\n' "$out"
}

name_matches() {
    local re=$1 folder=$2 zip=$3
    [[ "$folder" =~ $re || "$zip" =~ $re ]]
}

validate_regex() {
    local re=$1 rc=0
    # shellcheck disable=SC2254
    # Invalid ERE makes [[ =~ ]] return 2. A non-match is 1.
    [[ "x" =~ $re ]] && rc=0 || rc=$?
    if (( rc == 2 )); then
        die "Invalid regex: $re"
    fi
}

is_classic() {
    local zip=$1 c
    for c in "${CLASSICS[@]}"; do
        [[ "$c" == "$zip" ]] && return 0
    done
    return 1
}

have_zip() {
    local want=$1 row z
    for row in "${ALL_ROWS[@]}"; do
        z=${row%%$'\x1f'*}
        [[ "$z" == "$want" ]] && return 0
    done
    return 1
}

size_ok() {
    local file=$1 size=$2 actual
    [[ -n "$size" && "$size" != 0 && -f "$file" ]] || return 1
    actual=$(stat -c%s -- "$file")
    [[ "$actual" == "$size" ]]
}

# Fresh downloads must match size and, when the metadata has one, md5.
file_ok() {
    local file=$1 size=$2 md5=$3 got
    [[ -f "$file" ]] || return 1
    if [[ -n "$size" && "$size" != 0 ]]; then
        [[ "$(stat -c%s -- "$file")" == "$size" ]] || return 1
    fi
    if [[ -n "$md5" ]]; then
        got=$(md5sum -- "$file" | awk '{print $1}')
        [[ "$got" == "$md5" ]] || return 1
    fi
    [[ -s "$file" ]]
}

download_one() {
    local zip=$1 size=$2 md5=$3 folder=$4
    local dest part url attempt=1
    dest="$CACHE/$zip"
    part="$dest.part"
    if size_ok "$dest" "$size"; then
        printf '>> %s: cached (%s)\n' "$folder" "$(human_bytes "$size")"
        return 0
    fi
    rm -f -- "$dest"
    if [[ -f "$part" ]] && file_ok "$part" "$size" "$md5"; then
        mv -f -- "$part" "$dest" || return 1
        printf '>> %s: finished partial download\n' "$folder"
        return 0
    fi
    url="$BASE/$(urlencode "$zip")"
    local -a curl_args
    while (( attempt <= 2 )); do
        if [[ -f "$part" && -n "$size" && "$size" != 0 ]]; then
            if (( $(stat -c%s -- "$part") > size )); then
                rm -f -- "$part"
            fi
        fi
        printf '>> %s: downloading %s (attempt %s)\n' \
            "$folder" "$(human_bytes "$size")" "$attempt"
        curl_args=(-fsSL --retry 3 --retry-delay 2 --connect-timeout 20)
        if [[ -f "$part" ]]; then
            curl_args+=(-C -)
        fi
        # -o has to stay in front of --; curl treats everything after -- as a URL.
        if curl "${curl_args[@]}" -o "$part" -- "$url" && file_ok "$part" "$size" "$md5"; then
            mv -f -- "$part" "$dest" || return 1
            return 0
        fi
        # A resumed partial can be the wrong bytes with a matching length.
        # The second attempt starts over.
        rm -f -- "$part"
        attempt=$((attempt + 1))
    done
    return 1
}

run_extract() {
    local dest=$1 zip=$2 rc=0
    if [[ "$EXTRACT_STYLE" == 7z ]]; then
        7z x -y -o"$dest" -- "$zip" >/dev/null || rc=$?
        # 7z exits 1 for non-fatal warnings (odd extra fields, etc.).
        [[ "$rc" -le 1 ]]
    else
        bsdtar -xf "$zip" -C "$dest"
    fi
}

extract_one() {
    local zip=$1 folder=$2 size=$3 md5=$4
    local ex="$EXTRACT/$folder" tmp="$EXTRACT/.$folder.partial" sig="$size $md5"
    if [[ -f "$ex/.extracted" && "$(<"$ex/.extracted")" == "$sig" ]]; then
        printf '>> %s: extract cached\n' "$folder"
        return 0
    fi
    printf '>> %s: extracting\n' "$folder"
    rm -rf -- "$tmp"
    mkdir -p -- "$tmp"
    if ! run_extract "$tmp" "$CACHE/$zip"; then
        rm -rf -- "$tmp"
        return 1
    fi
    printf '%s\n' "$sig" > "$tmp/.extracted" || return 1
    rm -rf -- "$ex"
    mv -- "$tmp" "$ex" || return 1
}

is_audio_file() {
    local lower=${1,,} ext
    for ext in "${AUDIO_EXTS[@]}"; do
        [[ "$lower" == *."$ext" ]] && return 0
    done
    return 1
}

find_audio() {
    local root=$1 ext
    local -a expr=()
    for ext in "${AUDIO_EXTS[@]}"; do
        if ((${#expr[@]} > 0)); then
            expr+=(-o)
        fi
        expr+=(-iname "*.${ext}")
    done
    find "$root" -type f \( "${expr[@]}" \) -print0
}

# Descend through a single wrapper directory that holds no audio of its own.
content_root() {
    local d=$1 e depth=0
    local -a subs=()
    while (( depth < 8 )); do
        depth=$((depth + 1))
        subs=()
        local has_audio=0 any=0
        for e in "$d"/*; do
            [[ -e "$e" ]] || continue
            any=1
            if [[ -d "$e" ]]; then
                subs+=("$e")
            fi
            if is_audio_file "$e"; then
                has_audio=1
            fi
        done
        if [[ "$any" -eq 0 ]]; then
            break
        fi
        if [[ "${#subs[@]}" -eq 1 && "$has_audio" -eq 0 ]]; then
            d=${subs[0]}
        else
            break
        fi
    done
    printf '%s\n' "$d"
}

probe_audio() {
    PROBE_BITS=""
    PROBE_RATE=""
    PROBE_CODEC=""
    local k v
    while IFS='=' read -r k v; do
        case "$k" in
            bits_per_sample) PROBE_BITS=$v ;;
            sample_rate) PROBE_RATE=$v ;;
            codec_name) PROBE_CODEC=$v ;;
        esac
    done < <(ffprobe -v error -select_streams a:0 \
        -show_entries stream=bits_per_sample,sample_rate,codec_name \
        -of default=noprint_wrappers=1 -- "$1" </dev/null 2>/dev/null || true)
}

# Rewrite a WAV ffmpeg refuses to open, when the samples themselves are fine.
# Returns 0 and writes dst when it changed something.
#   LIST size < 4: ffmpeg errors "too short LIST tag" and drops the file.
#     Roland SH3A, Yamaha CS15D, and Yamaha CS-40M end with a 0-byte LIST
#     after a normal fmt+data (the RIFF size also stops short of that tail).
#   Format tag 3 (IEEE float) with an integer block align: ffmpeg reports
#     "no decoder". Korg MS-10 Crash.wav is 16-bit PCM mis-tagged as float.
# Anything else is left untouched so the caller uses the original.
repair_wav_header() {
    python3 - "$1" "$2" <<'PY'
import struct
import sys

src, dst = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
    sys.exit(1)

out = bytearray(data[:12])
changed = False
off = 12
n = len(data)
while off + 8 <= n:
    cid = data[off : off + 4]
    sz = struct.unpack_from("<I", data, off + 4)[0]
    pad = sz & 1
    step = 8 + sz + pad
    if sz > n or off + 8 + sz > n:
        break
    end = min(n, off + step)
    chunk = bytearray(data[off:end])
    if cid == b"LIST" and sz < 4:
        changed = True
        off = end
        continue
    if cid == b"fmt " and sz >= 16:
        fmt, ch, _rate, _br, balign, bits = struct.unpack_from("<HHIIHH", chunk, 8)
        if (
            fmt == 3
            and bits in (8, 16, 24)
            and ch > 0
            and balign == ch * (bits // 8)
        ):
            struct.pack_into("<H", chunk, 8, 1)
            changed = True
    out += chunk
    off = end

if not changed:
    sys.exit(1)
struct.pack_into("<I", out, 4, len(out) - 8)
with open(dst, "wb") as fh:
    fh.write(out)
PY
}

clear_repair() {
    if [[ -n "${REPAIR_TMP:-}" ]]; then
        rm -f -- "$REPAIR_TMP"
        REPAIR_TMP=""
    fi
}

# Probe src. When it is a WAV ffmpeg cannot identify, probe a repaired copy
# instead and leave that path in REPAIR_TMP. Sample bytes are not rewritten.
prepare_wav_input() {
    local src=$1 tmp
    REPAIR_TMP=""
    probe_audio "$src"
    [[ ${src,,} == *.wav ]] || return 0
    if [[ -n "$PROBE_CODEC" && "$PROBE_CODEC" != unknown && "$PROBE_CODEC" != none ]]; then
        return 0
    fi
    tmp=$(mktemp)
    if repair_wav_header "$src" "$tmp"; then
        REPAIR_TMP=$tmp
        probe_audio "$REPAIR_TMP"
        return 0
    fi
    rm -f -- "$tmp"
}

# stderr is captured so a benign per-file decode note (a truncated trailing
# PCM sample logs "Invalid PCM packet" at error level and still exits 0)
# does not flood the terminal. A nonzero exit is the caller's to record.
transcode_wav() {
    local input=$1 dest=$2 arate=$3 err
    err=$(mktemp)
    TRANSCODE_RC=0
    TRANSCODE_ERR=""
    ffmpeg -nostdin -y -hide_banner -loglevel error \
        -i "$input" -map 0:a:0 -ar "$arate" -c:a pcm_s16le -f wav \
        "$dest" </dev/null 2>"$err" || TRANSCODE_RC=$?
    TRANSCODE_ERR=$(tr '\n' ' ' <"$err" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
    rm -f -- "$err"
    if [[ -z "$TRANSCODE_ERR" ]]; then
        TRANSCODE_ERR="no error text"
    elif ((${#TRANSCODE_ERR} > 300)); then
        TRANSCODE_ERR="${TRANSCODE_ERR:0:300}..."
    fi
    return "$TRANSCODE_RC"
}

record_skip() {
    local file=$1 rel=$2 msg=$3
    rel=${rel//$'\t'/ }
    msg=${msg//$'\t'/ }
    printf '%s\t%s\n' "$rel" "$msg" >> "$file"
    printf '!! %s: %s: %s\n' "$(basename -- "$file")" "$rel" "$msg" >&2
}

stage_tree() {
    local root=$1 dest_root=$2 rate=$3 when=$4 skip_file=$5
    local -A used=()
    local src rel rel_src safe cand n stem ext dest input copy count=0 rc=0
    while IFS= read -r -d '' src; do
        rel_src=${src#"$root"/}
        rel=$rel_src
        # Staged names end in .wav. A copied .WAV keeps the source spelling.
        if [[ ${rel,,} != *.wav ]]; then
            rel="${rel%.*}.wav"
        fi
        safe=$(sanitize_rel "$rel")
        cand=$safe
        n=2
        # Key on the source path. foo.aif and foo.wav both stage as foo.wav.
        while [[ -n ${used[$cand]+x} && ${used[$cand]} != "$rel_src" ]]; do
            ext=""
            stem=$safe
            if [[ "$safe" == *.* ]]; then
                ext=".${safe##*.}"
                stem=${safe%.*}
            fi
            cand="${stem}-$n${ext}"
            n=$((n + 1))
        done
        used[$cand]=$rel_src
        safe=$cand
        dest="$dest_root/$safe"
        if ! mkdir -p -- "$(dirname -- "$dest")"; then
            record_skip "$skip_file" "$rel_src" "could not create output directory"
            continue
        fi

        prepare_wav_input "$src"
        input=$src
        if [[ -n "${REPAIR_TMP:-}" ]]; then
            input=$REPAIR_TMP
        fi

        # Copy only WAV, and only under the target's existing rule.
        # Non-WAV is always rewritten so a 16-bit AIFF is not renamed to .wav.
        copy=0
        if [[ ${src,,} == *.wav && "$when" == non16 && "$PROBE_BITS" == 16 ]]; then
            copy=1
        elif [[ ${src,,} == *.wav && "$when" == always && "$PROBE_BITS" == 16 \
            && "$PROBE_RATE" == "$rate" && "$PROBE_CODEC" == pcm_s16le ]]; then
            copy=1
        fi

        if [[ "$copy" == 1 ]]; then
            if [[ -f "$dest" ]] && [[ "$(stat -c%s -- "$dest")" == "$(stat -c%s -- "$input")" ]]; then
                count=$((count + 1))
                clear_repair
                continue
            fi
            if ! cp -f -- "$input" "$dest.part"; then
                rm -f -- "$dest.part"
                record_skip "$skip_file" "$rel_src" "copy failed"
                clear_repair
                continue
            fi
            if ! mv -f -- "$dest.part" "$dest"; then
                rm -f -- "$dest.part"
                record_skip "$skip_file" "$rel_src" "could not move staged file into place"
                clear_repair
                continue
            fi
        else
            if [[ -f "$dest" && "$dest" -nt "$src" ]]; then
                probe_audio "$dest"
                if [[ "$PROBE_BITS" == 16 && "$PROBE_RATE" == "$rate" \
                    && "$PROBE_CODEC" == pcm_s16le ]]; then
                    count=$((count + 1))
                    clear_repair
                    continue
                fi
            fi
            if ! transcode_wav "$input" "$dest.part" "$rate"; then
                rm -f -- "$dest.part"
                rc=$TRANSCODE_RC
                # Header looked readable but the decoder still refused it.
                if [[ -z "${REPAIR_TMP:-}" ]]; then
                    REPAIR_TMP=$(mktemp)
                    if repair_wav_header "$src" "$REPAIR_TMP"; then
                        if transcode_wav "$REPAIR_TMP" "$dest.part" "$rate"; then
                            if mv -f -- "$dest.part" "$dest"; then
                                count=$((count + 1))
                                clear_repair
                                continue
                            fi
                            rm -f -- "$dest.part"
                            record_skip "$skip_file" "$rel_src" \
                                "could not move staged file into place"
                            clear_repair
                            continue
                        fi
                        rm -f -- "$dest.part"
                        rc=$TRANSCODE_RC
                    else
                        rm -f -- "$REPAIR_TMP"
                        REPAIR_TMP=""
                    fi
                fi
                record_skip "$skip_file" "$rel_src" \
                    "ffmpeg exited ${rc}: ${TRANSCODE_ERR:-no error text}"
                clear_repair
                continue
            fi
            if ! mv -f -- "$dest.part" "$dest"; then
                rm -f -- "$dest.part"
                record_skip "$skip_file" "$rel_src" "could not move staged file into place"
                clear_repair
                continue
            fi
        fi
        count=$((count + 1))
        clear_repair
    done < <(find_audio "$root")
    printf '%s\n' "$count"
}

note_fail() {
    local folder=$1 msg=$2
    printf '%s\n' "$msg" > "$FAIL_DIR/$folder"
    printf '!! %s: %s\n' "$folder" "$msg" >&2
}

# Pack produced nothing usable. skipf is "source<TAB>reason" lines.
fail_skipped_pack() {
    local folder=$1 skipf=$2 rel msg
    {
        printf 'stage failed\n'
        while IFS=$'\t' read -r rel msg || [[ -n "${rel:-}" ]]; do
            [[ -n "${rel:-}" ]] || continue
            printf '%s: %s\n' "$rel" "$msg"
        done < "$skipf"
    } > "$FAIL_DIR/$folder"
    printf '!! %s: stage failed\n' "$folder" >&2
    rm -f -- "$skipf"
}

# One pack-level failure, possibly with one line per file under it.
print_fail_file() {
    local file=$1 folder line first=1
    folder=$(basename -- "$file")
    while IFS= read -r line || [[ -n "$line" ]]; do
        if (( first == 1 )); then
            printf '  %s: %s\n' "$folder" "$line"
            first=0
        else
            printf '    %s\n' "$line"
        fi
    done < "$file"
}

process_one() {
    local zip=$1 size=$2 md5=$3 folder=$4
    local lockpath="$CACHE/$folder.lock" lockfd=0 root n="" skipf
    if command -v flock >/dev/null 2>&1; then
        exec {lockfd}>"$lockpath"
        flock "$lockfd"
    fi
    if ! download_one "$zip" "$size" "$md5" "$folder"; then
        note_fail "$folder" "download failed"
        return 0
    fi
    if ! extract_one "$zip" "$folder" "$size" "$md5"; then
        note_fail "$folder" "extract failed"
        return 0
    fi
    root=$(content_root "$EXTRACT/$folder")
    skipf="$SKIP_DIR/$folder"
    rm -f -- "$skipf"
    if ! n=$(stage_tree "$root" "$OUT/$TARGET/$folder" "$RATE" "$WHEN" "$skipf"); then
        if [[ -s "$skipf" ]]; then
            fail_skipped_pack "$folder" "$skipf"
        else
            note_fail "$folder" "stage failed: unknown error"
        fi
        return 0
    fi
    if [[ ! "$n" =~ ^[0-9]+$ ]]; then
        note_fail "$folder" "stage failed: no file count"
        rm -f -- "$skipf"
        return 0
    fi
    if [[ "$n" == 0 ]]; then
        if [[ -s "$skipf" ]]; then
            fail_skipped_pack "$folder" "$skipf"
        else
            note_fail "$folder" "no audio files"
        fi
        return 0
    fi
    printf '%s\n' "$n" > "$STAT_DIR/$folder"
    if [[ -s "$skipf" ]]; then
        local skipped
        skipped=$(wc -l < "$skipf" | tr -d ' ')
        printf '>> %s: %s wavs, %s skipped\n' "$folder" "$n" "$skipped"
    else
        printf '>> %s: %s wavs\n' "$folder" "$n"
    fi
}

copy_card() {
    local card_dir src dest
    card_dir=$(target_spec "$TARGET" card)
    src="$OUT/$TARGET/"
    dest="$CARD/$card_dir/"
    if [[ ! -d "$OUT/$TARGET" ]]; then
        printf '!! nothing staged to copy into %s\n' "$dest" >&2
        return 1
    fi
    mkdir -p -- "$dest"
    if command -v rsync >/dev/null 2>&1; then
        printf '>> rsync %s -> %s (no delete)\n' "$src" "$dest"
        rsync -a -- "$src" "$dest"
    else
        printf '>> cp %s -> %s (no delete)\n' "$src" "$dest"
        cp -a -- "$src." "$dest"
    fi
}

load_rows() {
    local meta=$1 rows=$2
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 120 \
        -o "$meta" "$META_URL" || die "could not download $META_URL"
    python3 - "$meta" > "$rows" <<'PY' || die "could not parse archive metadata"
import json, re, sys, unicodedata

def folder_name(zip_name: str) -> str:
    stem = zip_name[:-4] if zip_name.lower().endswith(".zip") else zip_name
    stem = unicodedata.normalize("NFKD", stem)
    stem = "".join(ch for ch in stem if not unicodedata.combining(ch))
    # Keep "&" / "+" readable instead of dropping them.
    stem = stem.replace("&", " and ").replace("+", " plus ")
    stem = stem.replace("'", "").replace("\u2019", "").replace("`", "")
    stem = re.sub(r"[^A-Za-z0-9]+", "-", stem).strip("-")
    return stem or "machine"

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

zips = []
for entry in data.get("files", []):
    if entry.get("format") != "ZIP":
        continue
    name = entry.get("name") or ""
    if not name or "/" in name or name.startswith("."):
        continue
    zips.append(entry)

seen = {}
ordered = []
for entry in sorted(zips, key=lambda e: folder_name(e["name"]).lower()):
    base = folder_name(entry["name"])
    folder = base
    n = 2
    while folder in seen:
        folder = f"{base}-{n}"
        n += 1
    seen[folder] = entry["name"]
    ordered.append((entry, folder))

inner = sum(int(e.get("filecount") or 0) for e, _ in ordered)
total = sum(int(e.get("size") or 0) for e, _ in ordered)
sys.stdout.write("\x1f".join(["#META", str(len(ordered)), str(inner), str(total)]) + "\n")
for entry, folder in ordered:
    fields = [
        entry["name"],
        str(int(entry.get("size") or 0)),
        (entry.get("md5") or "").lower(),
        folder,
        str(int(entry.get("filecount") or 0)),
    ]
    sys.stdout.write("\x1f".join(fields) + "\n")
PY
}

print_target_limits() {
    local staged=${1:-}
    if [[ "$TARGET" == m8 ]]; then
        cat <<EOF

M8: 16-bit PCM only. A WAV that is already 16-bit is copied as it is;
any other WAV, and AIFF/FLAC/MP3/OGG, is rewritten to 44.1 kHz / 16-bit.
Land the tree in /Samples.
EOF
        return 0
    fi
    local sel_n=${#SELECTED[@]} sel_noun=zips
    if (( sel_n == 1 )); then
        sel_noun=zip
    fi
    cat <<EOF

SP-404MKII limits (nothing in this tree was dropped or renamed to fit them):
  Internal storage holds 2,560 samples and 16 GB, including preload data.
  This archive lists ${ARCHIVE_ZIPS} zips whose file counts sum to ${ARCHIVE_FILES}
  (not all of those entries are WAV). That is more than 2,560 samples, so the
  whole collection cannot be imported into the unit at once. This selection is
  ${sel_n} ${sel_noun} / ${SEL_FILES} inner files. The script does not trim it.
  Each sample can be at most about 16 minutes / 185 MB, including SD import.
  Files shorter than 100 ms may fail to import; they are still copied.
  The reference manual does not state a per-folder file cap, so packs are not
  split. On-device sample names are 23 characters; card filenames are not
  shortened. Names longer than 80 characters crashed before system v4.06
  (fixed in that release).
EOF
    if [[ -n "$staged" ]]; then
        printf '  This run staged %s wavs.\n' "$staged"
        if (( staged > 2560 )); then
            printf '  This run is over the 2,560-sample internal cap. Nothing was removed.\n'
        fi
        if (( SHORT_N > 0 )); then
            printf '  %s staged file(s) are under 100 ms and may not import.\n' "$SHORT_N"
        fi
        if (( BIG_N > 0 )); then
            printf '  %s staged file(s) are over ~185 MB and may not import.\n' "$BIG_N"
        fi
        if (( LONG_N > 0 )); then
            printf '  %s filename(s) are longer than 80 characters.\n' "$LONG_N"
        fi
    fi
}

scan_staged() {
    SHORT_N=0
    BIG_N=0
    LONG_N=0
    [[ "$TARGET" == sp404 ]] || return 0
    local row zip size md5 folder filecount dir f base sz dur
    for row in "${SELECTED[@]}"; do
        IFS=$'\x1f' read -r zip size md5 folder filecount <<<"$row"
        dir="$OUT/$TARGET/$folder"
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' f; do
            base=$(basename -- "$f")
            if ((${#base} > 80)); then
                LONG_N=$((LONG_N + 1))
            fi
            sz=$(stat -c%s -- "$f")
            if (( sz > 185000000 )); then
                BIG_N=$((BIG_N + 1))
            fi
            # 100 ms of 192 kHz stereo 16-bit is under 80 KB. Larger files
            # are past the short-sample warning, so they are not probed.
            if (( sz < 80000 )); then
                dur=$(ffprobe -v error -show_entries format=duration \
                    -of default=noprint_wrappers=1:nokey=1 -- "$f" </dev/null 2>/dev/null || true)
                if awk -v d="${dur:-0}" 'BEGIN { d += 0; exit !(d > 0 && d < 0.1) }'; then
                    SHORT_N=$((SHORT_N + 1))
                fi
            fi
        done < <(find "$dir" -type f -iname '*.wav' -print0)
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            [[ $# -ge 2 ]] || die "--target requires a value"
            TARGET=$2
            shift 2
            ;;
        --preset)
            [[ $# -ge 2 ]] || die "--preset requires a value"
            PRESET=$2
            shift 2
            ;;
        --include)
            [[ $# -ge 2 ]] || die "--include requires a regex"
            INCLUDES+=("$2")
            shift 2
            ;;
        --exclude)
            [[ $# -ge 2 ]] || die "--exclude requires a regex"
            EXCLUDES+=("$2")
            shift 2
            ;;
        --list)
            LIST_ONLY=1
            shift
            ;;
        --card)
            [[ $# -ge 2 ]] || die "--card requires a path"
            CARD=$2
            shift 2
            ;;
        -j)
            [[ $# -ge 2 ]] || die "-j requires a number"
            JOBS=$2
            shift 2
            ;;
        -j*)
            JOBS=${1#-j}
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1 (try --help)"
            ;;
    esac
done

case "$PRESET" in
    all|classics) ;;
    *) die "Unknown preset: $PRESET (want all or classics)" ;;
esac
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || die "-j must be a positive integer"
if (( JOBS > 6 )); then
    printf '>> -j %s is high; archive.org is happier around 3\n' "$JOBS" >&2
fi
target_spec "$TARGET" rate >/dev/null || die "Unknown target: $TARGET (want m8 or sp404)"
RATE=$(target_spec "$TARGET" rate)
WHEN=$(target_spec "$TARGET" when)
LABEL=$(target_spec "$TARGET" label)
if [[ -n "$CARD" && "$LIST_ONLY" -eq 1 ]]; then
    die "--card cannot be used with --list"
fi
if [[ -n "$CARD" && ! -d "$CARD" ]]; then
    die "--card is not a directory: $CARD"
fi
for re in "${INCLUDES[@]+"${INCLUDES[@]}"}" "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
    [[ -n "$re" ]] || die "regex must not be empty"
    validate_regex "$re"
done

command -v curl >/dev/null || die "Missing: curl (pacman -S curl)"
command -v python3 >/dev/null || die "Missing: python3 (pacman -S python)"
if [[ "$LIST_ONLY" -eq 0 ]]; then
    for bin in ffmpeg ffprobe; do
        command -v "$bin" >/dev/null || die "Missing: $bin (pacman -S ffmpeg)"
    done
    if command -v 7z >/dev/null; then
        EXTRACT_STYLE=7z
    elif command -v bsdtar >/dev/null; then
        EXTRACT_STYLE=bsdtar
    else
        die "Missing: need 7z (p7zip) or bsdtar (libarchive)"
    fi
fi

RUN_DIR=$(mktemp -d)
trap 'rm -rf "$RUN_DIR"' EXIT
FAIL_DIR="$RUN_DIR/fail"
STAT_DIR="$RUN_DIR/stat"
SKIP_DIR="$RUN_DIR/skip"
mkdir -p -- "$FAIL_DIR" "$STAT_DIR" "$SKIP_DIR" "$CACHE" "$EXTRACT" "$OUT"

load_rows "$RUN_DIR/metadata.json" "$RUN_DIR/rows.tsv"

ARCHIVE_ZIPS=0
ARCHIVE_FILES=0
ARCHIVE_BYTES=0
ALL_ROWS=()
while IFS=$'\x1f' read -r zip size md5 folder filecount || [[ -n "${zip:-}" ]]; do
    [[ -n "${zip:-}" ]] || continue
    if [[ "$zip" == "#META" ]]; then
        ARCHIVE_ZIPS=$size
        ARCHIVE_FILES=$md5
        ARCHIVE_BYTES=$folder
        continue
    fi
    ALL_ROWS+=("$zip"$'\x1f'"$size"$'\x1f'"$md5"$'\x1f'"$folder"$'\x1f'"$filecount")
done < "$RUN_DIR/rows.tsv"

if [[ "$PRESET" == classics ]]; then
    for c in "${CLASSICS[@]}"; do
        if ! have_zip "$c"; then
            note_fail "${c%.zip}" "not in archive metadata"
        fi
    done
fi

SELECTED=()
SEL_BYTES=0
SEL_FILES=0
for row in "${ALL_ROWS[@]}"; do
    IFS=$'\x1f' read -r zip size md5 folder filecount <<<"$row"
    if [[ "$PRESET" == classics ]] && ! is_classic "$zip"; then
        continue
    fi
    keep=1
    if ((${#INCLUDES[@]} > 0)); then
        keep=0
        for re in "${INCLUDES[@]}"; do
            if name_matches "$re" "$folder" "$zip"; then
                keep=1
                break
            fi
        done
    fi
    if (( keep == 1 && ${#EXCLUDES[@]} > 0 )); then
        for re in "${EXCLUDES[@]}"; do
            if name_matches "$re" "$folder" "$zip"; then
                keep=0
                break
            fi
        done
    fi
    if (( keep == 0 )); then
        continue
    fi
    SELECTED+=("$row")
    SEL_BYTES=$((SEL_BYTES + size))
    SEL_FILES=$((SEL_FILES + filecount))
done

if [[ "$LIST_ONLY" -eq 1 ]]; then
    printf 'target %s (%s)\n' "$TARGET" "$LABEL"
    printf 'archive: %s zips, %s inner files, %s compressed\n' \
        "$ARCHIVE_ZIPS" "$ARCHIVE_FILES" "$(human_bytes "$ARCHIVE_BYTES")"
    printf '%12s  %-40s  %s\n' "SIZE" "FOLDER" "ZIP"
    for row in "${SELECTED[@]}"; do
        IFS=$'\x1f' read -r zip size md5 folder filecount <<<"$row"
        printf '%12s  %-40s  %s\n' "$(human_bytes "$size")" "$folder" "$zip"
    done
    printf '%s machines, %s total download\n' \
        "${#SELECTED[@]}" "$(human_bytes "$SEL_BYTES")"
    print_target_limits
    mapfile -t fail_files < <(find "$FAIL_DIR" -type f | sort)
    if ((${#fail_files[@]} > 0)); then
        exit 1
    fi
    exit 0
fi

printf '>> %s machines, %s total download\n' \
    "${#SELECTED[@]}" "$(human_bytes "$SEL_BYTES")"
printf '>> target %s (%s), jobs %s\n' "$TARGET" "$LABEL" "$JOBS"

if ((${#SELECTED[@]} == 0)); then
    printf 'No machines matched.\n'
    exit 0
fi

cached_n=0
need_n=0
for row in "${SELECTED[@]}"; do
    IFS=$'\x1f' read -r zip size md5 folder filecount <<<"$row"
    if size_ok "$CACHE/$zip" "$size"; then
        cached_n=$((cached_n + 1))
    else
        need_n=$((need_n + 1))
    fi
done
printf '>> %s already cached, %s to download\n' "$cached_n" "$need_n"

running=0
for row in "${SELECTED[@]}"; do
    IFS=$'\x1f' read -r zip size md5 folder filecount <<<"$row"
    process_one "$zip" "$size" "$md5" "$folder" &
    running=$((running + 1))
    if (( running >= JOBS )); then
        wait -n || true
        running=$((running - 1))
    fi
done
wait || true

for row in "${SELECTED[@]}"; do
    IFS=$'\x1f' read -r zip size md5 folder filecount <<<"$row"
    if [[ ! -f "$STAT_DIR/$folder" && ! -f "$FAIL_DIR/$folder" ]]; then
        note_fail "$folder" "did not finish"
    fi
done

staged_n=0
for row in "${SELECTED[@]}"; do
    IFS=$'\x1f' read -r zip size md5 folder filecount <<<"$row"
    if [[ -f "$STAT_DIR/$folder" ]]; then
        staged_n=$((staged_n + $(<"$STAT_DIR/$folder")))
    fi
done

scan_staged

printf '\nStaged %s wavs under %s/%s/\n' "$staged_n" "$OUT" "$TARGET"
print_target_limits "$staged_n"

card_rc=0
if [[ -n "$CARD" ]]; then
    copy_card || card_rc=1
fi

mapfile -t fail_files < <(find "$FAIL_DIR" -type f | sort)
mapfile -t skip_files < <(find "$SKIP_DIR" -type f | sort)
if ((${#fail_files[@]} > 0 || ${#skip_files[@]} > 0 || card_rc != 0)); then
    if ((${#fail_files[@]} > 0)); then
        printf '\nFailures (%s):\n' "${#fail_files[@]}"
        for f in "${fail_files[@]}"; do
            print_fail_file "$f"
        done
    fi
    if ((${#skip_files[@]} > 0)); then
        skip_n=0
        for f in "${skip_files[@]}"; do
            skip_n=$((skip_n + $(wc -l < "$f" | tr -d ' ')))
        done
        printf '\nSkipped files (%s):\n' "$skip_n"
        for f in "${skip_files[@]}"; do
            folder=$(basename -- "$f")
            while IFS=$'\t' read -r rel msg || [[ -n "${rel:-}" ]]; do
                [[ -n "${rel:-}" ]] || continue
                printf '  %s: %s: %s\n' "$folder" "$rel" "$msg"
            done < "$f"
        done
    fi
    if (( card_rc != 0 )); then
        printf 'Card copy failed.\n' >&2
    fi
    exit 1
fi

printf '\nCopy onto the card (does not delete existing files):\n'
printf '  %s --target %s --card /run/media/<user>/<CARD>\n' "$0" "$TARGET"
printf 'lands in /%s/<Machine>/\n' "$(target_spec "$TARGET" card)"
