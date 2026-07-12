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

// Registers the pb_zipline_* anims into the player animtree (else scene errors
// "unable to find animation '…' in tree 'all_player'").
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

    // Resolve the chain once (the end struct's own .target, an unused marker, is ignored).
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

    // HINT_ACTIVATE drives the cursorhint slot; the overridden cursorhint_image
    // widget swaps in the zipline icon whenever this trigger's hint shows.
    self SetCursorHint("HINT_ACTIVATE");
    self SetHintString(&ZIPLINE_HINT_LOCALIZED);

    while (true)
    {
        self waittill("trigger", player);
        if (!isplayer(player) || IS_TRUE(player.on_zipline))
        {
            continue;
        }
        player thread _ride(start_struct, end_struct);
    }
}

function private _ride(start_struct, end_struct)
{
    self endon("disconnect");
    level endon("end_game");

    self.on_zipline = true;

    // The scene keeps the player aligned to this root, so moving it slides them.
    align_model = Spawn("script_model", start_struct.origin - (0, 0, ZIPLINE_HANG_OFFSET));
    align_model SetModel("tag_origin");
    align_model.angles = VectorToAngles(end_struct.origin - start_struct.origin);
    align_model NotSolid();

    // While still "playing" — else set_to_player errors.
    self clientfield::set_to_player(ZIPLINE_CF_TP, ZIPLINE_TP_BOARD);

    trolley = _spawn_trolley(self);
    // Not trolley PlaySound: the trolley isn't network-synced this frame, so the
    // event drops for clients (sound only plays sometimes). Position-based instead.
    PlaySoundAtPosition(ZIPLINE_SND_BOARD, self.origin);

    // Threaded so the slide can start mid-anim, the moment the player grabs on.
    align_model thread scene::play(ZIPLINE_SCENE_ATTACH, self);
    wait(ZIPLINE_GRAB_TIME);

    self clientfield::set_to_player(ZIPLINE_CF_TP, ZIPLINE_TP_GLIDE);
    trolley PlayLoopSound(ZIPLINE_SND_MOVE);
    sparks = _spawn_sparks(trolley);

    align_model thread _glide_pose(self);
    align_model _travel(self, start_struct, end_struct);

    trolley StopLoopSound(0.2);
    sparks Delete();
    PlaySoundAtPosition(ZIPLINE_SND_DETACH, self.origin);
    // Blend the dismount over the still-running idle; scene::stop would flicker.
    align_model notify("zipline_glide_done");

    self clientfield::set_to_player(ZIPLINE_CF_TP, ZIPLINE_TP_LAND);

    // Land on the surface ahead, not mid-air at the cable end.
    forward = AnglesToForward(align_model.angles);
    land_spot = align_model.origin + (forward[0], forward[1], 0) * ZIPLINE_LAND_DIST;
    align_model MoveTo(_ground_below(land_spot), ZIPLINE_LAND_TIME);

    align_model scene::play(ZIPLINE_SCENE_DISMOUNT, self);

    // Player has let go — drop the trolley now, not after the camera ramp.
    if (isdefined(trolley))
    {
        trolley Delete();
    }

    // CSC ramps the camera back in and drops third person; wait it out before
    // deleting the align model it still frames.
    self clientfield::set_to_player(ZIPLINE_CF_TP, ZIPLINE_TP_OFF);
    wait(ZIPLINE_TP_FADE);

    if (isdefined(align_model))
    {
        align_model Delete();
    }
    self.on_zipline = undefined;
}

function private _spawn_trolley(player)
{
    trolley = Spawn("script_model", player.origin);
    trolley SetModel(ZIPLINE_TROLLEY_MODEL);
    trolley NotSolid();
    trolley LinkTo(player, ZIPLINE_TROLLEY_TAG, (0, 0, 0), (0, 0, 0));
    return trolley;
}

function private _spawn_sparks(trolley)
{
    // Server-side FX on its own model (deleted to stop it) so all clients see it.
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

function private _glide_pose(player)
{
    self endon("death");
    self endon("zipline_glide_done");
    level endon("end_game");

    // Re-play so the pose holds whether scene::play loops or returns after a pass.
    while (true)
    {
        self scene::play(ZIPLINE_SCENE_IDLE, player);
        wait(0.05);
    }
}

function private _travel(player, start_struct, end_struct)
{
    self endon("death");
    level endon("end_game");
    player endon("disconnect");

    forward = AnglesToForward(self.angles);
    destination = end_struct.origin - forward * ZIPLINE_DISMOUNT_LEAD;
    total_distance = Distance(start_struct.origin, destination);

    while (true)
    {
        // Progress = hand position + one step, so the target can't outrun it and drift up.
        hand_origin = player GetTagOrigin(ZIPLINE_TROLLEY_TAG);
        grip_offset = hand_origin - self.origin;
        progress = VectorDot(hand_origin - start_struct.origin, forward) + ZIPLINE_SPEED_UPS * ZIPLINE_TICK;
        if (progress > total_distance)
        {
            progress = total_distance;
        }
        self.origin = start_struct.origin + forward * progress - grip_offset;
        if (progress >= total_distance)
        {
            break;
        }
        wait(ZIPLINE_TICK);
    }
}
