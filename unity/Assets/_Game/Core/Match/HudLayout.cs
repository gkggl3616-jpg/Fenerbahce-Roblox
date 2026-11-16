using System.Collections.Generic;

namespace Fenerbahce.Core.Match
{
    public enum BallOwnership { Ours, Theirs, Loose }

    public enum HudButton { Pass, ThroughPass, Shoot, Sprint, Skill, Slide }

    /// <summary>Sahipliğe göre değişen HUD düğme kümesi (T027, G35–G37). Canlı olmayan durumlarda kontrol kapalıdır.</summary>
    public static class HudLayout
    {
        public static IReadOnlyList<HudButton> ButtonsFor(BallOwnership o, MatchPhase phase)
        {
            if (phase != MatchPhase.Live) return None;
            switch (o)
            {
                case BallOwnership.Ours: return Attack;
                default: return Defend;
            }
        }

        static readonly HudButton[] None = new HudButton[0];
        static readonly HudButton[] Attack = { HudButton.Pass, HudButton.ThroughPass, HudButton.Shoot, HudButton.Sprint, HudButton.Skill };
        static readonly HudButton[] Defend = { HudButton.Sprint, HudButton.Slide };

        public static string Label(HudButton b, BallOwnership o)
        {
            switch (b)
            {
                case HudButton.Pass: return "PAS";
                case HudButton.ThroughPass: return "ARA";
                case HudButton.Shoot: return "ŞUT";
                case HudButton.Sprint: return "SPRİNT";
                case HudButton.Skill: return "BECERİ";
                default: return o == BallOwnership.Loose ? "ATIL" : "KAY";
            }
        }
    }
}
