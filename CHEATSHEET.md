# M8 Cheatsheet

Keyboard → m8c → M8.

## Key map

The M8 has only 8 buttons: 4 directions + **SHIFT, PLAY, OPTION, EDIT**. Everything is combos.

| Key | M8 button | Notes |
|---|---|---|
| Arrow keys | UP / DOWN / LEFT / RIGHT | Move cursor |
| **Shift** | SHIFT | Modifier / select |
| **Z** | OPTION | Modifier / back / no |
| **X** | EDIT | Enter / edit / yes |
| **Space** | PLAY | Play / stop |
| `Delete` | — | m8c clear value (extra) |
| `R` | — | m8c reset device (extra) |

Shortcuts below use the **M8 button names** (SHIFT / OPTION / EDIT / PLAY). Translate
with the table above — e.g. "Hold SHIFT + OPTION" = hold **Shift** + **Z**.

## Navigation

| Action | Combo |
|---|---|
| Move cursor | UP / DOWN / LEFT / RIGHT |
| Screen navigation | Hold SHIFT + [UP / DOWN / LEFT / RIGHT] |

## Editing

| Action | Combo |
|---|---|
| Change value (fine) | Hold EDIT + [LEFT / RIGHT] |
| Change value (coarse) | Hold EDIT + [UP / DOWN] |
| Cut value (cut / set to default) | EDIT + OPTION |
| YES (when prompted) | EDIT |
| NO (also exit sub-views) | OPTION |

## Play

| Action | Combo |
|---|---|
| Play all tracks (outside song view) | Hold SHIFT + PLAY |
| Mute current track | Hold OPTION + SHIFT — latch by releasing OPTION first |
| Solo current track | Hold OPTION + PLAY — latch by releasing OPTION first |
| Clear all mutes / solos | Hold OPTION + hold SHIFT + PLAY |

## Selection

| Action | Combo |
|---|---|
| Enter selection mode | Hold SHIFT + OPTION — tap OPTION to cycle modes |
| Copy selection (and exit) | OPTION |
| Paste selection | Hold SHIFT + EDIT |

## Phrase View

| Action | Combo |
|---|---|
| Create (new instrument) | On instrument column, EDIT (double-tap) |
| Clone and paste (instrument) | Hold SHIFT + OPTION then EDIT |
| Jump to track (left / right) | Hold OPTION + [LEFT / RIGHT] |
| Jump to phrase (prev / next) | Hold OPTION + [UP / DOWN] |
| Interpolate (selection) | With a single column selected, hold SHIFT + EDIT |
| Nudge (within a selection) | In selection mode, hold EDIT + [UP / DOWN] |
| Note fill — FILL modes | In selection mode (note column): OPTION + LEFT |
| Note fill — random fill | OPTION + RIGHT |
| Note fill — random note pitch | OPTION + [UP / DOWN] |

## Song View

| Action | Combo |
|---|---|
| Cue row (while playing) | Hold LEFT + PLAY |
| Create (new chain) | Double-tap EDIT |
| Clone and paste (chain alone) | Hold SHIFT + OPTION then EDIT |
| Clone and paste (chain & phrases) | Hold SHIFT + OPTION then double-tap EDIT |
| Solo tracks (left / right) | Hold OPTION + [LEFT / RIGHT] |
| Jump 16 rows (up / down) | Hold OPTION + [UP / DOWN] |
| Move selection | In selection mode, hold EDIT + [UP / DOWN] |
| Render selection | In selection mode, double-tap EDIT |

## Chain View

| Action | Combo |
|---|---|
| Create (new phrase) | Double-tap EDIT |
| Clone and paste (phrase) | Hold SHIFT + OPTION then EDIT |
| Jump to track (left / right) | Hold OPTION + [LEFT / RIGHT] |
| Jump to chain (prev / next) | Hold OPTION + [UP / DOWN] |

## Instrument View

| Action | Combo |
|---|---|
| Preview instrument | Hold EDIT + PLAY |
| Copy | Hold SHIFT + OPTION |
| Paste | Hold SHIFT + EDIT |
| Jump to instrument (prev / next) | OPTION + [LEFT / RIGHT] |

## Table View

| Action | Combo |
|---|---|
| Interpolate values | While in selection mode, hold SHIFT + EDIT |
| Jump to table (prev / next) | OPTION + [LEFT / RIGHT] |

## Mixer View

| Action | Combo |
|---|---|
| Create snapshot | Hold SHIFT + OPTION |
| Recall snapshot | Hold SHIFT + EDIT |

## File Browser

| Action | Combo |
|---|---|
| Sort directory | SHIFT + OPTION |
| Delete selected file | OPTION + EDIT |

## Screen hierarchy

Drill down with `EDIT` on a value, back out with `OPTION`.

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

1. `OPTION + ←/→` to the **Song** screen.
2. Cursor on row `00`, column `1` → `EDIT` → creates chain `00`.
3. `EDIT` again to enter chain `00`. Add phrase `00`.
4. `EDIT` into phrase `00`. Enter notes with `EDIT` on the note column.
5. `PLAY` to hear it.

## RTFM

The official manual is the source of truth — combos vary slightly by firmware version:

- Manual: <https://dirtywave.com/pages/m8-tracker-manual> (also bundled on the microSD)
- Community wiki: <https://github.com/DirtyWave/M8Docs>
- Quickstart videos: search "M8 tracker tutorial" on YouTube — Cuttoff and timetocode have solid beginner series.
</content>
</invoke>
