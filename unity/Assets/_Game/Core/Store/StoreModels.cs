using System.Collections.Generic;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Economy;

namespace Fenerbahce.Core.Store
{
    public class PriceOption
    {
        public Currency Currency { get; set; }
        public long Amount { get; set; }
    }

    /// <summary>
    /// Mağaza teklifi (G57–G60). Limit türü, çift para birimi, süre, kilit koşulu ve ücretsiz teklif modellenir.
    /// Rastgele paket içeriği (drop table) T066–T069 kapsamındadır; bu teklifler SABİT ödül verir.
    /// "VALUE %" rozeti modellenmez (hesabı videodan belirlenemez).
    /// </summary>
    public class OfferDefinition
    {
        public string OfferId { get; set; }
        public string Title { get; set; }
        public string Category { get; set; }
        public bool IsNew { get; set; }
        public LimitPeriod LimitPeriod { get; set; } = LimitPeriod.None;
        public int LimitMax { get; set; }
        /// <summary>Boş liste = ücretsiz teklif.</summary>
        public List<PriceOption> Prices { get; set; } = new List<PriceOption>();
        public List<string> RewardCardDefinitionIds { get; set; } = new List<string>();
        public long RewardCoins { get; set; }
        public long ExpiresUtcTicks { get; set; }
        /// <summary>Bu teklif, belirtilen başka teklif en az bir kez alınana kadar kilitlidir.</summary>
        public string RequiresOfferId { get; set; }
        public string LockedText { get; set; }
    }

    class OffersFile { public string ContentVersion { get; set; } public List<OfferDefinition> Offers { get; set; } }

    public static class OfferCatalog
    {
        public static List<OfferDefinition> Load(string json)
        {
            var f = JsonUtil.Deserialize<OffersFile>(json);
            return f == null || f.Offers == null ? new List<OfferDefinition>() : f.Offers;
        }

        public static List<string> Validate(IList<OfferDefinition> list, ContentCatalog cat)
        {
            var errors = new List<string>(); var ids = new HashSet<string>();
            foreach (var o in list) if (!string.IsNullOrEmpty(o.OfferId)) ids.Add(o.OfferId);
            var seen = new HashSet<string>();
            foreach (var o in list)
            {
                if (string.IsNullOrEmpty(o.OfferId) || !seen.Add(o.OfferId)) errors.Add("teklif kimliği boş/yinelenmiş: " + o.OfferId);
                if (o.LimitPeriod != LimitPeriod.None && o.LimitMax < 1) errors.Add(o.OfferId + " limit türü var ama LimitMax<1");
                foreach (var p in o.Prices) if (p.Amount <= 0) errors.Add(o.OfferId + " fiyat<=0");
                if (o.Prices.Count == 0 && o.LimitPeriod == LimitPeriod.None) errors.Add(o.OfferId + " ücretsiz teklif limitsiz olamaz (çift alma engeli)");
                if (o.RewardCardDefinitionIds.Count == 0 && o.RewardCoins <= 0) errors.Add(o.OfferId + " ödül yok");
                foreach (var c in o.RewardCardDefinitionIds) if (cat.GetCard(c) == null) errors.Add(o.OfferId + " geçersiz ödül kartı " + c);
                if (!string.IsNullOrEmpty(o.RequiresOfferId) && !ids.Contains(o.RequiresOfferId)) errors.Add(o.OfferId + " bilinmeyen önkoşul teklif " + o.RequiresOfferId);
                if (o.RequiresOfferId == o.OfferId && o.RequiresOfferId != null) errors.Add(o.OfferId + " kendi önkoşulu olamaz");
            }
            return errors;
        }
    }
}
