using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Domain;

namespace Fenerbahce.Core.Economy
{
    /// <summary>Kullanıcının kart örnekleri. Sahiplik/kilit/emanet bilgisi burada tutulur.</summary>
    public class Inventory
    {
        public List<CardInstance> Cards { get; set; } = new List<CardInstance>();

        public CardInstance Get(string cardInstanceId)
        {
            if (cardInstanceId == null) return null;
            for (int i = 0; i < Cards.Count; i++) if (Cards[i].CardInstanceId == cardInstanceId) return Cards[i];
            return null;
        }

        public bool Contains(string cardInstanceId) { return Get(cardInstanceId) != null; }
    }
}
