# MCP_STATUS — gerçek araç denemesiyle doğrulanan durum

Kural: "Bağlı" yalnız amaçlanan aracı çalıştırabildiysem yazılır. Tarih: 2026-11-16 (bu oturum).

| Bağlantı | Durum | Kanıt / başarısız adım |
|---|---|---|
| Claude Code yerel dosya + terminal | **Çalışıyor** | Bu oturumda dosya yazma, `dotnet`, `python3`, `git` kullanıldı. Ayrıca Filesystem MCP gerekmez. |
| GitHub MCP (`mcp__github__*`, oturum sağlayıcısı) | **Çalışıyor (okuma)** | `list_branches` ve `actions_list(list_workflows)` yanıt verdi (depo `gkggl3616-jpg/Fenerbahce-Roblox`). Yazma/tetikleme denemeleri: aşağıdaki "Güncelleme" bölümü. Kimlik doğrulama istemci tarafında; token dosyaya yazılmadı. |
| Unity MCP (CoplayDev) | **Kurulmadı** | Unity Editor yok. Etiket `v10.0.0` mevcut (`git ls-remote`ile doğrulandı) ancak paket eklenmedi/çalıştırılmadı. Kurulum: UPM'e `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#v10.0.0`, sonra *Window → MCP for Unity → Configure All Detected Clients*. Üretilen yapılandırmayı kullan; port/komut tahmin etme. İlk test: sahneyi oku, deneme nesnesi oluştur, geri al. |
| Figma | **Kurulmadı** | Figma hesabı/dosyası yok. `claude plugin install figma@claude-plugins-official` (tek yol; aynı sunucuyu iki kez ekleme). |
| Supabase | **Kurulmadı** | Backend henüz yok; proje ref'i yok. Kurulursa `read_only=true` ve yalnız geliştirme projesi. |
| Playwright | **Kullanılmadı** | Web yönetim paneli (T074) yok. Native Unity maçını test etmez. |
| Serena / Context7 / Playwright eklentileri | **Bu oturumda listelenmiş, kullanılmadı** | `.claude/settings.json` ile etkin; Context7 kimlik doğrulaması gerektiriyor ("needs authentication"). |

## Sürüm sabitleme (doğrulananlar)
- Unity Editor: 2022.3.62f1 (`unity/ProjectSettings/ProjectVersion.txt`); GameCI imajı etiketi `ubuntu-2022.3.62f1-android-3.2.2` Docker Hub'da mevcut.
- Unity paketleri: `com.unity.nuget.newtonsoft-json@3.2.1`, `com.unity.test-framework@1.1.33` (registry'de mevcut), `com.unity.ugui@1.0.0` (2022.3 yerleşik).
- GitHub Actions: `actions/checkout@v5`, `actions/setup-dotnet@v5`, `actions/cache@v4`, `actions/upload-artifact@v5`, `game-ci/unity-builder@v4.8.2`, `game-ci/unity-test-runner@v4.4.0`, `softprops/action-gh-release@v2` — etiketlerin varlığı `git ls-remote` ile doğrulandı; çalışma davranışı Actions koşusunda sınanır.

## Güncelleme
(İlk Actions koşusundan sonra bu bölüm doldurulur.)
