# Fener Kariyer

Roblox için tek oyunculu futbol kariyer oyunu. Fenerbahçe taraftar topluluğu için yapılıyor.

## Çalıştırma
1. [Rojo](https://rojo.space) 7 ve Roblox Studio'daki Rojo eklentisini kur.
2. Bu klasörde `rojo serve` çalıştır, Studio'da eklentiden bağlan.
3. Oyun ayarlarında "Enable Studio Access to API Services" seçeneğini aç (kapalıysa veri bellekte tutulur ve kalıcı olmaz).
4. Play'e bas.

## Şu an ne var (adım 1 ve 2)
- `src/ReplicatedStorage/Shared/Config.luau`: bütün ayarlar, kademeler, yetenek zincirleri
- `src/ServerScriptService/Server/DataService.luau`: DataStore, oturum kilidi, yeniden deneme, otomatik kayıt, sıralama
- `src/ServerScriptService/Server/PlayerService.luau`: istek doğrulama, kariyer oluşturma, mevki kilidi, özellik/yetenek/tesis
- `src/ReplicatedStorage/UI/`: Theme, UIMotion (giriş/çıkış, sıralı giriş, sayaç, parlama, sallanma, nabız, dalga, çubuklu perde), Components (panel, buton, çubuk, rozet, bildirim)
- `src/StarterPlayer/.../Main.client.luau`: yükleme ekranı, çubuklu perde, lobi katmanı

## Sınama
- Açılışta yükleme ekranı dolar, çubuklu perdeyle lobi katmanına geçer; paneller dört yönden kayarak gelir.
- "Pası geliştir": bakiye 100'den 40'a sayarak düşer, yeşil bildirim gelir.
- "Plase aç": seviye yetmediği için kırmızı bildirim gelir (sıralı kilit ve seviye şartı sunucuda).
- "Sıralama": kilitli buton sallanır ve nedenini söyler.
- Butonların üzerine gel: büyür ve parlaklık geçer; tıkla: dalga halkası yayılır.

## Belgeler
- `TEK_PROMPT.md`: oyunun tamamının tarifi
- `OYUN_TASARIM_VE_PROMPT.md`, `PROMPTLAR.md`, `tasarim/`: tasarım ve görseller
- `docs/onizleme/`: arayüz tasarım önizlemeleri (Roblox ekran görüntüsü değil)
