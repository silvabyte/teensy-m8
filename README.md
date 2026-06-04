# teensy-m8

M8 headless on a Teensy 4.1, driven by a wired Steam Controller, on Arch Linux.

## Hardware

- Teensy 4.1
- microSD (≤32GB: FAT32 / >32GB: exFAT)
- Steam Controller + USB cable
- microUSB cable, plugged directly into the PC (no hub)

## Files

| File | What it does |
|---|---|
| `setup.sh` | Installs deps, drops udev rules, adds you to `uinput` group |
| `flash.sh` | Downloads the latest M8 headless `.hex` and flashes the Teensy |
| `run.sh` | Starts `sc-controller-daemon` and launches `m8c` |
| `monitor.sh` | Routes M8 audio into your default sink via `pw-loopback` |
| `m8c-config.ini` | Gamepad mapping (copied into `~/.local/share/m8c/` by `run.sh`) |
| `udev/` | udev rules for Teensy + Steam Controller |

## Steps

1. **Setup** &nbsp; `./setup.sh` &nbsp; (log out + back in if it added you to `uinput`)
2. **Flash** &nbsp; Plug in Teensy → `./flash.sh` → press the button when prompted
3. **microSD** &nbsp; Format, insert into the Teensy
4. **Play** &nbsp; Plug in Steam Controller → `./run.sh`
5. **Hear it** &nbsp; In a second terminal: `./monitor.sh`

## Controls

Default sc-controller profile emulates an Xbox pad. m8c reads it as:

| Steam Controller | M8 |
|---|---|
| D-pad / left stick | Up / Down / Left / Right |
| A | Edit |
| B | Opt |
| Back | Select |
| Start | Start |
| Guide | Quit |
| L-stick click | Reset |

Remap on the SC side via the `sc-controller` GUI; m8c picks up changes live.

## Sanity checks

```
lsusb | grep 16c0                          # M8 enumerated (product 0489)
wpctl status | grep -iE 'teensy|m8'        # audio source visible
ls /dev/input/by-id/ | grep -i steam       # SC visible
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
