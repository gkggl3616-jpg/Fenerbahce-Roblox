using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Squad;

namespace Fenerbahce.Core.Exchange
{
    /// <summary>Takas durumu: koşul başına sağlanan/gereken sayaç ("3/3"), limit, süre ve sorunlar.</summary>
    public class ExchangeStatus
    {
        public Dictionary<string, int> Satisfied { get; } = new Dictionary<string, int>();
        public Dictionary<string, int> Required { get; } = new Dictionary<string, int>();
        public int UsesDone { get; set; }
        public int MaxUses { get; set; }
        public TimeSpan? Remaining { get; set; }
        public List<string> Errors { get; } = new List<string>();
        /// <summary>Hata değil uyarılar: örn. TRAINING_LEVEL_LOST (referansta "antrenman seviyesi aktarılamaz" uyarısı).</summary>
        public List<string> Warnings { get; } = new List<string>();
        public bool CanExecute { get { return Errors.Count == 0; } }
        public bool LimitReached { get { return MaxUses > 0 && UsesDone >= MaxUses; } }
    }

    /// <summary>
    /// Takas (T072/T073): koşul doğrulama, "Hızlı ekle", atomik tüketim + ödül. Seçim: koşul kimliği → kart örneği listesi.
    /// </summary>
    public class ExchangeService
    {
        readonly ProfileState _p; readonly ContentCatalog _cat; readonly EconomyService _eco;
        public ExchangeService(ProfileState profile, ContentCatalog catalog, EconomyService economy) { _p = profile; _cat = catalog; _eco = economy; }

        static string UsageKey(ExchangeRecipe r) { return "exchange:" + r.RecipeId; }
        static LimitPeriod PeriodOf(ExchangeRecipe r) { return LimitPeriod.Total; }

        public int UsesDone(ExchangeRecipe r) { return _eco.UsageCount(UsageKey(r), PeriodOf(r)); }

        bool Eligible(CardInstance ci, ExchangeRequirement q)
        {
            var def = _cat.GetCard(ci.CardDefinitionId); var pl = def == null ? null : _cat.GetPlayer(def.PlayerId);
            if (def == null || pl == null) return false;
            if (def.Overall < q.MinOverall) return false;
            if (q.Group.HasValue && pl.PositionGroup != q.Group.Value) return false;
            return true;
        }

        public ExchangeStatus Evaluate(ExchangeRecipe r, IDictionary<string, List<string>> selection)
        {
            var st = new ExchangeStatus { UsesDone = UsesDone(r), MaxUses = r.MaxUses };
            long now = _eco.NowTicks;
            if (r.ExpiresUtcTicks > 0)
            {
                st.Remaining = TimeSpan.FromTicks(Math.Max(0, r.ExpiresUtcTicks - now));
                if (now >= r.ExpiresUtcTicks) st.Errors.Add("EXPIRED");
            }
            if (st.LimitReached) st.Errors.Add("LIMIT_REACHED");

            var all = new List<string>();
            foreach (var q in r.Requirements)
            {
                List<string> sel; if (selection == null || !selection.TryGetValue(q.RequirementId, out sel)) sel = new List<string>();
                int ok = 0;
                foreach (var id in sel)
                {
                    all.Add(id);
                    var ci = _p.Inventory.Get(id);
                    if (ci != null && Eligible(ci, q)) ok++;
                    else if (ci != null) st.Errors.Add("REQUIREMENT_MISMATCH:" + q.RequirementId);
                }
                st.Satisfied[q.RequirementId] = Math.Min(ok, q.Count);
                st.Required[q.RequirementId] = q.Count;
                if (sel.Count > q.Count) st.Errors.Add("TOO_MANY:" + q.RequirementId);
                if (ok < q.Count) st.Errors.Add("REQUIREMENT_UNMET:" + q.RequirementId);
            }
            if (all.Distinct().Count() != all.Count) st.Errors.Add("DUPLICATE");
            if (all.Count > 0)
            {
                var bad = _eco.ValidateConsume(all);
                if (bad != null) st.Errors.Add(bad.ErrorCode);
            }
            if (all.Any(id => { var ci = _p.Inventory.Get(id); return ci != null && ci.TrainingLevel > 0; }))
                st.Warnings.Add("TRAINING_LEVEL_LOST");
            st.Errors.RemoveAll(e => e == null);
            return st;
        }

        /// <summary>
        /// HIZLI EKLE: her koşul için en düşük değerli uygun kartları seçer; kilitli/kadrodaki/satıştaki kartı ve
        /// başka koşulda kullanılan kartı atlar. Eksik kalan koşul için daha az kart döner (UI "+" yuvası gösterir).
        /// </summary>
        public Dictionary<string, List<string>> QuickAdd(ExchangeRecipe r)
        {
            var result = new Dictionary<string, List<string>>(); var used = new HashSet<string>();
            // Daha kısıtlı (yüksek GEN) koşullar önce dolsun ki düşük koşul onların kartını çalmasın.
            foreach (var q in r.Requirements.OrderByDescending(x => x.MinOverall))
            {
                var picks = _p.Inventory.Cards
                    .Where(c => !used.Contains(c.CardInstanceId) && _eco.ValidateConsume(new[] { c.CardInstanceId }) == null && Eligible(c, q))
                    .OrderBy(c => CardValue.Of(_cat.GetCard(c.CardDefinitionId).Overall)).ThenBy(c => c.CardInstanceId)
                    .Take(q.Count).Select(c => c.CardInstanceId).ToList();
                foreach (var id in picks) used.Add(id);
                result[q.RequirementId] = picks;
            }
            return result;
        }

        /// <summary>Atomik takas: kartlar tüketilir, ödül verilir, kullanım sayacı artar — tek işlemde; aynı anahtar tekrar gelirse aynı sonuç.</summary>
        public OpResult Execute(string key, ExchangeRecipe r, IDictionary<string, List<string>> selection)
        {
            var all = new List<string>();
            foreach (var q in r.Requirements) { List<string> sel; if (selection != null && selection.TryGetValue(q.RequirementId, out sel)) all.AddRange(sel); }
            string fp = "exchange:" + r.RecipeId + ":" + string.Join(",", all.OrderBy(x => x));
            var replay = _eco.PeekReplay(key, "exchange", fp);
            if (replay != null) return replay;

            var st = Evaluate(r, selection);
            if (!st.CanExecute)
            {
                string first = st.Errors.First();
                return OpResult.Fail(first.Split(':')[0], "takas yapılamaz: " + string.Join(", ", st.Errors.ToArray()));
            }
            var deltas = new List<CurrencyDelta>(); if (r.RewardCoins > 0) deltas.Add(new CurrencyDelta(Currency.Coin, r.RewardCoins));
            return _eco.ApplyBundle(key, "exchange", fp, deltas, r.RewardCardDefinitionIds, all, () => _eco.AddUsage(UsageKey(r), PeriodOf(r), 1), "Takas: " + r.Title);
        }
    }
}
