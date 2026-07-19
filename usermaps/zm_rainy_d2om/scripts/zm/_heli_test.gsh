// Shared heli_fx clientfield states — GSC sets them, CSC reacts, so they must match.
#define HELI_FX_FLYING      1   // rotor blur
#define HELI_FX_CRASHING    2   // + fire trail on tag_deathfx
#define HELI_FX_IMPACT      3   // first impact (heli_impact @550): trail off + explosion
#define HELI_FX_EXPLODE     4   // second explosion (heli_explo @608): rotor blur off + explosion

// Flyby (heli arrival) — straight MoveTo from the spawn to the crash point (the crash scene
// then takes over). No baked fly-in anim exists (BO1 did it with a vehicle path), so the lean
// and straighten are scripted with RotateTo.
#define FLYBY_SPEED_UPS     500    // fly-in speed (units/sec); duration derived from distance
#define FLYBY_PITCH_FWD     7.0    // nose-down forward lean while cruising, leveled out at the end
#define FLYBY_LEVEL_TIME    1.5    // seconds to ease into the lean at the start / out of it at the end
#define HELI_YAW_OFFSET     90     // huey model nose is 90 deg off +X; rotate heading to match (try -90 if reversed)
// Chase camera: players PlayerLinkToDelta'd to a cam ent MoveTo'd in parallel with the heli, sat
// behind + above it and angled at it, with clamped free-look. (A link, not CameraSetPosition, so the
// player can look around; a MoveTo'd ent, not a heli-tag link, so it stays smooth.)
#define FLYBY_CHASE_DIST    380    // how far behind the heli the chase cam sits
#define FLYBY_CHASE_HEIGHT  90     // how far above the heli origin the chase cam sits
#define FLYBY_LOOK_RIGHT    45     // free-look clamp (deg) from the heli-facing center; narrow = locked
#define FLYBY_LOOK_LEFT     45
#define FLYBY_LOOK_UP       30
#define FLYBY_LOOK_DOWN     30
#define FLYBY_ZOOM_OFFSET   90     // how close behind the heli the cam pushes in during the fade-out

// Black-fade handoff (fly-in -> first-person rappel scene). Fade out + zoom, then start the scene
// only once fully black (holding a server frame), then fade back in.
#define FADE_OUT_TIME       0.5    // seconds to fade the screen to black (also the zoom-in duration)
#define FADE_HOLD           0.6    // extra black hold after the scene starts, so it visibly settles
#define FADE_IN_TIME        0.5    // seconds to fade back in on the first-person rappel
