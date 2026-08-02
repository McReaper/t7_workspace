// Recovery get-up viewmodel that drives the first-person camera (MW3 berlin _id_72AD transposed to BO3).
// A scene bundle animates the rig as a node; the player's view is linked to a mount riding the rig's
// camera tag, so the eye follows the clip's get-up motion. Public entry: recovery::play() on a player.
// Debug console: `recovery 1` (DEBUG_RECOVERY).
//
// Why this shape: BO3 viewhands have no tag_player (MW3's link anchor), so we link to an existing tag
// that carries the motion (RECOVERY_LINK_TAG = tag_camera). PlayerLinkToDelta puts the player ORIGIN on
// the target tag and takes no position offset, so we go through a mount (LinkTo, dropped by the player's
// eye height so the eye seats at the anim level) - the same trick as _heli_intro::_ride_camera.

#using scripts\codescripts\struct;

#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_recovery.gsh;

#precache("script_bundle", RECOVERY_SCENE);

#namespace recovery;

REGISTER_SYSTEM("recovery", &__init__, undefined)

function __init__()
{
    level scene::init(RECOVERY_SCENE);

    if (DEBUG_RECOVERY)
    {
        level thread _watch();
    }
}

// Debug-only console trigger (see DEBUG_RECOVERY): set the `recovery` ModVar to replay.
function private _watch()
{
    level endon("end_game");

    ModVar("recovery", "");
    while (true)
    {
        WAIT_SERVER_FRAME;

        val = GetDvarString("recovery", "");
        if (!isdefined(val) || val == "")
        {
            continue;
        }
        ModVar("recovery", "");

        foreach (player in GetPlayers())
        {
            player thread play();
        }
    }
}

// Play the get-up on a player.
function play()
{
    self endon("disconnect");
    self endon("death");

    org = self.origin;
    ang = self.angles;

    // Where the clip plays. Lowered by RECOVERY_GROUND_DROP so the downed hands reach the floor (the port
    // seats the rig a bit high). Moving the play anchor drops the visible rig AND the camera together; only
    // the played clip is affected (the player is re-grounded on teardown).
    play_org = org + (0, 0, RECOVERY_GROUND_DROP);

    // Anchor for the scene (where the clip plays).
    align = Spawn("script_model", play_org);
    align SetModel("tag_origin");
    align.angles = ang;
    align NotSolid();

    // The rig, spawned as a node the scene bundle animates.
    node = Spawn("script_model", play_org);
    node SetModel(RECOVERY_NODE_MODEL);
    node NotSolid();

    // The view mount, rigidly riding tag_camera. PlayerLinkToDelta puts the player ORIGIN on its target and
    // the engine re-adds the player's own eye height, so drop the mount by that height (via
    // GetPlayerViewHeight - no magic 60) so the eye seats at the anim level. Same trick as
    // _heli_intro::_ride_camera.
    view_offset = ( 0, 0, -1 * self GetPlayerViewHeight() );
    mount = Spawn("script_model", node GetTagOrigin(RECOVERY_LINK_TAG));
    mount SetModel("tag_origin");
    mount NotSolid();
    mount LinkTo(node, RECOVERY_LINK_TAG, view_offset, (0, 0, 0));

    // Hand control over, then link the player's view to the mount (which rides RECOVERY_LINK_TAG).
    self DisableWeapons();
    self DisableOffhandWeapons();
    self AllowCrouch(false);
    self AllowProne(false);
    self PlayerLinkToDelta(mount, "tag_origin", 1, 0, 0, 0, 0);

    // Play the clip on the node (blocks until it ends).
    align scene::play(RECOVERY_SCENE, node);

    // Teardown. The get-up travels ~100 units, so end the player WHERE the clip finishes, not where it
    // started: the link has already carried the body to the final spot (its X,Y), so keep that and just
    // plant the feet back on the floor (the link left them at camera height, off the ground). The view is
    // deliberately NOT reset - control returns seamlessly facing where the get-up's camera ended.
    end = self.origin;
    self Unlink();
    self SetOrigin((end[0], end[1], org[2]));
    self AllowProne(true);
    self AllowCrouch(true);
    self EnableOffhandWeapons();
    self EnableWeapons();
    mount Delete();
    node Delete();
    align Delete();
}
