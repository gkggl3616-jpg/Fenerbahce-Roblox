using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Match;
using Fenerbahce.Core.Sim;
using NUnit.Framework;

namespace Fenerbahce.Tests
{
    public class SimTests
    {
        const float Dt = 1f / 60f;

        static SimStats Striker(float shooting = 80f, float pace = 80f, float passing = 80f, float dribbling = 80f, float defending = 60f)
        {
            return new SimStats { Pace = pace, Shooting = shooting, Passing = passing, Dribbling = dribbling, Defending = defending, Physical = 70, Stamina = 80, SkillStars = 3, DisplayName = "Test" };
        }

        static ControlField NewField(int seed = 1, bool defender = false, float shooting = 80f, float gk = 70f, bool targets = true, float session = 120f, SimStats attacker = null)
        {
            var cfg = new ControlFieldConfig { Seed = seed, DefenderEnabled = defender, SessionSeconds = session };
            if (!targets) cfg.PassTargets = new List<Vec2>();
            var f = new ControlField(cfg, attacker ?? Striker(shooting), SimStats.Generic(gk, "Kaleci") /* goalkeeping=gk */);
            StepUntilLive(f);
            return f;
        }

        static void StepUntilLive(ControlField f)
        {
            for (int i = 0; i < 600 && f.Machine.Phase != MatchPhase.Live; i++) f.Step(Dt, default(PlayerInput));
            Assert.AreEqual(MatchPhase.Live, f.Machine.Phase);
        }

        static void Run(ControlField f, float seconds, PlayerInput input = default(PlayerInput), float dt = Dt)
        {
            int n = (int)Math.Round(seconds / dt);
            for (int i = 0; i < n; i++) f.Step(dt, input);
        }

        static void PlaceWithBall(ControlField f, Vec2 pos, Vec2 facing)
        {
            f.Player.Pos = pos; f.Player.Vel = Vec2.Zero; f.Player.Facing = facing.Normalized;
            f.Ball.Take(ControlField.PlayerId);
            f.Ball.Pos = pos + f.Player.Facing * 0.62f;
        }

        // ---------------- top fiziği ----------------
        [Test]
        public void Ball_Roll_Distance_Matches_Analytic_Model_At_30_And_60_Fps()
        {
            foreach (var d in new[] { 10f, 20f, 35f })
            {
                float v0 = BallPhysics.SpeedForDistance(d, 40f);
                Assert.AreEqual(d, BallPhysics.RollDistance(v0), 0.05f);
                foreach (var dt in new[] { 1f / 30f, 1f / 60f })
                {
                    var b = new BallBody(); b.SetFree(Vec2.Zero, new Vec2(v0, 0));
                    for (int i = 0; i < (int)(12f / dt); i++) b.StepFree(dt);
                    Assert.AreEqual(d, b.Pos.X, d * 0.04f, "dt=" + dt + " d=" + d);
                }
            }
        }

        [Test]
        public void Ball_Mode_Transitions_Free_InFlight_Free_And_Controlled()
        {
            var b = new BallBody(); b.SetFree(Vec2.Zero, Vec2.Zero);
            Assert.AreEqual(BallMode.Free, b.Mode);
            b.Kick(new Vec2(10, 0), 6f, 1, 0.3f);
            b.StepFree(Dt); Assert.AreEqual(BallMode.InFlight, b.Mode);
            for (int i = 0; i < 400; i++) b.StepFree(Dt);
            Assert.AreEqual(BallMode.Free, b.Mode); Assert.AreEqual(0f, b.Z, 1e-3f);
            b.Take(7); Assert.AreEqual(BallMode.Controlled, b.Mode); Assert.AreEqual(7, b.OwnerId);
        }

        [Test]
        public void Ball_Bounces_And_Loses_Height()
        {
            var b = new BallBody(); b.SetFree(Vec2.Zero, new Vec2(5, 0)); b.Z = 3f;
            float maxAfterBounce = 0; bool bounced = false;
            for (int i = 0; i < 600; i++)
            {
                float prevVz = b.VZ; b.StepFree(Dt);
                if (prevVz < 0 && b.VZ > 0) bounced = true;
                if (bounced) maxAfterBounce = Math.Max(maxAfterBounce, b.Z);
            }
            Assert.IsTrue(bounced); Assert.Less(maxAfterBounce, 3f);
        }

        // ---------------- oyuncu hareketi ----------------
        [Test]
        public void Player_Accelerates_Gradually_And_Reaches_Max_Speed()
        {
            var p = new PlayerBody(1, true, Striker(pace: 80), Vec2.Zero);
            float vmax = p.MaxSpeed(false, false);
            for (int i = 0; i < 6; i++) p.Step(Dt, new Vec2(1, 0), false, false);
            Assert.Less(p.Speed, vmax * 0.9f, "anında azami hıza çıkmamalı");
            Assert.Greater(p.Speed, 0.5f);
            for (int i = 0; i < 240; i++) p.Step(Dt, new Vec2(1, 0), false, false);
            Assert.AreEqual(vmax, p.Speed, vmax * 0.02f);
        }

        [Test]
        public void Higher_Pace_Gives_Higher_Top_Speed_And_Sprint_Is_Faster()
        {
            var slow = new PlayerBody(1, true, Striker(pace: 50), Vec2.Zero);
            var fast = new PlayerBody(2, true, Striker(pace: 90), Vec2.Zero);
            Assert.Greater(fast.MaxSpeed(false, false), slow.MaxSpeed(false, false) + 1f);
            Assert.AreEqual(fast.MaxSpeed(false, false) * 1.3f, fast.MaxSpeed(true, false), 0.01f);
            Assert.Less(fast.MaxSpeed(false, true), fast.MaxSpeed(false, false), "top taşıyan biraz yavaşlar");
        }

        [Test]
        public void Sprint_Drains_Stamina_And_Rest_Recovers_It()
        {
            var p = new PlayerBody(1, true, Striker(), Vec2.Zero);
            for (int i = 0; i < 60 * 7; i++) p.Step(Dt, new Vec2(1, 0), true, false);
            Assert.Less(p.Stamina, 0.4f);
            float low = p.Stamina;
            for (int i = 0; i < 60 * 6; i++) p.Step(Dt, Vec2.Zero, false, false);
            Assert.Greater(p.Stamina, low + 0.3f);
        }

        [Test]
        public void Empty_Stamina_Prevents_Sprint_Boost()
        {
            var p = new PlayerBody(1, true, Striker(), Vec2.Zero) { Stamina = 0f };
            for (int i = 0; i < 300; i++) p.Step(Dt, new Vec2(1, 0), true, false);
            Assert.Less(p.Speed, p.MaxSpeed(true, false) * 0.9f);
        }

        [Test]
        public void Sharp_Reversal_Slows_Player_Down()
        {
            var p = new PlayerBody(1, true, Striker(), Vec2.Zero);
            for (int i = 0; i < 240; i++) p.Step(Dt, new Vec2(1, 0), false, false);
            float top = p.Speed; float min = top;
            for (int i = 0; i < 120; i++) { p.Step(Dt, new Vec2(-1, 0), false, false); min = Math.Min(min, p.Speed); }
            Assert.Less(min, top * 0.3f, "180° dönüş sırasında hız belirgin düşmeli");
            Assert.Less(p.Vel.X, 0f);
        }

        [Test]
        public void Movement_Distance_Is_Similar_At_30_And_60_Fps()
        {
            float Dist(float dt)
            {
                var p = new PlayerBody(1, true, Striker(), Vec2.Zero);
                for (int i = 0; i < (int)(2f / dt); i++) p.Step(dt, new Vec2(1, 0), true, false);
                return p.Pos.X;
            }
            Assert.AreEqual(Dist(1f / 60f), Dist(1f / 30f), Dist(1f / 60f) * 0.03f);
        }

        // ---------------- pas ----------------
        [Test]
        public void Pass_Direction_And_Power_Drive_Ball_Motion()
        {
            var weak = NewField(targets: false); var strong = NewField(targets: false);
            PlaceWithBall(weak, new Vec2(0, 0), new Vec2(1, 0)); PlaceWithBall(strong, new Vec2(0, 0), new Vec2(1, 0));
            weak.Step(Dt, new PlayerInput { Move = new Vec2(0, 1), Pass = true, Power = 0.1f });
            strong.Step(Dt, new PlayerInput { Move = new Vec2(0, 1), Pass = true, Power = 1f });
            Assert.AreEqual(BallMode.Free, weak.Ball.Mode);
            Assert.Greater(weak.Ball.Vel.Y, 0f, "yön girdisi topu +Y'ye göndermeli");
            Assert.Greater(Math.Abs(weak.Ball.Vel.Y), Math.Abs(weak.Ball.Vel.X) * 4f, "yaklaşık joystick yönünde");
            Assert.Greater(strong.Ball.Vel.Length, weak.Ball.Vel.Length * 1.8f);
            Assert.AreEqual(1, strong.Stats.Passes);
            Assert.AreEqual(BallOwnership.Loose, strong.Ownership);
        }

        [Test]
        public void Pass_While_Moving_And_Sprinting_Works_Simultaneously()
        {
            var f = NewField(targets: false);
            PlaceWithBall(f, new Vec2(0, 0), new Vec2(1, 0));
            Run(f, 0.8f, new PlayerInput { Move = new Vec2(1, 0), Sprint = true });
            Assert.IsTrue(f.HasBall);
            float x0 = f.Player.Pos.X;
            f.Step(Dt, new PlayerInput { Move = new Vec2(1, 0), Sprint = true, Pass = true, Power = 0.6f });
            Run(f, 0.3f, new PlayerInput { Move = new Vec2(1, 0), Sprint = true });
            Assert.Greater(f.Player.Pos.X, x0 + 1f, "oyuncu koşmaya devam etmeli");
            Assert.AreEqual(1, f.Stats.Passes);
            Assert.AreNotEqual(BallOwnership.Ours, f.Ownership);
        }

        [Test]
        public void Passer_Cannot_Immediately_Retake_Own_Pass()
        {
            var f = NewField(targets: false);
            PlaceWithBall(f, Vec2.Zero, new Vec2(1, 0));
            f.Step(Dt, new PlayerInput { Pass = true, Power = 0.05f });
            Run(f, 0.2f);
            Assert.IsFalse(f.HasBall);
        }

        [Test]
        public void Pass_Without_Ball_Is_Ignored()
        {
            var f = NewField(targets: false);
            f.Ball.SetFree(new Vec2(-30, 0), Vec2.Zero);
            f.Step(Dt, new PlayerInput { Pass = true, Shoot = true, Power = 1f });
            Assert.AreEqual(0, f.Stats.Passes); Assert.AreEqual(0, f.Stats.Shots);
        }

        [Test]
        public void PassTargeting_Picks_Best_In_Cone_And_Rejects_Outside()
        {
            var c = new List<Vec2> { new Vec2(20, 20), new Vec2(20, 0), new Vec2(-20, 0) };
            Assert.AreEqual(1, PassTargeting.Pick(Vec2.Zero, new Vec2(1, 0), c));
            Assert.AreEqual(0, PassTargeting.Pick(Vec2.Zero, new Vec2(0.3f, 1), c));
            Assert.AreEqual(-1, PassTargeting.Pick(Vec2.Zero, new Vec2(0, -1), c));
            Assert.AreEqual(2, PassTargeting.Pick(Vec2.Zero, new Vec2(-1, 0), c));
            Assert.AreEqual(-1, PassTargeting.Pick(Vec2.Zero, Vec2.Zero, c));
        }

        [Test]
        public void Assisted_Pass_Reaches_Target_In_Most_Seeds()
        {
            int hits = 0;
            for (int seed = 1; seed <= 40; seed++)
            {
                var f = NewField(seed);
                PlaceWithBall(f, new Vec2(12, 0), new Vec2(1, 0));
                f.Step(Dt, new PlayerInput { Move = new Vec2(1, 0), Pass = true, Power = 0.5f });
                Run(f, 5f);
                if (f.Stats.TargetPasses == 1) hits++;
            }
            Assert.GreaterOrEqual(hits, 36, "hedefli pas isabeti: " + hits + "/40");
        }

        // ---------------- şut / gol / kaleci ----------------
        [Test]
        public void Goal_Is_Scored_Once_And_Score_Matches_Stats()
        {
            // Savunmasız, kalecisiz boş kale: kaleci çok uzakta konumlandırılır.
            var f = NewField();
            f.Keeper.Pos = new Vec2(f.Pitch.HalfLength - 1f, 30f); f.Keeper.State = GkState.Beaten; f.Keeper.Timer = 99f; f.Keeper.DiveSpeed = 0;
            PlaceWithBall(f, new Vec2(40, 0), new Vec2(1, 0));
            var events = new List<FieldEvent>();
            f.Step(Dt, new PlayerInput { Shoot = true, Power = 0.7f });
            for (int i = 0; i < 60 * 8; i++) { f.Step(Dt, default(PlayerInput)); f.DrainEvents(events); }
            Assert.AreEqual(1, f.Stats.Goals);
            Assert.AreEqual(1, f.Machine.ScoreHome);
            Assert.AreEqual(1, events.Count(e => e.Type == FieldEventType.GoalScored));
        }

        [Test]
        public void Control_Is_Locked_During_Celebration_And_Returns_At_Kickoff()
        {
            var f = NewField();
            f.Machine.RegisterGoal(true);
            var pos = f.Player.Pos;
            Run(f, 1.0f, new PlayerInput { Move = new Vec2(1, 0), Sprint = true });
            Assert.AreEqual(MatchPhase.GoalCelebration, f.Machine.Phase);
            Assert.AreEqual(pos.X, f.Player.Pos.X, 0.05f);
            Run(f, MatchStateMachine.CelebrationSeconds + MatchStateMachine.ReplaySeconds, default(PlayerInput));
            Assert.IsTrue(f.Machine.Phase == MatchPhase.Kickoff || f.Machine.Phase == MatchPhase.Live);
            StepUntilLive(f);
            Assert.AreEqual(BallOwnership.Ours, f.Ownership, "santra sonrası top oyuncuda");
            float x = f.Player.Pos.X;
            Run(f, 0.5f, new PlayerInput { Move = new Vec2(1, 0) });
            Assert.Greater(f.Player.Pos.X, x + 0.5f, "canlı kontrol geri gelmeli");
        }

        [Test]
        public void Ball_Out_Of_Bounds_Returns_To_Player()
        {
            var f = NewField();
            f.Ball.Kick(new Vec2(0, 25), 0f, ControlField.PlayerId, 0.3f);
            var ev = new List<FieldEvent>();
            for (int i = 0; i < 60 * 8; i++) { f.Step(Dt, default(PlayerInput)); f.DrainEvents(ev); }
            Assert.AreEqual(1, ev.Count(e => e.Type == FieldEventType.BallOut));
            Assert.AreEqual(BallOwnership.Ours, f.Ownership);
        }

        [Test]
        public void Session_Ends_Once_And_Reaches_Result()
        {
            var f = NewField(session: 5f);
            var ev = new List<FieldEvent>();
            for (int i = 0; i < 60 * 8; i++) { f.Step(Dt, default(PlayerInput)); f.DrainEvents(ev); }
            Assert.AreEqual(MatchPhase.Result, f.Machine.Phase);
            Assert.AreEqual(1, ev.Count(e => e.Type == FieldEventType.SessionEnded));
        }

        class ShotResult { public int Shots, OnTarget, Goals, Saves; }

        /// <summary>20 m'den, kale köşelerine (±3 m) nişanlı tam güç şutlar; seed başına tek deneme.</summary>
        static ShotResult ShootMany(float shooting, float gk, int trials = 300)
        {
            var r = new ShotResult();
            for (int seed = 1; seed <= trials; seed++)
            {
                var f = NewField(seed, shooting: shooting, gk: gk);
                var pos = new Vec2(32.5f, (seed % 5 - 2) * 2f);
                PlaceWithBall(f, pos, new Vec2(1, 0));
                float cornerY = (seed % 2 == 0 ? 1f : -1f) * 3.0f;
                var aim = (new Vec2(f.Pitch.HalfLength, cornerY) - pos).Normalized;
                f.Step(Dt, new PlayerInput { Move = aim, Shoot = true, Power = 1f });
                Run(f, 3.5f);
                r.Shots += f.Stats.Shots; r.OnTarget += f.Stats.ShotsOnTarget; r.Goals += f.Stats.Goals; r.Saves += f.Stats.Saves;
            }
            return r;
        }

        [Test]
        public void Shooting_Attribute_Improves_Accuracy_In_Controlled_Trials()
        {
            var hi = ShootMany(95, 70); var lo = ShootMany(35, 70);
            Console.WriteLine("şut 95: " + hi.OnTarget + " isabet/" + hi.Goals + " gol | şut 35: " + lo.OnTarget + " isabet/" + lo.Goals + " gol");
            Assert.Greater(hi.OnTarget, lo.OnTarget + 15);
            Assert.Greater(hi.Goals, lo.Goals);
        }

        [Test]
        public void Goalkeeper_Attribute_Reduces_Goals_And_Elite_Striker_Does_Not_Always_Score()
        {
            var weakGk = ShootMany(85, 25); var strongGk = ShootMany(85, 95);
            Console.WriteLine("kaleci 25: " + weakGk.Goals + " gol, " + weakGk.Saves + " kurtarış | kaleci 95: " + strongGk.Goals + " gol, " + strongGk.Saves + " kurtarış");
            Assert.Less(strongGk.Goals, weakGk.Goals);
            Assert.Greater(strongGk.Saves, weakGk.Saves);
            var elite = ShootMany(99, 99);
            Assert.Greater(elite.Saves, 0, "yüksek GEN her pozisyonu golle bitirmemeli");
            Assert.Greater(elite.Goals, 0);
            Assert.Less(elite.Goals, elite.Shots);
        }

        [Test]
        public void Shot_Power_Affects_Ball_Speed()
        {
            var a = NewField(); var b = NewField();
            PlaceWithBall(a, new Vec2(20, 0), new Vec2(1, 0)); PlaceWithBall(b, new Vec2(20, 0), new Vec2(1, 0));
            a.Step(Dt, new PlayerInput { Shoot = true, Power = 0.25f }); b.Step(Dt, new PlayerInput { Shoot = true, Power = 1f });
            Assert.Greater(b.Ball.Vel.Length, a.Ball.Vel.Length * 1.5f);
        }

        // ---------------- savunma / sahiplik ----------------
        [Test]
        public void Standing_Still_With_Ball_Gets_Tackled_By_Defender_Most_Of_The_Time()
        {
            int lost = 0;
            for (int seed = 1; seed <= 20; seed++)
            {
                var f = NewField(seed, defender: true);
                PlaceWithBall(f, new Vec2(20, 0), new Vec2(1, 0));
                f.Defender.Pos = new Vec2(25, 0);
                Run(f, 12f);
                if (f.Stats.BallLosses > 0) lost++;
            }
            Assert.GreaterOrEqual(lost, 18, "savunmacı çelmesi: " + lost + "/20");
        }

        [Test]
        public void Ownership_And_Hud_Switch_When_Opponent_Wins_Ball_And_Slide_Can_Win_It_Back()
        {
            int won = 0, trials = 40;
            for (int seed = 1; seed <= trials; seed++)
            {
                var f = NewField(seed, defender: true);
                f.Player.Pos = new Vec2(10, 0); f.Player.Facing = new Vec2(1, 0); f.Player.Vel = Vec2.Zero;
                f.Defender.Pos = new Vec2(11.0f, 0); f.Defender.Facing = new Vec2(-1, 0); f.Defender.Vel = Vec2.Zero;
                f.Ball.Take(ControlField.DefenderId); f.Ball.Pos = f.Defender.Pos + f.Defender.Facing * 0.62f;
                Assert.AreEqual(BallOwnership.Theirs, f.Ownership);
                Assert.IsFalse(f.Hud.Contains(HudButton.Shoot)); Assert.IsTrue(f.Hud.Contains(HudButton.Slide));
                f.Step(Dt, new PlayerInput { Move = new Vec2(1, 0), Slide = true });
                Run(f, 0.5f, new PlayerInput());
                if (f.Stats.TacklesWon == 1) { won++; Assert.AreNotEqual(BallOwnership.Theirs, f.Ownership); }
            }
            Console.WriteLine("kayarak top kazanma: " + won + "/" + trials);
            Assert.Greater(won, trials * 0.35); Assert.Less(won, trials);
        }

        [Test]
        public void Hud_Shows_Attack_Buttons_When_We_Have_Ball()
        {
            var f = NewField();
            Assert.AreEqual(BallOwnership.Ours, f.Ownership);
            Assert.IsTrue(f.Hud.Contains(HudButton.Pass) && f.Hud.Contains(HudButton.Shoot));
            f.Ball.SetFree(new Vec2(0, 0), Vec2.Zero);
            Assert.AreEqual(BallOwnership.Loose, f.Ownership);
            Assert.IsTrue(f.Hud.Contains(HudButton.Slide));
        }

        // ---------------- çalım ----------------
        [Test]
        public void Skill_Direction_Change_Turns_Player_Respects_Cooldown_And_Stars()
        {
            var f = NewField();
            PlaceWithBall(f, new Vec2(0, 0), new Vec2(1, 0));
            f.Step(Dt, new PlayerInput { SkillDirection = -1 });
            Assert.AreEqual(1, f.Stats.Skills);
            Assert.Greater(f.Player.Facing.Y, 0.9f, "sol çalım +Y'ye döndürmeli (70°)");
            f.Step(Dt, new PlayerInput { SkillDirection = 1 });
            Assert.AreEqual(1, f.Stats.Skills, "bekleme süresinde ikinci çalım olmamalı");
            Run(f, 1.2f);
            Assert.IsTrue(f.HasBall || f.Ball.IsControlled);

            var noStars = Striker(); noStars.SkillStars = 0;
            var g = NewField(attacker: noStars);
            PlaceWithBall(g, Vec2.Zero, new Vec2(1, 0));
            g.Step(Dt, new PlayerInput { SkillDirection = 1 });
            Assert.AreEqual(0, g.Stats.Skills, "yetersiz beceri yıldızı çalımı engeller");
        }

        [Test]
        public void SkillMove_And_SkillUpgrade_Are_Separate_Types_And_Only_One_Move_Is_Implemented()
        {
            Assert.AreNotEqual(typeof(SkillMove), typeof(SkillUpgrade));
            Assert.AreEqual(4, SkillMoves.All.Count);
            Assert.AreEqual(1, SkillMoves.All.Count(s => s.Implemented));
            Assert.IsTrue(SkillMoves.All.All(s => s.IsPrototypeEstimate), "değerler ölçülmeden kesin sayılmamalı");
        }

        // ---------------- determinizm ----------------
        [Test]
        public void Same_Seed_And_Inputs_Produce_Identical_Results()
        {
            string Run1()
            {
                var f = NewField(seed: 7, defender: true);
                var rnd = new SimRandom(3);
                for (int i = 0; i < 60 * 20; i++)
                {
                    var inp = new PlayerInput { Move = new Vec2(rnd.NextSigned(), rnd.NextSigned()), Sprint = i % 90 < 30, Pass = i % 200 == 5, Shoot = i % 311 == 7, Power = 0.6f, Slide = i % 177 == 3 };
                    f.Step(Dt, inp);
                }
                return f.Player.Pos + "|" + f.Ball.Pos + "|" + f.Stats.Goals + "|" + f.Stats.Passes + "|" + f.Stats.Shots + "|" + f.Stats.BallLosses + "|" + f.Machine.Phase;
            }
            Assert.AreEqual(Run1(), Run1());
        }

        [Test]
        public void Ai_Defender_Does_Not_Stack_On_Same_Point_With_Player()
        {
            // Savunmacı top taşıyıcıyı kovalar ama aynı koordinata kilitlenmez (çelme denemesi aralıklı).
            var f = NewField(3, defender: true);
            PlaceWithBall(f, new Vec2(20, 0), new Vec2(1, 0));
            float minDist = 99f; int overlapFrames = 0;
            for (int i = 0; i < 60 * 10; i++)
            {
                f.Step(Dt, new PlayerInput { Move = new Vec2(0.6f, (float)Math.Sin(i * 0.02) * 0.8f), Sprint = true });
                float d = Vec2.Distance(f.Player.Pos, f.Defender.Pos);
                minDist = Math.Min(minDist, d);
                if (d < 0.05f) overlapFrames++;
            }
            Assert.Less(overlapFrames, 30);
        }
    }
}

namespace Fenerbahce.Tests
{
    public class ChargeCurveTests
    {
        [Test]
        public void Power_Is_Monotonic_Bounded_And_Taps_Are_Weak()
        {
            float prev = -1;
            for (float t = 0; t <= 1.5f; t += 0.02f)
            {
                float p = ChargeCurve.Power(t);
                Assert.GreaterOrEqual(p, prev - 1e-6f); Assert.That(p, Is.InRange(ChargeCurve.MinPower, 1f));
                prev = p;
            }
            Assert.AreEqual(ChargeCurve.MinPower, ChargeCurve.Power(0f), 1e-6f);
            Assert.AreEqual(1f, ChargeCurve.Power(ChargeCurve.FullChargeSeconds), 1e-6f);
            Assert.AreEqual(1f, ChargeCurve.Power(5f), 1e-6f);
            Assert.Less(ChargeCurve.Power(0.08f), 0.3f);
        }
    }
}
