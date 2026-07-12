// Client half of the zipline: camera dvars (rider) + ride sounds (all clients).

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zipline.gsh;

#namespace zipline;

REGISTER_SYSTEM("zipline", &__init__, undefined)

function __init__()
{
    clientfield::register("toplayer", ZIPLINE_CF_TP, VERSION_SHIP, ZIPLINE_CF_TP_BITS, "int", &_on_thirdperson_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
    clientfield::register("allplayers", ZIPLINE_CF_SND, VERSION_SHIP, ZIPLINE_CF_SND_BITS, "int", &_on_sound_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
}

function private _on_thirdperson_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    self notify("zipline_tp_ramp");
    switch (newval)
    {
        case ZIPLINE_TP_BOARD:
            SetDvar("cg_thirdPersonCamLerpScale", ZIPLINE_TP_LERP);
            self.zipline_range = ZIPLINE_TP_RANGE_START;
            SetDvar("cg_thirdPersonRange", ZIPLINE_TP_RANGE_START);
            SetDvar("cg_thirdPerson", 1);
            self thread _ramp_range(ZIPLINE_TP_RANGE_CLOSE, false, ZIPLINE_TP_ENTER_FADE);
            break;
        case ZIPLINE_TP_GLIDE:
            self thread _ramp_range(ZIPLINE_TP_RANGE_FAR, false, ZIPLINE_TP_FADE);
            break;
        case ZIPLINE_TP_LAND:
            self thread _ramp_range(ZIPLINE_TP_RANGE_CLOSE, false, ZIPLINE_TP_FADE);
            break;
        case ZIPLINE_TP_OFF:
            self thread _ramp_range(ZIPLINE_TP_RANGE_START, true, ZIPLINE_TP_FADE);
            break;
    }
}

function private _on_sound_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    switch (newval)
    {
        case ZIPLINE_TP_BOARD:
            self PlaySound(localclientnum, ZIPLINE_SND_BOARD);
            break;
        case ZIPLINE_TP_GLIDE:
            self.zipline_loop[localclientnum] = self PlayLoopSound(ZIPLINE_SND_MOVE, 0);
            break;
        case ZIPLINE_TP_LAND:
            self _stop_loop(localclientnum);
            self PlaySound(localclientnum, ZIPLINE_SND_DETACH);
            break;
        case ZIPLINE_TP_OFF:
            self _stop_loop(localclientnum);
            break;
    }
}

function private _stop_loop(localclientnum)
{
    if (isdefined(self.zipline_loop) && isdefined(self.zipline_loop[localclientnum]))
    {
        self StopLoopSound(self.zipline_loop[localclientnum], 0.2);
        self.zipline_loop[localclientnum] = undefined;
    }
}

function private _ramp_range(target_range, disable_after, fade)
{
    self endon("zipline_tp_ramp");

    start_range = self.zipline_range;
    if (!isdefined(start_range))
    {
        start_range = target_range;
    }
    for (step = 1; step <= ZIPLINE_TP_STEPS; step++)
    {
        self.zipline_range = start_range + (target_range - start_range) * step / ZIPLINE_TP_STEPS;
        SetDvar("cg_thirdPersonRange", self.zipline_range);
        wait(fade / ZIPLINE_TP_STEPS);
    }
    if (disable_after)
    {
        SetDvar("cg_thirdPerson", 0);
    }
}
