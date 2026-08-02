// Recovery get-up viewmodel that drives the first-person camera (MW3 berlin _id_72AD transposed to BO3).
// A scene bundle animates the rig as a node; the player's view is linked to a mount riding the rig's
// camera tag, so the eye follows the clip's get-up motion. Public entry: recovery::play() on a player.
// Debug console: `recovery 1` (DEBUG_RECOVERY).
//
// Why this shape: BO3 viewhands have no tag_player (MW3's link anchor), so we link to an existing tag
// that carries the motion (RECOVERY_LINK_TAG = tag_camera). PlayerLinkToDelta puts the player ORIGIN on
// the target tag and takes no position offset, so we go through a mount (LinkTo with RECOVERY_VIEW_OFFSET)
// to seat the eye at the anim level - the same trick as _heli_intro::_ride_camera.

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

    // Anchor for the scene (where the clip plays).
    align = Spawn("script_model", org);
    align SetModel("tag_origin");
    align.angles = ang;
    align NotSolid();

    // The rig, spawned as a node the scene bundle animates.
    node = Spawn("script_model", org);
    node SetModel(RECOVERY_NODE_MODEL);
    node NotSolid();

    // A mount rigidly riding the rig's camera tag, offset so the eye seats at the anim level.
    // PlayerLinkToDelta puts the player ORIGIN on its target and takes no offset, so we link to this.
    mount = Spawn("script_model", node GetTagOrigin(RECOVERY_LINK_TAG));
    mount SetModel("tag_origin");
    mount NotSolid();
    mount LinkTo(node, RECOVERY_LINK_TAG, RECOVERY_VIEW_OFFSET, (0, 0, 0));

    // Hand control over, then link the player's view to the mount (which rides RECOVERY_LINK_TAG).
    self DisableWeapons();
    self DisableOffhandWeapons();
    self AllowCrouch(false);
    self AllowProne(false);
    self PlayerLinkToDelta(mount, "tag_origin", 1, 0, 0, 0, 0);

    // Play the clip on the node (blocks until it ends).
    align scene::play(RECOVERY_SCENE, node);

    // Teardown. Drop the body back where it started (the link teleported it onto the mount, off the
    // ground, so it would fall on unlink - same reason _heli_intro grounds the player at its handoff).
    self Unlink();
    self SetOrigin(org);
    self SetPlayerAngles(ang);
    self AllowProne(true);
    self AllowCrouch(true);
    self EnableOffhandWeapons();
    self EnableWeapons();
    mount Delete();
    node Delete();
    align Delete();
}
