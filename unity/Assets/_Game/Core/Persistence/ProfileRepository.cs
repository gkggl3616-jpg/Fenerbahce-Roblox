using System;
using System.IO;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Economy;

namespace Fenerbahce.Core.Persistence
{
    public interface IProfileStorage
    {
        bool Exists();
        string Read();
        void Write(string json);
    }

    public class MemoryStorage : IProfileStorage
    {
        string _data;
        public bool Exists() { return _data != null; }
        public string Read() { return _data; }
        public void Write(string json) { _data = json; }
    }

    /// <summary>Yarım yazılmış dosya bırakmaması için geçici dosyaya yazıp yer değiştirir.</summary>
    public class FileStorage : IProfileStorage
    {
        readonly string _path;
        public FileStorage(string path) { _path = path; }
        public bool Exists() { return File.Exists(_path); }
        public string Read() { return File.ReadAllText(_path); }
        public void Write(string json)
        {
            var dir = Path.GetDirectoryName(_path);
            if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
            var tmp = _path + ".tmp";
            File.WriteAllText(tmp, json);
            if (File.Exists(_path)) File.Delete(_path);
            File.Move(tmp, _path);
        }
    }

    public class ProfileRepository
    {
        readonly IProfileStorage _storage;
        public ProfileRepository(IProfileStorage storage) { _storage = storage; }

        public bool HasSave { get { return _storage.Exists(); } }

        public ProfileState Load()
        {
            var p = JsonUtil.Deserialize<ProfileState>(_storage.Read());
            if (p == null) throw new InvalidOperationException("kayıt dosyası bozuk");
            if (p.SchemaVersion > ProfileState.CurrentSchemaVersion)
                throw new InvalidOperationException("kayıt daha yeni bir istemci sürümünden (v" + p.SchemaVersion + ")");
            return p;
        }

        public void Save(ProfileState p) { _storage.Write(JsonUtil.Serialize(p)); }

        /// <summary>Kayıt varsa yükler; yoksa yeni profil üretir ve başlangıç paketini verir.</summary>
        public ProfileState LoadOrCreate(ContentCatalog cat, out bool created, Func<string> idFactory = null)
        {
            if (HasSave)
            {
                try { created = false; return Load(); }
                catch (Exception) { /* bozuk kayıt: üzerine yazılmadan önce çağıran taraf haberdar edilmeli */ throw; }
            }
            var p = new ProfileState { ProfileId = (idFactory ?? (() => Guid.NewGuid().ToString("N")))() };
            new EconomyService(p, cat, idFactory).ClaimStarterPackage();
            Save(p);
            created = true;
            return p;
        }
    }
}
