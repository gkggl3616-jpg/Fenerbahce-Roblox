namespace Fenerbahce.Core.Economy
{
    /// <summary>Profil seviyesi (PROTOTİP eğrisi): her 100 XP bir seviye.</summary>
    public static class Progression
    {
        public const int XpPerLevel = 100;
        public static int Level(long xp) { return 1 + (int)(xp / XpPerLevel); }
        public static float Progress(long xp) { return (xp % XpPerLevel) / (float)XpPerLevel; }
    }
}
