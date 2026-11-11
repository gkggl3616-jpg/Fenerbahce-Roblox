# Sınamalar

Oyunun mantığını Roblox dışında çalıştıran sınama düzeneği. Roblox Studio'nun yerini tutmaz: çizim,
Roblox fizik motoru, gerçek arayüz ve gerçek DataStore yoktur. Amaç, kodun hatasız çalıştığını ve
sayıların dengeli olduğunu Studio'ya girmeden görmektir.

## Çalıştırma
```
npm i luau-web
node tests/run.mjs
```

## Neler sınanıyor (886 denetim)
- **Ayarlar:** kademeler, yetenek zincirlerinin seviye sırası, diziliş.
- **Animasyon verisi:** 23 eylemin anahtar kareleri, eklem adları, olay zamanları.
- **Animasyon motoru:** her eylem baştan sona oynatılır; sayılar sağlam mı, olaylar tetikleniyor mu, girdi tamponu çalışıyor mu. Tuşa basıştan topa temasa kadar geçen süreler raporlanır.
- **Top fiziği:** sürtünme, sekme, şut isabeti (Şut 10 ile Şut 1 farkı), fazla tutulan şut, füze hızı, plase falsosu, orta ve düşüş tahmini, sürme dokunuşu, pas.
- **Çalışma botları:** savunmacının haber vermesi ve top kapması, çalım penceresi, kalecinin ortaya ve köşeye gelen şutlara tepkisi, hücumcunun kaçışı, müdahale.
- **Maç yapay zekası:** 11'e 11, 3 sanal dakika; şut, kurtarış, topa sahip olma, skor, botların sahada kalması.
- **Arayüz bileşenleri:** panel, buton, çubuk, rozet, bildirim, form parçaları, perde, sayaç (kurulum ve etkileşim; çizim yok).
- **Sunucu:** kariyer oluşturma doğrulaması, mevki kilidi, özellik ve yetenek sırası, maç sonucu doğrulaması, ödül, lig atlama, kayıt ve oturum kilidi.
- **Oyuncu kontrolü:** ivmelenme, sprint, yorgunluk, şut tuşu, bütün eylem tuşları, orta ve kafa, röveşata.
- **Maç akışı:** kısaltılmış bir maç baştan sona; santra, devre arası, maç sonu ekranı, sunucu ödülü, lobiye dönüş.

## Maç kaydı
`node tests/replay.mjs <tohum> <saniye> <çıktı.json>` oyun kodunu çalıştırıp her karedeki oyuncu, bot ve top
konumlarını yazar. `docs/onizleme/mac-benzetimi.mp4` bu kayıttan çizildi.
