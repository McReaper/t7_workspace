// Client half of the heli intro test: plays the rappel_cam XCam (first-person camera +
// body) when the heli_xcam clientfield is set. PlayMainCamXCam is per-client, so this
// works for every player. Base origin/angles must match the heli_intro_spawn struct
// (serverside, not readable here) — keep in sync with the map.

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace heli_test;

REGISTER_SYSTEM("heli_test", &__init__, undefined)

function __init__()
{
    clientfield::register("toplayer", "heli_xcam", VERSION_SHIP, 1, "int", &_on_xcam_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
}

function private _on_xcam_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    // Camera is driven by the scene's cameraSwitcher (rappel_cam xcam). The bodycam
    // fisheye is intentionally LEFT ON during the cinematic (that "bodycam" look is
    // wanted for the intro). Hook kept for future per-client cinematic tweaks.
}
