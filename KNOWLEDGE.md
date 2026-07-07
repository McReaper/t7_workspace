# Investigations

In this document, there will be tips and stuff around my investigations and discoveries around treyarch engine (scripts, audio, image, videos, tools, general knowledge, etc). I think this effort is worth it considering me starting from scratch, for a later me or newcomer.

## Umbra

Culling issues can be fixed in narrowed spots with two techniques:
- For brushes: *Select the brushes* -> *Right click* -> `Make Umbra Target`
- For entities: *Select the entities* -> Add the user kvp `umbra_target_only`:`1`

But ... I found out this can FUCK THINGS AROUND! Removing these tweaks can save you some weird side effects of texture disappearing when you're close from it.

## Wtf

If blackhole script used to teleport player on a tilted entities, the player world axis is tilted as well, making it like the world has been tilted upside down lol 

## Sound/Audio format

- Wav file
- 48000 Hz
- Signed 16-bit PCM
- Stereo or Mono channel

> Remark: if audio `Bus` value is on `BUS_FX`, but `IsMusic` value is `yes`, it will play on `BUS_MUSIC` anyway.

## ZM character VOX tables (`share\raw\gamedata\audio\zm\*_vox.csv`)

These **headerless** CSVs map gameplay *events* to playable-character voice barks ("vox") — one file per character set (`zm_moon_vox` = Moon/O4 crew, `zm_usmc_vox` = the marines). Parsed row-by-row by `zm_audio::loadplayervoicecategories(table)` in [`_zm_audio.gsc`](.\share\raw\scripts\zm\_zm_audio.gsc) (→ `zmbvoxadd`), and fired in-game by `create_and_play_dialog(category, subcategory)`. The file is registered as a stringtable in the sound zone.

One row = one event line. Columns are **positional** (`row[0..5]`):

| # | Column | Role |
| - | ------ | ---- |
| 1 | **category** | Event group the line belongs to: `general`, `kill`, `perk`, `powerup`, `weapon_pickup`, `box_pickup`, `bgb`, `trap`. Lookup is `level.sndplayervox[category][subcategory]`. |
| 2 | **subcategory** | The exact event key that fired within the category — `headshot`, `melee`, `streak`, `ammo_low`, `intro`, `nuke`, the perk specialty (`specialty_armorvest`…), or the weapon class (`smg`/`shotgun`/`sniper`…). This is the key gameplay code passes to `create_and_play_dialog`. |
| 3 | **suffix** | The vox line key. The played sound alias = *speaking character's vox prefix* `+ suffix +` random variant (`zmbvoxgetlinevariant`), so the **same suffix resolves to different recordings per character** (e.g. `kill_headshot`, `perk_jugga`, `wpck_smg`, `level_start`). |
| 4 | **percentage** | Chance (0–100) the line plays when the event fires (rolled in `shouldplayerspeak`). `int(row[3])`; **blank or ≤ 0 → 100** (always). |
| 5 | **response** | `TRUE`/`FALSE` (blank = false). `TRUE` makes the loader auto-register 4 teammate-callback lines `<subcategory>_resp_0..3 → <suffix>_resp_0..3` at **50%** each (other characters answer the bark). The manual `_hr`/`_riv`/`_s` rows in `zm_moon_vox` are just extra per-character response subcategories on top of this. |
| 6 | **delaybeforeplayagain** | Per-player cooldown in **seconds** before this same line may repeat (default `0`; enforced via `player.voxtimer`). e.g. `120` on `outofmoney`, raygun kills, `hellhound` = at most once / 2 min. |

> `zm_usmc_vox.csv` has only **5 columns** (omits col 6) → cooldown defaults to `0`. `zm_moon_vox.csv` has all **6** (+ a trailing comma). Empty col 4 = "always"; empty/absent col 5 = "no teammate callbacks".

> Source: decompiled `_zm_audio.gsc` (`loadplayervoicecategories` → `zmbvoxadd` → `create_and_play_dialog` → `shouldplayerspeak`/`zmbvoxgetlinevariant`).

### Suffix → alias naming convention

Col 3 (`suffix`) is a free *label* — but it's only the **middle** of a strict alias name the engine assembles at play time:

```
vox_plr_<index>_<suffix>_<variant>
```

- `<index>` = player slot **0–3** (`zm_utility::get_player_index`), or **4** for Samantha (`player.issamantha`). The prefix `vox_plr_<index>_` comes from `shouldplayerspeak`.
- `<variant>` = 0-based take; the engine counts them with `zm_spawner::get_number_variants("vox_plr_<index>_<suffix>")` and random-picks (drains an "available" pool so a take won't immediately repeat).

Consequences:
- **One CSV row covers all characters** — the *only* per-character difference is the `vox_plr_<index>_` prefix, so each slot needs its own `vox_plr_<index>_<suffix>_<N>` aliases (variant counts may differ per character). e.g. row `kill,headshot,kill_headshot,…` ⇒ aliases `vox_plr_0_kill_headshot_0`, `vox_plr_0_kill_headshot_1`, … and likewise for `_1_`/`_2_`/`_3_`/`_4_`.
- `response=TRUE` additionally needs `vox_plr_<index>_<suffix>_resp_0..3_<variant>` aliases for the teammate callbacks.
- **Silent failure:** if nothing resolves (`get_number_variants(prefix+suffix) <= 0`), `zmbvoxgetlinevariant` returns `undefined` and the bark just **doesn't play — no error**. A typo'd suffix or a missing `_0` variant goes quiet.

### Gotcha: duplicate `(category, subcategory)` → last row wins

The table is keyed **only on cols 1–2** (`level.sndplayervox[category][subcategory]`), and `zmbvoxadd` does an unconditional `vox[category][subcategory] = spawnstruct()`. Two rows sharing the first two columns ⇒ the **later row silently overwrites** the earlier one — its suffix/percentage/response/cooldown are discarded. No merge, no random pick between them, no warning. (Multiple takes of one line are NOT extra rows — they're extra WAVs under the single alias, i.e. the `_<variant>` tail counted by `get_number_variants`.)

## Video format

Note: videos must be in `usermaps\zm_test\zone\video` to be embedded in the map. Full tutorial [here](https://wiki.modme.co/wiki/black_ops_3/intermediate/Setting-Up-Loadscreen-Videos.html)

- The format must be MKV
- There must be NO audio tracks
- There must be NO subtitle tracks
- H.264 encoding
- Select 720p30fps as a base

If when playing MKV videos, the game crashes, then the version of the software use to make the MKV is too recent:
- Use handbrake 1.0.3

## Loadscreen audio (cutscene sound binding)

The big mystery: how the loadscreen video gets its sound. **It's a pure engine-side naming convention** - nothing is embedded in the mkv (it must have NO audio track anyway), there is no reference field in the `.szc`/zone, and no GSC/LUA hook is involved. When the engine plays the loadscreen movie `zm_<map>_load.mkv`, it auto-looks-up a *cinematic* sound alias derived from the video filename:

- Alias `Name` = `bik_` + video basename -> **`bik_zm_<map>_load`** (e.g. `bik_zm_test_load`).
- Template `CIN_C_MOD` (center) is the minimal "just make sound come out" version. For real surround, add channel variants: `bik_zm_<map>_load_lr` (`CIN_LR_MOD`), `..._sur` (`CIN_S_MOD`/`CIN_QUAD_MOD`), `..._c` (`CIN_C_MOD`), `..._lfe` (`CIN_LFE_MOD`).
- `IsCinematic` = `yes`.

**Gotcha that cost me time:** the names you see *inside* a shipped `.sabs` (e.g. `zod_load_lr.SN100.pc.snd` in `core_post_gfx.all.sabs`) are the **compiled stream filenames**, NOT the alias names. The real alias is `bik_zm_zod_load_lr`; the `.SN100.pc.snd` is just the streamed output. Never put `.SN100.pc.snd` in the alias `Name` column.

### Why it needs a mod (the real 10-year wall)

A map's loadscreen plays **while that map's own `.ff` is still loading**, so nothing inside the map fastfile is available yet - including its sound bank. The audio has to live in a fastfile that is *already resident*:

- Treyarch's loadscreen audio sits in **`core_post_gfx`** (resident from boot - "played from the main menu, not bundled with their maps"). Can't touch it without overwriting core files.
- Our only equivalent is a `>type,common` fastfile = **a mod** (resident, loaded before the map).

Zone `>type` is the deciding factor (see `share\raw\zone_source\*.class`):
- `zm_mod.class` -> `>type,common` -> resident (this is a mod).
- `zm_level.class` / `zm_mod_level.class` -> `>type,level` -> loaded *with* the map.

`zm_mod_level` does NOT make a map resident - it is still `>type,level`. It only lets the map *build standalone* (`ignore_missing_shipped,zm_levelcommon`), which is why even The Giant (`zm_giant.zone`) uses it. A playable level can't be `>type,common`, so "map + resident loadscreen audio" is unavoidably **two fastfiles**, and the resident one is a mod by definition. The `.szc` `IsCommon` flag does not help - it marks the zone as shared across game modes, not resident at boot.

Workshop won't rescue this either: it does not auto-download/auto-activate a required mod (only a "required mod" popup). Load order is always: enable mod -> load map.

### Fade-in gotcha

The loadscreen blackscreen applies a duck (`.duk`) that fades audio in, and cinematic/scripted audio obeys it, so expect a short ramp at the very start. Author the wav with a beat of lead-in, or tweak the sound's occlusion/pan settings.

### Two practical options

1. **Real loadscreen audio** -> ship a small companion **mod** (`>type,common`; copy `rex\templates\Mod\mods\template\zone_source\zm_mod.zone`) whose sound zone defines `bik_zm_<map>_load`. Correct and matches Treyarch, but players must enable the mod before loading the map.
2. **No mod, fully self-contained** -> scripted pseudo-intro: wait for all players to connect, then `lui::play_movie(..., "fullscreen")` ([`lui_shared.gsc`](.\share\raw\scripts\shared\lui_shared.gsc#L216)) + play the sound on the player. In-game movie playback does NOT auto-pair a sound (`_play_movie_for_player` just opens the LUI menu), so you trigger both yourself. Not a true loadscreen, but needs no mod and has no residency problem.

> Sources: modme "Setting-Up-Loadscreen-Videos" tutorial; bo3modtools Discord loadscreen-sound threads (2020-2024, OG modders confirming "sound is played from the main menu, not bundled with their maps"); engine build classes in `share\raw\zone_source\`.

## Having theater mode working in custom maps

To have theater mode working in custom zombie maps, there a few pre-requisites, and tricks to have it working...
- **Disclaimer**: I just did it with my own maps, I never tried with a map from the workshop. Guidelines can be found at https://airyz.xyz/p/boiii-for-editing/
- **Disclaimer 2**: I did install boiii client from https://github.com/Ezz-lol/boiii-free before switching back to another version, could have an impact on the final result.
- **Disclaimer 3**: bo3tool from devraw never worked for the demo injection, it always crashed, so same story, I used another version.

**Pre-requisites**:
- boiii redacted client installed from ViktorSMI (with Theater server): https://github.com/ViktorSMI/boiii-redacted
- bo3tool v2.0.9 at https://airyz.xyz/p/bo3-tool/ or https://airyz.xyz/software/tool/editing/bo3-tool/BO3Tool.zip

**Tips**:
- Use a controller in theater mode, it's intuitive and it works even if you don't have the focus on the game.
- In theater mode, quick forward and backward operations may crash the game, keep a task manager open.

**Steps**:
- Initial setup:
  - Launch boiii client
  - Launch a game
  - Close the game entirely
  - Change boiii client dvar config at `boiii_players\user\config.cfg` with:
    ```cfg
    set demo_enableSvBandwidthLimitThrottle "0"
    set demo_enableAdvancedCameraControls "1"
    set demo_recordSystemLinkMatch "1"
    set demo_recordOfflineMatch "1"
    set demo_recordStaticEntityPositions "1"
    set demo_recordingRate "100"
    set demo_filesizeLimit "200"
    ```
    And then put it in readonly via windows properties menu to avoid having it overriden by the game at launch.
- Record a demo:
  - Launch boiii client
  - Load the mod: Mods ➡️ Select the mod associated to the map
  - Play a game of the associated custom map
  - Finish the game normally
  - From there, play a game from an official map
  - Finish the game normally
  - Close the game entirely
- Replay a recorded demo in theater mode:
  > Inspired from the manual steps at : https://airyz.xyz/p/boiii-for-editing/ (I saved a PDF of the page in case it goes down)
  - Manual injection (because bo3tool always crashed for me):
    - Go to `boiii_players\user\demos`
    - **Delete** these three files from the demo of the custom map:
      1. `zclassic_zm_YOURMAP_XX_XX_XXXX_XX_XX.demo.summary`
      1. `zclassic_zm_YOURMAP_XX_XX_XXXX_XX_XX.demo.tags`
      1. `zclassic_zm_YOURMAP_XX_XX_XXXX_XX_XX.demo.thumbnail`
    - **Delete** these two files from the demo of the official map (here it's shadow of evil):
      1. `zclassic_zm_zod_XX_XX_XXXX_XX_XX.demo`
      1. `zclassic_zm_zod_XX_XX_XXXX_XX_XX.demo.mod` (_can be missing if you unloaded the mod_)
    - Copy the name of your custom map demo: `zclassic_zm_YOURMAP_XX_XX_XXXX_XX_XX.demo` (including `.demo` yes)
    - **Rename** these three files from the demo of the official map to the custom map:
      1. `zclassic_zm_zod_XX_XX_XXXX_XX_XX.demo.summary` ➡️ F2 ➡️ Ctrl+V ➡️ Enter
      1. `zclassic_zm_zod_XX_XX_XXXX_XX_XX.demo.tags` ➡️ F2 ➡️ Ctrl+V ➡️ Enter
      1. `zclassic_zm_zod_XX_XX_XXXX_XX_XX.demo.thumbnail` ➡️ F2 ➡️ Ctrl+V ➡️ Enter
  - Launch boiii client
  - Load the mod: Mods ➡️ Select the mod associated to the map
  - Go to Zombie ➡️ Theater mode ➡️ Select ➡️ Select the replay here
  - Done, replay is playing.
  - You can use bo3 tool to tweak the camera settings.


## Custom postfx filters (script-driven constants)

A custom fullscreen postfx = a HLSL shader (`share\raw\shaders_stable\postfx\*.hlsl`) + a techsetdef (`share\raw\techsetdefs_stable\postfx\*.techsetdef` and a `_toolsgfx` twin) + a `2d` material whose `materialType` matches, applied client-side (CSC) with the `filter::` API: `filter::map_material_helper` → `setfilterpassmaterial` → `setfilterpassenabled`. Base look is tuned in APE. To animate it from script each frame you call `SetFilterPassConstant`.

### THE trap that cost me days: material `<cgNN>` constants ≠ script vectors

There are **two physically different constant buffers** that share the same "cgN ↔ scriptVectorN" numbering:

- **Material constants** — what you get when the techsetdef declares `float1("foo") { x = <cg03_x> tweak = Tweak(){...} }`. The value comes from the **material** (APE / GDT `cg03_x`). Renders fine. **`SetFilterPassConstant` does NOT touch it.**
- **Script vectors** — `float4 scriptVector0..7` in `cbuffer GenericsCBuffer : register(b3)` (defined in [`code\hlslcodeconstantbuffers.h`](.\share\raw\shaders_stable\code\hlslcodeconstantbuffers.h), `packoffset(c0..c7)`). This is **exactly** what `SetFilterPassConstant` writes.

So a shader value is script-drivable **only if the shader reads `scriptVectorN` directly**. If it reads a material `<cgNN>` constant, `SetFilterPassConstant` has zero visible effect **no matter what index or filter slot you use** — the base look still shows (material side), but nothing you push ever arrives. This is silent; no error.

Fix pattern in the shader:
```hlsl
// NOT: float vignetteDynamic;   // <cg03_x> in the techsetdef  -> material, dead to script
#if !TOOLSGFX
    float vignetteDynamic = scriptVector3.x;   // reads GenericsCBuffer -> SetFilterPassConstant works
#endif
```
And **do not** declare those constants in the techsetdef (no `<cgNN>` + Tweak for them). Shipped proof: [`2d\tactical_damage.techsetdef`](.\share\raw\techsetdefs_stable\2d\tactical_damage.techsetdef) declares its APE constants at cg01/cg02 and leaves cg00 undeclared — its script-driven "amount" (index 0) is read from `scriptVector0` in the shader. A modder put it as *"scriptVectors are defined inside the shader itself."*

### Index math for `SetFilterPassConstant`

`SetFilterPassConstant(localClientNum, filterIndex, passIndex, constantIndex, value)` where **`constantIndex = scriptVectorN * 4 + component`** (x/y/z/w = 0/1/2/3). So scriptVector0.x = 0, scriptVector1.x = 4, … scriptVector3.x = **12**, scriptVector3.w = 15, up to scriptVector7.x = 28. See [`scripts\postfx\_filters.gsh`](.\share\raw\scripts\postfx\_filters.gsh) (`SCRIPT_VECTOR_0..7`, `SCRIPT_VECTOR_X/Y/Z/W`) and `gfx_shared.csc::getShaderConstantIndex`.

### Other gotchas

- **Filter slot**: the API doc says `filterIndex` must be 0-3, but that's understated — `setfilterpassmaterial`/`setfilterpassenabled` work on higher slots, and slot **7** drives constants fine in a zombies map (Scobalula's raindrops postfx uses `FILTER_ID 7`). Slots 0-5 are taken by overlays/water/EMP/blood/environment; 7 = `FILTER_INDEX_BONUSZM` (free in a custom usermap).
- **Framebuffer must be `resolvedScene`** in the techsetdef technique (`sceneTexture = CodeTexture("resolvedScene")`), not `resolvedPostSun`, for the filter to work in-game.
- **`saturate()` trap**: if the shader does `lerp(1, vig, saturate(baseStrength + dynamic))` and `baseStrength` is already `1.0` in the material, your `dynamic` push does **nothing** (already clamped). Grain added *outside* a saturate shows up; a "boost" clamped by a maxed base won't. Lower the base value in APE to give the dynamic headroom.
- **Recompiling**: editing the `.hlsl`/techsetdef needs a **shader + material recompile**, not just a script relink. A stale shader binary silently ignores newly-added constants.

### Diagnostic tricks

- Blink the whole filter from the CSC loop with `setfilterpassenabled(lcn, id, 0, blink)` — if it flashes, your updater thread runs and the filter is applied (isolates thread/slot from the constant problem).
- Drive **grain** (or any effect added without `saturate`) to a big value in a 1s on/off square wave — an unmissable binary "does the constant arrive" test. A subtle vignette-strength change is easy to misread as "nothing happens".

> Sources: raw install ([`code\hlslcodeconstantbuffers.h`](.\share\raw\shaders_stable\code\hlslcodeconstantbuffers.h), `_filters.gsh/.csc`, `tactical_damage.techsetdef`, `posterization`/`chromatic_aberration_postfx`); t7kb (gscode API, LG-RZ BlackOps3Shaders, Scobalula raindrops, bo3modtools Discord). Discovered debugging the `zm_rainy_d2om` bodycam vignette.

## Troubleshoot

When booting game after a successful linking of the scripts in the tools, and having error: *`Error linking script: "blabla.gsc"`*, usually it means one script file is missing from zone file. It mostly does this because link step does the linkage with zoned files, not files from the folder AFAIK.

If the map includes weapons that are not linked (especially the ones buyable on the walls), the map doesn't run, and crashes instantly with error about zm_weapons or something.
There is also a wallbuy limit around 20 (depends of the guns used on the walls it seems), that makes the map crashes without errors when using PAP.

You fucking can't use animations prefixed with `%` in CSC. If you do, the game doesn't **FUCKING** boot (even if it exists in other scripts, I just don't know why ...), use raw string instead...
Oh and yeah... Trible/Quadruple check the model is clearly set to "animated" :)

`waitrealtime` keyword isn't affected by pausing the game.

`PlaySound(...)` on **GSC** spawns a temp struct behind the scene, which, if spammed a lot in a few frames, can make the game crash with a G_Spawn error, about no more space available to spawn more entities. Always prefer playing sound on CSC side, to avoid this issue.

## Powerups

Enabling logic is at [`_zm_spawner.gsc`](.\share\raw\scripts\zm\_zm_spawner.gsc#L1545). Zombie's actor variable `zombie.no_powerups` can be configured for specific actor. `level.no_powerups` or flag `flag::set("zombie_drop_powerups", 1)` can be set to true for general decision.

## AI

### Basic AI

`level.zombie_spawn` is an array containing all spawn script_struct for zombie actor spawner, filled in `_zm_spawner.gsc` (or `zm_spawner::` namespace) and it is then spawned in `_zm.gsc` through a loop.

`zm_ai_dogs::special_dog_spawn` can spawn dogs whenever whished, and `dog_spawn_func` to override spawn location, but it takes care of ai limit.

### Apothicon Furies

It seems that original script can be overwritten/customized in some places. Examples:

0. `APOTHICAN_FURY_DEBUG` used to have fury every round after round 1 (note: seem to not work if `APOTHICAN_FURY_USE_SPECIAL_FURY_ROUNDS` is 0. Yeah, because if `APOTHICAN_FURY_USE_SPECIAL_FURY_ROUNDS` is false, then `enable_apothicon_fury_rounds()` is skipped, and therefore, no more round tracker is enabled, and therefore, the spawn interception and trigger stops.
1. by specifying `level.apothicon_fury_round_track_override`, we can define when to spawn furies, during custom rounds for example ... By default, by switching `APOTHICAN_FURY_USE_SPECIAL_FURY_ROUNDS` to 1 or 0, we can have dedicated round, like for dogs.
2. by specifying `level.apothicon_fury_spawn_func`, we can overwrite spawn mechanic to spawn furies differently than the default `function apothicon_fury_special_spawn()` that spawns furies randomly around the player. But that's only if line 386 is fixed to be something like this: `e_ai = [[ level.apothicon_fury_spawn_func ]]();`

## Tips

GDT modifications on weapons (and maybe other properties in GDT) can be live tested with `NevisX` tool.

Every script in `share/raw/scripts/zm` can be overwritten by alimenting scripts with the same name by putting it in the `usermaps/zm_ai_test/scripts/zm`.
> Note: if it's coming from folder `share/raw/scripts/shared`, it seems it's also better to overwrite in `usermaps/zm_ai_test/scripts/shared`, so I should respect relative pathing when overwriting script files...

> Note 2: to override certains basic scripts like _zm_ai_dogs.gsc, it needs to be commented with `//` in `zone_source\all\assetlist\zm_patch.csv`, otherwise, previous version is still linked into the map.

> Note 3: to override certains basic resource file like `zm_levelcommon_weapons.csv`, **you don't need to comment anything** in `zone_source\all\assetlist\zm_levelcommon.csv`.

---

`array::thread_all(array, &func);` array being something like players.
> Cool to call a thread func on each element of array instead of looping over it, can also provide parameters during call.

---

`<entity> delete()` to free entity

### Ambient stuff

The `ambient_mod.csv` or **any ambient mod csv file** needs to be configured according to ardivee's script `_ambient_room.cs`.
> [***not true, I've tested it multiple times, sometimes work, sometimes doesn't, but with current config field value needs to be specified***] => There is a specificity regarding the csv file now: never specify column value `EntityContextValue0` for the default ambient sound.

"Reverb" column config doesn't seem to impact gun sound effects, weirdly, but will affect every other sounds I've been testing.
At least the context ringoff_plr does affect gun sound. Important! context "water":"over" needs to specified, if not, no gun sounds.

---

Extracam texture can be used for a mirror if X axis is flipped !

### VS Code searching

CoD mod files extensions: `*.csc,*.gsc,*.gsh,*.szc,*.zpkg,*.zone,*.csv,*.gdt,*.atr,*.map,*.str,*.lua,*.techsetdef`

## Clientfield

**DEBUG CLIENT FIELD WITH: `+set com_clientfieldsdebug 1`**

| Clientfield Type | CSC self          | Free Bits (Starter ZM Map) | Used in Zombies? (Base Game) | General Usage                                                                                                                              |
| :--------------: | :---------------- | -------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
|      world       | level             | 1917                       | Yes                          | A huge pool of bits to manipulate almost any client-side entity. Can also be useful for toggling LUA UI elements.                          |
|      actor       | AI                | 59                         | Yes                          | Used widely to play CSC FX and sounds on a basic Zombie AI.                                                                                |
|     vehicle      | vehicle entity    | 76                         | Sometimes                    | Some AI such as GK drones and SOE wasps use this asset type, along with the Origins tank. Useful to play CSC FX and sounds.                |
|    allplayers    | player            | 107                        | Yes                          | Gets called on EVERY player. A lot of times this is used to play 3rd-person FX on a player while filtering them from seeing it themselves. |
|     toplayer     | player            | 79                         | Yes                          | Gets called on A SINGLE player. Can be used to show FX to a specific player(s).                                                            |
|   playercorpse   | dead player body  | 112                        | No                           | Generally used for playing FX on a player's dead body in Multiplayer.                                                                      |
|  clientuimodel   | N/A               | 79                         | Yes                          | Used to directly interface with a client's LUA UI Model. No CSC functions are needed, but still needs to be registered in CSC.             |
|   scriptmover    | basic entity      | 84                         | Yes                          | Can be used to play client-side FX on a server-side entity. This is especially used if the entity is moving.                               |
|    helicopter    | helicopter entity | 36                         | No                           | Used in BO3 for handling FX and sounds for helicopters and drones.                                                                         |
|      plane       | plane entity      | 63                         | No                           | Used for Plane assets which are not used much in BO3.                                                                                      |
|     missile      | missile entity    | 56                         | Sometimes                    | Can help play FX or sounds on a missile coming from things like a launcher, bow, or AI weapon.                                             |
|     zbarrier     | zbarrier entity   | 44                         | Yes                          | Used to handle FX and sounds for zbarrier assets such as Pack-A-Punch, GobbleGum machines, and zombie barricades.                          |
|       item       | item entity       | 64                         | No                           | Rarely used for specific scenarios in the Campaign.                                                                                        |

## Text colors

| Code | Color     |
| ---- | --------- |
| ^0   | Black     |
| ^1   | Red       |
| ^2   | Green     |
| ^3   | Yellow    |
| ^4   | Blue      |
| ^5   | Cyan      |
| ^6   | Pink      |
| ^7   | White     |
| ^8   | Grey      |
| ^9   | Light red |

# Sphynx commands cheat sheet

If Sphynx scripts utilities were installed on a map scripts, here is a recap of the commands possible to be used.

> usage: `/command parameter`

| Command             | Possible parameters                   | Description                                                                 |
| ------------------- | ------------------------------------- | --------------------------------------------------------------------------- |
| `/getxuid`          | `1`                                   | Displays your XUID                                                          |
| `/spawning`         | `on`/`off`                            |                                                                             |
| `/spawn_dog`        | `<amount>`                            |                                                                             |
| `/spawn_zombie`     | `<amount>`                            | Spawn zombies and adds them to the zombies spawn list                       |
| `/perk`             | `<player_index>`/`all`                | Give perks to players                                                       |
| `/take_perk`        | `<player_index>`/`all`                | Take perks from players                                                     |
| `/points`           | `[<player_index>]` `<points>`         | Give points to player,/to self if not specified                             |
| `/give`             | `[<player_index>]` `<weaponname>`     | Better /give                                                                |
| `/ignore`           | `<player_index>`/`all`                | Make player ignored by AI                                                   |
| `/infinite_ammo`    | `<player_index>`/`all`                | Give player infinite ammo (no way of turning off now)                       |
| `/god`              | `<player_index>`/`all`                | Better godmode                                                              |
| `/camo`             | `[<player_index>]`/`<index>`          | Change camo of currentweapon                                                |
| `/revive`           | `<player_index>`/`all`                |                                                                             |
| `/power`            | `on`/`off`                            | Toggle power state                                                          |
| `/next_round`       | `<increment>`                         |                                                                             |
| `/previous_round`   | `<decrement>`                         |                                                                             |
| `/round`            | `<round_number>`                      | between 1 and 255                                                           |
| `/powerup`          | `<player_index>` `<powerup name>`     | Spawns powerup where player is looking                                      |
| `/upgrade_weapon`   | `<player_index>`/`all`                | Upgrades current weapon                                                     |
| `/downgrade_weapon` | `<player_index>`/`all`                | Downgrades current weapon                                                   |
| `/open`             | `all`                                 | Opens all doors                                                             |
| `/difficulty`       | `<difficulty>`                        | From 1 to 4. Changes difficulty (Zombie speed, amount of zombies)           |
| `/lighting`         | `<lightstate>`                        | From 0 to 3. Changes the lightingstate                                      |
| `/fog`              | `<fogstate>`                          | From 0 to 3. Changes the fog state                                          |
| `/get_coords`       | `1`                                   | Gets the coordinates on your exact location (Origin and Angles)             |
| `/outline`          | `<struct/model targetname>` `<state>` | State is 0 or 1. Add keylines around a specific model to look for it easier |
| `/show_zombies`     | `<state>`                             | State is 0 or 1. Shows all zombies through walls - 'Gives Death Perception' |
| `/teleportz`        | `<player_index>`                      | Teleports zombies to player with index                                      |
| `/bgb`              | `<bgbname>` `<player_index>`          | Gives the player a gobblegum                                                |
| `/aimbot`           | `on`/`off`                            | Aimbots zombies                                                             |
