using Fenerbahce.Core.Domain;

namespace Fenerbahce.Core.Squad
{
    public enum Fit { Exact, Alternate, OutOfPosition, Invalid }

    /// <summary>Mevki uygunluğu (G09/T035). Kural: birincil/alternatif = geçerli; aynı grup = pozisyon dışı (ceza); farklı grup = geçersiz.</summary>
    public static class PositionFit
    {
        /// <summary>Pozisyon dışı oynayan kartın GEN cezası. PROTOTİP değeri — denge testinde ayarlanır.</summary>
        public const int OutOfPositionPenalty = 6;

        public static Fit Evaluate(Position slot, PlayerDefinition p)
        {
            if (p.PrimaryPosition == slot) return Fit.Exact;
            if (p.AlternatePositions != null && p.AlternatePositions.Contains(slot)) return Fit.Alternate;
            if (slot == Position.GK || p.PrimaryPosition == Position.GK) return Fit.Invalid;
            if (PositionInfo.GroupOf(slot) == p.PositionGroup) return Fit.OutOfPosition;
            return Fit.Invalid;
        }

        public static bool IsValid(Fit f) { return f != Fit.Invalid; }

        public static int EffectiveOverall(int cardOverall, Fit f)
        {
            return f == Fit.OutOfPosition ? cardOverall - OutOfPositionPenalty : cardOverall;
        }
    }
}
