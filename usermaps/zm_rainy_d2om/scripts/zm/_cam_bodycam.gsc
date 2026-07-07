// ============================================================================
//  _cam_bodycam.gsc — bodycam camera mod, server half.
//
//  The look and its motion (sway + walk bob) are client-side (_cam_bodycam.csc).
//  Server side: glitch() spikes the grain on events, plus a movement-level
//  clientfield published as a hook for future speed-driven effects. Config in .gsh.
//
//  To glitch the camera from your own event code, call it on the player:
//      player cam_bodycam::glitch( 0.8, 1.5 );  // intensity 0..1, seconds
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
    clientfield::register("toplayer", CAM_BODYCAM_CF_GLITCH, VERSION_SHIP, CAM_BODYCAM_CF_GLITCH_BITS, "float");

    callback::on_spawned(&_on_player_spawned);
}

function private _on_player_spawned()
{
    self thread _track_movement();
}

function private _track_movement()
{
    // Singleton: a respawn's new thread cancels the previous loop (no stacking).
    self notify("cam_bodycam_track_movement");
    self endon("cam_bodycam_track_movement");
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

// Public: spike the camera grain to `amount` (0..1) for `duration` seconds
// (default 1.0), then fade back. Call on a player from event code.
function glitch(amount, duration)
{
    self endon("disconnect");
    self notify("cam_bodycam_glitch");
    self endon("cam_bodycam_glitch");

    if (!isdefined(duration))
    {
        duration = 1.0;
    }

    if (amount < 0)
    {
        amount = 0;
    }
    if (amount > 1)
    {
        amount = 1;
    }

    self clientfield::set_to_player(CAM_BODYCAM_CF_GLITCH, amount);
    wait(duration);
    self clientfield::set_to_player(CAM_BODYCAM_CF_GLITCH, 0);
}

// Public: set a sustained interference_level (0..1) -- grain rising into a full
// static wipe. Drive it continuously (e.g. from distance to an objective).
function set_interference(interference_level)
{
    if (interference_level < 0)
    {
        interference_level = 0;
    }
    if (interference_level > 1)
    {
        interference_level = 1;
    }
    self clientfield::set_to_player(CAM_BODYCAM_CF_GLITCH, interference_level);
}

// Spawn a runtime interference source at `origin` and drive every player's
// interference by distance to it. Returns the entity; call stop_interference_source
// on it to end. proximity_glitches=true -> near=glitch; false -> near=clear.
function spawn_interference_source(origin, range, proximity_glitches)
{
    ent = spawn("script_origin", origin);
    ent thread _proximity_loop(range, proximity_glitches);
    return ent;
}

// self == a source from spawn_interference_source. Stops it and clears the effect.
function stop_interference_source()
{
    self notify("cam_bodycam_source_stop");
    foreach (player in GetPlayers())
    {
        player set_interference(0);
    }
    self delete();
}

function private _proximity_loop(range, proximity_glitches)
{
    self endon("cam_bodycam_source_stop");
    level endon("end_game");

    while (true)
    {
        foreach (player in GetPlayers())
        {
            frac = Distance(player.origin, self.origin) / range;
            if (proximity_glitches)
            {
                frac = 1 - frac;
            }
            player set_interference(frac);   // set_interference clamps, so it plateaus past `range`
        }
        wait(0.1);
    }
}
