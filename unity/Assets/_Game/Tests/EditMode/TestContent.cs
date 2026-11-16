using System;
using System.IO;
using Fenerbahce.Core.Catalog;

namespace Fenerbahce.Tests
{
    /// <summary>İçerik JSON'unu hem Unity EditMode (cwd = unity/) hem dotnet test (cwd = bin/...) altında bulur.</summary>
    public static class TestContent
    {
        static ContentCatalog _cached;

        public static string ContentDir()
        {
            var rels = new[] { Path.Combine("unity", "Assets", "_Game", "Resources", "Content"), Path.Combine("Assets", "_Game", "Resources", "Content") };
            foreach (var start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
            {
                var dir = new DirectoryInfo(start);
                while (dir != null)
                {
                    foreach (var rel in rels)
                    {
                        var cand = Path.Combine(dir.FullName, rel);
                        if (File.Exists(Path.Combine(cand, "players.v1.json"))) return cand;
                    }
                    dir = dir.Parent;
                }
            }
            throw new DirectoryNotFoundException("players.v1.json bulunamadı");
        }

        public static ContentCatalog Catalog()
        {
            if (_cached == null)
            {
                var d = ContentDir();
                _cached = ContentCatalog.Load(File.ReadAllText(Path.Combine(d, "players.v1.json")), File.ReadAllText(Path.Combine(d, "cards.v1.json")));
            }
            return _cached;
        }

        public static string FreshJson(string file) { return File.ReadAllText(Path.Combine(ContentDir(), file)); }
    }
}
