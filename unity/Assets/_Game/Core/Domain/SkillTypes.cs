using System.Collections.Generic;

namespace Fenerbahce.Core.Domain
{
    /// <summary>
    /// Maç içi çalım hareketi. Kalıcı kart gelişimi (SkillUpgrade) ile KARIŞTIRILMAZ.
    /// Zaman/mesafe değerleri videodan alınmamıştır; prototipte ölçülecek PROTOTİP varsayımlarıdır (T031/T033).
    /// </summary>
    public class SkillMove
    {
        public string SkillMoveId { get; set; }
        public string DisplayName { get; set; }
        public string Gesture { get; set; }
        public int MinSkillStars { get; set; }
        public float ContactTimeSeconds { get; set; }
        public float DistanceMeters { get; set; }
        public float RecoverySeconds { get; set; }
        public float CooldownSeconds { get; set; }
        /// <summary>Sim tarafında uygulanmış mı. false ise UI'da "yakında" olarak gösterilir.</summary>
        public bool Implemented { get; set; }
        public bool IsPrototypeEstimate { get; set; } = true;
    }

    /// <summary>Kalıcı kart geliştirmesi (T056). Maç içi SkillMove'dan ayrı veri tipi.</summary>
    public class SkillUpgrade
    {
        public string SkillUpgradeId { get; set; }
        public string DisplayName { get; set; }
        public int MaxLevel { get; set; }
    }

    public static class SkillMoves
    {
        public const string DirectionChange = "SKM_DIRECTION_CHANGE";
        public const string HeelFlick = "SKM_HEEL_FLICK";
        public const string BallLift = "SKM_BALL_LIFT";
        public const string FeintShot = "SKM_FEINT_SHOT";

        public static readonly IReadOnlyList<SkillMove> All = new List<SkillMove>
        {
            new SkillMove { SkillMoveId = DirectionChange, DisplayName = "Yön Değiştirme", Gesture = "Beceri düğmesi: sola/sağa kaydır",
                MinSkillStars = 1, ContactTimeSeconds = 0.12f, DistanceMeters = 1.4f, RecoverySeconds = 0.28f, CooldownSeconds = 0.9f, Implemented = true },
            new SkillMove { SkillMoveId = HeelFlick, DisplayName = "Topuk Hareketi", Gesture = "Beceri düğmesi: aşağı kaydır",
                MinSkillStars = 2, ContactTimeSeconds = 0.18f, DistanceMeters = 1.8f, RecoverySeconds = 0.35f, CooldownSeconds = 1.2f, Implemented = false },
            new SkillMove { SkillMoveId = BallLift, DisplayName = "Topu Kaldırma", Gesture = "Beceri düğmesi: yukarı kaydır",
                MinSkillStars = 3, ContactTimeSeconds = 0.20f, DistanceMeters = 2.2f, RecoverySeconds = 0.40f, CooldownSeconds = 1.5f, Implemented = false },
            new SkillMove { SkillMoveId = FeintShot, DisplayName = "Feyk Şut", Gesture = "Şut düğmesi: çift dokun",
                MinSkillStars = 3, ContactTimeSeconds = 0.22f, DistanceMeters = 1.0f, RecoverySeconds = 0.45f, CooldownSeconds = 1.5f, Implemented = false },
        };

        public static SkillMove Get(string id)
        {
            for (int i = 0; i < All.Count; i++) if (All[i].SkillMoveId == id) return All[i];
            return null;
        }
    }
}
