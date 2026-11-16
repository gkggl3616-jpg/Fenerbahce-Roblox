# PLAN — Kanarya Futbol: bundan sonra ne yapılacak

Hazırlanma: 2026-11-16. Girdi: ana prompt + 104 görev + **referans kare arşivinin 5 bölümünün tamamı** (bkz. `docs/EKRAN_SPESIFIKASYONU.md` Ek A) + bu depodaki gerçek durum (`PROGRESS.md`, `TASKS.md`). Bu belge bir **çalışma planıdır**; takvim taahhüdü değildir (tek geliştirici + Claude için süre vaat edilmez; dilim büyüklükleri göreli).

## 0. Üç cümlede
1. Referanslar önceki 75 gözlemi **doğruladı** ve üstüne **yeni sistemler** ekledi (seviye kilitleri, çoklu kadro kilidi, kayan bekleme süreli ücretsiz paket, reklam teklifleri, rol ekranı, otomatik değişiklik, maç hazırlığı karşılaştırması, uzatma süresi, paket özet ızgarası). Hiçbiri kapsamı değiştirmiyor; **104 görev kimliği korunuyor**, ayrıntılar ilgili görevlere işlendi.
2. Kritik yol *maçtır* (kontrol hissi → takım AI → tamamlanabilen maç → kalıcı ödül). Unity lisansı yokken de ilerlenebilen işler **saf C# çekirdekte** yapılır ve `dotnet test` ile kanıtlanır; Unity gerektiren her şey (görsel, his, kare süresi, APK) lisans gelince **toplu doğrulanır**.
3. APK'yı engelleyen tek şey **sizin Unity lisans sırlarınızı eklemeniz**; planın bundan sonrası buna bağlı değil, ama "tamamlandı" demek bağlı.

## 1. Şu anki gerçek durum
| Alan | Durum | Kanıt |
|---|---|---|
| Veri (100 oyuncu, 110 kart) | ✅ prototip denge verisiyle hazır, doğrulayıcılı | `validate_catalog.py`, CatalogTests |
| Çekirdek (kadro, ekonomi, kayıt, mağaza/takas kural çekirdeği, sim, maç durum makinesi, sonuç) | ✅ yazıldı ve **122/122 test** | `dotnet test`, GitHub Core CI yeşil |
| Kontrol sahası (1 oyuncu + kaleci + savunmacı) | ✅ sim testli; Unity katmanı yazıldı | derleme kontrolü geçti; **Unity'de hiç çalıştırılmadı** |
| Menü (ana merkez, kulüp, koleksiyon, oyna, ayarlar, sonuç) | ⚠️ kod var, **hiç görülmedi** | yalnız compile-check |
| 11v11 maç, kurallar, tekrar | ❌ yok | TASKS T041–T047 |
| Mağaza/takas/etkinlik/bilet/pazar **ekranları** | ❌ yok (kural çekirdeği kısmen var) | |
| Sunucu (TypeScript+Postgres), çevrimiçi | ❌ yok | |
| APK | ❌ **üretilmedi** (lisans sırları yok) | Actions run 43858524662 |
| Portreler, animasyon, ses | ❌ yok (siluet, kapsül gövde) | |

Görev sayıları: 14 DONE · 33 IN_PROGRESS · 57 TODO (`TASKS.md`).

## 2. Sizden gerekenler (engeller ve kararlar)
| # | Konu | Neden | Ne yapmanız gerekiyor | Beklerken ne yapıyorum |
|---|---|---|---|---|
| B1 | **Unity lisans sırları** | APK + Unity'de hiçbir şeyin doğrulanması bunsuz olmaz | Depo *Settings → Secrets and variables → Actions*: `UNITY_LICENSE` (+`UNITY_EMAIL`, `UNITY_PASSWORD`) veya `UNITY_SERIAL`. Adımlar: `docs/ANDROID_APK_WORKFLOW.md`. **Şifreyi sohbete yazmayın.** | S1–S9 (Unity'siz) |
| B2 | **Hedef cihaz(lar)** | T007/T033: 30/60 FPS hedefi ölçülmeden anlamsız | Test edeceğiniz telefon model(ler)i (RAM, Android sürümü) | Taslak bütçe D-007 |
| B3 | **Portre / isim hakları** | 100 gerçek futbolcu adı + fotoğraf ticari yayında hukuki risk (T003/T091) | Hangi kaynaktan fotoğraf kullanılacak / yalnız ad + özgün çizim mi? | Siluet + izin matrisi |
| B4 | Ürün adı | "Kanarya Futbol" çalışma adı; paket kimliği `com.kanaryafutbol.game` | Yayın öncesi karar | Çalışma adıyla ilerleme |
| B5 | Sunucu altyapısı (S9) | Supabase hesabı var mı, yoksa düz PostgreSQL + kendi sunucu mu? | Tercih | Yerel docker-compose ile başlanır |
| B6 | Açık soru (T027) | Referanstaki savunma ekranındaki **`OTO.`** düğmesinin işlevi karelerden anlaşılmıyor | Oyunu biliyorsanız bir cümle | Kural uydurulmaz |
| B7 | Referans | **Bölüm 1/5 geldi**; 4/5 iki kez gönderildi. Başka video/ses varsa isteğe bağlı | — | — |

## 3. Referanstan çıkan kapsam eklemeleri → görevler
| Gözlem (Ek A) | Bizde yapılacak | Görev | Dilim |
|---|---|---|---|
| Özellik × seviye kilidi (`KİLİTLİ! Açmak için 10. Seviyeye Ulaş!`, soluk sekme) | `FeatureGates` (içerikten), kilit modalı | T010, T012 | S4 |
| Çoklu kadro: 3 plan, `AKTİF`, 15. seviye + mağaza ile açılır | `SquadPlan` listesi, kilit kuralı | T038 | S4 |
| Diziliş: ≥12 diziliş + stil soneki (`Atak/Düz/Dar/Geniş`), `Defansif/Önerilen` etiketi | diziliş içeriği genişlemesi (3 başlangıç korunur) | T035 | S4 |
| **Roller:** Kaptan, Yakın/Uzak Serbest Vuruş, Sol/Sağ Korner, Penaltı + `VARSAYILAN` | 6 rol modeli (şimdi 4), varsayılan atama | T038 | S4 |
| `Oto. oyc. değişikliği` anahtarı | ayar + AI karar kuralı | T038, T088 | S4/S12 |
| **Maç hazırlığı:** ATAK/ORTA SAHA/DEFANS karşılaştırma, kupa+derece, kaynak yükleme çubuğu | kadrodan hat gücü hesabı + ekran | T046, T014 | S3/S10 |
| Kadro tanıtımı, tünel, geri sayım `3`, kulüp renkli geçiş perdesi | sunum (atlanabilir) | T046, T092 | S10 |
| **Uzatma süresi** `+2`, süre kutusu, gol şeridi (golcü+dakika) | `MatchStateMachine` uzatma + HUD | T043, T047 | S3 |
| Korner ipucu `Köşe vuruşu için oyuncuya dokun.` | duran top kontrol modeli | T044, T045 | S2 |
| Sonuç: şut(isabet), sahip olma, pas isabeti, faul, ofsayt, golcüler, derece, `DEVAM ET` | ✅ çekirdek yapıldı; faul/ofsayt kurallarla dolacak | T048 | S2/S3 |
| **Ücretsiz paket "her 12 saatte bir yenilenir"** (kayan bekleme) | `LimitPeriod.Cooldown` | T065 | S6 |
| **Reklam teklifleri** (günlük/haftalık limitli, mağazada) | doğrulanmış ödüllü reklam sözleşmesi | T099 | S6 |
| Mağaza: sekmeler+kategori, limit/süre/çift fiyat/kilit, `%50 İNDİRİMLİ` etiketi | ✅ kural çekirdeği var; indirim etiketi = *içerik alanı* (hesap yok) | T065 | S6/S10 |
| **Etkinlik dükkanı** (etkinlik puanıyla satın alma) | ikinci para birimi + teklif | T064, T065 | S7 |
| Paket sahnesi: **bayrak → mevki → program rozeti → kart**, 3+ sahne şablonu, özet ızgarası, **düşük kartları toplama (`x10`)** | `PackOpening` sonuç + sahne dizisi verisi + şablonlar | T066–T069 | S6/S10 |
| Takas: koşul sayacı, limit, süre, hızlı ekle, uyarı | ✅ çekirdek yapıldı | T072–T073 | UI: S10 |
| Etkinlik haritası: sekmeler, düğüm türleri, **Yarı Final yol seçimi (`VS`)**, önkoşul | düğüm grafiği + yol seçimi | T060–T061 | S7 |
| Günlük/haftalık görev + **kilometre taşı** (`100/100 → AL`) | olay tabanlı görev + milestone | T062–T063 | S7 |
| Yıldız Bileti: ücretsiz/premium paralel, `TÜMÜNÜ TOPLA`, süre | bilet çekirdeği | T070–T071 | S7 |
| Antrenman: `AXP` (kart başına verilen XP), `0/25`, seviye aktarımı, önizleme; takasta aktarım kaybı uyarısı | antrenman çekirdeği (kendi kuralımız) | T053–T054 | S5 |
| Derece yükselt: kaynak yuvaları, `Antrenman Maçı`, `İlerleme x/50`, başarı ekranı | **kendi** kuralımız (olasılık videodan bilinmez) | T055 | S5 |
| Beceri geliştirici: seviye/XP/maliyet, `POZİSYON BONUSU +N GEN`, **etkilenen oyuncular** | kalıcı geliştirme (çalımdan ayrı) | T056 | S5 |
| Çalım ekranı: 4 slot, jest oku, `N Oyuncu`, `Etkinleştirildi` | slot/donatım + 3 çalım daha | T057–T058 | S5 |
| Pazar: sekmeler, **arama (ad+GEN aralığı+program+…)**, SAT penceresi (grafik, düzenlenebilir fiyat, komisyon) | emir/emanet/eşleştirme + arama modeli | T077–T080 | S8 |
| Mod merkezi: karşı-türe göre renkli şeritler, her modun kendi derece/puan birimi | mod başına ayrı puan | T089 | S12 |
| Seviye+XP başlığı, günlük giriş, bildirim noktaları | profil ilerlemesi + rozetler | T012, T015 | S4/S10 |

**Bilerek yapmayacaklarımız** (kanıt yok / hukuki / kapsam dışı): "VALUE %" rozeti hesabı, rank başarı olasılıkları, paket olasılıkları (kendi tablomuz), kimya/bağlantı sayaçları (`Juventus 2`…; kural doğrulanamadı → D-026), gerçek para (`FIFA POINTS`, ₺) MVP'de, referans sanat/ikon/kare kopyası, resmî arma/forma, "Pepsi/EA" gibi panolar (özgün pano yapılacak).

## 4. Strateji
- **İki iz.** *Unity'siz iz* (saf C# çekirdek, `dotnet test`, Python doğrulayıcılar, TypeScript sunucu): şimdi ilerler, kanıtı üretilebilir. *Unity'li iz* (UI, 3B, his, APK, cihaz): lisans gelince **tek sprintte** doğrulanır; o güne kadar yalnız kod yazılır ve `compile-check` ile korunur.
- **Kesme kuralı:** lisans sırları eklendiği an **S10a (Unity ilk ışık)** her şeyin önüne geçer: ilk APK koşusu, Unity'de EditMode testleri, açılışta menünün görülmesi, kontrol sahasının telefonda denenmesi. Orada çıkacak hatalar (BuildScript, GameCI, asmdef, UI yerleşimi) tahmin edilen riskli alandır.
- **Kritik yol:** kontrol hissi → takım AI (S1) → 11v11 + kurallar (S2) → tam maç + sonuç (S3) → kalıcı ödül/ekonomi (S5–S8) → sunucu (S9) → çevrimiçi (S11) → performans/yayın (S12–S13). Ekonomi dilimleri (S5–S8) birbirinden bağımsızdır; sıra değişebilir.
- **Doğrulama zorunluluğu:** her dilim (a) yeni test, (b) **mutasyon denemesi** (kuralı bozunca testin kırıldığını göster), (c) `validate_catalog.py` / `gen_tasks.py --check`, (d) GitHub Core CI yeşil. Bunlar olmadan görev `DONE` olmaz.

## 5. Dilimler
Boyut: **S** ≈ birkaç saatlik çalışma · **M** ≈ yarım–bir gün · **L** ≈ birkaç gün · **XL** ≈ hafta. (Göreli; Unity hataları ve içerik hukuku bunları uzatır.)

| Dilim | Amaç | Görevler | Teslim (somut) | Doğrulama | Unity? | Boy |
|---|---|---|---|---|---|---|
| **S0** | Sizden: lisans + cihaz + karar listesi | T004, T007 | Secrets eklendi, cihaz listesi | İlk Actions koşusu (S10a) | — | — |
| **S1** | **5v5 takım AI + oyuncu değiştirme** | T041, T026, T023 | `Core/Sim`: takım rolleri (destek koşusu, savunma yerleşimi, pas kanalı kapatma), `DEĞİŞTİR` (en yakın/ pas hedefi), 5v5 headless sim | AI yığılmıyor (ikili mesafe/yayılım metrikleri), pozisyon bağlılığı, 1000 maç deneyinde hata/NaN yok, deterministik tekrar; GEN farkı sonucu etkiliyor ama belirlemiyor | Hayır | L |
| **S2** | **11v11 + kaleci + kurallar** | T042, T044, T045 | 11v11 sim, aut/taç/kale vuruşu/korner/faul+sarı/ofsayt/penaltı/serbest vuruş, **uzatma süresi**, rol sahipleri (6 rol) kullanılır | Senaryo testleri (her kural için), 11v11 headless hız ≥ gerçek zamanın 30 katı (CI ölçer), 100 simüle maçta skor dağılımı makul (PROTOTİP hedef: ortalama 1,5–3,5 gol, kırmızı kart nadir) | Hayır | XL |
| **S3** | **Tam maç akışı + sonuç + tekrar verisi** | T043, T046, T047, T048 | Hazırlık→giriş→santra→devre→bitiş→sonuç; **maç hazırlığı hat gücü (ATAK/ORTA SAHA/DEFANS)**; olay kaydından tam istatistik (faul, ofsayt dahil); son N sn konum kaydı (tekrar verisi) | Durum makinesi + olay kaydı testleri, istatistikler yalnız olaydan, tekrar skoru/ödülü değiştirmez | Hayır (sunum S10) | L |
| **S4** | Kadro/plan/rol genişletmesi + **FeatureGates** | T035–T038, T010, T012 | ≥12 diziliş içeriği, 6 rol + `VARSAYILAN`, 3 kayıtlı plan (kilitli yuvalar), oto değişiklik ayarı, seviye kilidi sistemi | Kadro testleri, kilit kuralı testleri, kayıt/yükleme | Hayır | M |
| **S5** | **Gelişim çekirdeği** | T053–T058 | Antrenman XP + önizleme + tüketim, aktarım, **rank (kendi kuralımız)**, kalıcı beceri geliştirme + pozisyon bonusu + etkilenen oyuncular, çalım slotları/donatım, 3 çalım daha (sim) | Atomiklik/idempotency testleri, kilitli/kadrodaki kart engeli, önizleme = sonuç eşitliği | Sim kısmı Hayır | L |
| **S6** | **Paket + mağaza tamamlama** | T065–T069, T099 | `Cooldown` ücretsiz teklif, reklam teklifi sözleşmesi, `DropTable` (toplam=1, sürüm sabit), garanti sayacı, `PackOpening` (idempotent, kesilirse aynı sonuç), sahne dizisi verisi (bayrak→mevki→program→kart), özet + düşük kart toplama | Olasılık toplamı testi, 10⁵ çekiliş dağılımı ≈ tablo, çifte istek/kopma testleri | Hayır (sahne S10) | L |
| **S7** | **Etkinlik/görev/bilet** | T059–T064, T070–T071, T090 | Etkinlik takvimi (UTC), düğüm grafiği + önkoşul + yol seçimi, olay tabanlı görevler + milestone, etkinlik puanı/dükkan, Yıldız Bileti (ücretsiz/premium), 5 özgün etkinlik **veri** olarak | Aynı maç olayı iki kez ilerletmez, çift claim yok, sezon bitişi | Hayır | L |
| **S8** | **Pazar** | T077–T080 | Emir, emanet (kart satış süresince harcanamaz), eşleştirme, **yapılandırılabilir** komisyon, iptal, fiyat geçmişi, arama modeli | Eşzamanlı emir testleri, tek transaction kart+coin devri | Hayır | L |
| **S9** | **Sunucu iskeleti** | T049, T050, T074, T075 | TypeScript API + PostgreSQL: auth/profil/envanter, cüzdan+ledger+idempotency, paket/takas/mağaza uçları; **ortak altın dosyalar** (C# ve TS aynı senaryoları geçer) | vitest + sözleşme testleri, iki hesap birbirinin kartını okuyamaz, CI işi | Hayır | XL |
| **S10a** | **Unity ilk ışık** (lisans gelince) | T004, T033 | İlk APK, Unity'de EditMode testleri, menünün görülmesi, kontrol sahasının cihazda denenmesi, ekran görüntüleri, kare süresi | Gerçek build + cihaz kaydı | **Evet** | M–L |
| **S10b** | **Unity UI sprinti** | T009–T016, T039–T040, T053–T058, T060–T072, T077–T080 (ekranlar), T068, T092 | Spesifikasyona göre Mağaza/Takas/Etkinlik/Bilet/Gelişim/Pazar/Kadro v2 ekranları, paket sahnesi (3 şablon), kulüp renkli geçiş perdesi, safe area, Türkçe taşma testleri | Cihazda ekran görüntüleri + tıklama akışı | **Evet** | XL |
| **S11** | **Çevrimiçi** | T032, T081–T086 | Netcode denemesi, arkadaş/davet, yetkili maç sunucusu (`Core.Sim` headless), eşleştirme, yeniden bağlanma | 50/100/200 ms, jitter, kayıp, kopma, çifte sonuç testleri | Kısmen | XL |
| **S12** | Modlar, rekabet, sanat, ses, optimizasyon | T087–T096, T088 | Karşı Atak, Teknik Direktör, sezon/rank (mod başına puan), 100 portre, forma/arma/stadyum, ses, LOD/atlas/bellek, 20 dk oturum | Cihaz ölçümü | **Evet** | XL |
| **S13** | Ödeme, operasyon, yayın | T097–T104 | Mağaza SDK + makbuz, hesap bağlama, log/crash, beta, kademeli yayın | Makbuz tekrarı, restore, geri alma planı | **Evet** | XL |

**Sıra önerisi (Unity'siz iz, şimdiden):** S1 → S2 → S3 → S4 → (S5, S6, S7, S8 öncelik sırasına göre) → S9. Lisans gelirse S10a araya girer.

## 6. Kapı A — "gerçek cihazda oynanabilir dikey dilim" ölçütleri
Gerçek bir maç oynanır → sonuç olay kaydından türer → ödül **sunucu işlemiyle** envantere geçer → yeniden açılışta kadro/envanter korunur. Kapı A'yı **ancak** şunlar birlikte karşılar:
1. S1–S3 (11v11 maç + sonuç), S4 (kadro), S9'un cüzdan/ledger/envanter parçası, S10a (cihaz).
2. Cihazda 20 dk oturum: çökme yok, ısı/bellek kaydı var.
3. Menü → kadro → maç → sonuç → ödül → kayıt döngüsü telefonda tamamlanır (T052).
Bunlardan biri eksikse "tamamlandı" denmez.

## 7. Test ve kanıt stratejisi
- **Birim + senaryo:** NUnit (`Tests/EditMode`), `dotnet test` (Unity'siz) + Unity'de aynı dosyalar.
- **Özellik/oran testleri:** kontrollü deneme (nitelik farkı sonucu etkiler ama belirlemez), seed'li 10³–10⁵ koşu.
- **Mutasyon denemesi:** kritik kural bozulup testin kırıldığı gösterilir (bu turlarda yapıldı; 3 denemeden 2'si kırdı, 1'i kodda ikinci güvence bulunduğu için kırmadı — bilinçli not).
- **Altın dosyalar:** C# ve TypeScript aynı JSON senaryolarını geçmeli (S9).
- **compile-check:** Core ve Runtime ayrı derleme (asmdef sınırı). Gerçek Unity derlemesinin yerini tutmaz.
- **CI:** `ci.yml` (lisanssız, her push) + `android-apk.yml` (lisanslı). İlk Unity koşusunda hata çıkması normaldir.
- **Cihaz:** T033/T094/T095: kare süresi, 20 dk oturum, ısı, bellek.

## 8. Riskler
| Risk | Olasılık/etki | Önlem |
|---|---|---|
| Unity ilk derlemesinde beklenmedik hatalar (Editor betiği, asmdef, uGUI yerleşimi) | Yüksek / orta | S10a ilk iş; küçük adımlarla; compile-check azaltır ama kaldırmaz |
| 11v11 AI "yığılma"/saçma oyun | Yüksek / yüksek | S1'de 5v5'ten başla; metriklerle (yayılım, pas kanalı) gate'le |
| Kontrol hissi (dokunmatik) kötü | Orta / yüksek | T033 cihaz denemesi; ayarlar (hassasiyet/ölü bölge) zaten var; gerekirse sürükle-pas |
| Portre/isim hakları | Yüksek / yüksek (ticari) | B3 kararı; siluet ile devam; izin matrisi |
| Ekonomi istemcide kandırılabilir | Kesin / yüksek | S9 sunucu; o zamana kadar yalnız geliştirme cüzdanı |
| Kapsam şişmesi (referans çok geniş) | Yüksek / orta | 104 kimlik sabit; her dilim kabul ölçütüyle sınırlı |
| Tek geliştirici + Claude için süre belirsizliği | Kesin / orta | Takvim vaadi yok; dilim büyüklükleri göreli |

## 9. Hemen sonraki adım
**Siz:** B1 (lisans sırları) ve B2 (cihaz). **Ben (onay beklemeden, Unity'siz):** **S1 — 5v5 takım AI + oyuncu değiştirme**: `Core/Sim/TeamAI`, `Team`, `MatchWorld` (iki takım), yayılım ve yığılma metrikleri, `dotnet test`, mutasyon denemesi; ardından S2.
Önceliği değiştirmek isterseniz (örneğin ekonomi/UI'yi maçtan önce) söylemeniz yeterli; sıra §5'te serbest bağlı.
