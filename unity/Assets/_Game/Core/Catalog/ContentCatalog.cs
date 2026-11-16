using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Domain;

namespace Fenerbahce.Core.Catalog
{
    class PlayersFile
    {
        public string ContentVersion { get; set; }
        public int SchemaVersion { get; set; }
        public string StatsSource { get; set; }
        public List<PlayerDefinition> Players { get; set; }
    }

    class CardsFile
    {
        public string ContentVersion { get; set; }
        public int SchemaVersion { get; set; }
        public List<CardDefinition> Cards { get; set; }
    }

    /// <summary>
    /// Sürümlü içerik kataloğu. İstemcide Resources'tan, testlerde dosyadan yüklenir.
    /// Sayım birimi PlayerDefinition'dır; CardDefinition sayımı değiştirmez.
    /// </summary>
    public class ContentCatalog
    {
        public const int ExpectedPlayerCount = 100;

        public string PlayersVersion { get; private set; }
        public string CardsVersion { get; private set; }
        public IReadOnlyList<PlayerDefinition> Players { get; private set; }
        public IReadOnlyList<CardDefinition> Cards { get; private set; }

        private readonly Dictionary<string, PlayerDefinition> _players = new Dictionary<string, PlayerDefinition>();
        private readonly Dictionary<string, CardDefinition> _cards = new Dictionary<string, CardDefinition>();

        public static ContentCatalog Load(string playersJson, string cardsJson)
        {
            var pf = JsonUtil.Deserialize<PlayersFile>(playersJson);
            var cf = JsonUtil.Deserialize<CardsFile>(cardsJson);
            if (pf == null || pf.Players == null) throw new InvalidOperationException("players JSON boş veya bozuk");
            if (cf == null || cf.Cards == null) throw new InvalidOperationException("cards JSON boş veya bozuk");
            var c = new ContentCatalog
            {
                PlayersVersion = pf.ContentVersion,
                CardsVersion = cf.ContentVersion,
                Players = pf.Players,
                Cards = cf.Cards,
            };
            // Yinelenen kimlik doğrulayıcıda yakalanır; sözlükte ilkini tut.
            foreach (var p in pf.Players) if (p.PlayerId != null && !c._players.ContainsKey(p.PlayerId)) c._players[p.PlayerId] = p;
            foreach (var d in cf.Cards) if (d.CardDefinitionId != null && !c._cards.ContainsKey(d.CardDefinitionId)) c._cards[d.CardDefinitionId] = d;
            return c;
        }

        public PlayerDefinition GetPlayer(string playerId)
        {
            PlayerDefinition p; return playerId != null && _players.TryGetValue(playerId, out p) ? p : null;
        }

        public CardDefinition GetCard(string cardDefinitionId)
        {
            CardDefinition d; return cardDefinitionId != null && _cards.TryGetValue(cardDefinitionId, out d) ? d : null;
        }

        /// <summary>Benzersiz futbolcu sayısı (kart varyantları HARİÇ).</summary>
        public int UniquePlayerCount { get { return _players.Count; } }

        public PlayerDefinition PlayerOfCard(CardDefinition d) { return GetPlayer(d.PlayerId); }

        public string BaseCardIdOf(string playerId) { return playerId + "_BASE_V1"; }
    }
}
