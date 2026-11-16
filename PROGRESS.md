# PROGRESS — çalışma dilimi raporu

## Dilim 5 (2026-11-16): S1 — 5v5 takım AI + oyuncu değiştirme (T041, T026, T027)
- **Kullanıcıdan gelen bilgiler:** isimler sorun değil (D-031), `OTO.` = savunmada kontrol edilen oyuncuyu otomatik savunturur (D-032), test cihazı POCO X7 Pro (D-033), **Unity lisansı yok** (D-034). Referans: tüm kare galerisi (HUD düğme setleri galeriye göre yeniden kuruldu, D-036).
- **Somut değişiklik:**
  - `Core/Sim/MatchWorld.cs`: iki takımlı 5v5 simülasyonu (4 saha + kaleci/takım): taşıyıcı AI (şut/pas/uzaklaştırma/sürme), destek koşusu, 1. savunmacı baskısı, 2. savunmacı örtüsü, pas kanalı kapatma, dizilişe dönüş, ayrışma; DEĞİŞTİR (en yakın / joystick yönü), 2. DEF (baskıya çağır), OTO., UZAKLAŞTIR, ayakta müdahale, kayma; aut/korner/kale vuruşu (basit), gol→kutlama→santra, uzatma (+N), 2 yarı + devre arası/maç sonu beklemesi; `MatchLog`'dan sonuç.
  - `GoalkeeperAI` iki kaleyi savunabilir (`Sign`), `Hold`; `MatchStateMachine` uzatma süresi + `+N` dakika; `HudLayout` galerideki düğme setleri; `ControlField`'a UZAKLAŞTIR + ayakta müdahale.
  - Runtime: `FieldSource` (ControlField/MatchWorld ortak yüz), `FieldWorld` ve `FieldHud` genelleştirildi (8 oyuncu, 2 kaleci, dinamik mini harita, yeni düğmeler, OTO. aç/kapa), `FieldController` iki mod, Oyna ekranında **SAHA / 5v5 MAÇ** seçimi, sonuç ekranında skor.
- **Kanıt (çalıştırıldı):** `dotnet test` **145/145** (23 yeni test). Ölçümler (12 tohum, 2 dk): gol/maç ≈2,8; şut ≈8,8; pas isabeti ≈%65; topa sahip olma ≈%51; güçlü(82) takım zayıfı(55) 9-5-2 yener; aynı tohum=aynı maç; top en fazla 1,0 sn durur; takım yayılımı 11 m, genişlik 16 m, 3+ kişi top başında %2; hücumda takım 4,4 m yükselir. Mutasyon denemeleri (2. DEF, OTO., kaleci yönü, ayrışma, hücum kayması, diziliş) testlerce yakalandı; **çelme niteliği terimi yakalanmadı** (testler onu ölçmüyor). `dotnet build tools/compile-check` geçti.
- **Doğrulanamayan:** Unity'de hiçbir şey çalıştırılmadı; `FieldHud`/`FieldWorld`/Oyna ekranı yalnız derleme kontrolünden geçti. Dokunmatik his, kamera, 8 oyuncunun görünümü, kare süresi **bilinmiyor**. Faul/ofsayt/tam aut-korner/penaltı/tekrar yok (T044–T047), taraf değişimi yok.
- **Açık engel:** APK yok — Unity lisansı yok. Seçenekler A/B/C (D-034, PLAN B1); karar kullanıcıda.
- **Sıradaki:** S2 — T042 (11v11 + kaleci), T044 (duran toplar, faul/ofsayt), T045; kullanıcı kararına göre S10a (Unity ilk ışık) öne alınır.

---

## Dilim 4 (2026-11-16): beş bölümün tamamı okundu → plan
- **Girdi:** kare arşivi **5/5 bölüm** (1/5 bu turda geldi; 4/5 iki kez geldi). Yayıncı kamerası maskelenerek ~590 benzersiz menü ekranı çıkarıldı; yeni olanların ~400'üne bakıldı, önemli ~20'si 2× okundu.
- **Çıktı:** `docs/EKRAN_SPESIFIKASYONU.md` **Ek A** (yeni hesap/seviye kilitleri, mağaza ayrıntıları, paket sahneleri, kadro/roller, maça giriş, pazar arama/SAT, Oyna merkezi, etkinlik haritası, bilet) ve **`docs/PLAN.md`** (kapsam eşlemesi, engeller, S0–S13 dilimleri, Kapı A ölçütleri, test stratejisi, riskler).
- **Karar:** D-026..D-030 (kimya/VALUE% kapsam dışı, plan sırası, Cooldown teklif, seviye kilitleri, diziliş genişlemesi). 104 görev kimliği korunuyor; 25 göreve plan notu eklendi.
- **Kod değişmedi** (bu dilim yalnız analiz + plan); test sayısı 122.
- **Sıradaki:** S1 — 5v5 takım AI + oyuncu değiştirme (T041, T026). Sizden: Unity lisans sırları + cihaz listesi.

---

## Dilim 3 (2026-11-16): derin kare okuması → ekran spesifikasyonu + mağaza/takas çekirdeği
- **Neden:** ilk inceleme özet sayfalarıyla (12–20 sn örnekleme) yapılmıştı ve çoğunlukla "G kodları doğrulandı" çıkmıştı. Bu dilimde ~35 anahtar kare **2× büyütülüp tek tek okundu** (mağaza, paket, takas, derece yükselt, kadro, pazar, sonuç, etkinlik haritası, görevler, modlar, Teke Tek, taktik, sezon bileti, beceriler, oyuncu detayı, beceri geliştirici, antrenman, Futbol Merkezi, maç HUD'u, arkadaşlar).
- **Çıktı:** `docs/EKRAN_SPESIFIKASYONU.md` — ekran ekran tam Türkçe etiketler, alan listeleri, durumlar, limit/süre kuralları, sayı/süre biçimleri.
- **Kodlanan (testli):** `NumberFormat` (`1.329.300.000`, `408,6B`, `2,491Mln`), `TimeFormat` (`25:44:04`, `6 GÜN`), `Periods` (UTC gün/Pazartesi hafta), `EconomyService.ApplyBundle` (tek atomik kapı), **`StoreService`** (limit, çift fiyat, kilit, süre, adet) ve **`ExchangeService`** (koşul sayacı, limit, süre, hızlı ekle, atomik takas); `offers.v1.json`, `exchanges.v1.json`.
- **Kanıt:** `dotnet test` **122/122** geçti (25 yeni test); kural bozma (mutasyon) denemesinde ilgili testler kırıldı; `validate_catalog.py` yeni içeriği de denetliyor.
- **Sınır:** mağaza/takas **UI'ı yok** (Unity'de doğrulanamaz, spesifikasyona göre sıradaki iş); referans 360p ve anahtar kareler örneklemeli; bölüm 1/5 hâlâ gelmedi.

---

## Dilim 2 (2026-11-16): referans incelemesi 2 + maç sonucu çekirdeği
- **İnceleme:** kare arşivinin 2/5, 3/5, 4/5, 5/5 bölümleri (2.877 kare; sahne geçişleri tam, saniyelik kareler örneklemeli) incelendi → `docs/REFERANS_INCELEME_2.md`. Sonuç: G kodları doğrulandı, kapsam değişmedi, 8 ince ayrıntı görev notlarına eklendi. **Bölüm 1/5 gelmedi.** Bölüm 4/5 iki kez yüklenmiş (aynı SHA-256).
- **Karar (D-019):** Unity lisansı bekleyen APK dışında, saf C#'ta doğrulanabilen kritik yol ilerler: önce maç sonucu/istatistik çekirdeği, sonra 5v5 AI → 11v11 + kurallar.
- **Yapılan:** `MatchLog` + `MatchResultBuilder` (skor, golcüler+dakika, şut/isabetli, kurtarış, topa sahip olma, pas isabeti — yalnız olay kaydından); `ControlField` olayları kaydediyor; `ResultScreen` G46 düzeninde gösteriyor; faul/ofsayt üretilmediği için "—".
- **Kanıt:** `dotnet test` 97/97 geçti (4 yeni test), Runtime compile-check geçti. Unity'de çalıştırılmadı.
- **Sıradaki:** T041 (5v5 takım AI), T042–T045, T047; lisans gelince T004/T033.

---

## Dilim 1 (2026-11-16): F0/F1 iskeleti + ilk top-kontrol sahası + APK iş akışı

### Somut değişiklik
- **Veri:** 100 benzersiz futbolcu (`players.v1.json`), 110 kart tanımı (10 varyant), 4 kampanya — `tools/generate_catalog.py` ile deterministik üretim. Nitelikler **prototip denge verisi**.
- **Çekirdek (saf C#):** alan modeli (PlayerDefinition/CardDefinition/CardInstance ayrı), katalog doğrulayıcı, diziliş/kadro/otomatik kur, yerel ekonomi (ledger + idempotency + atomik tüketim), kayıt/yükleme, maç durum makinesi, HUD düğme kuralları, tasarım token'ları + kontrast denetimi, Türkçe arama katlama, portre kırpımı.
- **Simülasyon:** `ControlField` — top fiziği (serbest/kontrol/havada), oyuncu hareketi + stamina, pas/ara pası/hedef seçimi, şut, kaleci AI, rakip savunmacı, kayarak top kapma, "Yön Değiştirme" çalımı, gol/kutlama/santra akışı, 2 dk'lık oturum.
- **Unity katmanı:** kodla kurulan uGUI menü (ana merkez + kampanya vitrini, kulüp/kadro, koleksiyon + 100'lük katalog, oyna, ayarlar, "yakında" ekranları, sonuç), 3B saha + yayın açılı kamera, sanal joystick + çoklu dokunma düğmeleri, mini harita, duraklatma.
- **CI/APK:** `ci.yml` (lisanssız), `android-apk.yml` (GameCI Unity → APK + Release), `BuildScript` (sahne/ayar kodla), rehber `docs/ANDROID_APK_WORKFLOW.md`.
- **Belgeler:** CLAUDE.md, DECISIONS.md, TASKS.md (104 görev, kimlikler korunmuş), MCP_STATUS.md, bu dosya.

### Çalıştırma yöntemi
```bash
python3 tools/validate_catalog.py && python3 tools/gen_tasks.py --check
dotnet test tests/Core.Tests/Core.Tests.csproj
dotnet build tools/compile-check/UnityCompileCheck.csproj
```
Unity'de: `unity/` klasörünü 2022.3.62f1 ile aç → *Kanarya → Sahneyi ve ayarları hazırla* → Play. APK: bkz. `docs/ANDROID_APK_WORKFLOW.md`.

### Doğrulama kanıtı (bu oturumda gerçekten çalıştı)
- `dotnet test` (net8.0, NUnit): **93/93 geçti** (katalog, kadro, ekonomi/kalıcılık, durum makinesi, HUD, sim, tasarım, arama, portre kırpımı).
- `tools/validate_catalog.py`: 100 futbolcu, 110 kart, geçerli.
- `dotnet build tools/compile-check`: Core ve Runtime ayrı derlemeler olarak UnityEngine referanslarıyla **derlendi** (yaklaşık kontrol; GitHub'da da geçti).
- Ölçülebilir oynanış farkları (kontrollü denemeler, testte): kaleci 25 → 300 şutta 179 gol; kaleci 95 → 38 gol. Şutçu 95 → 90 gol; şutçu 35 → 42 gol. Kayarak top kazanma 29/40.
- Bulunan ve düzeltilen gerçek hatalar: Newtonsoft koleksiyon ikilenmesi (kayıt yüklenince kartlar 7→14), keşfedilen kaleci aşırı güçlülüğü, test senaryosu hataları.

### Doğrulanamayan / yapılmayan (dürüst liste)
- **Unity bu ortamda yok:** Unity derlemesi, EditMode testleri (Unity'de), Play modu, APK **çalıştırılmadı**. UI yerleşimi, 3B görünüm, dokunmatik his, kare süresi hiç görülmedi.
- **APK:** İş akışı yazıldı; Unity lisans sırları (UNITY_LICENSE/UNITY_SERIAL + UNITY_EMAIL + UNITY_PASSWORD) eklenmeden üretilemez. Bkz. aşağıdaki "Actions durumu".
- Gerçek portre yok (100/100 siluet), izinler DOGRULANACAK. Animasyon/ses yok.
- 11v11 maç, faul/ofsayt/korner/penaltı, tekrar, çevrimiçi, sunucu, mağaza/paket/takas/pazar, etkinlik/görev/bilet **yok** (TASKS.md'de TODO).

### Açık engeller
1. Unity lisans sırları (kullanıcı) → APK.
2. Hedef cihaz listesi (T007) ve cihaz ölçümü (T033).
3. Portre/izin teslimi (T091), kulüp kimliği hakları.

### Sıradaki görev kimlikleri
Hemen: **T004** (ilk Unity derlemesi/APK koşusu), **T033** (cihazda his + kare süresi), **T022/T027–T029** (Unity'de HUD/kamera doğrulaması), **T030–T031** (rig + çalımlar).
Sonra F3: **T041–T048** (11v11 AI, kurallar, penaltı/serbest vuruş, tekrar, sonuç), **T049–T052** (sunucu iskeleti, tam döngü).

### Actions durumu (gerçek koşular, 2026-11-16)
- **Core CI #1: success** — veri doğrulama, görev kontrolü, `dotnet test` (93 test), Runtime compile-check GitHub runner'ında geçti.
- **Android APK #1 (push):** `verify` ✓; Unity işleri sır olmadığı için atlandı.
- **Android APK #2 (workflow_dispatch):** **failure — bilerek**: `UNITY_LICENSE`/`UNITY_SERIAL` + `UNITY_EMAIL` + `UNITY_PASSWORD` sırları tanımlı değil. **APK üretilmedi.** Sırlar eklenince koşuyu yeniden çalıştırmak yeterli (`docs/ANDROID_APK_WORKFLOW.md`).
- Unity derlemesi/BuildScript/GameCI akışı henüz **hiç çalışmadı**; ilk gerçek koşuda hata çıkabilir.
