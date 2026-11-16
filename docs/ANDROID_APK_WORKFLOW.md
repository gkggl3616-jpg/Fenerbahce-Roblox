# Android APK — GitHub Actions ile derleme ve teslim

`.github/workflows/android-apk.yml`, Unity projesini (`unity/`) GameCI ile derleyip **APK** üretir, `Actions → koşu → Artifacts` altına yükler ve (main/etiket/elle) **GitHub Release** olarak yayınlar (telefondan doğrudan indirilebilir).

## Durum (dürüst özet)
- İş akışı GitHub'da gerçekten koştu (2026-11-16): `ci.yml` ve `verify` işi **geçti**; elle tetiklenen koşu (#2, run 43858524662) sırlar olmadığı için **bilerek kırmızı** bitti (`APK üretilemedi (lisans yok)`).
- **Unity derlemesi, ancak Unity lisans sırları eklenirse çalışır.** Bu geliştirme ortamında Unity ve lisans yok; bu nedenle `BuildScript` ve GameCI adımı **henüz hiç çalıştırılmadı/doğrulanmadı**. İlk gerçek koşuda ortaya çıkacak hatalar (kod, ayar, GameCI parametresi) beklenen bir sonraki adımdır.
- Sırlar yoksa APK üretilemez; iş akışı bunu açıkça bildirir (elle başlatılırsa kırmızı biter). Sahte/boş APK yüklenmez; APK < 1 MB ise koşu başarısız olur.

## Bir kerelik kurulum — Unity lisans sırları
GameCI, CI'da Unity'yi etkinleştirmek için lisans bilgisi ister. Depoda **Settings → Secrets and variables → Actions → New repository secret**:

### Kişisel (ücretsiz) lisans
1. Bilgisayarında **Unity Hub**'ı kur, Unity hesabınla giriş yap.
2. *Preferences → Licenses → Add → Get a free personal license* ile lisansı etkinleştir (bu `.ulf` dosyasını oluşturur).
3. `.ulf` dosyasını bul: Windows `C:\ProgramData\Unity\Unity_lic.ulf` · Mac `/Library/Application Support/Unity/Unity_lic.ulf` · Linux `~/.local/share/unity3d/Unity/Unity_lic.ulf`.
4. Sırlar: **`UNITY_LICENSE`** = `.ulf` dosyasının **tam içeriği**, **`UNITY_EMAIL`** = Unity hesap e-postası, **`UNITY_PASSWORD`** = Unity hesap şifresi.
5. Kopyaladıktan sonra Unity Hub'dan çıkış yap (kişisel lisans böylece iade edilir; yerelde seat tutmaz).

### Plus/Pro lisans
Sırlar: **`UNITY_SERIAL`** (`XX-XXXX-…`), `UNITY_EMAIL`, `UNITY_PASSWORD`. Hub'da lisansı CI'dan önce iade et.

> Kaynak: GameCI "Activation" belgesi. Hesap bilgisi yalnız Actions sırlarında durur; loglara yazılmaz, depoya konmaz. **Şifreyi sohbete veya dosyaya yazma.** Unity hesabında 2 adımlı doğrulama/lisans arayüzü değişirse GameCI belgesine bak; Kişisel `.ulf` yolu Unity'nin güncel sürümlerinde farklılık gösterebilir (doğrulanamadı).

## APK'yı üretme
1. Sırlar eklendikten sonra en kolay yol: **Actions → "Android APK" → son koşu (#2, elle başlatılan) → Re-run all jobs**. Bu koşu `publish_release=true` ile başlatıldığı için APK ayrıca **Releases**'e de konur.
   Alternatif: dala yeni bir `git push` (tetikleyen dallar: `main`, `ccr-**`, `v*` etiketleri) — dal `main` değilse yalnızca artifact yüklenir.
   *Run workflow* düğmesi, iş akışı dosyası **varsayılan dalda** olduğunda görünür (bu depoda şu an dosya yalnız `ccr-fd287559-z1tq0d` dalında); düğme için dalı varsayılan dala birleştirmek gerekir.
2. Koşu bitince: **Summary** sayfası APK boyutu, SHA-256 ve sürümü yazar. APK şurada: **Artifacts → `KanaryaFutbol-APK-<n>`** (zip içinde). Release açıksa **Releases** sayfasında `apk-<n>` (ön sürüm) olarak da bulunur.
3. Telefonda: APK'yı indir → "bilinmeyen kaynaklardan yükle" iznini ver → kur. APK **Unity varsayılan DEBUG anahtarıyla** imzalıdır (test içindir; mağaza yayını değil — T097/T102).

## Ne derleniyor?
- `unity/` projesi, Unity 2022.3.62f1, hedef Android API 24+, IL2CPP, ARM64, OpenGLES3, yatay.
- Giriş: `Fenerbahce.EditorTools.BuildScript.BuildAndroid` — boş açılış sahnesini kodla üretir, Player ayarlarını kodla yapar, `Assets/_Game/Scenes/Boot.unity` ile derler. Oyun, sahne bağımsız `GameApp` (RuntimeInitializeOnLoadMethod) ile kendini kurar.
- Sürüm: `0.1.<koşu no>`, versionCode = koşu no.

## Bilinen riskler (ilk koşuda beklenen)
- Gerçek Unity derlemesi, compile-check'in göremediği hatalar (Editor kodu, API farkları) bulabilir.
- GameCI özel `buildMethod`'a `-customBuildPath` verir; betik hem klasör hem dosya yolunu işler, ancak bu akış denenmedi.
- IL2CPP + ilk Library oluşturma uzun sürebilir (önbellek sonraki koşuları hızlandırır).
- `unity-editmode` işi gerçek Unity'de EditMode testlerini çalıştırır; ilk koşuda başarısız olabilir ve APK işini engellemez.

## Alternatifler
- Kendi bilgisayarında: Unity Hub → `unity/` aç → menü **Kanarya → Android APK derle**.
- Lisans sunucusu (`unityLicensingServer`) veya self-hosted runner: GameCI belgelerine bak.
