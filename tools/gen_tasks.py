#!/usr/bin/env python3
"""TASKS.md üretici. Kaynak: docs/reference/YAPILACAKLAR.json (104 görev, kimlikler korunur) + tools/task_status.json.
Kullanım:  python3 tools/gen_tasks.py          → TASKS.md yazar
           python3 tools/gen_tasks.py --check  → TASKS.md güncel mi + kurallar (CI)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "reference", "YAPILACAKLAR.json")
STATUS = os.path.join(ROOT, "tools", "task_status.json")
OUT = os.path.join(ROOT, "TASKS.md")
ALLOWED = ("TODO", "IN_PROGRESS", "DONE", "BLOCKED")
PHASE_TITLES = {
    "F0": "F0 — Kapsam, cihaz, içerik ve teknik kararlar (1. hafta)",
    "F1": "F1 — Tasarım sistemi ve çalışan menü iskeleti (2–3. haftalar)",
    "F2": "F2 — Oyuncu, top, kaleci, kontrol ve erken ağ denemesi (4–7. haftalar)",
    "F3": "F3 — 11v11 PvE, 100 oyuncu kataloğu ve kalıcı ödül döngüsü (8–12. haftalar)",
    "F4": "F4 — Gelişim, etkinlik, görev, bilet, mağaza, takas, yönetim (13–17. haftalar)",
    "F5": "F5 — Pazar, arkadaş sistemi ve çevrimiçi maç (18–22. haftalar)",
    "F6": "F6 — Diğer modlar, rekabet, sanat ve cihaz optimizasyonu (23–30. haftalar)",
    "F7": "F7 — Ödeme, operasyon ve kademeli yayın (31–36+. haftalar)",
}
ICON = {"TODO": "[ ]", "IN_PROGRESS": "[~]", "DONE": "[x]", "BLOCKED": "[!]"}


def load():
    tasks = json.load(open(SRC, encoding="utf-8"))
    status = json.load(open(STATUS, encoding="utf-8"))
    status.pop("_doc", None)
    return tasks, status


def build(tasks, status):
    counts = {k: 0 for k in ALLOWED}
    for t in tasks:
        counts[status.get(t["id"], {}).get("status", "TODO")] += 1
    L = []
    L.append("# TASKS — 104 görevlik çalışma sırası\n")
    L.append("> Bu dosya **üretilmiştir**: `python3 tools/gen_tasks.py` (kaynak: `docs/reference/YAPILACAKLAR.json` + `tools/task_status.json`). Elle düzenleme; durumu `task_status.json`'da güncelle.\n")
    L.append("Durum anlamları: `[ ]` TODO · `[~]` IN_PROGRESS (kod/belge var, kabul ölçütü tam karşılanmadı) · `[x]` DONE (uygulandı **ve** doğrulandı; kanıt zorunlu) · `[!]` BLOCKED.\n")
    L.append("**Önemli:** Unity bu geliştirme ortamında yoktur. Unity/cihaz doğrulaması gerektiren hiçbir görev DONE değildir. Kanıt sütunundaki *G kodları* video gözlemidir (`docs/reference/GEREKSINIM_IZLENEBILIRLIK.csv`); TEKNIK/TASARIM/KULLANICI etiketleri öneri/gereksinimdir.\n")
    L.append("| Durum | Adet |\n|---|---|")
    for k in ALLOWED:
        L.append("| %s %s | %d |" % (ICON[k], k, counts[k]))
    L.append("| **Toplam** | **%d** |\n" % len(tasks))
    cur = None
    for t in tasks:
        if t["phase"] != cur:
            cur = t["phase"]
            L.append("\n## " + PHASE_TITLES[cur] + "\n")
        st = status.get(t["id"], {})
        s = st.get("status", "TODO")
        L.append("- %s **%s · %s · %s** — %s" % (ICON[s], t["id"], t["priority"], t["area"], t["title"]))
        L.append("  - Kabul: %s" % t["acceptance"])
        L.append("  - Kanıt kodu: %s · Bağımlılık: %s · Durum: **%s**" % (t["evidence"], t["depends_on"], s))
        if st.get("evidence"):
            L.append("  - Doğrulama/Not: %s" % st["evidence"])
        if st.get("next"):
            L.append("  - Sıradaki: %s" % st["next"])
    return "\n".join(L) + "\n"


def check(tasks, status):
    errs = []
    ids = [t["id"] for t in tasks]
    if ids != ["T%03d" % i for i in range(1, 105)]:
        errs.append("104 görev kimliği T001..T104 sırasıyla korunmalı")
    for k, v in status.items():
        if k not in ids:
            errs.append("task_status.json bilinmeyen kimlik: " + k)
        elif v.get("status") not in ALLOWED:
            errs.append("%s: geçersiz durum %s" % (k, v.get("status")))
        elif v["status"] in ("DONE", "IN_PROGRESS") and not v.get("evidence"):
            errs.append("%s: %s için kanıt/not zorunlu" % (k, v["status"]))
    by = {t["id"]: t for t in tasks}
    for k, v in status.items():
        if v.get("status") == "DONE" and k in by:
            for d in [x.strip() for x in by[k]["depends_on"].replace("/", ",").split(",") if x.strip().startswith("T")]:
                if status.get(d, {}).get("status", "TODO") == "TODO":
                    errs.append("%s DONE ama bağımlılığı %s TODO" % (k, d))
    # Unity/cihaz gerektiren alanlarda DONE yasak (ek güvenlik): derleme/cihaz görevleri
    for forbidden in ("T033", "T052", "T094", "T095", "T102"):
        if status.get(forbidden, {}).get("status") == "DONE":
            errs.append(forbidden + " cihaz/Unity doğrulaması olmadan DONE olamaz")
    return errs


def main():
    tasks, status = load()
    errs = check(tasks, status)
    text = build(tasks, status)
    if "--check" in sys.argv:
        if not os.path.exists(OUT) or open(OUT, encoding="utf-8").read() != text:
            errs.append("TASKS.md güncel değil: python3 tools/gen_tasks.py çalıştır")
        if errs:
            print("GÖREV KONTROLÜ BAŞARISIZ:\n  - " + "\n  - ".join(errs)); return 1
        print("OK: 104 görev, durumlar tutarlı, TASKS.md güncel"); return 0
    if errs:
        print("UYARI:\n  - " + "\n  - ".join(errs))
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    c = {}
    for t in tasks:
        s = status.get(t["id"], {}).get("status", "TODO"); c[s] = c.get(s, 0) + 1
    print("TASKS.md yazıldı:", c)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
