using System;
using System.Globalization;

namespace Fenerbahce.Core.Design
{
    /// <summary>
    /// Türkçe sayı/süre biçimleri. Biçim kuralları referans karelerden GÖZLENMİŞTİR (docs/EKRAN_SPESIFIKASYONU.md §0):
    /// binlik ayraç nokta; B = bin, Mln = milyon, ondalık virgül; süre HH:MM:SS (saat 24'ü aşabilir), uzun sürede "N GÜN".
    /// </summary>
    public static class NumberFormat
    {
        static readonly CultureInfo Tr = new CultureInfo("tr-TR");
        static readonly NumberFormatInfo Nfi = BuildNfi();

        static NumberFormatInfo BuildNfi()
        {
            // Kültür verisi olmayan platformlarda (invariant globalization) bile aynı çıktı için elle ayarlanır.
            var n = (NumberFormatInfo)Tr.NumberFormat.Clone();
            n.NumberGroupSeparator = "."; n.NumberDecimalSeparator = ","; n.NumberGroupSizes = new[] { 3 };
            return n;
        }

        /// <summary>1329300000 → "1.329.300.000"</summary>
        public static string Full(long v)
        {
            return v.ToString("N0", Nfi);
        }

        /// <summary>
        /// Kısa biçim: &lt;1.000 olduğu gibi; ≥1.000 "408,6B"; ≥1.000.000 "2,491Mln"; ≥1.000.000.000 "1,5Mlr".
        /// Not: Referanstaki "Mlr" gözlenmedi; milyar için tasarım varsayımıdır.
        /// </summary>
        public static string Compact(long v)
        {
            long a = Math.Abs(v); string sign = v < 0 ? "-" : "";
            if (a < 1000) return v.ToString(CultureInfo.InvariantCulture);
            if (a < 1000000) return sign + Trim((a / 1000.0).ToString("0.0", Nfi)) + "B";
            if (a < 1000000000) return sign + Trim((a / 1000000.0).ToString("0.###", Nfi)) + "Mln";
            return sign + Trim((a / 1000000000.0).ToString("0.###", Nfi)) + "Mlr";
        }

        static string Trim(string s)
        {
            // "408,0" → "408"? Referans "15,0B" gösteriyor: tek ondalık korunur (B için). Mln/Mlr'de sondaki sıfırlar atılır.
            return s;
        }
    }

    public static class TimeFormat
    {
        public const double DayModeThresholdHours = 48.0;

        /// <summary>
        /// Kalan süre: 48 saatten az → "HH:MM:SS" (saat 24'ü aşabilir, örn. "25:44:04");
        /// 48 saat ve üstü → "N GÜN" (tam gün, aşağı yuvarlanır). Eşik tasarım varsayımıdır (referansta 36 saatlik ve 3 günlük değerler görüldü).
        /// </summary>
        public static string Remaining(TimeSpan t)
        {
            if (t < TimeSpan.Zero) t = TimeSpan.Zero;
            if (t.TotalHours >= DayModeThresholdHours) return ((int)t.TotalDays) + " GÜN";
            int h = (int)t.TotalHours;
            return h.ToString("00", CultureInfo.InvariantCulture) + ":" + t.Minutes.ToString("00", CultureInfo.InvariantCulture) + ":" + t.Seconds.ToString("00", CultureInfo.InvariantCulture);
        }
    }
}
