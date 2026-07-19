// Shared heli_fx clientfield states — GSC sets them, CSC reacts, so they must match.
#define HELI_FX_FLYING      1   // rotor blur
#define HELI_FX_CRASHING    2   // + fire trail on tag_deathfx
#define HELI_FX_IMPACT      3   // first impact (heli_impact @550): trail off + explosion
#define HELI_FX_EXPLODE     4   // second explosion (heli_explo @608): rotor blur off + explosion

// Flyby (heli arrival) — Catmull-Rom curve through the heli_intro_spawn target chain, sampled into
// short linear MoveTo pieces (smooth), with the model banking into its turns. No baked fly-in anim
// exists (BO1 did it with a vehicle path).
#define FLYBY_SPEED_UPS     500    // fly-in speed (units/sec); piece durations derived from length
#define FLYBY_SEG_LEN       120    // spline sample step (units per MoveTo piece); smaller = smoother
#define FLYBY_PITCH_FWD     15.0   // nose-down forward lean while cruising
#define FLYBY_BANK_PER_DEG  1.5    // model roll (deg) per deg of per-piece yaw change (flip sign if reversed)
#define FLYBY_BANK_MAX      35     // max model roll (deg)
// Arrival brake/flare: over the last (1 - FLYBY_LEVEL_FRAC) of the path the heli decelerates, the
// nose flares up (brake), then settles level for the handoff.
#define FLYBY_LEVEL_FRAC    0.80   // path fraction after which the braking/flare tail begins
#define FLYBY_PITCH_BRAKE   12.0   // nose-up flare angle at the peak of the brake
#define FLYBY_FLARE_PEAK    0.5    // split of the brake time between nose-up and settle (0..1)
#define FLYBY_FLARE_EASE    0.4    // ease-in/out fraction on the flare rotations (0..0.5); higher = softer
#define HELI_YAW_OFFSET     0      // free-heli nose = its own angles.yaw; add 180 if it flies backward, +/-90 if sideways
// Chase camera: players PlayerLinkToDelta'd to a cam ent MoveTo'd in parallel with the heli, sat
// behind + above it and angled at it, with clamped free-look. (A link, not CameraSetPosition, so the
// player can look around; a MoveTo'd ent, not a heli-tag link, so it stays smooth.)
#define FLYBY_CHASE_DIST    450    // how far behind the heli the chase cam sits
#define FLYBY_CHASE_HEIGHT  350     // how far above the heli origin the chase cam sits
#define FLYBY_LOOK_RIGHT    35     // free-look clamp (deg) from the heli-facing center; narrow = locked
#define FLYBY_LOOK_LEFT     35
#define FLYBY_LOOK_UP       -60     // this arc governs the downward range here — cam sits above the heli
#define FLYBY_LOOK_DOWN     20
#define FLYBY_ZOOM_OFFSET   90     // how close behind the heli the cam pushes in during the fade-out

// Black-fade handoff (fly-in -> first-person rappel scene). Fade out + zoom, then start the scene
// only once fully black (holding a server frame), then fade back in.
// Own LUI menu id so our fades don't collide with the scene's IGC fade on the default black menu
// (scene_shared.csc postfx_igc_zombies does an instant screen_fade_out(0) that would hard-cut ours).
#define FADE_MENU_ID        "heli_intro"
#define FLYBY_ZOOM_TIME     2.2    // seconds for the exterior->scene push-in; starts before the fade
#define FADE_OUT_TIME       1.1    // seconds to fade the screen to black (last part of the zoom)
#define FADE_HOLD           0.6    // black hold over the handoff before clearing (hides the flip/spin-up)
