// MW3 "Scorched Earth" hand-inspection / get-up viewmodel anim, retargeted onto the BO3 viewhands.
// Public entry: recovery::play() on a player. A debug console trigger (ModVar `recovery 1`) is
// compiled in only when DEBUG_RECOVERY is set in the .gsh.
//
// The clip is driven by a weapon, the same mechanism zm_test uses for t6_deathanim: the anim lives in
// the weapon's raise/idle slots, so switching to the weapon plays it on the viewhands. This is a test
// of whether the anim's own tag_camera drives the first-person view — no xcam involved.

#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_recovery.gsh;

#namespace recovery;

REGISTER_SYSTEM("recovery", &__init__, undefined)

function __init__()
{
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

// Gives the carrier weapon and switches to it, which starts the anim. Call on a player.
function play()
{
    self endon("disconnect");
    self endon("death");

    weapon = GetWeapon(RECOVERY_WEAPON);
    weapon = self GetBuildKitWeapon(weapon, false);
    options = self GetBuildKitWeaponOptions(weapon, 0);

    self GiveWeapon(weapon, options, 0);
    self SwitchToWeaponImmediate(weapon);
}
