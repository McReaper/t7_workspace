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

#using_animtree("all_player");

#precache("script_bundle", "cin_heli_test");
#precache("xcam", "rappel_cam");

#namespace heli_test;

REGISTER_SYSTEM("heli_test", &__init__, undefined)

function __init__()
{
    clientfield::register("toplayer", "heli_xcam", VERSION_SHIP, 1, "int");
    level thread _watch();
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

        // First-person body + camera: rappel_cam XCam (played CSC via the heli_xcam CF).
        cam_body = Spawn("script_model", origin);
        cam_body SetModel("c_zom_der_dempsey_viewbody");
        cam_body NotSolid();

        // Rope: AnimScripted plays the deploy anim on the model's own animtree and
        // advances it frame-by-frame (cymbal monkey pattern). The anim carries all
        // the world motion in its bones and is authored on the same scene origin as
        // the heli, so playing it here tracks the heli with no attach needed.
        rope = Spawn("script_model", origin);
        rope SetModel("fxanim_quag_rappelcrash02_mod");
        rope NotSolid();
        rope UseAnimTree(#animtree);
        rope AnimScripted("rope_deploy", origin, angles, %fxanim_quag_rappelcrash02_anim);

        // Third rope (crash01, the single remaining rope) — same recipe, same origin.
        rope2 = Spawn("script_model", origin);
        rope2 SetModel("fxanim_quag_rappelcrash01_mod");
        rope2 NotSolid();
        rope2 UseAnimTree(#animtree);
        rope2 AnimScripted("rope_deploy", origin, angles, %fxanim_quag_rappelcrash01_anim);

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
        interior Delete();
        heli Delete();
        align Delete();
    }

    level.heli_test_playing = undefined;
}
