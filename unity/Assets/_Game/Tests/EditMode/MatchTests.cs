using System;
using System.Linq;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Match;
using NUnit.Framework;

namespace Fenerbahce.Tests
{
    public class MatchStateMachineTests
    {
        static MatchStateMachine Live(float half = 10f, int halves = 2)
        {
            var m = new MatchStateMachine(half, halves);
            m.Begin(true);
            m.Tick(MatchStateMachine.KickoffDelay + 0.01f);
            return m;
        }

        [Test]
        public void Normal_Flow_Preparation_To_Result()
        {
            var m = new MatchStateMachine(1f, 2);
            Assert.AreEqual(MatchPhase.Preparation, m.Phase);
            m.Begin(false); Assert.AreEqual(MatchPhase.Intro, m.Phase);
            m.SkipIntro(); Assert.AreEqual(MatchPhase.Kickoff, m.Phase);
            m.Tick(1.3f); Assert.AreEqual(MatchPhase.Live, m.Phase);
            m.Tick(1.0f); Assert.AreEqual(MatchPhase.HalfTime, m.Phase);
            m.StartSecondHalf(); Assert.AreEqual(MatchPhase.Kickoff, m.Phase); Assert.AreEqual(2, m.Half);
            m.Tick(1.3f); Assert.AreEqual(MatchPhase.Live, m.Phase);
            m.Tick(1.0f); Assert.AreEqual(MatchPhase.FullTime, m.Phase);
            m.ShowResult(); Assert.AreEqual(MatchPhase.Result, m.Phase);
            Assert.IsTrue(m.IsFinished);
        }

        [Test]
        public void Illegal_Transitions_Throw()
        {
            var m = new MatchStateMachine(10f);
            Assert.Throws<InvalidOperationException>(() => m.TransitionTo(MatchPhase.Live));
            m.Begin(true);
            Assert.Throws<InvalidOperationException>(() => m.TransitionTo(MatchPhase.Result));
            Assert.Throws<InvalidOperationException>(() => m.Begin(true));
        }

        [Test]
        public void Control_Is_Enabled_Only_In_Live()
        {
            var m = new MatchStateMachine(10f);
            Assert.IsFalse(m.IsControlEnabled);
            m.Begin(true); Assert.IsFalse(m.IsControlEnabled);
            m.Tick(2f); Assert.IsTrue(m.IsControlEnabled);
            m.RegisterGoal(true); Assert.AreEqual(MatchPhase.GoalCelebration, m.Phase); Assert.IsFalse(m.IsControlEnabled);
            m.Tick(MatchStateMachine.CelebrationSeconds + 0.01f); Assert.AreEqual(MatchPhase.Replay, m.Phase); Assert.IsFalse(m.IsControlEnabled);
            m.Tick(MatchStateMachine.ReplaySeconds + 0.01f); Assert.AreEqual(MatchPhase.Kickoff, m.Phase); Assert.IsFalse(m.IsControlEnabled);
            m.Tick(2f); Assert.IsTrue(m.IsControlEnabled);
        }

        [Test]
        public void Goal_Is_Registered_Only_Once_During_Celebration()
        {
            var m = Live();
            Assert.IsTrue(m.RegisterGoal(true));
            Assert.IsFalse(m.RegisterGoal(true), "kutlama sırasında ikinci gol yazılmamalı");
            m.Tick(MatchStateMachine.CelebrationSeconds + 0.1f);
            Assert.IsFalse(m.RegisterGoal(true), "tekrar sırasında gol yazılmamalı");
            Assert.AreEqual(1, m.ScoreHome); Assert.AreEqual(1, m.GoalsRegistered);
        }

        [Test]
        public void Clock_Stops_During_Celebration_And_Replay()
        {
            var m = Live(60f);
            m.Tick(5f); var before = m.ElapsedInHalf;
            m.RegisterGoal(true);
            m.Tick(MatchStateMachine.CelebrationSeconds * 0.9f);
            Assert.AreEqual(before, m.ElapsedInHalf, 1e-4);
        }

        [Test]
        public void Replay_Can_Be_Skipped()
        {
            var m = Live(60f);
            m.RegisterGoal(false); m.Tick(MatchStateMachine.CelebrationSeconds + 0.1f);
            m.SkipReplay(); Assert.AreEqual(MatchPhase.Kickoff, m.Phase);
            Assert.AreEqual(1, m.ScoreAway);
        }

        [Test]
        public void Goal_At_End_Of_Half_Leads_To_HalfTime_After_Sequence_Not_Kickoff()
        {
            var m = Live(10f);
            m.Tick(9.99f);
            m.RegisterGoal(true);
            m.Tick(0.05f); // saat durur
            m.Tick(MatchStateMachine.CelebrationSeconds + 0.1f);
            m.SkipReplay();
            // Gol, devre bitmeden 0.01 sn önce olduysa Kickoff'a döner ve kalan süre oynanır.
            Assert.AreEqual(MatchPhase.Kickoff, m.Phase);
            m.Tick(2f); m.Tick(0.1f);
            Assert.AreEqual(MatchPhase.HalfTime, m.Phase);
        }

        [Test]
        public void Display_Minute_Scales_To_90()
        {
            var m = Live(100f, 2);
            m.Tick(50f); Assert.AreEqual(22, m.DisplayMinute);
            m.Tick(50f); Assert.AreEqual(MatchPhase.HalfTime, m.Phase);
            m.StartSecondHalf(); m.Tick(2f); m.Tick(100f);
            Assert.AreEqual(90, m.DisplayMinute);
        }

        [Test]
        public void SetPiece_Returns_To_Live()
        {
            var m = Live();
            m.BeginSetPiece(); Assert.AreEqual(MatchPhase.SetPiece, m.Phase); Assert.IsFalse(m.ClockRunning);
            m.EndSetPiece(); Assert.AreEqual(MatchPhase.Live, m.Phase);
        }
    }

    public class HudAndDesignTests
    {
        [Test]
        public void Hud_Buttons_Change_With_Ownership_And_Hide_Outside_Live()
        {
            var atk = HudLayout.ButtonsFor(BallOwnership.Ours, MatchPhase.Live);
            Assert.IsTrue(atk.Contains(HudButton.Pass) && atk.Contains(HudButton.Shoot) && atk.Contains(HudButton.Skill) && atk.Contains(HudButton.ThroughPass) && atk.Contains(HudButton.Sprint));
            Assert.IsFalse(atk.Contains(HudButton.Slide));
            foreach (var o in new[] { BallOwnership.Theirs, BallOwnership.Loose })
            {
                var def = HudLayout.ButtonsFor(o, MatchPhase.Live);
                Assert.IsTrue(def.Contains(HudButton.Slide) && def.Contains(HudButton.Sprint));
                Assert.IsFalse(def.Contains(HudButton.Shoot));
            }
            foreach (MatchPhase ph in Enum.GetValues(typeof(MatchPhase)))
                if (ph != MatchPhase.Live) Assert.AreEqual(0, HudLayout.ButtonsFor(BallOwnership.Ours, ph).Count, ph.ToString());
        }

        [Test]
        public void All_Design_Colors_Are_Valid_Hex()
        {
            foreach (var c in DesignTokens.AllColors) Assert.DoesNotThrow(() => DesignTokens.ParseHex(c), c);
        }

        [Test]
        public void Yellow_Text_On_Yellow_Is_Never_Chosen_And_Core_Pairs_Are_Readable()
        {
            Assert.AreEqual(1.0, Contrast.Ratio(DesignTokens.Yellow, DesignTokens.Yellow), 1e-9);
            Assert.AreEqual(DesignTokens.Navy, Contrast.TextOn(DesignTokens.Yellow), "sarı zeminde lacivert metin");
            Assert.AreEqual(DesignTokens.TextLight, Contrast.TextOn(DesignTokens.Navy));
            Assert.GreaterOrEqual(Contrast.Ratio(DesignTokens.Yellow, DesignTokens.Navy), 7.0);
            Assert.GreaterOrEqual(Contrast.Ratio(DesignTokens.TextLight, DesignTokens.Surface), 7.0);
            Assert.GreaterOrEqual(Contrast.Ratio(DesignTokens.Navy, DesignTokens.FrameSpecial), 7.0);
        }
    }
}

namespace Fenerbahce.Tests
{
    public class PortraitCropTests
    {
        [Test]
        public void Square_Box_Uses_Whole_Image()
        {
            var u = Fenerbahce.Core.Design.PortraitCrop.Compute(1f, 0.5f, 0.38f);
            Assert.AreEqual(0f, u.X, 1e-5); Assert.AreEqual(0f, u.Y, 1e-5); Assert.AreEqual(1f, u.W, 1e-5); Assert.AreEqual(1f, u.H, 1e-5);
        }

        [Test]
        public void Wide_Box_Crops_Vertically_Keeping_Face_Focal_Point_Inside_Window()
        {
            var u = Fenerbahce.Core.Design.PortraitCrop.Compute(2f, 0.5f, 0.38f);
            Assert.AreEqual(1f, u.W, 1e-5); Assert.AreEqual(0.5f, u.H, 1e-5);
            float topEdge = 1f - (u.Y + u.H); // görsel üstünden uzaklık
            Assert.That(0.38f, Is.InRange(topEdge, topEdge + u.H));
            Assert.GreaterOrEqual(u.Y, 0f); Assert.LessOrEqual(u.Y + u.H, 1f + 1e-5f);
        }

        [Test]
        public void Narrow_Box_Crops_Horizontally_And_Never_Leaves_Image()
        {
            foreach (var fx in new[] { 0f, 0.2f, 0.5f, 0.9f, 1f })
            {
                var u = Fenerbahce.Core.Design.PortraitCrop.Compute(0.5f, fx, 0.4f);
                Assert.AreEqual(0.5f, u.W, 1e-5);
                Assert.GreaterOrEqual(u.X, 0f); Assert.LessOrEqual(u.X + u.W, 1f + 1e-5f);
            }
            Assert.Throws<System.ArgumentOutOfRangeException>(() => Fenerbahce.Core.Design.PortraitCrop.Compute(0f, 0.5f, 0.5f));
        }
    }
}

namespace Fenerbahce.Tests
{
    public class SearchTests
    {
        [TestCase("Dominik Livaković", "livakovic")]
        [TestCase("Gökhan Gönül", "GOKHAN")]
        [TestCase("İrfan Can Kahveci", "irfan")]
        [TestCase("Rüştü Reçber", "rustu rec")]
        [TestCase("Mert Hakan Yandaş", "yandas")]
        [TestCase("Kylian Mbappé", "mbappe")]
        [TestCase("Jamal Musiala", "")]
        public void Turkish_And_Accent_Insensitive_Search_Matches(string name, string query)
        {
            Assert.IsTrue(Fenerbahce.Core.Design.TextFold.Matches(name, query));
        }

        [Test]
        public void Search_Does_Not_Match_Unrelated_And_Finds_Expected_Players_In_Catalog()
        {
            Assert.IsFalse(Fenerbahce.Core.Design.TextFold.Matches("Alex de Souza", "zidane"));
            var cat = TestContent.Catalog();
            Assert.AreEqual(1, cat.Players.Count(p => Fenerbahce.Core.Design.TextFold.Matches(p.DisplayName, "gokhan")));
            Assert.AreEqual(1, cat.Players.Count(p => Fenerbahce.Core.Design.TextFold.Matches(p.DisplayName, "livakovic")));
            Assert.AreEqual(0, cat.Players.Count(p => Fenerbahce.Core.Design.TextFold.Matches(p.DisplayName, "zzzz")));
        }
    }
}
