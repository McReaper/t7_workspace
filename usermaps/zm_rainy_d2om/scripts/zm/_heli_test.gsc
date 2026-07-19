// Dev throwaway: plays the ported BO1 huey rappel intro. Console: `heli_test 1`
// (a ModVar, not a dvar, so it can be set at runtime in a usermap).

#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_heli_test.gsh;

#precache("script_bundle", "cin_heli_crash");
#precache("script_bundle", "cin_rappel_fp");
#precache("script_bundle", "cin_rope");
#precache("script_bundle", "cin_rope2");
#precache("script_bundle", "cin_rappel_npc1");
#precache("script_bundle", "cin_rappel_npc2");
#precache("script_bundle", "cin_pilot");
#precache("xcam", "rappel_cam");

#namespace heli_test;

REGISTER_SYSTEM("heli_test", &__init__, undefined)

function __init__()
{
    clientfield::register("scriptmover", "heli_snd", VERSION_SHIP, 1, "int");
    clientfield::register("scriptmover", "heli_fx", VERSION_SHIP, 3, "int");
    level scene::init("cin_heli_crash");
    level scene::init("cin_rappel_fp");
    level scene::init("cin_rope");
    level scene::init("cin_rope2");
    level scene::init("cin_rappel_npc1");
    level scene::init("cin_rappel_npc2");
    level scene::init("cin_pilot");
    level thread _watch();
}

function private _pilot_out(pilot)
{
    self endon("death");
    level endon("end_game");
    self waittill("crash_begin");
    if (isdefined(pilot))
    {
        pilot Delete();
    }
}

function private _snd_out()
{
    self endon("death");
    level endon("end_game");
    self waittill("heli_impact");
    self clientfield::set("heli_snd", 0);
}

// Crash FX driven CSC via clientfield: a server looping FX can't stop without deleting its host,
// which would kill the heli mid-anim. Frames: crash_begin 279, heli_impact 550, heli_explo 608.
function private _crash_fx()
{
    self endon("death");
    level endon("end_game");

    self waittill("crash_begin");
    self clientfield::set("heli_fx", HELI_FX_CRASHING);

    self waittill("heli_impact");
    self clientfield::set("heli_fx", HELI_FX_IMPACT);

    self waittill("heli_explo");
    self clientfield::set("heli_fx", HELI_FX_EXPLODE);
}

function private _get_node(str_targetname)
{
    node = struct::get(str_targetname, "targetname");
    if (!isdefined(node))
    {
        node = GetEnt(str_targetname, "targetname");
    }
    return node;
}

// End of heli_intro_spawn's target chain: where the heli flies to and crashes (straight line, so
// only the spawn and the arrival matter).
function private _arrival_node(spawn)
{
    node = spawn;
    while (isdefined(node.target))
    {
        next = _get_node(node.target);
        if (!isdefined(next))
        {
            break;
        }
        node = next;
    }
    return node;
}

// Straight MoveTo from spawn to crash point (engine-interpolated = smooth), easing into a nose-down
// lean then leveling. Huey nose is 90 deg off +X, so align carries travel + HELI_YAW_OFFSET.
function private _flyby(align, cam_ent, start_pt, end_pt)
{
    level endon("end_game");

    travel = VectorToAngles(end_pt - start_pt);
    yaw = travel[1] + HELI_YAW_OFFSET;
    fwd = AnglesToForward(travel);

    cam_offset = (0, 0, FLYBY_CHASE_HEIGHT) - fwd * FLYBY_CHASE_DIST;
    cam_view = VectorToAngles(fwd * FLYBY_CHASE_DIST - (0, 0, FLYBY_CHASE_HEIGHT));   // cam -> heli

    duration = Distance(start_pt, end_pt) / FLYBY_SPEED_UPS;
    if (duration < FLYBY_LEVEL_TIME * 2)
    {
        duration = FLYBY_LEVEL_TIME * 2;
    }

    align.origin = start_pt;
    align.angles = (travel[0], yaw, 0);
    cam_ent.origin = start_pt + cam_offset;
    cam_ent.angles = cam_view;
    _ride_camera(cam_ent);

    align RotateTo((travel[0] + FLYBY_PITCH_FWD, yaw, 0), FLYBY_LEVEL_TIME);
    align MoveTo(end_pt, duration);
    cam_ent MoveTo(end_pt + cam_offset, duration);
    wait(duration - FLYBY_LEVEL_TIME);
    align RotateTo((travel[0], yaw, 0), FLYBY_LEVEL_TIME);
    wait(FLYBY_LEVEL_TIME);
}

function private _watch()
{
    level endon("end_game");

    ModVar("heli_test", "");
    while (true)
    {
        WAIT_SERVER_FRAME;

        val = GetDvarString("heli_test", "");
        if (!isdefined(val) || val == "")
        {
            continue;
        }
        ModVar("heli_test", "");

        if (!IS_TRUE(level.heli_test_playing))
        {
            level thread _play();
        }
    }
}

function private _play()
{
    level endon("end_game");
    level.heli_test_playing = true;

    spawn_node = _get_node("heli_intro_spawn");
    if (isdefined(spawn_node))
    {
        arrival = _arrival_node(spawn_node);
        b_flyby = isdefined(spawn_node.target);

        align = Spawn("script_model", spawn_node.origin);
        align SetModel("tag_origin");
        if (isdefined(spawn_node.angles))
        {
            align.angles = spawn_node.angles;
        }
        align NotSolid();

        heli = Spawn("script_model", spawn_node.origin);
        heli SetModel("t5_veh_helo_huey");
        heli NotSolid();
        interior = Spawn("script_model", spawn_node.origin);
        interior SetModel("t5_veh_helo_huey_att_interior");
        interior NotSolid();
        interior LinkTo(heli, "body_animate_jnt", (0, 0, 0), (0, 0, 0));

        // FP rappel body (animated by cin_rappel_fp). Hidden during the 3rd-person fly-in.
        cam_body = Spawn("script_model", spawn_node.origin);
        cam_body SetModel("c_zom_der_dempsey_viewbody");
        cam_body NotSolid();
        cam_body Hide();

        cam_ent = Spawn("script_model", spawn_node.origin);
        cam_ent SetModel("tag_origin");
        cam_ent NotSolid();

        level.heli_test_ents = array(align, heli, interior, cam_body, cam_ent);

        // Rotor blur + rotor-bed loop for the whole intro (both CSC).
        heli clientfield::set("heli_fx", HELI_FX_FLYING);
        heli clientfield::set("heli_snd", 1);

        if (b_flyby)
        {
            heli LinkTo(align);
            _flyby(align, cam_ent, spawn_node.origin, arrival.origin);

            travel = VectorToAngles(arrival.origin - spawn_node.origin);
            fwd = AnglesToForward(travel);

            // Zoom the chase cam in toward the main rotor (the rotor-FX tag), sampled while the heli
            // is still linked at the arrival, for a focused push-in.
            rotor_pos = heli GetTagOrigin("main_rotor_jnt");
            zoom_pos = rotor_pos - fwd * FLYBY_ZOOM_OFFSET;
            foreach (player in level.heli_test_players)
            {
                player thread lui::screen_fade_out(FADE_OUT_TIME);
            }
            cam_ent MoveTo(zoom_pos, FADE_OUT_TIME);
            cam_ent RotateTo(VectorToAngles(rotor_pos - zoom_pos), FADE_OUT_TIME);
            wait(FADE_OUT_TIME);

            // Fully black: release the chase link, free the heli, re-anchor at raw travel (the crash
            // anim faces the anchor directly). The server frame lets it settle before the scene
            // starts; the 90-deg model/anim flip happens here, hidden by the black.
            _release_ride_camera();
            heli Unlink();
            align.angles = (0, travel[1], 0);
            WAIT_SERVER_FRAME;
        }

        // Ropes / rappellers: NoSpawn scene bundles, so we provide the models; all anchor on align.
        rope = Spawn("script_model", align.origin);
        rope SetModel("fxanim_quag_rappelcrash02_mod");
        rope NotSolid();
        align thread scene::play("cin_rope", rope);

        rope2 = Spawn("script_model", align.origin);
        rope2 SetModel("fxanim_quag_rappelcrash01_mod");
        rope2 NotSolid();
        align thread scene::play("cin_rope2", rope2);

        npc1 = Spawn("script_model", align.origin);
        npc1 SetModel("c_zom_der_nikolai_mpc_fb");
        npc1 NotSolid();
        align thread scene::play("cin_rappel_npc1", npc1);

        npc2 = Spawn("script_model", align.origin);
        npc2 SetModel("c_zom_der_takeo_mpc_fb");
        npc2 NotSolid();
        align thread scene::play("cin_rappel_npc2", npc2);

        // Copilot idle at the driver-seat tag (no link).
        pilot_align = Spawn("script_model", heli GetTagOrigin("tag_driver"));
        pilot_align.angles = heli GetTagAngles("tag_driver");
        pilot_align NotSolid();

        npc3 = Spawn("script_model", align.origin);
        npc3 SetModel("c_zom_der_dempsey_mpc_fb");
        npc3 NotSolid();
        pilot_align thread scene::play("cin_pilot", npc3);
        heli thread _pilot_out(npc3);
        heli thread _snd_out();
        heli thread _crash_fx();

        level.heli_test_ents = array(align, heli, interior, cam_body, cam_ent, rope, rope2, npc1, npc2, npc3, pilot_align);

        // First-person rappel scene drives its own rappel_cam — the chase link is already released,
        // so we just play it. cin_heli_crash drives the heli; both anchor on align.
        cam_body Show();
        align thread scene::play("cin_rappel_fp", cam_body);
        align thread scene::play("cin_heli_crash", heli);

        // Reveal from black once the scene is running (fly-in path only).
        if (b_flyby)
        {
            wait(FADE_HOLD);
            foreach (player in level.heli_test_players)
            {
                player thread lui::screen_fade_in(FADE_IN_TIME);
            }
        }

        // Teardown on the heli anim's last-frame self-notify (heli_end @1095).
        heli waittill("heli_end");

        _restore_players();
        _cleanup_prev();
    }

    level.heli_test_playing = undefined;
}

// Chase cam: link each player's view to cam_ent (positioned + MoveTo'd by _flyby). PlayerLinkToDelta
// gives clamped free-look; the granular locks replace FreezeControls (doesn't survive a link).
function private _ride_camera(cam_ent)
{
    level.heli_test_players = GetPlayers();
    foreach (player in level.heli_test_players)
    {
        // Save the map origin: PlayerLinkToDelta teleports the body up, so we drop it back at the
        // handoff — otherwise it falls to its death.
        player.heli_test_org = player.origin;
        player.heli_test_ang = player.angles;

        player DisableWeapons();
        player DisableOffhandWeapons();
        player AllowCrouch(false);
        player AllowProne(false);
        player setClientUIVisibilityFlag("hud_visible", 0);
        player PlayerLinkToDelta(cam_ent, undefined, 1, FLYBY_LOOK_RIGHT, FLYBY_LOOK_LEFT, FLYBY_LOOK_UP, FLYBY_LOOK_DOWN);
    }
}

// Release the chase link so the scene's rappel_cam takes over, and drop the body back on its saved
// origin (frozen) — the rappel view is scripted, so the grounded body stays invisible.
function private _release_ride_camera()
{
    if (!isdefined(level.heli_test_players))
    {
        return;
    }
    foreach (player in level.heli_test_players)
    {
        if (isdefined(player))
        {
            player Unlink();
            _ground_player(player);
            player FreezeControls(true);
        }
    }
}

function private _ground_player(player)
{
    if (isdefined(player.heli_test_org))
    {
        player SetOrigin(player.heli_test_org);
        player SetPlayerAngles(player.heli_test_ang);
    }
}

function private _restore_players()
{
    if (!isdefined(level.heli_test_players))
    {
        return;
    }
    foreach (player in level.heli_test_players)
    {
        if (isdefined(player))
        {
            player Unlink();
            _ground_player(player);
            player.heli_test_org = undefined;
            player.heli_test_ang = undefined;
            player FreezeControls(false);
            player EnableWeapons();
            player EnableOffhandWeapons();
            player AllowCrouch(true);
            player AllowProne(true);
            player setClientUIVisibilityFlag("hud_visible", 1);
            player lui::screen_fade_in(0);   // defensive: never leave a stuck black screen
        }
    }
    level.heli_test_players = undefined;
}

function private _cleanup_prev()
{
    if (!isdefined(level.heli_test_ents))
    {
        return;
    }
    foreach (ent in level.heli_test_ents)
    {
        if (isdefined(ent))
        {
            ent Delete();
        }
    }
    level.heli_test_ents = undefined;
}
