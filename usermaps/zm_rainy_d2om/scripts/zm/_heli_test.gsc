// Dev throwaway: spawn the ported BO1 huey and play its baked anim to eyeball it.
// In-game console: `heli_test 1` to (re)play it in front of the player. A ModVar
// (not a plain dvar) so it can be set at runtime in a usermap.

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

        align thread scene::play("cin_heli_test", heli);

        // Rotors: the spinning blur is a looping FX (ported from BO1) played on the
        // rotor joints — the FX engine handles the model + spin, no script spinning.
        main_rotor_fx = PlayFXOnTag(level._effect["heli_rotor_main"], heli, "main_rotor_jnt");
        tail_rotor_fx = PlayFXOnTag(level._effect["heli_rotor_tail"], heli, "tail_rotor_jnt");

        // First-person body + camera: rappel_cam XCam (played CSC via the heli_xcam CF).
        cam_body = Spawn("script_model", origin);
        cam_body SetModel("c_zom_der_dempsey_viewbody");
        cam_body NotSolid();

        // Ropes: scene::play like the heli. The bundles are type/sceneType "scene"
        // with NoSpawn=1, so the scene animates the passed model (MainAnim). Same
        // align as the heli so they track it.
        rope = Spawn("script_model", origin);
        rope SetModel("fxanim_quag_rappelcrash02_mod");
        rope NotSolid();
        align thread scene::play("cin_rope", rope);

        rope2 = Spawn("script_model", origin);
        rope2 SetModel("fxanim_quag_rappelcrash01_mod");
        rope2 NotSolid();
        align thread scene::play("cin_rope2", rope2);

        // NPC rappellers (barnes + soldier anims retargeted onto mwr_mp_usmc_lmg_pb_base),
        // same align so they slot into the scene beside the player.
        npc1 = Spawn("script_model", origin);
        npc1 SetModel("c_zom_der_nikolai_mpc_fb");
        npc1 NotSolid();
        align thread scene::play("cin_rappel_npc1", npc1);

        npc2 = Spawn("script_model", origin);
        npc2 SetModel("c_zom_der_takeo_mpc_fb");
        npc2 NotSolid();
        align thread scene::play("cin_rappel_npc2", npc2);

        // Copilot: place its align once at the heli's driver-seat tag (no link), then
        // play the idle scene there so he sits in the cockpit.
        pilot_align = Spawn("script_model", heli GetTagOrigin("tag_driver"));
        pilot_align.angles = heli GetTagAngles("tag_driver");
        pilot_align NotSolid();

        npc3 = Spawn("script_model", origin);
        npc3 SetModel("c_zom_der_dempsey_mpc_fb");
        npc3 NotSolid();
        pilot_align thread scene::play("cin_pilot", npc3);
        heli thread _pilot_out(npc3);

        player = GetPlayers()[0];
        if (isdefined(player))
        {
            player clientfield::set_to_player("heli_xcam", 1);
        }

        align scene::play("cin_rappel_fp", cam_body);

        if (isdefined(player))
        {
            player clientfield::set_to_player("heli_xcam", 0);
        }

        cam_body Delete();
        rope Delete();
        rope2 Delete();
        npc1 Delete();
        npc2 Delete();
        if (isdefined(npc3))
        {
            npc3 Delete();
        }
        pilot_align Delete();
        if (isdefined(main_rotor_fx))
        {
            main_rotor_fx Delete();
        }
        if (isdefined(tail_rotor_fx))
        {
            tail_rotor_fx Delete();
        }
        interior Delete();
        heli Delete();
        align Delete();
    }

    level.heli_test_playing = undefined;
}
