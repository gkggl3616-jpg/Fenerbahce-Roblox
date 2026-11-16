using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Domain;
using NUnit.Framework;

namespace Fenerbahce.Tests
{
    public class CatalogTests
    {
        [Test]
        public void Catalog_Has_Exactly_100_Unique_Players()
        {
            var c = TestContent.Catalog();
            Assert.AreEqual(100, c.Players.Count);
            Assert.AreEqual(100, c.UniquePlayerCount);
            Assert.AreEqual(100, c.Players.Select(p => p.PlayerId).Distinct().Count());
        }

        [Test]
        public void Catalog_Passes_Validator_With_No_Errors()
        {
            var r = CatalogValidator.Validate(TestContent.Catalog());
            Assert.IsTrue(r.IsValid, r.ToString());
        }

        [Test]
        public void Card_Variants_Do_Not_Increase_Player_Count()
        {
            var c = TestContent.Catalog();
            Assert.Greater(c.Cards.Count, 100, "varyant kartlar bulunmalı");
            Assert.AreEqual(100, c.Cards.Select(d => d.PlayerId).Distinct().Count());
            Assert.IsTrue(c.Cards.Any(d => d.Family != "BASE"));
            foreach (var p in c.Players) Assert.NotNull(c.GetCard(p.PlayerId + "_BASE_V1"), p.PlayerId);
        }

        [Test]
        public void Group_Distribution_Matches_Proposal_10_32_32_26()
        {
            var c = TestContent.Catalog();
            Assert.AreEqual(10, c.Players.Count(p => p.PositionGroup == PositionGroup.GK));
            Assert.AreEqual(32, c.Players.Count(p => p.PositionGroup == PositionGroup.DEF));
            Assert.AreEqual(32, c.Players.Count(p => p.PositionGroup == PositionGroup.MID));
            Assert.AreEqual(26, c.Players.Count(p => p.PositionGroup == PositionGroup.ATT));
        }

        [Test]
        public void Every_Player_Has_A_Position_And_Stats_Are_Flagged_Prototype()
        {
            foreach (var p in TestContent.Catalog().Players)
            {
                Assert.AreEqual(PositionInfo.GroupOf(p.PrimaryPosition), p.PositionGroup, p.PlayerId);
                Assert.AreEqual("PROTOTIP_DENGE_V0", p.StatsSource, p.PlayerId);
            }
        }

        [Test]
        public void No_Real_Portrait_Is_Claimed_Delivered_Until_Rights_Verified()
        {
            var r = CatalogValidator.Validate(TestContent.Catalog());
            Assert.AreEqual(0, r.PortraitsDelivered, "Portreler teslim edilmedi (T091 açık)");
            Assert.AreEqual(100, r.PortraitsFallback);
            foreach (var p in TestContent.Catalog().Players) Assert.IsFalse(p.Portrait.CanShowRealPortrait);
        }

        // ---- Doğrulayıcının gerçekten hata yakaladığını kanıtlayan negatif testler ----
        ContentCatalog Fresh() { return ContentCatalog.Load(TestContent.FreshJson("players.v1.json"), TestContent.FreshJson("cards.v1.json")); }

        [Test]
        public void Validator_Rejects_Duplicate_PlayerId()
        {
            var c = Fresh();
            ((System.Collections.Generic.List<PlayerDefinition>)c.Players)[1].PlayerId = "P001";
            var r = CatalogValidator.Validate(c);
            Assert.IsFalse(r.IsValid);
            Assert.IsTrue(r.Errors.Any(e => e.StartsWith("PLAYER_DUP")));
            Assert.IsTrue(r.Errors.Any(e => e.StartsWith("PLAYER_COUNT")));
        }

        [Test]
        public void Validator_Rejects_99_Players()
        {
            var c = Fresh();
            ((System.Collections.Generic.List<PlayerDefinition>)c.Players).RemoveAt(99);
            Assert.IsTrue(CatalogValidator.Validate(c).Errors.Any(e => e.StartsWith("PLAYER_COUNT")));
        }

        [Test]
        public void Validator_Rejects_Card_With_Unknown_Player()
        {
            var c = Fresh();
            ((System.Collections.Generic.List<CardDefinition>)c.Cards)[0].PlayerId = "P999";
            Assert.IsTrue(CatalogValidator.Validate(c).Errors.Any(e => e.StartsWith("CARD_REF")));
        }

        [Test]
        public void Validator_Rejects_Delivered_Portrait_Without_Verified_Rights()
        {
            var c = Fresh();
            var p = c.Players[0]; p.Portrait.Delivered = true; p.Portrait.Source = "x"; // izin DOGRULANACAK
            Assert.IsTrue(CatalogValidator.Validate(c).Errors.Any(e => e.StartsWith("PORTRAIT_RIGHTS")));
        }

        [Test]
        public void Validator_Rejects_Alternate_Position_Equal_To_Primary()
        {
            var c = Fresh();
            var p = c.Players.First(x => x.PositionGroup == PositionGroup.MID);
            p.AlternatePositions.Add(p.PrimaryPosition);
            Assert.IsTrue(CatalogValidator.Validate(c).Errors.Any(e => e.StartsWith("PLAYER_ALT")));
        }
    }
}

namespace Fenerbahce.Tests
{
    public class CampaignTests
    {
        [Test]
        public void Campaigns_Load_And_Reference_Known_Screens()
        {
            var list = CampaignCatalog.Load(System.IO.File.ReadAllText(System.IO.Path.Combine(TestContent.ContentDir(), "campaigns.v1.json")));
            Assert.GreaterOrEqual(list.Count, 3);
            Assert.AreEqual(0, CampaignCatalog.Validate(list).Count, string.Join("\n", CampaignCatalog.Validate(list)));
            Assert.IsTrue(list.Any(c => c.Implemented));
            Assert.IsTrue(list.Any(c => !c.Implemented), "yapılmamış özellikler 'yakında' diye işaretli olmalı");
        }

        [Test]
        public void Validator_Rejects_Unknown_Target_Screen_And_Duplicate_Ids()
        {
            var bad = new System.Collections.Generic.List<Campaign>
            {
                new Campaign { Id = "a", Title = "x", TargetScreen = "yok", AccentHex = "#FFFFFF" },
                new Campaign { Id = "a", Title = "y", TargetScreen = "home", AccentHex = "bad" },
            };
            var errs = CampaignCatalog.Validate(bad);
            Assert.IsTrue(errs.Any(e => e.Contains("bilinmeyen hedef")));
            Assert.IsTrue(errs.Any(e => e.Contains("yinelenmiş")));
            Assert.IsTrue(errs.Any(e => e.Contains("renk")));
        }
    }
}
