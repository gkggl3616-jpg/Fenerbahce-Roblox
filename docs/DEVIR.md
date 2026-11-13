# Devir: bilgisayarda (Roblox Studio ile) yapılacaklar

Bu dosya, bilgisayarında çalışacak bir Claude Code oturumunun işi kaldığı yerden devralması
içindir. Bulut oturumu bilgisayara ve Roblox Studio'ya erişemediği için aşağıdakiler orada
yapılmalı.

## 1. Kurulum (bir kez)
1. Depoyu bilgisayara al ve `ccr-d59168f7-2irzbb` dalına geç; dal zaten varsa `git pull`.
2. Oyunu Studio'da aç. İki yol var:
   - `FenerKariyer.rbxlx` dosyasını açmak;
   - Rojo ile bağlanmak (`default.project.json`).
3. Claude'un Studio'yu görüp kullanabilmesi için Roblox'un resmî Studio MCP sunucusunu
   (Roblox'un GitHub hesabındaki "studio-rust-mcp-server") kendi README'sine göre kur ve
   Claude Code'a bağla. Komutları README'den al; buraya tahmini komut yazılmadı.
4. Kullanıcının istediği diğer eklentiler: *(kullanıcı listeyi buraya yazacak)*.

## 2. Gerçekçi oyuncu modeli
- Ayrıntılar: `assets/modeller/OKU.md`.
- **Home → Import 3D** ile `assets/modeller/FK_Oyuncu.glb` dosyasını içe aktar. "Merge Meshes"
  gibi bir seçenek varsa kapalı kalsın.
- Oluşan `FK_Oyuncu` modelini **ReplicatedStorage** içine koy ve kaydet.
- Play ile gir. Kontrol edilecekler:
  - forma ve renkler;
  - saç, sakal, yüz ve krampon seçenekleri;
  - koşu ve şut animasyonları;
  - rakip formasının boyanması.
  
  Sorun varsa önce `src/ServerScriptService/Server/MeshBody.luau` dosyasına bak.

## 3. Stadyum ve seyirci (kullanıcı şu anki hâli çirkin buluyor)
- Kodla kurulan kutu seyirci ve saha kenarı figürleri `Config.StadiumFx` ile kapatıldı.
- Hedef: dokulu modellerle gerçekçi tribün ve seyirci. Yol:
  - Creator Store'dan lisansı uygun stadyum, koltuk ve seyirci modelleri (ya da yapay zekâyla
    üretilip içe aktarılan dokulu meshler) seçilir.
  - `src/ReplicatedStorage/Shared/Stadium.luau` içindeki `stand()` bu modelleri tribün
    eğimine yerleştirecek biçimde güncellenir; seviyeler (1–6) korunur.
- Parça ve üçgen bütçesi: telefonda 30 FPS. Seyirci uzaktaysa düşük poligonlu ya da dokulu
  düzlem kullanılır; ön sıralar 3B olur.
- Gol anında seyirci tepkisi: `Stadium.Cheer()`.

## 4. Ses
- Creator Store'daki lisanslı seslerden seçilecekler:
  - tribün uğultusu ve tezahürat;
  - gol anı patlaması;
  - hakem düdüğü;
  - vuruş, direk ve file sesleri.
- Seçilen seslerin kimlikleri arayüz seslerinin tanımlandığı yere yazılır
  (`src/ReplicatedStorage/UI/UIMotion.luau` içinde ses adları).

## 5. Işık ve malzeme
- Studio'da Future ışıklandırması ile her seviyenin `mood` ayarlarını gözle ayarla:
  - Atmosphere, Bloom, ColorCorrection, SunRays;
  - gece maçlarında çatı projektörleri.
  
  Bu ayarlar `Stadium.luau` içinde `mood` tablosundadır.
- Çim için MaterialVariant (suni ve doğal çim dokusu) kullanılabilir.

## 6. Doğrulama
- Bulut ortamındaki sınamalar: `node tests/run.mjs` (önce `npm i luau-web`).
  Şu an 1414 denetim geçiyor.
- Studio'dan her değişiklik sonrası ekran görüntüsü alınıp kullanıcıya gönderilir. Gönderilen
  görüntülerin gerçek Roblox görüntüsü olduğu belirtilir.

## Şu ana kadar yapılanlar (özet)
- Kariyer, lig, maç yapay zekâsı, yetenek ağacı, mağaza, tesisler, başarımlar, halı saha.
- Gerçekçi oyuncu modeli:
  - 15 R15 parçası;
  - 8 saç modeli, 6 yüz, 5 sakal seçeneği, 4 krampon modeli;
  - forma desenleri; kısa tozluk.
- Tarama ve düzeltmeler: puan tablosu G/B/M, antrenman ödül tavanı ve diğerleri.
