using System;
using System.Collections.Generic;

namespace Fenerbahce.Core.Sim
{
    /// <summary>Pas hedefi seçimi (T024): yön konisi içindeki adaylardan en iyi puanlıyı seçer.</summary>
    public static class PassTargeting
    {
        public const float MaxAngleDeg = 50f;
        public const float MaxDistance = 55f;

        /// <returns>Aday indeksi veya -1.</returns>
        public static int Pick(Vec2 origin, Vec2 aimDir, IList<Vec2> candidates, float maxAngleDeg = MaxAngleDeg, float maxDist = MaxDistance)
        {
            if (aimDir.SqrLength < 1e-6f) return -1;
            int best = -1; float bestScore = float.MaxValue;
            for (int i = 0; i < candidates.Count; i++)
            {
                var rel = candidates[i] - origin;
                float d = rel.Length;
                if (d < 2f || d > maxDist) continue;
                float ang = Math.Abs(Vec2.SignedAngleDeg(aimDir, rel));
                if (ang > maxAngleDeg) continue;
                float score = ang + d * 0.15f;
                if (score < bestScore) { bestScore = score; best = i; }
            }
            return best;
        }
    }
}
