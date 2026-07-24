// Client half of the heli intro test: the rotor-bed loop sound (heli_snd) and the crash FX
// (heli_fx: rotor blur, smoke trails, explosion), both driven by clientfields from the GSC.

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_heli_intro.gsh;

#precache("client_fx", "_reapy/fx_huey_main_blade_full");
#precache("client_fx", "_reapy/fx_huey_small_blade_full");
#precache("client_fx", "killstreaks/fx_heli_smk_trail_tail");
#precache("client_fx", "killstreaks/fx_heli_exp_lg");

#namespace heli_intro;

REGISTER_SYSTEM("heli_intro", &__init__, undefined)

function __init__()
{
    level._effect["heli_rotor_main_fx"] = "_reapy/fx_huey_main_blade_full";
    level._effect["heli_rotor_tail_fx"] = "_reapy/fx_huey_small_blade_full";
    level._effect["heli_smk_trail"] = "killstreaks/fx_heli_smk_trail_tail";
    level._effect["heli_exp_lg"] = "killstreaks/fx_heli_exp_lg";

    clientfield::register("scriptmover", "heli_snd", VERSION_SHIP, 1, "int", &_on_snd_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
    clientfield::register("scriptmover", "heli_fx", VERSION_SHIP, 3, "int", &_on_fx_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
}

// Rotor bed looped on the heli (server sound is silent); stopped on newval 0 and,
// as a backstop, when the heli entity is deleted.
function private _on_snd_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    if (!IsSplitScreenHost(localclientnum))
    {
        return;
    }
    
    if (newval == 1)
    {
        self PlayLoopSound("heli_rotor_main", 0);
        self PlayLoopSound("heli_rotor_tail", 0);
        self PlayLoopSound("heli_turbine", 0);
        self PlayLoopSound("heli_lfe", 0);
    }
    else
    {
        self StopAllLoopSounds(0.5);
    }
}

// Crash FX, played client-side so the looping blur/trail can be StopFX'd without deleting the
// host heli (the GSC-FX trap that was killing the heli mid-anim). States: see _heli_intro.gsh.
function private _on_fx_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    switch (newval)
    {
        case HELI_FX_FLYING:
            self.rotor_main_fx = PlayFXOnTag(localclientnum, level._effect["heli_rotor_main_fx"], self, "main_rotor_jnt");
            self.rotor_tail_fx = PlayFXOnTag(localclientnum, level._effect["heli_rotor_tail_fx"], self, "tail_rotor_jnt");
            break;
        case HELI_FX_CRASHING:
            self.trail_fx = PlayFXOnTag(localclientnum, level._effect["heli_smk_trail"], self, "tag_deathfx");
            break;
        case HELI_FX_IMPACT:
            // First impact @550: stop the descent trail and fire the explosion. The rotor
            // blur keeps spinning until the second explosion.
            _stop_fx(localclientnum, self.trail_fx);
            self.trail_fx = undefined;
            PlayFX(localclientnum, level._effect["heli_exp_lg"], self GetTagOrigin("tag_deathfx"));
            break;
        case HELI_FX_EXPLODE:
            // Second explosion @608: the rotor blur stops here.
            _stop_fx(localclientnum, self.rotor_main_fx);
            _stop_fx(localclientnum, self.rotor_tail_fx);
            self.rotor_main_fx = undefined;
            self.rotor_tail_fx = undefined;
            PlayFX(localclientnum, level._effect["heli_exp_lg"], self GetTagOrigin("tag_deathfx"));
            break;
    }
}

function private _stop_fx(localclientnum, handle)
{
    if (isdefined(handle))
    {
        StopFX(localclientnum, handle);
    }
}
