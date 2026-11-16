using System;

namespace Fenerbahce.Core.Economy
{
    public enum LimitPeriod { None, Daily, Weekly, Total }

    /// <summary>
    /// Limit dönemleri UTC sunucu saatine göre hesaplanır; cihaz saati kullanılmaz (EconomyService'e saat enjekte edilir).
    /// Haftalar Pazartesi başlar.
    /// </summary>
    public static class Periods
    {
        const long TicksPerDay = TimeSpan.TicksPerDay;
        // 1970-01-01 Perşembe → Pazartesi tabanlı hafta numarası için +3.
        static readonly long UnixEpochTicks = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).Ticks;

        public static long DayIndex(long utcTicks) { return (utcTicks - UnixEpochTicks) / TicksPerDay; }
        public static long WeekIndex(long utcTicks) { return (DayIndex(utcTicks) + 3) / 7; }

        public static string KeyOf(LimitPeriod p, long utcTicks)
        {
            switch (p)
            {
                case LimitPeriod.Daily: return "D" + DayIndex(utcTicks);
                case LimitPeriod.Weekly: return "W" + WeekIndex(utcTicks);
                default: return "T";
            }
        }

        /// <summary>Dönemin bittiği an (yenilenme geri sayımı için). Total/None için null.</summary>
        public static long? NextResetTicks(LimitPeriod p, long utcTicks)
        {
            if (p == LimitPeriod.Daily) return UnixEpochTicks + (DayIndex(utcTicks) + 1) * TicksPerDay;
            if (p == LimitPeriod.Weekly) return UnixEpochTicks + (WeekIndex(utcTicks) * 7 - 3 + 7) * TicksPerDay;
            return null;
        }
    }
}
