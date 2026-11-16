# CLAUDE.md — Kanarya Futbol (çalışma adı)

Fenerbahçe temalı, Android öncelikli, yatay ekranlı 3B mobil futbol oyunu. Unity 2022.3 LTS + C#.
Kaynak sözleşme: `docs/reference/CLAUDE_ANA_PROMPT.md` (görev listesi: `TASKS.md`, kararlar: `DECISIONS.md`).

> Depo adında "Roblox" geçer; bu proje **Roblox değil, Unity** projesidir (D-001).

## Değişmez kurallar
1. **Dürüst raporlama.** Unity yoksa derlediğini, MCP bağlanmadıysa bağlı olduğunu, test çalışmadıysa geçtiğini söyleme. `DONE` yalnız uygulanmış **ve** doğrulanmış işler içindir (`tools/task_status.json`, kanıt zorunlu).
2. **100 benzersiz futbolcu** (`PlayerDefinition`). Kart varyantı (`CardDefinition`) ve sahip olunan kopya (`CardInstance`) sayımı artırmaz.
3. **Veri niteliği.** `players.v1.json` nitelikleri `PROTOTIP_DENGE_V0`'dır; gerçek FIFA/EA FC reytingi, güncel kulüp veya lisanslı veri **değildir**. Portre yoksa siluet; portre "teslim edildi" yalnız kaynak + doğrulanmış izinle.
4. **Ekonomi sunucuda doğrulanır.** İstemcideki `EconomyService` yerel geliştirme cüzdanıdır (idempotent, atomik, negatif bakiye yok) — TypeScript sunucusunun (T049/T050) uygulayacağı sözleşmedir, güvenilir değildir.
5. **Referans kareleri/üçüncü taraf asset'leri ürüne koyma.** Video gözlemleri `G##` kodlarıyla izlenir (`docs/reference/GEREKSINIM_IZLENEBILIRLIK.csv`).
6. Videodan doğrulanmayanları (paket olasılıkları, rank oranları, netcode, eşleştirme, çalım süreleri) FC kuralı gibi yazma; tasarım değerleri `PROTOTİP` etiketlidir.
7. Sırları (token, lisans, şifre) dosyaya/sohbete yazma. Unity lisansı GitHub Secrets'ta durur.

## Mimari
```
unity/Assets/_Game/
  Core/      saf C# (noEngineReferences): Domain, Catalog, Squad, Economy, Persistence, Sim, Match, Design
  Runtime/   Unity katmanı: GameApp, UI (kodla kurulan uGUI), ekranlar, FieldWorld/FieldHud/FieldController
  Editor/    BuildScript (CI APK), menü komutları
  Tests/EditMode/  NUnit — hem Unity Test Framework'te hem `dotnet test` ile çalışır
  Resources/Content/  sürümlü JSON: players.v1, cards.v1, campaigns.v1
tests/Core.Tests/   Core + EditMode testlerini Unity'siz çalıştıran .NET projesi
tools/              catalog üretici/doğrulayıcı, görev üretici, compile-check (UnityEngine referanslı yaklaşık derleme)
```
- UI, domain, girdi ve simülasyon ayrıdır: `Core.Sim.ControlField` (tek futbolcu) ve `Core.Sim.MatchWorld` (5v5, iki takım AI) deterministik saf C#'tır (sabit 1/60 sn adım); Unity yalnız çizer ve girdi besler (`Runtime/FieldSource` ikisini ortak yüze indirger). Aynı kod ileride yetkili maç sunucusunda (T083) yeniden kullanılabilir.
- UI sprite/prefab'sız, kodla kurulur; renkler `Core.Design.DesignTokens` (tek kaynak).
- Newtonsoft.Json: kalıcılık ve içerik. `ObjectCreationHandling.Replace` zorunlu (koleksiyon ikilenmesi hatası testle yakalandı).

## Komutlar
```bash
python3 tools/generate_catalog.py     # katalog JSON'larını üretir (deterministik)
python3 tools/validate_catalog.py     # 100 benzersiz oyuncu, geçersiz referans yok, vb.
python3 tools/gen_tasks.py [--check]  # TASKS.md'yi task_status.json'dan üretir / denetler
dotnet test tests/Core.Tests/Core.Tests.csproj                 # çekirdek + EditMode testleri (Unity'siz)
dotnet build tools/compile-check/UnityCompileCheck.csproj      # Runtime kodu için yaklaşık derleme kontrolü
```
Unity'de: `unity/` klasörünü Unity Hub ile aç (2022.3.62f1) → menü `Kanarya → Sahneyi ve ayarları hazırla`.
APK: GitHub Actions → *Android APK* (bkz. `docs/ANDROID_APK_WORKFLOW.md`; Unity lisans sırları gerekir).

## Çalışma kuralları
- Önce testi/doğrulayıcıyı çalıştır, sonra "bitti" de. Yeni oynanış kuralı → `Tests/EditMode` içinde test.
- Katalog değişikliği → `tools/generate_catalog.py` içindeki `SPEC`'i düzenle, üret, `validate_catalog.py` + `dotnet test`.
- Görev durumu değişikliği → `tools/task_status.json` → `python3 tools/gen_tasks.py`.
- Her çalışma diliminde raporla: somut değişiklik, çalıştırma yöntemi, doğrulama kanıtı, açık engel, sıradaki görev kimlikleri (`PROGRESS.md`).
- Dal kuralı: geliştirme dalına commit/push; PR yalnız kullanıcı isterse.
