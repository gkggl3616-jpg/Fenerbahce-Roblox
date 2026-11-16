using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Economy;

namespace Fenerbahce.Core.Store
{
    public enum OfferState { Available, LimitReached, Locked, Expired }

    public class OfferView
    {
        public OfferDefinition Offer { get; set; }
        public OfferState State { get; set; }
        /// <summary>Kullanılan / limit ("0/1"); limit yoksa Max=0.</summary>
        public int Used { get; set; }
        public int Max { get; set; }
        public TimeSpan? Remaining { get; set; }
        public bool IsFree { get { return Offer.Prices.Count == 0; } }
        /// <summary>Etiket: "Günlük Limit: 1", "Haftalık Limit: 30", "Satın Alma Limiti: 2" (referanstaki metinler).</summary>
        public string LimitLabel
        {
            get
            {
                if (Offer.LimitPeriod == LimitPeriod.None) return "";
                string name = Offer.LimitPeriod == LimitPeriod.Daily ? "Günlük Limit" : Offer.LimitPeriod == LimitPeriod.Weekly ? "Haftalık Limit" : "Satın Alma Limiti";
                return name + ": " + Offer.LimitMax;
            }
        }
    }

    /// <summary>Mağaza kuralları (T065): limit, süre, kilit, çok para birimli fiyat, atomik satın alma. Yerel geliştirme cüzdanıdır; gerçek ödeme sunucuda doğrulanır.</summary>
    public class StoreService
    {
        readonly ProfileState _p; readonly EconomyService _eco;
        readonly Dictionary<string, OfferDefinition> _byId = new Dictionary<string, OfferDefinition>();

        public StoreService(ProfileState profile, EconomyService economy, IEnumerable<OfferDefinition> offers)
        {
            _p = profile; _eco = economy;
            foreach (var o in offers) _byId[o.OfferId] = o;
        }

        static string UsageKey(OfferDefinition o) { return "offer:" + o.OfferId; }

        public OfferView View(OfferDefinition o)
        {
            var v = new OfferView { Offer = o, Max = o.LimitPeriod == LimitPeriod.None ? 0 : o.LimitMax };
            long now = _eco.NowTicks;
            if (o.LimitPeriod != LimitPeriod.None) v.Used = _eco.UsageCount(UsageKey(o), o.LimitPeriod);
            if (o.ExpiresUtcTicks > 0) v.Remaining = TimeSpan.FromTicks(Math.Max(0, o.ExpiresUtcTicks - now));
            else if (o.LimitPeriod == LimitPeriod.Daily || o.LimitPeriod == LimitPeriod.Weekly)
            {
                var reset = Periods.NextResetTicks(o.LimitPeriod, now);
                if (reset.HasValue) v.Remaining = TimeSpan.FromTicks(reset.Value - now);
            }
            if (o.ExpiresUtcTicks > 0 && now >= o.ExpiresUtcTicks) v.State = OfferState.Expired;
            else if (!string.IsNullOrEmpty(o.RequiresOfferId) && PurchasedAtLeastOnce(o.RequiresOfferId) == false) v.State = OfferState.Locked;
            else if (o.LimitPeriod != LimitPeriod.None && v.Used >= o.LimitMax) v.State = OfferState.LimitReached;
            else v.State = OfferState.Available;
            return v;
        }

        /// <summary>Önkoşul teklifin ömür boyu alınmış olması (dönemsel sayaç sıfırlansa da kilit açık kalır).</summary>
        bool PurchasedAtLeastOnce(string offerId)
        {
            OfferDefinition req; if (!_byId.TryGetValue(offerId, out req)) return false;
            return _p.Usage.ContainsKey("everbought:" + offerId);
        }

        public OpResult Purchase(string key, string offerId, int priceIndex, int quantity)
        {
            if (string.IsNullOrEmpty(key)) return OpResult.Fail("NO_KEY", "idempotency anahtarı zorunlu");
            OfferDefinition o; if (!_byId.TryGetValue(offerId, out o)) return OpResult.Fail("BAD_REF", "bilinmeyen teklif " + offerId);
            string fp = "offer:" + offerId + ":" + priceIndex + ":" + quantity;
            var replay = _eco.PeekReplay(key, "purchase", fp);
            if (replay != null) return replay;

            if (quantity < 1) return OpResult.Fail("BAD_QUANTITY", "adet 1 veya daha fazla olmalı");
            bool free = o.Prices.Count == 0;
            if (!free && (priceIndex < 0 || priceIndex >= o.Prices.Count)) return OpResult.Fail("BAD_PRICE", "geçersiz fiyat seçeneği");
            if (free && quantity != 1) return OpResult.Fail("BAD_QUANTITY", "ücretsiz teklif tek seferde 1 adet alınır");

            var v = View(o);
            if (v.State == OfferState.Expired) return OpResult.Fail("EXPIRED", "teklifin süresi doldu");
            if (v.State == OfferState.Locked) return OpResult.Fail("LOCKED", string.IsNullOrEmpty(o.LockedText) ? "teklif kilitli" : o.LockedText);
            if (v.State == OfferState.LimitReached) return OpResult.Fail("LIMIT_REACHED", "limite ulaşıldı");
            if (o.LimitPeriod != LimitPeriod.None && v.Used + quantity > o.LimitMax) return OpResult.Fail("LIMIT_REACHED", "adet limiti aşıyor (kalan " + (o.LimitMax - v.Used) + ")");

            var deltas = new List<CurrencyDelta>();
            if (!free) deltas.Add(new CurrencyDelta(o.Prices[priceIndex].Currency, -o.Prices[priceIndex].Amount * quantity));
            if (o.RewardCoins > 0) deltas.Add(new CurrencyDelta(Currency.Coin, o.RewardCoins * quantity));
            var grants = new List<string>(); for (int i = 0; i < quantity; i++) grants.AddRange(o.RewardCardDefinitionIds);

            return _eco.ApplyBundle(key, "purchase", fp, deltas, grants, null, () =>
            {
                if (o.LimitPeriod != LimitPeriod.None) _eco.AddUsage(UsageKey(o), o.LimitPeriod, quantity);
                _p.Usage["everbought:" + o.OfferId] = new UsageCounter { Count = 1, PeriodKey = "T" };
            }, "Mağaza: " + o.Title);
        }
    }
}
