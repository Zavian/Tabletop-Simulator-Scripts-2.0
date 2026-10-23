# Monster UI icons

`mon-*.png` are used by `src/modules/monster_ui.lua` (HP/stress pips, difficulty shield, condition row).

Glyphs from [Icons8](https://icons8.com) (Material Rounded style), tinted per use. Icons8 free
icons require attribution with a link to icons8.com; this file is that attribution.

| File | Icons8 glyph |
|---|---|
| mon-hp-filled / mon-hp-empty | heart |
| mon-stress-filled / mon-stress-empty | lightning bolt |
| mon-armor-filled / mon-armor-empty | shield |
| mon-stressed | quick mode on |
| mon-vulnerable | accuracy |
| mon-bloodied | broken heart |
| mon-restrained | anchor |
| mon-hidden | hide |

Hosted copy: `https://upload.zaes.dev/i/tts-monster-icons-png/<file>` (uploaded with `format=png`, since the
default WebP conversion does not load in TTS UI images). `ICON_BASE` in `monster_ui.lua` points there.

## Player panel (`assets/icons/player/`)

`hp`, `stress` (flame), `sun` (hope) and `armor` filled/empty pairs used by `src/modules/player_injector.lua`.
Hosted at `https://upload.zaes.dev/i/tts-player-icons/<file>`. The previous player injector is kept in `src/deprecated/`.
