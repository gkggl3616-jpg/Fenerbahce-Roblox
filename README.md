# Fener Kariyer

Roblox için tek oyunculu futbol kariyer oyunu. Fenerbahçe taraftar topluluğu için yapılıyor.

## Çalıştırma
1. [Rojo](https://rojo.space) 7 ve Roblox Studio'daki Rojo eklentisini kur.
2. Bu klasörde `rojo serve` çalıştır, Studio'da eklentiden bağlan.
3. Oyun ayarlarında "Enable Studio Access to API Services" seçeneğini aç (kapalıysa veri bellekte tutulur ve kalıcı olmaz).
4. Play'e bas.

## Studio ayarları (ilk kurulumda bir kez)
- Game Settings > Avatar > Avatar Type: **R15** (forma boyama R15 parça adlarına göre çalışır).
- Game Settings > Security > "Enable Studio Access to API Services": açık.

## Şu an ne var (adım 1-4)
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

Animasyonlar kodla yazıldı ve hiç görülmeden ayarlandı. Bir eklem ters yöne dönüyorsa (örneğin diz öne bükülüyorsa) hangi harekette olduğunu söyle; `Poses.luau` içindeki açının işareti düzeltilir.

Kariyeri sıfırlamak için: Studio'da DataStore anahtarını sil ya da `Config.DataStoreName` değerini değiştir.

## Bilinen sınırlar
- Gövde, oyuncunun kendi Roblox avatarının insan oranlarına ölçeklenmiş halidir. Gerçekçi gövde için bir gövde paketinin kimlikleri `Config.Body.Parts` içine yazılmalı.
- Saç, başa kaynaklı basit bir hacimdir. Yüz ve sakal seçimi kaydedilir ama görseli yoktur. Bunlar için model/görsel yüklenmesi gerekir.
- Top henüz yok; şut ve pas şimdilik yalnızca animasyon ve efekt oynatır (5. adım).
- `Config.Debug.UnlockAllActions` açık: bütün hareketler yetenek kilidine bakmadan denenebilir. Yayından önce kapatılacak.
- Varsayılan Roblox zıplama butonu (telefonda) çalışmaz; zıplama "Zıpla" butonuyla yapılır.
- Arma `Config.Assets.Crest` boşken göğüste kulüp kısaltmalı küçük kalkan çizilir.

## Belgeler
- `TEK_PROMPT.md`: oyunun tamamının tarifi
- `OYUN_TASARIM_VE_PROMPT.md`, `PROMPTLAR.md`, `tasarim/`: tasarım ve görseller
- `docs/onizleme/`: arayüz tasarım önizlemeleri (Roblox ekran görüntüsü değil)
