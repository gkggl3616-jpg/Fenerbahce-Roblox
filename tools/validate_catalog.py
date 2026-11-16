#!/usr/bin/env python3
"""Katalog/içerik doğrulayıcı (C# CatalogValidator'dan BAĞIMSIZ ikinci kontrol; Unity gerektirmez).

Kurallar (CLAUDE_ANA_PROMPT §9 Veri): tam 100 benzersiz playerId, geçersiz referans yok,
mevkisiz kart yok, kart varyantı futbolcu sayısını artırmaz, portre teslim iddiası izinsiz olamaz.
Çıkış kodu: 0 = geçerli, 1 = hata var.
"""
import json
import os
import re
import sys
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "unity", "Assets", "_Game", "Resources", "Content")
GROUP_OF = {"GK": "GK", "CB": "DEF", "LB": "DEF", "RB": "DEF", "CDM": "MID", "CM": "MID", "CAM": "MID",
            "LM": "MID", "RM": "MID", "LW": "ATT", "RW": "ATT", "ST": "ATT"}
SCREENS = {"home", "club", "collection", "play", "events", "store", "settings"}


def load(name):
    with open(os.path.join(CONTENT, name), encoding="utf-8") as f:
        return json.load(f)


def main():
    errors = []
    err = errors.append
    players = load("players.v1.json")["players"]
    cards = load("cards.v1.json")["cards"]
    camps = load("campaigns.v1.json")["campaigns"]

    ids = [p["playerId"] for p in players]
    if len(ids) != 100 or len(set(ids)) != 100:
        err("PLAYER_COUNT: tam 100 benzersiz playerId bekleniyor, bulunan %d (benzersiz %d)" % (len(ids), len(set(ids))))
    for pid in ids:
        if not re.fullmatch(r"P\d{3}", pid):
            err("PLAYER_ID: geçersiz %s" % pid)
    names = [p["displayName"].casefold() for p in players]
    for n, c in Counter(names).items():
        if c > 1:
            err("PLAYER_NAME_DUP: %s" % n)
    groups = Counter(p["positionGroup"] for p in players)
    if (groups["GK"], groups["DEF"], groups["MID"], groups["ATT"]) != (10, 32, 32, 26):
        err("GROUPS: beklenen 10/32/32/26, bulunan %s" % dict(groups))
    for p in players:
        pid = p["playerId"]
        pos = p.get("primaryPosition")
        if pos not in GROUP_OF:
            err("%s: mevki yok/geçersiz (%s)" % (pid, pos)); continue
        if GROUP_OF[pos] != p["positionGroup"]:
            err("%s: grup/mevki uyuşmuyor" % pid)
        alts = p.get("alternatePositions", [])
        if pos in alts or len(set(alts)) != len(alts) or any(a not in GROUP_OF for a in alts):
            err("%s: alternatif mevkiler hatalı" % pid)
        if p["positionGroup"] == "GK" and alts:
            err("%s: kalecinin alternatif mevkisi olamaz" % pid)
        if p["positionGroup"] != "GK" and "GK" in alts:
            err("%s: saha oyuncusu GK alternatifi alamaz" % pid)
        a = p["attributes"]
        for k in ("pace", "shooting", "passing", "dribbling", "defending", "physical"):
            if not 1 <= a[k] <= 99:
                err("%s: %s aralık dışı" % (pid, k))
        if p["positionGroup"] == "GK" and a["goalkeeping"] < 1:
            err("%s: kaleci goalkeeping<1" % pid)
        if p.get("statsSource") != "PROTOTIP_DENGE_V0":
            err("%s: statsSource prototip etiketi yok (gerçek veri iddiası)" % pid)
        pt = p["portrait"]
        if pt["delivered"] and (not pt["source"] or pt["usageRightsStatus"] != "DOGRULANDI"):
            err("%s: portre teslim edildi iddiası kaynak/izin kanıtı olmadan" % pid)
        if not pt["delivered"] and not pt.get("fallback"):
            err("%s: portre yok ve fallback yok" % pid)

    cids = [c["cardDefinitionId"] for c in cards]
    if len(cids) != len(set(cids)):
        err("CARD_DUP: yinelenen cardDefinitionId")
    base = set()
    for c in cards:
        if c["playerId"] not in set(ids):
            err("CARD_REF: %s geçersiz playerId %s" % (c["cardDefinitionId"], c["playerId"]))
        if not c["cardDefinitionId"].startswith(c["playerId"] + "_"):
            err("CARD_NAMING: %s" % c["cardDefinitionId"])
        if c["family"] == "BASE":
            base.add(c["playerId"])
    for pid in ids:
        if pid not in base:
            err("CARD_BASE: %s için BASE kart yok" % pid)
    if len({c["playerId"] for c in cards}) != len(set(ids)):
        err("VARIANT_COUNT: kart varyantları futbolcu sayısını değiştirdi")

    # Başlangıç paketi: ekonomi sabitiyle senkron
    cs = open(os.path.join(ROOT, "unity", "Assets", "_Game", "Core", "Economy", "EconomyService.cs"), encoding="utf-8").read()
    starter = re.findall(r'"(P\d{3}_BASE_V1)"', cs)
    if len(starter) != 18 or len(set(starter)) != 18:
        err("STARTER: başlangıç paketi 18 benzersiz kart olmalı, bulunan %d" % len(starter))
    for s in starter:
        if s not in cids:
            err("STARTER_REF: %s katalogda yok" % s)

    cids2 = set()
    for c in camps:
        if c["id"] in cids2:
            err("CAMPAIGN_DUP: %s" % c["id"])
        cids2.add(c["id"])
        if c["targetScreen"] not in SCREENS:
            err("CAMPAIGN_TARGET: %s -> %s" % (c["id"], c["targetScreen"]))

    if errors:
        print("DOĞRULAMA BAŞARISIZ (%d hata):" % len(errors))
        for e in errors:
            print("  - " + e)
        return 1
    print("OK: %d futbolcu (GK %d / DEF %d / MID %d / ATT %d), %d kart tanımı (%d varyant), %d kampanya, başlangıç paketi %d kart"
          % (len(ids), groups["GK"], groups["DEF"], groups["MID"], groups["ATT"], len(cards), len(cards) - len(ids), len(camps), len(starter)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
