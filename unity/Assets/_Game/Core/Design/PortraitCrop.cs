using System;

namespace Fenerbahce.Core.Design
{
    /// <summary>
    /// Portre kırpımı (T019): kare kaynak görseli, odak noktasını (focalX/Y, 0-1) koruyarak hedef kutuya (en/boy oranı) sığdırır.
    /// Sonuç, RawImage.uvRect değerleridir (x, y, w, h; 0-1, alt-sol orijin). Yanlış kırpım (yüz kesilmesi) engellenir.
    /// </summary>
    public static class PortraitCrop
    {
        public struct Uv { public float X, Y, W, H; }

        public static Uv Compute(float boxAspect, float focalX, float focalY)
        {
            if (boxAspect <= 0f) throw new ArgumentOutOfRangeException("boxAspect");
            float fx = Clamp01(focalX), fy = Clamp01(focalY);
            float w = 1f, h = 1f;
            if (boxAspect > 1f) h = 1f / boxAspect;      // kutu geniş: dikeyde kırp
            else if (boxAspect < 1f) w = boxAspect;      // kutu dar: yatayda kırp
            // Odak noktası kırpım penceresinin ortasına gelsin ama pencere görselin dışına taşmasın.
            float x = Clamp(fx - w / 2f, 0f, 1f - w);
            // focalY görselin ÜSTÜNDEN ölçülür (0 = üst); uv alt-sol orijinlidir.
            float yTop = Clamp(fy - h / 2f, 0f, 1f - h);
            float y = 1f - h - yTop;
            return new Uv { X = x, Y = y, W = w, H = h };
        }

        static float Clamp01(float v) { return v < 0f ? 0f : (v > 1f ? 1f : v); }
        static float Clamp(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
    }
}
