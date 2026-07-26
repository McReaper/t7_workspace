"""
Look through the animation's tag_camera in the viewport.

Creates (or re-creates) a camera called vm_preview, snaps it onto tag_camera with
the axis correction CoD needs, constrains it so it follows the anim, and points
the active panel at it. Scrub and you see roughly what the player sees.

THE AXIS TRAP: a Maya camera looks down its -Z, a CoD tag_camera's forward is
+X. Snap one to the other raw and the view faces sideways into the body. The
fix is a relative object-space rotation of (90, 0, -90) after the snap, and only
THEN constraining with -mo so the corrected aim is what gets locked.

Run again any time to reset it. Set LOOK_THRU = False to build the camera
without hijacking the viewport.
"""
import maya.cmds as cmds

CAM = "vm_preview"
TARGET = "tag_camera"        # resolved with or without the bo3_ prefix
LOOK_THRU = True

# Focal length on a 36 mm back (16:9). Conversion:  focal = 18 / tan(fov / 2)
#     120 deg -> 10.39      100 deg -> 15.1      80 deg -> 21.4      65 deg -> 28.2
# 10.39 lines up with what the xcam side calls flen ~10, which is the very wide
# end. Only a preview aid: in game the FOV comes from the xcam's flen, or from
# the player's fov dvar for a weapon viewmodel.
FOCAL_LENGTH = 10.39     # ~120 deg horizontal


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
    if cmds.objExists(CAM):
        cmds.delete(CAM)
    cam = cmds.camera(name=CAM)[0]
    cam = cmds.rename(cam, CAM)
    shape = cmds.listRelatives(cam, shapes=True)[0]

    cmds.setAttr(shape + ".focalLength", FOCAL_LENGTH)
    cmds.setAttr(shape + ".horizontalFilmAperture", 1.417)   # 36 mm
    cmds.setAttr(shape + ".verticalFilmAperture", 0.797)     # 16:9
    cmds.setAttr(shape + ".nearClipPlane", 0.1)
    cmds.setAttr(shape + ".displayGateMaskOpacity", 0.7)

    # 1. snap exactly onto the tag (no -mo), 2. correct the axes, 3. lock with -mo
    c = cmds.parentConstraint(tag, cam)
    cmds.delete(c)
    cmds.rotate(90, 0, -90, cam, relative=True, objectSpace=True, forceOrderXYZ=True)
    cmds.parentConstraint(tag, cam, maintainOffset=True)

    if LOOK_THRU:
        panel = cmds.getPanel(withFocus=True)
        if cmds.getPanel(typeOf=panel) != "modelPanel":
            panels = cmds.getPanel(type="modelPanel") or []
            panel = panels[0] if panels else None
        if panel:
            cmds.lookThru(panel, cam)
            print("   viewport '%s' now looks through %s" % (panel, CAM))
        else:
            print("   no model panel found - use Panels > Perspective > %s" % CAM)

    print("   %s follows %s. Scrub to preview." % (CAM, tag.split("|")[-1]))
    print("   if the view faces the wrong way, adjust the (90, 0, -90) by 90 deg steps")
