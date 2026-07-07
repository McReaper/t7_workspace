// ============================================================================
//  _cam_bodycam.gsc — bodycam camera mod, server half.
//
//  Feeds the client dynamics through two clientfields: player movement (from
//  GetPlayerSpeed) drives the vignette, and glitch() spikes the grain on events
//  (earthquakes, interference, ...). The look itself is client-side
//  (_cam_bodycam.csc). Config in _cam_bodycam.gsh.
//
//  To glitch the camera from your own event code, call it on the player:
//      player cam_bodycam::glitch( 7, 1.5 );   // intensity 0..7, seconds
// ============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_cam_bodycam.gsh;

#namespace cam_bodycam;

REGISTER_SYSTEM("cam_bodycam", &__init__, undefined)

function __init__()
{
    if (!CAM_BODYCAM_ENABLED)
    {
        return;
    }

    clientfield::register("toplayer", CAM_BODYCAM_CF_MOVE, VERSION_SHIP, CAM_BODYCAM_CF_MOVE_BITS, "int");
    clientfield::register("toplayer", CAM_BODYCAM_CF_GLITCH, VERSION_SHIP, CAM_BODYCAM_CF_GLITCH_BITS, "int");

    callback::on_spawned(&_on_player_spawned);
}

function private _on_player_spawned()
{
    if (IS_TRUE(self._cam_bodycam_move_running))
    {
        return;
    }
    self._cam_bodycam_move_running = true;

    self thread _track_movement();
}

function private _track_movement()
{
    self endon("disconnect");

    last_level = -1;
    while (true)
    {
        frac = self getplayerspeed() / CAM_BODYCAM_MOVE_REFSPEED;
        if (frac > 1.0)
        {
            frac = 1.0;
        }

        move_level = int(frac * CAM_BODYCAM_CF_MOVE_MAX + 0.5);
        if (move_level != last_level)   // only touch the clientfield when it changes
        {
            self clientfield::set_to_player(CAM_BODYCAM_CF_MOVE, move_level);
            last_level = move_level;
        }

        wait(0.05);
    }
}

// Public: spike the camera grain for `duration` seconds, then fade back.
// Call on a player from your event code (earthquake, interference, ...).
//   amount   = 0..CAM_BODYCAM_CF_GLITCH_MAX
//   duration = seconds held before returning to 0 (default 1.0)
function glitch(amount, duration)
{
    self endon("disconnect");
    self notify("cam_bodycam_glitch");
    self endon("cam_bodycam_glitch");

    if (!isdefined(duration))
    {
        duration = 1.0;
    }

    amount = int(amount);
    if (amount < 0)
    {
        amount = 0;
    }
    if (amount > CAM_BODYCAM_CF_GLITCH_MAX)
    {
        amount = CAM_BODYCAM_CF_GLITCH_MAX;
    }

    self clientfield::set_to_player(CAM_BODYCAM_CF_GLITCH, amount);
    wait(duration);
    self clientfield::set_to_player(CAM_BODYCAM_CF_GLITCH, 0);
}
