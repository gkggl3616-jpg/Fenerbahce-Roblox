"""
Üretilen iskeletli futbolcu modelini (assets/modeller/oyuncu_rig.glb) Roblox R15 karakterine
uygun parçalara dönüştürür.

Yaptıkları:
  1. Kolları iskelet ve deri ağırlıklarıyla T-pozdan aşağı indirir (R15 dinlenme pozu).
  2. Modeli -Z yönüne bakacak, ayakları y=0'da ve boyu HEIGHT stud olacak biçimde yerleştirir.
  3. Her üçgeni kemik ağırlıklarına göre 15 R15 parçasından birine verir.
  4. Giysi bölgelerini temiz düzlem kesimleriyle ayırır: forma, kol, yaka ve kol ağzı şeridi,
     şort, tozluk ve bandı, krampon, ten ve saç. Çubuklu ve kuşaklı desenleri de ayrı
     parçalar olarak keser.
  5. Çıktılar:
     - assets/modeller/FK_Oyuncu.glb: Studio'da 3D Importer ile içe aktarılacak parçalar.
       Düğüm adı "<R15 parçası>__<rol>[__<desen>]"; ayrıca FK_Origin, FK_AxisX, FK_AxisY
       işaretleri.
     - src/ReplicatedStorage/Shared/MeshRig.luau: iskelet (parça merkezleri ve ölçüleri,
       eklem noktaları, kalça yüksekliği, baskı yerleri).
     - assets/modeller/FK_Oyuncu_onizleme.glb: renkli önizleme (yalnız görüntü için).

Çalıştırma:  python tools/meshgen/oyuncu_r15.py
Gerekenler:  numpy, trimesh, pygltflib
"""

import json
import math
import os
import sys

import numpy as np
import pygltflib
import trimesh
import fast_simplification
from trimesh.intersections import slice_mesh_plane

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "modeller", "oyuncu_rig.glb")
OUT_GLB = os.path.join(ROOT, "assets", "modeller", "FK_Oyuncu.glb")
OUT_PREVIEW = os.path.join(ROOT, "assets", "modeller", "FK_Oyuncu_onizleme.glb")
OUT_LUAU = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "MeshRig.luau")

HEIGHT = 5.3  # stud; eski gövdeyle aynı boy, oynanış yükseklikleri değişmesin
ARM_OUT = 0.07  # kolların aşağı inerken dışa açıklığı (eğim); küçük: kollar gövdeye yakın


# ---------------------------------------------------------------- glTF okuma
def load(path):
    g = pygltflib.GLTF2().load(path)
    blob = g.binary_blob()

    def acc(i):
        a = g.accessors[i]
        bv = g.bufferViews[a.bufferView]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a.type]
        dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[a.componentType]
        off = (bv.byteOffset or 0) + (a.byteOffset or 0)
        size = np.dtype(dt).itemsize
        if bv.byteStride and bv.byteStride != n * size:
            raw = np.frombuffer(blob, dtype=np.uint8, count=bv.byteStride * a.count, offset=off)
            raw = raw.reshape(a.count, bv.byteStride)[:, : n * size].copy()
            return raw.view(dt).reshape(a.count, n)
        return np.frombuffer(blob, dtype=dt, count=a.count * n, offset=off).reshape(a.count, n).copy()

    return g, acc


def trs(node):
    m = np.eye(4)
    if node.matrix:
        return np.array(node.matrix, dtype=float).reshape(4, 4).T
    t = node.translation or [0, 0, 0]
    r = node.rotation or [0, 0, 0, 1]
    s = node.scale or [1, 1, 1]
    x, y, z, w = r
    R = np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )
    m[:3, :3] = R * np.array(s)
    m[:3, 3] = t
    return m


def rot_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))


# ---------------------------------------------------------------- 1. poz ve yerleşim
# Otomatik iskelet (oyuncu_rig.glb) kollarda tutarsız çıktığı için iskelet, ham modelin kendi
# genişlik profilinden ölçülür. Ham model: yükseklik 1 birim (y -0.5..0.5), yüz +X, yanlar Z.
raw = trimesh.load(os.path.join(ROOT, "assets", "modeller", "oyuncu_ham.glb")).to_geometry()
V = raw.vertices.copy()
F = raw.faces.copy()
V[:, 1] -= V[:, 1].min()
V /= V[:, 1].max()  # boy = 1 (normalize)

Y_SHOULDER = 0.733  # kol ekseni (T-poz)
TWIST = math.radians(-90)  # ön kol ve el dönmesi (avuç öne → avuç uyluğa)
Z_SHOULDER = 0.136  # omuz ekleminin yanal yeri (koltuk altı + kol yarıçapı)
Y_NECK = 0.845
Y_WAIST = 0.600
Y_HIP_CUT = 0.470  # gövde / bacak kesimi (kasık)
Y_HIP = 0.500
Y_KNEE = 0.285
Y_ANKLE_CUT = 0.072
Y_ANKLE = 0.060

# kollar: omuz eklemi etrafında, derinlik ekseni (X) çevresinde döner. Ağırlık omuzda yumuşak
# artar; açı ağırlıkla ölçeklenir (doğrusal karışımın hacim kaybı olmaz).
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


az = np.abs(V[:, 2])
# dar geçiş: omuz eklemi çevresinde; geniş geçiş omuzda yana taşan bir "raf" bırakıyordu
w_arm = smooth(Z_SHOULDER - 0.012, Z_SHOULDER + 0.03, az) * (V[:, 1] > 0.655)
target_angle = math.atan2(1.0, ARM_OUT)  # yataydan aşağı açı (rad)
P0 = V.copy()
for sgn in (-1, 1):
    sel = (np.sign(V[:, 2]) == sgn) & (w_arm > 0)
    piv = np.array([0.0, Y_SHOULDER, sgn * Z_SHOULDER])
    d = P0[sel] - piv
    th = sgn * target_angle * w_arm[sel]  # +Z kolu için pozitif açı kolu aşağı indirir
    c, s_ = np.cos(th), np.sin(th)
    # X ekseni çevresinde dönme: y' = y c - z s, z' = y s + z c
    y2 = d[:, 1] * c - d[:, 2] * s_
    z2 = d[:, 1] * s_ + d[:, 2] * c
    V[sel, 1] = piv[1] + y2
    V[sel, 2] = piv[2] + z2
# doğrulama: kol ucu artık omuzun altında olmalı
tip = V[np.argmax(az)]
assert tip[1] < Y_SHOULDER - 0.2, ("kollar inmedi", tip)

# omuz başı: kol inince üst kolun tepesi kubbe gibi kabarıyordu. Kolun üst üçte birindeki
# köşeler kol eksenine doğru toplanır (tepede %SHOULDER_SLIM, aşağı indikçe sıfıra).
SHOULDER_SLIM = 0.18
for sgn in (-1, 1):
    piv = np.array([0.0, Y_SHOULDER, sgn * Z_SHOULDER])
    u = np.array([0.0, -1.0, sgn * ARM_OUT])
    u /= np.linalg.norm(u)
    sel = (np.sign(V[:, 2]) == sgn) & (w_arm > 0.05)
    d = V[sel] - piv
    t = d @ u
    L = t.max()
    f = 1 - SHOULDER_SLIM * (1 - smooth(-0.02, 0.33 * L, t)) * w_arm[sel]
    along = np.outer(t, u)
    V[sel] = piv + along + (d - along) * f[:, None]

# avuçlar: T-pozda öne bakıyordu; kol indikten sonra ön kol ve el, kol ekseni çevresinde 90°
# döndürülür (avuç uyluğa bakar, başparmak öne). Dönme dirsekten bileğe artar, elde tamdır.
for sgn in (-1, 1):
    piv = np.array([0.0, Y_SHOULDER, sgn * Z_SHOULDER])
    u = np.array([0.0, -1.0, sgn * ARM_OUT])
    u /= np.linalg.norm(u)
    sel = (np.sign(V[:, 2]) == sgn) & (w_arm > 0.5)
    t = (V[sel] - piv) @ u
    L = t.max()
    tw = smooth(0.45 * L, 0.78 * L, t)  # dirsekten bileğe
    ang = sgn * TWIST * tw
    d = V[sel] - piv
    along = np.outer(d @ u, u)
    perp = d - along
    # u ekseni çevresinde Rodrigues dönmesi
    c, s_ = np.cos(ang)[:, None], np.sin(ang)[:, None]
    rot = perp * c + np.cross(u, perp) * s_
    V[sel] = piv + along + rot

# Gerçek insan oranı: kollar dahil omuz genişliği boyun ~%29'u olmalı (model %41'di).
# Kollar kendi eksenleri çevresinde inceltilir ve gövdeye yaklaştırılır; gövde biraz daraltılır.
ARM_THIN, ARM_IN = 0.84, 0.017
TORSO_W, TORSO_D = 0.92, 0.9
for sgn in (-1, 1):
    piv = np.array([0.0, Y_SHOULDER, sgn * Z_SHOULDER])
    u = np.array([0.0, -1.0, sgn * ARM_OUT])
    u /= np.linalg.norm(u)
    sel = (np.sign(V[:, 2]) == sgn) & (w_arm > 0.05)
    w = w_arm[sel][:, None]
    d = V[sel] - piv
    along = np.outer(d @ u, u)
    perp = d - along
    newp = piv + along + perp * (1 - (1 - ARM_THIN) * w)
    newp[:, 2] -= sgn * ARM_IN * w[:, 0]
    V[sel] = newp
body_w = (1 - w_arm) * smooth(0.44, 0.52, V[:, 1]) * (1 - smooth(0.80, 0.86, V[:, 1]))
V[:, 2] *= 1 - (1 - TORSO_W) * body_w
V[:, 0] *= 1 - (1 - TORSO_D) * body_w
Z_SHOULDER_P = Z_SHOULDER - ARM_IN  # inceltme sonrası omuz ekleminin yanal yeri

# ham → Roblox: ileri +X → -Z, sağ +Z → +X (karakterin sağı)
def to_rb(a):
    a = np.atleast_2d(a)
    return np.c_[a[:, 2], a[:, 1], -a[:, 0]] * HEIGHT


arm_mask = w_arm > 0.5
Vr = to_rb(V)

# eklemler (ham, normalize)
def leg_center(y, sgn):
    s_ = (np.abs(V[:, 1] - y) < 0.01) & (np.sign(V[:, 2]) == sgn) & ~arm_mask
    return V[s_].mean(0)


def arm_axis(sgn):
    sel = arm_mask & (np.sign(V[:, 2]) == sgn)
    pts = V[sel]
    piv = np.array([0.0, Y_SHOULDER, sgn * Z_SHOULDER_P])
    u = np.array([0.0, -1.0, sgn * ARM_OUT])
    u /= np.linalg.norm(u)
    t = (pts - piv) @ u
    L = t.max()
    return piv, u, L, t, sel


J = {}
for sgn in (-1, 1):
    side = "Right" if sgn > 0 else "Left"  # Roblox: +X karakterin sağı (ham +Z)
    piv, u, L, t, sel = arm_axis(sgn)
    # bilek: kolun en ince yeri (uzunluğun %62-%85'i arasında)
    pts = V[sel]
    best, wrist_t = 1e9, 0.76 * L
    for tt in np.linspace(0.62 * L, 0.85 * L, 24):
        ring = pts[np.abs(t - tt) < 0.006]
        if len(ring) < 6:
            continue
        rad = np.percentile(np.linalg.norm(np.cross(ring - piv, u), axis=1), 80)
        if rad < best:
            best, wrist_t = rad, tt
    elbow_t = wrist_t * 0.55
    J[side + "Arm"] = piv
    J[side + "ForeArm"] = piv + u * elbow_t
    J[side + "Hand"] = piv + u * wrist_t
    J[side + "_armlen"] = L
    hc = leg_center(0.42, sgn)
    kc = leg_center(Y_KNEE, sgn)
    ac = leg_center(0.12, sgn)
    J[side + "UpLeg"] = np.array([0.0, Y_HIP, hc[2]])
    J[side + "Leg"] = np.array([kc[0], Y_KNEE, kc[2]])
    J[side + "Foot"] = np.array([ac[0], Y_ANKLE, ac[2]])
J["Hips"] = np.array([0.0, 0.52, 0.0])
J["Spine01"] = np.array([0.0, Y_WAIST, 0.0])
J["Spine"] = np.array([0.0, 0.70, 0.0])
J["neck"] = np.array([0.0, Y_NECK, 0.0])

# parça ataması (ham koordinatlarda), sonra Roblox uzayına
def vertex_part():
    out = np.empty(len(V), dtype=object)
    for i, (p, a_, y) in enumerate(zip(V, arm_mask, V[:, 1])):
        pass
    return out


vp = np.full(len(V), "", dtype=object)
for sgn in (-1, 1):
    side = "Right" if sgn > 0 else "Left"
    piv, u, L, t, sel = arm_axis(sgn)
    tt = (V - piv) @ u
    e = (J[side + "ForeArm"] - piv) @ u
    w = (J[side + "Hand"] - piv) @ u
    m = arm_mask & (np.sign(V[:, 2]) == sgn)
    vp[m & (tt < e)] = side + "UpperArm"
    vp[m & (tt >= e) & (tt < w)] = side + "LowerArm"
    vp[m & (tt >= w)] = side + "Hand"
    leg = ~arm_mask & (V[:, 1] < Y_HIP_CUT) & (np.sign(V[:, 2] + 1e-9) == sgn)
    vp[leg & (V[:, 1] >= Y_KNEE)] = side + "UpperLeg"
    vp[leg & (V[:, 1] < Y_KNEE) & (V[:, 1] >= Y_ANKLE_CUT)] = side + "LowerLeg"
    vp[leg & (V[:, 1] < Y_ANKLE_CUT)] = side + "Foot"
body = ~arm_mask
vp[body & (V[:, 1] >= Y_NECK)] = "Head"
vp[body & (V[:, 1] >= Y_WAIST) & (V[:, 1] < Y_NECK)] = "UpperTorso"
vp[body & (V[:, 1] >= Y_HIP_CUT) & (V[:, 1] < Y_WAIST)] = "LowerTorso"
assert (vp != "").all(), "atanmamış köşe"

# Eller: kollar gövdeye yaklaşınca eller bol şortun içine giriyordu. Dirsek hafifçe bükülür
# (ön kol dışa ve öne açılır), el bilekten biraz büyütülür, şort kalçada biraz daraltılır.
ELBOW_OUT, ELBOW_FWD, HAND_SCALE = math.radians(7), math.radians(11), 1.1


def rot_x(a):
    c, s_ = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s_], [0, s_, c]])


def rot_z(a):
    c, s_ = math.cos(a), math.sin(a)
    return np.array([[c, -s_, 0], [s_, c, 0], [0, 0, 1]])


for sgn in (-1, 1):
    side = "Right" if sgn > 0 else "Left"
    el = J[side + "ForeArm"].copy()
    wr = J[side + "Hand"].copy()
    # dışa açılma (X ekseni çevresinde; yönü işaretle seçilir) ve öne bükülme (Z ekseni çevresinde)
    R = rot_z(ELBOW_FWD) @ rot_x(-sgn * ELBOW_OUT)
    test = R @ np.array([0.0, -1.0, 0.0])
    if np.sign(test[2]) != sgn:
        R = rot_z(ELBOW_FWD) @ rot_x(sgn * ELBOW_OUT)
    sel = np.isin(vp, [side + "LowerArm", side + "Hand"])
    # dirsekte yumuşak geçiş: dirsek ekleminin hemen altındaki köşeler kısmen döner
    piv_s = np.array([0.0, Y_SHOULDER, sgn * Z_SHOULDER_P])
    ua = (el - piv_s) / np.linalg.norm(el - piv_s)
    tt = (V - el) @ ua
    w = smooth(-0.004, 0.02, tt) * (np.isin(vp, [side + "UpperArm", side + "LowerArm", side + "Hand"]))
    w[sel] = np.maximum(w[sel], smooth(-0.004, 0.02, tt[sel]))
    moving = w > 0
    d = V[moving] - el
    rotated = d @ R.T
    V[moving] = el + d + (rotated - d) * w[moving][:, None]
    wr2 = el + (wr - el) @ R.T
    hand = vp == side + "Hand"
    V[hand] = wr2 + (V[hand] - wr2) * HAND_SCALE
    J[side + "Hand"] = wr2
# şort: kalça ve uyluk üstünde yanlara %7 dar (gövde merkezine göre, kesintisiz alan)
legs = ~arm_mask
shrink = 1 - 0.07 * smooth(0.30, 0.36, V[:, 1]) * (1 - smooth(0.50, 0.56, V[:, 1]))
V[legs, 2] *= shrink[legs]
Vr = to_rb(V)

V = Vr
joint_pos = {k: to_rb(v)[0] for k, v in J.items() if not k.endswith("_armlen")}

# ---------------------------------------------------------------- 2. R15 parçaları
PARTS = [
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
]  # fmt: skip
PI = {p: i for i, p in enumerate(PARTS)}
vpi = np.array([PI[p] for p in vp])
tri_parts = vpi[F]  # üçgenin köşelerinin parçaları
primary = np.array([np.bincount(r, minlength=len(PARTS)).argmax() for r in tri_parts])


def side_of(bone):
    return "Right" if joint_pos[bone][0] > 0 else "Left"


tri_sets = {}
for p in PARTS:
    i = PI[p]
    # köşelerinden biri bu parçadaysa üçgen bu parçaya da girer: eklemde hafif örtüşme
    tri_sets[p] = np.where((tri_parts == i).any(1))[0]


def submesh(tris):
    m = trimesh.Trimesh(V, F[tris], process=False)
    m.remove_unreferenced_vertices()
    return m


part_mesh = {p: submesh(tri_sets[p]) for p in PARTS}
center = {p: submesh(np.where(primary == PI[p])[0]).bounds.mean(0) for p in PARTS}
print("parça üçgenleri:", {p: len(tri_sets[p]) for p in PARTS})

# ---------------------------------------------------------------- 3. bölge kesimleri
def cut(m, normal, origin):
    """m'yi düzlemle ikiye böler: (normalin önü, arkası)."""
    n = np.asarray(normal, float)
    o = np.asarray(origin, float)
    a = slice_mesh_plane(m, n, o) if len(m.faces) else m
    b = slice_mesh_plane(m, -n, o) if len(m.faces) else m
    return a, b


def profile_step(m, a, b, lo, hi, want="drop"):
    """a→b ekseninde yarıçap profilinde en büyük düşüşün (ya da artışın) t değerini bulur."""
    ax = b - a
    L = np.linalg.norm(ax)
    u = ax / L
    d = m.vertices - a
    t = d @ u / L
    r = np.linalg.norm(d - np.outer(d @ u, u), axis=1)
    bins = np.linspace(lo, hi, 33)
    prof = []
    for i in range(len(bins) - 1):
        sel = (t >= bins[i]) & (t < bins[i + 1])
        prof.append(np.percentile(r[sel], 85) if sel.sum() > 3 else np.nan)
    prof = np.array(prof)
    diff = np.diff(prof)
    diff = np.nan_to_num(diff, nan=0)
    i = int(np.argmin(diff) if want == "drop" else np.argmax(diff))
    return (bins[i + 1] + bins[i + 2]) / 2, L, u


pieces = []  # (parça, rol, desen ya da None, mesh)


def add(p, role, m, pattern=None):
    if m is not None and len(m.faces) > 0:
        pieces.append((p, role, pattern, m))


J = joint_pos
landmarks = {}
up = np.array([0.0, 1.0, 0.0])
# önce iki yanın ölçüsü alınır, ortalaması ikisine de uygulanır (model simetrik)
def mean_t(kind):
    vals = []
    for sb in ("Left", "Right"):
        if kind == "sleeve":
            sd = side_of(sb + "Arm")
            vals.append(profile_step(part_mesh[sd + "UpperArm"], J[sb + "Arm"], J[sb + "ForeArm"], 0.15, 0.95, "drop")[0])
        elif kind == "shorts":
            sd = side_of(sb + "UpLeg")
            vals.append(profile_step(part_mesh[sd + "UpperLeg"], J[sb + "UpLeg"], J[sb + "Leg"], 0.25, 1.0, "drop")[0])
        else:
            sd = side_of(sb + "UpLeg")
            vals.append(profile_step(part_mesh[sd + "LowerLeg"], J[sb + "Leg"], J[sb + "Foot"], 0.02, 0.32, "rise")[0])
    print(kind, [round(v, 3) for v in vals])
    return float(min(vals)) if kind == "sleeve" else float(np.mean(vals))
T_SLEEVE, T_SHORTS, T_SOCK = mean_t("sleeve"), mean_t("shorts"), mean_t("sock")
for side_bone in ("Left", "Right"):
    sd = side_of(side_bone + "Arm")
    # üst kol: kol (forma) / kol ağzı şeridi / ten
    a, b = J[side_bone + "Arm"], J[side_bone + "ForeArm"]
    m = part_mesh[sd + "UpperArm"]
    _, L, u = profile_step(m, a, b, 0.15, 0.95, "drop")
    t = T_SLEEVE
    hem = a + u * L * t
    sleeve, rest = cut(m, -u, hem)
    cuff_top = hem - u * 0.07 * L
    sleeve_main, cuff = cut(sleeve, -u, cuff_top)
    add(sd + "UpperArm", "Sleeve", sleeve_main)
    add(sd + "UpperArm", "Trim", cuff)
    add(sd + "UpperArm", "Skin", rest)
    add(sd + "LowerArm", "Skin", part_mesh[sd + "LowerArm"])
    add(sd + "Hand", "Skin", part_mesh[sd + "Hand"])
    landmarks[sd + "SleeveT"] = float(t)

    sd = side_of(side_bone + "UpLeg")
    # uyluk: şort / şort ağzı / ten
    a, b = J[side_bone + "UpLeg"], J[side_bone + "Leg"]
    m = part_mesh[sd + "UpperLeg"]
    _, L, u = profile_step(m, a, b, 0.25, 1.0, "drop")
    t = T_SHORTS
    hem = a + u * L * t
    shorts, rest = cut(m, -u, hem)
    band_top = hem - u * 0.05 * L
    shorts_main, band = cut(shorts, -u, band_top)
    add(sd + "UpperLeg", "Shorts", shorts_main)
    add(sd + "UpperLeg", "Trim", band)
    add(sd + "UpperLeg", "Skin", rest)
    landmarks[sd + "ShortsT"] = float(t)
    # baldır: ten (diz) / tozluk bandı / tozluk
    a, b = J[side_bone + "Leg"], J[side_bone + "Foot"]
    m = part_mesh[sd + "LowerLeg"]
    _, L, u = profile_step(m, a, b, 0.05, 0.6, "rise")
    t = T_SOCK
    top = a + u * L * t
    knee, sock = cut(m, -u, top)
    band_bot = top + u * 0.08 * L
    band, sock_main = cut(sock, -u, band_bot)
    add(sd + "LowerLeg", "Skin", knee)
    add(sd + "LowerLeg", "Trim", band, None)
    # tozluk: üst yarı (kısa tozlukta tekmelik görünür), orta bant, alt yarı
    mid = top + u * 0.45 * L
    sock_top, sock_rest = cut(sock_main, -u, mid)
    sband, sock_low = cut(sock_rest, -u, mid + u * 0.06 * L)
    add(sd + "LowerLeg", "SockTop", sock_top)
    add(sd + "LowerLeg", "SockBand", sband)
    add(sd + "LowerLeg", "Sock", sock_low)
    landmarks[sd + "SockT"] = float(t)
    fm = part_mesh[sd + "Foot"]
    fy0, fy1 = fm.bounds[0][1], fm.bounds[1][1]
    sole, upper = cut(fm, -up, [0, fy0 + 0.085, 0])
    collar, upper = cut(upper, up, [0, fy1 - 0.07, 0])
    add(sd + "Foot", "BootSole", sole)
    add(sd + "Foot", "BootCollar", collar)
    add(sd + "Foot", "Boot", upper)

# alt gövde: forma ucu / şort (en büyük yarıçap düşüşü)
up = np.array([0.0, 1.0, 0.0])
lt = part_mesh["LowerTorso"]
y0, y1 = lt.bounds[0][1], lt.bounds[1][1]
t, L, u = profile_step(lt, np.array([0, y1, 0.0]), np.array([0, y0, 0.0]), 0.05, 0.9, "drop")
shirt_hem_y = y1 - t * (y1 - y0)
lt_shirt, lt_shorts = cut(lt, up, [0, shirt_hem_y, 0])
add("LowerTorso", "Shorts", lt_shorts)
# üst gövde: boyun (ten) / yaka şeridi / forma. Boyun, boyun ekseninin yakınındaki ve yaka
# çizgisinin üstündeki üçgenlerdir (düz kesim omuzları da keserdi).
neck_c = J["neck"]
collar_top = neck_c[1] - 0.06
# yalnız boyun çevresindeki üçgenler inceltilir (bütün gövdeyi inceltmek üçgen sayısını patlatır)
ut = part_mesh["UpperTorso"]
for _ in range(1):  # yalnız yaka sınırlarının çevresindeki dar halka inceltilir (tırtık küçülür)
    cc = ut.triangles_center
    rr = np.hypot(cc[:, 0] - neck_c[0], (cc[:, 2] - neck_c[2]) * 1.15)
    near = ((np.abs(cc[:, 1] - collar_top) < 0.06) | (np.abs(cc[:, 1] - (collar_top - 0.09)) < 0.06)) & (rr < 0.48)
    near |= (np.abs(rr - 0.34) < 0.05) & (cc[:, 1] > collar_top - 0.04)
    near |= (np.abs(rr - 0.42) < 0.05) & (cc[:, 1] > collar_top - 0.13)
    ut = ut.subdivide(face_index=np.where(near)[0])
cen = ut.triangles_center
rad = np.hypot(cen[:, 0] - neck_c[0], (cen[:, 2] - neck_c[2]) * 1.15)
is_neck = (cen[:, 1] > collar_top) & (rad < 0.34)
is_collar = ~is_neck & (cen[:, 1] > collar_top - 0.09) & (rad < 0.42)  # bisiklet yaka: boynu saran dar halka
def take(m, mask):
    if not mask.any():
        return None
    out = m.submesh([np.where(mask)[0]], append=True)
    return out
add("UpperTorso", "Skin", take(ut, is_neck))
add("UpperTorso", "Trim", take(ut, is_collar))
ut_shirt = take(ut, ~is_neck & ~is_collar)

# forma desenleri (üst ve alt gövdedeki forma için)
# omuz dikişi: gövde formasının omuz başına taşan yanları kol (Sleeve) rengini alır; düz düzlem
# kesimi temiz bir dikiş çizgisi verir (kol rengi formadan farklı olduğunda görünür)
chest_y = J["Spine"][1]
low = ut_shirt.vertices[np.abs(ut_shirt.vertices[:, 1] - (chest_y - 0.35)) < 0.15][:, 0]
seam_x = float(np.percentile(np.abs(low), 97)) + 0.02  # koltuk altı hizasında gövdenin yarı genişliği
armpit_y = HEIGHT * 0.70  # yalnız koltuk altının üstü (omuz başı); yanlar forma kalır
shoulder_band, ut_lower = cut(ut_shirt, up, [0, armpit_y, 0])
for sx in (-1, 1):
    side_part, shoulder_band = cut(shoulder_band, [sx, 0, 0], [sx * seam_x, 0, 0])
    add("UpperTorso", "Sleeve", side_part)
ut_shirt = trimesh.util.concatenate([shoulder_band, ut_lower])
chest_w = 2 * seam_x
print("omuz dikişi x=±%.3f" % seam_x)
for pname, shirt in (("UpperTorso", ut_shirt), ("LowerTorso", lt_shirt)):
    add(pname, "Shirt", shirt, "Duz")
    # Cubuklu: dokuz eşit dikey bant, 2-4-6-8. bantlar lacivert
    rest = shirt
    bw = chest_w / 9
    for k in range(1, 9):
        x = -chest_w / 2 + k * bw
        left, rest = cut(rest, [-1, 0, 0], [x, 0, 0])
        add(pname, "Stripe" if k % 2 == 0 else "Shirt", left, "Cubuklu")
    add(pname, "Shirt", rest, "Cubuklu")
    # Kusakli: göğüste gövdeyi saran yatay kuşak
    band_hi, band_lo = HEIGHT * 0.69, HEIGHT * 0.635
    above, below = cut(shirt, up, [0, band_hi, 0])
    band, below = cut(below, up, [0, band_lo, 0])
    add(pname, "Shirt", above, "Kusakli")
    add(pname, "Stripe", band, "Kusakli")
    add(pname, "Shirt", below, "Kusakli")

# baş: önce yüz işaretleri (burun ucu: en öndeki nokta), sonra saç bölgesi
hd = part_mesh["Head"]
hv_all = hd.vertices
mid = hv_all[np.abs(hv_all[:, 0]) < 0.06]
nose0 = mid[np.argmin(mid[:, 2])]
eye_y0 = nose0[1] + 0.13
hz0, hz1 = hd.bounds[0][2], hd.bounds[1][2]
hcz = (hz0 + hz1) / 2
cen = hd.triangles_center
zf_, yz = cen[:, 2], cen[:, 1]
is_hair = np.where(
    zf_ < hcz - 0.12,
    yz > eye_y0 + 0.21,  # önde: alın saç çizgisi
    np.where(zf_ > hcz + 0.12, yz > eye_y0 - 0.12, yz > eye_y0 + 0.07),  # arkada ense, yanda kulak üstü
)
hair = hd.submesh([np.where(is_hair)[0]], append=True)
face = hd.submesh([np.where(~is_hair)[0]], append=True)
add("Head", "Hair", hair, "S2")
add("Head", "Skin", face)

# Yüz işaretleri: çene ucu (ön alt), burun ucu (en önde), ağız (ikisinin arası)
fv = face.vertices
front_mid = fv[np.abs(fv[:, 0]) < 0.06]
nose = front_mid[np.argmin(front_mid[:, 2])]
below = front_mid[(front_mid[:, 1] < nose[1] - 0.05) & (front_mid[:, 2] < nose[2] + 0.14)]
chin_y = float(below[:, 1].min())
nose_y = float(nose[1])
mouth_y = chin_y + (nose_y - chin_y) * 0.45
eye_y = nose_y + 0.13
landmarks.update({"ChinY": chin_y, "NoseY": nose_y, "MouthY": mouth_y})


def shell(m, mask, off):
    """Yüzeyin seçili üçgenlerinden, normal boyunca off kadar dışarıda ince kabuk."""
    if not mask.any():
        return None
    sub = m.submesh([np.where(mask)[0]], append=True)
    sub.vertices = sub.vertices + sub.vertex_normals * off
    return sub


# Sakal: yüzün ön-alt bölgesi (çene hattı); bıyık: ağzın üstü; keçi: çene ortası
fs = face
cen = fs.triangles_center
front_half = cen[:, 2] < (fs.bounds[0][2] + fs.bounds[1][2]) / 2 + 0.05
jaw = front_half & (cen[:, 1] > chin_y - 0.025) & (cen[:, 1] < mouth_y + 0.03) & (cen[:, 2] < (fs.bounds[0][2] + fs.bounds[1][2]) / 2 - 0.02)
lips = (np.abs(cen[:, 1] - mouth_y) < 0.022) & (np.abs(cen[:, 0]) < 0.075) & front_half
add("Head", "Beard", shell(fs, jaw & ~lips, 0.012), "Tam")
must = front_half & (cen[:, 1] > mouth_y + 0.018) & (cen[:, 1] < nose_y - 0.012) & (np.abs(cen[:, 0]) < 0.14)
add("Head", "Beard", shell(fs, must, 0.012), "Biyik")
goat = front_half & (cen[:, 1] > chin_y - 0.04) & (cen[:, 1] < mouth_y - 0.02) & (np.abs(cen[:, 0]) < 0.1)
add("Head", "Beard", shell(fs, goat | must, 0.012), "Keci")
brow = front_half & (cen[:, 1] > eye_y + 0.035) & (cen[:, 1] < eye_y + 0.075) & (np.abs(cen[:, 0]) > 0.03) & (np.abs(cen[:, 0]) < 0.17)
brow &= cen[:, 2] < fs.bounds[0][2] + 0.16
add("Head", "Brow", shell(fs, brow, 0.006), "Ince")
brow_k = front_half & (cen[:, 1] > eye_y + 0.025) & (cen[:, 1] < eye_y + 0.09) & (np.abs(cen[:, 0]) > 0.025) & (np.abs(cen[:, 0]) < 0.18)
brow_k &= cen[:, 2] < fs.bounds[0][2] + 0.17
add("Head", "Brow", shell(fs, brow_k, 0.008), "Kalin")

# Kafa derisi (kel ve sıfır saç): saç parçası, kafatasına oturan bir elipsoide yansıtılır
hv = hair.vertices
temple = fv[np.abs(fv[:, 1] - eye_y) < 0.05]
rx = float(np.percentile(np.abs(temple[:, 0]), 97)) + 0.01
zf = float(fv[fv[:, 1] > eye_y][:, 2].min())  # alın önü
zb = float(hv[:, 2].max()) - 0.03  # ense arkası (saç kalınlığı düşülür)
cz = (zf + zb) / 2
rz = (zb - zf) / 2
cy = eye_y - 0.02
ry = (eye_y + 0.36) - cy
sc = hair.copy()
d = sc.vertices - np.array([0.0, cy, cz])
k_ = np.sqrt((d[:, 0] / rx) ** 2 + (d[:, 1] / ry) ** 2 + (d[:, 2] / rz) ** 2)
# yalnız kafatası elipsoidinin dışına taşan saç noktaları içeri çekilir; kenardaki noktalar (yüze
# değenler) yerinde kalır, böylece kafa derisi yüzle kesintisiz birleşir
sc.vertices = np.array([0.0, cy, cz]) + d / np.maximum(k_, 1.0)[:, None]
add("Head", "Scalp", sc)

from skimage import measure

C0 = np.array([0.0, cy, cz])
RR = np.array([rx, ry, rz])


def sd_skull(P):
    q = (P - C0) / RR
    k = np.linalg.norm(q, axis=-1)
    return (k - 1) * RR.min()


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def hairline(z):
    # önde alın, yanda kulak üstü, arkada ense (önceki saç bölgesiyle aynı)
    return np.interp(
        z,
        [zf - 1, cz - 0.14, cz - 0.06, cz + 0.1, cz + 0.18, zb + 1],
        [eye_y + 0.21, eye_y + 0.21, eye_y + 0.07, eye_y + 0.07, eye_y - 0.12, eye_y - 0.12],
    )


def region(P):
    return hairline(P[..., 2]) - P[..., 1]  # < 0: saç bölgesi


def sbox(P, c, b, r):
    q = np.abs(P - c) - b
    return np.linalg.norm(np.maximum(q, 0), axis=-1) + np.minimum(q.max(-1), 0) - r


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def hair_sdf(style, P):
    y, x = P[..., 1], P[..., 0]
    d0 = sd_skull(P)
    if style == 3:  # Hacimli: önde kabaran, tepede kalın, geriye taranmış
        lift = ss(eye_y + 0.18, eye_y + 0.42, y)
        Q = P + np.stack([0 * y, 0 * y, -0.05 * lift], -1)  # hacim arkaya kayar
        T = 0.025 + 0.085 * lift
        d = sd_skull(Q) - T
        return np.maximum(d, region(P) + 0.02 * (1 - lift))
    if style == 4:  # Uzun: önde ve yanda normal saç çizgisi, kulak arkasından omuza inen perde
        d = d0 - 0.045
        curtain = sbox(P, np.array([0, eye_y - 0.24, cz + rz * 0.6]), np.array([rx * 0.88, 0.34, rz * 0.42]), 0.06)
        d = smin(d, curtain, 0.08)
        back = ss(cz - 0.06, cz + 0.04, P[..., 2])  # arka yarı
        reg = region(P) * (1 - back) + (eye_y - 0.6 - y) * back
        return np.maximum(d, reg)
    if style == 5:  # Kıvırcık: tepede sık bukleler, yanlar kısa
        f = 26.0
        bumps = 0.022 * np.sin(f * x) * np.sin(f * y) * np.sin(f * P[..., 2])
        T = 0.03 + 0.06 * ss(eye_y + 0.1, eye_y + 0.3, y) + bumps
        return np.maximum(d0 - T, region(P))
    if style == 6:  # Topuz: geriye sıkı toplanmış, tepe arkasında topuz
        d = d0 - 0.03
        bun = np.linalg.norm(P - np.array([0, eye_y + 0.31, cz + rz * 0.92]), axis=-1) - 0.13
        d = np.maximum(d, region(P))
        return smin(d, bun, 0.04)
    if style == 7:  # Yanlar kısa: yanlar sıfır, tepede uzun şerit
        T = 0.018 + 0.1 * (1 - ss(0.09, 0.15, np.abs(x))) * ss(eye_y + 0.18, eye_y + 0.3, y)
        return np.maximum(d0 - T, region(P))
    raise ValueError(style)


lo = C0 - RR - np.array([0.25, 0.75, 0.25])
hi = C0 + RR + np.array([0.25, 0.25, 0.3])
step = 0.016
gx = np.arange(lo[0], hi[0], step)
gy = np.arange(lo[1], hi[1], step)
gz = np.arange(lo[2], hi[2], step)
Pg = np.stack(np.meshgrid(gx, gy, gz, indexing="ij"), -1)
for style in (3, 4, 5, 6, 7):
    vol = hair_sdf(style, Pg)
    verts, faces_, _, _ = measure.marching_cubes(vol, 0.0, spacing=(step, step, step))
    verts = verts + lo
    hm = trimesh.Trimesh(verts, faces_[:, ::-1], process=True)
    # en büyük bağlı parça (kopuk kırıntılar atılır), önce yumuşatma, sonra hafif sadeleştirme
    comps = hm.split(only_watertight=False)
    hm = max(comps, key=lambda m: len(m.faces))
    trimesh.smoothing.filter_taubin(hm, iterations=8)
    ref_lo, ref_hi = hm.bounds[0].copy(), hm.bounds[1].copy()
    target = 2200
    if len(hm.faces) > target:
        v2, f2 = fast_simplification.simplify(hm.vertices, hm.faces, target_reduction=1 - target / len(hm.faces), agg=3)
        cand = trimesh.Trimesh(v2, f2, process=True)
        # güvenlik: sadeleştirme şekli bozmamalı (sınır kutusu 2 cm'den fazla değişirse vazgeç)
        if np.abs(cand.bounds - np.array([ref_lo, ref_hi])).max() < 0.02:
            hm = cand
        else:
            print("  saç", style, "sadeleştirme şekli bozdu, tam çözünürlük kullanılıyor")
    assert np.all(hm.bounds[0] >= lo - 1e-3) and np.all(hm.bounds[1] <= hi + 1e-3), ("saç taşıyor", style, hm.bounds)
    assert (hm.bounds[1][1] - (cy + ry)) < 0.2, ("saç kafanın çok üstüne çıkıyor", style, hm.bounds)
    add("Head", "Hair", hm, "S%d" % style)
    print("saç", style, len(hm.faces))

# ---------------------------------------------------------------- 4. çıktı
ROLE_COLOR = {
    "Skin": (232, 190, 160),
    "Hair": (40, 30, 24),
    "Shirt": (255, 230, 0),
    "Stripe": (11, 23, 71),
    "Sleeve": (255, 230, 0),
    "Trim": (11, 23, 71),
    "Shorts": (11, 23, 71),
    "Sock": (255, 230, 0),
    "Boot": (20, 20, 24),
    "Beard": (40, 30, 24),
    "Scalp": (200, 160, 130),
    "Brow": (40, 30, 24),
    "BootSole": (235, 235, 235),
    "BootCollar": (20, 20, 24),
    "SockTop": (255, 230, 0),
    "SockBand": (255, 230, 0),
}


def marker(at):
    m = trimesh.creation.icosahedron()
    m.apply_scale(0.02)
    m.apply_translation(at)
    return m


def export(path, preview_pattern=None):
    scene = trimesh.Scene()
    count = 0
    for p, role, pattern, m in pieces:
        if preview_pattern is not None and pattern is not None and pattern != preview_pattern:
            continue
        name = f"{p}__{role}" + (f"__{pattern}" if pattern else "")
        mm = m.copy()
        mm.merge_vertices()
        if preview_pattern is not None:
            r, g_, b = ROLE_COLOR[role]
            mm.visual = trimesh.visual.TextureVisuals(
                material=trimesh.visual.material.PBRMaterial(
                    baseColorFactor=[r / 255, g_ / 255, b / 255, 1.0], roughnessFactor=0.7, metallicFactor=0.0
                )
            )
        # aynı adlı birden çok kesit (ör. çubuklu bantlar) tek düğümde birleşir
        scene.add_geometry(mm, node_name=f"{name}#{count}", geom_name=f"{name}#{count}")
        count += 1
    if preview_pattern is None:
        for nm, at in (("FK_Origin", (0, 0, 0)), ("FK_AxisX", (1, 0, 0)), ("FK_AxisY", (0, 1, 0))):
            scene.add_geometry(marker(np.array(at, float)), node_name=nm, geom_name=nm)
    return scene


def merged_pieces():
    out = {}
    for p, role, pattern, m in pieces:
        key = (p, role, pattern)
        out.setdefault(key, []).append(m)
    res = []
    for (p, role, pattern), ms in out.items():
        mm = trimesh.util.concatenate(ms) if len(ms) > 1 else ms[0]
        res.append((p, role, pattern, mm))
    return res


pieces = merged_pieces()

MAX_FACES = 20000  # yalnız Roblox içe aktarma sınırı için güvenlik; sadeleştirme komşu parçalar arasında aralık açar
import fast_simplification


def cap_faces(m):
    if len(m.faces) <= MAX_FACES:
        return m
    v, f = fast_simplification.simplify(m.vertices, m.faces, target_reduction=1 - MAX_FACES / len(m.faces))
    return trimesh.Trimesh(v, f, process=False)


pieces = [(p, r, pat, cap_faces(m)) for p, r, pat, m in pieces]

scene = trimesh.Scene()
for p, role, pattern, m in pieces:
    name = f"{p}__{role}" + (f"__{pattern}" if pattern else "")
    scene.add_geometry(m, node_name=name, geom_name=name)
for nm, at in (("FK_Origin", (0, 0, 0)), ("FK_AxisX", (1, 0, 0)), ("FK_AxisY", (0, 1, 0))):
    scene.add_geometry(marker(np.array(at, float)), node_name=nm, geom_name=nm)
scene.export(OUT_GLB)

prev = trimesh.Scene()
for p, role, pattern, m in pieces:
    if pattern not in (None, "Cubuklu", "Tam", "S2", "Ince") or role == "Scalp":
        continue
    mm = m.copy()
    r, g_, b = ROLE_COLOR[role]
    mm.visual = trimesh.visual.TextureVisuals(
        material=trimesh.visual.material.PBRMaterial(
            baseColorFactor=[r / 255, g_ / 255, b / 255, 1.0], roughnessFactor=0.75, metallicFactor=0.0
        )
    )
    prev.add_geometry(mm, node_name=f"{p}__{role}", geom_name=f"{p}__{role}__{pattern}")
prev.export(OUT_PREVIEW)

# iskelet: eklem noktaları (karakter uzayı, stud; ayaklar y=0, yüz -Z)
def jp(name):
    return J[name]


rig = {
    "Height": HEIGHT,
    "Parts": {},
    "Joints": {},
}
all_bounds = {}
for p in PARTS:
    m = part_mesh[p]
    all_bounds[p] = (m.bounds[0], m.bounds[1])
    size = m.bounds[1] - m.bounds[0]
    rig["Parts"][p] = {"Center": center[p], "Size": np.maximum(size, 0.2)}


def joint(name, p0, p1, at):
    rig["Joints"][name] = {"Part0": p0, "Part1": p1, "Pivot": np.asarray(at, float)}


hips_p = jp("Hips")
joint("Root", "HumanoidRootPart", "LowerTorso", hips_p)
joint("Waist", "LowerTorso", "UpperTorso", jp("Spine01"))
joint("Neck", "UpperTorso", "Head", jp("neck"))
for side in ("Left", "Right"):
    sd = side_of(side + "Arm")
    joint(sd + "Shoulder", "UpperTorso", sd + "UpperArm", jp(side + "Arm"))
    joint(sd + "Elbow", sd + "UpperArm", sd + "LowerArm", jp(side + "ForeArm"))
    joint(sd + "Wrist", sd + "LowerArm", sd + "Hand", jp(side + "Hand"))
    sd = side_of(side + "UpLeg")
    joint(sd + "Hip", "LowerTorso", sd + "UpperLeg", jp(side + "UpLeg"))
    joint(sd + "Knee", sd + "UpperLeg", sd + "LowerLeg", jp(side + "Leg"))
    joint(sd + "Ankle", sd + "LowerLeg", sd + "Foot", jp(side + "Foot"))
rig["RootCenter"] = np.array([0.0, hips_p[1], 0.0])
rig["HipHeight"] = float(hips_p[1] - 1.0)  # kök parça 2 stud yüksek, altı HipHeight'ta

# baskı yerleri: sırt ve göğüs yüzeyi
ys = ut_shirt.vertices
back = ys[(np.abs(ys[:, 0]) < 0.15)]
def surface_z(y, front):
    sel = back[np.abs(back[:, 1] - y) < 0.08]
    if len(sel) == 0:
        return None
    return float(sel[:, 2].min() if front else sel[:, 2].max())


chest_print_y = HEIGHT * 0.73
back_num_y = HEIGHT * 0.70
rig["Print"] = {
    "ChestY": chest_print_y,
    "ChestZ": surface_z(chest_print_y, True),
    "BackY": back_num_y,
    "BackZ": surface_z(back_num_y, False),
    "BackNameY": HEIGHT * 0.775,
    "BackNameZ": surface_z(HEIGHT * 0.775, False),
    "ChestW": chest_w,
}
rig["Landmarks"] = landmarks


def lua(v, ind=1):
    pad = "\t" * ind
    if isinstance(v, dict):
        items = []
        for k in sorted(v.keys()):
            items.append(f"{pad}{k} = {lua(v[k], ind + 1)},")
        return "{\n" + "\n".join(items) + "\n" + "\t" * (ind - 1) + "}"
    if isinstance(v, np.ndarray):
        return "Vector3.new(%.4f, %.4f, %.4f)" % tuple(v)
    if isinstance(v, str):
        return json.dumps(v)
    if v is None:
        return "nil"
    return "%.4f" % v


with open(OUT_LUAU, "w") as f:
    f.write(
        "--[[\n\tMeshRig (otomatik üretildi: tools/meshgen/oyuncu_r15.py)\n"
        "\tFK_Oyuncu mesh gövdesinin iskeleti: parça merkezleri ve ölçüleri, eklem noktaları,\n"
        "\tkalça yüksekliği ve forma baskı yerleri. Karakter uzayı: ayaklar y=0, yüz -Z, sağ el +X.\n"
        "\tElle düzenleme; betiği yeniden çalıştır.\n]]\n\n"
        "return " + lua(rig) + "\n"
    )

print("parçalar:", len(pieces), "en büyük:", max(len(m.faces) for *_, m in pieces))
typ = sum(len(m.faces) for p, r, pat, m in pieces if pat in (None, "Cubuklu") and r not in ("Scalp",))
print("tipik karakter üçgeni (çubuklu, sakalsız):", typ)
for p in PARTS:
    roles = sorted({(r, pat) for q, r, pat, _ in pieces if q == p}, key=str)
    print(" ", p, len(part_mesh[p].faces), roles)
print("landmarks", {k: round(v, 3) for k, v in landmarks.items()})
print("collar_top %.3f shirt_hem_y %.3f chest_w %.3f hip %.3f" % (collar_top, shirt_hem_y, chest_w, rig["HipHeight"]))
print("print", {k: (round(v, 3) if v is not None else None) for k, v in rig["Print"].items()})
