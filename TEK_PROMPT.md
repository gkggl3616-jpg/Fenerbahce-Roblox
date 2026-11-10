# Fener Kariyer: Tek Prompt

Aşağıdaki bloğun tamamını kopyalayıp Claude'a (veya başka bir kod asistanına) ver. Oyunun tamamını, maç mekaniklerini, animasyon sistemini, efektleri ve arayüzü tek seferde tarif eder.

```text
ROL
Sen kıdemli bir Roblox oyun geliştiricisi, oynanış tasarımcısı ve arayüz/hareket tasarımcısısın. Benimle birlikte "Fener Kariyer" adlı tek oyunculu futbol kariyer oyununu yapacaksın. Oyun bir Fenerbahçe taraftar topluluğu için. Hedef kalite: mobil bir konsol futbol oyunu hissi. Basit, düz, hareketsiz hiçbir ekran kabul edilmez; her etkileşimin animasyonu, sesi ve efekti olur.

TEKNİK ÇERÇEVE
- Luau, Rojo yapısı (src/ServerScriptService, src/ReplicatedStorage, src/StarterPlayer, src/StarterGui). Modüler kod, her modülün başında kısa açıklama.
- Tek oyunculu maç: takım arkadaşları ve rakipler bot. Sunucu kayıt (DataStore, oturum kilidi, pcall ve yeniden deneme) ve dünya sıralaması (OrderedDataStore) içindir.
- Bakiye, XP, özellik, yetenek, kulüp kademesi yalnızca sunucuda değişir. Her RemoteEvent girdisi tip ve aralık kontrolünden geçer.
- Görsel: Lighting.Technology = Future, Atmosphere, Bloom, ColorCorrection, DepthOfField (sinematiklerde), SunRays. StreamingEnabled açık.
- Platform: mobil, PC, konsol. Mobil birinci sınıf vatandaş; 60 FPS hedefi, düşük detay modu.
- Tüm ayar sayıları tek bir Config modülünde durur, koda gömülmez.

==================================================
1) OYUNUN ÖZÜ
==================================================
Oyuncu kendi futbolcusunu ve kendi kulübünü yaratır. Kulüp amatör ligde, mahalle sahasında başlar. Sezonlar kazanıldıkça lig atlar ve stadyumu büyür. En tepede Fenerbahçe'den teklif gelir ve oyuncu Kadıköy'de, Şükrü Saracoğlu'nda oynar.

Katmanlar:
- Futbolcu: seviye 1-30, altı özellik, beş yetenek zinciri.
- Kulüp: Amatör > 3. Lig > 2. Lig > 1. Lig > Süper Lig. Sezon 6 takım, 10 maç, ilk iki yükselir.
- Tesis: çim, tribün eki, aydınlatma, soyunma odası, antrenman sahası, sağlık merkezi. Kulüp kasasıyla (maç geliri) gelişir ve sahada görünür.
- Efsane: Süper Lig şampiyonluğu veya seviye 25 + güç 85 ile Fenerbahçe transferi.

Stadyum kademeleri (kapasite, ışık): 1 Mahalle Sahası (150, bulutlu gündüz), 2 İlçe Stadı (1.800, öğleden sonra), 3 Şehir Stadı (8.500, gün batımı), 4 Modern Stadyum (21.000, alacakaranlık), 5 Arena (34.000, gece), 6 Şükrü Saracoğlu (47.800, gece maçı, koreografi ve dev bayraklar).

==================================================
2) KARAKTER VE KULÜP
==================================================
- Kalıcı: futbolcu adı (TextService filtresi) ve mevki (Kaleci, Defans, Orta Saha, Forvet). Mevki ASLA değişmez; sunucu kilitler, ikinci onay penceresi çıkar.
- Özelleştirme: boy 165-195 cm, yapı (ince, atletik, güçlü), 6 ten, 6 yüz, 8 saç modeli + serbest renk, 4 sakal, krampon modeli ve rengi, aksesuarlar (kaptan bandı, uzun kol içlik, bileklik, saç bandı, eldiven, tozluk boyu), forma numarası. Boy ve yapı yalnızca görünümdür, isabet kutusu sabittir.
- Model: gerçekçi insan oranlarında R15, özel MeshPart gövde. Forma, şort, tozluk, krampon gövdeden ayrı katmanlar. Forma dokusu çalışma anında üretilir: desen, arma, isim, numara.
- Kulüp: ad, 2-3 harf kısaltma, arma şekli, forma deseni. Renkler sarı-lacivert ailesiyle sınırlı.

Özellikler (1-10, bakiye ile): Hız, Top Kontrolü, Pas, Şut, Defans, Fizik (dayanıklılık + hava hakimiyeti + güç).
Yetenek zincirleri (sıralı kilit; önceki açılmadan sonraki açılamaz; seviye + bakiye şartı):
- Şut: Normal > Plase > Füze > Aşırtma > Vole > Röveşata > Serbest vuruş ustası
- Çalım: Vücut çalımı > Top sürükleme > Marsilya > Nutmeg > Elastico > Rabona > Gökkuşağı
- Hava: Zıplama > Kafa vuruşu > Güçlü kafa > Uçan kafa > Makas vuruşu
- Defans: Ayakta müdahale > Pas arası > Omuz mücadelesi > Kayarak müdahale > Blok > Son adam
- Özel güç: Turbo > Demir adam > Kaptan lider > Efsane an
- Kaleciye özel: Plonjon > Yumruk > Bire bir çıkış > Uzun degaj > Penaltı uzmanı

==================================================
3) MAÇ HİSSİYATI VE MEKANİKLER (en önemli bölüm)
==================================================
Genel: 11'e 11, 2 x 3 dakika gerçek süre. Top sunucu otoriteli ayrı bir fizik nesnesidir; oyuncuya yapışmaz, her dokunuşla itilir.

3.1 HAREKET
- Yürüme, koşu, sprint. İvmelenme ve yavaşlama süresi var (0'dan tam hıza 0,45 sn), ani dönüşte hız kaybı ve ayak kayma animasyonu.
- Sprint dayanıklılık harcar; dayanıklılık bitince hız %25 düşer ve nefes animasyonu oynar.
- Topla koşarken hız %8 düşer; Top Kontrolü yükseldikçe bu ceza azalır.

3.2 TOP KONTROLÜ VE İLK DOKUNUŞ
- Top oyuncunun önünde 0,6-1,4 stud aralığında gider; sprintte daha uzağa itilir ve kapılması kolaylaşır.
- İlk dokunuş: gelen topun hızına ve Top Kontrolü özelliğine göre top yakın kalır veya açılır. Yön tuşuyla ilk dokunuş yönlendirilebilir.
- Top saklama (tuşa basılı tut): oyuncu sırtını rakibe döner, yavaşlar, topun kapılması zorlaşır.

3.3 PAS
- Yerden pas (kısa bas), sert pas (uzun bas), havadan pas, ara pası, duvar pası (pas + hemen koşu).
- Hedef seçimi yön + pas gücüne göre; hedef takım arkadaşının üstünde ince sarı halka ve pas çizgisi önizlemesi.
- Pas isabeti = Pas özelliği, vücut yönü ve baskı altında olma durumuna bağlı.

3.4 ŞUT
- Şut tuşuna basılı tut: güç barı dolar. Barın sonundaki yeşil pencerede bırakmak "mükemmel vuruş"tur (ek hız, ek isabet, özel efekt). Fazla tutmak topu havaya diker.
- Nişan: yön girdisi kalede bir hedef noktası seçer; nişan halkası Şut özelliği düşükse geniş, yüksekse dardır. Baskı ve denge halkayı büyütür.
- Falso: şut sırasında yana yön vererek. Zayıf ayak cezası vardır.
- Şut türleri ve davranışları:
  Normal: düz, orta hız.
  Plase: yavaş ama isabetli, köşeye kıvrılır.
  Füze: çok hızlı, düşük isabet, top arkasında iz bırakır, kaleci elinden kaçırabilir.
  Aşırtma: kaleci ilerideyken üstünden.
  Vole: havadan gelen topa yere düşmeden; zamanlama halkası ister.
  Röveşata: top bel üstü yükseklikte ve oyuncunun arkasına doğru gelirken; zamanlama halkası; başarıda yavaş çekim.
  Kafa: aşağıda 3.6.
  Serbest vuruş ve penaltı: ayrı nişan ekranı, güç + falso + kaleci aldatma.

3.5 ÇALIM SİSTEMİ
- Çalım tuşu + yön = hareket. Her çalımın bir "kazanma penceresi" vardır: rakip müdahale animasyonuna girdiği 0,25 saniyelik anda yapılırsa rakip dengesini kaybeder (sendeleme animasyonu, 0,8 sn devre dışı).
- Hareketler: vücut çalımı (yön değiştirme), top sürükleme, Marsilya dönüşü, nutmeg (bacak arası), elastico, rabona, gökkuşağı, sahte şut (şut + pas iptal), dur-kalk.
- Art arda başarılı çalımlar "kombo" sayacı doldurur; kombo dolunca kısa süreli Turbo ve tribün uğultusu gelir.
- Çalım dayanıklılık harcar; yanlış zamanda yapılırsa top açılır.

3.6 ZIPLAMA VE HAVA TOPLARI
- Zıplama tuşu: yerinde ve koşarak sıçrama. Yükseklik Fizik özelliğine bağlı.
- Havadan gelen topun düşeceği yerde yerde daralan bir halka görünür. Halka en dar olduğu anda zıplamak en yükseğe çıkarır.
- Hava mücadelesi: iki oyuncu aynı topa çıkarsa Fizik + zamanlama + pozisyon karşılaştırılır; kaybeden itilir ve dengesizlik animasyonu oynar.
- Kafa vuruşları: yere doğru kafa (kaleciye zor), yönlendirme kafası, güçlü kafa, uçan kafa (dalarak), kafa pası. Yön girdisi topun gideceği köşeyi seçer.
- Kafa golü ayrı kutlanır: "KAFA GOLÜ" yazısı, ek XP.
- Makas vuruşu ve röveşata bu sistemin üst basamağıdır.

3.7 DEFANS
- Kademe (savunma duruşu): tuş basılıyken oyuncu rakibe dönük yan yan hareket eder, hızı düşer ama çalıma karşı direnci artar.
- Ayakta müdahale: kısa menzil, düşük risk. Zamanlama doğruysa top temiz alınır.
- Kayarak müdahale: uzun menzil, yüksek risk. Topa önce değerse temiz; ayağa değerse faul, arkadan gelirse kart.
- Omuz mücadelesi: yan yana koşarken Fizik karşılaştırması.
- Pas arası: pas çizgisine girip tuşa basarak; başarıda top kontrolle alınır.
- Blok: şut anında önünde durup tuşa basınca vücutla engelleme animasyonu.
- Takım presi çağırma: tuşla en yakın iki bot topa baskı yapar (dayanıklılık harcar).
- Son adam müdahalesi ve çizgiden çıkarma özel animasyonlu anlardır.

3.8 KALECİ (oyuncu kaleciyse)
- Kamera kalenin arkasına geçer. Şut anında yön + zamanlama ile plonjon; mükemmel zamanlamada top tutulur, geç kalınırsa çelinir.
- Çıkış, yumruklama, bire birde küçülme, elle ve ayakla degaj, penaltıda yön tahmini.

3.9 KURALLAR VE DURAN TOPLAR
- Faul, avantaj, sarı/kırmızı kart, basitleştirilmiş ofsayt, taç, korner, aut, penaltı, serbest vuruş.
- Korner ve serbest vuruşta oyuncu forvetse ceza sahasında pozisyon alır, hava topu sistemi devreye girer.

3.10 MOMENTUM VE DUYGU
- Maç momentumu çubuğu: üst üste atak, çalım ve isabetli şut çubuğu doldurur; dolunca takım arkadaşı botlar daha agresif olur ve tribün koreografi yapar.
- Oyuncu formu: maç içi performans puanı (10 üzerinden) canlı güncellenir.
- Baskı anları: son dakikalar ve tek farklı skorda kalp atışı sesi, hafif vinyet, tribün gerilimi.

3.11 BOT YAPAY ZEKASI
- Rol tabanlı durum makinesi: diziliş pozisyonu, destek koşusu, boşa kaçma, pres, kademe, top kapma, pas seçimi, şut kararı.
- Takım arkadaşları oyuncuya pas için koşu yapar ve el kaldırarak top ister.
- Zorluk kademeyle artar: tepki süresi, pas isabeti, müdahale zamanlaması.
- Rakip kaleci şut türüne göre farklı kurtarış animasyonu seçer.

==================================================
4) ANİMASYON SİSTEMİ
==================================================
- Katmanlı durum makinesi: alt gövde (hareket), üst gövde (denge, kol), tam gövde (aksiyon), yüz/baş (bakış topa döner).
- Yön karışımı: 8 yönlü koşu blend'i, hıza göre yürüyüşten sprinte kesintisiz geçiş. Geçiş süreleri 0,1-0,2 sn.
- Animasyon olayları (marker): ayak yere basma (ses + toz), topa temas (top fiziği tam bu karede tetiklenir), en yüksek nokta, yere düşme.
- Topa uzanma: vuruş ayağı ve baş, topun gerçek konumuna IK ile hizalanır; ayak yerde kaymaz.
- Vuruş hissi: mükemmel vuruşta 0,06 sn hit-stop, kamera sarsıntısı, top sıkışma (squash) efekti.
- Her animasyonun hazırlık, vuruş ve toparlanma bölümü vardır; toparlanma sırasında girdi tamponu (input buffer) tutulur.
- En az şu animasyon seti:
  Hareket: bekleme (3 varyasyon), yürüme, koşu, sprint, geri geri, yan adım, ani dönüş, fren, yorgun koşu, nefes alma.
  Topla: sürme (yavaş/hızlı), ilk dokunuş (ayak, göğüs, diz, baş), top saklama.
  Pas: iç ayak, sert, havadan, topuk, kafa pası.
  Şut: normal, plase, füze, aşırtma, vole (sağ/sol), röveşata, makas, penaltı, serbest vuruş.
  Çalım: her hareket için ayrı animasyon + rakibin sendelemesi.
  Hava: zıplama, kafa (4 tür), hava mücadelesi kazanma/kaybetme, yere iniş.
  Defans: kademe duruşu, ayakta müdahale, kayma, omuz, blok, pas arası, çizgiden çıkarma.
  Kaleci: hazır duruş, plonjon (alt/orta/üst x sağ/sol), yumruk, tutuş, çıkış, degaj, gole üzülme.
  Tepki: düşme, kalkma, faul sonrası acı, itiraz, alkış, top isteme (el kaldırma), işaret etme.
  Sevinç: diz kayması, kollar açık koşu, kol kavuşturma, salto, armayı öpme, tribüne koşma, takım kucaklaşması.
  Üzüntü: kaçan gol (baş tutma), yenilgi (çökme).
  Sinematik: tünelden çıkış, sıralanma, tokalaşma, kupa kaldırma.
- Seyirci: oturan, ayakta, zıplayan, bayrak sallayan, atkı açan döngüler; golde hepsi ayağa kalkar.

==================================================
5) KAMERA
==================================================
- Maç: oyuncunun arkasından, hafif yukarıdan; hıza göre FOV 2-4 derece genişler; top uzaktaysa kamera hafif açılır.
- Şut gücü dolarken hafif yakınlaşma, mükemmel vuruşta kısa itme.
- Röveşata, kafa golü ve son dakika golünde yavaş çekim (0,5x-0,6x) ve yakın kamera.
- Gol tekrarı: iki açı (kale arkası, yan), atlanabilir.
- Sinematikler: tünel, VS, lig atlama (stadyum dönüşümü), kupa töreni. DepthOfField ve letterbox şeritleri.

==================================================
6) GÖRSEL EFEKTLER
==================================================
- Top: hızlı şutta iz (şut türüne göre renk: füze kırmızı-turuncu, plase sarı), falsoda dönen çizgiler, vuruşta halka dalgası, fileye çarpınca file dalgalanması.
- Saha: koşuda çim parçacığı, kaymada uzun çim izi ve toz, yağmurlu maçta su sıçraması.
- Oyuncu: sprintte hız çizgileri, Turbo'da sarı-lacivert aura, çalım kazanınca rakipte yıldız/sendeleme efekti, mükemmel zamanlamada parlama.
- Gol: konfeti (sarı-lacivert), ekran flaşı, tribünde meşale ve duman, skor tabelası patlaması, kamera sarsıntısı.
- Stadyum: projektör hüzmeleri, hafif sis, LED panolarda kayan yazı, golde panolar "GOL" yazar, koreografi açılır, dev bayraklar dalgalanır.
- Arayüz efektleri: aşağıda 7. bölüm.
- Tüm efektler kalite ayarına göre ölçeklenir.

SES: tezahürat döngüsü atakta yükselir, golde patlar; vuruş sesi güce göre değişir; file, direk, düdük, ayak, kayma sesleri; arayüz için kısa tıklama, onay, hata, ödül sesleri; baskı anında kalp atışı. Telifli marş kullanma, topluluk kaydı için ses yuvası bırak.

==================================================
7) ARAYÜZ (UI/GUI): ÇOK GELİŞMİŞ VE HAREKETLİ
==================================================
7.1 TASARIM DİLİ
- Renkler: Sarı #FFE600, Lacivert #0B1747, Mavi #1A2D86, Zemin #050B26, Metin #EEF1FF, Soluk #9AA6DF, İyi #3DDC84, Kötü #FF6B6B, Altın #FFC83D.
- Yazı: başlıklar kalın, dar, büyük harf (GothamBlack ya da benzeri), metinler Gotham. Rakamlar eş genişlikli.
- Şekil dili: eğik kesilmiş (10 derece) panel kenarları, kalkan rozetler, çubuklu (dikey sarı-lacivert) vurgu şeritleri, ince sarı çerçeve çizgileri.
- Derinlik: paneller yarı saydam lacivert cam (arkası bulanık), üstte ince parlak kenar, altta yumuşak gölge. UIGradient ve UIStroke kullan.
- Her panelin arkasında çok hafif hareket eden çubuk deseni veya parçacık.

7.2 HAREKET KURALLARI
- Hiçbir şey aniden belirmez. Giriş 0,25-0,35 sn, çıkış 0,15-0,2 sn. Easing: girişte Quint Out, vurguda Back Out, çıkışta Quad In.
- Paneller kayarak + saydamlaşarak gelir, öğeler 0,04 sn arayla sırayla (stagger) dizilir.
- Butonlar: üzerine gelince %4 büyür ve parlaklık süpürmesi geçer; basınca %96'ya çöker ve geri yaylanır; tıklamada dalga halkası.
- Sayılar artarken sayaç animasyonu; kazanılan bakiye ve XP ikonları uçarak sayaca gider ve sayaç nabız atar.
- Çubuklar dolarken ucunda parlama, seviye atlamada patlama ve halka.
- Ekran geçişleri: sarı-lacivert çubukların ekranı silip açtığı "çubuklu perde" geçişi.
- Kilitli öğe tıklanırsa sağa sola sallanır ve neden kilitli olduğunu yazar.
- Bir UIMotion modülü yaz: FadeSlide, Stagger, Pop, CountUp, Shine, Shake, Pulse, Wipe. Bütün ekranlar bunu kullanır.

7.3 MAÇ HUD'I
- Skor tabelası (üst orta): iki arma, skor, dakika, uzatma. Golde tabela büyür, skor rakamı döner, altından sarı ışık geçer.
- Radar (sol üst): oyuncular nokta, top beyaz, kendi oyuncun halkalı; pas hedefi yanıp söner.
- Oyuncu kartı (sol alt): isim, numara, form puanı, dayanıklılık çubuğu (azalınca renk değiştirir ve titrer).
- Şut gücü barı: oyuncunun yanında yay şeklinde dolar, mükemmel pencere yeşil, kaçınca kırmızı; mükemmel vuruşta "MÜKEMMEL" yazısı fırlar.
- Nişan halkası kalede; zamanlama halkaları (kafa, vole, röveşata, plonjon) yerde/topta daralır.
- Yetenek yuvaları (alt orta): simge, tuş, bekleme süresi dairesel dolum; hazır olunca parlar.
- Bağlama duyarlı ipucu: duruma göre tek satır ("Kafa için ZIPLA", "Müdahale zamanı").
- Kombo sayacı ve momentum çubuğu (üstte ince, dolunca alev efekti).
- Olay akışı (sağ üst): gol, kart, değişiklik kartları kayarak gelir.
- Kart ve faul gösterimi: hakem kartı ekranın ortasında döner.
- İsim plakaları oyuncuların başında; top sende değilken soluklaşır.
- Devre arası ve maç sonu: istatistik çubukları sırayla dolar, maçın oyuncusu kartı döner, ödül sandığı açılır.

7.4 DİĞER EKRANLAR (hepsi 7.1-7.2 kurallarıyla)
- Yükleme: lacivert zemin, ortada nabız atan arma, dolan çubuklu ilerleme, altında dönen ipuçları.
- Karakter oluşturma: solda sekmeli seçenek kartları, sağda dönen karakter; her seçimde karakter küçük bir tepki animasyonu yapar; mevki kilitlenirken kilit animasyonu.
- Lobi katmanı: oyuncu kartı, bakiye, görevler, sıradaki maç; binalara yaklaşınca kapı üstünde etkileşim balonu.
- Yetenek ağacı: düğümler arasında enerji akan çizgiler; açılabilir düğüm nabız atar; açınca düğümden ışık patlar ve yeteneğin kısa önizleme videosu oynar.
- Antrenman: istasyon kartları, canlı kombo ve kazanç paneli, uçan rakamlar.
- VS ekranı: iki taraf kayarak çarpışır, kıvılcım, güç karşılaştırma çubukları dolar.
- Gol ekranı: dev "GOL!" yazısı harf harf çarpar, golcü kartı, sevinç seçim çarkı.
- Lig atlama: stadyum önce/sonra silme geçişi, kazanımlar sayarak artar.
- Kulüp merdiveni ve tesis geliştirme: stadyumun canlı görüntüsü üstünde modül kartları; yükseltince kamera oraya yaklaşır.
- Dünya sıralaması: podyum yükselir, satırlar sırayla dizilir, kendi satırın sabit ve parlak.
- Seviye ödül yolu, mağaza (ürüne tıklayınca karakter üstünde önizleme), günlük görevler, ayarlar.
- Bildirimler: sağ üstten kayan kartlar; başarımlar altın çerçeveli.

7.5 MOBİL VE ERİŞİLEBİLİRLİK
- Mobil: sanal joystick (dokunulan yerde belirir), büyük Şut/Pas/Çalım/Zıpla/Sprint/Müdahale butonları (en az 76 piksel), bağlama göre buton etiketleri değişir (hücumda Şut, savunmada Müdahale).
- Güvenli alan, farklı ekran oranları, ölçeklenen yazı.
- Ayarlar: efekt yoğunluğu, kamera sarsıntısı, hareket azaltma, renk körü modu, buton yerleşimi.

==================================================
8) FENERBAHÇE KİMLİĞİ
==================================================
- Arma: yükleme, lobi zemini, forma, dış cephe, bayraklar, skorbord. Asset id'yi Config'den oku (topluluk yükleyecek).
- "1907", "Kadıköy", "Sarı Lacivert", "Çubuklu", beş yıldız: LED panolar, koreografi, yükleme ekranı.
- Mekanlar: Kariyer Merkezi (lobi), stadyum tüneli, Fenerium mağazası, akademi, kulüp binası, antrenman tesisi, kupa müzesi, sıralama ekranı.
- Gerçek futbolcu adı ve yüzü kullanma.

==================================================
9) EKONOMİ VE SIRALAMA
==================================================
- Bakiye: antrenman mini oyunları (koni slalomu, hedef şut, sprint, kukla savunma, kafa topu, penaltı), maç, gol, günlük görev. Özellik ve yeteneğe harcanır.
- Kulüp kasası: maç geliri, tesislere harcanır.
- Robux yalnızca görünüm ve 2x XP; güç satılmaz; tek ayarla kapatılabilir.
- Sıralama: genel güç, mevkiye göre, haftalık gol krallığı, en yüksek kulüp kademesi.

==================================================
10) ÇALIŞMA ŞEKLİ
==================================================
Adım adım ilerle. Her adımın sonunda: ne yaptın, nasıl test ederim, sıradaki adım. Belirsiz kararda varsayılanı seç, bir cümleyle belirt, devam et. Her adımda kodu çalışır halde bırak.
1. İskelet, Config, veri şeması, DataStore
2. UIMotion modülü ve tema; bileşen kütüphanesi (buton, panel, çubuk, kart, bildirim)
3. Karakter modeli, özelleştirme ve oluşturma ekranı
4. Animasyon durum makinesi ve temel hareket seti
5. Top fiziği, sürme, pas, şut (güç barı, nişan, mükemmel vuruş)
6. Çalım sistemi ve kombo
7. Zıplama, hava topu, kafa, vole, röveşata
8. Defans sistemi, faul ve kartlar
9. Kaleci (bot ve oyuncu)
10. Bot yapay zekası, kurallar, duran toplar
11. Maç HUD'ı, kamera, efektler, ses
12. Lobi, antrenman, yetenek ağacı
13. Lig, sezon, stadyum kademeleri, lig atlama sinematiği, tesisler
14. Mağaza, görevler, sıralama
15. Fenerbahçe finali ve genel cila

KABUL ÖLÇÜTLERİ
- Topa her vuruşta animasyon, ses ve efekt aynı karede tetiklenir.
- Hiçbir ekran animasyonsuz açılıp kapanmaz; hiçbir buton tepkisiz değildir.
- Çalım, kafa, röveşata ve müdahale zamanlamaya dayanır ve oyuncu neden başardığını ya da kaçırdığını ekranda görür.
- Mobilde 60 FPS'e yakın çalışır, tüm kontroller tek elle ulaşılabilir.
```
