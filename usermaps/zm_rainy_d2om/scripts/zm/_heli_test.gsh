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
#define FLYBY_YAW_SMOOTH    0.35   // nose eases toward the path each piece (1 = snap/old; lower = softer turns, cuts corners)
// Arrival brake/flare: over the last (1 - FLYBY_LEVEL_FRAC) of the path the heli decelerates, the
// nose flares up (brake), then settles level for the handoff.
#define FLYBY_LEVEL_FRAC    0.80   // path fraction after which the braking/flare tail begins
#define FLYBY_PITCH_BRAKE   12.0   // nose-up flare angle at the peak of the brake
#define FLYBY_FLARE_PEAK    0.5    // split of the brake time between nose-up and settle (0..1)
#define FLYBY_FLARE_EASE    0.4    // ease-in/out fraction on the flare rotations (0..0.5); higher = softer
#define HELI_YAW_OFFSET     0      // free-heli nose = its own angles.yaw; add 180 if it flies backward, +/-90 if sideways

// First-person ride: the player's view links to the heli's ride tag (clamped free-look). The player
// body (player_huey_pilot1_idle_loop1, head hidden) rides the same tag so the player sees it.
#define HELI_RIDE_TAG       "tag_passenger"   // heli tag the rider bodies sit on
#define HELI_VIEW_TAG       "tag_passenger"   // heli tag the view mount links to (cockpit; tag_origin sits up at the rotor)
#define HELI_VIEW_OFFSET    (8, -5, -5)   // view offset from the ride tag, local (fwd, left, up): 8 fwd, 5 right, 5 down
#define HELI_VIEW_ANGLES    (0, 0, 0)     // view orientation trim vs the ride tag (pitch, yaw, roll); (0,0,0) = straight
#define FLYBY_LOOK_RIGHT    65     // free-look clamp (deg) from the ride facing; narrow = locked
#define FLYBY_LOOK_LEFT     65
#define FLYBY_LOOK_UP       45
#define FLYBY_LOOK_DOWN     45
// Over the brake, ease the free-look clamps back to 0 so the view recenters on the ride facing and
// the scene cut lands on-axis (no snap if the player was looking away). 0 = keep free-look to the end.
#define FLYBY_RECENTER      1
#define FLYBY_RECENTER_EASE 0.3    // accel/decel fraction of the recenter lerp (0..0.5)

// Rider bodies visible during the ride (pilot + the player's own body), linked to heli tags and
// playing an idle so they ride along animated. animation::play links to the tag + animates.
#define HELI_PILOT_MODEL    "c_zom_der_dempsey_mpc_fb"    // pilot on tag_driver
#define HELI_RIDER_MODEL    "c_zom_der_nikolai_mpc_fb"    // the player's own body on the ride tag
#define HELI_PILOT_IDLE     "ai_huey_pilot1_idle_loop1"       // pilot idle (same anim cin_pilot uses)
#define HELI_PLAYER_IDLE    "player_huey_pilot1_idle_loop1"   // player-body idle (head hidden)

// Frames the flight visuals (heli + FX + riders) persist while the scene spins up, so there's no
// gap; the two overlap statically at the same pose for these frames.
#define HELI_HANDOFF_FRAMES 3
// The crash anim's frame-0 root sits slightly behind the anchor; nudge the crash anchor forward
// (units, along the arrival facing) so the crash heli lands on the flown heli's end pose (no recoil).
#define HELI_ARRIVE_FWD     0
