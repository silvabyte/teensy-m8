# M8 Cheatsheet

Steam Controller → m8c → M8.

## Button map

| Steam Controller | M8 button | Notes |
|---|---|---|
| D-pad / left stick | UP / DOWN / LEFT / RIGHT | Navigate cells |
| **A** | EDIT | Enter cell, change value |
| **B** | OPT | Secondary / modifier |
| **Back** | SHIFT (Select) | Modifier |
| **Start** | PLAY | Play / pause |
| Guide | quit m8c | |
| L-stick click | reset M8 | |

The M8 has only 8 buttons: 4 directions + **SHIFT, PLAY, OPT, EDIT**. Everything is combos.

## Essential combos

| Combo | Action |
|---|---|
| `PLAY` | Toggle play / stop |
| `SHIFT + PLAY` | Play from start of song |
| `EDIT` | Enter / edit value in current cell |
| `OPT + ↑ / ↓` | Nudge value ±1 |
| `SHIFT + OPT + ↑ / ↓` | Nudge value ±16 |
| `SHIFT + ↑ / ↓ / ← / →` | Jump to edge of column / row |
| `OPT + ← / →` | Switch screen (song → chain → phrase → …) |
| `SHIFT + EDIT` | Copy (hold + drag to select region) |
| `OPT + EDIT` | Cut |
| `SHIFT + OPT + EDIT` | Paste |
| Hold `SHIFT`, tap `OPT` | Open project / settings menu |

## Screen hierarchy

You drill down with `EDIT` on a value, back out with `OPT` (depending on screen).

```
Song  →  Chain  →  Phrase  →  Instrument / Table / Groove
```

- **Song** — top-level arrangement. Each row triggers chains across 8 tracks.
- **Chain** — sequence of phrases.
- **Phrase** — the actual notes + FX commands.
- **Instrument** — sound design (wavsynth, macrosynth, sample, FM, etc.).
- **Table** — automation / arpeggios that run per-note.
- **Groove** — swing / timing per row.

## First-time flow

1. `OPT + ←/→` to **Song** screen.
2. Cursor on row `00`, column `1` → `EDIT` → it creates chain `00`.
3. `EDIT` again to enter chain `00`. Add phrase `00`.
4. `EDIT` into phrase `00`. Enter notes with `EDIT` on note column.
5. `PLAY` to hear it.

## RTFM

The official manual is the source of truth — combos vary slightly by firmware version:

- Manual: <https://dirtywave.com/pages/m8-tracker-manual> (also bundled on the microSD)
- Community wiki: <https://github.com/DirtyWave/M8Docs>
- Quickstart videos: search "M8 tracker tutorial" on YouTube — Cuttoff and timetocode have solid beginner series.
