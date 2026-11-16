using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Fenerbahce.Core.Domain;

namespace Fenerbahce.Core.Catalog
{
    public class ValidationReport
    {
        public List<string> Errors { get; } = new List<string>();
        public List<string> Warnings { get; } = new List<string>();
        public bool IsValid { get { return Errors.Count == 0; } }
        public int PortraitsDelivered { get; set; }
        public int PortraitsFallback { get; set; }

        public void Error(string code, string msg) { Errors.Add(code + ": " + msg); }
        public void Warn(string code, string msg) { Warnings.Add(code + ": " + msg); }
        public override string ToString()
        {
            return "hata=" + Errors.Count + " uyarı=" + Warnings.Count + (Errors.Count > 0 ? "\n" + string.Join("\n", Errors) : "");
        }
    }

    /// <summary>T002/T017 doğrulaması: tam 100 benzersiz oyuncu, geçersiz referans yok, mevkisiz kart yok.</summary>
    public static class CatalogValidator
    {
        static readonly Regex PlayerIdPattern = new Regex(@"^P\d{3}$", RegexOptions.Compiled);

        public static ValidationReport Validate(ContentCatalog c)
        {
            var r = new ValidationReport();

            // --- Oyuncular ---
            var ids = new HashSet<string>();
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var p in c.Players)
            {
                if (string.IsNullOrEmpty(p.PlayerId) || !PlayerIdPattern.IsMatch(p.PlayerId))
                { r.Error("PLAYER_ID", "geçersiz playerId: '" + p.PlayerId + "'"); continue; }
                if (!ids.Add(p.PlayerId)) r.Error("PLAYER_DUP", "yinelenen playerId " + p.PlayerId);
                if (string.IsNullOrWhiteSpace(p.DisplayName)) r.Error("PLAYER_NAME", p.PlayerId + " görünen ad boş");
                else if (!names.Add(p.DisplayName)) r.Error("PLAYER_NAME_DUP", p.PlayerId + " yinelenen ad: " + p.DisplayName);
                if (string.IsNullOrWhiteSpace(p.NationalityLabel)) r.Error("PLAYER_NAT", p.PlayerId + " ülke etiketi boş");

                // Mevkisiz maç kartı yok.
                if (PositionInfo.GroupOf(p.PrimaryPosition) != p.PositionGroup)
                    r.Error("PLAYER_GROUP", p.PlayerId + " birincil mevki grubu " + p.PositionGroup + " ile uyuşmuyor");
                var alts = p.AlternatePositions ?? new List<Position>();
                if (alts.Contains(p.PrimaryPosition)) r.Error("PLAYER_ALT", p.PlayerId + " alternatif mevki birincili tekrar ediyor");
                if (alts.Distinct().Count() != alts.Count) r.Error("PLAYER_ALT", p.PlayerId + " alternatif mevki yinelenmiş");
                if (p.PositionGroup == PositionGroup.GK && alts.Count > 0) r.Error("PLAYER_GK_ALT", p.PlayerId + " kalecinin alternatif mevkisi olamaz");
                if (p.PositionGroup != PositionGroup.GK && alts.Contains(Position.GK)) r.Error("PLAYER_GK_ALT", p.PlayerId + " saha oyuncusu GK alternatifi alamaz");

                var a = p.Attributes;
                if (a == null) { r.Error("PLAYER_ATTR", p.PlayerId + " nitelik yok"); }
                else
                {
                    foreach (var kv in new[] { a.Pace, a.Shooting, a.Passing, a.Dribbling, a.Defending, a.Physical })
                        if (kv < 1 || kv > 99) { r.Error("PLAYER_ATTR", p.PlayerId + " nitelik aralık dışı"); break; }
                    if (p.PositionGroup == PositionGroup.GK && a.Goalkeeping < 1) r.Error("PLAYER_ATTR", p.PlayerId + " kaleci goalkeeping<1");
                }
                if (p.BaseOverall < 1 || p.BaseOverall > 99) r.Error("PLAYER_OVR", p.PlayerId + " GEN aralık dışı");
                if (p.SkillStars < 1 || p.SkillStars > 5) r.Error("PLAYER_STARS", p.PlayerId + " beceri yıldızı 1-5 dışı");
                if (p.Stamina < 1 || p.Stamina > 99) r.Error("PLAYER_STA", p.PlayerId + " dayanıklılık aralık dışı");
                if (string.IsNullOrEmpty(p.BodyType)) r.Error("PLAYER_BODY", p.PlayerId + " model eşlemesi yok");

                // Portre: teslim edilmediyse fallback şart; teslim edildiyse kaynak + doğrulanmış izin şart.
                var pt = p.Portrait;
                if (pt == null) { r.Error("PORTRAIT", p.PlayerId + " portre kaydı yok"); continue; }
                if (pt.Delivered)
                {
                    r.PortraitsDelivered++;
                    if (string.IsNullOrEmpty(pt.Source)) r.Error("PORTRAIT_SRC", p.PlayerId + " teslim edilmiş ama kaynak yok");
                    if (pt.UsageRightsStatus != PortraitAsset.RightsVerified) r.Error("PORTRAIT_RIGHTS", p.PlayerId + " teslim edilmiş ama izin doğrulanmadı");
                    if (string.IsNullOrEmpty(pt.Checksum)) r.Warn("PORTRAIT_SUM", p.PlayerId + " checksum yok");
                }
                else
                {
                    r.PortraitsFallback++;
                    if (string.IsNullOrEmpty(pt.Fallback)) r.Error("PORTRAIT_FALLBACK", p.PlayerId + " portre yok ve fallback tanımsız");
                }
                if (pt.FocalX < 0 || pt.FocalX > 1 || pt.FocalY < 0 || pt.FocalY > 1) r.Error("PORTRAIT_FOCAL", p.PlayerId + " odak noktası 0-1 dışı");
            }
            if (ids.Count != ContentCatalog.ExpectedPlayerCount)
                r.Error("PLAYER_COUNT", "tam " + ContentCatalog.ExpectedPlayerCount + " benzersiz playerId beklenir, bulunan: " + ids.Count);

            // --- Kartlar ---
            var cardIds = new HashSet<string>();
            var playersWithBase = new HashSet<string>();
            var playersReferenced = new HashSet<string>();
            foreach (var d in c.Cards)
            {
                if (string.IsNullOrEmpty(d.CardDefinitionId)) { r.Error("CARD_ID", "boş cardDefinitionId"); continue; }
                if (!cardIds.Add(d.CardDefinitionId)) r.Error("CARD_DUP", "yinelenen kart tanımı " + d.CardDefinitionId);
                if (!ids.Contains(d.PlayerId ?? "")) { r.Error("CARD_REF", d.CardDefinitionId + " geçersiz playerId: " + d.PlayerId); continue; }
                playersReferenced.Add(d.PlayerId);
                if (!d.CardDefinitionId.StartsWith(d.PlayerId + "_")) r.Error("CARD_NAMING", d.CardDefinitionId + " adı playerId ile başlamıyor");
                if (d.Family == "BASE") playersWithBase.Add(d.PlayerId);
                if (d.Overall < 1 || d.Overall > 99) r.Error("CARD_OVR", d.CardDefinitionId + " GEN aralık dışı");
                if (string.IsNullOrEmpty(d.FrameId)) r.Error("CARD_FRAME", d.CardDefinitionId + " çerçeve yok");
            }
            foreach (var id in ids)
                if (!playersWithBase.Contains(id)) r.Error("CARD_BASE", id + " için BASE kart tanımı yok");
            // Varyantlar futbolcu sayısını artırmamalı.
            if (playersReferenced.Count > ids.Count) r.Error("VARIANT_COUNT", "kart varyantı futbolcu sayısını artırdı");
            return r;
        }
    }
}
