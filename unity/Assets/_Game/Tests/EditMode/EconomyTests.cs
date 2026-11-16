using System.IO;
using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Persistence;
using Fenerbahce.Core.Squad;
using NUnit.Framework;

namespace Fenerbahce.Tests
{
    public class EconomyTests
    {
        int _n;
        EconomyService Svc(ProfileState p) { return new EconomyService(p, TestContent.Catalog(), () => "id" + (++_n).ToString("D4")); }

        [Test]
        public void Starter_Package_Grants_18_Cards_And_Coins_Exactly_Once()
        {
            var p = new ProfileState { ProfileId = "t" }; var s = Svc(p);
            var first = s.ClaimStarterPackage();
            var second = s.ClaimStarterPackage();
            Assert.IsTrue(first.Ok); Assert.IsFalse(first.Replayed);
            Assert.IsTrue(second.Ok); Assert.IsTrue(second.Replayed);
            Assert.AreEqual(first.CardInstanceIds, second.CardInstanceIds);
            Assert.AreEqual(EconomyService.StarterCards.Length, p.Inventory.Cards.Count);
            Assert.AreEqual(EconomyService.StarterCoins, p.Wallet.Get(Currency.Coin));
            Assert.AreEqual(1, p.Wallet.Ledger.Count);
            Assert.AreEqual(1, p.Squads.Count);
        }

        [Test]
        public void Starter_Cards_Are_All_Valid_Catalog_References()
        {
            foreach (var id in EconomyService.StarterCards) Assert.NotNull(TestContent.Catalog().GetCard(id), id);
            Assert.AreEqual(EconomyService.StarterCards.Length, EconomyService.StarterCards.Distinct().Count());
        }

        [Test]
        public void Coin_Never_Goes_Negative_And_Failed_Debit_Leaves_No_Trace()
        {
            var p = new ProfileState(); var s = Svc(p);
            s.ApplyCurrency("k1", Currency.Coin, 100, "test");
            var r = s.ApplyCurrency("k2", Currency.Coin, -101, "test");
            Assert.IsFalse(r.Ok); Assert.AreEqual("INSUFFICIENT_FUNDS", r.ErrorCode);
            Assert.AreEqual(100, p.Wallet.Get(Currency.Coin));
            Assert.AreEqual(1, p.Wallet.Ledger.Count);
            Assert.IsFalse(p.Operations.ContainsKey("k2"));
            Assert.IsTrue(s.ApplyCurrency("k3", Currency.Coin, -100, "test").Ok);
            Assert.AreEqual(0, p.Wallet.Get(Currency.Coin));
        }

        [Test]
        public void Repeated_Request_With_Same_Key_Does_Not_Duplicate_Reward()
        {
            var p = new ProfileState(); var s = Svc(p);
            for (int i = 0; i < 5; i++) s.ApplyCurrency("same", Currency.Coin, 250, "ödül");
            Assert.AreEqual(250, p.Wallet.Get(Currency.Coin));
            Assert.AreEqual(1, p.Wallet.Ledger.Count);
        }

        [Test]
        public void Reusing_A_Key_With_Different_Payload_Is_Rejected()
        {
            var p = new ProfileState(); var s = Svc(p);
            s.ApplyCurrency("k", Currency.Coin, 100, "a");
            var r = s.ApplyCurrency("k", Currency.Coin, 999, "a");
            Assert.IsFalse(r.Ok); Assert.AreEqual("KEY_REUSED", r.ErrorCode);
            Assert.AreEqual(100, p.Wallet.Get(Currency.Coin));
        }

        [Test]
        public void Missing_Key_Is_Rejected()
        {
            var s = Svc(new ProfileState());
            Assert.AreEqual("NO_KEY", s.ApplyCurrency("", Currency.Coin, 1, "x").ErrorCode);
        }

        [Test]
        public void Consume_Is_Atomic_Locked_Card_Blocks_Whole_Operation()
        {
            var p = new ProfileState(); var s = Svc(p); s.ClaimStarterPackage();
            s.GrantCards("spare", new[] { "P045_BASE_V1", "P046_BASE_V1", "P082_BASE_V1" }, "test");
            var spare = p.Inventory.Cards.Where(c => !SquadService.IsAssigned(p.ActiveSquad, c.CardInstanceId)).Select(c => c.CardInstanceId).ToList();
            Assert.GreaterOrEqual(spare.Count, 2, "başlangıç kartlarının tamamı kadroda (11+7); yedek kart ayrıca verildi");
            s.SetLocked(spare[1], true);
            int before = p.Inventory.Cards.Count;
            var r = s.ConsumeCards("train-1", new[] { spare[0], spare[1] }, "antrenman");
            Assert.IsFalse(r.Ok); Assert.AreEqual("LOCKED", r.ErrorCode);
            Assert.AreEqual(before, p.Inventory.Cards.Count, "kısmi tüketim olmamalı");
            Assert.IsNotNull(p.Inventory.Get(spare[0]));
        }

        [Test]
        public void Consume_Rejects_Squad_And_Listed_Cards_Silently_Spent_Never()
        {
            var p = new ProfileState(); var s = Svc(p); s.ClaimStarterPackage();
            s.GrantCards("spare", new[] { "P045_BASE_V1" }, "test");
            var inSquad = p.ActiveSquad.Starters[3];
            Assert.AreEqual("IN_SQUAD", s.ConsumeCards("a", new[] { inSquad }, "x").ErrorCode);
            var spare = p.Inventory.Cards.First(c => !SquadService.IsAssigned(p.ActiveSquad, c.CardInstanceId));
            spare.ListedOnMarket = true;
            Assert.AreEqual("LISTED", s.ConsumeCards("b", new[] { spare.CardInstanceId }, "x").ErrorCode);
            Assert.AreEqual("NOT_OWNED", s.ConsumeCards("c", new[] { "yok" }, "x").ErrorCode);
            Assert.AreEqual("DUPLICATE", s.ConsumeCards("d", new[] { spare.CardInstanceId, spare.CardInstanceId }, "x").ErrorCode);
        }

        [Test]
        public void Consume_Replay_Does_Not_Remove_Twice_Nor_Fail()
        {
            var p = new ProfileState(); var s = Svc(p); s.ClaimStarterPackage();
            s.GrantCards("spare", new[] { "P045_BASE_V1" }, "test");
            var spare = p.Inventory.Cards.First(c => !SquadService.IsAssigned(p.ActiveSquad, c.CardInstanceId)).CardInstanceId;
            int n = p.Inventory.Cards.Count;
            Assert.IsTrue(s.ConsumeCards("t1", new[] { spare }, "x").Ok);
            var again = s.ConsumeCards("t1", new[] { spare }, "x");
            Assert.IsTrue(again.Ok); Assert.IsTrue(again.Replayed);
            Assert.AreEqual(n - 1, p.Inventory.Cards.Count);
        }

        [Test]
        public void Two_Copies_Of_Same_Card_Have_Independent_Lock()
        {
            var p = new ProfileState(); var s = Svc(p);
            var g = s.GrantCards("g1", new[] { "P004_BASE_V1", "P004_BASE_V1" }, "test");
            Assert.AreEqual(2, g.CardInstanceIds.Distinct().Count());
            s.SetLocked(g.CardInstanceIds[0], true);
            Assert.IsTrue(p.Inventory.Get(g.CardInstanceIds[0]).Locked);
            Assert.IsFalse(p.Inventory.Get(g.CardInstanceIds[1]).Locked);
        }

        [Test]
        public void Grant_Rejects_Unknown_Card_Without_Partial_Grant()
        {
            var p = new ProfileState(); var s = Svc(p);
            var r = s.GrantCards("g", new[] { "P004_BASE_V1", "P999_BASE_V1" }, "x");
            Assert.IsFalse(r.Ok); Assert.AreEqual(0, p.Inventory.Cards.Count);
        }

        [Test]
        public void Control_Session_Reward_Derives_From_Events_Is_Capped_And_Idempotent()
        {
            var p = new ProfileState(); var s = Svc(p);
            Assert.IsTrue(s.ClaimControlSessionReward("S1", 3, 4, 1).Ok);
            Assert.AreEqual(3 * RewardCalculator.PerGoal + 4 * RewardCalculator.PerTargetPass, p.Wallet.Get(Currency.Coin));
            s.ClaimControlSessionReward("S1", 3, 4, 1);
            Assert.AreEqual(1, p.ControlSessionsPlayed);
            Assert.AreEqual(3 * RewardCalculator.PerGoal + 4 * RewardCalculator.PerTargetPass, p.Wallet.Get(Currency.Coin));
            Assert.AreEqual(RewardCalculator.SessionCap, RewardCalculator.ForControlSession(99, 99));
            Assert.AreEqual(0, RewardCalculator.ForControlSession(0, 0));
        }

        // ---- Kalıcılık: "yeniden açılışta kadro ve envanter korunur" ----
        [Test]
        public void Save_And_Reload_Preserves_Squad_Inventory_And_Wallet()
        {
            var path = Path.Combine(Path.GetTempPath(), "fb_test_" + System.Guid.NewGuid().ToString("N"), "profile.json");
            try
            {
                var repo = new ProfileRepository(new FileStorage(path));
                bool created;
                var p = repo.LoadOrCreate(TestContent.Catalog(), out created);
                Assert.IsTrue(created);
                var s = new EconomyService(p, TestContent.Catalog());
                s.SetLocked(p.Inventory.Cards[3].CardInstanceId, true);
                s.ClaimControlSessionReward("X", 2, 1, 0);
                var cat = TestContent.Catalog();
                var benchSt = p.ActiveSquad.Bench.First(id => cat.PlayerOfCard(cat.GetCard(p.Inventory.Get(id).CardDefinitionId)).PrimaryPosition == Fenerbahce.Core.Domain.Position.ST);
                Assert.IsTrue(SquadService.SwapWithBench(p.ActiveSquad, 10, benchSt));
                repo.Save(p);

                var repo2 = new ProfileRepository(new FileStorage(path));
                var q = repo2.LoadOrCreate(TestContent.Catalog(), out created);
                Assert.IsFalse(created, "var olan kayıt yeniden oluşturulmamalı");
                Assert.AreEqual(p.ProfileId, q.ProfileId);
                Assert.AreEqual(p.Inventory.Cards.Select(c => c.CardInstanceId), q.Inventory.Cards.Select(c => c.CardInstanceId));
                Assert.AreEqual(p.ActiveSquad.Starters, q.ActiveSquad.Starters);
                Assert.AreEqual(p.ActiveSquad.Bench, q.ActiveSquad.Bench);
                Assert.AreEqual(p.Wallet.Get(Currency.Coin), q.Wallet.Get(Currency.Coin));
                Assert.IsTrue(q.Inventory.Cards[3].Locked);
                Assert.IsTrue(new EconomyService(q, TestContent.Catalog()).ClaimStarterPackage().Replayed, "başlangıç ödülü yeniden verilmemeli");
                Assert.AreEqual(EconomyService.StarterCards.Length, q.Inventory.Cards.Count);
                Assert.AreEqual(0, SquadService.Validate(q.ActiveSquad, q.Inventory, TestContent.Catalog(), true).Count(i => i.IsError));
            }
            finally { try { Directory.Delete(Path.GetDirectoryName(path), true); } catch { } }
        }

        [Test]
        public void Newer_Schema_Save_Is_Refused_Instead_Of_Silently_Overwritten()
        {
            var st = new MemoryStorage();
            st.Write(JsonUtil.Serialize(new ProfileState { SchemaVersion = 99, ProfileId = "x" }));
            Assert.Throws<System.InvalidOperationException>(() => new ProfileRepository(st).Load());
        }
    }
}
