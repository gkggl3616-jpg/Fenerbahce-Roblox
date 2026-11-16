using System.Collections.Generic;
using Fenerbahce.Core.Match;

namespace Fenerbahce.Core.Sim
{
    /// <summary>Bir simülasyon adımı için oyuncu girdisi. Bir-seferlik bayraklar (Pass, Shoot...) adım sonunda tüketilir.</summary>
    public struct PlayerInput
    {
        public Vec2 Move;
        public bool Sprint;
        public bool Pass;
        public bool ThroughPass;
        public bool Shoot;
        /// <summary>Pas/şut için 0..1 güç (düğmeye basılı tutma süresinden istemci katmanı hesaplar).</summary>
        public float Power;
        /// <summary>-1 = sola, +1 = sağa, 0 = yok. Beceri düğmesi kaydırma yönü (Yön Değiştirme).</summary>
        public int SkillDirection;
        public bool Slide;
    }

    public enum FieldEventType
    {
        GoalScored, ShotOnTarget, ShotOffTarget, Save, PostHit, PassToTarget,
        TackleWon, TackleMissed, BallLost, BallRecovered, BallOut, SkillPerformed, PhaseChanged, SessionEnded, TackleSuffered
    }

    public struct FieldEvent
    {
        public FieldEventType Type;
        public float Time;
        public int Value;
        public Vec2 Pos;
        public override string ToString() { return Type + "@" + Time.ToString("0.00") + " v=" + Value; }
    }

    public class FieldStats
    {
        public int Goals, Shots, ShotsOnTarget, Saves, TargetPasses, Passes, TacklesWon, TacklesMissed, BallLosses, Skills;
    }

    public class ControlFieldConfig
    {
        public PitchSpec Pitch = new PitchSpec();
        /// <summary>Oturum süresi (gerçek saniye). 1 devre.</summary>
        public float SessionSeconds = 120f;
        public bool DefenderEnabled = true;
        /// <summary>0..1: savunmacının hız/isabet çarpanı. Prototip ayarı.</summary>
        public float DefenderLevel = 0.78f;
        public int Seed = 1;
        public List<Vec2> PassTargets = new List<Vec2>
        {
            new Vec2(24f, 20f), new Vec2(24f, -20f), new Vec2(36f, 0f),
        };
        public float PassTargetRadius = 2.5f;
    }
}
