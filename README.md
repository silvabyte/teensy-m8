# teensy-m8

M8 headless on a Teensy 4.1, driven by the host keyboard, on Arch Linux.

## Hardware

- Teensy 4.1
- microSD (≤32GB: FAT32 / >32GB: exFAT)
- microUSB cable, plugged directly into the PC (no hub)

## Files

| File | What it does |
|---|---|
| `setup.sh` | Installs deps and drops the Teensy udev rule |
| `flash.sh` | Downloads the latest M8 headless `.hex` and flashes the Teensy |
| `play.sh` | Runs `run.sh` + `monitor.sh` together — one command, one terminal |
| `run.sh` | Launches `m8c` |
| `monitor.sh` | Routes M8 audio into your default sink via `pw-loopback` |
| `fetch-content.sh` | Pulls community samples / instruments / themes into `./content/` |
| `fetch-drums.sh` | Pulls the archive.org drum-machines-collection and stages 16-bit WAV for the M8 or the SP-404MKII |
| `add-sample.sh` | Converts, names, and copies one media file to the M8 microSD card |
| `prep-samples.sh` | Batch-converts a folder of audio to M8-ready WAV (44.1k / 16-bit) |
| `m8c-config.ini` | Keyboard mapping (copied into `~/.local/share/m8c/` by `run.sh`) |
| `udev/` | udev rule for the Teensy |

## Steps

1. **Setup** &nbsp; `./setup.sh`
2. **Flash** &nbsp; Plug in Teensy → `./flash.sh` → press the button when prompted
3. **microSD** &nbsp; Format, insert into the Teensy
4. **Play + hear it** &nbsp; `./play.sh` (launches `m8c` and routes audio; Ctrl+C stops both)

Prefer separate terminals? Run `./run.sh` in one and `./monitor.sh` in another.

## Controls

See [CHEATSHEET.md](./CHEATSHEET.md) for the keyboard → M8 button map and the essential M8 combos.

Remap by editing `m8c-config.ini` (SDL scancodes) and re-running `./run.sh`.

## SD card content

The firmware ZIP is `.hex` only — no factory samples. Source content from the community.

SD layout (FAT32 ≤32 GB / exFAT >32 GB), all at the root. The headless firmware
creates the skeleton (`Bundles Instruments Renders Samples Scales Songs System
Themes`) on first boot:

```
/Bundles/      full projects, each in its own folder (NAME.m8s + its Instruments/ + Samples/)
/Samples/      .wav — M8 plays 16-bit PCM only (44.1 kHz recommended), mono or stereo; subfolders OK
/Instruments/  .m8i presets; subfolders OK
/Songs/        standalone .m8s (reference samples by path)
/Themes/       .m8t
```

`/Bundles/` is the easy win: load one and its samples + instruments resolve
automatically. The community starter pack ships its demo songs as bundles (not
in `/Songs/`).

Stage starter content locally:

```
./fetch-content.sh        # pulls into ./content/
```

This grabs the community starter pack (samples + songs), plus `laamaa/m8i` and
`tobokegao` instrument packs and `d-huck/m8-themes`. Copy what you want into
the matching dirs on the SD.

For a drum-machine sample library (the starter pack has almost no standalone
samples), `./fetch-drums.sh` reads every ZIP from the archive.org metadata for
`drum-machines-collection` (470 packs, 3.8 GiB / about 4.1 GB compressed) and stages
them under `./content/drums/<target>/<Machine>/`. The default target is the M8.
`--preset classics` is the old 15-pack set (808 / 909 / CR-78 / LinnDrum /
606 / 707 / 727 / Oberheim DMX+DX / SP-1200 / Drumulator / Drumtraks / Casio
RZ-1 / Simmons SDS5).

```
./fetch-drums.sh --list                         # names and sizes, no download
./fetch-drums.sh --preset classics              # the original 15, for the M8
./fetch-drums.sh --include 'TR808|TR-909' -j 3
./fetch-drums.sh --card /run/media/$USER/<CARD>
./fetch-drums.sh --target sp404 --card /run/media/$USER/<CARD>
```

`--include` / `--exclude` are extended regexes matched against the folder name
and the zip name. Repeat either flag: includes are OR, then excludes drop
matches. `-j` is how many machines to fetch at once (default 3).

Zips land in `content/.cache/drum-machines` and are extracted once, so running
M8 and then SP-404 does not download twice. A finished zip is skipped when its
size matches the metadata (a new download is also checked against the md5).
Partial downloads stay in a `.part` file. Already-staged WAV files are skipped.
One machine failing is logged; the rest continue; the script exits non-zero
and prints the failures.

`--card` copies the staged tree with `rsync -a` when rsync exists, otherwise
`cp -a`. It never deletes files already on the card.

**M8** (`--target m8`, the default). 16-bit PCM WAV. A file that is already
16-bit is copied unchanged; anything else is rewritten to 44.1 kHz / 16-bit.
`--card` puts each machine in `/Samples/<Machine>/`.

**SP-404MKII** (`--target sp404`). 48 kHz / 16-bit linear WAV, which is what
the unit stores. SD import accepts 16-bit linear WAV, AIFF, or MP3 from the
`IMPORT` folder, including subfolders, and converts imports to 48 kHz / 16-bit.
`--card` puts each machine in `/IMPORT/<Machine>/`.

The reference manual caps internal storage at 2,560 samples and 16 GB
(including the preload data), and each sample at about 16 minutes / 185 MB.
That per-sample cap applies to SD import too. Archive.org's zip file counts
sum to about 49,000 entries across the 470 packs, which is more than 2,560
samples, so the whole library cannot live in the unit at once. The script
copies every file and says so. It does not drop files, split folders, or
shorten names to fit. The manual does not state a per-folder file cap. Files
shorter than 100 ms may fail to import. Filenames longer than 80 characters
crashed on import before system v4.06 (fixed in that version). On-device
sample names are 23 characters when you rename them on the unit; filenames on
the card are left as they are.

Roland pages used for the SP-404 output:
[import formats](https://support.roland.com/hc/en-us/articles/4408190553883-SP-404MK2-What-audio-file-formats-can-be-imported-into-the-SP-404MK2),
[IMPORT SAMPLE](https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/7958977178537867.html),
[main specifications](https://static.roland.com/manuals/sp-404mk2_reference_v550/en-US/8010023578592395.html),
[maximum sampling time](https://support.roland.com/hc/en-us/articles/4408196941851-SP-404MK2-Maximum-Sampling-Time).

For samples from outside these packs:

```
./add-sample.sh ~/Videos/snare.mkv "Big Snare"
```

This extracts the first audio stream, converts it to a stereo 44.1 kHz / 16-bit
WAV, and writes `/Samples/Big Snare.wav` to the mounted M8 microSD card. If the
card cannot be detected automatically, pass its mount point explicitly:

```
./add-sample.sh ~/Videos/snare.mkv "Big Snare" /run/media/$USER/M8CARD
```

The command refuses to overwrite an existing sample. For batch conversion
without copying to the card, use:

```
./prep-samples.sh ~/some-folder-of-wavs
```

Produces `*.m8.wav` siblings at 44.1 kHz / 16-bit / stereo.

More: [patchstorage.com (Dirtywave M8)](https://patchstorage.com/platform/dirtywave-m8/),
[m8them.es](https://m8them.es/),
[awesome-m8](https://github.com/v3rm0n/awesome-m8).

## Sanity checks

```
lsusb | grep 16c0                          # M8 enumerated (product 0489)
wpctl status | grep -iE 'teensy|m8'        # audio source visible
```

## Always-on audio monitor

Drop into `~/.config/systemd/user/m8-monitor.service`:

```ini
[Unit]
Description=M8 audio monitor
After=pipewire.service
Wants=pipewire.service

[Service]
ExecStart=%h/code/teensy-m8/monitor.sh
Restart=on-failure

[Install]
WantedBy=default.target
```

Then `systemctl --user enable --now m8-monitor`.

## Upstream

- Setup guide: <https://github.com/DirtyWave/M8Docs/blob/main/docs/M8HeadlessSetup.md>
- Firmware: <https://github.com/DirtyWave/M8HeadlessFirmware>
- Display client: <https://github.com/laamaa/m8c>
