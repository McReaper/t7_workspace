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

// Removes the cockpit pilot on the heli anim's "crash_begin" self-notify (frame 279).
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

// Cuts the looping rotor bed on the anim's "heli_impact" self-notify (frame 550), so it
// stops at the crash instead of running to the scene's last frame.
function private _snd_out()
{
    self endon("death");
    level endon("end_game");
    self waittill("heli_impact");
    self clientfield::set("heli_snd", 0);
}

// Drives the crash FX through the heli_fx clientfield (all FX play CSC — a server FX can't be
// stopped without deleting its host entity, which would kill the heli mid-anim). Fire trail on
// crash_begin (279), first explosion on heli_impact (550), second on heli_explo (608).
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

// The arrival node the heli flies to (and crashes at): the end of heli_intro_spawn's target
// chain. The flight is a straight line, so only the spawn and the arrival matter.
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

// Flies align (and the parallel chase-camera ent) straight from spawn to crash point with one
// MoveTo each (engine-interpolated, so both stay smooth). Eases into a nose-down forward lean, then
// levels out for the crash-scene handoff. The huey model's nose sits 90 deg off +X, so align carries
// travel + HELI_YAW_OFFSET (the linked heli renders its nose along travel). The flight is a straight,
// constant-heading line, so the chase offset (behind + above) and the cam's look-at-heli angles are
// both constant — cam_ent rides that offset and stays framed on the heli.
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

    // Link the players' view to the chase ent now that it's positioned behind the heli.
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

        // First-person view body, animated by the cin_rappel_fp scene. Hidden during the 3rd-person
        // fly-in (it would show as a stray body in the chase cam); revealed under black at the rappel.
        cam_body = Spawn("script_model", spawn_node.origin);
        cam_body SetModel("c_zom_der_dempsey_viewbody");
        cam_body NotSolid();
        cam_body Hide();

        // Chase-camera ent: _flyby positions it behind the heli, links the players' view to it, and
        // MoveTo's it in parallel for the third-person fly-in.
        cam_ent = Spawn("script_model", spawn_node.origin);
        cam_ent SetModel("tag_origin");
        cam_ent NotSolid();

        level.heli_test_ents = array(align, heli, interior, cam_body, cam_ent);

        // Rotor blur (CSC crash-FX state machine) + rotor bed run for the whole intro.
        heli clientfield::set("heli_fx", HELI_FX_FLYING);
        heli clientfield::set("heli_snd", 1);

        // Third-person fly-in: the heli rides align (linked), chase cam behind it. Then fade to black
        // while the cam pushes in, and only once fully black hand off to the first-person scene.
        if (b_flyby)
        {
            heli LinkTo(align);
            _flyby(align, cam_ent, spawn_node.origin, arrival.origin);

            travel = VectorToAngles(arrival.origin - spawn_node.origin);
            fwd = AnglesToForward(travel);

            // Push the chase cam in toward the main rotor (the tag the rotor FX plays on) and aim at
            // it — a focal point makes the zoom read as a smooth deliberate push-in. Sample the tag
            // while the heli is still linked at the arrival.
            rotor_pos = heli GetTagOrigin("main_rotor_jnt");
            zoom_pos = rotor_pos - fwd * FLYBY_ZOOM_OFFSET;

            // Fade to black while the chase cam pushes in toward the rotor.
            foreach (player in level.heli_test_players)
            {
                player thread lui::screen_fade_out(FADE_OUT_TIME);
            }
            cam_ent MoveTo(zoom_pos, FADE_OUT_TIME);
            cam_ent RotateTo(VectorToAngles(rotor_pos - zoom_pos), FADE_OUT_TIME);
            wait(FADE_OUT_TIME);

            // Fully black now: release the chase link, free the heli, and re-anchor align at the raw
            // travel heading (the crash anim faces the anchor directly, unlike the static fly-in). A
            // server frame lets the unlink/re-anchor settle before the scene starts — starting it the
            // same frame bugs the handoff. The 90-deg model/anim flip happens here, hidden by black.
            _release_ride_camera();
            heli Unlink();
            align.angles = (0, travel[1], 0);
            WAIT_SERVER_FRAME;
        }

        // Ropes track the heli via the same align (bundles are type "scene", NoSpawn=1).
        rope = Spawn("script_model", align.origin);
        rope SetModel("fxanim_quag_rappelcrash02_mod");
        rope NotSolid();
        align thread scene::play("cin_rope", rope);

        rope2 = Spawn("script_model", align.origin);
        rope2 SetModel("fxanim_quag_rappelcrash01_mod");
        rope2 NotSolid();
        align thread scene::play("cin_rope2", rope2);

        // NPC rappellers (barnes + soldier anims retargeted onto mwr_mp_usmc_lmg_pb_base).
        npc1 = Spawn("script_model", align.origin);
        npc1 SetModel("c_zom_der_nikolai_mpc_fb");
        npc1 NotSolid();
        align thread scene::play("cin_rappel_npc1", npc1);

        npc2 = Spawn("script_model", align.origin);
        npc2 SetModel("c_zom_der_takeo_mpc_fb");
        npc2 NotSolid();
        align thread scene::play("cin_rappel_npc2", npc2);

        // Copilot idle, placed once at the driver-seat tag (no link).
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
        // so we just play it. cin_rappel_fp animates cam_body (the fp view body); cin_heli_crash
        // drives the heli. Both anchor on align at the travel heading.
        cam_body Show();
        align thread scene::play("cin_rappel_fp", cam_body);
        align thread scene::play("cin_heli_crash", heli);

        // Reveal the running first-person scene from black (fly-in path only). The brief hold lets
        // the scene's rappel_cam + AnimScripted settle before the fade-in.
        if (b_flyby)
        {
            wait(FADE_HOLD);
            foreach (player in level.heli_test_players)
            {
                player thread lui::screen_fade_in(FADE_IN_TIME);
            }
        }

        // Teardown on the heli anim's final-frame self-notify (heli_end @1095). The anim holds
        // the crashed pose through to its last frame, so the explosions play out with no
        // scripted delay needed.
        heli waittill("heli_end");

        _restore_players();
        _cleanup_prev();
    }

    level.heli_test_playing = undefined;
}

// Chase camera: link each player's view to cam_ent (which _flyby sits behind + above the heli and
// angles at it, then MoveTo's — so the view stays smooth). PlayerLinkToDelta gives clamped free-look
// via its arc args; the granular control locks replace FreezeControls (which doesn't survive a link,
// per the zipline). The heli fills the frame ahead since cam_ent is angled at it.
function private _ride_camera(cam_ent)
{
    level.heli_test_players = GetPlayers();
    foreach (player in level.heli_test_players)
    {
        // PlayerLinkToDelta teleports the body to cam_ent (up in the air); save the real map origin
        // so we can drop the body back onto it at the handoff — otherwise it falls to its death.
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

// Releases the chase link so the rappel scene's own first-person camera (rappel_cam) can take over,
// and drops the body back on its saved map origin (frozen there) — the rappel view is the scene's
// scripted camera, so the body stays grounded and invisible instead of falling from the sky.
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
            player Unlink();          // safety: already released at the handoff
            _ground_player(player);   // safety: already grounded at the handoff
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
