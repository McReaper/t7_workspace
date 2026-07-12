// ============================================================================
//  _cam_bodycam.csc — bodycam camera mod, client half.
//
//  Applies "filter_cam_bodycam" via the filter:: API and, each frame, pushes the
//  dynamics into scriptVector3 with SetFilterPassConstant: client-side camera
//  sway + walk bob move the vignette, and a server interference level ramps grain
//  into a full static wipe. Base look stays in APE. Config in _cam_bodycam.gsh.
// ============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_cam_bodycam.gsh;

#namespace cam_bodycam;

REGISTER_SYSTEM("cam_bodycam", &__init__, undefined)

function __init__()
{
    if (!CAM_BODYCAM_ENABLED)
    {
        return;
    }

    clientfield::register("toplayer", CAM_BODYCAM_CF_MOVE, VERSION_SHIP, CAM_BODYCAM_CF_MOVE_BITS, "int", &_on_move_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
    clientfield::register("toplayer", CAM_BODYCAM_CF_GLITCH, VERSION_SHIP, CAM_BODYCAM_CF_GLITCH_BITS, "float", &_on_glitch_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);

    callback::on_localclient_connect(&_on_localclient_connect);
    callback::on_localplayer_spawned(&_on_localplayer_spawned);
}

function private _on_localclient_connect(localclientnum)
{
    // Map the filter material once; level.filter_matid[...] persists.
    filter::init_filter_indices();
    filter::map_material_helper(self, CAM_BODYCAM_MATERIAL);
}

function private _on_localplayer_spawned(localclientnum)
{
    self endon("entityshutdown");

    setfilterpassmaterial(self.localClientNum, CAM_BODYCAM_FILTER_ID, 0, filter::mapped_material_id(CAM_BODYCAM_MATERIAL));
    setfilterpassenabled(self.localClientNum, CAM_BODYCAM_FILTER_ID, 0, true);

    self thread _dynamics_updater();
}

// Clientfields only carry the raw levels; the updater smooths + applies them.
function private _on_move_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    self.cam_move_level = newval / CAM_BODYCAM_CF_MOVE_MAX;
}

function private _on_glitch_cf(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
    self.cam_glitch_level = newval;
}

function private _dynamics_updater()
{
    self notify("cam_bodycam_dynamics");
    self endon("cam_bodycam_dynamics");
    self endon("entityshutdown");

    lcn = self.localClientNum;
    // The vignette-offset jiggle reads wrong across splitscreen's shared viewports,
    // so pin it there and skip sway/bob. Grain/interference stays per-player.
    do_jiggle = !IsSplitScreen();

    // Interference static bed: one 2D loop whose volume follows the level each
    // frame. Re-spawn cleanly if this updater restarts (respawn).
    if (isdefined(self.cam_bodycam_snd_ent))
    {
        self.cam_bodycam_snd_ent delete();
    }
    self.cam_bodycam_snd_ent = spawn(lcn, self.origin, "script_origin");
    snd_id = self.cam_bodycam_snd_ent playloopsound(CAM_BODYCAM_SND_STATIC, 5);
    WAIT_CLIENT_FRAME;
    SetSoundVolume(snd_id, 0);

    prev_yaw   = self.angles[1];
    prev_pitch = self.angles[0];
    off_x = 0.0;
    off_y = 0.0;
    move_amt = 0.0;   // smoothed speed fraction driving the walk bob
    glitch = 0.0;

    if (!do_jiggle)
    {
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIG_OFF_X, 0.0);
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIG_OFF_Y, 0.0);
    }

    while (true)
    {
        // Sway: the vignette centre lags behind view rotation, then eases back.
        cur_yaw   = self.angles[1];
        cur_pitch = self.angles[0];
        dyaw   = AngleClamp180(cur_yaw - prev_yaw);
        dpitch = AngleClamp180(cur_pitch - prev_pitch);
        prev_yaw   = cur_yaw;
        prev_pitch = cur_pitch;

        target_x = math::clamp(dyaw * CAM_BODYCAM_SWAY_GAIN, -CAM_BODYCAM_SWAY_MAX, CAM_BODYCAM_SWAY_MAX);
        target_y = math::clamp(-dpitch * CAM_BODYCAM_SWAY_GAIN, -CAM_BODYCAM_SWAY_MAX, CAM_BODYCAM_SWAY_MAX);
        off_x += (target_x - off_x) * CAM_BODYCAM_SWAY_RESPONSE;
        off_y += (target_y - off_y) * CAM_BODYCAM_SWAY_RESPONSE;

        // Walk bob: speed-scaled figure-8 (vertical at double frequency), ramped in/out.
        vel = self GetVelocity();
        speed_frac = Length((vel[0], vel[1], 0)) / CAM_BODYCAM_MOVE_REFSPEED;
        if (speed_frac > 1.0)
        {
            speed_frac = 1.0;
        }
        move_amt += (speed_frac - move_amt) * CAM_BODYCAM_BOB_SMOOTH;

        bob_phase = ((self getclienttime() % CAM_BODYCAM_BOB_PERIOD) * 360.0) / CAM_BODYCAM_BOB_PERIOD;
        bob_amp   = move_amt * CAM_BODYCAM_BOB_AMP;
        bob_x = sin(bob_phase) * bob_amp;
        bob_y = sin(bob_phase * 2.0) * bob_amp * 0.6;

        // Interference level (grain -> full static) from the server, smoothed.
        glitch_target = 0.0;
        if (isdefined(self.cam_glitch_level))
        {
            glitch_target = self.cam_glitch_level;
        }
        glitch += (glitch_target - glitch) * CAM_BODYCAM_SMOOTH;
        SetSoundVolume(snd_id, glitch);

        if (do_jiggle)
        {
            setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIG_OFF_X, off_x + bob_x);
            setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIG_OFF_Y, off_y + bob_y);
        }
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_GRAIN, glitch);
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIGNETTE, 0.0);

        WAIT_CLIENT_FRAME;
    }
}
