using System.Text;

namespace Fenerbahce.Core.Design
{
    /// <summary>Arama için Türkçe/aksanlı karakter katlama: "Livaković" ↔ "livakovic", "Gökhan" ↔ "gokhan", "İrfan" ↔ "irfan".</summary>
    public static class TextFold
    {
        public static string Fold(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new StringBuilder(s.Length);
            foreach (var ch in s)
            {
                switch (ch)
                {
                    case 'ı': case 'İ': case 'I': case 'í': case 'Í': case 'ï': case 'î': sb.Append('i'); break;
                    case 'ğ': case 'Ğ': sb.Append('g'); break;
                    case 'ş': case 'Ş': sb.Append('s'); break;
                    case 'ç': case 'Ç': case 'ć': case 'Ć': case 'č': case 'Č': sb.Append('c'); break;
                    case 'ö': case 'Ö': case 'ó': case 'Ó': case 'ô': sb.Append('o'); break;
                    case 'ü': case 'Ü': case 'ú': case 'Ú': case 'û': sb.Append('u'); break;
                    case 'á': case 'Á': case 'à': case 'â': case 'ã': case 'ä': sb.Append('a'); break;
                    case 'é': case 'É': case 'è': case 'ê': case 'ë': sb.Append('e'); break;
                    case 'ñ': case 'Ñ': sb.Append('n'); break;
                    case 'š': case 'Š': sb.Append('s'); break;
                    case 'ž': case 'Ž': sb.Append('z'); break;
                    case 'đ': case 'Đ': sb.Append('d'); break;
                    case 'ł': case 'Ł': sb.Append('l'); break;
                    case 'ø': case 'Ø': sb.Append('o'); break;
                    default: sb.Append(char.ToLowerInvariant(ch)); break;
                }
            }
            return sb.ToString();
        }

        public static bool Matches(string haystack, string query)
        {
            var q = Fold(query).Trim();
            return q.Length == 0 || Fold(haystack).Contains(q);
        }
    }
}
