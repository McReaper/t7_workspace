// ============================================================================
//  _cam_bodycam.csc — bodycam camera mod, client half.
//
//  Applies the "filter_cam_bodycam" fullscreen postfx (fisheye + vignette +
//  chromatic aberration + film grain) through the filter:: API — the same path
//  the stock rain-drops and binoculars filters use: map the material once, then
//  setfilterpassmaterial + setfilterpassenabled on a filter slot. (No
//  postfxbundle / playpostfxbundle.) Config in _cam_bodycam.gsh; the server
//  half (handheld shake) is _cam_bodycam.gsc.
// ============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\filter_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\zm\_cam_bodycam.gsh;

#namespace cam_bodycam;

REGISTER_SYSTEM("cam_bodycam", &__init__, undefined)

function __init__()
{
    if (!CAM_BODYCAM_ENABLED)
    {
        return;
    }

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

    // Fullscreen scene pass (like generic_filter_binoculars) — no sprite quads.
    setfilterpassmaterial(self.localClientNum, CAM_BODYCAM_FILTER_ID, 0, filter::mapped_material_id(CAM_BODYCAM_MATERIAL));
    setfilterpassenabled(self.localClientNum, CAM_BODYCAM_FILTER_ID, 0, true);

    /# println("[cam_bodycam] enabled filter '" + CAM_BODYCAM_MATERIAL + "' on slot " + CAM_BODYCAM_FILTER_ID); #/
}
