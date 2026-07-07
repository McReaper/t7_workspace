// ============================================================================
//  _cam_bodycam.gsh — compile-time config for the bodycam camera mod.
//  #insert'ed by _cam_bodycam.csc. Tune here, then rebuild. No dvars.
// ============================================================================

// Master on/off for the look.
#define CAM_BODYCAM_ENABLED         1

// Filter material, applied directly via the filter:: API (like the stock
// rain-drops / binoculars postfx) rather than a postfxbundle.
#define CAM_BODYCAM_MATERIAL        "filter_cam_bodycam"

// Filter slot to render into. Slots 0-5 and 7 are used by stock systems
// (FILTER_INDEX_* in shared.gsh); 6 is free. Avoid 7 here — it's the rain slot.
#define CAM_BODYCAM_FILTER_ID       6
