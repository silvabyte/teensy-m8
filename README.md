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
| `fetch-drums.sh` | Pulls curated classic drum-machine packs (808/909/CR-78/LinnDrum/...), M8-ready, into `./content/drums/` |
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
samples):

```
./fetch-drums.sh         # stages classic machines under ./content/drums/
cp -r ./content/drums/* /run/media/$USER/<CARD>/Samples/
```

This grabs 808 / 909 / CR-78 / LinnDrum / 606 / 707 / 727 / Oberheim DMX+DX /
SP-1200 / Drumulator / Drumtraks / Casio RZ-1 / Simmons SDS5 from the archive.org
`drum-machines-collection`, transcoding any 24/32-bit samples down to the 16-bit
PCM the M8 requires. Land them under `/Samples/DrumMachines/<Machine>/`.

For samples from outside these packs:

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
