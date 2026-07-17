// Client half of the heli intro test: plays the rappel_cam XCam when heli_xcam is set.
// Base origin/angles come from the serverside heli_intro_spawn struct.

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace heli_test;

REGISTER_SYSTEM("heli_test", &__init__, undefined)

function __init__()
{
    clientfield::register("toplayer", "heli_xcam", VERSION_SHIP, 1, "int", &_on_xcam_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
    clientfield::register("scriptmover", "heli_snd", VERSION_SHIP, 1, "int", &_on_snd_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
}

// Rotor bed looped on the heli (server sound is silent); stopped on newval 0 and,
// as a backstop, when the heli entity is deleted.
function private _on_snd_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    if (!IsSplitScreenHost(localclientnum))
    {
        return;
    }
    if (newval == 1)
    {
        self PlayLoopSound("heli_rotor_main", 0);
        self PlayLoopSound("heli_rotor_tail", 0);
        self PlayLoopSound("heli_turbine", 0);
        self PlayLoopSound("heli_lfe", 0);
    }
    else
    {
        self StopAllLoopSounds(0.5);
    }
}

function private _on_xcam_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    // Camera comes from the scene cameraSwitcher; the bodycam fisheye is left on
    // for the intro look. Empty hook kept for future per-client tweaks.
}
