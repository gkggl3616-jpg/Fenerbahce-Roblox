# Fener Kariyer: Karakter, Animasyon, Özelleştirme, Forma ve Halı Saha Üretim Promptu

Bu dosya iki bölümden oluşur:

1. **ANA PROMPT (Türkçe):** Bir kodlama yapay zekâsına, 3B sanatçıya ya da ekibe tek parça
   verilecek ayrıntılı iş tanımı. Baştan sona kopyalanıp yapıştırılabilir.
2. **ARAÇ PROMPTLARI (İngilizce):** Görsel ve 3B üretim araçlarına (çizimden 3B'ye, metinden
   3B'ye, doku üreticileri) verilecek kısa ve odaklı promptlar. Bu araçlar İngilizceyle daha
   iyi sonuç verdiği için İngilizce yazıldı.

Bütün sayılar (renkler, seçenek adları, animasyon süreleri, olay anları, hızlar, saha ölçüleri)
bu depodaki gerçek değerlerden alınmıştır; yeni varlıklar oyuna bu sayılarla uymalıdır.

---

## 1. ANA PROMPT

```text
=====================================================================
ROL VE ÇALIŞMA BİÇİMİ
=====================================================================
Roblox'ta yıllarca çalışmış bir teknik sanatçı (modelleme, sculpt, UV, doku, rig, skinning,
animasyon) ve kıdemli bir Luau geliştiricisi gibi çalış. Görevin, "Fener Kariyer" adlı tek
oyunculu futbol kariyer oyununda:
  (a) karakter modelini,
  (b) animasyonları,
  (c) karakter özelleştirmesini,
  (d) forma sistemini,
  (e) halı saha haritasını
yayın kalitesine yakın, gerçek insan oranlarında ve "kutu/oyuncak" görüntüsünden tamamen
arınmış hâle getirmek.

İşi aşağıdaki AŞAMALARA böl ve her aşamada şu çıktıları ver:
  1. Yapılacaklar listesi (kısa).
  2. Blender adımları: numaralı, hangi menü ve ayar olduğu belirtilmiş.
  3. Roblox Studio adımları: içe aktarma, kontrol, yükleme, klasöre yerleştirme.
  4. Luau kodu: değişen dosyanın TAMAMI. Parça kod verme; nereye gireceği belirsiz kod verme.
  5. Bu aşamada eklenecek otomatik sınamalar.
  6. Kabul kontrol listesi: her maddeyi "geçti/kaldı" diye işaretleyebileceğim biçimde.
Emin olmadığın bir Roblox API ayrıntısını uydurma; "Roblox belgelerinde doğrula" diye işaretle.

=====================================================================
1. OYUN VE MEVCUT TEKNİK DURUM
=====================================================================
- Proje Rojo + Luau. Önemli dosyalar:
  · src/ServerScriptService/Server/CharacterService.luau
    Karakteri giydirir. dress(character, look) → buildBody(character, look, kit, skin).
    Bot şablonlarını kurar (ReplicatedStorage/FK_BotTemplates: Rival, RivalAttacker,
    RivalKeeper, Mate, Mate2, MateKeeper, Referee ...).
  · src/StarterPlayer/StarterPlayerScripts/Client/Anim/Poses.luau
    Prosedürel animasyon verisi: anahtar kareler, süreler, olaylar.
  · src/StarterPlayer/StarterPlayerScripts/Client/Anim/Animator.luau
    Motor6D.Transform ile oynatır. Play(action, opts), Update(dt, state), Current().
  · src/StarterPlayer/StarterPlayerScripts/Client/Match/MatchAI.luau
    Maçta botları kurar. Rakip formasını FK özniteliğine göre yeniden boyar.
  · src/StarterPlayer/StarterPlayerScripts/Client/Screens/SkillTree.luau
    Yetenek ağacında ViewportFrame içinde FK_BotTemplates.Mate kopyasıyla hareket önizlemesi
    gösterir.
  · src/ReplicatedStorage/Shared/Config.luau, Kits.luau, Crest.luau, Stadium.luau
  · tests/spec.luau ve tests/prelude.luau
    Roblox dışında çalışan sınama düzeneği; şu an 1395 denetim geçiyor.
- Şu anki karakter: Standart R15 iskeleti. Hazır parçalar görünmez yapılıyor; görünen gövde
  kodla temel şekillerden (Part, silindir, elips) kuruluyor. Sonuç: köşeli, oyuncak gibi.
  BU, değiştirilecek şeydir.
- Görünüm verisi (sunucuda doğrulanıyor, DataStore'da saklanıyor):
    appearance = {
      height = 165..195 (cm), build = "Ince" | "Atletik" | "Guclu",
      skin = 1..6, face = 1..6, hairStyle = 1..8, hairColor = "<hex>",
      beard = 0..4, bootModel = 1..4, bootColor = "<hex>",
      accessories = { UzunKol, Bileklik, SacBandi, KisaTozluk } (true/false)
    }
  Ayrıca: position (Kaleci, Defans, OrtaSaha, Forvet), kitPattern ("Cubuklu" | "Duz" |
  "Kusakli"), number (1..99), name (3..16 karakter), crest (shape, pattern, a, b, symbol),
  atFenerbahce (true/false), level (kaptanlık bandı seviye 10'da gelir).
- Seçenek adları:
  · Saç: 1 Sıfır, 2 Kısa, 3 Hacimli, 4 Uzun, 5 Kıvırcık, 6 Topuz, 7 Yanlar kısa, 8 Kel
  · Sakal: 0 Yok, 1 Kirli, 2 Bıyık, 3 Tam, 4 Keçi
  · Yapı: İnce, Atletik, Güçlü
  · Aksesuar: Uzun kol içlik, Bileklik, Saç bandı, Kısa tozluk
- Renkler (hex):
  · Arayüz: Sarı FFE600, Lacivert 0B1747, Mavi 1A2D86, Altın FFC83D, Beyaz FFFFFF
  · Ten: F5D6BE, E8BEA0, CDA07D, AA7858, 7D543C, 54382A
  · Saç: 1B1410, 2E2118, 0C0C0E, 5A4326, 8A6A3A, C9B27A
  · Krampon: 101216, F4F4F4, FFE600, E33A3A, 22BBDD, 0B1747
- Formalar (Kits.luau). Bölgeler: Shirt / Stripe / Sleeve / Trim / Shorts / Sock /
  Ink (yazı) / InkStroke (yazı konturu).
  · Fenerbahçe (transfer sonrası): Cubuklu; Shirt FFE600, Stripe 0B1747, Sleeve 0B1747,
    Trim FFE600, Shorts FFFFFF, Sock 0B1747; yazı beyaz, kontur lacivert.
  · Kulüp / Cubuklu: Shirt FFE600, Stripe 0B1747, Sleeve FFE600, Trim 0B1747,
    Shorts 0B1747, Sock FFE600; yazı beyaz, kontur lacivert.
  · Kulüp / Duz: Shirt 0B1747, Stripe FFE600, Sleeve 0B1747, Trim FFE600, Shorts 0B1747,
    Sock 0B1747; yazı sarı, kontur lacivert.
  · Kulüp / Kusakli: Shirt FFFFFF, Stripe 0B1747, Sleeve FFFFFF, Trim FFE600,
    Shorts 0B1747, Sock FFFFFF; yazı lacivert, kontur beyaz.
  · Kaleci: Shirt 19B56A, Stripe 0D7A45, Sleeve 0D7A45, Trim 0B1747, Shorts 0D7A45,
    Sock 19B56A; yazı beyaz, kontur lacivert.
  · Rakip varsayılanı: Shirt EEF3F4, Stripe 0F8F80, Sleeve 0F8F80, Trim FFFFFF,
    Shorts 0F8F80, Sock EEF3F4.
  · Maçta rakip kulübün renkleri uygulanır: Shirt, Sleeve, Sock → kulübün A rengi;
    Shorts, Trim, Stripe → B rengi. Kaleci yeniden boyanmaz. Boyama, parçalardaki "FK"
    özniteliğine (Shirt, Sleeve, Shorts, Sock, Trim, Stripe) ve adı "Stripe" olan arayüz
    karelerine göre yapılır. YENİ SİSTEM BU SÖZLEŞMEYİ BOZMAMALI.
- Hareket hızları (stud/sn): koşu 17, depar 25, 0'dan tam hıza 0,3 sn, durma 0,25 sn.
  Ani dönüşte hızın %80'i kalır. Yorgunken hız düşer.
- Ölçek: 1 m = 3 stud. Maç sahası 210 × 320 stud, kaleler 24 × 8 stud.
- KISITLAR:
  · Gerçek futbolcu adı, yüzü ya da benzerliği yok.
  · Resmî kulüp, lig ya da marka logosu yok; FIFA/EA FC/eFootball varlığı ya da birebir
    görünümü yok.
  · Armalar, sponsorlar ve isimler uydurma. Fenerbahçe'ye transferde göğüste yalnız "FB"
    yazısı olur; resmî logo kullanılmaz.
  · Arayüz Türkçe.
  · Sahada 22 oyuncu + hakem. Hedef: orta seviye PC'de 60 FPS, orta seviye telefonda 30 FPS.

=====================================================================
2. GÖRSEL HEDEF (SANAT YÖNÜ)
=====================================================================
- Stil: "Stilize gerçekçi". Gerçek insan anatomisi ve oranları korunur; yüzeyler temiz ve
  okunaklı tutulur; aşırı gözenek ya da kıl ayrıntısı yok. Roblox'un ışığında 10–40 m
  uzaktan okunmalı.
- Okunaklılık için yalnız şu üç yerde hafif abartı var:
  · baş ×1,08
  · el ve ayak ×1,05
  · omuz genişliği ×1,04
- Siluet kuralları:
  · Gövde V biçimli.
  · Omuz, boyundan trapez eğimiyle iner.
  · Kollar gövdeden ayrı okunur; aradaki boşluk bele doğru açılır.
  · Bacaklar arasında kasıktan itibaren boşluk var.
  · Hiçbir yerde düz kutu kenarı, basamak ya da bitişme boşluğu yok.
- Işık ve malzeme:
  · Ten: yumuşak, roughness 0,6–0,7.
  · Forma kumaşı: roughness 0,75, ince örgü normali.
  · Krampon: yarı parlak, roughness 0,35.
  · Saç: mat, roughness 0,8, kalın tutamlar.
- Referans: Genel anatomi kaynakları (atletik insan oranları, futbolcu vücut tipi).
  Gerçek bir kişinin fotoğrafından birebir yüz ya da vücut kopyalanmaz.

=====================================================================
3. KARAKTER MODELİ
=====================================================================
3.1 ORANLAR (180 cm Atletik erkek = 5,40 stud; diğer boylar orantılı ölçeklenir)
  Yerden yükseklikler (stud):
    tepe 5,40 · göz 5,05 · çene 4,70 · omuz başı (akromiyon) 4,42 · koltuk altı 4,05
    göğüs ucu 3,89 · dirsek 3,40 · göbek 3,24 · kalça eklemi 2,81 · el bileği 2,62
    kasık 2,54 · parmak ucu 2,04 · diz ortası 1,54 · ayak bileği 0,21
  Genişlik × derinlik (stud):
    · omuz, deltoid dışından: 1,50 (İnce 1,40 / Güçlü 1,60)
    · göğüs (koltuk altı hizası): 1,05 × 0,70
    · bel (en dar): 0,88 × 0,60
    · kalça: 1,02 × 0,66
    · baş: 0,54 geniş × 0,78 yüksek (tepe–çene)
    · boyun çapı: 0,38
    · pazı: 0,34 · ön kolun en kalın yeri: 0,31 · bilek: 0,18
    · el: 0,57 boy × 0,26 en
    · uyluk üstü: 0,52 · diz: 0,36 · baldır: 0,40 · ayak bileği: 0,23
    · ayak: 0,80 boy × 0,30 en
  Boy değişimi (165–195 cm): Gövde ve uzuvlar h/180 ile ölçeklenir; baş yalnız yarısı kadar
  ölçeklenir (1 + 0,5 × (h/180 − 1)), böylece uzun oyuncuda baş küçük kalmaz.
  Yapı farkları:
    · İnce: genişlik ×0,93, kas hacmi az.
    · Güçlü: genişlik ×1,07, derinlik ×1,05; göğüs, omuz ve uyluk daha dolgun.
  Kadın gövdesi (önerilir): aynı iskelet ve forma sistemi; omuz ×0,9, bel ×0,9, kalça ×1,05.

3.2 ANATOMİ (futbolcu, vücut geliştirici değil)
  - Gövde:
    · trapez eğimi; köprücük kemiği hafif
    · göğüs kası alt çizgisi yumuşak
    · karın düz, kaburgalar belli belirsiz
    · sırtta kürek kemikleri ve omurga oluğu hafif
    · latissimus kasıyla V biçimi
  - Kol:
    · deltoid üç başlı yuvarlak
    · pazı ve arka kol ayrımı yumuşak
    · ön kolda dirsekten bileğe incelme
    · el: başparmak ayrı, dört parmak hafif kıvrık; rahat duruşta yarı açık
  - Bacak:
    · uyluk önü güçlü; iç uyluk dolgun
    · diz kapağı belirgin
    · baldır iki başlı, içteki daha aşağıda
    · Aşil tendonu ince
    · ayak bileğinde iç topuk kemiği dıştakinden yüksek
  - Boyun: göğüs-köprücük kası çizgisi hafif; boyun gövdeye kaşla değil, eğimle bağlanır.

3.3 MESH YAPISI VE İSKELET
  - Roblox R15 iskeletli (skinned) gövde: 15 MeshPart, adları birebir:
    Head, UpperTorso, LowerTorso, LeftUpperArm, LeftLowerArm, LeftHand, RightUpperArm,
    RightLowerArm, RightHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, RightUpperLeg,
    RightLowerLeg, RightFoot.
  - Rig eklentileri:
    RootRigAttachment, WaistRigAttachment, NeckRigAttachment,
    Left/RightShoulderRigAttachment, Left/RightElbowRigAttachment,
    Left/RightWristRigAttachment, Left/RightHipRigAttachment,
    Left/RightKneeRigAttachment, Left/RightAnkleRigAttachment.
  - Aksesuar eklentileri:
    HairAttachment, HatAttachment, FaceFrontAttachment, FaceCenterAttachment,
    NeckAttachment, BodyFrontAttachment, BodyBackAttachment,
    Left/RightCollarAttachment, WaistCenter/Front/BackAttachment,
    Left/RightShoulderAttachment, Left/RightGripAttachment, Left/RightFootAttachment.
  - Kemik adları R15 parça adlarıyla aynı. Eklem merkezleri 3.1'deki noktalarda:
    omuz akromiyonun 0,12 altı ve 0,1 içi; kalça eklemi kasığın 0,27 üstü ve
    ortadan ±0,26; diz ve ayak bileği yukarıdaki yüksekliklerde.
  - Ağırlıklar:
    · Omuz: UpperTorso ile UpperArm arasında yumuşak geçiş; omuz başı UpperArm'a %70.
    · Dirsek: komşu iki kemik 50/50; dirseğin içinde hacim kaybını önleyen 2 ek kenar halkası.
    · Bilek: el ve ön kol; ön kolun son %30'u bileğe doğru dönmeye katılır.
    · Bel: LowerTorso ile UpperTorso arası geniş geçiş (göbek ±0,25 stud).
    · Kalça ve kasık: uyluk üstünde 3 halka; kalça kası LowerTorso'ya %60.
    · Diz: bükülünce diz kapağı sivrilir; hacim ±%10 içinde kalır.
  - Dikiş yerleri giysi sınırlarına gizlenir: bel = forma ile şort sınırı, kol = kol ağzı,
    bacak = şort paçası ve tozluk üstü.
  - Katmanlı giysi için gövdede kafes meshleri: _InnerCage ve _OuterCage (WrapTarget).
    Kafes, gövdeye 0,01 stud içten ve dıştan oturur; kafesin köşe sayısı Roblox şablonuyla
    uyumlu olur (Roblox'un güncel kafes şablonunu kullan).

3.4 TOPOLOJİ VE POLİGON BÜTÇESİ
  - Dörtgen ağırlıklı, simetrik, üçgen ve 5'li köşe yalnız düz bölgelerde.
  - Kenar halkaları: omuz 4, dirsek 3, bilek 2, bel 3, kalça 4, diz 3, ayak bileği 2,
    boyun 3.
  - Üçgen bütçesi (LOD0):
    baş 1800 (kulak ve göz dahil) · UpperTorso 1400 · LowerTorso 500 · üst kol 2×350
    ön kol 2×300 · el 2×450 · uyluk 2×450 · baldır 2×400 · ayak 2×200
    → toplam ≈ 8900.
    Krampon ayağın yerini alırsa ayak meshi yalnız bilek bağlantısı kadar olur.
  - LOD: RenderFidelity Automatic. Ayrıca bot oyuncular için %50 üçgenli LOD1 seti hazırla;
    kamera uzaklığı 60 stud'u geçince ya da mobilde kullanılır.
  - Gölge: küçük parçalarda (yaka şeridi, bant, bağcık) CastShadow kapalı.

3.5 UV VE DOKULAR
  - Gövde teni: tek 1024×1024 atlas. Kollar ve bacaklar simetrik UV'yi paylaşabilir.
    Texel yoğunluğu her yerde eşit; yüz hariç.
  - Baş: ayrı 1024×1024. Yüz bölgesi atlasın en az %45'ini kaplar.
  - Normal harita: yüksek poligonlu sculpt'tan (kas çizgileri, diz kapağı, eklem kıvrımları,
    kulak) pişirilir.
  - Roughness haritası: alın ve burunda biraz daha parlak (0,5), gövde 0,65.
  - TEN RENGİ ÇALIŞMA ANINDA SEÇİLEBİLMELİ (6 ton). İki yoldan biri:
    (A) Ten meshleri dokusuz kalır; renk MeshPart.Color'dan gelir; ayrıntıyı normal harita
        verir (SurfaceAppearance içinde yalnız NormalMap ve RoughnessMap).
    (B) 6 ton için önceden hazırlanmış 6 SurfaceAppearance kopyası; ten değişince takas
        edilir (SurfaceAppearance dokuları betikle değiştirilemez, kopya takası yapılır).
    Öneri: A. Hangisinin desteklendiğini ve görünümünü Studio'da doğrula.

3.6 BAŞ, YÜZ, SAÇ, SAKAL
  - Baş:
    · kafatası, alın, kaş kemeri, elmacık, burun (köprü, kanat), dudak, çene açısı, kulak
    · Gözler ayrı küre meshler; göz rengi Color ile.
  - Yüzler (6 hazır): her biri göz şekli, kaş biçimi, burun ve ağız farkıyla ayrışır;
    hiçbiri gerçek bir kişiye benzemez.
    · İfade: Dinamik Baş (FaceControls/FACS) desteklenirse nötr, efor (şut anı), sevinç
      ve üzülme ifadeleri.
    · Desteklenmezse: her yüz için 3 ifade dokusu (nötr, efor, sevinç) ve ifade değişiminde
      hazır doku takası.
  - Saç (8, Config sırasıyla). Her biri ayrı Accessory, HairAttachment'a bağlı, 500–1500
    üçgen, kalın tutamlı mat yüzey:
    1. Sıfır: kafa derisine yapışık kısa doku kabuğu.
    2. Kısa: 2–3 cm, önü hafif kalkık.
    3. Hacimli: üstü 6–8 cm, yanları kısa, geriye taranmış.
    4. Uzun: omuza değen, kulak arkasına alınmış; saç bandıyla da uyumlu.
    5. Kıvırcık: üstte sık bukleler, yanlar kısa (fade).
    6. Topuz: arkası toplanmış, tepe arkasında topuz.
    7. Yanlar kısa: yanlar 0, üstte uzun şerit (undercut).
    8. Kel: saç meshi yok; kafa derisi teni, hafif parlak.
    Saç rengi Color ile; gri ayrıntı dokusu kullanılırsa renk tonu bozulmamalı.
  - Sakal (0–4):
    · 0 Yok
    · 1 Kirli: yalnız doku/ince kabuk
    · 2 Bıyık: mesh
    · 3 Tam: çene hattını izleyen kabuk mesh
    · 4 Keçi: çene ucu ve bıyık
    Renk saçla aynı.
  - Saç bandı (SacBandi): uzun saçta saçın üstünde, kısa saçta alında; ayrı mesh,
    Trim rengi.

3.7 KRAMPON (4 model)
  1. Klasik: deri görünümlü, dili katlanır, 13 krampon dişi.
  2. Hız: ince, alçak bilek, parlak; tabanda üçgen dişler.
  3. Kontrol: örgü çorap bilekli.
  4. Retro: siyah gövde, kalın beyaz şerit (logo değil, düz şerit).
  Her biri: gövde, taban ve bağcık ayrı malzeme bölgesi. Gövde rengi bootColor; taban
  açık gri ya da gövdeyle uyumlu. Sol ve sağ ayrı mesh, LeftFoot/RightFoot'a bağlı.
  600 üçgen.

3.8 BLENDER → ROBLOX AKTARIMI
  - Roblox'un güncel avatar/skinned mesh Blender ayarları belgesini izle (birim ölçeği,
    eksenler, "Add Leaf Bones" kapalı, yalnız armature + meshler seçili).
  - Studio'da 3D Importer ile içe aktar. Kontrol:
    · 180 cm karakter ≈ 5,4 stud
    · eklemler doğru dönüyor
    · Humanoid R15 olarak tanınıyor
  - Rojo ile senkron için: Studio'da hazırlanan varlık klasörünü (FK_Assets) .rbxm olarak
    dışa aktar ve depoya src/ReplicatedStorage/FK_Assets.rbxm olarak koy.
    Mesh kimlikleri (MeshId) Roblox'a yüklenmiş varlıklara bakar; varlıkların sahibi, oyunun
    sahibi olan hesap ya da grup olmalı.
  - OYUNA ETKİSİ: Gerçek oranlı bacaklarla HipHeight ≈ 2,6–2,8 olur (eski gövdede ≈ 2).
    Bu, kafa vuruşu yüksekliğini, kalecinin uzanma mesafesini, topa ayak temas yüksekliğini
    ve kamera ofsetlerini etkiler. Bu değerleri Config'te bul, yeni boya göre yeniden ayarla
    ve sınamalarını güncelle.

=====================================================================
4. FORMA SİSTEMİ
=====================================================================
4.1 PARÇALAR
  Gövdenin dış kafesine oturan ayrı meshler: tercihen katmanlı giysi (WrapLayer); destek
  yoksa gövde kemiklerine kaynaklı kabuk meshler (deriden 0,02–0,04 stud dışarıda).
  Her parça bir FK rolü taşır:
    · Forma gövdesi, kısa kol                         → Shirt / Sleeve
    · Uzun kol (Uzun kol içlik açıkken ve kalecide)   → Sleeve
    · Yaka: bisiklet / V / polo (3 seçenek)           → Trim
    · Kol ağzı şeridi                                 → Trim
    · Şort                                            → Shorts
    · Şort yan şeridi ve paça şeridi                  → Trim
    · Tozluk (dize kadar)                             → Sock
    · Tozluk bandı (üst kenar)                        → Trim
    · Kısa tozluk aksesuarı: tozluk kaval kemiğinin ortasına iner ve tekmelik görünür
      (tekmelik beyaz, rolsüz)
    · Kaptanlık bandı: sol kol, seviye 10'da, altın (FFC83D), rolsüz
    · Kaleci eldiveni: 2 renkli, avuç beyaz, rolsüz
    · Kaleci dirsek pedi                               → Sleeve
  Kol boyu:
    · Kısa kol, üst kolun ortasında biter (omuzdan ≈ 0,5 × üst kol).
    · Şort dizin 0,3 stud üstünde biter.
    · Tozluk diz altının 0,15 stud altında biter.
  Forma, şortun 0,1 stud üstünde serbest biter (içeri sokulmuş değil). Etek kenarı
  çok hafif açılır. Belde ve koltuk altında 2–3 yumuşak kırışıklık normal haritada.

4.2 DESENLER
  Her desen, forma gövdesinin 0,005 stud üstüne oturan ve yalnız desen bölgesini kaplayan
  ikinci bir kabuktur. Rolü "Stripe". Z-fighting yok.
  - Cubuklu: önde ve arkada 4 dikey lacivert çubuk. Gövdenin ön genişliği 9 eşit banda
    bölünür; 2., 4., 6. ve 8. bant çubuktur. Çubuklar gövdeyle birlikte bele doğru daralır
    (göğüste geniş, belde dar) ve yanlara kadar devam eder.
  - Kusakli: göğüste gövdeyi tam saran yatay kuşak; yerden 3,80–4,15 stud arası
    (göğüs ucu hizasının hemen üstü). Arkada da devam eder; numara kuşağın üstüne gelirse
    kontur sayesinde okunur.
  - Duz: desen kabuğu yok; yaka ve kol ağzı Trim rengi.
  - YENİ (önerilir; Config.Appearance.KitPatterns'a eklenir ve sunucu doğrulamasına girer):
    · Yarim: sol yarı Shirt, sağ yarı Stripe
    · Capraz: sağ omuzdan sol kalçaya 0,35 stud genişlikte çapraz kuşak
    · InceCizgi: 2 cm aralıklı ince çizgiler (doku ile)
    · Degrade: göğüsten etek kenarına Stripe rengine geçiş (doku + tint)

4.3 RENK UYGULAMA (ÇALIŞMA ANI)
  - Her renk bölgesi ayrı MeshPart olduğu için renk doğrudan Color ile verilir. FK
    özniteliği zorunlu.
  - Kumaş dokusu: ince örgü NormalMap (512–1024, tekrarlı). SurfaceAppearance kullanılırsa
    ColorMap nötr beyaz kalır. Renk vermenin desteklenen yolunu (Color ya da TintMask)
    Studio'da doğrula.
  - Rakip boyama (MatchAI) aynı öznitelikle çalışmaya devam eder. Yeni bir rol eklenirse
    (ör. "Collar") byRole tablosuna eklenir.

4.4 YAZI, NUMARA, ARMA (ölçüler gerçek forma kurallarına yakın; 1 m = 3 stud)
  - Sırt numarası: 25–30 cm yükseklik (≈ 0,80 stud). Üst kenarı kürek kemiklerinin üstünde.
  - Sırt ismi: 7,5 cm harf (≈ 0,23 stud). Numaranın 0,08 stud üstünde. Düz yazı, 16
    karaktere kadar sığacak biçimde yatay sıkıştırılır.
  - Göğüs numarası: 10 cm (≈ 0,30 stud), sağ göğüste.
  - Şort numarası: 10 cm, sol paçanın önünde.
  - Arma: sol göğüste, göğüs ucu hizasının 0,15 stud üstünde, 0,25 stud. Mevcut Crest
    modülü çizer (şekil, desen, sembol, iki renk). Fenerbahçe'de "FB" yazısı.
  - Uygulama: gövdenin eğimine uyan ince görünmez plakalar üzerinde SurfaceGui
    (ön, arka, şort). Ya da 0–9 rakam atlası (tek doku, ImageLabel + ImageRectOffset).
    Atlas yöntemi daha keskin görünür.
  - Yazı tipi: 3 seçenek (Blok, Klasik, Dar). Renk Ink, kontur InkStroke (2–3 piksel).
  - Maçta bot numaraları dizilişe göre yeniden yazılır (MatchAI rakam olan metinleri
    değiştirir); bu davranış korunur.

=====================================================================
5. ÖZELLEŞTİRME EKRANI
=====================================================================
5.1 YERLEŞİM (1280×720 referans; mobilde dikey yığılır)
  - Solda sekmeler (ikonlu):
    Vücut · Yüz · Saç · Sakal · Krampon · Aksesuar · Forma · Arma
  - Ortada canlı önizleme (ViewportFrame + WorldModel):
    · sürükleyince 360° döner, tekerlek ya da iki parmakla yakınlaştırır (3 ön ayar:
      tüm boy, bel üstü, yüz)
    · yerde halı saha zemini; gece ışığı ve arkadan kontur ışığı
  - Sağda seçenekler: kart ızgarası (küçük resimli), kaydırıcılar ve renk paletleri.
  - Altta: "Rastgele", "Varsayılana dön", "Kaydet".
5.2 KONTROLLER
  - Vücut: boy kaydırıcısı 165–195 cm (1 cm adım, değer yazılı); yapı 3 kart; ten 6 renk
    dairesi.
  - Yüz: 6 kart (küçük resim = önizlemenin yüz yakın çekimi); göz rengi 5 renk
    (önerilir, yeni alan: eyeColor).
  - Saç: 8 kart; 6 renk.
  - Sakal: 5 kart (Yok dahil).
  - Krampon: 4 model kartı; 6 renk.
  - Aksesuar: 4 açma/kapama (Uzun kol içlik, Bileklik, Saç bandı, Kısa tozluk);
    kaptanlık bandı kilitli olarak görünür ("Seviye 10").
  - Forma: desen kartları; numara 1–99 sayı kutusu; isim kutusu (3–16 karakter, anında
    süzme önizlemesi); yaka tipi (önerilir, yeni alan: collar); numara yazı tipi
    (önerilir, yeni alan: font).
  - Arma: mevcut arma düzenleyicisi.
5.3 DAVRANIŞ
  - Her değişiklikte önizleme 0,15 sn içinde güncellenir. Değişen parça kısa bir parlama
    yapar; tık sesi çalar.
  - Önizleme sırayla 3 animasyon oynar: bekleme → top sektirme → seçilen sevinç.
    Sekme değişince ilgili poza geçer (Krampon → ayağa yakın çekim, Saç → yüze yakın çekim).
  - Kaydet: RemoteFunction ile sunucuya gider.
    · Sunucu her alanı izinli listeyle doğrular (Config.Appearance aralıkları, renk listeleri).
    · İsim TextService:FilterStringAsync ile süzülür.
    · Geçerliyse DataStore'a yazar ve karakteri yeniden giydirir; geçersizse hangi alanın
      neden reddedildiği Türkçe bildirimle gösterilir.
  - Kilitli içerik (mağaza ya da seviye): kartta kilit ikonu ve "Seviye N" ya da fiyat.
    Tıklayınca açıklama gösterilir.
  - Yeni alanlar (eyeColor, collar, font, yeni desenler) eklenirse: DataService varsayılan
    değerleri, PlayerService temizleme/doğrulama ve sınamalar birlikte güncellenir.
    Eski kayıtlar varsayılanla açılır.

=====================================================================
6. ANİMASYON
=====================================================================
6.1 GENEL
  - Araç: Roblox Animation Editor (IK destekli), Moon Animator 2 ya da Blender (R15 kemik
    adları). 30 fps anahtar kare.
  - Animasyonlar Animation varlığı olarak, oyunun sahibi olan hesap ya da grup adına
    yüklenir; yoksa oyunda oynamaz.
  - Kimlikler Config.AnimIds tablosuna yazılır: { Shoot = "rbxassetid://…", … }.
  - Animator.luau: Config.AnimIds[eylem] varsa AnimationTrack çalar; yoksa bugünkü
    prosedürel Poses verisine düşer. İki yol aynı olayları (aşağıdaki işaretler) aynı
    anlarda tetikler.
  - İşaretler (Animation Event / Marker): eylem tablosundaki olay adlarıyla BİREBİR aynı:
    strike, jump, land, feint, touch, tackle, slide, block, save, flick, skid.
    Oyun, topa kuvveti ve diğer etkileri GetMarkerReachedSignal ile bu işaret karesinde
    uygular.
  - Öncelikler:
    · Core: bekleme
    · Movement: yürüme / koşu / depar / sürme
    · Action: şut / pas / kafa / müdahale
    · Action2: çalımlar
    · Action3: kaleci
    · Action4: sevinç ve tepkiler
  - "Upper" maskeli eylemler (TopIste, Ucak, Sevinc, Uzulme) yalnız bel üstü kemikleri
    içerir; koşu altta sürerken üstte oynar.
  - Geçişler:
    · giriş karışımı 0,08–0,12 sn, çıkış 0,12–0,18 sn
    · Plonjon soldaki için aynalanır (sağ animasyon yeter)
    · çalımlarda sol ayak sürümü aynalama ile
  - Kalite kuralları:
    · hazırlık (anticipation) → vuruş → takip
    · eğrisel yollar, gecikmeli takip (kol ve baş bir kare geriden gelir)
    · ağırlık merkezi destek ayağının üstünde
    · ayak yere bastığı karelerde kaymaz
    · eklemler doğal sınırlarda (diz geriye bükülmez, dirsek 150°'yi aşmaz)

6.2 HAREKET (LOKOMOSYON) SETİ — Movement önceliği, döngülü
  Hız eşikleri (stud/sn) ve döngü süreleri (1 döngü = 2 adım):
    · Bekleme (0): 2,4 sn nefes döngüsü; göğüs 0,02 stud kalkar; omuzlar hafif. Her 6–10 sn'de
      rastgele çeşitleme: omuz çevirme, kramponla zemine vurma, ellerle tozluğu çekme.
    · Yürüme (≤ 6): 1,05 sn döngü, adım ≈ 2,4 stud. Kollar az sallanır.
    · Hafif koşu (6–12): 0,8 sn döngü.
    · Koşu (12–17): 0,68 sn döngü, adım ≈ 5,8 stud; gövde öne 6°.
    · Depar (17–25): 0,46 sn döngü, adım ≈ 5,75 stud; gövde öne 12–15°; kollar güçlü;
      diz yüksek; ilk 0,3 sn ivmelenme pozu (gövde 20° öne).
    · Geri geri koşu, sağa ve sola yan adım: savunmada ve kalecide.
    · 180° dönüş: 0,35 sn; destek ayağında dönüp ilk adımı atar.
    · Ani duruş (Fren): 0,3 sn; işaret skid 0,05. Ayak öne kayar, gövde geride.
    · Yorgun: koşu döngüsü %10 yavaş; baş hafif önde; durunca eller dizde (1,5 sn).
  Karışım: hız değerine göre ağırlıklar yumuşak geçer. Döngü hızı AdjustSpeed ile gerçek
  yer hızına eşlenir:
    oynatma hızı = (yer hızı / adım uzunluğu) / (2 / döngü süresi)
  Bu, ayak kaymasını ve "bir hızlanıp bir yavaşlama" sorununu önler.
  Dönüşlerde gövde dönüş yönüne 6–10° yatar. Baş ve göğüs topa bakar (IKControl LookAt,
  en çok 40°).
  Top sürme:
    · koşu döngüsünde her iki adımda bir ayağın iç ya da dış yüzüyle dokunuş
      (işaret: touch)
    · deparda uzun dokunuş (her 4 adımda bir)
    · durunca topu tabanla durdurma (0,25 sn)

6.3 AKSİYONLAR — oyundaki sürelere ve olay anlarına UYULMALI
  Süre ve olay anı saniyedir; değiştirilirse oyun dengesi bozulur. Tümünde maske Full,
  aksi yazılmadıkça.
  ŞUT (Action):
    · Shoot 0,62 sn, strike 0,30 — ayak üstü. 0,00 koşu pozundan son adım; 0,18 destek
      ayağı topun yanında (topa 0,4 stud), vuran bacak geride, kollar açık; 0,30 temas
      (kalça döner, ayak bileği kilitli, gövde topun üstünde); 0,45 takip (bacak gövde
      hizasını geçer); 0,62 iniş.
    · Plase 0,52 sn, strike 0,24 — iç taraf. Kalça daha az döner; ayak yana açık; vuruş
      yumuşak, takip kısa.
    · Fuze 0,78 sn, strike 0,38 — uzun gerilme (0,25'te vuran bacak tam geride, kollar
      geniş); temasta iki ayak birden yerden kesilir; takipte zıplayarak iner.
    · Asirtma 0,56 sn, strike 0,26 — ayak topun altına girer; gövde geriye yatar; takip
      yukarı.
    · Vole 0,60 sn, strike 0,28 — gövde yana yatar (40°); vuran bacak yatay savrulur; destek
      ayağında döner.
    · Rovesata 1,05 sn, strike 0,46, land 0,82 — 0,10 sıçrama; 0,30 sırt üstü yatay;
      bacaklar makas; 0,46 temas tepe noktada (baş aşağıda); 0,82 kollarla yere iniş;
      1,05 yarı oturur.
  PAS (Action):
    · Pass 0,40 sn, strike 0,16 — iç taraf; 0,08 geri çekiş; 0,16 temas; kısa takip.
      Uzun basışta aynı animasyon daha yüksek takiple oynar.
  HAVA (Action):
    · Jump 0,70 sn, jump 0,12, land 0,60 — iki ayakla yükselme; kollar yukarı.
    · Header 0,85 sn, jump 0,12, strike 0,44, land 0,74 — havada gövde geriye gerilir;
      0,44'te boyun ve gövde öne kırbaç; gözler açık; kollar denge için yanda.
    · GucluKafa 0,95 sn, jump 0,12, strike 0,50, land 0,84 — gövde yay gibi geriye
      gerilir; daha sert kırbaç.
    · UcanKafa 1,00 sn, strike 0,30, land 0,60 — koşarken öne balıklama; gövde yatay;
      kollar önde; karın üstü kayarak iniş.
    · Makas 1,00 sn, jump 0,10, strike 0,38, land 0,78 — koşarken havada yana yatıp
      bacakları makaslar; yan iniş.
  ÇALIM (Action2):
    · VucutCalimi 0,42 sn, feint 0,20 — omuz ve kalça bir yana, top öbür yana.
    · Bisiklet 0,62 sn, feint 0,34 — topun üstünden önce sağ, sonra sol ayak döner.
    · Marsilya 0,72 sn, touch 0,16, feint 0,44 — topu tabanla durdurur; 360° döner; diğer
      ayakla çeker.
    · Elastico 0,46 sn, touch 0,14, feint 0,26 — dış ayakla iter, aynı ayağın içiyle
      ani geri çeker.
    · Gokkusagi 0,84 sn, flick 0,30, feint 0,44, land 0,64 — top iki ayak arasında; arka
      ayağın topuğuyla baş üstünden aşırılır; gövde öne eğilir.
    · Stagger 0,80 sn (olay yok) — çalımı yiyen oyuncu: dengesini kaybeder, yana sendeler,
      kollar açılır, toparlanır.
  SAVUNMA (Action):
    · AyaktaMudahale 0,48 sn, tackle 0,18 — destek bacağı bükülü; diğer bacak topa uzanır.
    · Omuz 0,50 sn, tackle 0,18 — omuzla yaslanıp ayağı topa sokar.
    · Kayma 1,00 sn, slide 0,10, tackle 0,26 — kalça üstünde kayar; öndeki bacak düz, arka
      bükülü; bir el yerde; 0,70'ten kalkış.
    · Blok 0,55 sn, block 0,15 — gövdeyle öne çıkar; kollar arkada (el ile oynamamak için).
    · UcanBlok 0,80 sn, jump 0,08, block 0,20, land 0,62 — şuta doğru atlar; bacağı ve
      gövdeyi açar.
  KALECİ (Action3):
    · Hazır duruş: dizler bükük, ağırlık parmak uçlarında, eller bel önünde.
    · Yan adım (Movement).
    · Plonjon 1,05 sn, save 0,30, land 0,62 — sağa; sola aynalanır. Yüksek ve alçak
      sürümleri önerilir (aynı olay anları).
    · Önerilen ek animasyonlar: yer topu alma, göğüse alma, yumruklama, ayaklara yatma,
      elle atış, degaj, aut vuruşu.
  TEPKİ VE SEVİNÇ (Action4):
    · TopIste 0,90 sn, Upper — kol kaldırıp topu ister.
    · Ucak 2,20 sn, Upper — kollar iki yana açık, gövde sağa sola yatar; koşarken de oynar.
    · Sevinc 2,20 sn, Upper — iki yumruk havada.
    · DizKaymasi 2,00 sn, slide 0,20 — dizler üstünde kayar; kollar açık; baş geride.
    · Uzulme 1,60 sn, Upper — eller başta.
    · Önerilen: tribünü selamlama, kol kavuşturma, takla, "sessiz ol" işareti, faulde düşme
      ve yerden kalkma, sarı/kırmızı kart tepkisi, sakatlık (bacak tutma).
  DURAN TOP (önerilir): taç atışı, korner vuruşu, penaltı koşusu, frikikte duvarda zıplama.

6.4 YETENEK AĞACI ÖNİZLEMESİ
  SkillTree önizlemesi aynı Animator'ü kullanır. Her animasyon önizlemede kameraya
  3/4 açıyla ve tam boy görünecek biçimde yerinde oynamalı. Kök hareketi (root motion)
  kullanılmaz; ilerleme oyun kodundan gelir.

=====================================================================
7. HALI SAHA HARİTASI
=====================================================================
7.1 KULLANIM
  - Antrenman ve deneme sahası (şut, pas mankenleri, çalım botu, kafa topu; mevcut deneme
    sahasındaki işlevler).
  - Hızlı Maç 7'ye 7 (önerilir):
    · 2 × 120 sn devre, ofsayt yok
    · topa kafes de oyuna dahil: top fileden seker (Config.MatchPitch.Walls benzeri
      Walls = true)
    · kaleci + 6 oyuncu; dizilişler 2-3-1 ve 3-2-1
    · taç yerine kenardan ayakla oyuna sokma
7.2 ÖLÇÜLER (1 m = 3 stud; yeni Config.HaliSaha tablosu)
  - Oyun alanı: 30 × 50 m = 90 × 150 stud. Önerilen yer: X −45…45, Z 45…195
    (mevcut deneme sahasının yerine), zemin Y = −0,02.
  - Kaleler: 3 × 2 m = 9 × 6 stud (GoalHalfWidth 4,5, GoalHeight 6); direk çapı 0,3 stud;
    file derinliği 3 stud; file gergin, hafif sarkık.
  - Çizgiler: 8 cm ≈ 0,25 stud, beyaz F2F2F2, hafif aşınmış.
    · Orta çizgi; orta yuvarlak yarıçapı 9 stud.
    · Ceza alanı 36 × 18 stud; penaltı noktası kaleden 21 stud.
    · Kale alanı 18 × 6 stud.
  - Çizgi dışı güvenlik payı: 2 m = 6 stud. Kafes bu payın dışında.
7.3 ZEMİN
  - Suni çim: Part + MaterialVariant "SuniCim" (ColorMap, NormalMap, RoughnessMap;
    StudsPerTile 6).
  - Biçme şeritleri: 5 m (15 stud) genişlikte, renkler 3C8F3F ve 347F37 sırayla.
  - Aşınma: kale ağızlarında, penaltı noktalarında ve orta noktada daha açık ve kahverengimsi
    lekeler (6E8A45, şeffaflık 0,3, zeminin 0,01 üstünde ince parçalar).
  - Siyah kauçuk granül (1B1B1B) ParticleEmitter ile sıçrar:
    · deparda her adımda 2–3 parça
    · kaymada 15–20 parça
    · şutta destek ayağından 5 parça
    · topun sekişinde 3 parça
    Ömür 0,4–0,7 sn, yerçekimi tam, boyut 0,06–0,1 stud. Mobilde yarı sayıda.
7.4 ÇEVRE VE KAFES
  - Direkler: galvaniz (A7ADB3, Metal), 9 stud arayla, 18 stud (6 m) yükseklik,
    çap 0,35 stud; üstte gergi teli.
  - File: koyu yeşil (1F4D2B). Şeffaf dokulu düzlem (ağ deseni, şeffaflık 0,5). Top
    çarpınca 0,4 sn hafif dalgalanır; "şlak" sesi çıkar.
  - Kale arkasında file 24 stud'a yükselir; isteğe bağlı tavan filesi.
  - Alt pano: 3 stud yüksek tahta ya da plastik panolar. Uydurma yerel sponsorlar:
    "Moda Tüp", "Kadıköy Kırtasiye", "Yoğurtçu Fırını", "Bahariye Spor", "Sarı Lacivert
    Kafe". Gerçek marka yok.
  - Giriş kapısı (kafes kapı), beton yürüme yolu, kapının yanında tabela:
    "MODA HALI SAHA — Saatlik kiralanır" (uydurma).
7.5 IŞIK
  - 8 direk (her uzun kenarda 4): 30 stud (10 m) yükseklik, her birinde 2 LED projektör.
  - SpotLight: Brightness 3, Range 60, Angle 70, renk FFF1DC; sahaya 35° eğik.
    Gölge yalnız 2 projektörde açık (performans).
  - Projektör yüzeyi Neon. Bloom: Intensity 0,6, Size 32, Threshold 1,6.
  - Gece ayarı:
    · ClockTime 20,5; Brightness 1
    · Ambient 4A5068; OutdoorAmbient 5A6075
    · Atmosphere: Density 0,32, Haze 1,6, renk C9D3E6
    · ColorCorrection: Contrast 0,06, Saturation 0,08
  - Gündüz ayarı: ClockTime 16; projektörler kapalı; gölgeler uzun.
  - Gündüz/gece seçimi menüden.
7.6 YEREL AYRINTILAR (her biri 2000 üçgenin altında; CanCollide yalnız gerekenlerde)
  - Soyunma konteyneri: 6 × 2,5 m, beyaz; kapı ve küçük pencere.
  - Çay ocağı: tezgâh, semaver, ince belli çay bardakları, şeker kutusu, plastik tabure,
    küçük televizyon.
  - Oturma: kenarda 10 plastik sandalye, yedek kulübesi bankı (şeffaf çatılı).
  - Elle çevrilen skor tabelası: iki takım, sayı kartları.
  - Su sebili, top filesi (6 top), 12 koni, 3 antrenman mankeni, antrenman merdiveni.
  - Dışarıda: 2 araba, 3 motosiklet, sokak lambaları. Arkada 5–7 katlı apartman blokları;
    balkonlar ve çamaşır ipleri. Uzakta İstanbul'dan esinli genel bir siluet (kubbe ve minare
    biçimleri; gerçek bir bina kopyası değil).
7.7 SES (Creator Store'daki lisanslı sesler ya da kendi kayıtların)
  - top vuruşu (suni çimde tok) 0,8
  - file çarpması 0,6; direkten dönme 0,9
  - top sekmesi 0,4
  - isimsiz kenar bağırışları ("Ver!", "Bende!", "Arkanda!") 0,5 — rastgele, 8–15 sn arayla
  - uzak trafik 0,2 döngü; martı 0,25, 20–40 sn arayla
  - projektör vızıltısı 0,05
7.8 PERFORMANS
  - Dekorda CanCollide, CanQuery ve CanTouch kapalı; CollisionFidelity Box.
  - Statik parçalar Anchored.
  - StreamingEnabled açık; toplam parça < 3000.
  - Mobilde: projektörlerin yarısı, gölgesiz, parçacıklar yarı.

=====================================================================
8. KOD ENTEGRASYONU (Luau)
=====================================================================
8.1 VARLIK KLASÖRÜ: ReplicatedStorage/FK_Assets (depoda FK_Assets.rbxm)
    FK_Assets/
      Body/Atletik, Body/Ince, Body/Guclu    (her biri: 15 R15 MeshPart + kafes)
      Heads/Yuz1..Yuz6                       (baş meshi + ifade dokuları ya da FaceControls)
      Hair/Sac1..Sac7                        (Accessory; 8 = Kel, mesh yok)
      Beard/Sakal1..Sakal4
      Boots/Krampon1..Krampon4               (Left, Right)
      Kit/Shirt, SleeveShort, SleeveLong, Collar_Bisiklet, Collar_V, Collar_Polo, Cuff,
          Shorts, ShortsTrim, Sock, SockBand, SockShort, ShinPad,
          Pattern_Cubuklu, Pattern_Kusakli, Pattern_Yarim, Pattern_Capraz,
          KeeperGloves, ElbowPad, CaptainBand, Headband, Wristband
      Digits/RakamAtlasi                     (0–9 doku kimliği, 3 yazı tipi)
      HaliSaha/…                             (eşya modelleri)
8.2 CharacterService.luau
  - dress(): FK_Assets/Body/<build> varsa buildMeshBody(character, look, kit, skin)
    çağrılır; yoksa bugünkü buildBody (temel şekiller) kullanılır. Bu YEDEK YOL SİLİNMEZ;
    sınamalar ve varlıksız ortam için gerekli.
  - buildMeshBody:
    · R15 parçalarını değiştirir (Humanoid:ReplaceBodyPartR15 ya da şablon karakteri
      kopyalama; doğru yöntemi belgelerden doğrula).
    · Ten rengini uygular.
    · Baş, yüz, saç, sakal aksesuarlarını takar.
    · Forma parçalarını (WrapLayer ya da kaynak) takar; her birine FK rolü verir ve rengini
      kit tablosundan uygular.
    · Desen kabuğunu kitPattern'e göre ekler.
    · Baskı plakalarını (ön, arka, şort) ve armayı (Crest.Fill, "FK_Crest" adlı kare) kurar.
    · Aksesuarları (UzunKol, Bileklik, SacBandi, KisaTozluk, kaptanlık bandı) uygular.
    · Boy için HumanoidDescription ölçeklerini ayarlar.
  - BuildBotTemplates aynı yoldan kurar. MatchAI'deki rakip boyama ve numara yazma
    değişmeden çalışmalı.
8.3 Animator.luau
  - Play(action, opts):
    · Config.AnimIds[action] varsa: humanoid'in Animator'ünden LoadAnimation (her eylem
      bir kez yüklenip önbellekte tutulur), Priority 6.1'deki gibi, opts.Mirror için
      aynalanmış ayrı kimlik (AnimIds[action .. "_L"]).
    · Poses.Actions[action].Events'teki her olay adı için GetMarkerReachedSignal bağlanır;
      prosedürel yolla aynı geri çağırmalar tetiklenir.
  - Update(dt, state): lokomosyon ağırlıkları ve AdjustSpeed (6.2 formülü); IKControl ile
    baş/göğüs topa bakar; destek ayağı yere oturur.
  - Current(): oynayan aksiyon var mı (önizleme döngüsü bunu kullanır).
8.4 Config.luau
  - AnimIds tablosu.
  - Appearance'a yeni alanlar (eyeColor, collar, font, yeni desenler) ve sınırları.
  - HaliSaha ölçü tablosu.
  - Gerçek boya göre güncellenen kafa vuruşu, uzanma ve temas yükseklikleri.
8.5 Yeni modül: Shared/HaliSaha.luau
  - Build(options): zemin, çizgiler, kaleler, kafes, ışık, eşyalar, ses.
  - SetNight(bool).
  - Antrenman sahası ve 7'ye 7 modu bunu kullanır.
8.6 SINAMALAR (tests/spec.luau)
  - Yedek yol (varlık yok): bugünkü bütün denetimler geçmeye devam eder.
  - Varlık şablonu taklidiyle (prelude'da sahte FK_Assets):
    · her FK rolünden en az bir parça var
    · desen kabuğu Stripe renginde
    · kaleci rakipte boyanmıyor
    · arma ve numara plakaları var
  - Animasyon:
    · Poses.Actions'taki her eylem için AnimIds anahtarı ya da bilinçli boşluk listesi
    · işaret adları olay adlarıyla aynı
    · strike işaretinde top kuvveti uygulanıyor
  - Görünüm doğrulaması: geçersiz değerler (boy 300, saç 99, bilinmeyen renk) reddediliyor;
    eski kayıt yeni alanlarla açılıyor.
  - Halı saha: ölçüler Config'ten; kaleler doğru yerde; kafes kapalı bir dikdörtgen; top
    kafesten seker.

=====================================================================
9. AŞAMALAR VE KABUL
=====================================================================
AŞAMA 1 — Temel gövde (Atletik), 1 yüz, 1 saç (Kısa), Cubuklu forma, 1 krampon, lokomosyon
          (bekleme, yürüme, koşu, depar, dönüş, fren) ve entegrasyon.
  Kabul:
  [ ] 10 m ve 30 m'den önden, yandan, arkadan bakınca kutu, basamak ya da boşluk yok.
  [ ] Omuz-kol, gövde-şort, şort-uyluk, tozluk-krampon geçişleri kesintisiz.
  [ ] Koşu ve deparda ayak kayması yok: ayak yere bastığı karelerde zemin hızı ±%10.
  [ ] Rakip formasında renkler tüm bölgelere geçiyor; kaleci değişmiyor.
  [ ] Yetenek ağacı önizlemesi yeni gövdeyle çalışıyor.
  [ ] Bütün sınamalar geçiyor.
AŞAMA 2 — Bütün yüzler, saçlar, sakallar, kramponlar, aksesuarlar, bütün desenler ve
          özelleştirme ekranı.
  Kabul:
  [ ] Her seçenek önizlemede 0,15 sn içinde değişiyor.
  [ ] Kaydet → oyundan çık → gir: aynı görünüm.
  [ ] Geçersiz veri sunucuda reddediliyor ve Türkçe hata gösteriliyor.
AŞAMA 3 — Bütün aksiyonlar (şut, pas, hava, çalım, savunma, kaleci) ve sevinçler.
  Kabul:
  [ ] Her vuruşta top kuvveti strike karesinde (±1 kare).
  [ ] Olay anları 6.3 tablosuyla aynı.
  [ ] Aynalanan sürümler doğru tarafa gidiyor.
AŞAMA 4 — Halı saha haritası (gündüz/gece) ve 7'ye 7 modu.
  Kabul:
  [ ] Ölçüler 7.2'deki gibi.
  [ ] Gece ışığı sahayı eşit aydınlatıyor (köşelerde karanlık yok).
  [ ] Granül ve file efektleri çalışıyor.
  [ ] Mobilde 30 FPS.
AŞAMA 5 — Performans ve cila.
  Kabul:
  [ ] 22 oyuncu + stadyum: orta seviye PC'de 60 FPS, orta seviye telefonda 30 FPS.
  [ ] Bellek ve parça sayısı ölçülüp raporlanmış.
Her aşamanın sonunda: Studio'dan önden, yandan ve arkadan karakter görüntüleri; her yeni
animasyonun kısa kaydı; halı sahanın gündüz ve gece görüntüleri.

=====================================================================
10. YAPMA LİSTESİ
=====================================================================
- Gerçek futbolcunun yüzünü, adını, dövmesini, saç modelini birebir kopyalama.
- Resmî logo, marka, lig ya da oyun varlığı (FIFA/EA FC/eFootball) kullanma ya da birebir
  taklit etme.
- Oyundaki süreleri, olay anlarını ve hızları sormadan değiştirme.
- FK rolleri, FK_Crest ve "Stripe" adlandırma sözleşmesini bozma.
- Varlıksız yedek yolu silme.
- Parça kod verme; değişen dosyayı tam ver.
- Doğrulamadığın API'yi kesin bilgi gibi yazma.
```

---

## 2. ARAÇ PROMPTLARI (İngilizce)

Her promptun sonunda "Negative" satırı, aracın desteklediği "negatif prompt" alanına yazılır.
Önce A ile çizim (dönüş sayfası) üret, sonra B–F'yi "image-to-3D" ya da "text-to-3D" aracında
bu çizimi referans vererek kullan.

### A) Karakter dönüş sayfası (görsel üretimi)
```text
Character design turnaround sheet of an original football player for a stylized-realistic
video game: front view, side view and back view side by side, A-pose with arms 45 degrees
down, full body, orthographic, plain light-gray background, even studio lighting.
Athletic male, 180 cm, realistic human proportions about 7 heads tall with a very slightly
larger head, broad chest and back tapering to a narrow waist (V-shape), sloped trapezius
shoulders, rounded deltoids, toned (not bodybuilder) arms, strong thighs, defined calves,
visible neck. Generic friendly face that does not resemble any real person, short dark hair.
Kit: yellow (#FFE600) short-sleeve football shirt with four vertical navy (#0B1747) stripes
that taper with the torso, navy crew collar and cuffs, navy shorts with a thin yellow side
stripe, yellow socks with a navy top band, black boots. Clean readable shapes for game
modeling, matte fabric.
Negative: logos, brand marks, text, numbers, real athletes, celebrity likeness, cartoon chibi
proportions, blocky shapes, extra limbs, perspective distortion, dramatic lighting, background
scenery.
```

### B) Çıplak temel gövde (3B)
```text
Game-ready base mesh of an original athletic male football player for a stylized-realistic
game, A-pose, 1.80 m tall, realistic proportions about 7 heads tall: V-shaped torso, sloped
trapezius shoulders, rounded deltoids, subtle pectoral and abdominal definition, shoulder
blades, toned arms, strong quadriceps, visible kneecaps, two-headed calves, slim ankles.
Clean symmetrical quad topology with extra edge loops at shoulders (4), elbows (3), wrists (2),
waist (3), hips (4), knees (3), ankles (2) and neck (3). About 7,500 triangles without the
head. Wearing only plain tight neutral-gray shorts. Bald, neutral expression. Separate head
and separate eyeballs. Hands relaxed and slightly curled, thumb separate. Skin albedo in
neutral light gray for runtime tinting, plus normal map and roughness map at 1024 px baked
from a high-detail sculpt.
Negative: clothing other than shorts, hair, logos, real person likeness, exaggerated muscles,
cartoon proportions, non-manifold geometry, n-gons, asymmetry.
```

### C) Baş ve 6 yüz (3B)
```text
Six original male head variants for the same game character base, stylized-realistic,
identical neck seam and topology (about 1,800 triangles each), separate eyeballs, neutral
expression: 1) oval face with straight nose, 2) square jaw with heavy brow, 3) round face with
soft features, 4) long face with high cheekbones, 5) narrow face with hooked nose, 6) broad
face with wide nose and full lips. Each must clearly differ in silhouette from the front and in
profile. None should resemble any real person. Neutral light-gray skin albedo for runtime
tinting, 1024 px normal and roughness maps.
Negative: real people, celebrities, athletes, hair, beards, makeup, tattoos, extreme caricature.
```

### D) Saç paketi (3B)
```text
Set of 7 game-ready hair meshes fitted to the same stylized-realistic male head, each a
separate accessory, 500–1,500 triangles, chunky sculpted strand clumps (no hair cards), matte,
neutral gray albedo for runtime tinting: 1) very short buzz cut as a thin scalp shell,
2) short 2–3 cm hair with slightly lifted front, 3) voluminous top 6–8 cm swept back with short
sides, 4) shoulder-length hair tucked behind the ears compatible with a sports headband,
5) tight curly top with faded sides, 6) hair tied into a bun at the crown, 7) undercut with
shaved sides and a long top strip.
Negative: hair cards, transparency, real hairstyle of a famous person, accessories, faces.
```

### E) Sakal paketi (3B)
```text
Four facial hair meshes fitted to the same male head, matte, neutral gray albedo for tinting,
each under 600 triangles: 1) light stubble as a thin shell following the jaw, 2) moustache only,
3) full short beard following the jawline and connecting to the moustache, 4) goatee with
moustache.
Negative: long wizard beards, braids, real person likeness.
```

### F) Krampon paketi (3B)
```text
Four original football boot designs for a game character, left and right pair, about 600
triangles each, separate material zones for upper, sole and laces so each can be tinted at
runtime, studs on the sole, no brand logos: 1) classic leather-look boot with fold-over tongue
and 13 round studs, 2) slim low-cut speed boot with glossy upper and bladed studs, 3) control
boot with knit sock collar, 4) retro black boot with one thick plain white side stripe (not a
logo). Neutral white albedo, 1024 px normal map, roughness 0.35 on the upper.
Negative: brand logos, swooshes, three-stripe marks, text, real product copies.
```

### G) Forma kabukları ve desenler (3B)
```text
Football kit clothing meshes for an athletic stylized-realistic base body, made as fitted
layered-clothing shells 0.5–1 cm off the skin: short-sleeve shirt (sleeve ends mid upper arm,
untucked hem slightly flared), long-sleeve undershirt, three separate collars (crew, V-neck,
polo), sleeve cuff band, shorts ending 10 cm above the knee with side panel and hem band,
knee-high socks with top band, a short-sock variant that shows a white shin pad. Separate thin
pattern shells sitting 1 mm above the shirt: four vertical stripes that follow and taper with
the torso front and back, a horizontal chest band wrapping around the whole torso, a diagonal
sash from right shoulder to left hip, a left/right half split. Subtle tiling knit-fabric normal
map and soft wrinkles at waist and armpits. Neutral white albedo for runtime tinting, no
logos, no text.
Negative: logos, sponsor marks, numbers, names, real club designs, baggy oversized fit.
```

### H) Kaleci ekipmanı (3B)
```text
Goalkeeper equipment for the same game character: padded goalkeeper gloves (two-tone cuff and
back, white palm, about 500 triangles each), elbow pads that fit over a long sleeve, separate
material zones for tinting, no logos.
Negative: logos, text, baseball gloves, boxing gloves.
```

### I) Halı saha eşyaları (3B)
```text
Modular game-ready assets for an original Turkish neighborhood 7-a-side artificial turf pitch
at night, realistic and slightly worn, each under 2,000 triangles, PBR textures 1024 px:
galvanized steel fence posts (6 m) with dark green netting panels (alpha texture),
10 m floodlight poles with two rectangular LED heads, small 3×2 m goals with nets,
1 m tall wooden kickboard panels for fictional local ads, a white prefab changing-room
container with door and small window, a small tea kiosk with counter, samovar and thin
tulip-shaped tea glasses on saucers, plastic chairs and stools, a substitutes bench with a
clear canopy, a manual flip scoreboard, a water dispenser, a ball net bag with six balls,
orange training cones, training mannequins, an agility ladder, street lamps, a parked scooter.
Negative: real brand names, logos, text other than blank signs, high-poly film assets.
```

### J) Suni çim ve çizgi dokusu (doku/malzeme üretimi)
```text
Seamless tileable PBR material of artificial football turf seen from above at 1 m × 1 m:
dense synthetic grass blades with slight direction, black rubber granules visible between the
blades, subtle color variation, no stripes, no lines. Outputs: albedo (green #3C8F3F
average), normal, roughness (0.8), ambient occlusion, 1024 px.
Second variant: the same turf worn and flattened in goal mouths, more granules visible,
lighter yellow-brown tone.
Third: white painted line on turf, 8 cm wide, slightly worn edges, alpha channel.
```

### K) Arka plan (gökyüzü ve şehir)
```text
Night skybox and distant city backdrop for a game: dark navy evening sky with faint clouds lit
from below by city light, distant generic Istanbul-inspired skyline silhouette with domes,
thin minaret shapes and apartment blocks on hills, warm window lights, light haze; no real
identifiable landmark copies. Six cube-map faces 1024 px each, plus a separate wide 4096×1024
backdrop strip with alpha.
Negative: specific real landmarks rendered accurately, text, logos, moon too large, people.
```

---

### Notlar
- Varlıklar Roblox'a yüklendikten sonra kimlikleri ve `FK_Assets.rbxm` dosyası depoya
  konursa, kod tarafındaki entegrasyon (8. bölüm) bu depoda yapılabilir.
- Animasyonlar ve meshler, oyunun sahibi olan hesap ya da grup adına yüklenmelidir.
- Bu dosyadaki sayılar, oyunun şu anki Config ve Poses değerleriyle uyumludur; oyun
  değiştikçe bu tablonun da güncellenmesi gerekir.
