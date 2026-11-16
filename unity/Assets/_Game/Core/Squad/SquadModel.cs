using System.Collections.Generic;

namespace Fenerbahce.Core.Squad
{
    /// <summary>Kayıtlı kadro/oyun planı (G12). Slotlar kart ÖRNEĞİNE referans verir (T034).</summary>
    public class SquadPlan
    {
        public string SquadId { get; set; }
        public string Name { get; set; }
        public string FormationId { get; set; }
        /// <summary>Uzunluk 11; boş slot = null.</summary>
        public string[] Starters { get; set; } = new string[11];
        public List<string> Bench { get; set; } = new List<string>();
        /// <summary>Slot indeksleri (G13). -1 = atanmamış.</summary>
        public int CaptainSlot { get; set; } = -1;
        public int PenaltyTakerSlot { get; set; } = -1;
        public int FreeKickTakerSlot { get; set; } = -1;
        public int CornerTakerSlot { get; set; } = -1;

        public const int MaxBench = 7;

        public SquadPlan Clone()
        {
            var c = (SquadPlan)MemberwiseClone();
            c.Starters = (string[])Starters.Clone();
            c.Bench = new List<string>(Bench);
            return c;
        }

        public int FilledStarters()
        {
            int n = 0; foreach (var s in Starters) if (s != null) n++; return n;
        }
    }
}
