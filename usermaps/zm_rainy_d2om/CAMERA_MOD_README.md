# Bodycam camera mod — `zm_rainy_d2om`

Our own take on the KILLFEED / UNRECORD "bodycam" look, built as **one custom
fullscreen post‑process filter** (`cam_bodycam`) that stacks:

1. **Fisheye** — radial UV warp (barrel distortion), same math as the shipping `postfx/fisheye.hlsl`
2. **Chromatic aberration** — per‑channel split that ramps up toward the frame edges
3. **Vignette** — radial darkening toward the edges
4. **Film grain** — animated per‑pixel hash noise

…plus a subtle **handheld micro‑shake** on the client. Everything runs
**client‑side** and is toggleable live with dvars.

> ⚠️ **I wrote every source file, but I could not compile the shader, link the
> map, or test it in‑game from here.** Those steps are below and are yours to
> run. The shader is deliberately built on the exact scaffolding of the stock
> `fisheye.hlsl` (which compiles) to keep the risk low, but treat the first
> Linker build as the real test.

---

## Files added / changed

**New — shader + techset (added alongside the stock postfx, same folders):**
```
share/raw/shaders_stable/postfx/cam_bodycam.hlsl
share/raw/shaders_stable_toolsgfx/postfx/cam_bodycam.hlsl          (identical twin, for APE preview)
share/raw/techsetdefs_stable/postfx/cam_bodycam.techsetdef
share/raw/techsetdefs_stable_toolsgfx/postfx/cam_bodycam.techsetdef (identical twin)
```

**New — material + postfx bundle (cloned from the stock fisheye assets):**
```
source_data/_cam_bodycam.gdt
    filter_cam_bodycam   ( material.gdf     )   materialType = "cam_bodycam"
    cam_bodycam          ( postfxbundle.gdf )   looping, 1 stage -> filter_cam_bodycam
```

**Edited — the map itself:**
```
usermaps/zm_rainy_d2om/zone_source/zm_rainy_d2om.zone       (+ material + scriptbundle deps)
usermaps/zm_rainy_d2om/scripts/zm/zm_rainy_d2om.csc         (+ postfx enable / dvar toggle, client-side)
usermaps/zm_rainy_d2om/scripts/zm/zm_rainy_d2om.gsc         (+ handheld shake, server-side)
```

Nothing stock was modified in place — the shader/techset are **new files next
to** the community postfx set already in those folders.

---

## How it fits together (the pipeline)

```
cam_bodycam.hlsl  ──(source =)──►  cam_bodycam.techsetdef  ──(materialType)──►  filter_cam_bodycam
                                   (sceneTexture = resolvedScene)                        │
                                                                                         ▼
CSC: postfx::playpostfxbundle("cam_bodycam")  ◄──(scriptbundle)──  cam_bodycam (postfxbundle)
```

- The techset binds the full frame to the code texture **`resolvedScene`** — the
  one framebuffer that works for postfx filters — and maps the eight look
  parameters to material registers `cg00.*` / `cg01.*`.
- The bundle is **looping / 1 stage**, so it just runs continuously with the
  material's constants (no keyframe animation).
- `zm_rainy_d2om.csc` registers `callback::on_localplayer_spawned` and threads
  `postfx::playpostfxbundle("cam_bodycam")` for each local player.

---

## Build it (in the mod tools)

1. **APE** — open it; it reads `source_data/_cam_bodycam.gdt`. Confirm both
   assets exist: material **`filter_cam_bodycam`** and postfxbundle
   **`cam_bodycam`**. (You'll see a **"Bodycam"** category of sliders on the
   material — that's the techset tweak UI.)
2. **Build the map** — Launcher → **Linker** → select `zm_rainy_d2om` →
   build the mod / fast file. The material pulls the `cam_bodycam` techset,
   which compiles `cam_bodycam.hlsl` as part of the build. Watch the linker log
   and make sure the material/techset/shader resolve with no errors.
   - If your setup compiles shaders as a separate step, run that first so the
     `cam_bodycam` techset exists before the Linker asks for it.
3. **Run** the map. The look should be on immediately (dvars default to `1`).

If anything misbehaves, set `dev 2` and `logfile 1` in the Launcher dvars,
reproduce, and read the exact message (separate *compile* vs *linker /
unresolved external* vs *runtime* — see the notes below).

---

## Test / toggle (dvars)

| Dvar | Default | Meaning |
|------|---------|---------|
| `cam_bodycam` | `1` | Master on/off for the whole filter |
| `cam_bodycam_shake` | `1` | Handheld micro‑shake on/off |

Bind a key from the console to flip it live:
```
bind h "toggle cam_bodycam 0 1"
bind j "toggle cam_bodycam_shake 0 1"
```

**Recommended in‑game settings for the look** (from the reference mod): motion
blur **off**, FOV **~120**, high graphics. Want the raw‑footage HUD‑off look?
`cg_draw2d 0` hides the 2D HUD while leaving the filter running (kept out of
script on purpose — LUI HUD hiding is fiddly and I couldn't test it).

---

## Tune the look

Two ways — either edit the sliders on `filter_cam_bodycam` in **APE** (the
**Bodycam** category) and rebuild, or edit the constants directly in
`source_data/_cam_bodycam.gdt`. The mapping:

| Effect | Material key | Shader param | Default | Try |
|--------|--------------|--------------|---------|-----|
| Fisheye reach | `cg00_x` | `fisheyeRadius` | `1.3` | 0.8–2.0 |
| Fisheye falloff | `cg00_y` | `fisheyeDensity` | `1.2` | 0.5–2.5 |
| Fisheye strength | `cg00_z` | `fisheyeIntensity` | `0.22` | 0.1 subtle → 0.5 strong |
| Vignette strength | `cg00_w` | `vignetteStrength` | `0.5` | 0 off → 1 heavy |
| Vignette start | `cg01_x` | `vignetteRadius` | `0.95` | smaller = darker sooner |
| Vignette softness | `cg01_y` | `vignetteDensity` | `1.4` | 0.5–3.0 |
| Chromatic aberration | `cg01_z` | `chromaticStrength` | `0.0035` | 0.001 subtle → 0.01 heavy |
| Film grain | `cg01_w` | `grainStrength` | `0.06` | 0.02 subtle → 0.15 gritty |

Handheld shake feel: the `Earthquake( 0.09, 0.9, self.origin, 128 )` call in
`zm_rainy_d2om.gsc` — raise `0.09` for shakier, lower for steadier, or set
`cam_bodycam_shake 0`.

---

## If something breaks

- **Linker: unresolved external / missing `filter_cam_bodycam`** → the GDT
  wasn't converted (open it in APE) or the zone lines are missing. Confirm the
  two `.zone` lines: `material,filter_cam_bodycam` and `scriptbundle,cam_bodycam`.
- **Shader won't compile** → open `cam_bodycam.hlsl`; it mirrors the stock
  `fisheye.hlsl` (same includes / helpers). Compare against
  `share/raw/shaders_stable/postfx/fisheye.hlsl` if the compiler flags a helper.
- **Screen looks wrong / washed** → the techset must bind
  `sceneTexture = CodeTexture("resolvedScene")` (it does). If you retarget it to
  `resolvedPostSun` it will misbehave — keep it on `resolvedScene`.
- **Compiler chokes on `RandomFloatRange` in the .gsc** (unlikely — it's a stock
  builtin) → replace line with `wait( 0.85 );`.

---

## Fallback (no custom shader) — "Strategy B"

If the custom shader ever fights you, the fisheye alone can run with **zero**
custom‑shader compilation by reusing BO3's already‑compiled fisheye:

- In the `.zone`, swap our lines for `scriptbundle,postfx_fisheye` +
  `material,filter_postfx_fisheye` (both stock, in `postfx_templates.gdt`).
- In the `.csc`, call `postfx::playpostfxbundle( "postfx_fisheye" )`.
- Do the vignette + grain as full‑screen 2D overlay images instead of shader math.

You lose the single‑pass combined look, but it's the lowest‑risk path to a
working fisheye. Our `cam_bodycam` route is the "our own" version and the one I'd
push on first.

---

## Provenance

The mechanism (custom postfx → techset on `resolvedScene` → material →
`postfxbundle` → `postfx::playpostfxbundle`) is verified against your raw
install and the decompiled `postfx_shared.csc`. The reference for custom BO3
postfx shaders is **LG‑RZ/BlackOps3Shaders** (LG = the "LG" credited on the
KILLFEED workshop page). The stock `fisheye.hlsl` / `fisheye.techsetdef` /
`filter_postfx_fisheye` / `postfx_fisheye` in this install were the templates.
