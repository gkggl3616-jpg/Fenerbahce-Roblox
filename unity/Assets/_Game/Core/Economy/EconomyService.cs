using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Squad;

namespace Fenerbahce.Core.Economy
{
    public class OpResult
    {
        public bool Ok { get; set; }
        /// <summary>true ise aynı anahtarlı daha önceki sonucun tekrarıdır; durum DEĞİŞMEDİ.</summary>
        public bool Replayed { get; set; }
        public string ErrorCode { get; set; }
        public string Message { get; set; }
        public List<string> CardInstanceIds { get; set; } = new List<string>();

        public static OpResult Fail(string code, string msg) { return new OpResult { Ok = false, ErrorCode = code, Message = msg }; }
        public override string ToString() { return Ok ? "OK" + (Replayed ? " (tekrar)" : "") : "HATA " + ErrorCode + ": " + Message; }
    }

    /// <summary>
    /// Yerel geliştirme ekonomisi: idempotent, atomik (ya hep ya hiç), bakiye negatife düşmez.
    /// Bu kurallar TypeScript sunucusunun (T049/T050) birebir uygulayacağı sözleşmedir; istemci kaynaklı
    /// bu sınıf gerçek ekonomi için GÜVENİLİR sayılmaz.
    /// </summary>
    public class EconomyService
    {
        public const string StarterKey = "starter-package:v1";
        public const long StarterCoins = 5000;
        public static readonly string[] StarterCards =
        {
            "P004_BASE_V1", "P002_BASE_V1", // GK
            "P017_BASE_V1", "P021_BASE_V1", "P019_BASE_V1", "P022_BASE_V1", "P018_BASE_V1", "P023_BASE_V1", // DEF
            "P047_BASE_V1", "P048_BASE_V1", "P049_BASE_V1", "P050_BASE_V1", "P051_BASE_V1", "P052_BASE_V1", // MID
            "P079_BASE_V1", "P080_BASE_V1", "P081_BASE_V1", "P088_BASE_V1", // ATT
        };

        private readonly ProfileState _p;
        private readonly ContentCatalog _cat;
        private readonly Func<string> _newId;
        private readonly Func<long> _nowTicks;

        public EconomyService(ProfileState profile, ContentCatalog catalog, Func<string> idFactory = null, Func<long> utcTicks = null)
        {
            _p = profile; _cat = catalog;
            _newId = idFactory ?? (() => Guid.NewGuid().ToString("N"));
            _nowTicks = utcTicks ?? (() => DateTime.UtcNow.Ticks);
        }

        // ---------- yardımcılar ----------
        bool TryReplay(string key, string kind, string fp, out OpResult replay)
        {
            replay = null;
            OperationRecord rec;
            if (!_p.Operations.TryGetValue(key, out rec)) return false;
            if (rec.Kind != kind || rec.Fingerprint != fp)
                replay = OpResult.Fail("KEY_REUSED", "işlem anahtarı farklı içerikle yeniden kullanıldı: " + key);
            else
                replay = new OpResult { Ok = true, Replayed = true, CardInstanceIds = new List<string>(rec.CardInstanceIds) };
            return true;
        }

        void Record(string key, string kind, string fp, List<string> ids, string detail)
        {
            _p.Operations[key] = new OperationRecord { Key = key, Kind = kind, Fingerprint = fp, CardInstanceIds = ids ?? new List<string>(), Detail = detail, UtcTicks = _nowTicks() };
        }

        void WriteLedger(string key, Currency c, long delta, string reason)
        {
            var w = _p.Wallet;
            long bal = w.Get(c) + delta;
            w.Balances[c] = bal;
            w.Ledger.Add(new LedgerEntry { Seq = w.Ledger.Count + 1, IdempotencyKey = key, Currency = c, Delta = delta, BalanceAfter = bal, Reason = reason, UtcTicks = _nowTicks() });
        }

        CardInstance NewInstance(CardDefinition d, string via)
        {
            return new CardInstance { CardInstanceId = _newId(), CardDefinitionId = d.CardDefinitionId, Tradable = d.Tradable, AcquiredVia = via };
        }

        // ---------- para ----------
        public OpResult ApplyCurrency(string key, Currency c, long delta, string reason)
        {
            if (string.IsNullOrEmpty(key)) return OpResult.Fail("NO_KEY", "idempotency anahtarı zorunlu");
            string fp = "cur:" + c + ":" + delta;
            OpResult rp; if (TryReplay(key, "currency", fp, out rp)) return rp;
            if (_p.Wallet.Get(c) + delta < 0) return OpResult.Fail("INSUFFICIENT_FUNDS", c + " bakiyesi yetersiz");
            WriteLedger(key, c, delta, reason);
            Record(key, "currency", fp, null, reason);
            return new OpResult { Ok = true };
        }

        // ---------- kart verme ----------
        public OpResult GrantCards(string key, IList<string> cardDefinitionIds, string reason)
        {
            if (string.IsNullOrEmpty(key)) return OpResult.Fail("NO_KEY", "idempotency anahtarı zorunlu");
            string fp = "grant:" + string.Join(",", cardDefinitionIds);
            OpResult rp; if (TryReplay(key, "grant", fp, out rp)) return rp;
            var defs = new List<CardDefinition>();
            foreach (var id in cardDefinitionIds)
            {
                var d = _cat.GetCard(id);
                if (d == null) return OpResult.Fail("BAD_REF", "geçersiz kart tanımı: " + id);
                defs.Add(d);
            }
            var created = defs.Select(d => NewInstance(d, reason)).ToList();
            _p.Inventory.Cards.AddRange(created);
            var ids = created.Select(c => c.CardInstanceId).ToList();
            Record(key, "grant", fp, ids, reason);
            return new OpResult { Ok = true, CardInstanceIds = ids };
        }

        // ---------- kart tüketme (antrenman/takas/satış için ortak güvenli kapı) ----------
        public OpResult ConsumeCards(string key, IList<string> cardInstanceIds, string reason)
        {
            if (string.IsNullOrEmpty(key)) return OpResult.Fail("NO_KEY", "idempotency anahtarı zorunlu");
            string fp = "consume:" + string.Join(",", cardInstanceIds);
            OpResult rp; if (TryReplay(key, "consume", fp, out rp)) return rp;
            var bad = ValidateConsume(cardInstanceIds);
            if (bad != null) return bad;
            // Doğrulama bitti → tek seferde uygula.
            _p.Inventory.Cards.RemoveAll(c => cardInstanceIds.Contains(c.CardInstanceId));
            Record(key, "consume", fp, new List<string>(cardInstanceIds), reason);
            return new OpResult { Ok = true, CardInstanceIds = new List<string>(cardInstanceIds) };
        }

        /// <summary>Kartların harcanabilirliğini denetler (sahip, kilit, satış, kadro, yinelenme). Sorun yoksa null.</summary>
        public OpResult ValidateConsume(IList<string> cardInstanceIds)
        {
            if (cardInstanceIds.Count == 0) return OpResult.Fail("EMPTY", "tüketilecek kart yok");
            if (cardInstanceIds.Distinct().Count() != cardInstanceIds.Count) return OpResult.Fail("DUPLICATE", "aynı kart iki kez seçilmiş");
            foreach (var id in cardInstanceIds)
            {
                var ci = _p.Inventory.Get(id);
                if (ci == null) return OpResult.Fail("NOT_OWNED", "kart envanterde yok: " + id);
                if (ci.Locked) return OpResult.Fail("LOCKED", "kilitli kart harcanamaz: " + id);
                if (ci.ListedOnMarket) return OpResult.Fail("LISTED", "satıştaki kart harcanamaz: " + id);
                foreach (var sq in _p.Squads)
                    if (SquadService.IsAssigned(sq, id)) return OpResult.Fail("IN_SQUAD", "kadrodaki kart harcanamaz (" + sq.Name + "): " + id);
            }
            return null;
        }

        // ---------- ortak atomik işlem kapısı (mağaza, takas, ileride paket/antrenman) ----------
        /// <summary>Aynı anahtarla daha önce tamamlanmış işlemin sonucunu döndürür; yoksa null. Farklı içerikle yeniden kullanım KEY_REUSED.</summary>
        public OpResult PeekReplay(string key, string kind, string fingerprint)
        {
            OpResult rp; return TryReplay(key, kind, fingerprint, out rp) ? rp : null;
        }

        public long NowTicks { get { return _nowTicks(); } }

        /// <summary>
        /// Para değişimi + kart verme + kart tüketme + ek durum güncellemesini TEK atomik işlemde uygular:
        /// önce tümü doğrulanır (bakiye negatife düşmez, kart tanımları geçerli, tüketilen kartlar serbest), sonra uygulanır.
        /// Aynı anahtar tekrar gelirse durum değişmez, ilk sonuç döner.
        /// </summary>
        public OpResult ApplyBundle(string key, string kind, string fingerprint, IList<CurrencyDelta> deltas, IList<string> grantCardDefinitionIds, IList<string> consumeCardInstanceIds, Action onApplied, string reason)
        {
            if (string.IsNullOrEmpty(key)) return OpResult.Fail("NO_KEY", "idempotency anahtarı zorunlu");
            OpResult rp; if (TryReplay(key, kind, fingerprint, out rp)) return rp;
            deltas = deltas ?? new List<CurrencyDelta>();
            grantCardDefinitionIds = grantCardDefinitionIds ?? new List<string>();
            consumeCardInstanceIds = consumeCardInstanceIds ?? new List<string>();

            var sums = new Dictionary<Currency, long>();
            foreach (var d in deltas) { long cur; sums.TryGetValue(d.Currency, out cur); sums[d.Currency] = cur + d.Amount; }
            foreach (var kv in sums)
                if (_p.Wallet.Get(kv.Key) + kv.Value < 0) return OpResult.Fail("INSUFFICIENT_FUNDS", kv.Key + " bakiyesi yetersiz");
            var defs = new List<CardDefinition>();
            foreach (var id in grantCardDefinitionIds)
            {
                var def = _cat.GetCard(id);
                if (def == null) return OpResult.Fail("BAD_REF", "geçersiz kart tanımı: " + id);
                defs.Add(def);
            }
            if (consumeCardInstanceIds.Count > 0)
            {
                var bad = ValidateConsume(consumeCardInstanceIds);
                if (bad != null) return bad;
            }

            // --- uygulama (hata olamaz) ---
            foreach (var d in deltas) if (d.Amount != 0) WriteLedger(key, d.Currency, d.Amount, reason);
            if (consumeCardInstanceIds.Count > 0) _p.Inventory.Cards.RemoveAll(c => consumeCardInstanceIds.Contains(c.CardInstanceId));
            var created = defs.Select(d => NewInstance(d, reason)).ToList();
            _p.Inventory.Cards.AddRange(created);
            if (onApplied != null) onApplied();
            var ids = created.Select(c => c.CardInstanceId).ToList();
            Record(key, kind, fingerprint, ids, reason);
            return new OpResult { Ok = true, CardInstanceIds = ids };
        }

        // ---------- dönemsel sayaçlar (sunucu saatine bağlı) ----------
        public int UsageCount(string usageKey, LimitPeriod period)
        {
            UsageCounter c; if (!_p.Usage.TryGetValue(usageKey, out c)) return 0;
            return c.PeriodKey == Periods.KeyOf(period, _nowTicks()) ? c.Count : 0;
        }

        public void AddUsage(string usageKey, LimitPeriod period, int amount)
        {
            string pk = Periods.KeyOf(period, _nowTicks());
            UsageCounter c;
            if (!_p.Usage.TryGetValue(usageKey, out c) || c.PeriodKey != pk) { c = new UsageCounter { PeriodKey = pk, Count = 0 }; _p.Usage[usageKey] = c; }
            c.Count += amount;
        }

        public OpResult SetLocked(string cardInstanceId, bool locked)
        {
            var ci = _p.Inventory.Get(cardInstanceId);
            if (ci == null) return OpResult.Fail("NOT_OWNED", "kart envanterde yok");
            ci.Locked = locked; // Doğal olarak idempotent (aynı değeri yazar).
            return new OpResult { Ok = true };
        }

        // ---------- başlangıç paketi (T051) ----------
        /// <summary>Tek seferlik ilk giriş ödülü: 18 kart + coin, TEK atomik işlemde. İkinci çağrı aynı sonucu döndürür.</summary>
        public OpResult ClaimStarterPackage()
        {
            string fp = "starter";
            OpResult rp; if (TryReplay(StarterKey, "starter", fp, out rp)) return rp;
            var defs = new List<CardDefinition>();
            foreach (var id in StarterCards)
            {
                var d = _cat.GetCard(id);
                if (d == null) return OpResult.Fail("BAD_REF", "başlangıç kartı katalogda yok: " + id);
                defs.Add(d);
            }
            var created = defs.Select(d => NewInstance(d, "starter")).ToList();
            _p.Inventory.Cards.AddRange(created);
            WriteLedger(StarterKey, Currency.Coin, StarterCoins, "Başlangıç hediyesi");
            var ids = created.Select(c => c.CardInstanceId).ToList();
            Record(StarterKey, "starter", fp, ids, "Başlangıç paketi");

            // Başlangıç kadrosu: 4-4-2 otomatik kur.
            var pick = AutoPicker.Pick(Formations.F442, _p.Inventory, _cat, null, "squad-1", "Ana Kadro");
            _p.Squads.Clear();
            _p.Squads.Add(pick.Plan);
            _p.ActiveSquadId = pick.Plan.SquadId;
            return new OpResult { Ok = true, CardInstanceIds = ids };
        }

        // ---------- kontrol sahası ödülü (PROTOTİP; gerçek maç ödülü T048) ----------
        public OpResult ClaimControlSessionReward(string sessionId, int goals, int passesToTargets, int saves)
        {
            string key = "control-session:" + sessionId;
            string fp = "ctl:" + goals + ":" + passesToTargets + ":" + saves;
            OpResult rp; if (TryReplay(key, "control-reward", fp, out rp)) return rp;
            long coins = RewardCalculator.ForControlSession(goals, passesToTargets);
            if (coins > 0) WriteLedger(key, Currency.Coin, coins, "Kontrol sahası ödülü");
            _p.ControlSessionsPlayed++;
            _p.ControlGoalsTotal += goals;
            _p.Xp += 10 + goals * 5;
            Record(key, "control-reward", fp, null, "coin=" + coins);
            return new OpResult { Ok = true };
        }
    }

    public static class RewardCalculator
    {
        public const long PerGoal = 50;
        public const long PerTargetPass = 10;
        public const long SessionCap = 500;

        /// <summary>Gerçekleşen olaylardan türetilir (sabit değil); oturum başına üst sınırlıdır.</summary>
        public static long ForControlSession(int goals, int targetPasses)
        {
            long v = Math.Max(0, goals) * PerGoal + Math.Max(0, targetPasses) * PerTargetPass;
            return Math.Min(v, SessionCap);
        }
    }
}
