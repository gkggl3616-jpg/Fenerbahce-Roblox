using System.Collections.Generic;
using Fenerbahce.Core.Squad;

namespace Fenerbahce.Core.Economy
{
    public enum Currency { Coin, Token, EventPoints }

    public class LedgerEntry
    {
        public long Seq { get; set; }
        public string IdempotencyKey { get; set; }
        public Currency Currency { get; set; }
        public long Delta { get; set; }
        public long BalanceAfter { get; set; }
        public string Reason { get; set; }
        public long UtcTicks { get; set; }
    }

    public class Wallet
    {
        public Dictionary<Currency, long> Balances { get; set; } = new Dictionary<Currency, long>();
        public List<LedgerEntry> Ledger { get; set; } = new List<LedgerEntry>();

        public long Get(Currency c) { long v; return Balances.TryGetValue(c, out v) ? v : 0; }
    }

    /// <summary>Tamamlanmış işlemin kaydı. Aynı anahtarla tekrar gelen istek bu kaydı döndürür (idempotency).</summary>
    public class OperationRecord
    {
        public string Key { get; set; }
        public string Kind { get; set; }
        /// <summary>İstek içeriğinin parmak izi; aynı anahtarla farklı içerik gelirse reddedilir.</summary>
        public string Fingerprint { get; set; }
        public List<string> CardInstanceIds { get; set; } = new List<string>();
        public string Detail { get; set; }
        public long UtcTicks { get; set; }
    }

    /// <summary>Dönemsel sayaç (günlük/haftalık/toplam limit). PeriodKey değişince sayaç sıfırlanmış sayılır.</summary>
    public class UsageCounter
    {
        public int Count { get; set; }
        public string PeriodKey { get; set; }
    }

    /// <summary>Atomik işlem kapısında para birimi değişimi.</summary>
    public class CurrencyDelta
    {
        public Currency Currency { get; set; }
        public long Amount { get; set; }
        public CurrencyDelta() { }
        public CurrencyDelta(Currency c, long amount) { Currency = c; Amount = amount; }
    }

    public class ProfileSettings
    {
        public string Language { get; set; } = "tr";
        public float JoystickSensitivity { get; set; } = 1.0f;
        public float JoystickDeadZone { get; set; } = 0.12f;
        public float ButtonScale { get; set; } = 1.0f;
        public bool Vibration { get; set; } = true;
        public float SfxVolume { get; set; } = 0.8f;
        public float MusicVolume { get; set; } = 0.5f;
        /// <summary>0=otomatik, 1=düşük (30 FPS), 2=yüksek (60 FPS). T007/T094 ölçümüne kadar varsayım.</summary>
        public int GraphicsQuality { get; set; } = 0;
    }

    /// <summary>Oyuncunun kalıcı durumu. Sunucu gelene kadar yerel geliştirme cüzdanıdır; GERÇEK ekonomi sunucuda doğrulanmalıdır (T049/T050).</summary>
    public class ProfileState
    {
        public const int CurrentSchemaVersion = 1;
        public int SchemaVersion { get; set; } = CurrentSchemaVersion;
        public string ProfileId { get; set; }
        public string DisplayName { get; set; } = "Taraftar";
        public int Level { get; set; } = 1;
        public long Xp { get; set; }
        public Wallet Wallet { get; set; } = new Wallet();
        public Inventory Inventory { get; set; } = new Inventory();
        public List<SquadPlan> Squads { get; set; } = new List<SquadPlan>();
        public string ActiveSquadId { get; set; }
        public Dictionary<string, OperationRecord> Operations { get; set; } = new Dictionary<string, OperationRecord>();
        /// <summary>Teklif/takas kullanım sayaçları. Anahtar: "offer:&lt;id&gt;" veya "exchange:&lt;id&gt;".</summary>
        public Dictionary<string, UsageCounter> Usage { get; set; } = new Dictionary<string, UsageCounter>();
        public ProfileSettings Settings { get; set; } = new ProfileSettings();
        public int ControlSessionsPlayed { get; set; }
        public int ControlGoalsTotal { get; set; }

        public SquadPlan ActiveSquad
        {
            get
            {
                foreach (var s in Squads) if (s.SquadId == ActiveSquadId) return s;
                return null;
            }
        }
    }
}
