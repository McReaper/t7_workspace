// MW3-style get-up recovery: link the player to a NODE whose tag_player carries the camera + travel;
// the node plays the clip (the camera-less cin_recovery_fp scene bundle animates it). Faithful transpose
// of MW3 berlin _id_72AD (spawn node -> playerlinkto tag_player -> play anim on node -> unlink). Public
// entry: recovery::play() on a player. Debug console: `recovery 1` (DEBUG_RECOVERY).
//
// PoC scope: materials not cabled (arms render with a default material), no viewmodel swap yet - first
// validate that tag_player drives the camera. If the node stays FROZEN (doesn't animate), the fallback
// is animation::play(%anim) + node UseAnimTree(#animtree) (the heli-rider pattern in _heli_intro, which
// definitely animates a script_model), with the anim referenced from the generic animtree.

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

// MW3 mechanism. Call on a player.
function play()
{
    self endon("disconnect");
    self endon("death");

    org = self.origin;
    ang = self.angles;

    // Align anchor for the scene (where the clip plays).
    align = Spawn("script_model", org);
    align SetModel("tag_origin");
    align.angles = ang;
    align NotSolid();

    // The node = the MW3 rig WITH tag_player. The scene animates it; its tag_player carries the player.
    node = Spawn("script_model", org);
    node SetModel(RECOVERY_NODE_MODEL);
    node NotSolid();

    // A view mount rigidly linked to the node's tag_player with a position offset (PlayerLinkToDelta
    // takes no offset, so we link the player to this - the _ride_camera trick). The offset drops the eye
    // back to natural height (tag_player is authored ~60 up, and the link puts the player origin on it).
    mount = Spawn("script_model", node GetTagOrigin(RECOVERY_LINK_TAG));
    mount SetModel("tag_origin");
    mount NotSolid();
    mount LinkTo(node, RECOVERY_LINK_TAG, RECOVERY_VIEW_OFFSET, (0, 0, 0));

    // Hand control over, then link the player to the mount (which rides tag_player, offset down).
    self DisableWeapons();
    self DisableOffhandWeapons();
    self AllowCrouch(false);
    self AllowProne(false);
    self PlayerLinkToDelta(mount, "tag_origin", 1, 0, 0, 0, 0);

    // DIAGNOSTIC (dev): where does tag_player sit vs the anchor + the player's real eye height? Tells us
    // the offset to fix the camera height. Remove once solved.
    self thread _dbg(node, align);

    // Play the clip on the node (blocks until it ends).
    align scene::play(RECOVERY_SCENE, node);

    // Teardown. Drop the body back where it started: PlayerLinkToDelta teleported it onto tag_player
    // (up high), so without this it falls from that height on unlink (same reason _heli_intro grounds
    // the player at its handoff).
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

// DIAGNOSTIC (dev): compare the key tags' height above the anchor, over the clip.
//   all three high  -> the whole anim plays too high  -> lower the anchor (or fix retarget height).
//   player high, view ~60 -> tag_player is offset; link to tag_view instead.
// (~60 = normal eye height above the feet/anchor.)
function private _dbg(node, align)
{
    self endon("disconnect");
    for (i = 0; i < 8; i++)
    {
        wait(0.35);
        if (!isdefined(node) || !isdefined(align))
        {
            return;
        }
        az = align.origin[2];
        pv = node GetTagOrigin("tag_view");
        pc = node GetTagOrigin("tag_camera");
        pb = node GetTagOrigin("tag_cambone");
        pt = node GetTagOrigin("tag_torso");
        self IPrintLnBold("dz view=" + Int(pv[2]-az) + " cam=" + Int(pc[2]-az) + " cambone=" + Int(pb[2]-az) + " torso=" + Int(pt[2]-az));
    }
}
