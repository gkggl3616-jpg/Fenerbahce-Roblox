# Gerçekçi oyuncu modeli (FK_Oyuncu)

## Dosyalar
- `oyuncu_ham.glb`: Higgsfield (Tripo, metinden 3B, dokusuz) ile üretilen ham model. T-pozda.
- `oyuncu_rig.glb`: Aynı modelin otomatik iskeletli hâli. Kollardaki iskelet tutarsız çıktığı
  için kullanılmıyor; yalnızca kayıt olarak duruyor.
- `FK_Oyuncu.glb`: Oyuna girecek hâli. `tools/meshgen/oyuncu_r15.py` üretir:
  - kollar aşağıda, avuçlar uyluğa dönük, gerçek insan oranları;
  - 15 R15 parçasına bölünmüş;
  - forma, kol, yaka, şort, tozluk, krampon, ten, saç, kaş, sakal ve kafa derisi bölgeleri
    ayrı ayrı;
  - çubuklu, kuşaklı ve düz forma desenleri ayrı parçalar.
- `FK_Oyuncu_onizleme.glb`: Yalnızca renkli önizleme; oyunda kullanılmaz.

## Studio'ya alma (bir kez)
1. Studio'da oyunu aç. **Home → Import 3D** (ya da **Model → Import 3D**) ile
   `FK_Oyuncu.glb` dosyasını seç.
2. İçe aktarma ayarlarında parçaların birleştirilmemesi gerekir. "Merge Meshes" gibi bir
   seçenek görürsen kapalı bırak. Bunun dışındaki ayarlar varsayılan kalabilir.
3. Oluşan `FK_Oyuncu` modelini **ReplicatedStorage** içine taşı. İstersen
   `ReplicatedStorage/FK_Assets/FK_Oyuncu` olarak da koyabilirsin; ikisi de çalışır.
4. Oyunu kaydet ya da yayımla. Meshler hesabına yüklenir.

## Model içe aktarılmazsa
Model yoksa oyun kodla kurulan eski gövdeyi kullanmaya devam eder.

## Konum ve iskelet
- İçe aktarıcı modeli kaydırsa, döndürse ya da ölçeklese de sorun olmaz: `FK_Origin`,
  `FK_AxisX` ve `FK_AxisY` işaretleri bu farkı geri çözer.
- İskelet (eklem yerleri, kalça yüksekliği) `src/ReplicatedStorage/Shared/MeshRig.luau`
  dosyasındadır; betik bu dosyayı yeniden üretir.

## Özelleştirme (hepsi oyunda çalışır)
- **Ten:** 6 renk.
- **Saç:** 8 model.
  - 1 Sıfır ve 8 Kel: kafa derisi.
  - 2 Kısa: modelin kendi saçı.
  - 3 Hacimli, 4 Uzun, 5 Kıvırcık, 6 Topuz, 7 Yanlar kısa: kafatasına oturan, betiğin ürettiği
    pürüzsüz saçlar.
  - 6 saç rengi.
- **Sakal:** Yok, Kirli, Bıyık, Tam, Keçi.
- **Kaş:** saç rengini alır. Tek sıradaki yüzlerde ince, çift sıradakilerde kalın.
- **Yüz (6):** kafa oranı (geniş çene, uzun yüz, iri, ince, yuvarlak) ve kaş kalınlığı.
- **Krampon:** 4 model, 6 renk.
  - 1 Klasik: tek renk.
  - 2 Hız: beyaz taban.
  - 3 Kontrol: siyah örgü bilek.
  - 4 Retro: siyah gövde, beyaz taban.
- **Forma:** desen (çubuklu, kuşaklı, düz), ana renk, ikinci renk, kol ve şerit renkleri.
  - Kol rengi formadan farklıysa omuzda temiz dikiş çizgisi.
  - Rakip kulüp renkleri de aynı yolla uygulanır.
- **Kısa tozluk:** tozluk aşağı katlanır, tekmelik görünür.
- **Uzun kol ve kaleci:** uzun kolda kol derisi forma kolu rengini alır; kalecide eldiven.
- **Boy ve yapı:** ölçekle uygulanır.
- **Diğer:** bileklik, saç bandı, kaptanlık bandı; isim, numara, arma.
