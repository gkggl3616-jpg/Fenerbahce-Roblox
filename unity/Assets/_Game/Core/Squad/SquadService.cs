using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Economy;

namespace Fenerbahce.Core.Squad
{
    public class SquadIssue
    {
        public string Code { get; set; }
        public string Message { get; set; }
        public int Slot { get; set; } = -1;
        public bool IsError { get; set; }
        public override string ToString() { return (IsError ? "HATA " : "UYARI ") + Code + ": " + Message; }
    }

    public class TeamSummary
    {
        public int FilledSlots { get; set; }
        /// <summary>Takım GEN: dolu slotların etkin GEN ortalaması (yuvarlanmış). Boş slot 0 sayılır.</summary>
        public int Overall { get; set; }
        public long Value { get; set; }
        public int OutOfPositionCount { get; set; }
    }

    public static class CardValue
    {
        /// <summary>Kart değeri (coin). PROTOTİP eğrisi: kaynak oyundan kopyalanmaz, dengede ayarlanır.</summary>
        public static long Of(int overall)
        {
            return (long)Math.Round(100.0 * Math.Pow(1.22, overall - 60));
        }
    }

    public static class SquadService
    {
        public static List<SquadIssue> Validate(SquadPlan plan, Inventory inv, ContentCatalog cat, bool requireFull)
        {
            var issues = new List<SquadIssue>();
            var f = Formations.Get(plan.FormationId);
            if (f == null) { Add(issues, true, "FORMATION", "bilinmeyen diziliş " + plan.FormationId); return issues; }
            if (plan.Starters == null || plan.Starters.Length != 11) { Add(issues, true, "SLOT_COUNT", "kadro 11 slot içermeli"); return issues; }

            var seen = new HashSet<string>();
            for (int i = 0; i < 11; i++)
            {
                var id = plan.Starters[i];
                if (id == null) { if (requireFull) Add(issues, true, "SLOT_EMPTY", "slot " + i + " boş", i); continue; }
                if (!seen.Add(id)) { Add(issues, true, "DUPLICATE_CARD", "aynı kart örneği iki slotta: " + id, i); continue; }
                CheckCard(issues, id, inv, cat, i, f.Slots[i].Position);
            }
            if (plan.Bench.Count > SquadPlan.MaxBench) Add(issues, true, "BENCH_SIZE", "yedek sayısı " + SquadPlan.MaxBench + " üstünde");
            foreach (var id in plan.Bench)
            {
                if (!seen.Add(id)) { Add(issues, true, "DUPLICATE_CARD", "kart hem ilk 11'de/yedekte yinelenmiş: " + id); continue; }
                CheckCard(issues, id, inv, cat, -1, null);
            }
            foreach (var slot in new[] { plan.CaptainSlot, plan.PenaltyTakerSlot, plan.FreeKickTakerSlot, plan.CornerTakerSlot })
                if (slot != -1 && (slot < 0 || slot > 10 || plan.Starters[slot] == null))
                    Add(issues, true, "ROLE_SLOT", "rol atanan slot geçersiz/boş: " + slot);
            return issues;
        }

        static void CheckCard(List<SquadIssue> issues, string id, Inventory inv, ContentCatalog cat, int slot, Position? slotPos)
        {
            var ci = inv.Get(id);
            if (ci == null) { Add(issues, true, "NOT_OWNED", "kart envanterde yok: " + id, slot); return; }
            if (ci.ListedOnMarket) Add(issues, true, "LISTED", "satıştaki (emanet) kart kadroya konamaz: " + id, slot);
            var def = cat.GetCard(ci.CardDefinitionId);
            var pl = def == null ? null : cat.GetPlayer(def.PlayerId);
            if (def == null || pl == null) { Add(issues, true, "BAD_REF", "geçersiz kart tanımı: " + ci.CardDefinitionId, slot); return; }
            if (slotPos.HasValue)
            {
                var fit = PositionFit.Evaluate(slotPos.Value, pl);
                if (fit == Fit.Invalid) Add(issues, true, "POSITION_INVALID", pl.DisplayName + " (" + pl.PrimaryPosition + ") " + slotPos.Value + " slotunda oynayamaz", slot);
                else if (fit == Fit.OutOfPosition) Add(issues, false, "OUT_OF_POSITION", pl.DisplayName + " pozisyon dışı: " + slotPos.Value, slot);
            }
        }

        static void Add(List<SquadIssue> l, bool err, string code, string msg, int slot = -1)
        {
            l.Add(new SquadIssue { IsError = err, Code = code, Message = msg, Slot = slot });
        }

        public static TeamSummary Summarize(SquadPlan plan, Inventory inv, ContentCatalog cat)
        {
            var f = Formations.Get(plan.FormationId);
            var s = new TeamSummary();
            int sum = 0;
            for (int i = 0; i < 11; i++)
            {
                var ci = inv.Get(plan.Starters[i]);
                if (ci == null) continue;
                var def = cat.GetCard(ci.CardDefinitionId);
                var pl = def == null ? null : cat.GetPlayer(def.PlayerId);
                if (def == null || pl == null) continue;
                var fit = PositionFit.Evaluate(f.Slots[i].Position, pl);
                if (fit == Fit.OutOfPosition) s.OutOfPositionCount++;
                s.FilledSlots++;
                sum += PositionFit.EffectiveOverall(def.Overall, fit);
                s.Value += CardValue.Of(def.Overall);
            }
            s.Overall = (int)Math.Round(sum / 11.0);
            return s;
        }

        /// <summary>Kartı slota yerleştirir; kart başka yerde (slot/yedek) ise oradan çıkarır → aynı kart iki yerde olamaz.</summary>
        public static void Place(SquadPlan plan, int slot, string cardInstanceId)
        {
            if (slot < 0 || slot > 10) throw new ArgumentOutOfRangeException("slot");
            RemoveEverywhere(plan, cardInstanceId);
            plan.Starters[slot] = cardInstanceId;
        }

        public static void RemoveEverywhere(SquadPlan plan, string cardInstanceId)
        {
            for (int i = 0; i < 11; i++) if (plan.Starters[i] == cardInstanceId) plan.Starters[i] = null;
            plan.Bench.RemoveAll(x => x == cardInstanceId);
        }

        /// <summary>İlk 11 slotundaki kartla yedekteki kartın yerini değiştirir (G11).</summary>
        public static bool SwapWithBench(SquadPlan plan, int slot, string benchCardId)
        {
            if (!plan.Bench.Contains(benchCardId)) return false;
            var old = plan.Starters[slot];
            plan.Bench.Remove(benchCardId);
            plan.Starters[slot] = benchCardId;
            if (old != null) plan.Bench.Add(old);
            return true;
        }

        public static bool IsAssigned(SquadPlan plan, string cardInstanceId)
        {
            return plan.Starters.Contains(cardInstanceId) || plan.Bench.Contains(cardInstanceId);
        }
    }
}
