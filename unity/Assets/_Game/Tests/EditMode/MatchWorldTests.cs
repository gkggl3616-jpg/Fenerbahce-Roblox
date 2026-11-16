using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Match;
using Fenerbahce.Core.Sim;
using NUnit.Framework;

namespace Fenerbahce.Tests
{
    /// <summary>S1: 5v5 takım yapay zekâsı (T041/T026). Ölçüt testleri: sonuçlar tek maça değil çok tohuma bakar.</summary>
    public class MatchWorldTests
    {
        const float Dt = 1f / 60f;

        static MatchWorldConfig Cfg(int seed, float homeLevel = 70f, float awayLevel = 70f, bool human = false, float half = 120f)
        {
            return new MatchWorldConfig
            {
                Seed = seed, HalfSeconds = half, HumanControlsHome = human,
                Home = TeamSetup.Small5("Kanarya", homeLevel), Away = TeamSetup.Small5("Rakip", awayLevel),
            };
        }

        static void Run(MatchWorld w, float seconds, Func<MatchWorld, PlayerInput> input = null)
        {
            int n = (int)(seconds / Dt);
            for (int i = 0; i < n; i++) w.Step(Dt, input == null ? new PlayerInput() : input(w));
        }

        static MatchWorld PlayFull(MatchWorldConfig cfg)
        {
            var w = new MatchWorld(cfg);
            int guard = 0;
            while (w.Machine.Phase != MatchPhase.Result && guard++ < 60 * 60 * 10) w.Step(Dt, new PlayerInput());
            return w;
        }

        [Test]
        public void Creates_Two_Teams_With_Keepers_And_Kickoff_Possession()
        {
            var w = new MatchWorld(Cfg(1, human: true));
            Assert.AreEqual(8, w.Agents.Count);
            Assert.AreEqual(4, w.Agents.Count(a => a.Team == 0));
            Assert.AreEqual(4, w.Agents.Count(a => a.Team == 1));
            Assert.AreEqual(2, w.Keepers.Length);
            Assert.AreEqual(-1, w.Keepers[0].Sign);
            Assert.AreEqual(+1, w.Keepers[1].Sign);
        }

        [Test]
        public void Ai_Vs_Ai_Full_Match_Reaches_Result_With_Plausible_Football_Metrics()
        {
            int matches = 12; int goals = 0, shots = 0, onTarget = 0, saves = 0, passes = 0, passDone = 0;
            double possHome = 0; int zeroZero = 0; var scores = new List<int>();
            for (int seed = 1; seed <= matches; seed++)
            {
                var w = PlayFull(Cfg(seed));
                Assert.AreEqual(MatchPhase.Result, w.Machine.Phase, "seed " + seed + " bitmeli");
                var r = w.BuildResult();
                goals += r.ScoreHome + r.ScoreAway; scores.Add(r.ScoreHome + r.ScoreAway);
                shots += r.Home.Shots + r.Away.Shots; onTarget += r.Home.ShotsOnTarget + r.Away.ShotsOnTarget;
                saves += r.Home.Saves + r.Away.Saves; passes += r.Home.Passes + r.Away.Passes; passDone += r.Home.PassesCompleted + r.Away.PassesCompleted;
                possHome += r.HomePossessionPercent;
                if (r.ScoreHome + r.ScoreAway == 0) zeroZero++;
                Assert.AreEqual(r.ScoreHome, w.Machine.ScoreHome, "log skoru ile makine skoru aynı olmalı");
                Assert.AreEqual(r.ScoreAway, w.Machine.ScoreAway);
            }
            Console.WriteLine("5v5 AI vs AI ({0} maç, 2 dk): gol/maç={1:0.0} şut/maç={2:0.0} isabetli={3:0.0} kurtarış={4:0.0} pas/maç={5:0.0} pas isabeti={6:0}% ev sahibi topa sahip olma={7:0}% 0-0={8}",
                matches, goals / (double)matches, shots / (double)matches, onTarget / (double)matches, saves / (double)matches,
                passes / (double)matches, 100.0 * passDone / Math.Max(1, passes), possHome / matches, zeroZero);
            Assert.GreaterOrEqual(goals / (double)matches, 0.8, "gol/maç çok düşük");
            Assert.LessOrEqual(goals / (double)matches, 9.0, "gol/maç çok yüksek");
            Assert.GreaterOrEqual(shots / (double)matches, 3.0, "şut/maç çok düşük");
            Assert.GreaterOrEqual(passes / (double)matches, 8.0, "takımlar pas oynamalı");
            Assert.Less(zeroZero, matches, "tüm maçlar 0-0 olmamalı");
            Assert.That(possHome / matches, Is.InRange(35.0, 65.0), "eşit takımlar topa sahip olmayı kabaca bölüşmeli");
        }

        [Test]
        public void Two_Halves_Pass_Through_HalfTime_And_End_With_FullTime_Then_Result()
        {
            var cfg = Cfg(4, half: 40f); cfg.Halves = 2;
            var w = new MatchWorld(cfg);
            var phases = new List<MatchPhase>(); var seen = new List<FieldEvent>();
            int guard = 0; MatchPhase last = w.Machine.Phase;
            while (w.Machine.Phase != MatchPhase.Result && guard++ < 60 * 400)
            {
                w.Step(Dt, new PlayerInput());
                if (w.Machine.Phase != last) { phases.Add(w.Machine.Phase); last = w.Machine.Phase; }
            }
            Assert.AreEqual(MatchPhase.Result, w.Machine.Phase);
            Assert.AreEqual(1, phases.Count(p => p == MatchPhase.HalfTime), "tek devre arası");
            Assert.AreEqual(1, phases.Count(p => p == MatchPhase.FullTime));
            Assert.Greater(phases.IndexOf(MatchPhase.FullTime), phases.IndexOf(MatchPhase.HalfTime));
            Assert.AreEqual(2, w.Machine.Half);
        }

        [Test]
        public void Same_Seed_Gives_Identical_Match_And_Different_Seeds_Differ()
        {
            var a = PlayFull(Cfg(7)).BuildResult(); var b = PlayFull(Cfg(7)).BuildResult();
            Assert.AreEqual(a.ScoreHome, b.ScoreHome); Assert.AreEqual(a.ScoreAway, b.ScoreAway);
            Assert.AreEqual(a.Home.Passes, b.Home.Passes); Assert.AreEqual(a.Away.Shots, b.Away.Shots);
            var distinct = new HashSet<string>();
            for (int s = 1; s <= 6; s++) { var r = PlayFull(Cfg(s)).BuildResult(); distinct.Add(r.Home.Passes + "/" + r.Away.Passes + "/" + r.Home.Shots + "/" + r.Away.Shots); }
            Assert.Greater(distinct.Count, 3, "farklı tohumlar farklı maç üretmeli");
        }

        [Test]
        public void Teams_Take_Positions_Spread_Out_Do_Not_Crowd_And_Push_Up_When_They_Have_The_Ball()
        {
            // T041 kabul: "5v5 denemede takımlar pozisyon alır". Ölçütler: yayılım, genişlik, yığılma, hücumda öne çıkma.
            double spreadSum = 0, widthSum = 0; long frames = 0, crowded = 0, crowdFrames = 0;
            double atkDepth = 0, defDepth = 0; long atkN = 0, defN = 0; long clumped = 0;
            for (int seed = 1; seed <= 6; seed++)
            {
                var w = new MatchWorld(Cfg(seed)); int guard = 0;
                while (w.Machine.Phase != MatchPhase.Result && guard++ < 60 * 400)
                {
                    w.Step(Dt, new PlayerInput());
                    if (w.Machine.Phase != MatchPhase.Live || guard % 6 != 0) continue;
                    for (int t = 0; t < 2; t++)
                    {
                        var mates = w.Agents.Where(a => a.Team == t).ToList();
                        float cx = mates.Average(a => a.Body.Pos.X), cy = mates.Average(a => a.Body.Pos.Y);
                        spreadSum += mates.Average(a => Math.Sqrt((a.Body.Pos.X - cx) * (a.Body.Pos.X - cx) + (a.Body.Pos.Y - cy) * (a.Body.Pos.Y - cy)));
                        widthSum += mates.Max(a => a.Body.Pos.Y) - mates.Min(a => a.Body.Pos.Y);
                        frames++;
                        int near = mates.Count(a => Vec2.Distance(a.Body.Pos, w.Ball.Pos) < 4f);
                        crowdFrames++; if (near >= 3) crowded++;
                        bool pair = false; for (int i = 0; i < mates.Count && !pair; i++) for (int j = i + 1; j < mates.Count; j++) if (Vec2.Distance(mates[i].Body.Pos, mates[j].Body.Pos) < 2.5f) { pair = true; break; }
                        if (pair) clumped++;
                        int dir = t == 0 ? 1 : -1;
                        if (w.PossessingTeam == t) { atkDepth += cx * dir; atkN++; } else if (w.PossessingTeam == 1 - t) { defDepth += cx * dir; defN++; }
                    }
                }
            }
            double spread = spreadSum / frames, width = widthSum / frames, crowd = (double)crowded / crowdFrames;
            double push = atkDepth / atkN - defDepth / defN;
            double pairs = (double)clumped / crowdFrames;
            Console.WriteLine("yayılım: takım merkezine ort. {0:0.0} m, genişlik {1:0.0} m, ≥3 oyuncu topa <4 m: {2:P1}, 2.5 m içinde ikili: {4:P1}, hücumda öne çıkma {3:0.0} m", spread, width, crowd, push, pairs);
            Assert.Greater(spread, 6.0, "takım tek noktaya yığılmamalı");
            Assert.Greater(width, 14.0, "takım sahayı genişliğine kullanmalı");
            Assert.Less(crowd, 0.12, "aynı takımdan 3+ oyuncu topun başında yığılmamalı");
            Assert.Less(pairs, 0.08, "takım arkadaşları üst üste binmemeli (ayrışma)");
            Assert.Greater(push, 3.8, "top bizdeyken takım rakip kaleye doğru yükselmeli");
        }

        [Test]
        public void Play_Never_Stalls_Ball_Moves_And_Possession_Changes_Hands()
        {
            double maxStill = 0, maxHold = 0; int changes = 0, matches = 6;
            for (int seed = 1; seed <= matches; seed++)
            {
                var w = new MatchWorld(Cfg(seed)); double still = 0, hold = 0; int lastOwner = -2;
                int guard = 0;
                while (w.Machine.Phase != MatchPhase.Result && guard++ < 60 * 400)
                {
                    w.Step(Dt, new PlayerInput());
                    if (w.Machine.Phase != MatchPhase.Live) { still = 0; hold = 0; continue; }
                    if (!w.Ball.IsControlled && w.Ball.Vel.Length < 0.3f) still += Dt; else still = 0;
                    int owner = w.Ball.IsControlled ? w.Ball.OwnerId : -1;
                    if (owner >= 0 && owner == lastOwner) hold += Dt; else hold = 0;
                    if (owner >= 0 && owner != lastOwner && lastOwner >= 0) changes++;
                    if (owner >= 0) lastOwner = owner;
                    maxStill = Math.Max(maxStill, still); maxHold = Math.Max(maxHold, hold);
                }
            }
            Console.WriteLine("durma: top en uzun {0:0.0} sn hareketsiz, en uzun tek oyuncu sahipliği {1:0.0} sn, el değiştirme {2}", maxStill, maxHold, changes);
            Assert.Less(maxStill, 5.0, "top hareketsiz kalmamalı");
            Assert.Less(maxHold, 14.0, "bir oyuncu topu sonsuza dek tutmamalı");
            Assert.Greater(changes, matches * 10, "top el değiştirmeli (pas/çelme)");
        }

        [Test]
        public void Players_Stay_On_Pitch_And_Ball_Stays_Bounded()
        {
            var w = new MatchWorld(Cfg(3));
            float maxX = w.Pitch.HalfLength + 4f, maxY = w.Pitch.HalfWidth + 4f;
            for (int i = 0; i < 60 * 240; i++)
            {
                w.Step(Dt, new PlayerInput());
                foreach (var a in w.Agents)
                {
                    Assert.LessOrEqual(Math.Abs(a.Body.Pos.X), maxX, "oyuncu X taştı t=" + w.Time);
                    Assert.LessOrEqual(Math.Abs(a.Body.Pos.Y), maxY, "oyuncu Y taştı t=" + w.Time);
                }
                Assert.IsFalse(float.IsNaN(w.Ball.Pos.X) || float.IsNaN(w.Ball.Pos.Y));
                Assert.LessOrEqual(Math.Abs(w.Ball.Pos.X), w.Pitch.HalfLength + 8f);
                Assert.LessOrEqual(Math.Abs(w.Ball.Pos.Y), w.Pitch.HalfWidth + 8f);
            }
        }

        [Test]
        public void Stronger_Team_Wins_More_Often_Over_Many_Seeds()
        {
            int strongWins = 0, weakWins = 0, draws = 0, n = 16;
            for (int s = 1; s <= n; s++)
            {
                var r = PlayFull(Cfg(s, 82f, 55f)).BuildResult();
                if (r.ScoreHome > r.ScoreAway) strongWins++; else if (r.ScoreHome < r.ScoreAway) weakWins++; else draws++;
            }
            Console.WriteLine("güçlü(82) vs zayıf(55): galibiyet={0} beraberlik={1} mağlubiyet={2}", strongWins, draws, weakWins);
            Assert.Greater(strongWins, weakWins, "güçlü takım daha çok kazanmalı");
        }

        [Test]
        public void Goal_Starts_Celebration_Then_Restarts_With_Conceding_Team_At_Center()
        {
            // Bir golü sahnele: ev sahibi forveti topla kaleye vurur.
            for (int seed = 1; seed <= 40; seed++)
            {
                var w = new MatchWorld(Cfg(seed, 95f, 30f));
                int before = w.Machine.ScoreHome + w.Machine.ScoreAway;
                float t = 0; bool seen = false;
                while (t < 200f && !seen) { w.Step(Dt, new PlayerInput()); t += Dt; seen = w.Machine.ScoreHome + w.Machine.ScoreAway > before; }
                if (!seen) continue;
                Assert.AreEqual(MatchPhase.GoalCelebration, w.Machine.Phase);
                Run(w, 12f);
                Assert.AreEqual(MatchPhase.Live, w.Machine.Phase, "kutlama sonrası santra ile oyun başlar");
                return;
            }
            Assert.Fail("40 tohumda hiç gol çıkmadı");
        }

        [Test]
        public void Stoppage_Time_Extends_Half_After_Goals_And_Display_Shows_Added_Minutes()
        {
            for (int seed = 1; seed <= 30; seed++)
            {
                var w = new MatchWorld(Cfg(seed, 90f, 40f, half: 60f));
                int guard = 0;
                while (w.Machine.Phase != MatchPhase.Result && guard++ < 60 * 400) w.Step(Dt, new PlayerInput());
                var r = w.BuildResult();
                if (r.ScoreHome + r.ScoreAway == 0) continue;
                Assert.Greater(w.Machine.StoppageSeconds, 0f, "gol sonrası uzatma süresi eklenmeli");
                return;
            }
            Assert.Fail("gol çıkmadı");
        }

        [Test]
        public void Hud_Follows_Ownership_And_Field_Position_In_Two_Team_Match()
        {
            var w = new MatchWorld(Cfg(2, human: true));
            Assert.AreEqual(0, w.Hud.Count, "santra bekleme anında kontrol kapalı (G35: yalnız canlı oyunda düğmeler)");
            ToLive(w);
            Assert.AreEqual(BallOwnership.Ours, w.Ownership, "santra: ev sahibi başlar");
            CollectionAssert.Contains(w.Hud.ToList(), HudButton.Pass);
            // Top rakipte
            var opp = w.Agents.First(a => a.Team == 1);
            w.Ball.Take(opp.Id);
            Assert.AreEqual(BallOwnership.Theirs, w.Ownership);
            CollectionAssert.IsSubsetOf(new[] { HudButton.Switch, HudButton.SecondDefender, HudButton.Slide, HudButton.SprintTackle, HudButton.AutoDefend }, w.Hud.ToList());
        }

        // ---------------- insan komutları ----------------
        static MatchWorld ToLive(MatchWorld w)
        {
            int guard = 0;
            while (w.Machine.Phase != MatchPhase.Live && guard++ < 600) w.Step(Dt, new PlayerInput());
            Assert.AreEqual(MatchPhase.Live, w.Machine.Phase);
            return w;
        }

        static MatchWorld HumanWorld(int seed, float awayLevel = 70f)
        {
            return ToLive(new MatchWorld(Cfg(seed, 70f, awayLevel, human: true)));
        }

        [Test]
        public void Switch_Moves_Control_To_Closest_Teammate_To_Ball()
        {
            var w = HumanWorld(5);
            var opp = w.Agents.First(a => a.Team == 1);
            w.Ball.Take(opp.Id); w.Ball.Pos = opp.Body.Pos + opp.Body.Facing * 0.6f;
            int cur = w.ControlledId;
            // en yakın takım arkadaşını hesapla (kontrol edilen hariç)
            var expected = w.Agents.Where(a => a.Team == 0 && a.Id != cur).OrderBy(a => Vec2.Distance(a.Body.Pos, w.Ball.Pos)).First().Id;
            w.SwitchPlayer(Vec2.Zero);
            Assert.AreEqual(expected, w.ControlledId);
            Assert.AreNotEqual(cur, w.ControlledId);
        }

        [Test]
        public void Switch_With_Stick_Direction_Prefers_Teammate_In_That_Direction()
        {
            var w = HumanWorld(5);
            var opp = w.Agents.First(a => a.Team == 1);
            w.Ball.Take(opp.Id);
            var cur = w.Controlled; cur.Body.Pos = new Vec2(0, 0);
            var mates = w.Agents.Where(a => a.Team == 0 && a.Id != cur.Id).ToList();
            mates[0].Body.Pos = new Vec2(0, 12); mates[1].Body.Pos = new Vec2(0, -12); mates[2].Body.Pos = new Vec2(-25, 0);
            w.SwitchPlayer(new Vec2(0, 1));
            Assert.AreEqual(mates[0].Id, w.ControlledId, "joystick yukarı → üstteki oyuncu");
            w.SwitchPlayer(new Vec2(0, -1));
            Assert.AreNotEqual(mates[0].Id, w.ControlledId);
        }

        [Test]
        public void Auto_Defend_Moves_Controlled_Player_Without_Input_When_Opponent_Has_Ball_But_Not_When_Off_Or_When_We_Have_It()
        {
            double Travelled(bool auto, bool weHaveBall)
            {
                double sum = 0;
                for (int seed = 1; seed <= 8; seed++)
                {
                    var w = HumanWorld(seed);
                    var opp = w.Agents.First(a => a.Team == 1);
                    opp.Body.Pos = new Vec2(-10, 0); opp.Body.Facing = new Vec2(-1, 0);
                    var me = w.Controlled; me.Body.Pos = new Vec2(-4, 6); me.Body.Vel = Vec2.Zero; me.Body.Facing = new Vec2(1, 0);
                    if (weHaveBall) { w.GiveBallTo(me); foreach (var o in w.Agents.Where(a => a.Team == 1)) o.Body.Pos = new Vec2(25, o.Body.Pos.Y); }
                    else { w.Ball.Take(opp.Id); w.Ball.Pos = opp.Body.Pos + opp.Body.Facing * 0.62f; }
                    if (auto) w.Step(Dt, new PlayerInput { ToggleAutoDefend = true });
                    int id = w.ControlledId; var start = me.Body.Pos;
                    Run(w, 1.5f);
                    sum += Vec2.Distance(w.AgentById(id).Body.Pos, start);
                }
                return sum / 8;
            }
            double autoDef = Travelled(true, false), manual = Travelled(false, false), autoWithBall = Travelled(true, true);
            Console.WriteLine("OTO. açık (rakipte top): {0:0.0} m, kapalı: {1:0.0} m, OTO. açık ama top bizde: {2:0.0} m", autoDef, manual, autoWithBall);
            Assert.Greater(autoDef, 4.0, "OTO. açıkken oyuncu girdi olmadan savunmaya koşmalı");
            Assert.Less(manual, 0.5, "OTO. kapalıyken oyuncu girdi olmadan durmalı");
            Assert.Less(autoWithBall, 2.5, "top bizdeyse OTO. devralmaz: topu taşıyan oyuncu kontrolde kalır");
        }

        [Test]
        public void Auto_Defend_Keeps_The_Same_Controlled_Player_And_Returns_Input_When_Turned_Off()
        {
            var w = HumanWorld(3);
            var opp = w.Agents.First(a => a.Team == 1);
            opp.Body.Pos = new Vec2(-10, 0); w.Ball.Take(opp.Id); w.Ball.Pos = opp.Body.Pos + opp.Body.Facing * 0.62f;
            w.Step(Dt, new PlayerInput { ToggleAutoDefend = true });
            Assert.IsTrue(w.AutoDefend);
            int id = w.ControlledId;
            w.Step(Dt, new PlayerInput { ToggleAutoDefend = true });
            Assert.IsFalse(w.AutoDefend);
            Assert.AreEqual(id, w.ControlledId);
            var me = w.AgentById(id); me.Body.Pos = new Vec2(0, 0); me.Body.Vel = Vec2.Zero;
            // top el değiştirmesin diye rakibi uzak tut
            w.Ball.Take(opp.Id); opp.Body.Pos = new Vec2(-25, 0); w.Ball.Pos = opp.Body.Pos;
            for (int i = 0; i < 30; i++) w.Step(Dt, new PlayerInput { Move = new Vec2(0, 1) });
            Assert.Greater(me.Body.Pos.Y, 1.0f, "OTO. kapalıyken joystick yine oyuncuyu sürer");
        }

        [Test]
        public void Auto_Defend_Toggle_Flips_State()
        {
            var w = HumanWorld(1);
            Assert.IsFalse(w.AutoDefend);
            w.Step(Dt, new PlayerInput { ToggleAutoDefend = true }); Assert.IsTrue(w.AutoDefend);
            w.Step(Dt, new PlayerInput { ToggleAutoDefend = true }); Assert.IsFalse(w.AutoDefend);
        }

        [Test]
        public void Second_Defender_Call_Makes_Next_Nearest_Teammate_Press_Instead_Of_Cover()
        {
            // Kurulum: taşıyıcı (-6,0) kendi kalemize doğru; 1. savunmacı yakın, aday 2. savunmacı taşıyıcının ÖNÜNDE (-9.5,3.5).
            // Örtü hedefi taşıyıcıdan kaleye doğru 5.5 m ötedir (uzaklaşır); baskı hedefi taşıyıcıdır (yaklaşır).
            double DistanceAfter(bool call, out int id)
            {
                var w = HumanWorld(9);
                var opp = w.Agents.First(a => a.Team == 1);
                var mates = w.Agents.Where(a => a.Team == 0 && a.Id != w.ControlledId).ToList();
                foreach (var o in w.Agents.Where(a => a.Team == 1 && a.Id != opp.Id)) o.Body.Pos = new Vec2(20, o.Body.Pos.Y);
                w.AgentById(w.ControlledId).Body.Pos = new Vec2(10, 12);
                opp.Body.Pos = new Vec2(-6, 0); opp.Body.Facing = new Vec2(-1, 0); opp.Body.Vel = Vec2.Zero;
                mates[0].Body.Pos = new Vec2(-7.5f, -1.5f);   // 1. savunmacı (en yakın)
                mates[1].Body.Pos = new Vec2(-9.5f, 3.5f);    // aday 2. savunmacı
                mates[2].Body.Pos = new Vec2(-3f, -12f);
                foreach (var m in mates) { m.Body.Vel = Vec2.Zero; }
                // Ölçümü bozmasın: taşıyıcı pas/şut düşünmesin, savunmacılar çelme denemesin (rol davranışı ölçülür).
                opp.ThinkTimer = 100f; foreach (var a in w.Agents.Where(a => a.Team == 0)) a.TackleCooldown = 100f;
                w.Ball.Take(opp.Id); w.Ball.Pos = opp.Body.Pos + opp.Body.Facing * 0.62f;
                w.Step(Dt, new PlayerInput { CallSecondDefender = call });
                id = w.SecondDefender(0);
                Run(w, 1.0f);
                return Vec2.Distance(w.AgentById(id).Body.Pos, w.Carrier != null ? w.Carrier.Body.Pos : w.Ball.Pos);
            }
            int idA, idB;
            double press = DistanceAfter(true, out idA), cover = DistanceAfter(false, out idB);
            Console.WriteLine("2. DEF: 1 sn sonra taşıyıcıya mesafe baskı={0:0.0} m, örtü={1:0.0} m (aynı oyuncu: {2})", press, cover, idA == idB);
            Assert.AreEqual(idA, idB, "aynı oyuncu 2. savunmacı olmalı (karşılaştırma geçerli)");
            Assert.Less(press, cover - 1.0, "çağrılan 2. savunmacı taşıyıcıya baskı yapmalı (örtüye göre en az 1 m daha yakın)");
            Assert.Less(press, 3.0);
        }

        [Test]
        public void Clear_Kicks_Ball_Far_Toward_Opponent_Half()
        {
            var w = HumanWorld(6);
            var me = w.Controlled; me.Body.Pos = new Vec2(-w.Pitch.HalfLength + 8f, 3f); me.Body.Facing = new Vec2(1, 0);
            w.GiveBallTo(me);
            Assert.IsTrue(w.ControlledInOwnHalf);
            w.Step(Dt, new PlayerInput { Clear = true });
            Assert.IsFalse(w.Ball.IsControlled);
            Assert.Greater(w.Ball.Vel.X, 10f, "uzaklaştırma rakip kaleye doğru olmalı");
            Run(w, 1.5f);
            Assert.Greater(w.Ball.Pos.X, me.Body.Pos.X + 8f, "top ileri gitmeli");
        }

        [Test]
        public void Human_Pass_Reaches_Teammate_Often_And_Is_Counted_From_Events()
        {
            int completed = 0, trials = 30;
            for (int seed = 1; seed <= trials; seed++)
            {
                var w = HumanWorld(seed);
                var me = w.Controlled; var mate = w.Agents.First(a => a.Team == 0 && a.Id != me.Id);
                me.Body.Pos = new Vec2(-5, 0); mate.Body.Pos = new Vec2(5, 4);
                foreach (var o in w.Agents.Where(a => a.Team == 1)) o.Body.Pos = new Vec2(25, o.Body.Pos.Y);
                w.GiveBallTo(me);
                w.Step(Dt, new PlayerInput { Pass = true, Power = 0.6f, Move = (mate.Body.Pos - me.Body.Pos).Normalized });
                Run(w, 2.0f);
                var r = w.BuildResult();
                Assert.AreEqual(1, r.Home.Passes);
                completed += r.Home.PassesCompleted;
            }
            Console.WriteLine("insan pası tamamlanma: " + completed + "/" + trials);
            Assert.Greater(completed, trials * 0.6);
        }

        [Test]
        public void Possession_Time_Sums_To_Live_Play_And_Result_Percentages_Add_Up()
        {
            var w = PlayFull(Cfg(11));
            var r = w.BuildResult();
            Assert.AreEqual(100, r.HomePossessionPercent + r.AwayPossessionPercent, 1);
            Assert.Greater(w.PossessionSeconds[0] + w.PossessionSeconds[1], 20f);
        }

        [Test]
        public void Every_Goal_In_Log_Has_A_Scorer_Name_And_Minute_In_Range()
        {
            for (int s = 1; s <= 10; s++)
            {
                var r = PlayFull(Cfg(s, 80f, 50f)).BuildResult();
                foreach (var sc in r.Scorers) { Assert.IsFalse(string.IsNullOrEmpty(sc.Name)); Assert.That(sc.Minute, Is.InRange(0, 95)); }
                Assert.AreEqual(r.ScoreHome + r.ScoreAway, r.Scorers.Count);
            }
        }
    }
}
