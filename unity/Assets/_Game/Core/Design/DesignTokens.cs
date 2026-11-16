using System;

namespace Fenerbahce.Core.Design
{
    /// <summary>
    /// Sarı-lacivert tasarım token'ları (T008) — TEK KAYNAK. Renk/boşluk/yazı boyutu yalnızca buradan değişir.
    /// Bu değerler proje önerisidir; Fenerbahçe'nin resmî marka renk kodları DEĞİLDİR.
    /// </summary>
    public static class DesignTokens
    {
        // Çekirdek palet (öneri)
        public const string Navy = "#071B3A";
        public const string Yellow = "#FFD600";
        public const string TextLight = "#F5F7FA";
        public const string Surface = "#101E36";

        // Türevler
        public const string NavyLight = "#0E2A57";
        public const string SurfaceRaised = "#17294A";
        public const string YellowPressed = "#D9B500";
        public const string TextMuted = "#9FB0CC";
        public const string Success = "#2FBF71";
        public const string Danger = "#E5484D";
        public const string Locked = "#5B6B85";
        public const string Pitch = "#2E7D32";

        // Nadirlik çerçeveleri (T020): çerçeve portreden bağımsız değişir.
        public const string FrameBase = "#C9D3E3";
        public const string FrameSpecial = "#FFD600";
        public const string FrameLegend = "#FF9F1C";

        // Boşluk / boyut (referans çözünürlük 1920×1080 birimleri)
        public const int Space1 = 4, Space2 = 8, Space3 = 12, Space4 = 16, Space5 = 24, Space6 = 32;
        public const int Radius = 14;
        public const int MinTouchTarget = 64;
        public const int SafeMargin = 32;

        // Yazı boyutları
        public const int FontCaption = 20, FontBody = 26, FontTitle = 38, FontDisplay = 64, FontButton = 30;

        public static readonly int[] ReferenceResolution = { 1920, 1080 };

        public static float[] ParseHex(string hex)
        {
            if (hex == null || hex.Length != 7 || hex[0] != '#') throw new FormatException("Geçersiz renk: " + hex);
            return new[]
            {
                Convert.ToInt32(hex.Substring(1, 2), 16) / 255f,
                Convert.ToInt32(hex.Substring(3, 2), 16) / 255f,
                Convert.ToInt32(hex.Substring(5, 2), 16) / 255f,
            };
        }

        public static string[] AllColors
        {
            get
            {
                return new[] { Navy, Yellow, TextLight, Surface, NavyLight, SurfaceRaised, YellowPressed, TextMuted, Success, Danger, Locked, Pitch, FrameBase, FrameSpecial, FrameLegend };
            }
        }
    }

    /// <summary>WCAG tabanlı kontrast denetimi: sarı metin sarı zeminde kaybolmaz.</summary>
    public static class Contrast
    {
        public static double Luminance(string hex)
        {
            var c = DesignTokens.ParseHex(hex);
            Func<float, double> lin = v => v <= 0.03928f ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4);
            return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
        }

        public static double Ratio(string a, string b)
        {
            double la = Luminance(a), lb = Luminance(b);
            double hi = Math.Max(la, lb), lo = Math.Min(la, lb);
            return (hi + 0.05) / (lo + 0.05);
        }

        /// <summary>Verilen zemin üzerinde okunur metin rengi (lacivert veya açık yazı).</summary>
        public static string TextOn(string backgroundHex)
        {
            return Ratio(DesignTokens.Navy, backgroundHex) >= Ratio(DesignTokens.TextLight, backgroundHex) ? DesignTokens.Navy : DesignTokens.TextLight;
        }
    }
}
