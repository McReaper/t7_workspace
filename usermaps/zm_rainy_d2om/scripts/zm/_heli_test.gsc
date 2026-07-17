// Dev throwaway: plays the ported BO1 huey rappel intro. Console: `heli_test 1`
// (a ModVar, not a dvar, so it can be set at runtime in a usermap).

#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache("script_bundle", "cin_heli_test");
#precache("script_bundle", "cin_rappel_fp");
#precache("script_bundle", "cin_rope");
#precache("script_bundle", "cin_rope2");
#precache("script_bundle", "cin_rappel_npc1");
#precache("script_bundle", "cin_rappel_npc2");
#precache("script_bundle", "cin_pilot");
#precache("xcam", "rappel_cam");
#precache("fx", "_reapy/fx_huey_main_blade_full");
#precache("fx", "_reapy/fx_huey_small_blade_full");

#namespace heli_test;

REGISTER_SYSTEM("heli_test", &__init__, undefined)

function __init__()
{
    clientfield::register("toplayer", "heli_xcam", VERSION_SHIP, 1, "int");
    clientfield::register("scriptmover", "heli_snd", VERSION_SHIP, 1, "int");
    level scene::init("cin_heli_test");
    level scene::init("cin_rappel_fp");
    level scene::init("cin_rope");
    level scene::init("cin_rope2");
    level scene::init("cin_rappel_npc1");
    level scene::init("cin_rappel_npc2");
    level scene::init("cin_pilot");
    level._effect["heli_rotor_main"] = "_reapy/fx_huey_main_blade_full";
    level._effect["heli_rotor_tail"] = "_reapy/fx_huey_small_blade_full";
    level thread _watch();
}

// Waits on the heli anim's "crash_begin" self-notify (frame 350) → remove the pilot.
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

// Cuts the looping heli SFX on the anim's "heli_impact" self-notify (frame 608), so the
// rotor bed stops at the crash instead of running to the scene's last frame.
function private _snd_out()
{
    self endon("death");
    level endon("end_game");
    self waittill("heli_impact");
    self clientfield::set("heli_snd", 0);
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
    _cleanup_prev();
    level.heli_test_playing = true;

    spot = struct::get("heli_intro_spawn", "targetname");
    if (!isdefined(spot))
    {
        spot = GetEnt("heli_intro_spawn", "targetname");
    }
    if (isdefined(spot))
    {
        origin = spot.origin;
        angles = spot.angles;

        align = Spawn("script_model", origin);
        align SetModel("tag_origin");
        align.angles = angles;
        align NotSolid();

        heli = Spawn("script_model", origin);
        heli SetModel("t5_veh_helo_huey");
        heli NotSolid();
        interior = Spawn("script_model", origin);
        interior SetModel("t5_veh_helo_huey_att_interior");
        interior NotSolid();
        interior LinkTo(heli, "body_animate_jnt", (0, 0, 0), (0, 0, 0));

        // Rotor blur = looping FX ported from BO1, spun by the FX engine on the joints.
        main_rotor_fx = PlayFXOnTag(level._effect["heli_rotor_main"], heli, "main_rotor_jnt");
        tail_rotor_fx = PlayFXOnTag(level._effect["heli_rotor_tail"], heli, "tail_rotor_jnt");

        // Rotor bed: looping SFX played CSC on the heli (server PlayLoopSound is silent).
        heli clientfield::set("heli_snd", 1);

        // First-person body + camera: rappel_cam XCam (played CSC via the heli_xcam CF).
        cam_body = Spawn("script_model", origin);
        cam_body SetModel("c_zom_der_dempsey_viewbody");
        cam_body NotSolid();

        // Ropes track the heli via the same align (bundles are type "scene", NoSpawn=1).
        rope = Spawn("script_model", origin);
        rope SetModel("fxanim_quag_rappelcrash02_mod");
        rope NotSolid();
        align thread scene::play("cin_rope", rope);

        rope2 = Spawn("script_model", origin);
        rope2 SetModel("fxanim_quag_rappelcrash01_mod");
        rope2 NotSolid();
        align thread scene::play("cin_rope2", rope2);

        // NPC rappellers (barnes + soldier anims retargeted onto mwr_mp_usmc_lmg_pb_base).
        npc1 = Spawn("script_model", origin);
        npc1 SetModel("c_zom_der_nikolai_mpc_fb");
        npc1 NotSolid();
        align thread scene::play("cin_rappel_npc1", npc1);

        npc2 = Spawn("script_model", origin);
        npc2 SetModel("c_zom_der_takeo_mpc_fb");
        npc2 NotSolid();
        align thread scene::play("cin_rappel_npc2", npc2);

        // Copilot idle, placed once at the driver-seat tag (no link).
        pilot_align = Spawn("script_model", heli GetTagOrigin("tag_driver"));
        pilot_align.angles = heli GetTagAngles("tag_driver");
        pilot_align NotSolid();

        npc3 = Spawn("script_model", origin);
        npc3 SetModel("c_zom_der_dempsey_mpc_fb");
        npc3 NotSolid();
        pilot_align thread scene::play("cin_pilot", npc3);
        heli thread _pilot_out(npc3);
        heli thread _snd_out();

        level.heli_test_ents = array(align, heli, interior, cam_body, rope, rope2, npc1, npc2, npc3, pilot_align);

        player = GetPlayers()[0];
        if (isdefined(player))
        {
            player clientfield::set_to_player("heli_xcam", 1);
        }

        align thread scene::play("cin_rappel_fp", cam_body);

        // Blocking (un-threaded): scene::play returns on the native scene_done, fired
        // when the heli anim reaches its last frame — no manual end-notetrack needed.
        // Nothing is stopped or deleted before it returns, so no sound gets cut mid-anim.
        align scene::play("cin_heli_test", heli);

        if (isdefined(main_rotor_fx))
        {
            main_rotor_fx Delete();
        }
        if (isdefined(tail_rotor_fx))
        {
            tail_rotor_fx Delete();
        }
        if (isdefined(player))
        {
            player clientfield::set_to_player("heli_xcam", 0);
        }
        _cleanup_prev();
    }

    level.heli_test_playing = undefined;
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
