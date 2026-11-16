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
            // Doğrulama bitti → tek seferde uygula.
            _p.Inventory.Cards.RemoveAll(c => cardInstanceIds.Contains(c.CardInstanceId));
            Record(key, "consume", fp, new List<string>(cardInstanceIds), reason);
            return new OpResult { Ok = true, CardInstanceIds = new List<string>(cardInstanceIds) };
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
