# Ekran spesifikasyonu — referans karelerden çıkarılan ayrıntılar

Kaynak: kare arşivi bölümleri 2/5–5/5, **anahtar kareler 2× büyütülerek** okundu (V01–V04). Bu belge *gözlem* içerir; bizim oyunun kuralı değildir. Kural/tasarım kararları ayrıca **TASARIM** diye işaretli. Metinler karelerde görüldüğü gibidir (360p; okunamayan değer yazılmadı). Referans görseller/ikonlar ürüne alınmaz; yalnız yapı ve davranış alınır.

Kısaltma: V0x mm:ss = kaynak video zamanı. G## = `GEREKSINIM_IZLENEBILIRLIK.csv` kodu.

## 0. Ortak kalıplar (tüm ekranlarda)
- **Başlık çubuğu:** sol üstte yuvarlak geri düğmesi (‹), yanında ekran adı (BÜYÜK HARF, kalın). Eski sürümde (V03) sağ üstte: coin (`141.373.237`, yanında + simgesi), cevher (`12.060`, +), jeton/puan (`0`, +), sepet, hedef, ev simgesi. Yeni sürümde (V02/V04) tek para birimi rozeti + bildirim + sepet + ev.
- **Sayı biçimi (TR):** binlik ayraç nokta (`1.329.300.000`, `408.600`); kısaltma **B = bin**, **Mln = milyon**, ondalık virgül (`408,6B KUPA`, `2,491Mln KUPA`, `15,0B`).
- **Süre biçimi:** `HH:MM:SS` (saat 24'ü aşabilir: `25:44:04`, `36:37:51`) ve uzun sürelerde gün (`6 GÜN`, `24 GÜN`, `45 GÜN`, `122 GÜN`). Etiket: `Kalan süre:` / `KALAN SÜRE:` / `YENİLENME:` / `SEZON SONU: 6 GÜN`.
- **Etiketler:** kırmızı `YENİ`, `ÜCRETSİZ`, `SATILAMAZ` (kart üstü), `BONUS`, `LİMİTE ULAŞILDI` (soluk + onay işareti), kilit simgesi (koşul sağlanmadı), zaman simgesi (süreli).
- **Sekmelerde rozet:** `9+` kırmızı sayaç; kenar çubuğunda kırmızı nokta.
- **Birincil eylem düğmeleri:** yeşil (`TAKAS`, satın alma), camgöbeği (`HIZLI EKLE`, `DEVAM ET`), kontur (`UZAKLAŞTIR`); pasif durum gri.
- **Bağlantı göstergesi:** başlıkta ping (`60ms`, yeşil) çevrimiçi modlarda.

## 1. Ana ekran (G01–G05)
Sol dikey ikon rayı (görevler, bilgi, bilet, kazanç…), orta büyük oyuncu görseli, sağda dönen kampanya kutusu (noktalı gösterge, `HEMEN GİT`/`GİT` çağrısı), altında `KULÜP` (GEN rozeti + arma) ve `OYNA` kutuları; alt gezinti: GÖREVLER · LİGLER · PAZAR · TAKAS · MAĞAZA (V04) / TRANSFERLER · TAKAS · MAĞAZA (V02). Eski sürümde ek: `TEKLİFLER`, `CANLI ETKİNLİKLER`, `DIVISION RIVALS` (NEW). Kulüp kutusu o anki kadronun GEN değerini ve diziliş adını taşır (`4-3-3 Rölanti`, `4-2-3-1 Geniş`).

## 2. Kulüp ve kadro (G06–G13)
- **Kulüp menüsü (V04 07:18):** solda "TAKIMIM" önizlemesi (diziliş adı, GEN rozeti, minyatür saha), sağda üç kutu: `OYUNCULAR`, `TAKAS`, `SOYUNMA ODASI` (kırmızı nokta). V02: `PAZAR`, `OYUNCULAR`, `SOYUNMA ODASI`, `TAKIM ARMASI` (YENİ).
- **Takımım (V04 08:01):** sol panel: açılır `TAKIMIM` (plan seçici), arma, GEN rozeti, `4-3-3 Rölanti`, takım değeri `1.329.300.000`; düğmeler `OTOMATİK KUR`, `YEDEKLER`, `TAKIM DÜZENLEME`; sağda saha, her kartın altında **mevki rozeti** (SLK, SNT, MO, MDO, SLB, STP, SGB, KL), yedek yuvaları sahanın altında. V02: ek `OYUN PLANLARI`, simge ve değer, üç rol/başarı rozeti.
- **Oyuncu listesi (V02 02:20):** `GEN ↓` sıralama açılırı + `FİLTRE`; 3 sütun kart ızgarası. Seçili kart için bağlam düğmeleri: `DEĞİŞTİR`, `BİLGİLER`, `ANTRENMAN`, `DERECE YÜKSELT`, `BECERİ PUANLARI`, `ANTRENMAN AKTARIMI`.
- **Yıldız/Oyuncularım listesi (V02 04:00):** her kartın altında coin değeri; `İlk 11'de` etiketli kart soluk; altta `OTOMATİK SEÇ` ve `SERBEST BIRAK` + toplam kazanç (`0`).

## 3. Oyuncu detayı (G15–G19, G25–G27)
- **V03 (08:53):** kart (GEN, mevki, ülke bayrağı, isim), kilit ve forma simgeleri; `ÖGEYİ KİLİTLE` anahtarı; `KULLANDIĞI AYAK` (5 ayak puanı), `DAYANIKLILIK` çubuğu, `BECERİ HAR.` yıldızlar, `DEĞER` (satılamazsa 🚫); orta `ÖZET`: büyük **GEN 117** halkası, `OYUNCU GEN 108`, `DERECE YÜKSELTME 0`, `BECERİ GELİŞTİRME +9`; altı nitelik halkası **HIZ · ŞUT · PAS · DRİ · DEF · FİZ**; sayfalama `ÖZELLİKLER / NİTELİKLER`; sağ `BECERİ GELİŞTİRİCİLERİ` (rozet, `POZİSYON BONUSU` satırları `+10 GEN`, ilerleme `127 / 250`), `OYUNCU KARTI` (kulüp/lig/ülke/ikon zinciri: `Juventus 2`, `Serie A TİM 4`, `İtalya 3`, `İkonlar 2`); `ÇALIŞTIR` düğmesi.
- **V02 (gecis 37):** `KARŞILAŞTIR` düğmesi; boy/kilo/yaş/tercih edilen ayak/ülke/lig; altı nitelik (**HIZ, ŞUT, PAS, DRİBLİNG, SAVUNMA, FİZİK GÜCÜ**), düşük nitelik sarı; `Antrenman seviyesi 0/30` + `ANTRENMAN`; `Derece Yükseltme Seviyesi` (5 üçgen) + `DERECE YÜKSELT`; `OyunTarzları`, `Beceriler` + `DÜZENLE`; alt sekmeler: …, `OYUNTARZLARI`, `ÖZELLİKLER`, `TRANSFER` (kilitliyse pasif).
- **Beceri geliştirici (V03 08:20):** rozet + seviye `10`, `GELİŞT. BONUSU +10 GEN`, `SEVİYE 10 / 20`, `143 / 250 BECERİ GELİŞTİRİCİLERİ`, `SEVİYE ATLA ⛁ 300.000`; `GELİŞTİRME` şeridi (+15 Top sürme, +15 Orta açma, +10 Üstünlüğü, +5 Uzaktan şut, +5 Çeviklik); **`ETKİLENEN OYUNCULAR`** ayrı iki liste: ilk 11 / yedek.

## 4. Çalım ekranı — "BECERİ HAREKETLERİ" (G23, G24)
Sekme `BECERİ HAREKETLERİ`. Üstte önizleme paneli: hareket adı + yıldız, `1. BÖLME` ve `DENE` düğmeleri, oynat düğmeli video, sağda **giriş jesti** göstergesi (`SPRİNT VE BECERİ` düğmesi çevresinde yön okları). Altta dört slot: **numara (1–4)**, hareket adı, yıldız gereği, `N Oyuncu` (hareketi kullanabilen oyuncu sayısı), yön oku (slotun jesti: ←, ↑, →, ↓), `Etkinleştirildi` anahtarı. Görülen: Yön Değiştirme ★4 (9 oyuncu), Topuk Hareketi ★3 (11), Topu Kaldırma ★1 (12), Rahat Feyk Şut ★1 (12).

## 5. Gelişim (G20–G22)
- **Antrenman yükseltmesi (V03 11:08):** sol kart + `ANTRENMAN SEVİYESİNİ AKTAR ›`, `ANTRENMAN SVY: 0 → SVY: 1`, `ANTRENMAN XP'Sİ 0 / 25`, − / + düğmeleri, `YÜKSELTME ÖNİZLEMESİ`; sağ başlık `YÜKSELTME İÇİN HARCANACAK ORTA SAHA OYUNCUSUNU SEÇ`, 4 sütun kart ızgarası, **her kartın altında `AXP: 80/85`** (verdiği XP), süzme düğmesi.
- **Derece yükselt (V04 07:44):** sol: kart, `Derece Yükseltme seviyesi` (5 üçgen), `Antrenman Maçı 5`, `Beceri Puanları 0`, `İlerleme 0/50` + çubuk; sağ: 4 kaynak yuvası (dolu yuva kilit simgeli), `DERECE YÜKSELT` pasif; (i) bilgi düğmesi; başarı ekranı `Başarılı — Derece Yükseltme seviyesi`.

## 6. Etkinlikler ve görevler (G48–G52)
- **Liste (V03 00:42):** dört boy poster kart; başlık + mavi alt açıklama (`LİG TURU — Her gün 1 yeni ligle yenilenir!`, `GÜNLÜK ANTRENMAN — Normal Mücadele`, `İKON SERÜVENLERİ — Bir İkon Oyuncu kazan!`, `GÖREV MODU — Şampiyon ol!`), durum şeridi (`Müsabaka yok`, `KALAN SÜRE: 45 GÜN`).
- **Harita (V03 01:40):** sekmeler `ANA · ÖDÜL YOLU · OYUNCU TAKASI · YARI FİNAL`; yatay kaydırmalı düğüm haritası: yuvarlak düğüm, **tamamlandı** (yeşil onay), **kilitli** (kilit), **süreli** (zaman simgesi), numara rozeti + sayaç (`3 0/1`, `4 2/1`); merkezde `GÖREVLER` ve `GÖREV MODU`; ödeme/reklam düğümü (sepet); sağ panel `Şampiyonluk Yolu / GRUP AŞAMASI` düğüm sütunu.
- **Günlük görevler (V03 02:20):** sol dikey kategori simgeleri; orta liste `GÜNLÜK GÖREVLER — YENİLENME: 01:44:04` (boşsa `Yeni Görevler için yarın tekrar gel!`); sağ **kilometre taşı ödülleri**: `GÜNLÜK ÖDÜLLER` (i) + `YENİLENME` + `İLERLEME 100 / 100` çubuk + `AL`; `HAFTALIK ÖDÜLLER` aynı yapı (`700 / 700`, `YENİLENME: 25:44:04`); `AL` hak kazanılmadıkça pasif. Görev satırı: açıklama (`Golcü: Herhangi bir modda en az 3 gol farkla 1 maç kazan`), ödül puanı, onay ✓.

## 7. Futbol Merkezi / Taraftar Merkezi (G53, G54)
Sekmeler `MÜSABAKA · ÖDÜLLER · TOTW · POTM`. **Müsabaka:** `1. Maç` + yönerge (`Aşağıdaki maçı oynayarak iki canlı GEN oyuncularından birini al.`), iki ülke arması `VS`, iki ödül adayı kartı, `OYNA` düğmesi (onay işaretli), kilitli/süreli takas simgesi; 2. maç kartı yan tarafta kaydırılır. **Ödüller:** `PUAN TAKASI` (kart `112 → …` + `TAKAS`), `KAYNAKLAR` (sepetli yuvalar). **POTM:** `AYIN OYUNCUSU` + `Kadronu güçlendirmek için ayın en iyi oyuncularıyla takas yap!`; dört kart, her birinin altında `TAKAS`.

## 8. Sezon bileti (G55, G56)
`YILDIZ BİLETİ — UCL 22-23`; üstte turuncu şerit `SVY36 2962/3000` (XP) + `SERİNİN BİTMESİNE KALAN SÜRE: 24 GÜN` + (i). **İki paralel şerit:** üstte `PREMIUM` (büyük ödül kartı + `SATIN AL`), altta `ÜCRETSİZ`; ortada seviye çizgisi (35, 36, 37, …, 50), tamamlanan seviyeler dolu, mevcut seviye vurgulu; her seviyede iki ödül (`x250`, `x300.000`, `x1` …), gizemli ödül `?`; sağda büyük 50. seviye ödülü; `TÜMÜNÜ TOPLA`. Mağazada bilet teklifleri: `PREMİUM BİLETİ ₺129,99`, `PREMİUM BİLETİ DESTESİ ₺279,99`, `FANTEZİ BİLETİ ⛁1.000 (Kalan süre: 3 GÜN)`.

## 9. Mağaza (G57–G60)
Başlık `MAĞAZA`; üst sekmeler (`ÖNERİLEN`, `FC POINTS ve CEVHERLER`, `TAKASLAR` + rozetler); sol kategori çubuğu (`ÖNE ÇIKAN`, `EN ÇOK SATAN`, `EN İYİ ETKİNLİKLER`, `YILDIZ BİLETİ`; eski sürümde `HOŞ GELDİN TEKLİFLERİ`, `SINIRLI TEKLİF`, `KAHRAMANLAR`, `FANTEZİ`). **Teklif kartı:** başlık; **limit satırı** (`Satın Alma Limiti: 2` / `Günlük Limit: 1` / `Haftalık Limit: 30`); `YENİ` etiketi; değer rozeti (`300% VALUE`); sanat; **fiyat satırı** tek veya çift para birimi (`2.000` veya `500 / 7.500`); alt çizgi `Kalan süre: 12:37:51`. **Durumlar:** `LİMİTE ULAŞILDI` (soluk + onay), **kilitli** (kilit + koşul metni: `Satın aldığında her 10 Copa…`), `ÜCRETSİZ`. Eski sürümde mağaza para gerçek (₺) ve oyun içi para birimi karışık.
- **Paket detayı (V04 01:15):** sol paket kartı + değer rozeti + **iki yeşil satın alma düğmesi** (her biri `fiyat` + `0/1` kullanım sayacı); sağ `PAKET İÇERİĞİ` → `GARANTİ ÖDÜLLER` (kutu + adet: `Temel Oyuncu x2`, `Jeton x100.000`, `BONUS EURO Oyuncusu x1`) → `OLASI ÖDÜLLER:` + uyarı **"Öğeler yalnızca betimleme amacıyla gösterilir, hiçbiri garanti edilmez."** + 5 kart, her birinde `SATILAMAZ`.
- **Paket açılış akışı:** `AÇMAK İÇİN DOKUN` → geçiş perdesi (paket adı üstte) → ülke bayrağı → stadyum tüneli/arena walkout (havai fişek, arma) → kart gösterimi (`Şu Anki Değer ⛁ 47.400.000`) → `TEKRAR İZLE` + `DEVAM ET`; toplu: `TÜMÜNÜ AÇ`; `Bonus Satılamayan Oyuncu` ayrı sahne.

## 10. Takas (G65–G68)
Başlık `TAKAS`; sol: `Takas Ödülleri: EURO Yıldız Oyuncu x2`, ödül kartı (aralık: `94-98`), `Limit: 0 / 5`, `Kalan süre: ⏱ 12:34:50`, yeşil `TAKAS`; sağ `TAKAS KOŞULLARI`: her satırda örnek kart + koşul metni (`94+ GEN Oyuncu`, `90+ GEN Oyuncu`) + **sayaç** `3/3` (yeşil = sağlanan); uyarı **"Bir takas yaparken antrenman seviyesi aktarılamaz. Lütfen gerekli tüm aktarımları takastan önce gerçekleştirin."**; `UZAKLAŞTIR` (seçimi temizle) ve `HIZLI EKLE`. Limit kullanıldıkça `1 / 5`, `2 / 5`; limit dolunca `TAKAS` pasif. Koşul sağlanmayan satırda `+` yuvası.

## 11. Pazar (G69–G73)
`TRANSFER PAZARI`; sekmeler `ÖNER · OYUNCULARIM · TAKİP LİSTEM · EMİRLERİM`; `SAHİP OLUNAN OYUNCU: 855`; 5 sütun ızgara, kart altında fiyat; sağ panel: büyük kart, `Oyuncuyu Takip Et` anahtarı, `Şu Anki Değer / En Düşük Değer / En Yüksek Değer`, `SAT` ve `SATIN AL`; sol altta `FİLTRE`. **Yıldız Transferleri (V02):** ayrı para birimi (`204.111`), `GEN ↑/↓` sıralama, `İZLEME LİSTESİ: 0/50`, `TÜM OYUNCULAR 2.249`.

## 12. Modlar ve rekabet (G28–G30)
- **Mod seçimi (V03 03:00):** dört dikey kart: `KARŞI ATAK` (`D. KLAS. III · TARAFTAR: 442.500`, "Yüksek tempolu gol atma aksiyonu"), `TEKE TEK` (`PRO I · KUPALAR: 408.600`, "Özgün maç kontrolleri"), `T. DİREKTÖR MODU` (`AMATÖR I · PUAN: 0`, "Taktik savaşı"), `ARKADAŞLARA KARŞI`; her kartta **kendi derece rozeti ve kendi puan birimi** + `SEZON SONU: 6 GÜN`; başlıkta ping.
- **Teke Tek (V03 04:00):** `17. Sezon`; mevcut derece → sonraki derece ilerleme çubuğu (kupa sayısı, kalan gün); `ÖDÜLLER`; kupa-zaman çizgi grafiği; sayaçlar `GALİBİYET 38 · GOL 150 · KOMBO 9`; `DERECESİZ OYNA` + `OYNA`; `KULÜP STADYUMU` seçici; sağ `ŞU ANKİ LİDERLER` (1–3 vurgulu; ad, `GEN 133 | SVY 57`, derece adı, `2,126Mln KUPA`), `SIRALAMAN`, `TAM LİDERLİK TABLOSUNU GÖR`.
- **Taktiği düzenle (V03 04:20):** modal; sol ön ayarlar `HÜCUM · KONTROL · KONTRA · DEFANSİF · ÖZEL`; orta açılır `OYUN KURMA` + **`HIZ` (3 kademe, −/+)**, **`PAS MESAFESİ` (3 kademe)**, **`MANTALİTE` (‹ DENGELİ ›, 3 nokta)**, **`POZ. ALMA` (‹ ORGANİZE ›, 2 nokta)**; katlanır `HÜCUM`, `SAVUNMA`; sağ minyatür saha oklu pas rotası; `SIFIRLA` / `BAŞVUR`.

## 13. Maç (G31–G46)
- **HUD (V01 12:04):** sol üstte **tek şerit**: saat kutusu (yeşil `10:12`), ağ simgesi, takım arması + kısa ad, skor kutusu (beyaz `0 - 1`), rakip arma + ad, ağ simgesi; sol altta sanal joystick (dönen yön yayı); alt ortada mini harita (iki takımın noktaları); sağ altta **kümelenmiş yuvarlak düğmeler**. Hücum: `ŞUT` (sağ üst), `ARA`, `PAS`, büyük `SPRİNT VE BECERİ`. Savunma: `KAY`, `2. DEF`, `DEĞİŞTİR`, büyük `SPRİNT VE MÜDAHALE`. Serbest top/uzaklaştırma: `UZAKLAŞTIR`. Düğme çevresinde renkli halka (düğme rolü). Kontrol edilen oyuncuda yeşil ok + isim etiketi. Savunmada solda **`OTO.`** sarı yuvarlak düğme (işlevi doğrulanamadı).
- **Duran top:** serbest vuruşta `‹ ›` kamera okları; penaltıda kaleci/oyuncu sahnesi.
- **Maç sonu:** `MAÇ SONU` şeridi + havai fişek; **sonuç (V04 13:16):** başlık: oyuncu adı/alt adı, **skor `4 - 0`**, `90:00`; kupa karşılaştırması (`319.000 KUPA PRO I` ↔ `290.900 KUPA PRO II`); **istatistik çubukları** (iki renkli yatay çubuk): `KALEYİ BULAN ŞUT 4(4) / 1(1)`, `TOPA SAHİP OLMA 49% / 51%`, `PAS İSABETİ 72% / 79%`, `FAUL 0 / 2`, `OFSAYTLAR 0 / 0`; sağda golcü listesi (dakika `27'`, top simgesi, `Vieira GOL`); `DEVAM ET` + hoparlör düğmesi.
- **Arkadaşlar (V01 14:52):** `ARKADAŞLAR`; `OYUN ARKADAŞLARI 1/32` (kapasite); gösterge `ONLINE / MAÇTA / ÇEVRİMDIŞI`; `ŞUNA GÖRE SIRALA: VARSAYILAN` + arkadaş ekle simgesi; satır: durum noktası, arma, ad, `LİG YOK`, `GEN 69 | SVY 8`, derece/taraftar/kupa, **`MAÇ`** düğmesi, açılır ok.

## 14. Bizim oyun için çıkarımlar (TASARIM)
Bunlar karar değil, öneridir; uygulanana kadar `TASKS.md` notudur.
1. Mağaza/takas/limit mantığı **model olarak** çıkarılabildi (limit türleri, çift fiyat, kullanım sayacı, süre, kilit koşulu, sağlanan/gereken sayaç) → `Core/Store`, `Core/Exchange` (bu dilimde kodlandı ve testlendi).
2. "VALUE %" rozeti hesabı videodan belirlenemez → **kullanılmayacak** (yanıltıcı olabilir).
3. Her modun kendi derece/puan birimi var (Taraftar/Kupa/Puan) → T089'da mod başına ayrı sezon puanı.
4. Kadro ekranında mevki rozeti kartın altında, yedekler sahanın altında; bizim `ClubScreen` yerleşimi buna yaklaşıyor ama yedekleri alta almalı.
5. Maç HUD'unda düğme **kümesi sağ altta yay şeklinde**, büyük sprint/müdahale düğmesi en dışta; bizim `FieldHud` benzer; "OTO." için karar bekleniyor (T027).
6. Oyuncu detayında nitelik **renk kodu** (düşük = sarı, yüksek = yeşil) ve **etkilenen oyuncular** listesi → `CollectionScreen` detayına eklenecek (T039/T056).
