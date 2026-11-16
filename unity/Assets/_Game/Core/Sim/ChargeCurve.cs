using System;

namespace Fenerbahce.Core.Sim
{
    /// <summary>
    /// Düğmeye basılı tutma süresinden pas/şut gücü (0..1). Eğri ve süre PROTOTİP değerleridir;
    /// kesin hissi gerçek cihaz denemesiyle ayarlanır (T033). Videodan alınmış değer DEĞİLDİR.
    /// </summary>
    public static class ChargeCurve
    {
        public const float FullChargeSeconds = 0.8f;
        public const float MinPower = 0.15f;

        public static float Power(float holdSeconds)
        {
            if (holdSeconds <= 0f) return MinPower;
            float t = Math.Min(1f, holdSeconds / FullChargeSeconds);
            // Başta yavaş, sonda hızlı: kısa dokunuş hassas, uzun basış tam güç.
            float eased = t * t * (3f - 2f * t);
            return MinPower + (1f - MinPower) * eased;
        }
    }
}
