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

// First-person ride: players PlayerLinkToDelta'd directly to a heli tag, with clamped free-look.
#define HELI_RIDE_TAG       "tag_passenger"   // heli tag the player rides on (first person)
#define FLYBY_LOOK_RIGHT    45     // free-look clamp (deg) from the ride facing; narrow = locked
#define FLYBY_LOOK_LEFT     45
#define FLYBY_LOOK_UP       45
#define FLYBY_LOOK_DOWN     45

// Rider bodies visible during the ride (pilot + the player's own body), linked to heli tags and
// playing the driver idle so they ride along animated. animation::play links to the tag + animates.
#define HELI_PILOT_MODEL    "c_zom_der_dempsey_mpc_fb"    // pilot on tag_driver
#define HELI_RIDER_MODEL    "c_zom_der_nikolai_mpc_fb"    // the player's own body on the ride tag
#define HELI_RIDE_IDLE      "ai_huey_pilot1_idle_loop1"   // driver idle (same anim cin_pilot uses)

// Frames the flight visuals (heli + FX + riders) persist while the scene spins up, so there's no
// gap; the two overlap statically at the same pose for these frames.
#define HELI_HANDOFF_FRAMES 3
