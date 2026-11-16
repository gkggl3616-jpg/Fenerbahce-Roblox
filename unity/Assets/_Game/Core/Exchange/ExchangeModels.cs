using System.Collections.Generic;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Domain;

namespace Fenerbahce.Core.Exchange
{
    /// <summary>Takas koşulu (G66): "94+ GEN Oyuncu — 3 adet". Gereken kart sayısı ve en düşük GEN.</summary>
    public class ExchangeRequirement
    {
        public string RequirementId { get; set; }
        public string Label { get; set; }
        public int MinOverall { get; set; }
        public int Count { get; set; }
        /// <summary>İsteğe bağlı mevki grubu kısıtı (null = hepsi).</summary>
        public PositionGroup? Group { get; set; }
    }

    /// <summary>
    /// Takas tarifi. Ödül sabittir (kart tanımları + coin); rastgele ödül (drop table) T066/T067 kapsamındadır.
    /// Süre ve limit sunucu/servis saatine bağlıdır (G67).
    /// </summary>
    public class ExchangeRecipe
    {
        public string RecipeId { get; set; }
        public string Title { get; set; }
        public string Program { get; set; }
        public List<ExchangeRequirement> Requirements { get; set; } = new List<ExchangeRequirement>();
        public List<string> RewardCardDefinitionIds { get; set; } = new List<string>();
        public long RewardCoins { get; set; }
        /// <summary>0 = sınırsız. Referansta "Limit: 0 / 5".</summary>
        public int MaxUses { get; set; }
        /// <summary>UTC ticks; 0 = süresiz.</summary>
        public long ExpiresUtcTicks { get; set; }
    }

    class ExchangeFile { public string ContentVersion { get; set; } public List<ExchangeRecipe> Recipes { get; set; } }

    public static class ExchangeCatalog
    {
        public static List<ExchangeRecipe> Load(string json)
        {
            var f = JsonUtil.Deserialize<ExchangeFile>(json);
            return f == null || f.Recipes == null ? new List<ExchangeRecipe>() : f.Recipes;
        }

        public static List<string> Validate(IList<ExchangeRecipe> list, ContentCatalog cat)
        {
            var errors = new List<string>(); var ids = new HashSet<string>();
            foreach (var r in list)
            {
                if (string.IsNullOrEmpty(r.RecipeId) || !ids.Add(r.RecipeId)) errors.Add("tarif kimliği boş/yinelenmiş: " + r.RecipeId);
                if (r.Requirements.Count == 0) errors.Add(r.RecipeId + " koşul yok");
                var rq = new HashSet<string>();
                foreach (var q in r.Requirements)
                {
                    if (string.IsNullOrEmpty(q.RequirementId) || !rq.Add(q.RequirementId)) errors.Add(r.RecipeId + " koşul kimliği hatalı");
                    if (q.Count < 1) errors.Add(r.RecipeId + "/" + q.RequirementId + " adet<1");
                    if (q.MinOverall < 1 || q.MinOverall > 99) errors.Add(r.RecipeId + "/" + q.RequirementId + " GEN aralık dışı");
                }
                if (r.RewardCardDefinitionIds.Count == 0 && r.RewardCoins <= 0) errors.Add(r.RecipeId + " ödül yok");
                foreach (var c in r.RewardCardDefinitionIds) if (cat.GetCard(c) == null) errors.Add(r.RecipeId + " geçersiz ödül kartı " + c);
                if (r.RewardCoins < 0) errors.Add(r.RecipeId + " negatif coin ödülü");
                if (r.MaxUses < 0) errors.Add(r.RecipeId + " negatif limit");
            }
            return errors;
        }
    }
}
