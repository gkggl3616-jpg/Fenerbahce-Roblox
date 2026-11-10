# Fener Kariyer: Oyun Tasarımı

Roblox için tek oyunculu futbol kariyer oyunu. Fenerbahçe taraftar topluluğu için yapılıyor.

## Dosyalar
- `tasarim/tasarim-panosu.html`: tüm ekranların görsel tasarımı, numaralı notlarla (ana referans)
- `tasarim/gorseller/`: 23 konsept görsel (6 stadyum kademesi, maç, gol, karakter, lobi, antrenman)
- `TEK_PROMPT.md`: oyunun tamamını tarif eden tek prompt (maç mekanikleri, animasyon, efekt, arayüz)
- `PROMPTLAR.md`: geliştirme, görsel üretim ve 3D model promptları
- `tasarim/render/`: görselleri üreten kaynak kod
- `prototype/`: önceki oynanabilir denemeler (eski, yalnızca kontrol hissi için)

## Oyunun özü
Oyuncu kendi futbolcusunu ve kendi kulübünü yaratır. Kulüp amatör ligde, mahalle sahasında başlar. Sezonlar kazanıldıkça kulüp lig atlar ve stadyumu büyür. En tepede Fenerbahçe'den teklif gelir ve oyuncu Kadıköy'de oynar.

Varsayımlar:
- Maçlar tek oyunculu, rakipler ve takım arkadaşları bot. Sunucu yalnızca kayıt ve dünya sıralaması için.
- "Kulübümüz yükseldikçe sahamız yükselsin": oyuncunun kurduğu kulüp lig atlar. Fenerbahçe en üst basamaktır ve transferle açılır.

## İlerleme katmanları
| Katman | Ne yükselir | Nasıl |
|---|---|---|
| Futbolcu | Seviye 1-30, beş özellik, dört yetenek zinciri | Maç ve antrenman XP'si, bakiye |
| Kulüp | Amatör, 3. Lig, 2. Lig, 1. Lig, Süper Lig | 10 maçlık sezonu ilk ikide bitir |
| Tesis | Çim, tribün eki, aydınlatma, soyunma odası, antrenman sahası, sağlık merkezi | Kulüp kasası (maç geliri) |
| Efsane | Fenerbahçe forması, kaptanlık | Süper Lig şampiyonluğu veya seviye 25 + güç 85 |

## Stadyum kademeleri
| Kademe | Lig | Stadyum | Kapasite | Işık | Bot gücü | Maç geliri |
|---|---|---|---|---|---|---|
| 1 | Amatör Lig | Mahalle Sahası | 150 | Bulutlu gündüz | 30-40 | 50 |
| 2 | 3. Lig | İlçe Stadı | 1.800 | Öğleden sonra | 40-52 | 150 |
| 3 | 2. Lig | Şehir Stadı | 8.500 | Gün batımı | 52-64 | 400 |
| 4 | 1. Lig | Modern Stadyum | 21.000 | Alacakaranlık | 64-75 | 900 |
| 5 | Süper Lig | Arena | 34.000 | Gece | 75-86 | 1.800 |
| 6 | Fenerbahçe | Şükrü Saracoğlu | 47.800 | Gece maçı | 86-95 | 3.500 |

Her kademenin görseli ve özellik listesi panoda.

## Futbolcu
- Kalıcı: isim, mevki (Kaleci, Defans, Orta Saha, Forvet). Mevki asla değişmez.
- Özelleştirme: boy (165-195 cm), yapı, ten, yüz, saç modeli ve rengi, sakal, krampon, aksesuarlar (kaptan bandı, uzun kol içlik, bileklik, saç bandı, eldiven, tozluk boyu).
- Özellikler (1-10): koşu hızı, çalım/pas, defans gücü, şut gücü, dayanıklılık.
- Yetenek zincirleri (sıralı kilit, seviye ve bakiye şartı):
  - Şut: Normal, Plase, Füze, Röveşata, Serbest vuruş uzmanı
  - Çalım: Marsilya, Nutmeg, Rabona, Elastico
  - Özel güç: Turbo, Demir adam, Kaptan lider, Efsane an
  - Mevkiye özel dördüncü zincir
- Her şut türünün ayrı animasyonu ve top davranışı var.

## Kulüp
- Ad, 2-3 harfli kısaltma, arma şekli, forma deseni oyuncuya ait. Renkler sarı-lacivert ailesiyle sınırlı.
- Sezon: 6 takımlı lig, 10 maç, ilk iki yükselir. Yükselince stadyum dönüşüm sinematiği oynar.

## Fenerbahçe kimliği
- Renkler: sarı #FFE600, lacivert #0B1747.
- Arma: yükleme ekranı, lobi zemini, forma, dış cephe, bayraklar, skorbord. Gerçek armayı topluluk Roblox'a yükler; görsellerdeki arma temsilidir.
- Sözler: 1907, Kadıköy, Sarı Lacivert, Çubuklu, beş yıldız.
- Mekanlar: Şükrü Saracoğlu, Kariyer Merkezi (lobi), Fenerium (mağaza), antrenman tesisi, kupa müzesi.
- Tribün: sarı-lacivert seyirci, koreografi, dev bayraklar, tezahürat.
- Gerçek futbolcu adı veya yüzü kullanılmaz. Telifli marş kaydı kullanılmaz.

## Ekonomi
- Bakiye: antrenman mini oyunları, maç ve gol ödülleri, günlük görevler. Özellik ve yeteneğe harcanır.
- Kulüp kasası: maç geliri. Yalnızca tesis modüllerine harcanır.
- Robux yalnızca görünüm ve 2x XP içindir; güç satılmaz. Bölüm tek ayarla kapatılabilir.

## Dünya sıralaması
Genel güç, mevkiye göre, haftalık gol krallığı, en yüksek kulüp kademesi. Lobide dev ekranda görünür.

## Sonraki adım
`PROMPTLAR.md` içindeki ana geliştirme promptunun ilk adımı: proje iskeleti, veri şeması, karakter ve kulüp oluşturma.
