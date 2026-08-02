"""
Post-bake conversion. Run AFTER the bake shelf button, BEFORE exporting.

  1.  checks the bake actually landed (target joints must own keys now)
  2.  deletes every constraint, so the baked curves play on their own
  3.  zeroes MW3's constant tag_torso rotation             (FLATTEN_TORSO)
  3c. spreads the forearm twist across j_wristtwist1..6     (DISTRIBUTE_TWIST)
  4.  strips the bo3_ prefix

Step 4 is not optional: the prefix only existed to stop the Cast anim importer
choking on duplicate short names between the two rigs. An xanim exported with
bones called bo3_j_wrist_le binds to no model at all.

Safe to re-run; each phase is a no-op once done.
"""
import math
import maya.cmds as cmds
from maya.api import OpenMaya as om

DST_ROOT = "Joints1"
PREFIX = "bo3_"
FLATTEN_TORSO = True     # zero MW3's constant tag_torso rotation - see flatten_torso

# Spread the forearm twist across the BO3 wrist-twist chain. MW3 has ONE wrist joint; BO3 has
# j_wristtwist1..6 (siblings under j_elbow) that distribute pronation/supination from elbow to wrist so
# the sleeve doesn't pinch ("candy wrapper"). The retarget only drives j_wrist, so those 6 sit at bind.
# We extract the wrist's PURE twist (swing-twist decomposition, no bend leak) and key each joint to a
# fraction of it - the fraction is the joint's REST position along the forearm, from geometry (the
# numbering is NOT elbow-to-wrist, so an index-based i/N spreads it backwards). TWIST_AXIS = the bone's
# roll axis (0=X, 1=Y, 2=Z); if the wrist BENDS instead of twisting, change it.
DISTRIBUTE_TWIST = True
NUM_TWIST = 6
TWIST_AXIS = 0

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


def _twist_angle(joint, axis):
    """Signed twist angle (deg) of the joint's animated rotation around its local axis (0=X/1=Y/2=Z).
    Swing-twist decomposition: project the quaternion's vector part onto the axis, so only the roll is
    kept (bend is discarded)."""
    e = cmds.getAttr(joint + ".rotate")[0]
    q = om.MEulerRotation(math.radians(e[0]), math.radians(e[1]), math.radians(e[2]),
                          cmds.getAttr(joint + ".rotateOrder")).asQuaternion()
    comp = (q.x, q.y, q.z)[axis]
    return math.degrees(2.0 * math.atan2(comp, q.w))


def _set_twist(joint, axis, angle):
    r = [0.0, 0.0, 0.0]
    r[axis] = angle
    for i, ax in enumerate("XYZ"):
        a = "%s.rotate%s" % (joint, ax)
        if not cmds.getAttr(a, lock=True):
            cmds.setAttr(a, r[i])
    cmds.setKeyframe(joint, at=("rotateX", "rotateY", "rotateZ"))


def _pos(node):
    return om.MVector(*cmds.xform(node, q=True, ws=True, t=True))


def distribute_wrist_twist():
    """Key j_wristtwist1..N to a fraction of the wrist's pure twist, per side, every frame. The fraction
    is each joint's REST position along the forearm (elbow=0, wrist=1), derived from geometry - the
    numbering is not elbow-to-wrist order, so an index-based i/N would spread it backwards."""
    start = int(cmds.playbackOptions(q=True, min=True))
    end = int(cmds.playbackOptions(q=True, max=True))
    done = 0
    for s in ("le", "ri"):
        elbow = _one("j_elbow_" + s)
        wrist = _one("j_wrist_" + s)
        chain = [_one("j_wristtwist%d_%s" % (i, s)) for i in range(1, NUM_TWIST + 1)]
        if not elbow or not wrist or None in chain:
            print("      %s: elbow / wrist / j_wristtwist1..%d not found - skipped" % (s, NUM_TWIST))
            continue
        # projection fraction along the forearm; pose-invariant, so read it once.
        ep = _pos(elbow)
        fwd = _pos(wrist) - ep
        flen2 = fwd * fwd
        fracs = [((_pos(tj) - ep) * fwd) / flen2 for tj in chain]
        for f in range(start, end + 1):
            cmds.currentTime(f, edit=True)
            tw = _twist_angle(wrist, TWIST_AXIS)
            for tj, fr in zip(chain, fracs):
                _set_twist(tj, TWIST_AXIS, tw * fr)
        done += 1
        print("      %s: twist by rest position, fracs [%s]"
              % (s, ", ".join("%.2f" % fr for fr in fracs)))
    return done


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
    print("\n== 3c. distribute wrist twist ==")
    if DISTRIBUTE_TWIST:
        distribute_wrist_twist()
    else:
        print("   skipped (DISTRIBUTE_TWIST = False)")
    print("\n== 4. strip prefix ==")
    clean = strip_prefix()
    print("\n== done ==  %s" % (
        "scrub to confirm, then export (Select > Hierarchy, check NUMPARTS 110)"
        if clean else "!! some bo3_* names remain - fix before exporting"))
