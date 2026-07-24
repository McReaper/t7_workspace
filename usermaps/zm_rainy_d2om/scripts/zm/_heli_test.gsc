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
#precache("script_bundle", "cin_pilot_player");
#precache("script_bundle", HELI_GLASS_SCENE_PLAYER);
#precache("script_bundle", HELI_GLASS_SCENE_NPC);
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
    level scene::init("cin_pilot_player");
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

// Each building-window pane breaks on its own crash-anim notetrack (self-notified on the animating
// heli): the player side and the NPC rappeller's side.
function private _glass_out()
{
    self endon("death");
    level endon("end_game");
    self thread _shatter_on_note(HELI_WINDOW_NT_PLAYER, HELI_WINDOW_ORIGIN_PLAYER, HELI_WINDOW_BRUSH_PLAYER, HELI_GLASS_SCENE_PLAYER);
    self thread _shatter_on_note(HELI_WINDOW_NT_NPC, HELI_WINDOW_ORIGIN_NPC, HELI_WINDOW_BRUSH_NPC, HELI_GLASS_SCENE_NPC);
}

// On its notetrack, hide the intact pane (script_brushmodel) and play the shatter bundle on the placed
// ClientSide script_origin (its server object spawns the shattered pane + shatter anim).
function private _shatter_on_note(str_note, str_origin, str_brush, str_scene)
{
    self endon("death");
    level endon("end_game");
    self waittill(str_note);
    s_origin = _get_node(str_origin);
    if (isdefined(s_origin))
    {
        s_origin thread scene::play(str_scene);
    }
    WAIT_SERVER_FRAME;
    brush = _get_node(str_brush);
    if (isdefined(brush))
    {
        brush Hide();
    }
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

// Ordered node list of the heli_intro_spawn target chain (any node count).
function private _flyby_nodes()
{
    a_nodes = [];
    node = _get_node("heli_intro_spawn");
    while (isdefined(node))
    {
        a_nodes[a_nodes.size] = node;
        if (!isdefined(node.target))
        {
            break;
        }
        node = _get_node(node.target);
    }
    return a_nodes;
}

// Ordered point list of the chain (the flight path).
function private _flyby_path()
{
    a_pts = [];
    foreach (node in _flyby_nodes())
    {
        a_pts[a_pts.size] = node.origin;
    }
    return a_pts;
}

// Whole-server-frame count to travel dist at speed (min 1), so MoveTo and wait land on the same
// frame — else the heli is read mid-move and pauses/recoils at each joint.
function private _frames_for(dist, speed)
{
    frames = Int(dist / speed / SERVER_FRAME + 0.5);
    if (frames < 1)
    {
        frames = 1;
    }
    return frames;
}

// Heli nose yaw eased toward the travel direction (FLYBY_YAW_SMOOTH); holds prev_yaw on a null move.
function private _yaw_toward(prev_yaw, dir)
{
    target_yaw = prev_yaw;
    if (LengthSquared(dir) > 0.01)
    {
        target_yaw = VectorToAngles(dir)[1];
    }
    return prev_yaw + AngleClamp180(target_yaw - prev_yaw) * FLYBY_YAW_SMOOTH;
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

    // Arrival heading = the last path node's authored angle (Radiant); the braking tail turns the
    // heli onto it so it finishes exactly there, and the crash scene anchors on that same heading.
    a_nodes = _flyby_nodes();
    last_node = a_nodes[a_nodes.size - 1];
    arrive_yaw = undefined;
    if (isdefined(last_node) && isdefined(last_node.angles))
    {
        arrive_yaw = last_node.angles[1];
    }

    heli.origin = a_pts[0];
    heli.angles = (FLYBY_PITCH_FWD, start_yaw + HELI_YAW_OFFSET, 0);
    _spawn_riders(heli);
    _ride_camera(heli);

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

        yaw = _yaw_toward(prev_yaw, dir);
        roll = math::clamp(-1 * FLYBY_BANK_PER_DEG * AngleClamp180(yaw - prev_yaw), -1 * FLYBY_BANK_MAX, FLYBY_BANK_MAX);

        t_seg = _frames_for(Length(dir), FLYBY_SPEED_UPS) * SERVER_FRAME;

        heli MoveTo(pos, t_seg);
        heli RotateTo((FLYBY_PITCH_FWD, yaw + HELI_YAW_OFFSET, roll), t_seg);
        wait(t_seg);

        prev_pos = pos;
        prev_yaw = yaw;
    }

    // Braking tail: keep following the spline through the remaining nodes. A single straight MoveTo
    // to the final node cut across the last curve (brutal Last-2 -> Last-1 jump) and halved the speed
    // in one step (weird slowdown). Instead ease the speed down over the tail pieces while staying on
    // the curve, folding the nose-up flare into the same per-piece rotation so the arrival decelerates
    // smoothly onto the final node. Two-pass: precompute the pieces so the recenter spans the tail.
    tail_count = num_pieces - brake_piece;
    if (tail_count < 1)
    {
        tail_count = 1;
    }

    a_tpos = [];
    a_tang = [];
    a_ttime = [];
    brake_time = 0;
    for (i = 1; i <= tail_count; i++)
    {
        piece = brake_piece + i;
        pos = _spline_pos(a_pts, (n - 1) * (piece / num_pieces));
        dir = pos - prev_pos;
        p = i / tail_count;

        // Follow the curve tangent, then blend the heading onto the last node's authored arrival angle
        // so the heli finishes exactly on it (p=1 lands on arrive_yaw).
        yaw = _yaw_toward(prev_yaw, dir);
        if (isdefined(arrive_yaw))
        {
            yaw = yaw + AngleClamp180(arrive_yaw - yaw) * p;
        }
        // Level the wings out as the tail settles (roll -> 0 at p=1) to match the level crash pose.
        roll = math::clamp(-1 * FLYBY_BANK_PER_DEG * AngleClamp180(yaw - prev_yaw), -1 * FLYBY_BANK_MAX, FLYBY_BANK_MAX) * (1 - p);

        // Nose flares up then settles level across the tail (nose-down cruise -> nose-up -> level).
        if (p <= FLYBY_FLARE_PEAK)
        {
            pitch = FLYBY_PITCH_FWD + (-1 * FLYBY_PITCH_BRAKE - FLYBY_PITCH_FWD) * (p / FLYBY_FLARE_PEAK);
        }
        else
        {
            pitch = -1 * FLYBY_PITCH_BRAKE + FLYBY_PITCH_BRAKE * ((p - FLYBY_FLARE_PEAK) / (1 - FLYBY_FLARE_PEAK));
        }

        // Smoothstep the cruise speed down to the arrival speed (no abrupt halving at the tail start).
        s = p * p * (3 - 2 * p);
        speed = FLYBY_SPEED_UPS + (FLYBY_ARRIVE_UPS - FLYBY_SPEED_UPS) * s;
        t_seg = _frames_for(Length(dir), speed) * SERVER_FRAME;

        a_tpos[a_tpos.size] = pos;
        a_tang[a_tang.size] = (pitch, yaw + HELI_YAW_OFFSET, roll);
        a_ttime[a_ttime.size] = t_seg;
        brake_time += t_seg;

        prev_pos = pos;
        prev_yaw = yaw;
    }

    if (FLYBY_RECENTER)
    {
        _recenter_ride_view(brake_time);
    }

    for (i = 0; i < a_tpos.size; i++)
    {
        heli MoveTo(a_tpos[i], a_ttime[i]);
        heli RotateTo(a_tang[i], a_ttime[i]);
        wait(a_ttime[i]);
    }

    // Wait until the heli is actually at rest before handing off: MoveTo leaves ~1 frame of residual
    // travel past its wait, which the scene handoff would read as the heli recoiling to its final pose.
    prev = heli.origin;
    for (i = 0; i < 10; i++)
    {
        WAIT_SERVER_FRAME;
        if (DistanceSquared(heli.origin, prev) < 1)
        {
            break;
        }
        prev = heli.origin;
    }
}

// Ease every ride player's free-look clamps to 0 over the brake, so the view drifts back to the ride
// facing and the scene camera cuts in on-axis. Non-blocking (engine-driven lerp).
function private _recenter_ride_view(lerp_time)
{
    if (!isdefined(level.heli_test_players))
    {
        return;
    }
    ease = lerp_time * FLYBY_RECENTER_EASE;
    foreach (player in level.heli_test_players)
    {
        if (isdefined(player))
        {
            player LerpViewAngleClamp(lerp_time, ease, ease, 0, 0, 0, 0);
        }
    }
}

// Pilot (on tag_driver) + the player's own body (on the ride tag), linked to the heli tags via
// animation::play so they ride along animated with the driver idle.
function private _spawn_riders(heli)
{
    pilot = Spawn("script_model", heli GetTagOrigin("tag_driver"));
    pilot SetModel(HELI_PILOT_MODEL);
    pilot NotSolid();
    pilot UseAnimTree(#animtree);
    pilot thread animation::play(HELI_PILOT_IDLE, heli, "tag_driver");

    body = Spawn("script_model", heli GetTagOrigin(HELI_RIDE_TAG));
    body SetModel(HELI_RIDER_MODEL);
    body NotSolid();
    body UseAnimTree(#animtree);
    body thread animation::play(HELI_PLAYER_IDLE, heli, HELI_RIDE_TAG);

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
            _flyby(heli, a_pts);

            // Anchor on the flown heli's ACTUAL resting pose (origin AND yaw) so the crash lands
            // exactly on the ride's end pose — no recoil, no heading pop. HELI_ARRIVE_FWD trims root.
            align.angles = (0, heli.angles[1] - HELI_YAW_OFFSET, 0);
            align.origin = heli.origin + AnglesToForward(align.angles) * HELI_ARRIVE_FWD;
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

        // Rappel scene drives its own rappel_cam. The crash plays on a SEPARATE heli so the flown
        // heli (still ridden) can overlap the scene's first-frame anchor and hide the AnimScripted pop.
        cam_body Show();
        align thread scene::play("cin_rappel_fp", cam_body);

        if (b_flyby)
        {
            crash_heli = Spawn("script_model", align.origin);
            crash_heli SetModel("t5_veh_helo_huey");
            crash_heli NotSolid();
            crash_interior = Spawn("script_model", align.origin);
            crash_interior SetModel("t5_veh_helo_huey_att_interior");
            crash_interior NotSolid();
            crash_interior LinkTo(crash_heli, "body_animate_jnt", (0, 0, 0), (0, 0, 0));
            crash_heli clientfield::set("heli_fx", HELI_FX_FLYING);
            crash_heli clientfield::set("heli_snd", 1);
        }
        else
        {
            crash_heli = heli;
            crash_interior = interior;
        }
        
        crash_heli thread _snd_out();
        crash_heli thread _crash_fx();
        crash_heli thread _glass_out();
        align thread scene::play("cin_heli_crash", crash_heli);

        // Overlap: hold the flown heli + FX + riders + ride camera while the crash anim anchors, then
        // hand off and drop the flown heli (crash_heli has been rendering for HELI_HANDOFF_FRAMES).
        if (b_flyby)
        {
            wait(HELI_HANDOFF_FRAMES * SERVER_FRAME);
            _release_ride_camera();
            _cleanup_riders();
            interior Delete();
            heli Delete();
        }

        // Copilot: seat it on the crash heli's driver tag once the crash anim has posed it (else it
        // clips forward on the stale flight-end pose).
        pilot_align = Spawn("script_model", crash_heli GetTagOrigin("tag_driver"));
        pilot_align.angles = crash_heli GetTagAngles("tag_driver");
        pilot_align NotSolid();
        npc3 = Spawn("script_model", pilot_align.origin);
        npc3 SetModel("c_zom_der_dempsey_mpc_fb");
        npc3 NotSolid();
        pilot_align thread scene::play("cin_pilot", npc3);
        crash_heli thread _pilot_out(npc3);

        level.heli_test_ents = array(align, crash_heli, crash_interior, cam_body, rope, rope2, npc1, npc2, npc3, pilot_align);

        // Teardown on the crash anim's last-frame self-notify (heli_end @1095).
        crash_heli waittill("heli_end");

        _restore_players();
        _cleanup_prev();
    }

    level.heli_test_playing = undefined;
}

// First-person ride: link each player's view to the heli's ride tag with clamped free-look, so they
// ride inside the heli and follow its motion+rotation. Granular locks replace FreezeControls
// (doesn't survive a link).
function private _ride_camera(heli)
{
    // A view mount linked to the ride tag with a local offset — PlayerLinkToDelta takes no position
    // offset, so the players link to this instead (tune HELI_VIEW_OFFSET).
    mount = Spawn("script_model", heli GetTagOrigin(HELI_VIEW_TAG));
    mount SetModel("tag_origin");
    mount NotSolid();
    mount LinkTo(heli, HELI_VIEW_TAG, HELI_VIEW_OFFSET, HELI_VIEW_ANGLES);
    level.heli_test_view_mount = mount;

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
        player PlayerLinkToDelta(mount, "tag_origin", 1, FLYBY_LOOK_RIGHT, FLYBY_LOOK_LEFT, FLYBY_LOOK_UP, FLYBY_LOOK_DOWN);
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

    if (isdefined(level.heli_test_view_mount))
    {
        level.heli_test_view_mount Delete();
        level.heli_test_view_mount = undefined;
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
    if (isdefined(level.heli_test_view_mount))
    {
        level.heli_test_view_mount Delete();
        level.heli_test_view_mount = undefined;
    }
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
