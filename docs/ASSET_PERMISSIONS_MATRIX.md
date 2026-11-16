# Oyuncu / portre / marka kaynak ve izin matrisi (T003)

Kabul ölçütü: her varlık sınıfının **kaynak** ve **izin** alanı vardır. İzinlerin kendisi bu belgede *verilmiş sayılmaz*; hepsi doğrulanmayı bekler.

| Varlık sınıfı | Alan(lar) (veri/şema) | Şu anki durum | Sorumlu / sonraki adım |
|---|---|---|---|
| Futbolcu adı/ülke etiketi (100 kişi) | `PlayerDefinition.displayName/nationalityLabel`, `rosterStatus=ADAY_ONAYLANMADI` | Aday liste; kesin lisanslı kadro değil | Ticari yayın öncesi hukuki inceleme (kişi adı/imaj hakları) |
| Futbolcu nitelikleri / GEN | `statsSource=PROTOTIP_DENGE_V0` | Prototip denge değeri; gerçek reyting değil | Denge çalışması (T104) |
| Portre fotoğrafı | `PortraitAsset.path/delivered/source/usageRightsStatus/checksum/focalX/focalY/fallback` | **100/100 teslim edilmedi**, `DOGRULANACAK`; kart siluet gösterir | T091: kaynak + lisans kaydı + 512×512 saydam PNG + checksum |
| 3B model / yüz | `PlayerDefinition.bodyType` (ortak rigli model eşlemesi) | Model yok (kapsül gövde) | T030/T092: ortak rig; özgün yüz sonraki aşama. Fotoğraf ≠ 3B yüz. |
| Fenerbahçe kimliği (arma, forma, isim, renk kodları) | `docs: DesignTokens` önerisi; arma/forma varlığı yok | Renkler öneri; **resmî marka kodu iddiası yok**; arma/forma dosyası eklenmedi | T092/T096: kulüp kimliği kullanım hakkı doğrulanmadan resmi arma/forma eklenmez |
| Video referans kareleri | `docs/reference/GEREKSINIM_IZLENEBILIRLIK.csv` (yalnız G kodu eşlemesi) | Kareler depoya **konmadı**, ürüne sprite olarak girmez | — |
| Müzik / ses | — | Ses yok (T093) | Özgün veya lisanslı olacak |
| Yazı tipi | Unity yerleşik `LegacyRuntime.ttf` | Yerleşik | Özel font seçilirse lisansı burada kaydedilir |
| Etkinlik adları | `campaigns.v1.json` | "Kadıköy Geceleri" vb. **proje önerisi**, videodan değil | — |
| Üçüncü taraf kod | `Newtonsoft.Json` (MIT), NUnit (MIT), GameCI (MIT) | Kullanılıyor | Lisans metinleri yayın paketine eklenecek |

Kural: bir portre `delivered=true` olamaz → `source` boş veya `usageRightsStatus != DOGRULANDI` ise (CatalogValidator ve `tools/validate_catalog.py` bunu reddeder; negatif test var).
