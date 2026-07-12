// Third-person zipline traversal on the shipped pb_zipline_* scenes. Chain per
// zipline: "zipline" trigger -> start struct -> end struct (via .target).

#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zipline.gsh;

#precache("script_bundle", ZIPLINE_SCENE_ATTACH);
#precache("script_bundle", ZIPLINE_SCENE_IDLE);
#precache("script_bundle", ZIPLINE_SCENE_DISMOUNT);
#precache("fx", ZIPLINE_FX_PATH);
#precache("triggerstring", ZIPLINE_HINT_LOCALIZED);

#namespace zipline;

REGISTER_SYSTEM("zipline", &__init__, undefined)

function __init__()
{
    clientfield::register("toplayer", ZIPLINE_CF_TP, VERSION_SHIP, ZIPLINE_CF_TP_BITS, "int");
    clientfield::register("allplayers", ZIPLINE_CF_SND, VERSION_SHIP, ZIPLINE_CF_SND_BITS, "int");
    level._effect[ZIPLINE_FX_KEY] = ZIPLINE_FX_PATH;

    triggers = GetEntArray(ZIPLINE_TRIGGER_TARGETNAME, "targetname");
    foreach (trigger in triggers)
    {
        trigger thread _watch_trigger();
    }
}

function private _watch_trigger()
{
    self endon("death");
    level endon("end_game");

    start_struct = struct::get(self.target, "targetname");
    if (!isdefined(start_struct) || !isdefined(start_struct.target))
    {
        PRINT_ZIPLINE_DEBUG("^1zipline: trigger '" + self.target + "' has no start/end struct");
        return;
    }
    end_struct = struct::get(start_struct.target, "targetname");
    if (!isdefined(end_struct))
    {
        PRINT_ZIPLINE_DEBUG("^1zipline: struct '" + start_struct.target + "' (end) not found");
        return;
    }

    self SetCursorHint("HINT_ACTIVATE");
    self SetHintString(&ZIPLINE_HINT_LOCALIZED);

    while (true)
    {
        self waittill("trigger", player);
        if (!isplayer(player) || IS_TRUE(player.on_zipline))
        {
            continue;
        }
        player thread _ride(start_struct, end_struct, self);
    }
}

function private _set_phase(phase)
{
    self clientfield::set_to_player(ZIPLINE_CF_TP, phase);
    self clientfield::set(ZIPLINE_CF_SND, phase);
}

// Anims play on a player clone, never the real player (a scripted anim on the
// player permanently kills its walking-footstep notetracks). The real player is
// ghosted and rides linked to the cable model; the clone (its own skin) is animated
// anchored to that model. Pattern from cp_mi_sing_biodomes_supertrees::zipline_player.
function private _ride(start_struct, end_struct, trigger)
{
    self endon("disconnect");
    level endon("end_game");

    self.on_zipline = true;
    // Freeze input for the ride: PlayerLinkToDelta otherwise leaves the use-scan
    // latched on the trigger and its prompt stuck on screen the whole descent.
    self FreezeControls(true);

    align_model = Spawn("script_model", start_struct.origin - (0, 0, ZIPLINE_HANG_OFFSET));
    align_model SetModel("tag_origin");
    align_model.angles = VectorToAngles(end_struct.origin - start_struct.origin);
    align_model NotSolid();

    // While still "playing" — else the clientfield set errors.
    self _set_phase(ZIPLINE_TP_BOARD);

    // 180° clamps = free look (the 20/15/60 campaign values clamp the view).
    self PlayerLinkToDelta(align_model, undefined, 1, 180, 180, 180, 180);
    self DisableWeaponCycling();
    self DisableOffhandWeapons();
    self AllowCrouch(false);
    self AllowProne(false);

    clone = util::spawn_player_clone(self);
    clone NotSolid();
    trolley = _spawn_trolley(clone);
    self Ghost();

    // Scene plays the pose on the clone (object1 is now a Prop) and keeps it aligned
    // to align_model, so moving align_model slides the clone smoothly along the cable.
    align_model thread scene::play(ZIPLINE_SCENE_ATTACH, clone);
    wait(ZIPLINE_GRAB_TIME);

    self _set_phase(ZIPLINE_TP_GLIDE);
    sparks = _spawn_sparks(trolley);

    align_model thread _glide_pose(clone);
    align_model _travel(clone, start_struct, end_struct);

    sparks Delete();
    // scene::stop would reset the pose and flicker; blend the dismount instead.
    align_model notify("zipline_glide_done");

    self _set_phase(ZIPLINE_TP_LAND);

    forward = AnglesToForward(align_model.angles);
    land_spot = _ground_below(align_model.origin + (forward[0], forward[1], 0) * ZIPLINE_LAND_DIST);
    align_model MoveTo(land_spot, ZIPLINE_LAND_TIME);

    align_model scene::play(ZIPLINE_SCENE_DISMOUNT, clone);

    self Unlink();
    if (isdefined(trolley))
    {
        trolley Delete();
    }
    self Show();
    if (isdefined(clone))
    {
        clone Delete();
    }

    self EnableWeaponCycling();
    self EnableOffhandWeapons();
    self AllowCrouch(true);
    self AllowProne(true);

    // Let the CSC ramp the camera back before deleting the model it still frames.
    self _set_phase(ZIPLINE_TP_OFF);
    wait(ZIPLINE_TP_FADE);

    if (isdefined(align_model))
    {
        align_model Delete();
    }
    self FreezeControls(false);
    self.on_zipline = undefined;
}

function private _glide_pose(actor)
{
    self endon("death");
    self endon("zipline_glide_done");
    level endon("end_game");

    while (true)
    {
        self scene::play(ZIPLINE_SCENE_IDLE, actor);
        wait(0.05);
    }
}

function private _travel(actor, start_struct, end_struct)
{
    self endon("death");
    level endon("end_game");

    forward = AnglesToForward(self.angles);
    destination = end_struct.origin - forward * ZIPLINE_DISMOUNT_LEAD;
    total_distance = Distance(start_struct.origin, destination);

    while (true)
    {
        // Drive progress from the grip, compensating its offset, so the trolley
        // stays on the cable rather than the model's origin.
        hand_origin = actor GetTagOrigin(ZIPLINE_TROLLEY_TAG);
        grip_offset = hand_origin - self.origin;
        progress = VectorDot(hand_origin - start_struct.origin, forward) + ZIPLINE_SPEED_UPS * ZIPLINE_TICK;
        if (progress > total_distance)
        {
            progress = total_distance;
        }
        self.origin = start_struct.origin + forward * progress - grip_offset - (0, 0, ZIPLINE_GRIP_DROP);
        if (progress >= total_distance)
        {
            break;
        }
        wait(ZIPLINE_TICK);
    }
}

function private _spawn_trolley(host)
{
    trolley = Spawn("script_model", host.origin);
    trolley SetModel(ZIPLINE_TROLLEY_MODEL);
    trolley NotSolid();
    trolley LinkTo(host, ZIPLINE_TROLLEY_TAG, (0, 0, 0), (0, 0, 0));
    return trolley;
}

function private _spawn_sparks(trolley)
{
    sparks = Spawn("script_model", trolley.origin);
    sparks SetModel("tag_origin");
    sparks NotSolid();
    sparks LinkTo(trolley, "tag_origin", (ZIPLINE_FX_FWD, ZIPLINE_FX_LEFT, ZIPLINE_FX_UP), (ZIPLINE_FX_PITCH, ZIPLINE_FX_YAW, ZIPLINE_FX_ROLL));
    PlayFXOnTag(level._effect[ZIPLINE_FX_KEY], sparks, "tag_origin");
    return sparks;
}

function private _ground_below(land_spot)
{
    trace = BulletTrace(land_spot + (0, 0, ZIPLINE_LAND_TRACE_UP), land_spot - (0, 0, ZIPLINE_LAND_TRACE_DOWN), false, undefined);
    if (trace["fraction"] < 1)
    {
        return trace["position"] + (0, 0, ZIPLINE_LAND_GROUND_OFFSET);
    }
    return land_spot;
}

