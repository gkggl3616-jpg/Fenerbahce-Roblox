#!/usr/bin/env python3
"""T002/T017 — 100 oyunculuk aday katalogu oyun içeriğine (players.v1.json, cards.v1.json) dönüştürür.

Girdi : docs/reference/100_OYUNCU_ADAYI.json (aday liste; baseOverall=null, positions=[])
Çıktı : unity/Assets/_Game/Resources/Content/players.v1.json
        unity/Assets/_Game/Resources/Content/cards.v1.json

ÖNEMLİ — veri niteliği:
  * mevki, ayak, tier ve nitelikler PROTOTİP DENGE değerleridir (statsSource=PROTOTIP_DENGE_V0).
    Gerçek FIFA/EA FC reytingi, güncel kulüp bilgisi veya lisanslı veri DEĞİLDİR.
  * Portre dosyaları teslim edilmemiştir (portrait.delivered=false); kart siluet fallback gösterir.
  * Kullanım izni durumu DOGRULANACAK olarak kalır (T003/T091).
Çalıştırma: python3 tools/generate_catalog.py   (deterministik; aynı girdi → aynı çıktı)
"""
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "reference", "100_OYUNCU_ADAYI.json")
OUT_DIR = os.path.join(ROOT, "unity", "Assets", "_Game", "Resources", "Content")

# playerId: (birincil mevki, [alternatif mevkiler], tier, ayak)   tier: S > A > B
# Mevki/tier kararları prototip tasarım yargısıdır; içerik aşamasında (T091) gözden geçirilir.
SPEC = {
    # --- Kaleciler ---
    "P001": ("GK", [], "A", "R"), "P002": ("GK", [], "B", "R"), "P003": ("GK", [], "A", "R"),
    "P004": ("GK", [], "B", "R"), "P005": ("GK", [], "S", "L"), "P006": ("GK", [], "S", "R"),
    "P007": ("GK", [], "A", "L"), "P008": ("GK", [], "S", "R"), "P009": ("GK", [], "S", "R"),
    "P010": ("GK", [], "S", "R"),
    # --- Savunma ---
    "P011": ("LB", ["LM"], "S", "L"), "P012": ("RB", ["RM"], "B", "R"), "P013": ("CB", [], "A", "R"),
    "P014": ("CB", [], "B", "R"), "P015": ("CB", [], "A", "L"), "P016": ("CB", [], "A", "R"),
    "P017": ("LB", ["LM"], "B", "R"), "P018": ("RB", ["RM", "RW"], "B", "R"), "P019": ("CB", [], "B", "R"),
    "P020": ("CB", [], "B", "R"), "P021": ("CB", [], "B", "R"), "P022": ("RB", ["RM"], "B", "R"),
    "P023": ("LB", ["CB"], "B", "L"), "P024": ("CB", [], "S", "R"), "P025": ("CB", [], "S", "R"),
    "P026": ("CB", [], "A", "R"), "P027": ("CB", ["CDM"], "A", "R"), "P028": ("CB", ["RB"], "A", "R"),
    "P029": ("CB", [], "A", "R"), "P030": ("CB", ["RB"], "A", "R"), "P031": ("RB", ["RM", "RW"], "S", "R"),
    "P032": ("RB", ["CM", "RM"], "S", "R"), "P033": ("RB", ["LB"], "A", "R"), "P034": ("LB", ["LM"], "A", "L"),
    "P035": ("LB", ["LM"], "A", "L"), "P036": ("LB", ["LM"], "A", "L"), "P037": ("CB", ["LB"], "S", "L"),
    "P038": ("CB", [], "S", "R"), "P039": ("CB", [], "S", "R"), "P040": ("CB", ["RB"], "A", "R"),
    "P041": ("RB", ["LB", "CDM"], "S", "R"), "P042": ("CB", ["RB"], "S", "R"),
    # --- Orta saha ---
    "P043": ("CAM", ["CM", "LW"], "S", "R"), "P044": ("CM", ["CDM", "CAM"], "A", "R"),
    "P045": ("CM", ["CDM"], "B", "R"), "P046": ("CDM", ["CB", "CM"], "B", "R"),
    "P047": ("CDM", ["CM"], "B", "R"), "P048": ("CM", ["CDM"], "B", "R"),
    "P049": ("CM", ["RM"], "B", "R"), "P050": ("CAM", ["LM", "RM", "CM"], "B", "R"),
    "P051": ("CAM", ["CM"], "B", "R"), "P052": ("CM", ["CDM"], "B", "R"),
    "P053": ("CAM", ["LM", "CM"], "A", "L"), "P054": ("CAM", ["LW", "CM"], "A", "R"),
    "P055": ("CAM", ["CM", "RM"], "S", "R"), "P056": ("CM", [], "S", "R"), "P057": ("CM", ["CDM"], "S", "R"),
    "P058": ("CM", ["CAM"], "S", "R"), "P059": ("CM", ["CAM"], "A", "R"), "P060": ("CM", ["CDM"], "A", "R"),
    "P061": ("CAM", ["CM"], "A", "R"), "P062": ("CAM", ["LW", "LM"], "A", "L"),
    "P063": ("CM", ["RW", "CAM"], "A", "L"), "P064": ("CDM", ["CM"], "S", "R"),
    "P065": ("CDM", ["CM"], "S", "R"), "P066": ("CM", ["RM", "CDM"], "A", "R"),
    "P067": ("CAM", ["LW", "CM"], "A", "R"), "P068": ("CAM", ["LW"], "A", "R"),
    "P069": ("CAM", ["CM"], "S", "R"), "P070": ("CM", [], "S", "R"), "P071": ("CM", ["LM", "CAM"], "S", "R"),
    "P072": ("CDM", ["CM"], "S", "R"), "P073": ("CDM", ["CM"], "S", "R"), "P074": ("CM", ["CDM", "RM"], "S", "R"),
    # --- Hücum ---
    "P075": ("ST", ["LW"], "B", "R"), "P076": ("LW", ["ST", "LM"], "B", "L"), "P077": ("ST", [], "A", "R"),
    "P078": ("ST", [], "A", "R"), "P079": ("ST", [], "B", "R"), "P080": ("ST", [], "B", "R"),
    "P081": ("ST", ["LW", "CAM"], "B", "R"), "P082": ("ST", [], "B", "R"), "P083": ("ST", ["LW"], "A", "R"),
    "P084": ("ST", [], "B", "R"), "P085": ("ST", [], "B", "R"), "P086": ("ST", ["RW"], "A", "R"),
    "P087": ("ST", [], "A", "R"), "P088": ("ST", [], "B", "R"), "P089": ("ST", [], "A", "R"),
    "P090": ("RW", ["LW"], "A", "R"), "P091": ("ST", [], "S", "L"), "P092": ("ST", [], "A", "R"),
    "P093": ("ST", [], "A", "R"), "P094": ("RW", ["CAM", "ST"], "S", "L"), "P095": ("ST", ["LW"], "S", "R"),
    "P096": ("LW", ["CAM"], "S", "R"), "P097": ("ST", ["LW"], "S", "R"), "P098": ("ST", [], "S", "L"),
    "P099": ("RW", ["ST"], "S", "L"), "P100": ("ST", [], "S", "R"),
}

GROUP_OF = {"GK": "GK", "CB": "DEF", "LB": "DEF", "RB": "DEF", "CDM": "MID", "CM": "MID", "CAM": "MID",
            "LM": "MID", "RM": "MID", "LW": "ATT", "RW": "ATT", "ST": "ATT"}

TIER_RANGE = {"S": (88, 92), "A": (82, 87), "B": (74, 80)}

# Mevki şablonu: (hız, şut, pas, dribbling, defans, fizik) — GEN'e göre sapma. PROTOTİP değerleri.
TEMPLATE = {
    "GK":  (-38, -55, -28, -48, -60, -22),
    "CB":  (-12, -30, -12, -22, 3, 3),
    "LB":  (4, -22, -6, -6, -4, -8),
    "RB":  (4, -22, -6, -6, -4, -8),
    "CDM": (-8, -14, 0, -10, 2, 0),
    "CM":  (-4, -8, 3, -2, -8, -4),
    "CAM": (-2, 0, 4, 4, -26, -14),
    "LM":  (4, -4, -2, 4, -22, -12),
    "RM":  (4, -4, -2, 4, -22, -12),
    "LW":  (6, 0, -4, 6, -34, -14),
    "RW":  (6, 0, -4, 6, -34, -14),
    "ST":  (2, 4, -12, -2, -38, -4),
}
STAMINA_BASE = {"GK": 62, "CB": 72, "LB": 82, "RB": 82, "CDM": 82, "CM": 84, "CAM": 78, "LM": 82, "RM": 82,
                "LW": 78, "RW": 78, "ST": 74}
BODY_TYPE = {"GK": "GK_TALL", "CB": "DEF_STRONG", "LB": "DEF_LEAN", "RB": "DEF_LEAN", "CDM": "MID_STRONG",
             "CM": "MID_NORMAL", "CAM": "MID_LEAN", "LM": "MID_LEAN", "RM": "MID_LEAN", "LW": "ATT_LEAN",
             "RW": "ATT_LEAN", "ST": "ATT_STRONG"}

# Kart varyantları (futbolcu sayısını ARTIRMAZ). Program adları proje önerisidir, videodan gelmez.
VARIANTS = [
    ("P004", "SPECIAL", "KADIKOY_GECELERI", 3), ("P044", "SPECIAL", "KADIKOY_GECELERI", 3),
    ("P050", "SPECIAL", "KANARYA_AKADEMISI", 3), ("P054", "SPECIAL", "KADIKOY_GECELERI", 3),
    ("P043", "LEGEND", "EFSANELER_HAFTASI", 4), ("P011", "LEGEND", "EFSANELER_HAFTASI", 4),
    ("P069", "LEGEND", "EFSANELER_HAFTASI", 4), ("P094", "SPECIAL", "DUNYA_YILDIZLARI", 3),
    ("P097", "SPECIAL", "DUNYA_YILDIZLARI", 3), ("P037", "LEGEND", "EFSANELER_HAFTASI", 4),
]


def h(player_id: str, salt: str) -> int:
    return int(hashlib.sha256((player_id + ":" + salt).encode()).hexdigest()[:8], 16)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def build_player(src):
    pid = src["playerId"]
    pos, alts, tier, foot = SPEC[pid]
    lo, hi = TIER_RANGE[tier]
    overall = lo + h(pid, "ovr") % (hi - lo + 1)
    t = TEMPLATE[pos]
    names = ["pace", "shooting", "passing", "dribbling", "defending", "physical"]
    attrs = {}
    for i, n in enumerate(names):
        jitter = (h(pid, n) % 7) - 3
        attrs[n] = clamp(overall + t[i] + jitter, 20, 99)
    attrs["goalkeeping"] = clamp(overall + (h(pid, "gk") % 3) - 1, 40, 99) if pos == "GK" else 0
    stars = {"S": 4, "A": 3, "B": 2}[tier]
    if tier in ("S", "A") and pos in ("CAM", "LW", "RW", "ST", "LB", "RB") and h(pid, "star") % 2 == 0:
        stars += 1
    if pos == "GK":
        stars = 1
    stamina = clamp(STAMINA_BASE[pos] + (h(pid, "sta") % 11) - 5, 40, 99)
    return {
        "playerId": pid,
        "displayName": src["displayName"],
        "nationalityLabel": src["nationalityLabel"],
        "positionGroup": GROUP_OF[pos],
        "primaryPosition": pos,
        "alternatePositions": alts,
        "preferredFoot": "Left" if foot == "L" else "Right",
        "skillStars": stars,
        "stamina": stamina,
        "baseOverall": overall,
        "tier": tier,
        "attributes": attrs,
        "bodyType": BODY_TYPE[pos],
        "rosterStatus": "ADAY_ONAYLANMADI",
        "statsSource": "PROTOTIP_DENGE_V0",
        "portrait": {
            "path": "Portraits/" + pid,
            "delivered": False,
            "source": "",
            "usageRightsStatus": "DOGRULANACAK",
            "focalX": 0.5,
            "focalY": 0.38,
            "checksum": "",
            "fallback": "generic_silhouette",
        },
    }


def main():
    with open(SRC, encoding="utf-8") as f:
        cand = json.load(f)
    if len(cand) != 100 or len({c["playerId"] for c in cand}) != 100:
        sys.exit("HATA: aday liste tam 100 benzersiz playerId içermiyor")
    missing = [c["playerId"] for c in cand if c["playerId"] not in SPEC]
    if missing:
        sys.exit("HATA: SPEC eksik: %s" % missing)
    # Kaynak grup önerisi ile birincil mevkinin grubu çelişmemeli
    for c in cand:
        g = GROUP_OF[SPEC[c["playerId"]][0]]
        if g != c["positionGroupProposal"]:
            sys.exit("HATA: %s grup çelişkisi %s != %s" % (c["playerId"], g, c["positionGroupProposal"]))

    players = [build_player(c) for c in cand]
    by_id = {p["playerId"]: p for p in players}

    cards = []
    for p in players:
        cards.append({
            "cardDefinitionId": p["playerId"] + "_BASE_V1",
            "playerId": p["playerId"],
            "family": "BASE",
            "rarity": "Base",
            "program": "TEMEL",
            "overall": p["baseOverall"],
            "frameId": "frame_base",
            "tradable": True,
        })
    for pid, family, program, bonus in VARIANTS:
        p = by_id[pid]
        cards.append({
            "cardDefinitionId": "%s_%s_V1" % (pid, family),
            "playerId": pid,
            "family": family,
            "rarity": "Special" if family == "SPECIAL" else "Legend",
            "program": program,
            "overall": min(99, p["baseOverall"] + bonus),
            "frameId": "frame_special" if family == "SPECIAL" else "frame_legend",
            "tradable": True,
        })

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "players.v1.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({
            "contentVersion": "players.v1",
            "schemaVersion": 1,
            "statsSource": "PROTOTIP_DENGE_V0",
            "notice": "Nitelikler prototip denge değeridir; gerçek reyting/kulüp/lisans verisi değildir.",
            "players": players,
        }, f, ensure_ascii=False, indent=2)
        f.write("\n")
    with open(os.path.join(OUT_DIR, "cards.v1.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"contentVersion": "cards.v1", "schemaVersion": 1, "cards": cards}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("OK: %d oyuncu, %d kart tanımı (%d varyant)" % (len(players), len(cards), len(VARIANTS)))


if __name__ == "__main__":
    main()
