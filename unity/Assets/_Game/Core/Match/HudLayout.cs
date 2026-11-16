using System.Collections.Generic;

namespace Fenerbahce.Core.Match
{
    public enum BallOwnership { Ours, Theirs, Loose }

    /// <summary>
    /// Maç HUD düğmeleri — referans kare galerisine göre (G35–G37, V01 06:12–11:20):
    /// Hücum: ŞUT (kendi yarı sahada UZAKLAŞTIR), ARA, PAS, büyük "SPRİNT VE BECERİ".
    /// Savunma: DEĞİŞTİR, 2. DEF, KAY, büyük "SPRİNT VE MÜDAHALE" ve solda OTO. (otomatik savunma).
    /// </summary>
    public enum HudButton { Pass, ThroughPass, Shoot, Clear, SprintSkill, Slide, SecondDefender, Switch, SprintTackle, AutoDefend }

    /// <summary>Sahipliğe göre değişen HUD düğme kümesi (T027). Canlı olmayan durumlarda kontrol kapalıdır.</summary>
    public static class HudLayout
    {
        /// <param name="inOwnHalf">Kontrol edilen oyuncu kendi yarı sahasındaysa hücumda ŞUT yerine UZAKLAŞTIR çıkar (G37).</param>
        /// <param name="multiPlayer">false = tek oyunculu kontrol sahası: DEĞİŞTİR/2. DEF/OTO. yok.</param>
        public static IReadOnlyList<HudButton> ButtonsFor(BallOwnership o, MatchPhase phase, bool inOwnHalf = false, bool multiPlayer = true)
        {
            if (phase != MatchPhase.Live) return None;
            if (o == BallOwnership.Ours) return inOwnHalf ? AttackOwnHalf : Attack;
            return multiPlayer ? Defend : DefendSolo;
        }

        static readonly HudButton[] None = new HudButton[0];
        static readonly HudButton[] Attack = { HudButton.Pass, HudButton.ThroughPass, HudButton.Shoot, HudButton.SprintSkill };
        static readonly HudButton[] AttackOwnHalf = { HudButton.Pass, HudButton.ThroughPass, HudButton.Clear, HudButton.SprintSkill };
        static readonly HudButton[] Defend = { HudButton.Switch, HudButton.SecondDefender, HudButton.Slide, HudButton.SprintTackle, HudButton.AutoDefend };
        static readonly HudButton[] DefendSolo = { HudButton.Slide, HudButton.SprintTackle };

        public static string Label(HudButton b, BallOwnership o)
        {
            switch (b)
            {
                case HudButton.Pass: return "PAS";
                case HudButton.ThroughPass: return "ARA";
                case HudButton.Shoot: return "ŞUT";
                case HudButton.Clear: return "UZAKLAŞTIR";
                case HudButton.SprintSkill: return "SPRİNT\nVE BECERİ";
                case HudButton.SecondDefender: return "2. DEF";
                case HudButton.Switch: return "DEĞİŞTİR";
                case HudButton.SprintTackle: return "SPRİNT\nVE MÜDAHALE";
                case HudButton.AutoDefend: return "OTO.";
                default: return "KAY";
            }
        }
    }
}
