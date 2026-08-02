"""
Look through the animation's tag_camera in the viewport - BO3 (vertical fov) view.

Creates (or re-creates) a camera called vm_preview_bo3, snaps it onto tag_camera
with the axis correction CoD needs, constrains it so it follows the anim, and
points the active panel at it. Scrub and you see roughly what the player sees in
BO3 at BO3_VFOV degrees.

Companion: view_through_tag_camera_mw3.py builds the MW3 (horizontal fov) view as
vm_preview_mw3, so you can compare the two conventions on the SAME camera path -
the only difference is the lens. To see both at once: focus one viewport panel and
run this, focus the other panel and run the mw3 one.

THE AXIS TRAP: a Maya camera looks down its -Z, a CoD tag_camera's forward is
+X. Snap one to the other raw and the view faces sideways into the body. The
fix is a relative object-space rotation of (90, 0, -90) after the snap, and only
THEN constraining with -mo so the corrected aim is what gets locked.

Run again any time to reset it. Set LOOK_THRU = False to build the camera
without hijacking the viewport.
"""
import math
import maya.cmds as cmds

CAM = "vm_preview_bo3"
TARGET = "tag_camera"        # resolved with or without the bo3_ prefix
LOOK_THRU = True

# BO3 uses VERTICAL fov, and a raw viewmodel's fov comes from the player's fov
# dvar (not an xcam flen) - so we drive the camera's VERTICAL angle of view to the
# in-game value and lock the film fit to vertical (below), so the viewport's aspect
# ratio can't skew what you see.
#     focal = (vAperture / 2) / tan(vfov / 2)     vAperture = 0.797 in = 20.24 mm
#     120 V -> 5.84      80 V -> 12.06      75 V (console default) -> 13.19
BO3_VFOV = 120.0                       # in-game (vertical) fov we're matching
_V_APERTURE_MM = 0.797 * 25.4          # 20.24 mm, the 16:9 back set on the cam below
FOCAL_LENGTH = (_V_APERTURE_MM / 2.0) / math.tan(math.radians(BO3_VFOV) / 2.0)


def _resolve(name):
    for n in (name, "bo3_" + name):
        hits = cmds.ls(n, long=True) or []
        if len(hits) == 1:
            return hits[0]
        if len(hits) > 1:
            print("   several %s in the scene, taking %s" % (n, hits[0]))
            return hits[0]
    return None


tag = _resolve(TARGET)
if not tag:
    print("!! no %s (or bo3_%s) in the scene" % (TARGET, TARGET))
else:
    # clean slate: remove every prior preview node (transform AND a stray shape
    # left by a half-finished run) so repeated clicks can't stack cameras or
    # compound the relative axis-fix below. Match by short name across the whole
    # scene, not just objExists on one path.
    for node in set(cmds.ls(CAM, CAM + "Shape", long=True) or []):
        if cmds.objExists(node):
            cmds.delete(node)

    # create WITHOUT -name, then rename: this guarantees the transform is exactly
    # CAM and its shape becomes CAMShape. Passing name= to camera() can instead
    # land CAM on the *shape*, and the following rename then collides with it and
    # yields vm_preview_bo31 - which next run's cleanup misses, so cameras pile up
    # and the view drifts a bit more each click (the idempotency bug).
    cam = cmds.camera()[0]
    cam = cmds.rename(cam, CAM)
    shape = cmds.listRelatives(cam, shapes=True)[0]

    cmds.setAttr(shape + ".focalLength", FOCAL_LENGTH)
    cmds.setAttr(shape + ".horizontalFilmAperture", 1.417)   # 36 mm
    cmds.setAttr(shape + ".verticalFilmAperture", 0.797)     # 16:9
    cmds.setAttr(shape + ".filmFit", 2)                      # 2 = Vertical: lock the vfov to viewport height, ignore aspect
    cmds.setAttr(shape + ".nearClipPlane", 0.1)
    cmds.setAttr(shape + ".displayGateMaskOpacity", 0.7)

    # 1. snap exactly onto the tag (no -mo), 2. correct the axes, 3. lock with -mo
    c = cmds.parentConstraint(tag, cam)
    cmds.delete(c)
    cmds.rotate(90, 0, -90, cam, relative=True, objectSpace=True, forceOrderXYZ=True)
    cmds.parentConstraint(tag, cam, maintainOffset=True)

    if LOOK_THRU:
        panel = cmds.getPanel(withFocus=True)
        if not panel or cmds.getPanel(typeOf=panel) != "modelPanel":
            panels = cmds.getPanel(type="modelPanel") or []
            panel = panels[0] if panels else None
        if panel:
            cmds.lookThru(panel, cam)
            print("   viewport '%s' now looks through %s" % (panel, CAM))
        else:
            print("   no model panel found - use Panels > Perspective > %s" % CAM)

    print("   %s follows %s. Scrub to preview." % (CAM, tag.split("|")[-1]))
    print("   calibrated to BO3 %.0f vertical fov  (focal %.2f mm, film fit vertical)"
          % (BO3_VFOV, FOCAL_LENGTH))
    print("   if the view faces the wrong way, adjust the (90, 0, -90) by 90 deg steps")
