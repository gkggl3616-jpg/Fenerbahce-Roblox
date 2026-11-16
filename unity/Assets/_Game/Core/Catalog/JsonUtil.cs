using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;

namespace Fenerbahce.Core.Catalog
{
    /// <summary>Tüm içerik/profil JSON'ları için tek ayar kümesi (camelCase, enum=string).</summary>
    public static class JsonUtil
    {
        public static readonly JsonSerializerSettings Settings = Create();

        private static JsonSerializerSettings Create()
        {
            var s = new JsonSerializerSettings
            {
                ContractResolver = new CamelCasePropertyNamesContractResolver(),
                NullValueHandling = NullValueHandling.Include,
                MissingMemberHandling = MissingMemberHandling.Ignore,
                Formatting = Formatting.Indented,
                // Önemli: varsayılan (Auto) başlangıç değerli listelere ekleme yapar → kayıt yüklenince kartlar ikilenirdi.
                ObjectCreationHandling = ObjectCreationHandling.Replace,
            };
            s.Converters.Add(new StringEnumConverter());
            return s;
        }

        public static T Deserialize<T>(string json) { return JsonConvert.DeserializeObject<T>(json, Settings); }
        public static string Serialize(object o) { return JsonConvert.SerializeObject(o, Settings); }
    }
}
