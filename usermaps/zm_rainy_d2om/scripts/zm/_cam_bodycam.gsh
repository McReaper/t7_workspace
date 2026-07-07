// ============================================================================
//  _cam_bodycam.gsh — compile-time config for the bodycam camera mod.
//  #insert'ed by _cam_bodycam.csc (client) and _cam_bodycam.gsc (server).
// ============================================================================

// Master on/off for the look.
#define CAM_BODYCAM_ENABLED         1

// Filter material + slot (applied via the filter:: API, see _cam_bodycam.csc).
#define CAM_BODYCAM_MATERIAL        "filter_cam_bodycam"
// Filter slot. Slot 7 is proven to accept SetFilterPassConstant in a zombies
// usermap (Scobalula's raindrops postfx) and is free in this map; lower slots are
// used by overlays/damage/blood. (Note: the earlier "constants don't reach"
// symptom was NOT the slot -- it was the shader reading material <cgNN> constants
// instead of scriptVector3; see _cam_bodycam.hlsl. Slot 6 would likely work too.)
#define CAM_BODYCAM_FILTER_ID       7

// --- Script-driven shader constants (register cg03), added on top of the
//     APE-tuned base. index = register*4 + component -> cg03 starts at 12. ---
#define CAM_BODYCAM_CI_VIGNETTE     12   // cg03.x - extra vignette strength
#define CAM_BODYCAM_CI_GRAIN        13   // cg03.y - extra grain strength
#define CAM_BODYCAM_CI_VIG_OFF_X    14   // cg03.z - vignette centre offset X
#define CAM_BODYCAM_CI_VIG_OFF_Y    15   // cg03.w - vignette centre offset Y

// --- Server -> client clientfields that drive the dynamics ---
#define CAM_BODYCAM_CF_MOVE         "cam_bodycam_move"     // movement level 0..15
#define CAM_BODYCAM_CF_MOVE_BITS    4
#define CAM_BODYCAM_CF_MOVE_MAX     15
#define CAM_BODYCAM_CF_GLITCH       "cam_bodycam_glitch"   // event glitch 0..7
#define CAM_BODYCAM_CF_GLITCH_BITS  3
#define CAM_BODYCAM_CF_GLITCH_MAX   7

// --- Tuning ---
#define CAM_BODYCAM_MOVE_REFSPEED   180.0  // speed (u/s) counted as "full" movement
#define CAM_BODYCAM_MOVE_VIGNETTE   0.25   // extra vignette strength at full movement
#define CAM_BODYCAM_GLITCH_GRAIN    0.5    // extra grain at full glitch
#define CAM_BODYCAM_SMOOTH          0.15   // per-frame lerp toward target (0..1)

// --- Camera sway (client-side handheld / bodycam feel). The vignette centre
//     lags behind view rotation, then eases back to centre. Subtle is realistic. ---
#define CAM_BODYCAM_SWAY_GAIN       0.008  // view deg turned/frame -> centre offset
#define CAM_BODYCAM_SWAY_MAX        0.06   // clamp on the centre offset (keep small)
#define CAM_BODYCAM_SWAY_RESPONSE   0.12   // per-frame follow toward target (lower = laggier)

// --- Walk bob (physical movement). Speed-scaled figure-8 wobble (side-to-side
//     plus vertical at double frequency), ramped in/out. Uses MOVE_REFSPEED. ---
#define CAM_BODYCAM_BOB_PERIOD      700    // ms per lateral bob cycle (lower = faster steps)
#define CAM_BODYCAM_BOB_AMP         0.02   // max bob centre offset at full speed
#define CAM_BODYCAM_BOB_SMOOTH      0.08   // per-frame lerp of bob amplitude (ramp in/out)
