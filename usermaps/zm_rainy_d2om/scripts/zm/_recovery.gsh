// Debug: compile in the console replay trigger (ModVar `recovery 1`). Ship with this at 0 - the anim is
// then only played by a caller of recovery::play(). 1 = dev iteration (current).
#define DEBUG_RECOVERY    1

// --- MW3 mechanism -------------------------------------------------------------------------------
// Link the player to a NODE whose tag_player carries the camera + travel; the node plays the clip via
// the camera-less cin_recovery_fp scene bundle; the delta viewhands show the arms. Mirrors MW3 _id_72AD.
// Assets ripped from MW3 (Greyhound) -> recovery.gdt + model_export/_reapy/recovery/.

// The animating node the player links to. Stock BO3 viewhands (clean skinning) - the MW3 Greyhound rig
// had a broken skinned .bin (5 mesh objects, only some deformed). The BO3-retargeted anim drives it fully.
#define RECOVERY_NODE_MODEL   "c_zom_der_dempsey_viewhands"

// The tag on the rig the player links to (its motion carries the camera). BO3 has no tag_player, but the
// retargeted anim has tag_view / tag_camera / tag_cambone / tag_torso - any of them works (the MW3
// tag_player was just a link anchor). The _dbg print compares their heights so you can pick the best.
#define RECOVERY_LINK_TAG   "tag_camera"

// The camera-less scriptbundle scene that animates the node (object1 = the node, MainAnim = the clip).
#define RECOVERY_SCENE   "cin_recovery_fp"

// PlayerLinkToDelta puts the player ORIGIN on the linked tag, but tag_player is authored ~60 up (eye
// level - measured dz~63), which doubles the camera height (eye = origin + 60). So we link to a mount
// offset DOWN from tag_player by this (PlayerLinkToDelta takes no offset - same trick as _ride_camera's
// HELI_VIEW_OFFSET). Tune the Z until the camera sits at natural eye height.
#define RECOVERY_VIEW_OFFSET   ( 0, 0, -60 )

// The grenadeweapon that carries a wpn/none viewmodel context (kept from the old weapon method).
#define RECOVERY_WEAPON    "berlin_recovery"
