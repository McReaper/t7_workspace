#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#using scripts\shared\ai\zombie_utility;

// Perks
#using scripts\zm\_zm_pack_a_punch;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
#using scripts\zm\_zm_perk_deadshot;
#using scripts\zm\_zm_perk_juggernaut;
#using scripts\zm\_zm_perk_quick_revive;
#using scripts\zm\_zm_perk_sleight_of_hand;
#using scripts\zm\_zm_perk_staminup;

// Powerups
#using scripts\zm\_zm_powerup_double_points;
#using scripts\zm\_zm_powerup_carpenter;
#using scripts\zm\_zm_powerup_fire_sale;
#using scripts\zm\_zm_powerup_free_perk;
#using scripts\zm\_zm_powerup_full_ammo;
#using scripts\zm\_zm_powerup_insta_kill;
#using scripts\zm\_zm_powerup_nuke;

// Traps
#using scripts\zm\_zm_trap_electric;

#using scripts\zm\zm_usermap;

// Bodycam camera mod (feature: _cam_bodycam.gsc/.csc, config: _cam_bodycam.gsh).
#using scripts\zm\_cam_bodycam;

// First-person zipline traversal (feature: _zipline.gsc, config: _zipline.gsh).
#using scripts\zm\_zipline;

// BO1 huey rappel intro (heli_intro::play(); debug console trigger via DEBUG_HELI_INTRO).
#using scripts\zm\_heli_intro;

// *****************************************************************************
// MAIN
// *****************************************************************************

function main()
{
    zm_usermap::main();

    level._zombie_custom_add_weapons = &custom_add_weapons;

    // Set up the level's zombie zone volumes.
    level.zones = [];
    level.zone_manager_init_func = &usermap_test_zone_init;
    init_zones[0] = "start_zone";
    level thread zm_zonemgr::manage_zones(init_zones);

    level.pathdist_type = PATHDIST_ORIGINAL;

    // Bodycam demo: spawn a runtime interference source at the "bodycam_test"
    // point. Real events call cam_bodycam::spawn_interference_source(origin, ...).
    bodycam_ref = struct::get("bodycam_test", "targetname");
    if (!isdefined(bodycam_ref))
    {
        bodycam_ref = GetEnt("bodycam_test", "targetname");
    }
    if (isdefined(bodycam_ref))
    {
        cam_bodycam::spawn_interference_source(bodycam_ref.origin, 400, true);
    }
}

function usermap_test_zone_init()
{
    level flag::init("always_on");
    level flag::set("always_on");
}

function custom_add_weapons()
{
    zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);
}
