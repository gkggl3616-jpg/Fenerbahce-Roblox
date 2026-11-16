# PROGRESS — çalışma dilimi raporu

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
- `dotnet build tools/compile-check`: Runtime katmanı UnityEngine referanslarıyla **derlendi** (yaklaşık kontrol).
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

### Actions durumu
(İlk koşudan sonra güncellenir.)
