# Kanarya Futbol (çalışma adı) — Fenerbahçe temalı mobil futbol

Unity + C#, Android öncelikli, yatay ekran. Ayrıntı: `CLAUDE.md`, `PROGRESS.md`, `TASKS.md`, `DECISIONS.md`.

**Şu an ne var:** menü iskeleti (ana merkez, kulüp/kadro, koleksiyon + 100'lük katalog, oyna, ayarlar, "yakında" ekranları), 100 oyunculuk veri kataloğu, yerel kayıt/ekonomi çekirdeği ve oynanabilir **Kontrol Sahası** (tek futbolcu + top + kaleci + rakip savunmacı). **Tam 11v11 maç, çevrimiçi, mağaza, pazar vb. henüz yok.**

**APK:** GitHub Actions → *Android APK*. Unity lisans sırları gerekir: `docs/ANDROID_APK_WORKFLOW.md`.

Hızlı doğrulama (Unity'siz): `python3 tools/validate_catalog.py && dotnet test tests/Core.Tests/Core.Tests.csproj`
