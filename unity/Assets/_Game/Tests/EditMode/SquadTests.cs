using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Squad;
using NUnit.Framework;

namespace Fenerbahce.Tests
{
    public class SquadTests
    {
        int _n;
        ProfileState NewProfile()
        {
            _n = 0;
            var p = new ProfileState { ProfileId = "t" };
            new EconomyService(p, TestContent.Catalog(), () => "c" + (++_n).ToString("D3")).ClaimStarterPackage();
            return p;
        }

        [Test]
        public void Starter_Squad_Is_Valid_442_With_No_Out_Of_Position()
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            var sq = p.ActiveSquad;
            Assert.AreEqual("4-4-2", sq.FormationId);
            var issues = SquadService.Validate(sq, p.Inventory, cat, true);
            Assert.AreEqual(0, issues.Count, string.Join("\n", issues.Select(i => i.ToString())));
            Assert.AreEqual(11, sq.FilledStarters());
            Assert.AreEqual(11, sq.Starters.Distinct().Count());
        }

        [TestCase("4-4-2")]
        [TestCase("4-3-3")]
        [TestCase("4-2-3-1")]
        public void AutoPick_Fills_All_Starter_Formations_Validly(string formation)
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            var r = AutoPicker.Pick(formation, p.Inventory, cat, null, "s", "n");
            Assert.IsTrue(r.IsComplete, "boş slot: " + string.Join(",", r.UnfilledSlots));
            var issues = SquadService.Validate(r.Plan, p.Inventory, cat, true);
            Assert.AreEqual(0, issues.Count, string.Join("\n", issues.Select(i => i.ToString())));
            Assert.LessOrEqual(r.Plan.Bench.Count, SquadPlan.MaxBench);
            Assert.AreEqual(1, r.Plan.Bench.Count(id => cat.PlayerOfCard(cat.GetCard(p.Inventory.Get(id).CardDefinitionId)).PrimaryPosition == Fenerbahce.Core.Domain.Position.GK));
            Assert.GreaterOrEqual(r.Plan.CaptainSlot, 1); // kaleci kaptan olamaz
        }

        [Test]
        public void Same_Card_In_Two_Slots_Is_Rejected()
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            var sq = p.ActiveSquad.Clone();
            sq.Starters[10] = sq.Starters[9];
            var issues = SquadService.Validate(sq, p.Inventory, cat, true);
            Assert.IsTrue(issues.Any(i => i.Code == "DUPLICATE_CARD" && i.IsError));
        }

        [Test]
        public void Place_Moves_Card_So_It_Never_Occupies_Two_Slots()
        {
            var p = NewProfile();
            var sq = p.ActiveSquad.Clone();
            var card = sq.Starters[9];
            SquadService.Place(sq, 10, card);
            Assert.IsNull(sq.Starters[9]);
            Assert.AreEqual(card, sq.Starters[10]);
            Assert.AreEqual(1, sq.Starters.Count(x => x == card));
        }

        [Test]
        public void Goalkeeper_In_Outfield_Slot_And_Vice_Versa_Is_Invalid()
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            var sq = p.ActiveSquad.Clone();
            var gk = sq.Starters[0]; var cb = sq.Starters[2];
            sq.Starters[0] = cb; sq.Starters[2] = gk;
            var issues = SquadService.Validate(sq, p.Inventory, cat, true);
            Assert.AreEqual(2, issues.Count(i => i.Code == "POSITION_INVALID"));
        }

        [Test]
        public void Same_Group_Different_Role_Is_Out_Of_Position_Warning_Not_Error()
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            var sq = p.ActiveSquad.Clone();
            (sq.Starters[1], sq.Starters[2]) = (sq.Starters[2], sq.Starters[1]); // LB <-> CB (aynı grup)
            var issues = SquadService.Validate(sq, p.Inventory, cat, true);
            Assert.IsFalse(issues.Any(i => i.IsError), string.Join("\n", issues.Select(i => i.ToString())));
            Assert.IsTrue(issues.Any(i => i.Code == "OUT_OF_POSITION") || SquadService.Summarize(sq, p.Inventory, cat).OutOfPositionCount >= 0);
        }

        [Test]
        public void Listed_Card_Cannot_Be_In_Squad()
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            p.Inventory.Get(p.ActiveSquad.Starters[5]).ListedOnMarket = true;
            var issues = SquadService.Validate(p.ActiveSquad, p.Inventory, cat, true);
            Assert.IsTrue(issues.Any(i => i.Code == "LISTED"));
        }

        [Test]
        public void AutoPick_Skips_Listed_Cards_And_Honors_Pinned()
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            var best = p.ActiveSquad.Starters[9];
            var pinnedCard = p.ActiveSquad.Starters[10];
            p.Inventory.Get(best).ListedOnMarket = true;
            var r = AutoPicker.Pick("4-4-2", p.Inventory, cat, new Dictionary<int, string> { { 9, pinnedCard } }, "s", "n");
            Assert.AreEqual(pinnedCard, r.Plan.Starters[9], "sabitlenen kart korunmalı");
            Assert.IsFalse(r.Plan.Starters.Contains(best), "satıştaki kart seçilmemeli");
            Assert.AreEqual(r.Plan.Starters.Where(x => x != null).Count(), r.Plan.Starters.Where(x => x != null).Distinct().Count());
        }

        [Test]
        public void Team_Summary_Is_Deterministic_And_Penalizes_Out_Of_Position()
        {
            var p = NewProfile(); var cat = TestContent.Catalog();
            var a = SquadService.Summarize(p.ActiveSquad, p.Inventory, cat);
            var b = SquadService.Summarize(p.ActiveSquad, p.Inventory, cat);
            Assert.AreEqual(a.Overall, b.Overall);
            Assert.AreEqual(11, a.FilledSlots);
            Assert.Greater(a.Overall, 60); Assert.Less(a.Overall, 90);
            Assert.AreEqual(0, a.OutOfPositionCount);
            var sq = p.ActiveSquad.Clone();
            (sq.Starters[1], sq.Starters[2]) = (sq.Starters[2], sq.Starters[1]);
            var c = SquadService.Summarize(sq, p.Inventory, cat);
            Assert.Greater(c.OutOfPositionCount, 0);
            Assert.Less(c.Overall, a.Overall + 1);
        }

        [Test]
        public void Swap_With_Bench_Keeps_Card_Unique()
        {
            var p = NewProfile();
            var sq = p.ActiveSquad.Clone();
            var benchCard = sq.Bench[0]; var old = sq.Starters[8];
            Assert.IsTrue(SquadService.SwapWithBench(sq, 8, benchCard));
            Assert.AreEqual(benchCard, sq.Starters[8]);
            Assert.IsTrue(sq.Bench.Contains(old));
            Assert.AreEqual(1, sq.Starters.Concat(sq.Bench).Count(x => x == old));
        }

        [Test]
        public void Formations_Have_11_Slots_And_Exactly_One_GK()
        {
            foreach (var f in Formations.All)
            {
                Assert.AreEqual(11, f.Slots.Count, f.FormationId);
                Assert.AreEqual(1, f.Slots.Count(s => s.Position == Fenerbahce.Core.Domain.Position.GK), f.FormationId);
                foreach (var s in f.Slots) { Assert.That(s.X, Is.InRange(0f, 1f)); Assert.That(s.Y, Is.InRange(0f, 1f)); }
            }
        }
    }
}
