// ============================================================================
//  _cam_bodycam.csc — bodycam camera mod, client half.
//
//  Applies "filter_cam_bodycam" via the filter:: API, and each frame pushes the
//  script-driven dynamics into the shader's cg03 register with
//  SetFilterPassConstant: movement tightens the vignette, and a server-triggered
//  glitch spikes the grain. Both come from clientfields the server sets. Base
//  look stays in APE; these are added on top. Config in _cam_bodycam.gsh.
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
    clientfield::register("toplayer", CAM_BODYCAM_CF_GLITCH, VERSION_SHIP, CAM_BODYCAM_CF_GLITCH_BITS, "int", &_on_glitch_cf, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);

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
    self.cam_glitch_level = newval / CAM_BODYCAM_CF_GLITCH_MAX;
}

function private _dynamics_updater()
{
    self endon("entityshutdown");

    lcn = self.localClientNum;

    // Sway state: last view angles + the current (lagged) vignette centre offset.
    prev_yaw   = self.angles[1];
    prev_pitch = self.angles[0];
    off_x = 0.0;
    off_y = 0.0;

    move_amt = 0.0;   // smoothed speed fraction driving the walk bob
    glitch = 0.0;

    while (true)
    {
        // --- Camera sway: the vignette "mask" lags behind view rotation, then
        //     eases back to centre -- the handheld / shoulder-cam feel. Driven
        //     purely client-side from the local view angles; no network needed.
        cur_yaw   = self.angles[1];
        cur_pitch = self.angles[0];
        dyaw   = AngleClamp180(cur_yaw - prev_yaw);       // signed deg turned this frame
        dpitch = AngleClamp180(cur_pitch - prev_pitch);
        prev_yaw   = cur_yaw;
        prev_pitch = cur_pitch;

        // Target offset trails the turn (flip either sign to change the lean),
        // clamped so fast flicks can't throw the mask off-screen.
        target_x = math::clamp(dyaw * CAM_BODYCAM_SWAY_GAIN, -CAM_BODYCAM_SWAY_MAX, CAM_BODYCAM_SWAY_MAX);
        target_y = math::clamp(-dpitch * CAM_BODYCAM_SWAY_GAIN, -CAM_BODYCAM_SWAY_MAX, CAM_BODYCAM_SWAY_MAX);

        // Follow the target with lag; when you stop turning it decays back to 0.
        off_x += (target_x - off_x) * CAM_BODYCAM_SWAY_RESPONSE;
        off_y += (target_y - off_y) * CAM_BODYCAM_SWAY_RESPONSE;

        // --- Walk bob: physical movement adds a speed-scaled figure-8 wobble
        //     (side-to-side, plus vertical at double frequency). Amplitude ramps
        //     in/out with a smoothed horizontal speed so start/stop isn't a pop. ---
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

        // --- Event glitch: grain spike from server glitch(), smoothed toward 0. ---
        glitch_target = 0.0;
        if (isdefined(self.cam_glitch_level))
        {
            glitch_target = self.cam_glitch_level;
        }
        glitch += (glitch_target - glitch) * CAM_BODYCAM_SMOOTH;

        // --- Push into scriptVector3 (sway + bob summed into the centre offset). ---
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIG_OFF_X, off_x + bob_x);
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIG_OFF_Y, off_y + bob_y);
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_GRAIN, glitch * CAM_BODYCAM_GLITCH_GRAIN);
        setfilterpassconstant(lcn, CAM_BODYCAM_FILTER_ID, 0, CAM_BODYCAM_CI_VIGNETTE, 0.0);

        WAIT_CLIENT_FRAME;
    }
}
