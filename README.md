# Fener Kariyer

Roblox için tek oyunculu futbol kariyer oyunu. Fenerbahçe taraftar topluluğu için yapılıyor.

## Tek tıkla açma

`FenerKariyer.rbxlx` dosyasına çift tıkla; Roblox Studio açılır. Sonra **F5** (Play) ile oyna.
Rojo kurmak gerekmez. Kod değişirse dosyayı yeniden üretmek için: `python3 tools/build_rbxlx.py`

- Dosya yalnızca kod içerir; saha, stat, karakter ve arayüz oyun başlayınca kodla kurulur.
- Avatar R15 olmalı (Studio: Home > Game Settings > Avatar > R15). Yayınlanmamış dosyada kayıt bellekte tutulur.
- Herkes aynı varsayılan gövdeyle oynar; oyuncunun kendi Roblox avatarı yüklenmez.
- Yetenek ağacı: lobi > "Yetenek ağacı". Aynı tuş, zincirde açılan en üst hareketi oynatır (Q çalım, Boşluk hava, C müdahale, V blok).
- PC kontrolleri: WASD koş, Shift sprint, **sol tık** şut (top sende değilse müdahale), **sağ tık** pas (topsuzken top iste), **Boşluk** çalım (topsuzken kafa). Eski tuşlar (F, E, Q, C, V) da çalışır.
- Hakem: düdük, faul, sarı/kırmızı kart (ikinci sarı = kırmızı), serbest vuruş (baraj 9,15 m), ceza sahasında penaltı. Düdük sesi için `Config.Assets.Whistle` alanına ses kimliği yazılabilir; boşsa yedek ses çalar. Ofsayt ve elle oynama yok.
- Takım emirleri: maçta **T** ile Dengeli > Atak > Defans > Pres (sol paneldeki düğmelerle de seçilir). Topsuzken **sağ tık** "pas ver!" çağrısıdır. Kaptanlık bandı (seviye 10) emirleri tam etkili yapar.
- Stadyum: kulübün kademesine göre kurulur (6 kademe), en büyük üç statta dev ekran hakem kararlarını da gösterir: `src/ReplicatedStorage/Shared/Stadium.luau`
- Kulüp arması: lobi > "Kulüp arması". Biçim, desen, simge ve iki renk seçilir (`Shared/Crest.luau`). Forma göğsünde, kadro ekranında ve takım arkadaşlarının formasında görünür; rakiplerin armaları hazırdır.
- Karakter gövdesi: Roblox'un "Man" gövde paketi (`Config.Body.Parts`); yüklenemezse standart köşeli gövdeye döner. Saç modelleri, burun ve kulak yuvarlak hacimlerle kurulur.
- Botlar: şutta kalecinin uzak köşesi, kapalı pas yolundan kaçınma, koşan oyuncunun önüne ve ara pası, adam tutma, baskı altında topu uzaklaştırma; rakip skora ve dakikaya göre öne çıkar ya da geri yaslanır. Maç başına gol sayısı ölçülerek ayarlandı (beceriye göre 2-6).
- Puan durumu: lobi > "Puan durumu" (`Screens/League.luau`). Diğer kulüplerin sonuçları sezona bağlı tohumla üretilir.
- Ofsayt: pas anında son ikinci savunmacının ilerisindeki oyuncu topla buluşursa çalınır (santra, taç, korner, aut ve serbest vuruştan sonraki ilk paslarda aranmaz). Elle oynama yok.
- Devre arası ekranı: özet, ikinci yarı emri ve oyuncu değişikliği (5 yedek, 3 hak; oyuncunun kendisi değiştirilemez). Rakip 62. dakikada bir değişiklik yapar. Oyuncular sahada kaldıkça yorulur, giren oyuncu dinçtir.
- Maç sonu: oyuncu puanları (3,5-10) ve maçın adamı; gol ve asist oyuncuya yazılır.
- Karakter: hazır R15 gövdesi gizlenir; görünen gövde (yuvarlak yanlı gövde kesiti, V gövde, kas hatları, çene, eller, krampon) kodla kurulur. Forma deseni, isim, numara ve arma düz ön/arka yüzlere basılır.
- Depar: Shift (mobilde "Depar"); kalkışta toz ve ses, gövdede rüzgâr izleri ve hava parçacıkları, ekran kenarında hız çizgileri.
- Tesislerin gerçek etkileri: Çim (maçta top kontrolü +0,6/seviye, toprak kalkar), Tribün eki (kasa geliri +%20/seviye), Aydınlatma (projektörler, daha parlak ışık), Soyunma (maç XP +%10/seviye), Antrenman sahası (antrenman ödülü +%50/seviye), Sağlık (dayanıklılık yenilenmesi +%15/seviye).
- Yetenek ağacı: hareket önizlemesi (üstüne gelinen hareketi forma giymiş oyuncu oynar), açılma efektleri.
- Mağaza topları farklı desenlerde (klasik, kuşak, yıldız, dikiş, yaldızlı). Sıralamada ilk üçe madalya.
- Maç spikeri, yağmurlu maçlar (2. kademeden itibaren yaklaşık 1/4), başarımlar ve kariyer/kupa dolabı sayfası.
- Maç öncesi kadro ekranı: iki kulüp, armalar, teknik direktörler, 11'ler ve oyuncu özellikleri (`Shared/Squads.luau`).

## Çalıştırma
1. [Rojo](https://rojo.space) 7 ve Roblox Studio'daki Rojo eklentisini kur.
2. Bu klasörde `rojo serve` çalıştır, Studio'da eklentiden bağlan.
3. Oyun ayarlarında "Enable Studio Access to API Services" seçeneğini aç (kapalıysa veri bellekte tutulur ve kalıcı olmaz).
4. Play'e bas.

## Studio ayarları (ilk kurulumda bir kez)
- Game Settings > Avatar > Avatar Type: **R15** (forma boyama R15 parça adlarına göre çalışır).
- Game Settings > Security > "Enable Studio Access to API Services": açık.

## Şu an ne var (adım 1-10)
- `Shared/Config.luau`: bütün ayarlar, kademeler, yetenek zincirleri, görünüm seçenekleri, hareket sayıları, tuşlar
- `Shared/Kits.luau`: forma tanımları
- `Server/DataService.luau`: DataStore, oturum kilidi, yeniden deneme, otomatik kayıt, sıralama
- `Server/PlayerService.luau`: istek doğrulama, kariyer oluşturma, mevki kilidi, önizleme, özellik/yetenek/tesis
- `Server/CharacterService.luau`: gövde ölçüsü, ten, saç, forma deseni, isim ve numara, aksesuarlar, stüdyo ve deneme çimi
- `UI/Theme`, `UI/UIMotion`, `UI/Components`, `UI/Forms`
- `Client/Screens/Creator.luau`: karakter ve kulüp oluşturma ekranı
- `Client/Anim/Poses.luau`: kodla tanımlı 21 animasyon (şutlar, pas, kafa, uçan kafa, röveşata, çalımlar, müdahaleler, blok, plonjon, sevinçler)
- `Client/Anim/Animator.luau`: katmanlı animasyon motoru (koşu döngüsü, eylem karışımı, olaylar, girdi tamponu)
- `Client/Controllers/PlayerController.luau`: ivmeli hareket, sprint, dayanıklılık, eylem tuşları, dokunmatik butonlar, efektler, saha içi arayüz
- `Client/Match/Ball.luau`: top fiziği (sekme, sürtünme, falso, direk, kale), sürme, ilk dokunuş, şut, pas, kafa, vole, röveşata, düşüş tahmini
- `Client/Match/Bots.luau`: savunmacı (kademe, müdahale, sendeleme), kaleci (izleme, plonjon, çelme, elden kaçırma), top süren hücumcu
- `Client/Match/MatchAI.luau`: 11'e 11 maçın yapay zekası (diziliş, pres, pas, şut, top kapma, iki kaleci)
- `Client/Match/MatchController.luau`: maç akışı (santra, devreler, gol, taç, korner, aut), skor tabelası, radar, maç sonu ekranı
- `Client/Match/TimeScale.luau`: yavaş çekim ve vuruş anı duraksaması
- `Client/Match/RemoteAnim.luau`: diğer oyuncuların karakterlerini de canlandırır
- `Client/Main.client.luau`: yükleme ekranı, çubuklu perde, lobi katmanı

## Sınama listesi
1. Açılış: yükleme ekranı dolar, çubuklu perdeyle karakter oluşturma ekranına geçer.
2. Karakter lacivert stüdyoda, ekranın sağında durur ve kamera yavaşça döner. Sağ tarafta sürükleyince döner.
3. Sekmeler: Kimlik, Yüz, Saç, Vücut, Forma, Aksesuar. Yüz ve Saç sekmesinde kamera yüze yaklaşır.
4. Ten, saç modeli/rengi, boy, yapı, forma deseni, krampon rengi, aksesuar değişince karakter yaklaşık yarım saniyede güncellenir.
5. Mevki Kaleci seçilince forma yeşile döner, eller beyaz olur.
6. İsim ya da kulüp boşken "Kariyere başla": buton sallanır, kırmızı bildirim çıkar.
7. Geçerli bilgilerle "Kariyere başla": onay penceresi açılır. Onaylayınca perdeyle lobi katmanına geçer, sırtta isim ve numara görünür, karakter yürüyebilir.
8. Oyundan çıkıp tekrar gir: oluşturma ekranı gelmez, doğrudan lobi katmanı açılır (API erişimi açıksa).
9. Lobi: "Pası geliştir" bakiyeyi sayarak düşürür; "Plase aç" seviye yetmediği için reddedilir; "Sıralama" kilitli olduğu için sallanır.

### Adım 4: hareket ve animasyon
10. Lobide "Deneme sahası": perdeyle çime geçer, menüler kapanır, altta dayanıklılık ve şut yuvaları, sağda tuş listesi (telefonda yuvarlak butonlar) açılır.
11. Yürü ve dur: koşu döngüsü hıza göre açılır, dururken nefes alır. Hız 0'dan 17'ye yaklaşık yarım saniyede çıkar.
12. Shift ile sprint: hız 25'e çıkar, gövde öne eğilir, ayaklardan toz çıkar, görüş açısı genişler, dayanıklılık azalır. Bitince "Yoruldun" yazar, hız düşer, dururken eğilip soluklanır.
13. Koşarken tam ters yöne dön: hız yarıya düşer, fren animasyonu ve toz.
14. 1-6 ile şut türü seç, F ile vur: her türün hazırlık, vuruş ve toparlanma pozu farklıdır; vuruş anında halka ve kamera sarsıntısı.
15. Boşluk: zıplayıp kafa vurur. Sprintteyken Boşluk: uçan kafa.
16. 6 seçip F: röveşata (havada geriye yatış).
17. Q, R, T: vücut çalımı, Marsilya dönüşü, elastico. C: müdahale (sprintte kayma). V: blok. Z/X: plonjon. G: sevinç (koşarken diz kayması). H: top iste (koşarken oynar).
18. Bir hareket bitmeden ikinci tuşa bas: ilk hareket toparlanınca ikincisi kendiliğinden oynar.
19. "Lobiye dön": perdeyle menüler geri gelir.

### Adım 5: top, sürme, pas, şut
20. Deneme sahasına girince önünde top belirir. Topa doğru koş: her adımda top öne itilir, ayağına yapışmaz. Sprintte daha uzağa kaçar.
21. Dur: top ayağının dibinde durur. Ters yöne dönünce top geride kalabilir (geri dönüp alman gerekir).
22. F'ye basılı tut: şut yuvalarının üstünde güç barı dolar, kalede sarı nişan halkası belirir. A/D ile halka sağa sola kayar, güç arttıkça yükselir.
23. Yeşil pencerede bırak: "Mükemmel!" yazar, oyun bir an duraksar, top daha hızlı ve isabetli gider. Kırmızıda bırak: "Fazla tuttun", top üstten gider.
24. Gol: "Gol!" yazısı, konfeti, file parlaması, sarsıntı, gol sayacı artar, bakiye 10 artar (3 saniyede bir). Top geri gelir.
25. Direğe çarparsa "Direk!", kaleyi ıskalarsa "Aut".
26. Şut türleri: 2 Plase (A/D basılıyken köşeye kıvrılır, sarı iz), 3 Füze (çok hızlı, kırmızı iz, isabeti düşük), 4 Aşırtma (yüksek yay).
27. E: pas. Sarı mankenlere doğru bakarken pas mankene yönelir. Uzun basınca sert ve havadan gider.
28. B: kanattan orta gelir. Yerde topun düşeceği yeri gösteren halka daralır ve yeşile döner. Boşluk ile zıplayıp kafa vur; doğru zamanda vurursan "Mükemmel!", gol olursa "Kafa golü!".
29. Orta gelirken 5 seçip F (vole) ya da 6 seçip F (röveşata): top doğru yükseklikteyse vurur ve yavaş çekim oynar; değilse "Iska".
30. N: topu önüne getirir.

### Adım 6, 8, 9: çalım, defans, kaleci
Sunucu açılışta beş bot şablonu kurar; ilk girişte botların gelmesi birkaç saniye sürebilir.

31. Deneme sahasında artık iki rakip savunmacı (beyaz-yeşil) ve bir kaleci (turuncu) var. Üstte "Hücum çalışması / Savunma çalışması" seçimi.
32. Topla savunmacıya yaklaş: önünü keser, topla kale arasında durur. Yaklaşınca altında kırmızı halka yanıp söner (müdahale hazırlığı).
33. Halka yanarken Q, R ya da T ile çalım at: savunmacı sendeler, "Çalım!" yazar, kombo sayacı artar. Üç çalımda "Turbo!": dört saniye hızlanırsın ve karakter sarı parlar.
34. Halka yanarken çalım atmazsan savunmacı topu kapar ve uzağa vurur: "Top kaptırdın", kombo sıfırlanır.
35. Şut çek: kaleci topun gideceği yere uzanır. Ortaya ve yavaş şutları tutar ya da çeler; köşeye, hızlı ve mükemmel şutlar gol olur. Füze şutunda bazen "Kaleci elinden kaçırdı!".
36. Savunmacıya çarpan şut geri seker.
37. "Savunma çalışması"na geç: bir hücumcu topu sürerek sana doğru gelir. C ile (sprintteyken kayarak) topa müdahale et: topa değersen "Top sende!", topa değmeden adama girersen "Faul!", arkadan ya da kayarak girersen sarı kart; ikinci sarıda kırmızı kart. Kaçırırsan "Rakip kaçtı" ve yeniden başlar.

### Adım 10: maç
38. Lobide "Maça çık": perdeyle iki kaleli maç sahasına geçer. Üstte skor tabelası ve dakika, solda radar (sarı biz, kırmızı rakip, beyaz top, büyük sarı nokta sen).
39. 11'e 11: on takım arkadaşı (sarı-lacivert) ve on bir rakip (beyaz-yeşil). Sen mevkine göre dizilirsin; Forvet ileride, Defans geride başlar.
40. Üç saniyelik "vs" yazısından sonra "Başla!". Botlar dizilişini korur, top ilerledikçe takım birlikte kayar, topa en yakın oyuncu topa gider.
41. Takım arkadaşların sana pas verir; sen de E ile onlara pas verebilirsin. Top sendeyken boştaki forvet el kaldırır.
42. Rakip sana yaklaşınca kırmızı halka yanar: çalım at ya da topu kaptır. Rakip toptayken C ile müdahale et (faul ve kart kuralları geçerli; ikinci sarıda maç senin için biter).
43. Rakip kaleci şutlarını kurtarmaya çalışır; kendi kalecin de rakibin şutlarını.
44. Gol: büyük yazı, konfeti, skor tabelası parlar, bildirim düşer, santra yapılır.
45. Top yandan çıkarsa "Taç", kale çizgisinden çıkarsa "Aut" (kaleci uzun vurur) ya da "Korner" (köşeden orta gelir; bizim kornerimizde top senin önüne düşer, kafa şansı).
46. 90. dakika (iki devre, her biri 3 gerçek dakika) sonunda maç sonu ekranı: sonuç, şut ve topa sahip olma çubukları, sayarak artan bakiye, XP ve kulüp kasası, sezon durumu.
47. Maçı "Lobiye dön" ile yarıda bırakırsan ödül verilmez.
48. Mevkin Kaleci ise kalede başlarsın; rakip şutlarında Z/X ile plonjon yap, top el hizasındaysa "Kurtardın!".

Hızlı denemek için `Config.Match.HalfSeconds` değerini geçici olarak 40 yapabilirsin (sunucu, sürenin %80'i dolmadan biten maça ödül vermez).

Animasyonlar kodla yazıldı ve hiç görülmeden ayarlandı. Bir eklem ters yöne dönüyorsa (örneğin diz öne bükülüyorsa) hangi harekette olduğunu söyle; `Poses.luau` içindeki açının işareti düzeltilir.

Kariyeri sıfırlamak için: Studio'da DataStore anahtarını sil ya da `Config.DataStoreName` değerini değiştir.

## Bilinen sınırlar
- Gövde, oyuncunun kendi Roblox avatarının insan oranlarına ölçeklenmiş halidir. Gerçekçi gövde için bir gövde paketinin kimlikleri `Config.Body.Parts` içine yazılmalı.
- Saç, başa kaynaklı basit bir hacimdir. Yüz ve sakal seçimi kaydedilir ama görseli yoktur. Bunlar için model/görsel yüklenmesi gerekir.
- Maç sadeleştirmeleri: ofsayt yok; taç, korner ve aut otomatik kullanılır; faulde serbest vuruş yok (oyun devam eder); devre arasında sahalar değişmez; pas arası ve blok yalnızca animasyon.
- Lig tablosu yok: 10 maçta 19 puan toplayan kulüp lig atlar. Lig atlayınca stadyum henüz değişmiyor (13. adım).
- Takım arkadaşları hep çubuklu forma giyer; seçtiğin desen yalnızca kendi karakterinde görünür.
- Maç sahasında tribün yok; kademeli stadyumlar 13. adımda.
- Top istemcide benzetilir (tek oyunculu maç). Ödüller sunucuda bekleme süresiyle sınırlanır.
- Yetenek kilitleri yalnızca Studio'da kapalıdır (`Config.Debug.UnlockAllActionsInStudio`); yayınlanan oyunda her zaman çalışır.
- Yüklenmiş animasyon dosyan olursa kimliğini `Config.Animations` içine yaz; o eylemde kod yerine o oynar.
- Arma `Config.Assets.Crest` boşken göğüste kulüp kısaltmalı küçük kalkan çizilir.

## Sınamalar
`tests/` klasöründe oyunun mantığını Roblox dışında çalıştıran 886 denetim var (`node tests/run.mjs`). Ayrıntı: `tests/README.md`.
Bu sınamalar Studio testinin yerini tutmaz; görünüm, Roblox fiziği ve gerçek cihaz davranışı yalnızca Studio'da görülür.

## Belgeler
- `TEK_PROMPT.md`: oyunun tamamının tarifi
- `OYUN_TASARIM_VE_PROMPT.md`, `PROMPTLAR.md`, `tasarim/`: tasarım ve görseller
- `docs/onizleme/`: arayüz tasarım önizlemeleri (Roblox ekran görüntüsü değil)

- **Gerçekçi oyuncu modeli:** Yapay zekâyla üretilmiş gerçek oranlı futbolcu meshi
  (`assets/modeller/FK_Oyuncu.glb`) 15 R15 parçasına bölündü.
  - Kollar ve avuçlar doğal duruşta.
  - Forma, şort, tozluk, krampon, ten, saç, sakal bölgeleri ayrı parçalar; oyunda
    özelleştirilebilir.
  - Studio'da bir kez içe aktarılınca karakterler bu gövdeyle giyinir; aktarılmazsa eski gövde
    kullanılır.
  - Ayrıntılar: `assets/modeller/OKU.md`.
