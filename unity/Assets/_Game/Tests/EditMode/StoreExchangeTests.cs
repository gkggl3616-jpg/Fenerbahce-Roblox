using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Exchange;
using Fenerbahce.Core.Squad;
using Fenerbahce.Core.Store;
using NUnit.Framework;

namespace Fenerbahce.Tests
{
    public class FormatTests
    {
        [Test]
        public void Numbers_Use_Turkish_Grouping_And_B_Mln_Abbreviations()
        {
            Assert.AreEqual("1.329.300.000", NumberFormat.Full(1329300000L));
            Assert.AreEqual("141.373.237", NumberFormat.Full(141373237L));
            Assert.AreEqual("0", NumberFormat.Full(0));
            Assert.AreEqual("999", NumberFormat.Compact(999));
            Assert.AreEqual("408,6B", NumberFormat.Compact(408600));
            Assert.AreEqual("2,491Mln", NumberFormat.Compact(2491000));
            Assert.AreEqual("1,5Mlr", NumberFormat.Compact(1500000000L));
            Assert.AreEqual("-1,0B", NumberFormat.Compact(-1000));
        }

        [Test]
        public void Remaining_Time_Uses_HHMMSS_Below_48h_And_Days_Above()
        {
            Assert.AreEqual("12:37:51", TimeFormat.Remaining(new TimeSpan(12, 37, 51)));
            Assert.AreEqual("01:44:04", TimeFormat.Remaining(new TimeSpan(1, 44, 4)));
            Assert.AreEqual("25:44:04", TimeFormat.Remaining(new TimeSpan(25, 44, 4)));
            Assert.AreEqual("47:59:59", TimeFormat.Remaining(new TimeSpan(47, 59, 59)));
            Assert.AreEqual("2 GÜN", TimeFormat.Remaining(TimeSpan.FromHours(48)));
            Assert.AreEqual("6 GÜN", TimeFormat.Remaining(TimeSpan.FromDays(6.5)));
            Assert.AreEqual("00:00:00", TimeFormat.Remaining(TimeSpan.FromSeconds(-5)));
        }

        [Test]
        public void Periods_Daily_Rolls_At_Utc_Midnight_And_Weekly_On_Monday()
        {
            long T(int y, int m, int d, int h = 0) { return new DateTime(y, m, d, h, 0, 0, DateTimeKind.Utc).Ticks; }
            Assert.AreEqual(Periods.KeyOf(LimitPeriod.Daily, T(2026, 11, 16, 0)), Periods.KeyOf(LimitPeriod.Daily, T(2026, 11, 16, 23)));
            Assert.AreNotEqual(Periods.KeyOf(LimitPeriod.Daily, T(2026, 11, 16, 23)), Periods.KeyOf(LimitPeriod.Daily, T(2026, 11, 17, 0)));
            // 2026-11-16 Pazartesi
            Assert.AreNotEqual(Periods.KeyOf(LimitPeriod.Weekly, T(2026, 11, 15, 23)), Periods.KeyOf(LimitPeriod.Weekly, T(2026, 11, 16, 0)));
            Assert.AreEqual(Periods.KeyOf(LimitPeriod.Weekly, T(2026, 11, 16, 0)), Periods.KeyOf(LimitPeriod.Weekly, T(2026, 11, 22, 23)));
            Assert.AreNotEqual(Periods.KeyOf(LimitPeriod.Weekly, T(2026, 11, 22, 23)), Periods.KeyOf(LimitPeriod.Weekly, T(2026, 11, 23, 0)));
            Assert.AreEqual(T(2026, 11, 17, 0), Periods.NextResetTicks(LimitPeriod.Daily, T(2026, 11, 16, 9)));
            Assert.AreEqual(T(2026, 11, 23, 0), Periods.NextResetTicks(LimitPeriod.Weekly, T(2026, 11, 18, 9)));
            Assert.IsNull(Periods.NextResetTicks(LimitPeriod.Total, T(2026, 11, 16, 9)));
        }
    }

    public class BundleTests
    {
        int _n;
        EconomyService Svc(ProfileState p, Func<long> clock = null) { return new EconomyService(p, TestContent.Catalog(), () => "b" + (++_n).ToString("D4"), clock); }

        [Test]
        public void Bundle_Is_All_Or_Nothing_When_Any_Part_Is_Invalid()
        {
            var p = new ProfileState(); var s = Svc(p);
            s.ApplyCurrency("seed", Currency.Coin, 1000, "t");
            var g = s.GrantCards("g", new[] { "P045_BASE_V1" }, "t");
            // geçersiz ödül kartı → hiçbir şey tüketilmez, para düşmez
            var r = s.ApplyBundle("k1", "x", "fp", new[] { new CurrencyDelta(Currency.Coin, -500) }, new[] { "YOK_BASE_V1" }, g.CardInstanceIds, null, "t");
            Assert.IsFalse(r.Ok); Assert.AreEqual("BAD_REF", r.ErrorCode);
            Assert.AreEqual(1000, p.Wallet.Get(Currency.Coin)); Assert.AreEqual(1, p.Inventory.Cards.Count);
            // yetersiz bakiye
            r = s.ApplyBundle("k2", "x", "fp", new[] { new CurrencyDelta(Currency.Coin, -5000) }, null, g.CardInstanceIds, null, "t");
            Assert.AreEqual("INSUFFICIENT_FUNDS", r.ErrorCode); Assert.AreEqual(1, p.Inventory.Cards.Count);
            // kilitli kart
            s.SetLocked(g.CardInstanceIds[0], true);
            r = s.ApplyBundle("k3", "x", "fp", null, new[] { "P046_BASE_V1" }, g.CardInstanceIds, null, "t");
            Assert.AreEqual("LOCKED", r.ErrorCode); Assert.AreEqual(1, p.Inventory.Cards.Count);
        }

        [Test]
        public void Bundle_Replay_Does_Nothing_And_Different_Payload_Is_Rejected()
        {
            var p = new ProfileState(); var s = Svc(p); s.ApplyCurrency("seed", Currency.Coin, 1000, "t");
            var a = s.ApplyBundle("k", "x", "fp1", new[] { new CurrencyDelta(Currency.Coin, -100) }, new[] { "P046_BASE_V1" }, null, null, "t");
            var b = s.ApplyBundle("k", "x", "fp1", new[] { new CurrencyDelta(Currency.Coin, -100) }, new[] { "P046_BASE_V1" }, null, null, "t");
            Assert.IsTrue(a.Ok && b.Ok && b.Replayed); Assert.AreEqual(a.CardInstanceIds, b.CardInstanceIds);
            Assert.AreEqual(900, p.Wallet.Get(Currency.Coin)); Assert.AreEqual(1, p.Inventory.Cards.Count);
            Assert.AreEqual("KEY_REUSED", s.ApplyBundle("k", "x", "FARKLI", null, null, null, null, "t").ErrorCode);
        }
    }

    public class StoreTests
    {
        int _n; long _now;
        ProfileState _p; EconomyService _eco; StoreService _store; List<OfferDefinition> _offers;

        long T(int y, int m, int d, int h = 0) { return new DateTime(y, m, d, h, 0, 0, DateTimeKind.Utc).Ticks; }

        [SetUp]
        public void Setup()
        {
            _n = 0; _now = T(2026, 11, 16, 10);
            _p = new ProfileState { ProfileId = "t" };
            _eco = new EconomyService(_p, TestContent.Catalog(), () => "s" + (++_n).ToString("D4"), () => _now);
            _offers = OfferCatalog.Load(TestContent.FreshJson("offers.v1.json"));
            _store = new StoreService(_p, _eco, _offers);
        }

        void Fund(long coin, long token = 0)
        {
            if (coin > 0) _eco.ApplyCurrency("f-c" + (++_n), Currency.Coin, coin, "t");
            if (token > 0) _eco.ApplyCurrency("f-t" + (++_n), Currency.Token, token, "t");
        }

        [Test]
        public void Shipped_Offers_And_Exchanges_Validate_Clean()
        {
            Assert.AreEqual(0, OfferCatalog.Validate(_offers, TestContent.Catalog()).Count, string.Join("\n", OfferCatalog.Validate(_offers, TestContent.Catalog())));
            var ex = ExchangeCatalog.Load(TestContent.FreshJson("exchanges.v1.json"));
            Assert.AreEqual(0, ExchangeCatalog.Validate(ex, TestContent.Catalog()).Count, string.Join("\n", ExchangeCatalog.Validate(ex, TestContent.Catalog())));
            Assert.GreaterOrEqual(ex.Count, 3); Assert.GreaterOrEqual(_offers.Count, 4);
        }

        [Test]
        public void Validator_Rejects_Free_Offer_Without_Limit_And_Bad_References()
        {
            var bad = new List<OfferDefinition>
            {
                new OfferDefinition { OfferId = "A", Title = "x", RewardCoins = 10 }, // ücretsiz + limitsiz
                new OfferDefinition { OfferId = "B", Title = "y", Prices = { new PriceOption { Currency = Currency.Coin, Amount = 5 } }, RewardCardDefinitionIds = { "YOK_BASE_V1" } },
                new OfferDefinition { OfferId = "C", Title = "z", Prices = { new PriceOption { Currency = Currency.Coin, Amount = 5 } }, RewardCoins = 1, RequiresOfferId = "YOK" },
            };
            var errs = OfferCatalog.Validate(bad, TestContent.Catalog());
            Assert.IsTrue(errs.Any(e => e.Contains("limitsiz"))); Assert.IsTrue(errs.Any(e => e.Contains("geçersiz ödül")));
            Assert.IsTrue(errs.Any(e => e.Contains("önkoşul")));
        }

        [Test]
        public void Free_Daily_Offer_Cannot_Be_Claimed_Twice_Per_Day_But_Resets_Next_Utc_Day()
        {
            Assert.IsTrue(_store.Purchase("g1", "OFR_GUNLUK_HEDIYE", 0, 1).Ok);
            Assert.AreEqual(500, _p.Wallet.Get(Currency.Coin));
            var again = _store.Purchase("g2", "OFR_GUNLUK_HEDIYE", 0, 1);
            Assert.AreEqual("LIMIT_REACHED", again.ErrorCode); Assert.AreEqual(500, _p.Wallet.Get(Currency.Coin));
            var v = _store.View(_offers.First(o => o.OfferId == "OFR_GUNLUK_HEDIYE"));
            Assert.AreEqual(OfferState.LimitReached, v.State); Assert.AreEqual(1, v.Used); Assert.AreEqual("Günlük Limit: 1", v.LimitLabel);
            Assert.AreEqual(TimeSpan.FromHours(14), v.Remaining.Value, "gece yarısına kalan süre UTC'ye göre");
            _now = T(2026, 11, 17, 0);
            Assert.IsTrue(_store.Purchase("g3", "OFR_GUNLUK_HEDIYE", 0, 1).Ok);
            Assert.AreEqual(1000, _p.Wallet.Get(Currency.Coin));
        }

        [Test]
        public void Device_Clock_Cannot_Reset_Limits_Only_The_Injected_Server_Clock_Does()
        {
            Assert.IsTrue(_store.Purchase("g1", "OFR_GUNLUK_HEDIYE", 0, 1).Ok);
            // "cihaz saati" ileri alınsa bile servis saati aynıysa limit sürer
            var deviceNow = DateTime.UtcNow.AddDays(30).Ticks; Assert.Greater(deviceNow, _now);
            Assert.AreEqual("LIMIT_REACHED", _store.Purchase("g2", "OFR_GUNLUK_HEDIYE", 0, 1).ErrorCode);
        }

        [Test]
        public void Dual_Price_Pays_With_Chosen_Currency_And_Insufficient_Funds_Changes_Nothing()
        {
            var r = _store.Purchase("p1", "OFR_BASLANGIC_OYUNCU", 0, 1);
            Assert.AreEqual("INSUFFICIENT_FUNDS", r.ErrorCode); Assert.AreEqual(0, _p.Inventory.Cards.Count);
            Fund(1000, 25);
            Assert.AreEqual("INSUFFICIENT_FUNDS", _store.Purchase("p2", "OFR_BASLANGIC_OYUNCU", 0, 1).ErrorCode, "coin yetmiyor");
            var ok = _store.Purchase("p3", "OFR_BASLANGIC_OYUNCU", 1, 1); // jeton ile
            Assert.IsTrue(ok.Ok);
            Assert.AreEqual(5, _p.Wallet.Get(Currency.Token)); Assert.AreEqual(1000, _p.Wallet.Get(Currency.Coin));
            Assert.AreEqual(1, _p.Inventory.Cards.Count);
        }

        [Test]
        public void Quantity_Multiplies_Price_And_Rewards_And_Respects_Total_Limit_Atomically()
        {
            Fund(10000);
            var tooMany = _store.Purchase("q1", "OFR_BASLANGIC_OYUNCU", 0, 3); // limit 2
            Assert.AreEqual("LIMIT_REACHED", tooMany.ErrorCode); Assert.AreEqual(10000, _p.Wallet.Get(Currency.Coin)); Assert.AreEqual(0, _p.Inventory.Cards.Count);
            var two = _store.Purchase("q2", "OFR_BASLANGIC_OYUNCU", 0, 2);
            Assert.IsTrue(two.Ok); Assert.AreEqual(7000, _p.Wallet.Get(Currency.Coin)); Assert.AreEqual(2, _p.Inventory.Cards.Count);
            Assert.AreEqual(2, two.CardInstanceIds.Distinct().Count());
            Assert.AreEqual("LIMIT_REACHED", _store.Purchase("q3", "OFR_BASLANGIC_OYUNCU", 0, 1).ErrorCode);
            var v = _store.View(_offers.First(o => o.OfferId == "OFR_BASLANGIC_OYUNCU"));
            Assert.AreEqual("2/2", v.Used + "/" + v.Max); Assert.AreEqual("Satın Alma Limiti: 2", v.LimitLabel);
        }

        [Test]
        public void Weekly_Limit_Resets_On_Monday()
        {
            Fund(20000);
            _now = T(2026, 11, 18, 12); // Çarşamba
            for (int i = 0; i < 3; i++) Assert.IsTrue(_store.Purchase("w" + i, "OFR_HAFTALIK_TAKVIYE", 0, 1).Ok);
            Assert.AreEqual("LIMIT_REACHED", _store.Purchase("wx", "OFR_HAFTALIK_TAKVIYE", 0, 1).ErrorCode);
            _now = T(2026, 11, 22, 23); // Pazar, aynı hafta
            Assert.AreEqual("LIMIT_REACHED", _store.Purchase("wy", "OFR_HAFTALIK_TAKVIYE", 0, 1).ErrorCode);
            _now = T(2026, 11, 23, 0);  // Pazartesi
            Assert.IsTrue(_store.Purchase("wz", "OFR_HAFTALIK_TAKVIYE", 0, 1).Ok);
        }

        [Test]
        public void Locked_Offer_Opens_After_Prerequisite_And_Stays_Open()
        {
            Fund(20000);
            var o = _offers.First(x => x.OfferId == "OFR_OZEL_KART");
            Assert.AreEqual(OfferState.Locked, _store.View(o).State);
            var locked = _store.Purchase("l1", "OFR_OZEL_KART", 0, 1);
            Assert.AreEqual("LOCKED", locked.ErrorCode); StringAssert.Contains("Başlangıç Oyuncu", locked.Message);
            Assert.AreEqual(20000, _p.Wallet.Get(Currency.Coin));
            Assert.IsTrue(_store.Purchase("l2", "OFR_BASLANGIC_OYUNCU", 0, 1).Ok);
            Assert.AreEqual(OfferState.Available, _store.View(o).State);
            Assert.IsTrue(_store.Purchase("l3", "OFR_OZEL_KART", 0, 1).Ok);
        }

        [Test]
        public void Expired_Offer_And_Bad_Inputs_Are_Rejected_Without_Side_Effects()
        {
            Fund(5000);
            var exp = new OfferDefinition { OfferId = "OFR_SURELI", Title = "Süreli", Prices = { new PriceOption { Currency = Currency.Coin, Amount = 100 } }, RewardCoins = 1, ExpiresUtcTicks = T(2026, 11, 16, 9) };
            var st = new StoreService(_p, _eco, new[] { exp });
            Assert.AreEqual("EXPIRED", st.Purchase("e1", "OFR_SURELI", 0, 1).ErrorCode);
            Assert.AreEqual("BAD_PRICE", _store.Purchase("e2", "OFR_BASLANGIC_OYUNCU", 7, 1).ErrorCode);
            Assert.AreEqual("BAD_QUANTITY", _store.Purchase("e3", "OFR_BASLANGIC_OYUNCU", 0, 0).ErrorCode);
            Assert.AreEqual("BAD_QUANTITY", _store.Purchase("e4", "OFR_GUNLUK_HEDIYE", 0, 2).ErrorCode);
            Assert.AreEqual("BAD_REF", _store.Purchase("e5", "YOK", 0, 1).ErrorCode);
            Assert.AreEqual("NO_KEY", _store.Purchase("", "OFR_GUNLUK_HEDIYE", 0, 1).ErrorCode);
            Assert.AreEqual(5000, _p.Wallet.Get(Currency.Coin)); Assert.AreEqual(0, _p.Inventory.Cards.Count);
        }

        [Test]
        public void Repeated_Purchase_With_Same_Key_Charges_Once_And_Survives_Save_Reload()
        {
            Fund(5000);
            var a = _store.Purchase("dup", "OFR_HAFTALIK_TAKVIYE", 0, 1);
            var b = _store.Purchase("dup", "OFR_HAFTALIK_TAKVIYE", 0, 1);
            Assert.IsTrue(a.Ok && b.Ok && b.Replayed); Assert.AreEqual(4100, _p.Wallet.Get(Currency.Coin)); Assert.AreEqual(1, _p.Inventory.Cards.Count);
            Assert.AreEqual("KEY_REUSED", _store.Purchase("dup", "OFR_HAFTALIK_TAKVIYE", 0, 2).ErrorCode);
            // kayıt/yükleme sonrası sayaçlar ve işlem kaydı korunur
            var json = JsonUtil.Serialize(_p); var q = JsonUtil.Deserialize<ProfileState>(json);
            var eco2 = new EconomyService(q, TestContent.Catalog(), null, () => _now);
            var store2 = new StoreService(q, eco2, _offers);
            Assert.IsTrue(store2.Purchase("dup", "OFR_HAFTALIK_TAKVIYE", 0, 1).Replayed);
            Assert.AreEqual(1, store2.View(_offers.First(o => o.OfferId == "OFR_HAFTALIK_TAKVIYE")).Used);
        }
    }

    public class ExchangeTests
    {
        int _n; long _now;
        ProfileState _p; EconomyService _eco; ExchangeService _ex; ExchangeRecipe _kanarya;

        [SetUp]
        public void Setup()
        {
            _n = 0; _now = new DateTime(2026, 11, 16, 10, 0, 0, DateTimeKind.Utc).Ticks;
            _p = new ProfileState { ProfileId = "t" };
            _eco = new EconomyService(_p, TestContent.Catalog(), () => "x" + (++_n).ToString("D4"), () => _now);
            _ex = new ExchangeService(_p, TestContent.Catalog(), _eco);
            _kanarya = ExchangeCatalog.Load(TestContent.FreshJson("exchanges.v1.json")).First(r => r.RecipeId == "EX_KANARYA_1");
        }

        List<string> GrantBase(int minOverall, int count, int skip = 0)
        {
            var cat = TestContent.Catalog();
            var defs = cat.Cards.Where(c => c.Family == "BASE" && c.Overall >= minOverall).OrderBy(c => c.CardDefinitionId).Skip(skip).Take(count).Select(c => c.CardDefinitionId).ToList();
            Assert.AreEqual(count, defs.Count, "katalogda yeterli kart yok");
            return _eco.GrantCards("grant" + (++_n), defs, "t").CardInstanceIds;
        }

        Dictionary<string, List<string>> Sel(params KeyValuePair<string, List<string>>[] kv) { return kv.ToDictionary(x => x.Key, x => x.Value); }

        [Test]
        public void Counters_Show_Satisfied_Over_Required_And_Execution_Is_Blocked_Until_All_Met()
        {
            var hi = GrantBase(80, 2); var mid = GrantBase(75, 3, skip: 40);
            var st0 = _ex.Evaluate(_kanarya, null);
            Assert.AreEqual(0, st0.Satisfied["r1"]); Assert.AreEqual(2, st0.Required["r1"]); Assert.IsFalse(st0.CanExecute);
            var partial = _ex.Evaluate(_kanarya, Sel(new KeyValuePair<string, List<string>>("r1", hi)));
            Assert.AreEqual(2, partial.Satisfied["r1"]); Assert.AreEqual(0, partial.Satisfied["r2"]); Assert.IsFalse(partial.CanExecute);
            var full = _ex.Evaluate(_kanarya, Sel(new KeyValuePair<string, List<string>>("r1", hi), new KeyValuePair<string, List<string>>("r2", mid)));
            Assert.IsTrue(full.CanExecute, string.Join(",", full.Errors.ToArray()));
            Assert.AreEqual(0, full.UsesDone); Assert.AreEqual(5, full.MaxUses);
        }

        [Test]
        public void Execute_Consumes_Exactly_Selection_Grants_Reward_And_Counts_Usage_Atomically()
        {
            var hi = GrantBase(80, 2); var mid = GrantBase(75, 3, skip: 40); var spare = GrantBase(75, 1, skip: 60);
            var sel = Sel(new KeyValuePair<string, List<string>>("r1", hi), new KeyValuePair<string, List<string>>("r2", mid));
            int before = _p.Inventory.Cards.Count;
            var r = _ex.Execute("t1", _kanarya, sel);
            Assert.IsTrue(r.Ok, r.ToString());
            Assert.AreEqual(before - 5 + 1, _p.Inventory.Cards.Count);
            foreach (var id in hi.Concat(mid)) Assert.IsNull(_p.Inventory.Get(id), "seçilen kart tüketilmeli");
            Assert.IsNotNull(_p.Inventory.Get(spare[0]), "seçilmeyen kart dokunulmamalı");
            Assert.AreEqual("P050_SPECIAL_V1", TestContent.Catalog().GetCard(_p.Inventory.Get(r.CardInstanceIds[0]).CardDefinitionId).CardDefinitionId);
            Assert.AreEqual(1, _ex.UsesDone(_kanarya));
        }

        [Test]
        public void Double_Request_Does_Not_Duplicate_Reward_Or_Consume_Twice()
        {
            var hi = GrantBase(80, 2); var mid = GrantBase(75, 3, skip: 40);
            var sel = Sel(new KeyValuePair<string, List<string>>("r1", hi), new KeyValuePair<string, List<string>>("r2", mid));
            var a = _ex.Execute("same", _kanarya, sel);
            int afterFirst = _p.Inventory.Cards.Count;
            var b = _ex.Execute("same", _kanarya, sel);
            Assert.IsTrue(a.Ok && b.Ok && b.Replayed);
            Assert.AreEqual(afterFirst, _p.Inventory.Cards.Count); Assert.AreEqual(1, _ex.UsesDone(_kanarya));
            Assert.AreEqual(a.CardInstanceIds, b.CardInstanceIds);
        }

        [Test]
        public void Locked_InSquad_Listed_And_Mismatched_Cards_Are_Rejected_Without_Side_Effects()
        {
            var cat = TestContent.Catalog();
            var hi = GrantBase(80, 2); var mid = GrantBase(75, 3, skip: 40);
            var low = _eco.GrantCards("low", new[] { "P002_BASE_V1" }, "t").CardInstanceIds; // GEN<75
            _eco.SetLocked(hi[0], true);
            var sel = Sel(new KeyValuePair<string, List<string>>("r1", hi), new KeyValuePair<string, List<string>>("r2", mid));
            var r = _ex.Execute("a", _kanarya, sel);
            Assert.IsFalse(r.Ok); Assert.AreEqual("LOCKED", r.ErrorCode);
            _eco.SetLocked(hi[0], false);
            _p.Inventory.Get(mid[0]).ListedOnMarket = true;
            Assert.AreEqual("LISTED", _ex.Execute("b", _kanarya, sel).ErrorCode);
            _p.Inventory.Get(mid[0]).ListedOnMarket = false;
            var sq = new SquadPlan { SquadId = "s", Name = "s", FormationId = "4-4-2" }; sq.Bench.Add(hi[1]); _p.Squads.Add(sq);
            Assert.AreEqual("IN_SQUAD", _ex.Execute("c", _kanarya, sel).ErrorCode);
            _p.Squads.Clear();
            var bad = Sel(new KeyValuePair<string, List<string>>("r1", new List<string> { low[0], hi[0] }), new KeyValuePair<string, List<string>>("r2", mid));
            var stBad = _ex.Evaluate(_kanarya, bad);
            Assert.IsTrue(stBad.Errors.Any(e => e.StartsWith("REQUIREMENT_MISMATCH")), "GEN yetmeyen kart koşulu sağlamaz");
            Assert.AreEqual("REQUIREMENT_MISMATCH", _ex.Execute("d", _kanarya, bad).ErrorCode);
            Assert.AreEqual(1, _p.Inventory.Cards.Count(c => c.CardInstanceId == hi[0]) + 0 * low.Count);
            Assert.AreEqual(0, _ex.UsesDone(_kanarya));
        }

        [Test]
        public void Same_Card_Cannot_Satisfy_Two_Requirements()
        {
            var hi = GrantBase(80, 2); var mid = GrantBase(75, 2, skip: 40);
            var sel = Sel(new KeyValuePair<string, List<string>>("r1", hi), new KeyValuePair<string, List<string>>("r2", new List<string> { mid[0], mid[1], hi[0] }));
            var st = _ex.Evaluate(_kanarya, sel);
            Assert.IsTrue(st.Errors.Contains("DUPLICATE")); Assert.IsFalse(st.CanExecute);
        }

        [Test]
        public void Quick_Add_Picks_Cheapest_Eligible_Skips_Locked_And_Squad_And_Does_Not_Reuse_Cards()
        {
            var hi = GrantBase(80, 4); var mid = GrantBase(75, 5, skip: 40);
            _eco.SetLocked(hi[0], true);
            var sel = _ex.QuickAdd(_kanarya);
            Assert.AreEqual(2, sel["r1"].Count); Assert.AreEqual(3, sel["r2"].Count);
            var allIds = sel.Values.SelectMany(x => x).ToList();
            Assert.AreEqual(allIds.Count, allIds.Distinct().Count(), "aynı kart iki koşula girmez");
            Assert.IsFalse(allIds.Contains(hi[0]), "kilitli kart eklenmez");
            var cat = TestContent.Catalog();
            long worstChosen = sel["r1"].Max(id => CardValue.Of(cat.GetCard(_p.Inventory.Get(id).CardDefinitionId).Overall));
            long bestUnchosenEligible = _p.Inventory.Cards.Where(c => !allIds.Contains(c.CardInstanceId) && !c.Locked && cat.GetCard(c.CardDefinitionId).Overall >= 80)
                .Select(c => CardValue.Of(cat.GetCard(c.CardDefinitionId).Overall)).DefaultIfEmpty(long.MaxValue).Min();
            Assert.LessOrEqual(worstChosen, bestUnchosenEligible, "en ucuz uygun kartlar seçilmeli");
            Assert.IsTrue(_ex.Evaluate(_kanarya, sel).CanExecute);
        }

        [Test]
        public void Quick_Add_With_Too_Few_Cards_Returns_Partial_Selection_For_Plus_Slots()
        {
            GrantBase(80, 1);
            var sel = _ex.QuickAdd(_kanarya);
            Assert.AreEqual(1, sel["r1"].Count); Assert.IsFalse(_ex.Evaluate(_kanarya, sel).CanExecute);
        }

        [Test]
        public void Usage_Limit_Blocks_After_Max_And_Expiry_Blocks_With_Remaining_Time()
        {
            var r = new ExchangeRecipe { RecipeId = "T_LIM", Title = "t", MaxUses = 2, RewardCoins = 10, Requirements = { new ExchangeRequirement { RequirementId = "a", MinOverall = 70, Count = 1, Label = "70+" } } };
            for (int i = 1; i <= 3; i++)
            {
                var c = GrantBase(70, 1, skip: i);
                var res = _ex.Execute("lim" + i, r, Sel(new KeyValuePair<string, List<string>>("a", c)));
                if (i <= 2) Assert.IsTrue(res.Ok, res.ToString()); else Assert.AreEqual("LIMIT_REACHED", res.ErrorCode);
            }
            Assert.AreEqual(20, _p.Wallet.Get(Currency.Coin));
            var timed = new ExchangeRecipe { RecipeId = "T_EXP", Title = "t", RewardCoins = 10, ExpiresUtcTicks = _now + TimeSpan.FromHours(12).Ticks, Requirements = { new ExchangeRequirement { RequirementId = "a", MinOverall = 70, Count = 1, Label = "70+" } } };
            Assert.AreEqual(TimeSpan.FromHours(12), _ex.Evaluate(timed, null).Remaining.Value);
            _now += TimeSpan.FromHours(13).Ticks;
            Assert.IsTrue(_ex.Evaluate(timed, null).Errors.Contains("EXPIRED"));
            var c2 = GrantBase(70, 1, skip: 9);
            Assert.AreEqual("EXPIRED", _ex.Execute("exp", timed, Sel(new KeyValuePair<string, List<string>>("a", c2))).ErrorCode);
            Assert.IsNotNull(_p.Inventory.Get(c2[0]));
        }

        [Test]
        public void Training_Level_Loss_Is_A_Warning_Not_A_Block()
        {
            var r = new ExchangeRecipe { RecipeId = "T_TR", Title = "t", RewardCoins = 10, Requirements = { new ExchangeRequirement { RequirementId = "a", MinOverall = 70, Count = 1, Label = "70+" } } };
            var c = GrantBase(70, 1); _p.Inventory.Get(c[0]).TrainingLevel = 3;
            var st = _ex.Evaluate(r, Sel(new KeyValuePair<string, List<string>>("a", c)));
            Assert.IsTrue(st.Warnings.Contains("TRAINING_LEVEL_LOST")); Assert.IsTrue(st.CanExecute);
        }

        [Test]
        public void Reward_With_Unknown_Card_Does_Not_Consume_Anything()
        {
            var r = new ExchangeRecipe { RecipeId = "T_BAD", Title = "t", RewardCardDefinitionIds = { "YOK_BASE_V1" }, Requirements = { new ExchangeRequirement { RequirementId = "a", MinOverall = 70, Count = 1, Label = "70+" } } };
            var c = GrantBase(70, 1);
            var res = _ex.Execute("bad", r, Sel(new KeyValuePair<string, List<string>>("a", c)));
            Assert.AreEqual("BAD_REF", res.ErrorCode); Assert.IsNotNull(_p.Inventory.Get(c[0])); Assert.AreEqual(0, _ex.UsesDone(r));
        }
    }
}
