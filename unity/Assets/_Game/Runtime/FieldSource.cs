using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Match;
using Fenerbahce.Core.Sim;

namespace Fenerbahce.Runtime
{
    public enum DotKind { Controlled, Mate, Opponent, KeeperHome, KeeperAway, Ball, Target }
    public struct MiniDot { public Vec2 Pos; public DotKind Kind; }

    /// <summary>
    /// Sahada oynanan simülasyonun Runtime katmanına açılan ortak yüzü: tek futbolcu kontrol sahası (ControlField)
    /// veya iki takımlı maç (MatchWorld). Çizim (FieldWorld) ve arayüz (FieldHud) yalnız bunu bilir.
    /// </summary>
    public abstract class FieldSource
    {
        public abstract PitchSpec Pitch { get; }
        public abstract MatchStateMachine Machine { get; }
        public abstract BallBody Ball { get; }
        public abstract BallOwnership Ownership { get; }
        public abstract IReadOnlyList<HudButton> Buttons { get; }
        public abstract IReadOnlyList<PlayerBody> Bodies { get; }
        /// <summary>0 = ev sahibi (bizim), 1 = rakip.</summary>
        public abstract IReadOnlyList<int> BodyTeams { get; }
        public abstract int ControlledIndex { get; }
        public abstract IReadOnlyList<GoalkeeperAI> Keepers { get; }
        public abstract bool AutoDefend { get; }
        public abstract string HomeName { get; }
        public abstract string AwayName { get; }
        public abstract string ClockText { get; }
        public abstract string LastGoalText { get; }
        public abstract void Step(float dt, PlayerInput input);
        public abstract void DrainEvents(List<FieldEvent> into);
        public abstract MatchResult BuildResult();
        public abstract FieldStats StatsCopy();

        public virtual bool BodyActive(int i) { return true; }
        public virtual IReadOnlyList<Vec2> Targets { get { return NoTargets; } }
        public virtual float TargetRadius { get { return 0f; } }
        public virtual int SelectedTarget { get { return -1; } }
        public virtual float TargetFlash(int i) { return 0f; }

        static readonly Vec2[] NoTargets = new Vec2[0];

        public PlayerBody Controlled { get { int i = ControlledIndex; return i >= 0 && i < Bodies.Count ? Bodies[i] : null; } }
        public string ControlledName { get { var c = Controlled; return c == null ? "" : c.Stats.DisplayName; } }

        /// <summary>Mini harita noktaları (her karede yeniden doldurulur).</summary>
        public void FillDots(List<MiniDot> into)
        {
            into.Clear();
            for (int i = 0; i < Bodies.Count; i++)
            {
                if (!BodyActive(i)) continue;
                var kind = i == ControlledIndex ? DotKind.Controlled : (BodyTeams[i] == 0 ? DotKind.Mate : DotKind.Opponent);
                into.Add(new MiniDot { Pos = Bodies[i].Pos, Kind = kind });
            }
            foreach (var k in Keepers) into.Add(new MiniDot { Pos = k.Pos, Kind = k.Sign < 0 ? DotKind.KeeperHome : DotKind.KeeperAway });
            into.Add(new MiniDot { Pos = Ball.Pos, Kind = DotKind.Ball });
            foreach (var t in Targets) into.Add(new MiniDot { Pos = t, Kind = DotKind.Target });
        }
    }

    /// <summary>Tek futbolculu kontrol sahası (T023) için kaynak.</summary>
    public class ControlFieldSource : FieldSource
    {
        public readonly ControlField Sim;
        readonly PlayerBody[] _bodies; readonly int[] _teams = { 0, 1 }; readonly GoalkeeperAI[] _keepers;
        public ControlFieldSource(ControlField sim) { Sim = sim; _bodies = new[] { sim.Player, sim.Defender }; _keepers = new[] { sim.Keeper }; }

        public override PitchSpec Pitch { get { return Sim.Pitch; } }
        public override MatchStateMachine Machine { get { return Sim.Machine; } }
        public override BallBody Ball { get { return Sim.Ball; } }
        public override BallOwnership Ownership { get { return Sim.Ownership; } }
        public override IReadOnlyList<HudButton> Buttons { get { return Sim.Hud; } }
        public override IReadOnlyList<PlayerBody> Bodies { get { return _bodies; } }
        public override IReadOnlyList<int> BodyTeams { get { return _teams; } }
        public override int ControlledIndex { get { return 0; } }
        public override IReadOnlyList<GoalkeeperAI> Keepers { get { return _keepers; } }
        public override bool AutoDefend { get { return false; } }
        public override string HomeName { get { return "KANARYA"; } }
        public override string AwayName { get { return "RAKİP"; } }
        public override string ClockText { get { int rem = (int)Math.Ceiling(Sim.RemainingSeconds); return (rem / 60) + ":" + (rem % 60).ToString("00"); } }
        public override string LastGoalText { get { return Sim.Player.Stats.DisplayName + "  " + Sim.Machine.DisplayMinute + "'"; } }
        public override void Step(float dt, PlayerInput input) { Sim.Step(dt, input); }
        public override void DrainEvents(List<FieldEvent> into) { Sim.DrainEvents(into); }
        public override MatchResult BuildResult() { return Sim.BuildResult(); }
        public override bool BodyActive(int i) { return i == 0 || Sim.Config.DefenderEnabled; }
        public override IReadOnlyList<Vec2> Targets { get { return Sim.Config.PassTargets; } }
        public override float TargetRadius { get { return Sim.Config.PassTargetRadius; } }
        public override int SelectedTarget { get { return Sim.SelectedTarget; } }
        public override float TargetFlash(int i) { return Sim.TargetFlash[i]; }
        public override FieldStats StatsCopy()
        {
            var st = Sim.Stats;
            return new FieldStats { Goals = st.Goals, Shots = st.Shots, ShotsOnTarget = st.ShotsOnTarget, Saves = st.Saves, TargetPasses = st.TargetPasses, Passes = st.Passes, TacklesWon = st.TacklesWon, TacklesMissed = st.TacklesMissed, BallLosses = st.BallLosses, Skills = st.Skills };
        }
    }

    /// <summary>İki takımlı 5v5 maç (S1: T041/T026) için kaynak.</summary>
    public class MatchWorldSource : FieldSource
    {
        public readonly MatchWorld Sim;
        readonly List<PlayerBody> _bodies; readonly List<int> _teams;
        readonly string _home, _away;
        public MatchWorldSource(MatchWorld sim, string home, string away)
        {
            Sim = sim; _home = home; _away = away;
            _bodies = sim.Agents.Select(a => a.Body).ToList(); _teams = sim.Agents.Select(a => a.Team).ToList();
        }

        public override PitchSpec Pitch { get { return Sim.Pitch; } }
        public override MatchStateMachine Machine { get { return Sim.Machine; } }
        public override BallBody Ball { get { return Sim.Ball; } }
        public override BallOwnership Ownership { get { return Sim.Ownership; } }
        public override IReadOnlyList<HudButton> Buttons { get { return Sim.Hud; } }
        public override IReadOnlyList<PlayerBody> Bodies { get { return _bodies; } }
        public override IReadOnlyList<int> BodyTeams { get { return _teams; } }
        public override int ControlledIndex { get { int id = Sim.ControlledId; for (int i = 0; i < Sim.Agents.Count; i++) if (Sim.Agents[i].Id == id) return i; return -1; } }
        public override IReadOnlyList<GoalkeeperAI> Keepers { get { return Sim.Keepers; } }
        public override bool AutoDefend { get { return Sim.AutoDefend; } }
        public override string HomeName { get { return _home; } }
        public override string AwayName { get { return _away; } }
        public override string ClockText
        {
            get
            {
                var m = Sim.Machine; int added = m.DisplayAddedMinutes;
                return m.DisplayMinute + "'" + (added > 0 ? "+" + added : "");
            }
        }
        public override string LastGoalText { get { return Sim.LastGoalText; } }
        public override void Step(float dt, PlayerInput input) { Sim.Step(dt, input); }
        public override void DrainEvents(List<FieldEvent> into) { Sim.DrainEvents(into); }
        public override MatchResult BuildResult() { return Sim.BuildResult(); }
        public override FieldStats StatsCopy()
        {
            var r = Sim.BuildResult();
            // Hedefli pas yalnız kontrol sahasının kavramıdır; takım maçında 0 (ödül gol sayısından türetilir).
            return new FieldStats { Goals = r.ScoreHome, Shots = r.Home.Shots, ShotsOnTarget = r.Home.ShotsOnTarget, Saves = r.Home.Saves, TargetPasses = 0, Passes = r.Home.Passes };
        }
    }
}
