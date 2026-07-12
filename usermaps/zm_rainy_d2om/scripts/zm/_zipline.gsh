// Tunables for the zipline traversal (feature: _zipline.gsc).

// No commas inside __str — use +.
#define DEBUG_ZIPLINE           0
#define PRINT_ZIPLINE_DEBUG(__str) if(DEBUG_ZIPLINE) IPrintLnBold(__str)

// Radiant chain: trigger_use(targetname) -> start struct(.target) -> end struct(.target).
#define ZIPLINE_TRIGGER_TARGETNAME  "zipline"

// String in share/raw/<lang>/localizedstrings/zipline.str (zone: localize,zipline).
#define ZIPLINE_HINT_LOCALIZED      "ZIPLINE_USE"

// Only HINT_ACTIVATE routes through ZMCursorHint (where the widget swaps the icon).
#define ZIPLINE_HINT_ENUM       "HINT_ACTIVATE"

// Scene bundles (zipline_scenes.gdt); object1 is Prop so the clone can bind.
#define ZIPLINE_SCENE_ATTACH    "cin_gen_traversal_zipline_player_attach"
#define ZIPLINE_SCENE_IDLE      "cin_gen_traversal_zipline_player_idle"
#define ZIPLINE_SCENE_DISMOUNT  "cin_gen_traversal_zipline_player_dismount"

#define ZIPLINE_TROLLEY_MODEL   "wpn_t7_zipline_trolley_prop"
#define ZIPLINE_TROLLEY_TAG     "tag_weapon_left"

// Trolley link angle offset, to seat the pulley on the cable.
#define ZIPLINE_TROLLEY_PITCH   0
#define ZIPLINE_TROLLEY_YAW     0
#define ZIPLINE_TROLLEY_ROLL    15

// Sound aliases (share/raw/sound/aliases/zipline.csv).
#define ZIPLINE_SND_BOARD       "zip_attach"
#define ZIPLINE_SND_MOVE        "zip_move"
#define ZIPLINE_SND_DETACH      "zip_detach"

// Rumble presets (share/raw/rumble/*.rmb, base name w/o _h/_l; zone: rumble,NAME).
#define ZIPLINE_RMB_START       "slide_start"
#define ZIPLINE_RMB_LOOP        "slide_loop"
#define ZIPLINE_RMB_END         "slide_end"

// Sparks FX on a model linked to the trolley; FWD/LEFT/UP offset, PITCH/YAW/ROLL aim.
#define ZIPLINE_FX_KEY          "zipline_sparks"
#define ZIPLINE_FX_PATH         "electric/fx_sparks_zipline"
#define ZIPLINE_FX_FWD          3
#define ZIPLINE_FX_LEFT         0
#define ZIPLINE_FX_UP           4
#define ZIPLINE_FX_PITCH        320
#define ZIPLINE_FX_YAW          0
#define ZIPLINE_FX_ROLL         40

// Glide speed (units/s) and travel step (one server frame).
#define ZIPLINE_SPEED_UPS       300
#define ZIPLINE_TICK            0.05

// Units the rig hangs below the struct at attach.
#define ZIPLINE_HANG_OFFSET     88

// Drops the pulley below the struct line so it sits on the cable. Raise to lower it.
#define ZIPLINE_GRIP_DROP       3

// Fire the dismount this far (units) before the end struct.
#define ZIPLINE_DISMOUNT_LEAD   70

// Landing: carry DIST forward, trace to ground, MoveTo over TIME; GROUND_OFFSET tunes Z.
#define ZIPLINE_LAND_DIST           90
#define ZIPLINE_LAND_TIME           0.9
#define ZIPLINE_LAND_TRACE_UP       40
#define ZIPLINE_LAND_TRACE_DOWN     400
#define ZIPLINE_LAND_GROUND_OFFSET  0

// Slide start = the attach anim's grab note (frame 30 @ 30fps).
#define ZIPLINE_GRAB_TIME       1.0

// Ride phase clientfields: CF_TP (toplayer) camera; CF_SND (allplayers) sounds.
#define ZIPLINE_CF_TP           "zipline_thirdperson"
#define ZIPLINE_CF_TP_BITS      2
#define ZIPLINE_CF_SND          "zipline_sound"
#define ZIPLINE_CF_SND_BITS     2
#define ZIPLINE_TP_OFF          0
#define ZIPLINE_TP_BOARD        1
#define ZIPLINE_TP_GLIDE        2
#define ZIPLINE_TP_LAND         3

// Radial speed blur over the glide (CSC EnableSpeedBlur); IN/OUT ramp times in ms.
#define ZIPLINE_BLUR_AMOUNT     0.3
#define ZIPLINE_BLUR_INNER      0.2
#define ZIPLINE_BLUR_OUTER      1.0
#define ZIPLINE_BLUR_IN         1500
#define ZIPLINE_BLUR_OUT        400

// cg_thirdPersonRange per phase (smaller = closer); LERP smooths the ramp.
#define ZIPLINE_TP_RANGE_CLOSE  70
#define ZIPLINE_TP_RANGE_FAR    150
#define ZIPLINE_TP_LERP         0.5

// START = near first-person; the ramp pulls out/in over FADE in STEPS steps.
#define ZIPLINE_TP_RANGE_START  8
#define ZIPLINE_TP_STEPS        32
#define ZIPLINE_TP_FADE         1.0
// Slower pull-out on board.
#define ZIPLINE_TP_ENTER_FADE   3.0
