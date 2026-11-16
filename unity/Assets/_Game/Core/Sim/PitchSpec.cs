namespace Fenerbahce.Core.Sim
{
    /// <summary>Saha ölçüleri (metre). Merkez (0,0). Rakip kale +X ucunda.</summary>
    public class PitchSpec
    {
        public float HalfLength = 52.5f;
        public float HalfWidth = 34f;
        public float GoalHalfWidth = 3.66f;
        public float GoalHeight = 2.44f;
        public float GoalDepth = 2.4f;
        public float PostRadius = 0.06f;
        public float PenaltyAreaDepth = 16.5f;
        public float PenaltyAreaHalfWidth = 20.16f;
        public float PenaltySpotDistance = 11f;
    }

    /// <summary>Top fiziği sabitleri ve yardımcıları. Tüm değerler PROTOTİP'tir; T033 cihaz ölçümüyle ayarlanır.</summary>
    public static class BallPhysics
    {
        public const float Gravity = 9.81f;
        public const float RollDecelConst = 1.4f;
        public const float RollDecelProp = 0.45f;
        public const float AirDrag = 0.06f;
        public const float Restitution = 0.55f;
        public const float Radius = 0.11f;

        /// <summary>v0 hızıyla yerde yuvarlanan topun duruncaya kadar aldığı yol (m). v' = -(a + k v) çözümü.</summary>
        public static float RollDistance(float v0)
        {
            if (v0 <= 0) return 0;
            float c = RollDecelConst / RollDecelProp;
            float tStop = (float)System.Math.Log((v0 + c) / c) / RollDecelProp;
            float k = RollDecelProp;
            return (v0 + c) / k * (1f - c / (v0 + c)) - c * tStop;
        }

        /// <summary>Verilen mesafeyi yuvarlanarak alacak başlangıç hızı (ikili arama).</summary>
        public static float SpeedForDistance(float dist, float maxSpeed)
        {
            float lo = 0, hi = maxSpeed;
            if (RollDistance(hi) <= dist) return hi;
            for (int i = 0; i < 24; i++)
            {
                float mid = (lo + hi) * 0.5f;
                if (RollDistance(mid) < dist) lo = mid; else hi = mid;
            }
            return hi;
        }
    }
}
