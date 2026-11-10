# Fener Kariyer: Roblox Futbol Kariyer Oyunu

Bu belge iki parçadan oluşuyor: (1) oyun tasarımı, (2) Claude'a verilecek ana geliştirme promptu.

Not: "Online olmayacak" ifadesini şöyle yorumladım: maçlar tek oyunculu, rakipler yapay zekalı bot. Sunucu yalnızca kayıt (DataStore) ve dünya sıralaması için kullanılır. Farklıysa söyle, değiştiririz.

---

## 1. Oyun tasarımı

### Temel fikir
Oyuncu kendi futbolcusunu yaratır. Küçük bir kulüpte başlar, maç oynar, antrenman yapar, yeteneklerini açar ve basamak basamak Fenerbahçe'ye yükselir. Hedef: dünya sıralamasında ilk sıra.

### Karakter oluşturma
- Futbolcu adı (isim filtresi Roblox `TextService:FilterStringAsync` ile)
- Başlangıç kulübü (4 küçük kulüp seçeneği)
- Mevki: Kaleci, Defans, Orta Saha, Forvet. Mevki seçildikten sonra asla değişmez. Sunucu tarafında kilitli tutulur.
- Mevki yetenek ağacını ve statların başlangıç dağılımını belirler (forvet şutta, defans savunmada güçlü başlar).

### Ana döngü
1. Maç oyna (bot takım, yapay zeka)
2. Maç ve antrenmandan bakiye + XP kazan
3. Bakiye ile özellik geliştir ve yetenek aç
4. Seviye atla, ödül al
5. Güç arttıkça daha iyi kulüplerden teklif gelir

### Özellikler (stat)
| Özellik | Etkisi | Seviye |
|---|---|---|
| Koşu hızı | WalkSpeed, sprint süresi | 1-10 |
| Çalım ve pas | Top kontrolü, pas isabeti | 1-10 |
| Defans gücü | Top kapma, müdahale şansı | 1-10 |
| Şut gücü | Şut hızı ve isabeti | 1-10 |
| Dayanıklılık (öneri) | Sprint barı | 1-10 |

### Yetenek zincirleri (sıralı kilit)
Her zincirde bir sonraki yetenek için önceki açık olmalı ve seviye şartı sağlanmalı.
- Şut: Plase, Füze, Röveşata, Serbest vuruş uzmanı (her biri ayrı şut animasyonu)
- Çalım: Marsilya, Nutmeg, Rabona, Elastico
- Özel güçler: Turbo, Demir adam, Kaptan lideri, Efsane an (yavaş çekim şut)
- Mevkiye özel zincir: Kaleci için refleks/plonjon, defans için kayarak müdahale, orta saha için ara pası

### Seviye ve ödüller (1-10 örnek)
| Seviye | Ödül |
|---|---|
| 2 | +200 bakiye |
| 3 | Deplasman forması |
| 4 | +500 bakiye |
| 5 | Gol sevinci |
| 6 | Orta lig transfer teklifi |
| 7 | +1000 bakiye |
| 8 | Altın krampon |
| 9 | Üst lig transfer teklifi |
| 10 | Fenerbahçe teklifi ve kaptan bandı |

### Kulüp merdiveni
Amatör kulüp, 3. lig, 2. lig, 1. lig, Süper Lig takımı, Fenerbahçe. Her basamakta botların gücü artar, maç ödülü artar.

### Dünya sıralaması
- `OrderedDataStore` ile global liste: Genel güç, mevkiye göre, haftalık gol krallığı
- Sıralama güncellemesi sunucudan, istemci puan gönderemez
- Haftalık sıfırlanan sezon tablosu ve ödülü

### Aklıma gelen ek fikirler
**Oynanış**
- Maç sırasında "form" göstergesi: iyi oynarsan bir sonraki maçta bonus
- Sakatlık ve yorgunluk: dinlenme veya fizyoterapi için bakiye harca
- Kaptanlık ve takım içi moral sistemi
- Antrenör NPC'si: antrenmanda mini oyunlar (direk-hedef şutu, koni slalomu, penaltı)
- Penaltı ve serbest vuruş nişan mini oyunu

**İlerleme**
- Günlük görevler (3 gol at, 2 antrenman yap) ve giriş serisi ödülü
- Başarımlar (hat-trick, 10 maç yenilmezlik)
- Transfer pazarlığı: teklifleri karşılaştır, kulüp seç
- Sezon sistemi: lig tablosu, kupa maçları, Şampiyonlar Ligi
- Prestij (emeklilik): 10. seviyede sıfırdan başla, kalıcı bonus kazan

**Kozmetik ve para**
- Forma, krampon, saç, gol sevinçleri (oyun içi bakiyeyle)
- Robux ile 2x XP geçişi, kozmetik paketleri (güç satın alma yok, adil kalsın)
- Fenerbahçe temalı stadyum: Ülker Stadyumu - Şükrü Saracoğlu atmosferi, tribün sesleri

**Sosyal (sunucu gerektirmeden)**
- Profil kartı ve arkadaşlarla karşılaştırma
- Haftalık sıralama ödülü

**Teknik**
- Mobil, konsol ve PC kontrolleri
- Mobilde tek parmak şut, kaydırarak pas
- Hile önlemi: tüm bakiye, XP ve stat işlemleri sunucuda

---

## 2. Claude'a verilecek ana prompt

Aşağıdakini yeni bir oturumda olduğu gibi kullanabilirsin.

```text
Roblox için "Fener Kariyer" adlı tek oyunculu bir futbol kariyer oyunu geliştiriyoruz. Luau kullan, Rojo proje yapısıyla çalış (src/ServerScriptService, src/ReplicatedStorage, src/StarterPlayer, src/StarterGui). Kodu modüler yaz ve her modülün kısa bir açıklaması olsun.

OYUN
- Oyuncu futbolcu adı, başlangıç kulübü ve mevki seçer (Kaleci, Defans, Orta Saha, Forvet). Mevki kariyer boyunca ASLA değişmez; sunucu bunu doğrular.
- Maçlar tek oyunculu, rakip ve takım arkadaşları yapay zekalı botlardır (PathfindingService veya basit durum makinesi: bekle, pres yap, pas ver, şut at).
- Sunucu yalnızca DataStore kaydı ve OrderedDataStore dünya sıralaması içindir.
- Özellikler (1-10): koşu hızı, çalım/pas, defans gücü, şut gücü, dayanıklılık.
- Yetenek zincirleri sıralı kilitlidir: önceki yetenek açılmadan sonraki açılamaz; her yeteneğin seviye ve bakiye şartı vardır.
- Seviye 1-10, her seviyede ödül. Antrenman ve maçtan bakiye + XP kazanılır.
- Kulüp merdiveni: amatör -> 3. lig -> 2. lig -> 1. lig -> Süper Lig -> Fenerbahçe.
- Birden fazla şut animasyonu (plase, füze, röveşata, serbest vuruş) yetenekle açılır.

GÜVENLİK
- Bakiye, XP, stat ve yetenek işlemleri sadece sunucuda yapılır; istemci RemoteEvent ile istek gönderir, sunucu doğrular.
- Tüm RemoteEvent girdilerini tip ve aralık açısından kontrol et. Oyuncu adı için TextService filtresi kullan.
- DataStore işlemlerini pcall ve yeniden deneme ile yaz, oturum kilidi kullan.

ARAYÜZ
- Fenerbahçe renkleri: lacivert #0b1747 ve sarı #ffe600. Üstte oyuncu çubuğu (rozet, isim, seviye/XP, bakiye), altında sekmeler: Kariyer, Antrenman, Yetenekler, Maç, Sıralama, Ödüller.
- Mobil, konsol ve PC desteği. Mobilde büyük butonlar.
- Görsel referans: prototype/prototype-3d.html (3D oynanış, kamera, karakter stili) ve prototype/prototype.html (menü ve arayüz sekmeleri)

ADIM ADIM İLERLE
1. Proje iskeleti ve veri modeli (PlayerData şeması, DataStore modülü)
2. Karakter oluşturma ekranı ve mevki kilidi
3. Stat ve yetenek sistemi (sunucu doğrulamalı)
4. Antrenman mini oyunları
5. Maç sistemi: saha, top fiziği, bot yapay zekası, skor, süre
6. Seviye, ödül ve kulüp teklifleri
7. Dünya sıralaması (OrderedDataStore)
8. Cila: ses, efekt, günlük görevler

Her adımın sonunda neyi yaptığını, nasıl test edeceğimi ve sıradaki adımı yaz. Belirsiz bir tasarım kararında varsayılanı seç, bir cümleyle belirt ve devam et.
```

---

## 3. Sonraki adımlar
1. 3D prototipi (`prototype/prototype-3d.html`) incele, beğenmediğin yerleri söyle.
2. Kulüp isimlerini, yetenek adlarını ve ödülleri sen belirle.
3. Fenerbahçe logosu, forma ve stadyum isimleri marka hakkı taşır. Roblox'ta yayınlamadan önce lisans konusunu düşünmek gerekir; güvenli yol "Fener" esintili özgün isim ve tasarımdır.
4. Onaylarsan 1. adımdan Roblox projesini kurmaya başlarım.
