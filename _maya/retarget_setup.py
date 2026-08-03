"""
MW3 viewhands  ->  BO3 viewhands : full retarget setup.

Run ONCE on a fresh scene containing BOTH rigs in bind pose and nothing else.
Load the animation AFTERWARDS, onto the MW3 rig.

BO3 TARGET RIG - READ THIS, it is the whole ballgame:
Retarget onto the rig the GAME ACTUALLY RENDERS, which for berlin_recovery is
    model_export/_reapy/rigs/mp_western_kyle_1_1_viewhands.xmodel_export
an MW2019 (iw8) viewhands port that OVERWRITES the c_zom_der_dempsey_viewhands
slot in game (recovery.gdt: the xanim's "model" field points at this kyle rig;
"previewModel" is dempsey, which is only the APE preview - not what ships).
Do NOT retarget onto the stock c_zom_der_dempsey_viewhands*.cast extracts: same
bone names, same 74 count, but a DIFFERENT bind pose (tag_cambone rest height in
particular). Anim authored against dempsey's bind but applied in game to kyle's
bind = "camera too high, perfect in Maya" - the bug we chased for hours. The
74-joint guard below CANNOT tell the two rigs apart (both are 74); it is on YOU to
import the kyle rig as Joints1. Verify after import: the tag_cambone/tag_camera
rest position must match what the game uses, not the stock dempsey extract.

Phases:
  1. sanity      - 67 joints under Joints, 74 under Joints1, no curves, no constraints
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
  pointConstraint  - the torso translation, plus (via anchor_arms) each shoulder,
                     anchored to a WEIGHTED blend of MW3's wrist and shoulder so the
                     shorter, rigid BO3 arm lands its wrist on MW3's. MW3's arms are
                     longer, so a 1:1 shoulder pin drifts the hand and a wrist pin
                     tears the arm (shoulder stops tracking MW3's arm translation).
                     tag_torso itself does not move (measured amplitude 0.00).
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
PREALIGN_FINGERS = True # also match the source finger BEND (not just the arm) - see prealign_fingers.
                        # Without it, orientConstraint -mo bakes BO3's curled rest as the finger baseline,
                        # so MW3's flat-hand moments render curled.

SRC_ROOT = "Joints"     # source rig group (imported first)
DST_ROOT = "Joints1"    # BO3 target rig group (imported second)
PREFIX = "bo3_"

# EXPERIMENT (reversible): also carry tag_torso's TRANSLATION, not just its
# rotation. Normally the torso's position is left to the BO3 rest pose (see the
# "WHY EACH CONSTRAINT TYPE" note) - harmless inside Maya because the wrists are
# world-pinned. BUT in game the anim binds to BO3's OWN base viewhands skeleton: if
# that skeleton's tag_torso sits at a non-zero offset, an exported torso translation
# stuck at rest can shift the viewmodel in game in a way Maya's live preview never
# shows. This flag pins the torso translation to the source so the export is
# unambiguous. Flip to False to restore the original orient-only torso.
MAP_TORSO_TRANSLATION = True

# For a VIEWMODEL you want the SOURCE's absolute framing, not the BO3 rest pose:
# the hands/weapon must sit where MW3 put them relative to the (already pixel-perfect)
# camera. With this on, the torso POSITION pin (if mapped) is created with mo=False,
# so BO3 snaps exactly onto MW3 instead of freezing the rest-pose gap that was
# shipping as an ugly offset in game. Rotations (orient) and the camera (parent) stay
# mo=True, untouched. The arms snap regardless, through anchor_arms (always mo=False).
# Off = the old proportion-preserving fit.
SNAP_ARMS_TO_SOURCE = True

# Anchor each BO3 shoulder onto MW3's shoulder->wrist line so the shorter, RIGID BO3 arm lands its wrist on
# MW3's - see anchor_arms(). This is how the arms are position-matched (the shoulders/wrists are NOT in
# POINT_PAIRS). Off = arms take positions from the BO3 rest pose (orient only), and the hand drifts.
ARM_ANCHOR = True

# expected joint counts, purely a "did I import the right files" guard.
# set either to None to skip the check when reusing on another rig pair.
EXPECT_SRC = 67         # MW3 viewhands
EXPECT_DST = 74         # mp_western_kyle_1_1_viewhands (the in-game rig). NOTE: stock dempsey extract is also 74 - this guard can't distinguish them, import the KYLE rig.

PARENT_PAIRS = [
    ('tag_view', 'tag_view'),
    ('tag_camera', 'tag_camera'),
    # tag_cambone is the bone BO3 actually anchors the viewmodel CAMERA to in game
    # (tag_camera drives the Maya preview, but the engine reads tag_cambone). It must
    # be POSITION-driven, not orient-only, or the in-game camera sits at the BO3 rest
    # height while Maya (through tag_camera) looks fine -> "camera too high in game".
    # Safe as a parentConstraint: it matches to 0.00 after co-locate (see header), so
    # no lever arm.
    ('tag_cambone', 'tag_cambone'),
]

# The ARMS are NOT pinned 1:1 here - see anchor_arms() / ARM_ANCHOR. MW3's arms are LONGER than BO3's, so
# no single 1:1 pin works: pin the shoulder and the hand drifts short by the length gap; pin the wrist and
# the arm tears (the shoulder, orient only, stops following MW3's arm-driving translation and the forearm
# stretches to span the gap -> mesh deform). anchor_arms places the shoulder on the MW3 arm-line instead,
# so the rigid BO3 arm reaches the wrist with nothing stretched. Only the torso translation is a plain pin.
POINT_PAIRS = []
if MAP_TORSO_TRANSLATION:
    # point (not parent): translation only, so the torso's own rotation can't swing
    # a lever arm. tag_torso stays in ORIENT_PAIRS too, so its rotation is still driven.
    POINT_PAIRS.append(('tag_torso', 'tag_torso'))

ORIENT_PAIRS = [
    ('tag_ads', 'tag_ads'),
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


def _aim_dir(j_dst, child_dst, j_src, child_src):
    """Rotate j_dst by the minimal WORLD swing that points its bone (j_dst->child_dst)
    along the source bone (j_src->child_src). Only the bone DIRECTION is matched; the
    roll around it is left untouched, so orientConstraint -mo keeps BO3's own twist and
    only the bend baseline changes. (Finger joints are near-collinear, so the plane-based
    _align_one is degenerate on them - a pure direction swing is the robust choice.)"""
    dcur = (_pos(child_dst) - _pos(j_dst)).normal()
    dtgt = (_pos(child_src) - _pos(j_src)).normal()
    q = om.MQuaternion(dcur, dtgt)
    cur = om.MTransformationMatrix(
        om.MMatrix(cmds.xform(j_dst, q=True, ws=True, m=True))).rotation(asQuaternion=True)
    e = (cur * q).asEulerRotation()
    order = cmds.getAttr(j_dst + ".rotateOrder")
    e.reorderIt(order)
    cmds.xform(j_dst, ws=True, ro=[math.degrees(v) for v in (e.x, e.y, e.z)])
    return math.degrees(q.asAxisAngle()[1])


def prealign_fingers():
    """Match each BO3 finger's rest BEND to MW3's, so orientConstraint -mo absorbs only
    the roll/axis convention and not the (curled-vs-flat) rest-pose gap. MW3 joints are
    _0/1/2, BO3 are _1/2/3, so BO3 i is driven by MW3 i-1 (see ORIENT_PAIRS). Aim the two
    proximal joints (each has a child bone to point); the distal tip has no child joint,
    so it is left to -mo. Top-down, so a parent's new pose is baked before its child aligns."""
    fingers = ('index', 'mid', 'ring', 'pinky', 'thumb')
    moved = 0
    for s in ('le', 'ri'):
        for f in fingers:
            for i in (1, 2):
                jd = _resolve(PREFIX + 'j_%s_%s_%d' % (f, s, i), DST_ROOT)
                cd = _resolve(PREFIX + 'j_%s_%s_%d' % (f, s, i + 1), DST_ROOT)
                js = _resolve('j_%s_%s_%d' % (f, s, i - 1), SRC_ROOT)
                cs = _resolve('j_%s_%s_%d' % (f, s, i), SRC_ROOT)
                if not (jd and cd and js and cs):
                    continue
                _aim_dir(jd, cd, js, cs)
                moved += 1
    print("      aimed %d finger joints (bend only; roll left to -mo)" % moved)
    return moved


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
    point_mo = not SNAP_ARMS_TO_SOURCE   # False = snap BO3 exactly onto the source
    missing = []
    for label, pairs, fn, mo in (
            ("parent", PARENT_PAIRS, cmds.parentConstraint, True),
            ("point",  POINT_PAIRS,  cmds.pointConstraint,  point_mo),
            ("orient", ORIENT_PAIRS, cmds.orientConstraint, True)):
        made = 0
        for src, dst in pairs:
            a = _resolve(src, SRC_ROOT)
            b = _resolve(PREFIX + dst, DST_ROOT)
            if not a or not b:
                missing.append("%s: %s -> %s" % (label, src, dst))
                continue
            fn(a, b, mo=mo, w=1.0)
            made += 1
        print("   %-7s %d / %d%s" % (label, made, len(pairs),
                                     "" if mo else "   (snap, mo=off)"))
    if missing:
        print("   !! UNRESOLVED:")
        for m in missing:
            print("      " + m)
    return not missing


def anchor_arms():
    """Place each BO3 shoulder so the rigid BO3 arm's WRIST reaches MW3's wrist.

    MW3's arms are LONGER than BO3's, so no 1:1 pin works: pin the shoulder and the
    hand drifts short by the length gap; pin the wrist and the arm tears, because the
    shoulder (orient only) stops following MW3's arm-driving TRANSLATION and the
    forearm stretches to span the gap. Instead, point-constrain the shoulder to a
    WEIGHTED blend of MW3's wrist and shoulder - weight (1-r) on the wrist, r on the
    shoulder, r = BO3 arm length / MW3 arm length (straight shoulder->wrist at bind).
    That drops the shoulder ONTO the MW3 arm line at exactly BO3-arm distance from the
    wrist, so the rigid BO3 arm (orient-driven, its own bone lengths) lands the wrist
    on MW3. Exact at bind (prealign makes the BO3 arm parallel to MW3's) and for
    proportional arms; only a small residual when the elbow bends and the two rigs
    foreshorten differently. The shoulder rides off-screen; nothing stretches, so the
    mesh never deforms. The shoulder stays in ORIENT_PAIRS, so its rotation is driven."""
    made = 0
    for s in ('le', 'ri'):
        sh_s = _resolve('j_shoulder_%s' % s, SRC_ROOT)
        wr_s = _resolve('j_wrist_%s' % s, SRC_ROOT)
        sh_d = _resolve(PREFIX + 'j_shoulder_%s' % s, DST_ROOT)
        wr_d = _resolve(PREFIX + 'j_wrist_%s' % s, DST_ROOT)
        if not (sh_s and wr_s and sh_d and wr_d):
            print("      %s: shoulder / wrist unresolved - skipped" % s)
            continue
        arm_src = (_pos(wr_s) - _pos(sh_s)).length()
        arm_dst = (_pos(wr_d) - _pos(sh_d)).length()
        if arm_src < 1e-4:
            print("      %s: zero-length source arm - skipped" % s)
            continue
        r = arm_dst / arm_src
        c = cmds.pointConstraint(wr_s, sh_s, sh_d, mo=False)[0]
        wl = cmds.pointConstraint(c, q=True, weightAliasList=True)   # order = [wrist, shoulder]
        cmds.setAttr(c + "." + wl[0], 1.0 - r)   # MW3 wrist
        cmds.setAttr(c + "." + wl[1], r)         # MW3 shoulder
        print("      %-2s  arm src %.2f  dst %.2f  ratio %.3f  ->  wrist weight %.3f"
              % (s, arm_src, arm_dst, r, 1.0 - r))
        made += 1
    return made


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
            if PREALIGN_FINGERS:
                print("\n== 3b2. pre-align BO3 finger bend ==")
                prealign_fingers()
        print("\n== 4. constraints ==")
        good = constrain()
        if ARM_ANCHOR:
            print("\n== 4b. anchor arms (shoulder onto MW3 arm-line so the wrist lands) ==")
            anchor_arms()
        # CoD anims are 30fps; a 24fps scene lands every key on the wrong frame.
        # The playback RANGE is left alone on purpose - the Cast import extends
        # it to the clip's own length.
        cmds.currentUnit(time="ntsc")
        print("\n   scene fps -> ntsc (30)")
        print("\n== done ==  %s"
              % ("OK - now import the anim onto the MW3 rig"
                 if good else "unresolved pairs above"))
