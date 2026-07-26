"""
MW3 viewhands  ->  BO3 viewhands : full retarget setup.

Run ONCE on a fresh scene containing BOTH rigs in bind pose and nothing else.
Load the animation AFTERWARDS, onto the MW3 rig.

Phases:
  1. sanity      - 67 joints under Joints, 110 under Joints1, no curves, no constraints
  2. co-locate   - slide the BO3 group so its tag_view sits exactly on MW3's tag_view
  3. prefix      - rename BO3 joints to bo3_* (the rigs share short names; without
                   this the Cast anim importer rejects every shared track with
                   "name conflict in the scene")
  4. constrain

WHY CO-LOCATE FIRST (this was a real bug): MW3 is rooted at tag_origin with
tag_view at Z=152.4; the BO3 root IS tag_view at Z=0. Constraining across that
gap with -mo bakes a ~150-unit offset into the constraint, and every rotation of
the source then swings the target through a huge arc - the arms fly off sideways.
After co-locating, tag_view / tag_ads / tag_cambone / tag_camera match to 0.00.

WHY EACH CONSTRAINT TYPE:
  parentConstraint - only where the residual offset is 0.00 (tag_view, tag_camera),
                     so there is no lever arm to swing. Carries the global travel
                     (tag_view moves 2075 units in X) and the exact camera path.
  pointConstraint  - the shoulders. MW3 drives the arms by TRANSLATING the
                     shoulders (140-164 units); tag_torso does not move at all
                     (measured amplitude 0.00). A pointConstraint offset is not
                     rotated by the source, so no lever arm.
  orientConstraint - everything else. Positions below the root must come from the
                     BO3 skeleton's own bone lengths: the two rigs' rest poses
                     genuinely differ (wrist residual 31.5 units after co-locating).

-mo EVERYWHERE because the bind axes differ by 40 deg (pinky) to 174 deg (right
metacarpals), median 54 deg. Without it every joint is twisted at rest.
=> BOTH RIGS MUST BE IN BIND WHEN THIS RUNS.
"""
import math
import maya.cmds as cmds
from maya.api import OpenMaya as om

PREALIGN = True         # match the source arm rest pose before constraining

SRC_ROOT = "Joints"     # source rig group (imported first)
DST_ROOT = "Joints1"    # BO3 target rig group (imported second)
PREFIX = "bo3_"

# expected joint counts, purely a "did I import the right files" guard.
# set either to None to skip the check when reusing on another rig pair.
EXPECT_SRC = 67         # MW3 viewhands
EXPECT_DST = 110        # BO3 c_zom_der_*_viewhands

PARENT_PAIRS = [
    ('tag_view', 'tag_view'),
    ('tag_camera', 'tag_camera'),
]

POINT_PAIRS = [
    ('j_shoulder_le', 'j_shoulder_le'),
    ('j_shoulder_ri', 'j_shoulder_ri'),
]

ORIENT_PAIRS = [
    ('tag_ads', 'tag_ads'),
    ('tag_cambone', 'tag_cambone'),
    ('tag_torso', 'tag_torso'),
]
for _s in ('le', 'ri'):
    ORIENT_PAIRS += [
        ('j_shoulder_%s' % _s, 'j_shoulder_%s' % _s),
        ('j_elbow_%s' % _s, 'j_elbow_%s' % _s),
        ('j_wrist_%s' % _s, 'j_wrist_%s' % _s),
        ('j_wristtwist_%s' % _s, 'j_wristtwist_%s' % _s),
        ('j_pinkypalm_%s' % _s, 'j_pinkybase_%s' % _s),
        ('j_ringpalm_%s' % _s, 'j_ringbase_%s' % _s),
    ]
    for _f in ('index', 'mid', 'ring', 'pinky', 'thumb'):
        for _i in (0, 1, 2):
            ORIENT_PAIRS.append(('j_%s_%s_%d' % (_f, _s, _i),
                                 'j_%s_%s_%d' % (_f, _s, _i + 1)))


def _resolve(short, root):
    hits = [p for p in (cmds.ls(short, long=True) or [])
            if p.startswith("|" + root + "|")]
    if len(hits) == 1:
        return hits[0]
    if not hits:
        return None
    print("   AMBIGUOUS: %s under %s (%d hits)" % (short, root, len(hits)))
    return hits[0]


def sanity():
    ok = True
    for root, want in ((SRC_ROOT, EXPECT_SRC), (DST_ROOT, EXPECT_DST)):
        if not cmds.objExists(root):
            print("   !! missing group: %s" % root)
            ok = False
            continue
        n = len(cmds.listRelatives(root, ad=True, type="joint", f=True) or [])
        if want is None:
            print("   %-8s %3d joints" % (root, n))
        else:
            print("   %-8s %3d joints (expected %d)%s"
                  % (root, n, want, "" if n == want else "   <-- MISMATCH"))
            if n != want:
                ok = False
        if n == 0:
            ok = False
    curves = len(cmds.ls(type="animCurveTA") or []) + len(cmds.ls(type="animCurveTL") or [])
    cons = len(cmds.ls(type="orientConstraint") or []) \
        + len(cmds.ls(type="parentConstraint") or []) \
        + len(cmds.ls(type="pointConstraint") or [])
    print("   anim curves: %d    constraints: %d" % (curves, cons))
    if curves or cons:
        print("   !! scene is not clean - re-open a fresh scene with the two rigs")
        ok = False
    return ok


def colocate():
    a = _resolve("tag_view", SRC_ROOT)
    b = _resolve("tag_view", DST_ROOT)
    if not a or not b:
        print("   !! tag_view not found on both rigs")
        return False
    pa = cmds.xform(a, q=True, ws=True, t=True)
    pb = cmds.xform(b, q=True, ws=True, t=True)
    d = [pa[i] - pb[i] for i in range(3)]
    cur = cmds.xform(DST_ROOT, q=True, ws=True, t=True)
    cmds.xform(DST_ROOT, ws=True, t=[cur[i] + d[i] for i in range(3)])
    pb2 = cmds.xform(b, q=True, ws=True, t=True)
    err = max(abs(pa[i] - pb2[i]) for i in range(3))
    print("   moved %s by (%.2f, %.2f, %.2f)   residual %.4f"
          % (DST_ROOT, d[0], d[1], d[2], err))
    return err < 0.01


def prefix_target():
    total = 0
    for _ in range(30):
        js = cmds.listRelatives(DST_ROOT, ad=True, f=True, type="joint") or []
        todo = [p for p in js if not p.split("|")[-1].startswith(PREFIX)]
        if not todo:
            break
        todo.sort(key=lambda s: s.count("|"), reverse=True)   # deepest first
        n = 0
        for p in todo:
            if not cmds.objExists(p):
                continue                    # stale path, next pass re-queries
            cmds.rename(p, PREFIX + p.split("|")[-1])
            n += 1
        total += n
        if n == 0:
            break
    print("   renamed %d joints -> %s*" % (total, PREFIX))
    return total


def probe(root=None):
    """Print a rig's hand chain so you can rebuild ORIENT_PAIRS for a new
    source game. Finger naming is NOT portable across CoD titles: MW3 uses
    j_<finger>_<side>_0/1/2 plus j_pinkypalm/j_ringpalm, while BO3 uses
    _1/2/3 plus j_pinkybase/j_ringbase. Run probe() before trusting the
    mapping on anything other than MW3.
        probe("Joints")     # source
        probe("Joints1")    # target
    """
    root = root or SRC_ROOT
    js = cmds.listRelatives(root, ad=True, type="joint", f=True) or []
    short = sorted(set(p.split("|")[-1] for p in js))
    hand = [n for n in short if any(k in n for k in
            ("index", "mid", "ring", "pinky", "thumb", "palm", "base",
             "wrist", "elbow", "shoulder", "webbing"))]
    tags = [n for n in short if n.startswith(PREFIX + "tag_") or n.startswith("tag_")]
    print("== %s : %d joints ==" % (root, len(js)))
    print("   tags : %s" % ", ".join(tags))
    print("   hand : %s" % ", ".join(hand))
    return short


def _pos(n):
    return om.MVector(*cmds.xform(n, q=True, ws=True, t=True))


def _basis(p0, p1, p2):
    """Orthonormal world frame: X along p0->p1, Z normal to the p0/p1/p2 plane."""
    x = (p1 - p0).normal()
    t = (p2 - p1).normal()
    z = (x ^ t).normal()
    y = (z ^ x).normal()
    return om.MMatrix([x.x, x.y, x.z, 0.0,
                       y.x, y.y, y.z, 0.0,
                       z.x, z.y, z.z, 0.0,
                       0.0, 0.0, 0.0, 1.0])


def _align_one(j_dst, trio_dst, trio_src):
    """Rotate j_dst in world so its (bone, plane) frame matches the MW3 one."""
    try:
        bd = _basis(*[_pos(n) for n in trio_dst])
        bs = _basis(*[_pos(n) for n in trio_src])
    except Exception as e:
        print("      skip %s (%s)" % (j_dst, e))
        return 0.0
    q = om.MTransformationMatrix(bd.inverse() * bs).rotation(asQuaternion=True)
    cur = om.MTransformationMatrix(
        om.MMatrix(cmds.xform(j_dst, q=True, ws=True, m=True))).rotation(asQuaternion=True)
    e = (cur * q).asEulerRotation()
    order = cmds.getAttr(j_dst + ".rotateOrder")
    e.reorderIt(order)
    cmds.xform(j_dst, ws=True, ro=[math.degrees(v) for v in (e.x, e.y, e.z)])
    return math.degrees(q.asAxisAngle()[1])


def prealign():
    """Match the BO3 arm rest pose to MW3's, so -mo only absorbs the axis
    convention and not the (large) rest-pose difference. Top-down per side."""
    moved = 0
    for s in ('le', 'ri'):
        chain = [
            ('j_shoulder_%s' % s,
             ('j_shoulder_%s' % s, 'j_elbow_%s' % s, 'j_wrist_%s' % s)),
            ('j_elbow_%s' % s,
             ('j_elbow_%s' % s, 'j_wrist_%s' % s, 'j_mid_%s_MID' % s)),
            ('j_wrist_%s' % s,
             ('j_wrist_%s' % s, 'j_mid_%s_MID' % s, 'j_index_%s_IDX' % s)),
        ]
        for joint, trio in chain:
            d = _resolve(PREFIX + joint, DST_ROOT)
            td = [_resolve(PREFIX + n.replace('_MID', '_1').replace('_IDX', '_1'),
                           DST_ROOT) for n in trio]
            ts = [_resolve(n.replace('_MID', '_0').replace('_IDX', '_0'),
                           SRC_ROOT) for n in trio]
            if not d or None in td or None in ts:
                print("      unresolved chain for %s" % joint)
                continue
            ang = _align_one(d, td, ts)
            print("      %-18s rotated %6.1f deg" % (joint, ang))
            moved += 1
    return moved


def constrain():
    missing = []
    for label, pairs, fn in (("parent", PARENT_PAIRS, cmds.parentConstraint),
                             ("point", POINT_PAIRS, cmds.pointConstraint),
                             ("orient", ORIENT_PAIRS, cmds.orientConstraint)):
        made = 0
        for src, dst in pairs:
            a = _resolve(src, SRC_ROOT)
            b = _resolve(PREFIX + dst, DST_ROOT)
            if not a or not b:
                missing.append("%s: %s -> %s" % (label, src, dst))
                continue
            fn(a, b, mo=True, w=1.0)
            made += 1
        print("   %-7s %d / %d" % (label, made, len(pairs)))
    if missing:
        print("   !! UNRESOLVED:")
        for m in missing:
            print("      " + m)
    return not missing


print("\n== 1. sanity ==")
if not sanity():
    print("\nABORTED - nothing was changed.")
else:
    print("\n== 2. co-locate ==")
    if not colocate():
        print("\nABORTED during co-locate.")
    else:
        print("\n== 3. prefix BO3 joints ==")
        prefix_target()
        if PREALIGN:
            print("\n== 3b. pre-align BO3 arms onto the MW3 rest pose ==")
            prealign()
        print("\n== 4. constraints ==")
        good = constrain()
        # CoD anims are 30fps; a 24fps scene lands every key on the wrong frame.
        # The playback RANGE is left alone on purpose - the Cast import extends
        # it to the clip's own length.
        cmds.currentUnit(time="ntsc")
        print("\n   scene fps -> ntsc (30)")
        print("\n== done ==  %s"
              % ("OK - now import the anim onto the MW3 rig"
                 if good else "unresolved pairs above"))
