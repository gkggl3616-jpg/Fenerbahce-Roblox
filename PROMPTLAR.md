# Fener Kariyer: Prompt Paketi

Bu dosyadaki her kod bloğu tek başına kopyalanıp kullanılabilir.

- **Bölüm 1-4** Claude'a (veya başka bir kod asistanına) verilir, Roblox projesini üretir.
- **Bölüm 5** görsel üreten yapay zekalara (Midjourney, Flux, DALL·E, Higgsfield vb.) verilir. Bu araçlar İngilizce komutla daha iyi sonuç verdiği için İngilizce yazıldı.
- **Bölüm 6** 3D model üreten araçlara (Meshy, Tripo vb.) verilir.

Görsel referanslar: `tasarim/tasarim-panosu.html` ve `tasarim/gorseller/`.

---

## 1. Ana geliştirme promptu

```text
Roblox için "Fener Kariyer" adlı tek oyunculu bir futbol kariyer oyunu geliştiriyoruz. Oyun bir Fenerbahçe taraftar topluluğu için yapılıyor ve her ekranında Fenerbahçe kimliği hissedilmeli.

TEKNİK ÇERÇEVE
- Dil: Luau. Proje yapısı: Rojo (src/ServerScriptService, src/ReplicatedStorage, src/StarterPlayer, src/StarterGui).
- Maçlar tek oyunculu: takım arkadaşları ve rakipler yapay zekalı bot. Sunucu yalnızca kayıt (DataStore) ve dünya sıralaması (OrderedDataStore) için kullanılır.
- Bakiye, XP, özellik, yetenek, kulüp kademesi ve stadyum durumu yalnızca sunucuda değişir. İstemci RemoteEvent ile istek gönderir, sunucu tip ve aralık kontrolü yapar.
- Mobil, PC ve konsol kontrolleri. Görsel ayarlar: Lighting.Technology = Future, Atmosphere, Bloom, ColorCorrection. StreamingEnabled açık.

OYUNUN ÖZÜ
Oyuncu kendi futbolcusunu ve kendi kulübünü yaratır. Kulüp amatör ligde, bir mahalle sahasında başlar. Sezonlar kazanıldıkça kulüp lig atlar ve stadyumu büyür. En tepede Fenerbahçe'den teklif gelir ve oyuncu Kadıköy'de, Şükrü Saracoğlu'nda oynar.

1) KARAKTER VE KULÜP OLUŞTURMA (yalnızca ilk girişte)
- Futbolcu adı (TextService filtresi), forma numarası (1-99).
- Mevki: Kaleci, Defans, Orta Saha, Forvet. Mevki kariyer boyunca ASLA değişmez; sunucu kilitler ve ikinci bir onay penceresi gösterilir.
- Görünüm özelleştirme: boy (165-195 cm), yapı (ince, atletik, güçlü), ten (6 ton), yüz (6 hazır yüz), saç modeli (8) ve rengi, sakal (4), krampon modeli ve rengi.
- Aksesuar: kaptan bandı, uzun kol içlik, bileklik, saç bandı, kaleci eldiveni, tozluk boyu.
- Kulüp: ad (filtreli), 2-3 harfli kısaltma, arma şekli (4 kalkan), forma deseni (çubuklu, düz, göğüs kuşaklı). Renkler sarı-lacivert ailesiyle sınırlıdır.
- Görünüm sonradan mağazadan değiştirilebilir; isim ve mevki değişmez.

2) İKİ KATMANLI İLERLEME
A. Futbolcu: seviye 1-30, XP maç ve antrenmandan gelir.
   - Özellikler (her biri 1-10): koşu hızı, çalım/pas, defans gücü, şut gücü, dayanıklılık. Bakiye ile yükseltilir.
   - Yetenek zincirleri sıralı kilitlidir: önceki açılmadan sonraki açılamaz, her yeteneğin seviye ve bakiye şartı vardır.
     Şut: Normal > Plase > Füze > Röveşata > Serbest vuruş uzmanı
     Çalım: Marsilya > Nutmeg > Rabona > Elastico
     Özel güç: Turbo > Demir adam > Kaptan lider > Efsane an
     Mevkiye özel dördüncü zincir (kaleci: refleks/plonjon, defans: kayarak müdahale, orta saha: ara pası, forvet: bitiricilik).
   - Her şut türünün ayrı animasyonu ve ayrı top davranışı vardır (plase kıvrılır, füze çok hızlıdır, röveşata havada yapılır ve yavaş çekim oynar).
   - Her seviye bir ödül verir (bakiye, forma, gol sevinci, krampon, kaptan bandı).
B. Kulüp: 6 kademe. Sezon 6 takımlı lig, 10 maç. İlk iki sıra bir üst lige çıkar.
   Kademe | Lig         | Stadyum          | Kapasite | Işık          | Bot gücü | Maç geliri
   1      | Amatör Lig  | Mahalle Sahası   | 150      | bulutlu gündüz| 30-40    | 50
   2      | 3. Lig      | İlçe Stadı       | 1.800    | öğleden sonra | 40-52    | 150
   3      | 2. Lig      | Şehir Stadı      | 8.500    | gün batımı    | 52-64    | 400
   4      | 1. Lig      | Modern Stadyum   | 21.000   | alacakaranlık | 64-75    | 900
   5      | Süper Lig   | Arena            | 34.000   | gece          | 75-86    | 1.800
   6      | Fenerbahçe  | Şükrü Saracoğlu  | 47.800   | gece maçı     | 86-95    | 3.500
   - Kademe 6 kulübün yükselmesiyle değil, oyuncunun Fenerbahçe'ye transferiyle açılır: Süper Lig şampiyonluğu VEYA seviye 25 + güç 85.
   - Her kademe içinde 6 tesis modülü kulüp kasasıyla geliştirilir ve sahada görünür: çim kalitesi, tribün eki, aydınlatma, soyunma odası, antrenman sahası, sağlık merkezi.
   - Lig atlandığında "yükselme" sinematiği oynar: eski stadyum yeni stadyuma dönüşür.

3) STADYUM KADEMELERİ (görsel hedef)
1. Mahalle Sahası: yıpranmış, yer yer toprak çim; tel örgü; 3 sıralı ahşap tribün; konteyner soyunma odası; arkada apartmanlar ve ağaçlar; ışık direkleri sönük.
2. İlçe Stadı: çatılı tek ana tribün (9 sıra), karşıda açık tribün, basit skorbord, 4 ince aydınlatma direği, renkli sabit reklam panoları.
3. Şehir Stadı: iki çatılı uzun tribün ve bir kale arkası, LED reklam panoları, 4 projektör kulesi, LED skorbord, sarı-lacivert koltuk blokları.
4. Modern Stadyum: dört ayrı çatılı tribün, köşelerde projektör kuleleri, sarı-lacivert cephe kaplaması, dev ekran.
5. Arena: köşeleri kapalı çanak, iki katlı tribün, çatı kenarında ışık şeridi, iki dev ekran, otopark.
6. Şükrü Saracoğlu: iki katlı dik çanak, tam dolu tribün, koltuklarda ve tribünde "FENERBAHÇE", "1907", "KADIKÖY", "SARI LACİVERT" koreografisi, dev bayraklar, dış cephede arma ve stadyum yazısı, etrafta Kadıköy'ün şehir ışıkları.

4) FENERBAHÇE KİMLİĞİ
- Renkler: sarı #FFE600, lacivert #0B1747. Zemin lacivert, vurgu sarı.
- Arma: yükleme ekranı, lobi zemini, forma göğsü, dış cephe, bayraklar, skorbord. Arma dosyasını topluluk decal olarak yükler; koda sabit asset id yazma, bir ayar tablosundan oku.
- Metinler: "1907", "Kadıköy", "Sarı Lacivert", "Çubuklu", beş yıldız.
- Mekanlar: lobi "Kariyer Merkezi" (ortasında kupa ve zemin arması), Fenerium mağazası, antrenman tesisi, stadyum tüneli, kupa müzesi, sıralama ekranı.
- Tribün sesi: tezahürat döngüsü, atakta yükselir, golde patlar. Telifli marş kaydı kullanma; topluluğun kendi kaydı için ses yuvası bırak.
- Gerçek futbolcu adı veya yüzü kullanma.

5) LOBİ (Kariyer Merkezi)
Menüler yerine yürünen bir 3D meydan. Kapılar: Stadyum Girişi (maça çık), Akademi (yetenek ağacı), Kulüp Binası (lig, transfer, tesis geliştirme), Fenerium (mağaza), Antrenman Tesisi, Dünya Sıralaması ekranı, Kupa Müzesi.

6) MAÇ
- 11'e 11, 2 x 3 dakika gerçek süre. Kamera oyuncunun arkasından, hafif yukarıdan.
- Kontroller: hareket, sprint (dayanıklılık harcar), pas, şut (basılı tutunca güç dolar), şut türü seçimi (1-4), özel güç.
- Bot yapay zekası durum makinesi: pozisyon al, pres yap, top kap, pas ver, şut at. Zorluk kademeyle artar.
- Arayüz: skor ve dakika üst ortada, radar sol üstte, olay akışı sağ üstte, yetenek yuvaları alt ortada, şut gücü ve dayanıklılık altta.
- Gol: yavaş tekrar, konfeti, sevinç seçimi, ödül sayacı. Maç sonu: istatistik karşılaştırması, maçın oyuncusu, XP ve bakiye.

7) EKONOMİ
- Bakiye: antrenman mini oyunları (koni slalomu, hedef şut, sprint, kukla savunma, penaltı), maç ve gol ödülleri, günlük görevler.
- Kulüp kasası: maç geliri (kapasiteyle artar) tesis modüllerine harcanır.
- Robux yalnızca görünüm ve 2x XP içindir; güç satılmaz. Bu bölüm tek bir ayarla kapatılabilmelidir.

8) DÜNYA SIRALAMASI
OrderedDataStore: genel güç, mevkiye göre, haftalık gol krallığı, en yüksek kulüp kademesi. Lobide dev ekranda ilk 10 ve oyuncunun kendi sırası.

ÇALIŞMA ŞEKLİ
Adım adım ilerle. Her adımın sonunda ne yaptığını, nasıl test edeceğimi ve sıradaki adımı yaz. Belirsiz bir tasarım kararında varsayılanı seç, bir cümleyle belirt ve devam et.
1. Proje iskeleti, veri şeması (PlayerData, ClubData), DataStore modülü (pcall, yeniden deneme, oturum kilidi)
2. Karakter ve kulüp oluşturma, mevki kilidi, görünüm sistemi
3. Lobi ve kapılar
4. Özellik ve yetenek sistemi
5. Antrenman mini oyunları
6. Maç: saha, top fiziği, bot yapay zekası, kamera, arayüz
7. Lig, sezon, yükselme ve stadyum kademeleri
8. Tesis modülleri, mağaza, günlük görevler
9. Dünya sıralaması
10. Fenerbahçe finali, ses ve efekt cilası
```

---

## 2. Stadyum üretici promptu

```text
Fener Kariyer için Luau'da prosedürel bir stadyum üretici yaz: StadiumBuilder.Build(tier: number, modules: {[string]: number}) -> Model.
Saha 105 x 68 stud'dur (1 stud = 1 metre kabul et), merkez (0,0,0), uzun kenar X ekseninde.

ORTAK PARÇALAR
- Çim: kademe 1'de yıpranmış ve toprak lekeli, 2'de hafif şeritli, 3-4'te belirgin biçme şeritleri, 5-6'da damalı biçme deseni. Çizgiler ayrı beyaz Part veya tek SurfaceGui dokusu.
- Kaleler 7,32 x 2,44, file yarı saydam ızgara dokulu. Köşe bayrakları.
- Tribün üretici: Stand(side, length, rows, gap, tierIndex, roof). Sıra derinliği 0,82, sıra yüksekliği alt katta 0,42-0,45, üst katta 0,54-0,60. Koltuklar MeshPart, 0,56 aralıkla, her 13 stud'da merdiven boşluğu.
- Seyirci: düşük poligonlu tek mesh, renk dağılımı parametreli. Uzak tribünlerde 4'lü gruplar halinde birleştir.

KADEME PARAMETRELERİ
1: tribün yok; saha çevresinde 2,6 yüksekliğinde tel örgü; kuzeyde 16 stud uzunluğunda 3 sıralı ahşap tribün; konteyner kulüp binası; 4 sönük direk.
2: kuzey 56 x 9 sıra çatılı; güney 42 x 4 sıra açık; 4 direk (19 yükseklik); doğuda küçük skorbord.
3: kuzey 92 x 15 sıra çatılı; güney 92 x 11 sıra çatılı; doğu 54 x 9 sıra açık; batıda LED skorbord; 4 kule (31 yükseklik); üç kenarda LED pano.
4: kuzey ve güney 104 x 21 sıra; doğu ve batı 66 x 18 sıra; hepsi çatılı, köşeler açık; 4 kule (40 yükseklik); dış cephe; batı çatısında dev ekran.
5: köşeleri kapalı çanak; alt kat 17 sıra, üst kat 14 sıra; çatı kenarında ışık şeridi; iki dev ekran; otopark.
6: köşeleri kapalı çanak; alt kat 24 sıra, üst kat 22 sıra, üst kat daha dik; tam doluluk; koreografi maskeleri (kuzey alt "FENERBAHÇE", güney alt "1907", doğu üst "1907", batı üst "KADIKÖY", güney üst "SARI LACİVERT"); 46 dev bayrak; dış cephede arma ve "FENERBAHÇE ŞÜKRÜ SARACOĞLU STADYUMU" yazısı.

IŞIK VE ATMOSFER (kademeye göre Lighting ayarı)
1 bulutlu gündüz, 2 açık öğleden sonra, 3 gün batımı, 4 alacakaranlık (projektörler açık), 5-6 gece (çatı ışıkları, Bloom yüksek).

TESİS MODÜLLERİ
modules tablosu şunları alır: cim (1-3), tribunEki (0-2), aydinlatma (0-2), soyunma (0-2), antrenman (0-2), saglik (0-2). Her seviye sahada görünür bir değişiklik üretir.

YÜKSELME SİNEMATİĞİ
StadiumBuilder.Morph(fromTier, toTier): eski model kaybolurken yeni tribünler yerden yükselir, kamera stadyumun etrafında döner, süre 6 saniye.

Koltuk ve seyirci sayısı çok yüksek olduğu için performans notlarını ve mobil için düşük detay modunu da yaz.
```

---

## 3. Karakter sistemi promptu

```text
Fener Kariyer için özelleştirilebilir futbolcu karakter sistemini yaz.

MODEL
- R15 iskeleti, gerçekçi insan oranları (Roblox blok karakter değil). Gövde parçaları özel MeshPart: baş, gövde, üst/alt kol, el, üst/alt bacak, ayak.
- Forma, şort, tozluk ve krampon ayrı katmanlar: gövdeden hafif geniş, kol ağzı ve paça gövdeden ayrık durur.
- Forma dokusu çalışma anında üretilir: desen (çubuklu, düz, göğüs kuşaklı), renkler, göğüste arma, sırtta isim ve numara, kaptan bandı.

ÖZELLEŞTİRME VERİSİ (PlayerData.appearance)
boy (165-195), yapi (ince | atletik | guclu), ten (1-6), yuz (1-6), sacModeli (1-8), sacRengi, sakal (0-4), kramponModeli, kramponRengi, aksesuarlar {kaptanBandi, uzunKol, bileklik, sacBandi, eldiven, tozlukBoyu}, golSevinci, formaNumarasi.
Boy ve yapı iskelet ölçeğiyle uygulanır; isabet kutusu değişmez (adil kalsın).

ANİMASYONLAR
bekleme, yürüme, koşu, sprint, top sürme, pas, normal şut, plase, füze, röveşata, kafa vuruşu, kayarak müdahale, kaleci plonjonu (sağ/sol), gol sevinçleri (diz kayması, kolları açarak koşma, kol kavuşturma), üzülme, kaptan işareti.

EKRAN
Karakter oluşturma ekranında karakter sahnede yavaşça döner, her seçim anında modele yansır. Sekmeler: Kimlik, Yüz, Saç, Vücut, Forma, Aksesuar. Mevki kartı seçildikten sonra kilit simgesi gösterilir.

Görünüm sunucuda saklanır, istemciden gelen değerler aralık kontrolünden geçer.
```

---

## 4. Arayüz promptu

```text
Fener Kariyer arayüzünü tasarim/tasarim-panosu.html içindeki ekranlara birebir uyacak şekilde Roblox ScreenGui olarak kur.

STİL
- Renk belirteçleri: Sari #FFE600, Lacivert #0B1747, Mavi #1A2D86, Zemin #050B26, Metin #EEF1FF, Soluk #9AA6DF, Iyi #3DDC84, Kotu #FF6B6B.
- Yazı: başlıklar GothamBlack büyük harf, metinler Gotham. Köşe yarıçapı 6-8. Rozetler kalkan şeklinde.
- Birincil buton sarı zemin lacivert yazı, ikincil buton mavi zemin, kilitli buton soluk.
- Tüm renkler tek bir Theme modülünden okunur.

EKRANLAR
Yükleme, karakter ve kulüp oluşturma, ana menü katmanı (lobide), antrenman, yetenek ağacı, maç öncesi VS, maç arayüzü, gol anı, maç sonu, kulüp merdiveni, tesis geliştirme, dünya sıralaması, seviye ödül yolu, mağaza, günlük görevler, ayarlar.

KURALLAR
- Mobilde butonlar en az 76 piksel, joystick sol altta, şut ve pas sağ altta.
- Sayılar artarken sayaç animasyonu, ödüllerde uçan rakam.
- Kilitli her öğe neden kilitli olduğunu yazar (seviye, önceki yetenek, bakiye).
```

---

## 5. Görsel üretim promptları (İngilizce)

Her blok bir görsel içindir. Tutarlılık için hepsinin sonuna aynı stil cümlesi eklendi. En boy oranı 16:9.

```text
STYLE SUFFIX (append to every prompt):
high-fidelity stylized-realistic 3D game art, realistic human proportions, clean PBR materials, cinematic stadium lighting, volumetric haze, yellow (#FFE600) and navy blue (#0B1747) color identity, Fenerbahçe fan-made football career game, sharp focus, 16:9, no text artifacts, no watermark
```

```text
01 KEY ART
Night match at a packed 48,000-seat two-tier rectangular football stadium in Kadıköy, Istanbul. The whole crowd wears yellow and navy striped shirts and forms a giant tifo spelling "FENERBAHÇE" and "1907" across the stands. Huge yellow-navy striped flags wave, roof-edge floodlights glow, light haze over a perfect checker-mown pitch. In the foreground a striker in a yellow and navy vertical striped shirt, white shorts, navy socks, number 9, captain armband, seen from behind as he walks out of the tunnel.
```

```text
02 STADIUM TIER 1: NEIGHBOURHOOD PITCH
Aerial three-quarter view of a humble amateur football pitch in an Istanbul neighbourhood on an overcast afternoon. Worn grass with brown dirt patches in the goal mouths and centre circle, slightly faded white lines, chain-link fence around the pitch, a tiny three-row wooden bleacher with about thirty spectators, a cream shipping-container clubhouse with a small yellow and navy sign, parked cars, trees and plain apartment blocks behind.
```

```text
03 STADIUM TIER 2: DISTRICT GROUND
Same camera angle. A small third-division ground on a clear afternoon: one covered main stand with nine rows and a simple steel roof, a low open terrace opposite, four slim floodlight poles, a basic scoreboard, coloured static advertising boards, lightly striped grass with minor wear, about a thousand fans, some in yellow and navy.
```

```text
04 STADIUM TIER 3: CITY STADIUM
Same camera angle at golden hour. Two long roofed stands and one open stand behind a goal, about 8,500 seats in yellow and navy blocks, LED perimeter boards, four tall floodlight towers, an LED scoreboard at the open end, neatly striped pitch, long warm shadows, low-rise city behind.
```

```text
05 STADIUM TIER 4: MODERN STADIUM
Same camera angle at dusk. Four separate fully roofed single-tier stands with open corners, 21,000 seats, floodlight towers in the corners switched on with soft glow, yellow and navy striped facade cladding, a large video screen above one end, most fans in yellow and navy.
```

```text
06 STADIUM TIER 5: ARENA
Same camera angle at night. A closed two-tier bowl with filled corners, 34,000 seats, a continuous pale roof ring with a bright strip of floodlights on its inner edge, two giant video screens, a blue LED ribbon between the tiers, a yellow and navy facade, a full car park and city lights around.
```

```text
07 STADIUM TIER 6: ŞÜKRÜ SARACOĞLU
Same camera angle at night. A steep closed two-tier rectangular stadium inspired by Fenerbahçe Şükrü Saracoğlu Stadium in Kadıköy, 47,800 seats completely full. The crowd choreography spells "FENERBAHÇE" on one long side and "1907" behind a goal in yellow on navy. Dozens of giant striped flags, a glowing roof-edge light ring, a huge round club crest and the stadium name in illuminated yellow letters on the navy and yellow facade, Istanbul city lights and the Sea of Marmara in the distance.
```

```text
08 PLAYER CHARACTER SHEET
Character turnaround sheet of a football player on a dark navy studio backdrop: front, back and side views. Athletic realistic proportions, short dark hair, light stubble. Kit: yellow and navy vertical striped shirt with navy sleeves and yellow cuffs, round crest with five small stars on the left chest, white shorts with navy trim, navy socks with a yellow band, black boots with white soles, yellow captain armband on the left arm, name and a large white number 9 with navy outline on the back.
```

```text
09 CHARACTER CUSTOMISATION LINE-UP
Six football players standing side by side in the same yellow and navy striped kit, showing customisation variety: different heights from 165 to 195 cm, slim, athletic and strong builds, six skin tones, hairstyles (buzz cut, short, quiff, long, bald), beards, boot colours (black, white, yellow, red, cyan), long-sleeve undershirt, captain armband. Dark navy studio backdrop with subtle yellow pinstripes.
```

```text
10 GAMEPLAY CAMERA
Third-person gameplay view from behind and slightly above a striker in a yellow and navy striped shirt, number 9, dribbling toward the penalty area at night in a packed stadium. Three defenders in white and teal, a goalkeeper in orange, the goal ahead, LED boards reading "FENERBAHÇE", "1907", "KADIKÖY", a wall of yellow and navy fans and flags behind the goal. Leave empty space at the corners for a HUD.
```

```text
11 GOAL MOMENT
View from inside the goal, looking through the net: the ball hits the top corner while the goalkeeper in orange dives at full stretch and misses. Behind him the striker in yellow and navy is in his follow-through. Stadium roof lights, a giant scoreboard and a roaring yellow and navy crowd in the background. Freeze-frame energy, slight motion blur on the ball.
```

```text
12 BICYCLE KICK
Low side angle of a player in a yellow and navy striped shirt performing a bicycle kick in mid-air, body horizontal, kicking leg above his head striking the ball. A defender jumps beside him. Night stadium, slow-motion feel, flags and crowd behind, shadow on the grass below.
```

```text
13 CAREER HUB (LOBBY)
A football club plaza at dusk used as the game lobby. A large round club crest is inlaid in the floor with a golden trophy on a pedestal at its centre, surrounded by a ring of flagpoles with yellow and navy striped flags. Buildings around the plaza with illuminated signs: a stadium entrance, an academy, a club office, a "FENERIUM" fan shop with a glass front, and a giant LED world ranking screen. Warm street lamps, players in club kits walking around, pink and navy sky.
```

```text
14 TRAINING GROUND
Daytime training pitch at a club academy. In the foreground a player in a black training top with yellow details dribbles through orange cones. Further away: passing mannequins in yellow, small hurdles, an agility ladder, a coach watching. A long low club building with a navy roof and a yellow sign in the background, trees and blue sky.
```

```text
15 ROBLOX THUMBNAIL (1920x1080)
Bold game thumbnail: a confident striker in a yellow and navy striped shirt celebrating with arms wide in front of a blazing stadium at night, yellow and navy flares and confetti, big empty space on the left for the title "FENER KARİYER". High contrast, saturated, readable at small size.
```

```text
16 ROBLOX ICON (512x512, 1:1)
Square game icon: close-up of a football boot striking a ball in front of yellow and navy vertical stripes, a small round crest shape in the corner, strong rim light, simple and readable at 64 pixels.
```

---

## 6. 3D model promptları (İngilizce)

```text
FOOTBALL PLAYER BASE MESH
Game-ready male football player, A-pose, realistic athletic proportions, 1.80 m tall, separate meshes for head, torso, arms, hands, legs and feet for a Roblox R15 rig. Short-sleeve football shirt slightly loose with open cuffs, shorts ending above the knee with a loose hem, knee-high socks, low-cut football boots with studs. Clean quad topology, under 12k triangles, neutral grey materials, no logos.
```

```text
HAIR PACK
Eight low-poly football player hairstyles as separate meshes fitting the same head: buzz cut, short crop, side part, quiff, curly short, long tied back, afro, shaved sides with long top. Each under 1,500 triangles, single material.
```

```text
FOOTBALL BOOT
Low-cut football boot, sleek modern design, visible studs, single mesh under 1,200 triangles, material zones for upper, sole and stripe so colours can be changed in engine.
```

```text
MATCH BALL
Classic 32-panel football, white hexagons and dark navy pentagons with thin yellow seams, 800 triangles, PBR textures.
```

```text
STADIUM SEAT AND STAND MODULE
Modular stadium stand section 8 m wide and 12 rows deep with plastic tip-up seats, concrete steps and one aisle stair, designed to tile seamlessly. Seat colour as a separate material. Under 6k triangles.
```

```text
FLOODLIGHT TOWER
Tall steel lattice floodlight tower with a rectangular lamp panel of 6 x 4 lamps tilted downward, 40 m tall, under 3k triangles.
```

```text
TROPHY
Elegant golden league trophy with two handles on a dark navy pedestal with a blank plaque, polished metal PBR, under 2k triangles.
```

```text
LOW-POLY FAN
Very low-poly seated football fan for stadium crowds, striped shirt area as a separate vertex-colour zone, arms raised variant and scarf variant, each under 120 triangles.
```
