// Dev throwaway: plays the ported BO1 huey rappel intro. Console: `heli_test 1`
// (a ModVar, not a dvar, so it can be set at runtime in a usermap).

#using scripts\codescripts\struct;

#using scripts\shared\animation_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_heli_test.gsh;

#using_animtree("generic");

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

// Ordered point list of the heli_intro_spawn target chain (any node count).
function private _flyby_path()
{
    a_pts = [];
    node = _get_node("heli_intro_spawn");
    while (isdefined(node))
    {
        a_pts[a_pts.size] = node.origin;
        if (!isdefined(node.target))
        {
            break;
        }
        node = _get_node(node.target);
    }
    return a_pts;
}

// Catmull-Rom position along the point list at global param t in [0, count-1].
function private _spline_pos(a_pts, t)
{
    n = a_pts.size;
    seg = Int(t);
    if (seg >= n - 1)
    {
        return a_pts[n - 1];
    }
    u = t - seg;
    p1 = a_pts[seg];
    p2 = a_pts[seg + 1];
    p0 = (seg > 0 ? a_pts[seg - 1] : p1);
    p3 = (seg + 2 < n ? a_pts[seg + 2] : p2);
    u2 = u * u;
    u3 = u2 * u;
    return (p1 * 2 + (p2 - p0) * u + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 + (p1 * 3 - p2 * 3 + p3 - p0) * u3) * 0.5;
}

// Flies the heli along the Catmull-Rom curve through a_pts as short linear MoveTo pieces (smooth),
// banking into turns. The player rides first person, linked to a heli tag.
function private _flyby(heli, a_pts)
{
    level endon("end_game");

    n = a_pts.size;
    start_yaw = VectorToAngles(a_pts[1] - a_pts[0])[1];
    heli.origin = a_pts[0];
    heli.angles = (FLYBY_PITCH_FWD, start_yaw + HELI_YAW_OFFSET, 0);
    _ride_camera(heli);
    _spawn_riders(heli);

    approx_len = 0;
    for (i = 1; i < n; i++)
    {
        approx_len += Distance(a_pts[i - 1], a_pts[i]);
    }
    num_pieces = Int(approx_len / FLYBY_SEG_LEN);
    if (num_pieces < 2)
    {
        num_pieces = 2;
    }

    // Cruise at constant speed, nose-down, banking; stops short so the brake/flare owns the tail.
    brake_piece = Int(num_pieces * FLYBY_LEVEL_FRAC);
    prev_pos = a_pts[0];
    prev_yaw = start_yaw;
    for (i = 1; i <= brake_piece; i++)
    {
        pos = _spline_pos(a_pts, (n - 1) * (i / num_pieces));
        dir = pos - prev_pos;

        yaw = prev_yaw;
        if (LengthSquared(dir) > 0.01)
        {
            yaw = VectorToAngles(dir)[1];
        }
        roll = math::clamp(-1 * FLYBY_BANK_PER_DEG * AngleClamp180(yaw - prev_yaw), -1 * FLYBY_BANK_MAX, FLYBY_BANK_MAX);

        // Snap to whole server frames so MoveTo and wait line up (else the heli pauses each joint).
        frames = Int(Length(dir) / FLYBY_SPEED_UPS / SERVER_FRAME + 0.5);
        if (frames < 1)
        {
            frames = 1;
        }
        t_seg = frames * SERVER_FRAME;

        heli MoveTo(pos, t_seg);
        heli RotateTo((FLYBY_PITCH_FWD, yaw + HELI_YAW_OFFSET, roll), t_seg);
        wait(t_seg);

        prev_pos = pos;
        prev_yaw = yaw;
    }

    // Brake to a stop, entering at cruise speed (brake_time = 2*dist/speed, decel over the whole move)
    // so there's no velocity jump. Nose flares up then settles level over the brake.
    end_pos = a_pts[n - 1];
    final_yaw = prev_yaw;
    if (LengthSquared(end_pos - prev_pos) > 0.01)
    {
        final_yaw = VectorToAngles(end_pos - prev_pos)[1];
    }

    brake_time = 2 * Distance(prev_pos, end_pos) / FLYBY_SPEED_UPS;
    heli MoveTo(end_pos, brake_time, 0, brake_time);
    heli thread _flare(final_yaw + HELI_YAW_OFFSET, brake_time);
    wait(brake_time);
}

// Nose flares up then settles level over the brake time (eased), on the heli independently so the
// arrival transition can overlap the brake.
function private _flare(yaw, brake_time)
{
    self endon("death");
    level endon("end_game");

    up_time = brake_time * FLYBY_FLARE_PEAK;
    down_time = brake_time - up_time;
    self RotateTo((-1 * FLYBY_PITCH_BRAKE, yaw, 0), up_time, up_time * FLYBY_FLARE_EASE, up_time * FLYBY_FLARE_EASE);
    wait(up_time);
    self RotateTo((0, yaw, 0), down_time, down_time * FLYBY_FLARE_EASE, down_time * FLYBY_FLARE_EASE);
}

// Pilot (on tag_driver) + the player's own body (on the ride tag), linked to the heli tags via
// animation::play so they ride along animated with the driver idle.
function private _spawn_riders(heli)
{
    pilot = Spawn("script_model", heli GetTagOrigin("tag_driver"));
    pilot SetModel(HELI_PILOT_MODEL);
    pilot NotSolid();
    pilot UseAnimTree(#animtree);
    pilot thread animation::play(HELI_RIDE_IDLE, heli, "tag_driver");

    body = Spawn("script_model", heli GetTagOrigin(HELI_RIDE_TAG));
    body SetModel(HELI_RIDER_MODEL);
    body NotSolid();
    body UseAnimTree(#animtree);
    body thread animation::play(HELI_RIDE_IDLE, heli, HELI_RIDE_TAG);

    level.heli_test_riders = array(pilot, body);
}

function private _cleanup_riders()
{
    if (!isdefined(level.heli_test_riders))
    {
        return;
    }
    foreach (ent in level.heli_test_riders)
    {
        if (isdefined(ent))
        {
            ent Delete();
        }
    }
    level.heli_test_riders = undefined;
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
        a_pts = _flyby_path();
        b_flyby = a_pts.size >= 2;

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

        // FP rappel body (animated by cin_rappel_fp). Hidden during the first-person ride.
        cam_body = Spawn("script_model", spawn_node.origin);
        cam_body SetModel("c_zom_der_dempsey_viewbody");
        cam_body NotSolid();
        cam_body Hide();

        level.heli_test_ents = array(align, heli, interior, cam_body);

        // Rotor blur + rotor-bed loop for the whole intro (both CSC).
        heli clientfield::set("heli_fx", HELI_FX_FLYING);
        heli clientfield::set("heli_snd", 1);

        if (b_flyby)
        {
            end_pt = a_pts[a_pts.size - 1];
            final_yaw = VectorToAngles(end_pt - a_pts[a_pts.size - 2])[1];

            _flyby(heli, a_pts);

            // Anchor the scene at the arrival. The heli + FX + riders stay up (player still riding)
            // while the scenes below spin up; we release + drop the riders after HELI_HANDOFF_FRAMES.
            align.origin = end_pt;
            align.angles = (0, final_yaw, 0);
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

        level.heli_test_ents = array(align, heli, interior, cam_body, rope, rope2, npc1, npc2, npc3, pilot_align);

        // Rappel scene drives its own rappel_cam. cin_heli_crash drives the heli; both anchor on align.
        cam_body Show();
        align thread scene::play("cin_rappel_fp", cam_body);
        align thread scene::play("cin_heli_crash", heli);

        // Let the flight visuals overlap the scene spin-up for a few frames, then release the player
        // ride and drop the ride riders (the scene's own pilot/rappellers have taken over).
        if (b_flyby)
        {
            wait(HELI_HANDOFF_FRAMES * SERVER_FRAME);
            _release_ride_camera();
            _cleanup_riders();
        }

        // Teardown on the heli anim's last-frame self-notify (heli_end @1095).
        heli waittill("heli_end");

        _restore_players();
        _cleanup_prev();
    }

    level.heli_test_playing = undefined;
}

// First-person ride: link each player to the heli's ride tag with clamped free-look, so they ride
// inside the heli and follow its motion+rotation. Granular locks replace FreezeControls (doesn't
// survive a link).
function private _ride_camera(heli)
{
    level.heli_test_players = GetPlayers();
    foreach (player in level.heli_test_players)
    {
        // Save the map origin — the link teleports the body onto the heli, so we drop it back
        // grounded at the handoff (else it falls to its death).
        player.heli_test_org = player.origin;
        player.heli_test_ang = player.angles;

        player DisableWeapons();
        player DisableOffhandWeapons();
        player AllowCrouch(false);
        player AllowProne(false);
        player setClientUIVisibilityFlag("hud_visible", 0);
        player Ghost();
        player PlayerLinkToDelta(heli, HELI_RIDE_TAG, 1, FLYBY_LOOK_RIGHT, FLYBY_LOOK_LEFT, FLYBY_LOOK_UP, FLYBY_LOOK_DOWN);
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
            player Show();
            player FreezeControls(false);
            player EnableWeapons();
            player EnableOffhandWeapons();
            player AllowCrouch(true);
            player AllowProne(true);
            player setClientUIVisibilityFlag("hud_visible", 1);
        }
    }
    level.heli_test_players = undefined;
}

function private _cleanup_prev()
{
    _cleanup_riders();   // safety: released at the handoff, but not on an aborted run
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
