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

## Özelleştirme
- **Ten:** 6 renk.
- **Saç:** 6 renk.
  - Saç seçeneklerinden "Sıfır" ve "Kel" kafa derisi kabuğunu kullanır.
  - Diğer saç seçenekleri şimdilik modelin kendi saçını gösterir.
- **Sakal:** Yok, Kirli, Bıyık, Tam, Keçi.
- **Kaş:** saç rengini alır.
- **Krampon:** 6 renk.
- **Forma:** desen, ana renk, ikinci renk, kol ve şerit renkleri. Rakip kulübün renkleri de
  aynı yolla uygulanır.
- **Boy ve yapı:** ölçekle uygulanır.
- **Uzun kol:** kol derisi forma kolu rengini alır.
- **Kaleci:** uzun kol ve eldiven.
- **Diğer:** bileklik, saç bandı, kaptanlık bandı; isim, numara, arma.
