using System.Collections.Generic;
using System.Linq;

namespace Fenerbahce.Core.Catalog
{
    /// <summary>Menü ekran kimlikleri — tek kaynak.</summary>
    public static class ScreenIds
    {
        public const string Home = "home", Club = "club", Collection = "collection", Play = "play", Events = "events", Store = "store", Settings = "settings";
        public static readonly string[] All = { Home, Club, Collection, Play, Events, Store, Settings };
    }

    /// <summary>Ana ekran kampanya afişi (G04). Veriyle değişir; hedef ekran içerikte tanımlıdır (T011).</summary>
    public class Campaign
    {
        public string Id { get; set; }
        public string Title { get; set; }
        public string Subtitle { get; set; }
        public string TargetScreen { get; set; }
        public string AccentHex { get; set; }
        /// <summary>false ise hedef ekran henüz uygulanmamıştır; afiş "yakında" rozetiyle gösterilir.</summary>
        public bool Implemented { get; set; }
        public string TaskIds { get; set; }
    }

    class CampaignFile { public string ContentVersion { get; set; } public List<Campaign> Campaigns { get; set; } }

    public static class CampaignCatalog
    {
        public static List<Campaign> Load(string json)
        {
            var f = JsonUtil.Deserialize<CampaignFile>(json);
            return f == null || f.Campaigns == null ? new List<Campaign>() : f.Campaigns;
        }

        public static List<string> Validate(IList<Campaign> list)
        {
            var errors = new List<string>();
            if (list.Count == 0) errors.Add("kampanya listesi boş");
            var ids = new HashSet<string>();
            foreach (var c in list)
            {
                if (string.IsNullOrEmpty(c.Id) || !ids.Add(c.Id)) errors.Add("kampanya kimliği boş/yinelenmiş: " + c.Id);
                if (!ScreenIds.All.Contains(c.TargetScreen)) errors.Add(c.Id + " bilinmeyen hedef ekran: " + c.TargetScreen);
                if (string.IsNullOrWhiteSpace(c.Title)) errors.Add(c.Id + " başlık boş");
                if (c.AccentHex == null || c.AccentHex.Length != 7 || c.AccentHex[0] != '#') errors.Add(c.Id + " renk geçersiz");
            }
            return errors;
        }
    }
}
