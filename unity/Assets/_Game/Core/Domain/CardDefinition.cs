namespace Fenerbahce.Core.Domain
{
    /// <summary>
    /// Tasarlanmış kart varyantı. Örn. playerId=P001 → cardDefinitionId=P001_BASE_V1.
    /// Varyant eklemek benzersiz futbolcu sayısını ARTIRMAZ.
    /// </summary>
    public class CardDefinition
    {
        public string CardDefinitionId { get; set; }
        public string PlayerId { get; set; }
        public string Family { get; set; }
        public Rarity Rarity { get; set; }
        public string Program { get; set; }
        public int Overall { get; set; }
        public string FrameId { get; set; }
        public bool Tradable { get; set; }
    }

    /// <summary>Kullanıcının sahip olduğu tek kart kopyası. İki kopyanın kilidi ve durumu bağımsızdır (T018).</summary>
    public class CardInstance
    {
        /// <summary>UUID.</summary>
        public string CardInstanceId { get; set; }
        public string CardDefinitionId { get; set; }
        public bool Locked { get; set; }
        /// <summary>Satılamaz kuralı kart örneğine bağlıdır (G68).</summary>
        public bool Tradable { get; set; }
        /// <summary>Pazarda emanet durumunda (T078): harcanamaz, kadroya konamaz.</summary>
        public bool ListedOnMarket { get; set; }
        public int TrainingLevel { get; set; }
        public int Rank { get; set; }
        public string AcquiredVia { get; set; }
    }
}
