// Debug: compile in the console replay trigger (ModVar `recovery 1`). Ship with this at 0 - the anim is
// then only played by a caller of recovery::play(). 1 = dev iteration (current).
#define DEBUG_RECOVERY    1

// MW3-style get-up (mirrors _id_72AD): the player is linked to a NODE that plays the clip via the
// camera-less cin_recovery_fp scene bundle; the node's tag carries the camera and the viewhands show the arms.

// The animating node the player links to: stock BO3 viewhands, driven by the BO3-retargeted anim.
#define RECOVERY_NODE_MODEL   "c_zom_der_dempsey_viewhands"

// The tag on the rig the player links to - its motion carries the camera. BO3 has no tag_player, so we
// ride tag_camera.
#define RECOVERY_LINK_TAG   "tag_camera"

// The camera-less scriptbundle scene that animates the node (object1 = the node, MainAnim = the clip).
#define RECOVERY_SCENE   "cin_recovery_fp"

// Lower where the rig PLAYS (world Z) so the downed HANDS reach the floor. The port seats the whole
// viewhands a bit high, so at the low pose (~frame 100, character down) the hands would hover instead of
// planting. Negative = down; moves the visible rig AND the camera together (coupled), and only affects the
// played clip - the body is restored to its real origin on teardown.
// Value from the frame-100 anim geometry: with tag_view as the ground ref (it maps to the player origin - at
// standing the camera sits 57 above it, ~eye height), the lowest hand point is ~12 above the floor, so -12
// plants the hands (-13 seats the palms/wrists, -9 the elbows).
#define RECOVERY_GROUND_DROP   -12
