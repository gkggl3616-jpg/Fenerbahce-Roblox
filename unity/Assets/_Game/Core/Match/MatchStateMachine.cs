using System;
using System.Collections.Generic;

namespace Fenerbahce.Core.Match
{
    /// <summary>Hazırlık → Giriş → Santra → Canlı → (Duran top/Devre) → Canlı → Bitiş → Sonuç. Gol/kutlama/tekrar canlı kontrolden ayrı durumlardır.</summary>
    public enum MatchPhase { Preparation, Intro, Kickoff, Live, SetPiece, GoalCelebration, Replay, HalfTime, FullTime, Result }

    public class MatchStateMachine
    {
        public MatchPhase Phase { get; private set; } = MatchPhase.Preparation;
        public int Half { get; private set; } = 1;
        public int Halves { get; private set; }
        public float HalfLengthSeconds { get; private set; }
        public float ElapsedInHalf { get; private set; }
        /// <summary>Uzatma (eklenen) süre, saniye. Devre/maç, HalfLength+Stoppage dolunca biter. Referansta '+2' göstergesi görüldü.</summary>
        public float StoppageSeconds { get; set; }
        public float PeriodEnd { get { return HalfLengthSeconds + StoppageSeconds; } }
        public float PhaseTimer { get; private set; }
        public int ScoreHome { get; private set; }
        public int ScoreAway { get; private set; }
        public int GoalsRegistered { get; private set; }

        public const float KickoffDelay = 1.2f;
        public const float CelebrationSeconds = 2.5f;
        public const float ReplaySeconds = 3.0f;

        static readonly Dictionary<MatchPhase, MatchPhase[]> Allowed = new Dictionary<MatchPhase, MatchPhase[]>
        {
            { MatchPhase.Preparation, new[] { MatchPhase.Intro, MatchPhase.Kickoff } },
            { MatchPhase.Intro, new[] { MatchPhase.Kickoff } },
            { MatchPhase.Kickoff, new[] { MatchPhase.Live } },
            { MatchPhase.Live, new[] { MatchPhase.SetPiece, MatchPhase.GoalCelebration, MatchPhase.HalfTime, MatchPhase.FullTime } },
            { MatchPhase.SetPiece, new[] { MatchPhase.Live } },
            { MatchPhase.GoalCelebration, new[] { MatchPhase.Replay, MatchPhase.Kickoff, MatchPhase.HalfTime, MatchPhase.FullTime } },
            { MatchPhase.Replay, new[] { MatchPhase.Kickoff, MatchPhase.HalfTime, MatchPhase.FullTime } },
            { MatchPhase.HalfTime, new[] { MatchPhase.Kickoff } },
            { MatchPhase.FullTime, new[] { MatchPhase.Result } },
            { MatchPhase.Result, new MatchPhase[0] },
        };

        public event Action<MatchPhase, MatchPhase> PhaseChanged;

        public MatchStateMachine(float halfLengthSeconds, int halves = 2)
        {
            if (halfLengthSeconds <= 0) throw new ArgumentOutOfRangeException("halfLengthSeconds");
            if (halves < 1 || halves > 2) throw new ArgumentOutOfRangeException("halves");
            HalfLengthSeconds = halfLengthSeconds; Halves = halves;
        }

        /// <summary>Oyuncunun maçı canlı olarak kontrol edebildiği tek durum.</summary>
        public bool IsControlEnabled { get { return Phase == MatchPhase.Live; } }
        public bool ClockRunning { get { return Phase == MatchPhase.Live; } }
        public bool IsFinished { get { return Phase == MatchPhase.FullTime || Phase == MatchPhase.Result; } }

        public bool CanTransition(MatchPhase to)
        {
            return Array.IndexOf(Allowed[Phase], to) >= 0;
        }

        public void TransitionTo(MatchPhase to)
        {
            if (!CanTransition(to)) throw new InvalidOperationException("Geçersiz maç durumu geçişi: " + Phase + " → " + to);
            var from = Phase; Phase = to; PhaseTimer = 0f;
            if (PhaseChanged != null) PhaseChanged(from, to);
        }

        /// <summary>Maçı başlatır. skipIntro=true ise giriş sunumu atlanır (atlanabilir sunum, T046).</summary>
        public void Begin(bool skipIntro)
        {
            if (Phase != MatchPhase.Preparation) throw new InvalidOperationException("Maç zaten başladı");
            TransitionTo(skipIntro ? MatchPhase.Kickoff : MatchPhase.Intro);
        }

        public void SkipIntro() { if (Phase == MatchPhase.Intro) TransitionTo(MatchPhase.Kickoff); }
        public void SkipReplay() { if (Phase == MatchPhase.Replay) AfterGoalSequence(); }

        public void BeginSetPiece() { if (Phase == MatchPhase.Live) TransitionTo(MatchPhase.SetPiece); }
        public void EndSetPiece() { if (Phase == MatchPhase.SetPiece) TransitionTo(MatchPhase.Live); }

        /// <summary>
        /// Gol kaydı. YALNIZ canlı oyunda kabul edilir; kutlama/tekrar sırasında gelen ikinci çağrı reddedilir (gol bir kez yazılır).
        /// </summary>
        public bool RegisterGoal(bool home)
        {
            if (Phase != MatchPhase.Live) return false;
            if (home) ScoreHome++; else ScoreAway++;
            GoalsRegistered++;
            TransitionTo(MatchPhase.GoalCelebration);
            return true;
        }

        /// <summary>Saati ve geçici durumları ilerletir.</summary>
        public void Tick(float dt)
        {
            PhaseTimer += dt;
            switch (Phase)
            {
                case MatchPhase.Kickoff:
                    if (PhaseTimer >= KickoffDelay) TransitionTo(MatchPhase.Live);
                    break;
                case MatchPhase.Live:
                    ElapsedInHalf += dt;
                    if (ElapsedInHalf >= PeriodEnd)
                    {
                        ElapsedInHalf = PeriodEnd;
                        TransitionTo(Half >= Halves ? MatchPhase.FullTime : MatchPhase.HalfTime);
                    }
                    break;
                case MatchPhase.GoalCelebration:
                    if (PhaseTimer >= CelebrationSeconds) TransitionTo(MatchPhase.Replay);
                    break;
                case MatchPhase.Replay:
                    if (PhaseTimer >= ReplaySeconds) AfterGoalSequence();
                    break;
            }
        }

        /// <summary>Devre arası bittiğinde ikinci yarıyı başlatır.</summary>
        public void StartSecondHalf()
        {
            if (Phase != MatchPhase.HalfTime) throw new InvalidOperationException("Devre arasında değil");
            Half++; ElapsedInHalf = 0f; TransitionTo(MatchPhase.Kickoff);
        }

        public void ShowResult() { if (Phase == MatchPhase.FullTime) TransitionTo(MatchPhase.Result); }

        void AfterGoalSequence()
        {
            if (ElapsedInHalf >= PeriodEnd) TransitionTo(Half >= Halves ? MatchPhase.FullTime : MatchPhase.HalfTime);
            else TransitionTo(MatchPhase.Kickoff);
        }

        /// <summary>Ekranda gösterilen maç dakikası (0-90). Gerçek süre ölçeklenir; uzatmada devre sonu dakikasında kalır.</summary>
        public int DisplayMinute
        {
            get
            {
                float perHalf = 90f / Halves;
                float frac = Math.Min(1f, ElapsedInHalf / HalfLengthSeconds);
                return (int)(((Half - 1) * perHalf) + frac * perHalf);
            }
        }

        /// <summary>Uzatma göstergesi ("+2"): devre süresi aşıldıysa aşan oyun dakikası, aksi halde 0.</summary>
        public int DisplayAddedMinutes
        {
            get
            {
                if (ElapsedInHalf <= HalfLengthSeconds) return 0;
                float perHalf = 90f / Halves;
                return (int)Math.Ceiling((ElapsedInHalf - HalfLengthSeconds) / HalfLengthSeconds * perHalf);
            }
        }
    }
}
