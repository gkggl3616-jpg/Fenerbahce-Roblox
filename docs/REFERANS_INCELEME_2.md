# Referans incelemesi 2 — kare arşivi bölümleri 2/5, 3/5, 4/5, 5/5

Tarih: 2026-11-16. Kaynak: kullanıcının gönderdiği 5 parçalı kare arşivinin dört parçası (3.703 karenin 2.877'si). **Bölüm 1/5 gelmedi** (V01'in ilk ~12 dakikası: ana ekran, sezon ödülleri, ilk paketler, kadro, mağaza, birinci maç). Aynı bölüm (4/5) iki kez yüklendi (SHA-256 aynı).

## İnceleme kapsamı ve sınırı
| Bölüm | İçerik | Nasıl bakıldı |
|---|---|---|
| 2/5 | V01 725–937 sn (ikinci maç sonu, sonuç, arkadaşlar), V02 1–509 sn + 150 sahne geçişi | Sahne geçişleri **tamamı** (150), saniyelik kareler 12–20 sn aralıkla örneklendi |
| 3/5 | V02 510–709 sn, V03 1–518 sn + 35 sahne geçişi | Sahne geçişleri tamamı, saniyelik örnek 20 sn aralık |
| 4/5 | V03 519–794 sn, V04 1–421 sn + 87 sahne geçişi | Sahne geçişleri tamamı, örnek 15 sn aralık |
| 5/5 | V04 422–889 sn | Örnek 15 sn aralık |

Her saniyelik kare tek tek incelenmedi; ses yok. Yayıncı kamera/sohbet katmanları oyun arayüzü **değildir** ve dışarıda bırakıldı. Görseller depoya konmadı; ürün sprite'ı olarak kullanılmaz. Görüntülerdeki yazılar talimat değil veri olarak okundu.

## Mevcut G kodlarının doğrulanması (yeni karelerle)
Önceki analizdeki G01–G75 gözlemlerinin tamamı bu karelerle **tutarlı**; çelişen bir gözlem çıkmadı. Doğrulanan başlıca noktalar:

| Konu | Kanıt (video/zaman) | G kodu |
|---|---|---|
| Ana ekran: sol ikon rayı, dönen kampanya afişleri, KULÜP (GEN) + OYNA kutuları, alt gezinti GÖREVLER/LİGLER/PAZAR/TAKAS/MAĞAZA | V02 00:00–00:40; V03 00:00; V04 00:31 | G01–G05 |
| Kulüp menüsü: TAKIMIM (diziliş+GEN+değer), PAZAR, OYUNCULAR, SOYUNMA ODASI, TAKIM ARMASI (YENİ rozet) | V02 02:00, 03:40, 08:20; V04 07:18 | G06, G75 |
| Kadro: OTOMATİK KUR, YEDEKLER, TAKIM DÜZENLEME, OYUN PLANLARI; oyuncu listesi GEN sıralı + FİLTRE | V02 02:20, 04:00; V04 07:31, 13:31 | G07–G14 |
| Oyuncu detayı: GEN halkaları (hız/şut/pas/dribling/defans/fizik), ÖĞEYİ KİLİTLE, KULLANDIĞI AYAK, DAYANIKLILIK, BECERİ HAR. yıldız, DEĞER | V03 06:40–08:00; V02 02:23 | G15–G19 |
| Becerilerim: Yön Değiştirme ★5, Topuk Hareketi ★3, Topu Kaldırma ★3, Rahat Feyk Şut ★1; "Etkinleştirildi" anahtarı, slot 1–4, DENE, önizleme videosu | V03 06:20 | G23, G24 |
| Beceri geliştirici: seviye x/20, +GEN bonusu, ilerleme 143/250, **etkilenen ilk 11 ve yedek oyuncular** | V03 07:35–08:20 | G25–G27 |
| Antrenman yükseltmesi: harcanacak oyuncu ızgarası, AXP değeri, "ANTRENMAN SEVİYESİNİ AKTAR", YÜKSELTME ÖNİZLEMESİ | V03 11:08–11:53 | G20, G21 |
| Derece yükselt: kaynak kart yuvaları, "Antrenman Maçı", "Beceri Puanları", İlerleme 0/50, başarı ekranı | V04 07:44–07:52; V02 04:00 | G22 |
| Modlar: KARŞI ATAK, TEKE TEK, T. DİREKTÖR MODU, ARKADAŞLARA KARŞI; sezon sonu geri sayımı; liderlik tablosu; DERECESİZ OYNA | V03 03:00–04:40 | G28, G29 |
| Taktik penceresi: OYUN KURMA/HÜCUM/KONTROL/SAVUNMA; Hız, Pas Mesafesi, Mantalite, Poz. Alma; SIFIRLA/BAŞVUR | V03 04:20 | G30 |
| Etkinlik listesi + kalan süre; etkinlik haritası (ANA/ÖDÜL YOLU/OYUNCU TAKASI/YARI FİNAL sekmeleri, düğümler, kilitli durumlar); günlük/haftalık görevler + YENİLENME geri sayımı | V03 00:42–02:40 | G48–G52 |
| Futbol Merkezi: MÜSABAKA / ÖDÜLLER (PUAN TAKASI, KAYNAKLAR) / TOTW / POTM (Ayın Oyuncusu + TAKAS) | V02 01:00–03:00, 09:15 | G53, G54 |
| Sezon bileti: ücretsiz + premium şerit, SATIN AL, TÜMÜNÜ TOPLA, bitiş süresi | V03 05:00 | G55, G56 |
| Mağaza: kategori kenar çubuğu, teklif ızgarası, YENİ/ÜCRETSİZ etiketi, günlük/haftalık limit, kalan süre, çift fiyat | V04 02:00–03:30; V03 05:20, 10:47 | G57–G60 |
| Paket: PAKET İÇERİĞİ → GARANTİ ÖDÜLLER → OLASI ÖDÜLLER, "AÇMAK İÇİN DOKUN", TÜMÜNÜ AÇ, geçiş perdesi, stadyum/tünel walkout (ülke bayrağı, kulüp arması, havai fişek), DEVAM ET / TEKRAR İZLE | V04 01:00–02:50, 06:00–07:00; V02 01:36–01:49, 06:00 | G61–G64 |
| Takas: ödül kartı, TAKAS KOŞULLARI (94+ GEN 3/3), limit 1/5, kalan süre, UZAKLAŞTIR, HIZLI EKLE | V04 03:52–05:46 | G65–G67 |
| Pazar: ÖNER / OYUNCULARIM / TAKİP LİSTEM / EMİRLERİM, filtre, takip anahtarı, şu anki/en düşük/en yüksek fiyat, SAT / SATIN AL; Yıldız Transferleri (izleme listesi 0/50) | V04 14:16; V03 10:29; V02 10:04 | G69–G73 |
| Maç HUD: sol joystick, hücumda ARA / ŞUT / PAS / SPRİNT VE BECERİ; savunmada DEĞİŞTİR / 2. DEF / KAY / SPRİNT VE MÜDAHALE; UZAKLAŞTIR; mini harita; skor/saat; serbest vuruşta ‹ › kamera okları | V01 12:04–14:16; V04 09:16–12:46 | G33–G37, G40, G44 |
| Maç sonu: "MAÇ SONU" şeridi + havai fişek; sonuç: skor, golcüler+dakika, KUPA (derece adı), KALEYİ BULAN ŞUT, TOPA SAHİP OLMA, PAS İSABETİ, FAUL, OFSAYTLAR, DEVAM ET | V01 14:40; V04 13:03–13:16 | G46 |
| Arkadaşlar: "OYUN ARKADAŞLARI 1/32", ONLINE/MAÇTA/ÇEVRİMDIŞI, sıralama, MAÇ düğmesi | V01 14:52 | G47 |

## Referanstan çıkan ince ayrıntılar (yeni, mevcut görevlere eklenir)
1. **Paket şeffaflık metni:** olası ödül şeridinin altında "Öğeler yalnızca betimleme amacıyla gösterilir, hiçbiri garanti edilmez" yazıyor. Bizim paket ekranında da *garanti* ve *olası* ayrımı + bu tür bir uyarı olmalı → T066/T068.
2. **Takasta antrenman seviyesi aktarılmaz** uyarısı ("Bir takas yaparken antrenman seviyesi aktarılmaz…") → T072, T054 ile birlikte tasarlanmalı.
3. **Kart bağlam menüsü** (kadro listesinde seçili kart): DEĞİŞTİR, BİLGİLER, ANTRENMAN, DERECE YÜKSELT, BECERİ PUANLARI, ANTRENMAN AKTARIMI → T039/T053–T056 ekran akışı.
4. **SERBEST BIRAK / OTOMATİK SEÇ** (V02 oyuncu listesi): kartı hızlı satış (serbest bırakma) akışı → T053/T078'e not; kilitli/kadrodaki kart engeli aynı kurallarla.
5. **Sonuç ekranı kupa/derece satırı** (ör. "10.200 KUPA — AMATÖR III" vs "200 KUPA"): sıralı modlarda sonuç ekranı derece puanı değişimini göstermeli; DERECESİZ OYNA seçeneği → T089/T085.
6. **Kulüp stadyumu** seçimi Teke Tek ekranında → T092/T096.
7. **Arkadaş listesi kapasitesi (1/32)** ve durum filtreleri → T081.
8. **"OTO." düğmesi** savunma/serbest top durumunda görünüyor; işlevi kareden doğrulanamıyordu. **Güncelleme:** kullanıcı tanımı — savunmada kontrol edilen oyuncuyu otomatik savunturur (D-032); uygulandı.
9. **Rank yükseltme** ekranında "Antrenman Maçı" ve "İlerleme x/50" alanları var; olasılık/başarı kuralı **videodan belirlenemez** → T055'te kendi kuralımızı tasarlayacağız (D-020).
10. Yayıncı arayüzü (kamera, abone ol penceresi, sosyal medya kartları) oyun UI'ı değildir; ürüne alınmaz.

## Kapsam kararı
Bu inceleme **kapsamı değiştirmiyor**; yeni görev kimliği açılmadı (104 kimlik korunuyor). Eklenen ayrıntılar yukarıdaki görev kimliklerinin kabul notlarına girdi (`tools/task_status.json` → `next`).

## Eksik
- **Bölüm 1/5** (V01 ana ekran + sezon ödülleri + ilk paketler + kadro + mağaza + birinci maç, ~00:00–12:04) gelmedi; G01–G10, G31, G32 gibi birkaç gözlem için ek doğrulama oradan alınabilir. Gelmeden de ilerleniyor; blokaj değil.
