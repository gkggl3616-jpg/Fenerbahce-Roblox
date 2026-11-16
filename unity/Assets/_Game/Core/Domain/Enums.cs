using System;

namespace Fenerbahce.Core.Domain
{
    /// <summary>Maç slotu / oyuncu mevkisi. Katalog grubundan (PositionGroup) ayrıdır.</summary>
    public enum Position { GK, CB, LB, RB, CDM, CM, CAM, LM, RM, LW, RW, ST }

    public enum PositionGroup { GK, DEF, MID, ATT }

    public enum PreferredFoot { Right, Left }

    /// <summary>Nadirlik; GEN ve etkinlik programı ile bağımsız alanlardır (T020).</summary>
    public enum Rarity { Base, Special, Legend }

    public static class PositionInfo
    {
        public static PositionGroup GroupOf(Position p)
        {
            switch (p)
            {
                case Position.GK: return PositionGroup.GK;
                case Position.CB:
                case Position.LB:
                case Position.RB: return PositionGroup.DEF;
                case Position.CDM:
                case Position.CM:
                case Position.CAM:
                case Position.LM:
                case Position.RM: return PositionGroup.MID;
                default: return PositionGroup.ATT;
            }
        }

        /// <summary>Kart/UI için Türkçe kısaltma. Kısaltmalar uluslararası olduğu için aynı kalır.</summary>
        public static string Label(Position p) { return p.ToString(); }
    }
}
