# Görsel üretim kaynak kodu

`tasarim/gorseller/` içindeki sahneleri üreten three.js kodu. Roblox'a doğrudan taşınmaz; stadyum kademelerinin ölçüleri, tribün sıra sayıları ve forma düzeni için referans olarak durur.

- `stadium.js`: 6 kademeli stadyum üretici (tribün, çatı, seyirci, koreografi, ışık)
- `fig.js`: futbolcu modeli (gövde, forma, özelleştirme, pozlar)
- `gfx.js`: arma ve forma dokuları
- `render.js`: sahne ve kamera tanımları

Çalıştırmak için: `npm i three@0.160.0 playwright`, three.js örnek modellerinden `Xbot.glb` ve `readyplayer.me.glb` dosyalarını `models/` klasörüne (ikincisini `rpm.glb` adıyla) koy, klasörü bir yerel sunucuyla aç ve `node all.js tier1 tier6 game` gibi çalıştır. Çıktılar `out/` klasörüne yazılır.

Not: Baş ve iskelet için three.js örnek modelleri yalnızca konsept görsel üretmek için kullanıldı. Oyundaki karakter modeli Roblox için ayrıca yapılacak.
