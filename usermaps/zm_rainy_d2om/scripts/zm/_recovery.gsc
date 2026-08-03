// Recovery get-up viewmodel that drives the first-person camera (MW3 berlin _id_72AD transposed to BO3).
// A scene bundle animates the rig as a node; the player's view is linked to a mount riding the rig's
// camera tag, so the eye follows the clip's get-up motion. Public entry: recovery::play() on a player.
// Debug console: `recovery 1` (DEBUG_RECOVERY).
//
// Runs on-demand, on every player independently and at the same time: all state is per-player (the scene
// bundle is AllowMultiple, so each call spawns its own instance), and the node is shown only to its owner
// (SetInvisibleToAll + SetVisibleToPlayer) so nobody sees anyone else's arms floating in the world.
// Resilient to a mid-clip death or disconnect: the lifecycle is owned by 'align' (a world entity that
// outlives the player), which tears everything down on the FIRST of {clip done, death, disconnect} - so
// no thread that holds resources ever endon()s those events, and nothing is left orphaned.
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

// Play the get-up on a player. Fire-and-forget: sets everything up, then hands the lifecycle to 'align'
// (see _run) so cleanup is guaranteed even if the player leaves. Ignores a re-trigger already in progress.
function play()
{
    if (IS_TRUE(self.recovery_active))
    {
        return; // one get-up at a time per player - no double link
    }
    self.recovery_active = true;

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

    // The rig, spawned as a node the scene bundle animates. Shown ONLY to its owner - other players must
    // not see this player's viewhands floating in the world.
    node = Spawn("script_model", play_org);
    node SetModel(RECOVERY_NODE_MODEL);
    node NotSolid();
    node SetInvisibleToAll();
    node SetVisibleToPlayer(self);

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

    // Lifecycle + guaranteed teardown, owned by align (survives a disconnect).
    align thread _run(self, node, mount, org);
}

// Owns the get-up's lifecycle on the align entity. Races the clip finishing against the player leaving,
// then always tears down. On death/disconnect it just STOPS and frees - the clip is never resumed or
// replayed at respawn/reconnect (only a fresh play() call starts it again). self == align.
function private _run(player, node, mount, org)
{
    // Route every end condition to a single "recovery_ended" on align, tagging why it ended. Relays and the
    // scene worker all endon "recovery_cleanup", so once we act, the losers stop themselves.
    if (isdefined(player))
    {
        player thread _relay_end(self, "death");
        player thread _relay_end(self, "disconnect");
    }
    self thread _play_scene(node);

    self waittill("recovery_ended", reason);
    self notify("recovery_cleanup");

    // Stop the clip if we cut it short (a clean finish has already stopped it).
    if (reason != "done")
    {
        self scene::stop(RECOVERY_SCENE);
    }

    if (isdefined(player))
    {
        // Snapshot where the clip left the body (it travels ~100 units) BEFORE unlinking.
        end = player.origin;
        player Unlink();
        // Only reposition on a clean finish: keep that final X,Y, re-ground Z, and leave the view facing
        // where the camera ended. On death/disconnect the respawn owns placement, so we don't fight it.
        if (reason == "done")
        {
            player SetOrigin((end[0], end[1], org[2]));
        }
        player AllowProne(true);
        player AllowCrouch(true);
        player EnableOffhandWeapons();
        player EnableWeapons();
        player.recovery_active = undefined;
    }

    if (isdefined(mount))
    {
        mount Delete();
    }
    if (isdefined(node))
    {
        node Delete();
    }
    self Delete(); // align
}

// Play the clip on the node (blocks), then flag a clean finish. self == align.
function private _play_scene(node)
{
    self endon("recovery_cleanup");
    self scene::play(RECOVERY_SCENE, node);
    self notify("recovery_ended", "done");
}

// Wait for one player-end event and forward it to align as the end reason. self == player.
function private _relay_end(e_align, str_event)
{
    e_align endon("recovery_cleanup");
    self waittill(str_event);
    e_align notify("recovery_ended", str_event);
}
