"""
Post-bake conversion. Run AFTER the bake shelf button, BEFORE exporting.

  1. checks the bake actually landed (target joints must own keys now)
  2. deletes every constraint, so the baked curves play on their own
  3. zeroes MW3's constant tag_torso rotation      (FLATTEN_TORSO)
  4. strips the bo3_ prefix

Step 4 is not optional: the prefix only existed to stop the Cast anim importer
choking on duplicate short names between the two rigs. An xanim exported with
bones called bo3_j_wrist_le binds to no model at all.

Safe to re-run; each phase is a no-op once done.

--------------------------------------------------------------------------------
What the engine actually reads, established by measurement:

  * View POSITION comes from tag_view, which the engine parks on the player's
    eye. tag_camera / tag_cambone only supply a DIRECTION - every working
    reference pins both at (0,0,0) with zero amplitude, so their position cannot
    be load-bearing. Translating tag_camera changes nothing on screen, and
    neither does translating tag_torso. If the hands need repositioning
    relative to the view, do it on an animation layer - this script no longer
    ships a constant-offset knob, because none of them reproduced reliably.
  * The viewmodel hangs off tag_torso, and BO3 expects that torso at identity.
    MW3 keeps it permanently pivoted (a constant ~(101.7, 8.2, 68.0) local to
    tag_ads) and authors the arms in that frame; orientConstraint -mo copies the
    convention faithfully, and that constant ~100 deg is what rendered as "arms
    rotated 90 degrees in game". Phase 3 is the fix.

Dead ends, all measured, none of which helped - do not repeat:

  clear tag_view + tag_ads          -> no change, arms still offset
  rebase per-frame onto the camera  -> view frozen, hands ~12 units below the
                                       view axis, invisible
  + pin torso to camera             -> arms gone entirely
  rebase by constant inv(camera@0)  -> view detached from the body
  translate tag_camera              -> no visible effect at all

The world placement was never the problem, and neither was the camera.
--------------------------------------------------------------------------------
"""
import maya.cmds as cmds

DST_ROOT = "Joints1"
PREFIX = "bo3_"
FLATTEN_TORSO = True     # zero MW3's constant tag_torso rotation - see flatten_torso


def _one(short):
    hits = [p for p in (cmds.ls(PREFIX + short, long=True) or [])
            if p.startswith("|" + DST_ROOT + "|")]
    return hits[0] if hits else None


def check_bake():
    js = cmds.listRelatives(DST_ROOT, ad=True, type="joint", f=True) or []
    keyed = sum(1 for j in js if (cmds.keyframe(j, q=True, kc=True) or 0) > 0)
    print("   %d / %d target joints hold keys" % (keyed, len(js)))
    if keyed == 0:
        print("   !! nothing baked - run the bake shelf button first, then re-run this")
        return False
    return True


def drop_constraints():
    cons = []
    for t in ("parentConstraint", "pointConstraint", "orientConstraint",
              "aimConstraint", "scaleConstraint"):
        cons += cmds.ls(type=t) or []
    if cons:
        cmds.delete(cons)
    print("   deleted %d constraints" % len(cons))
    return len(cons)


def flatten_torso():
    """Drop MW3's constant tag_torso rotation, which BO3 renders as tilted arms.

    Measured on the rig, same frames, both anims loaded:
        working BO2 port : tag_torso local rot (0.0, 0.0, 0.0) on every frame
        MW3 retarget     : tag_torso local rot (101.7, 8.2, 68.0), CONSTANT

    MW3 keeps tag_torso permanently pivoted relative to tag_ads and authors the
    arms in that frame; BO3 expects it at identity and anchors the viewmodel on
    it. orientConstraint -mo faithfully copied the MW3 convention, offset
    included - and that constant ~100 deg is the "arms rotated 90 degrees" bug.

    Because the offset is CONSTANT it can be pushed down into the arms with no
    change to the animation: zero the torso's rotation, then restore the
    shoulders' world transforms so the arms keep the exact pose they had.
    Only the shoulders need restoring - everything below keeps its local keys.
    """
    torso = _one("tag_torso")
    sh = {s: _one("j_shoulder_" + s) for s in ("le", "ri")}
    if not torso or any(v is None for v in sh.values()):
        print("   !! tag_torso / shoulders not found")
        return False

    start = int(cmds.playbackOptions(q=True, min=True))
    end = int(cmds.playbackOptions(q=True, max=True))

    before = cmds.getAttr(torso + ".rotate")[0]

    world = {s: {} for s in sh}
    for f in range(start, end + 1):
        cmds.currentTime(f, edit=True)
        for s, j in sh.items():
            world[s][f] = cmds.xform(j, q=True, ws=True, m=True)

    cmds.cutKey(torso, clear=True, at=("rotateX", "rotateY", "rotateZ"))
    for ax in "XYZ":
        a = "%s.rotate%s" % (torso, ax)
        if not cmds.getAttr(a, lock=True):
            cmds.setAttr(a, 0.0)

    for f in range(start, end + 1):
        cmds.currentTime(f, edit=True)
        for s, j in sh.items():
            cmds.xform(j, ws=True, m=world[s][f])
            cmds.setKeyframe(j, at=("translateX", "translateY", "translateZ",
                                    "rotateX", "rotateY", "rotateZ"))

    cmds.currentTime(start, edit=True)
    after = cmds.getAttr(torso + ".rotate")[0]
    print("   tag_torso local rot (%.1f, %.1f, %.1f) -> (%.1f, %.1f, %.1f)"
          % (before[0], before[1], before[2], after[0], after[1], after[2]))
    print("   %d frames of shoulder motion preserved" % (end - start + 1))
    return max(abs(v) for v in after) < 0.01


def strip_prefix():
    total = 0
    for _ in range(30):
        js = cmds.listRelatives(DST_ROOT, ad=True, f=True, type="joint") or []
        todo = [p for p in js if p.split("|")[-1].startswith(PREFIX)]
        if not todo:
            break
        todo.sort(key=lambda s: s.count("|"), reverse=True)   # deepest first
        n = 0
        for p in todo:
            if not cmds.objExists(p):
                continue                       # stale path, next pass re-queries
            cmds.rename(p, p.split("|")[-1][len(PREFIX):])
            n += 1
        total += n
        if n == 0:
            break
    # count JOINTS only: the bake also makes ~10 animCurve nodes per joint, named
    # after the attribute they drive (bo3_j_wrist_le_rotateX ...). Those keep the
    # prefix and it does not matter - an xanim carries bone names, not node names.
    js = cmds.listRelatives(DST_ROOT, ad=True, type="joint", f=True) or []
    left = len([p for p in js if p.split("|")[-1].startswith(PREFIX)])
    curves = len([n for n in (cmds.ls(PREFIX + "*") or [])
                  if cmds.nodeType(n) != "joint"])
    print("   stripped %d joints   still prefixed: %d joints" % (total, left))
    print("   (%d non-joint %s* nodes left - baked anim curves, harmless)"
          % (curves, PREFIX))
    return left == 0


print("\n== 1. bake check ==")
if not check_bake():
    print("\nABORTED - nothing was changed.")
else:
    print("\n== 2. constraints ==")
    drop_constraints()
    print("\n== 3. flatten torso ==")
    if FLATTEN_TORSO:
        flatten_torso()
    else:
        print("   skipped (FLATTEN_TORSO = False)")
    print("\n== 4. strip prefix ==")
    clean = strip_prefix()
    print("\n== done ==  %s" % (
        "scrub to confirm, then export (Select > Hierarchy, check NUMPARTS 110)"
        if clean else "!! some bo3_* names remain - fix before exporting"))
