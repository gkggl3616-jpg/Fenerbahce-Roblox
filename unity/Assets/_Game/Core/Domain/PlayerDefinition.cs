using System.Collections.Generic;

namespace Fenerbahce.Core.Domain
{
    /// <summary>Temel nitelikler. Prototip denge değerleridir (statsSource), gerçek reyting DEĞİLDİR.</summary>
    public class PlayerAttributes
    {
        public int Pace { get; set; }
        public int Shooting { get; set; }
        public int Passing { get; set; }
        public int Dribbling { get; set; }
        public int Defending { get; set; }
        public int Physical { get; set; }
        /// <summary>Yalnız kalecilerde anlamlı (0 = kaleci değil).</summary>
        public int Goalkeeping { get; set; }
    }

    /// <summary>
    /// Portre kaydı. Fotoğraf dosyası, kaynak ve kullanım izni 3B modelden AYRI varlıktır (T003/T019).
    /// Delivered=false iken kart siluet fallback gösterir.
    /// </summary>
    public class PortraitAsset
    {
        public string Path { get; set; }
        public bool Delivered { get; set; }
        public string Source { get; set; }
        public string UsageRightsStatus { get; set; }
        public float FocalX { get; set; }
        public float FocalY { get; set; }
        public string Checksum { get; set; }
        public string Fallback { get; set; }

        public const string RightsVerified = "DOGRULANDI";
        public const string RightsPending = "DOGRULANACAK";

        /// <summary>Gerçek portre yalnız teslim edilmiş VE izni doğrulanmışsa gösterilebilir.</summary>
        public bool CanShowRealPortrait
        {
            get { return Delivered && UsageRightsStatus == RightsVerified && !string.IsNullOrEmpty(Source); }
        }
    }

    /// <summary>Benzersiz futbolcu (100 kişilik sayımın birimi). Kart varyantı DEĞİLDİR.</summary>
    public class PlayerDefinition
    {
        public string PlayerId { get; set; }
        public string DisplayName { get; set; }
        public string NationalityLabel { get; set; }
        public PositionGroup PositionGroup { get; set; }
        public Position PrimaryPosition { get; set; }
        public List<Position> AlternatePositions { get; set; } = new List<Position>();
        public PreferredFoot PreferredFoot { get; set; }
        /// <summary>Beceri yıldızı 1-5; SkillMove uygunluğunu belirler.</summary>
        public int SkillStars { get; set; }
        public int Stamina { get; set; }
        public int BaseOverall { get; set; }
        public string Tier { get; set; }
        public PlayerAttributes Attributes { get; set; } = new PlayerAttributes();
        /// <summary>Ortak rigli model eşlemesi (3B yüz ayrı iş kalemi).</summary>
        public string BodyType { get; set; }
        public string RosterStatus { get; set; }
        public string StatsSource { get; set; }
        public PortraitAsset Portrait { get; set; } = new PortraitAsset();
    }
}
