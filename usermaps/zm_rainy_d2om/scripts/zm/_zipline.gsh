// Tunables for the zipline traversal (feature: _zipline.gsc).

// Debug: flip to 1 to print chain-resolution failures. No commas inside __str — use +.
#define DEBUG_ZIPLINE           0
#define PRINT_ZIPLINE_DEBUG(__str) if(DEBUG_ZIPLINE) IPrintLnBold(__str)

// Radiant contract: each zipline is a chain — a trigger_use with this targetname,
// its .target a start script_struct, that struct's .target the end script_struct.
#define ZIPLINE_TRIGGER_TARGETNAME  "zipline"

// Hint prompt on the trigger. Ref = <str filename>_<REFERENCE>: zipline.str + USE.
// String lives in share/raw/<lang>/localizedstrings/zipline.str (zone: localize,zipline).
#define ZIPLINE_HINT_LOCALIZED      "ZIPLINE_USE"

// Custom cursorhint icon: image asset "zipline_hint" (image,zipline_hint), drawn by
// the overridden cursorhint_image LUI widget (cursorhint_image_zipline.lua) whenever
// this trigger's HINT_ACTIVATE cursorhint shows. No GSC state needed.

// Shipped campaign scene bundles (extracted to zipline_scenes.gdt).
#define ZIPLINE_SCENE_ATTACH    "cin_gen_traversal_zipline_player_attach"
#define ZIPLINE_SCENE_IDLE      "cin_gen_traversal_zipline_player_idle"
#define ZIPLINE_SCENE_DISMOUNT  "cin_gen_traversal_zipline_player_dismount"

// Trolley the player grips, linked to this hand tag.
#define ZIPLINE_TROLLEY_MODEL   "wpn_t7_zipline_trolley_prop"
#define ZIPLINE_TROLLEY_TAG     "tag_weapon_left"

// Sound aliases (share/raw/sound/aliases/zipline.csv); detach reuses the board set.
#define ZIPLINE_SND_BOARD       "zip_attach"
#define ZIPLINE_SND_MOVE        "zip_move"
#define ZIPLINE_SND_DETACH      "zip_detach"

// Sparks FX, played server-side on a model linked to the trolley (zone: fx,PATH).
// FWD/LEFT/UP offset it off the trolley tag; PITCH/YAW/ROLL aim the emission.
#define ZIPLINE_FX_KEY          "zipline_sparks"
#define ZIPLINE_FX_PATH         "electric/fx_sparks_zipline"
#define ZIPLINE_FX_FWD          0
#define ZIPLINE_FX_LEFT         0
#define ZIPLINE_FX_UP           3
#define ZIPLINE_FX_PITCH        310
#define ZIPLINE_FX_YAW          0
#define ZIPLINE_FX_ROLL         0

// Glide speed (world units/second) and the slide step (one server frame).
#define ZIPLINE_SPEED_UPS       300
#define ZIPLINE_TICK            0.05

// Units the player hangs below the start struct during the attach grab, before the
// slide takes over. Set near the grip's vertical offset so there's no pop at launch.
#define ZIPLINE_HANG_OFFSET     88

// Fire the dismount this far (units) before the end struct, not at the tip.
#define ZIPLINE_DISMOUNT_LEAD   70

// Landing: carry DIST forward off the cable, trace to ground, MoveTo onto it over
// TIME. GROUND_OFFSET nudges the final Z (raise if feet clip/sink).
#define ZIPLINE_LAND_DIST           90
#define ZIPLINE_LAND_TIME           0.9
#define ZIPLINE_LAND_TRACE_UP       40
#define ZIPLINE_LAND_TRACE_DOWN     400
#define ZIPLINE_LAND_GROUND_OFFSET  0

// Slide start = the attach anim's grab (its zipline_attached note, frame 30 @ 30fps).
#define ZIPLINE_GRAB_TIME       1.0

// Ride phase: CF_TP (toplayer) = rider's camera/footsteps; CF_SND (allplayers) =
// ride sounds for every client.
#define ZIPLINE_CF_TP           "zipline_thirdperson"
#define ZIPLINE_CF_TP_BITS      2
#define ZIPLINE_CF_SND          "zipline_sound"
#define ZIPLINE_CF_SND_BITS     2
#define ZIPLINE_TP_OFF          0
#define ZIPLINE_TP_BOARD        1
#define ZIPLINE_TP_GLIDE        2
#define ZIPLINE_TP_LAND         3

// cg_thirdPersonRange per phase (smaller = closer); LERP smooths the ramp.
#define ZIPLINE_TP_RANGE_CLOSE  70
#define ZIPLINE_TP_RANGE_FAR    150
#define ZIPLINE_TP_LERP         0.35

// Range the ramp starts/ends at — near first-person, so entering/leaving third
// person pulls the camera out and back in over FADE seconds in STEPS increments
// instead of snapping.
#define ZIPLINE_TP_RANGE_START  8
#define ZIPLINE_TP_STEPS        32
#define ZIPLINE_TP_FADE         1.0
// Slower pull-out on board so the first-person -> third jump eases in gently.
#define ZIPLINE_TP_ENTER_FADE   3.0
