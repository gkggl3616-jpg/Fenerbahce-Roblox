using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Economy;

namespace Fenerbahce.Core.Squad
{
    public class AutoPickResult
    {
        public SquadPlan Plan { get; set; }
        public List<int> UnfilledSlots { get; } = new List<int>();
        public bool IsComplete { get { return UnfilledSlots.Count == 0; } }
    }

    /// <summary>
    /// Otomatik takım kurma (G10/T036). Kurallar: kullanıcı sabitlemeleri (pinned) korunur,
    /// satıştaki kart seçilmez, aynı kart iki slota girmez, önce geçerli mevki sonra pozisyon dışı aynı grup.
    /// Açgözlü + kıtlık sıralaması kullanır; en iyi atama garantisi vermez (bilinen sınır).
    /// </summary>
    public static class AutoPicker
    {
        public static AutoPickResult Pick(string formationId, Inventory inv, ContentCatalog cat, IDictionary<int, string> pinned, string squadId, string name)
        {
            var f = Formations.Get(formationId);
            if (f == null) throw new ArgumentException("bilinmeyen diziliş");
            var plan = new SquadPlan { SquadId = squadId, Name = name, FormationId = formationId };
            var used = new HashSet<string>();
            if (pinned != null)
                foreach (var kv in pinned)
                    if (kv.Key >= 0 && kv.Key < 11 && kv.Value != null && inv.Contains(kv.Value) && used.Add(kv.Value))
                        plan.Starters[kv.Key] = kv.Value;

            var pool = new List<Candidate>();
            foreach (var ci in inv.Cards)
            {
                if (ci.ListedOnMarket) continue;
                var def = cat.GetCard(ci.CardDefinitionId);
                var pl = def == null ? null : cat.GetPlayer(def.PlayerId);
                if (def == null || pl == null) continue;
                pool.Add(new Candidate { Card = ci, Def = def, Player = pl });
            }

            var open = Enumerable.Range(0, 11).Where(i => plan.Starters[i] == null).ToList();
            // 1. tur: geçerli mevki (Exact/Alternate), en kıt slot önce.
            Func<int, int> scarcity = s => pool.Count(c => !used.Contains(c.Card.CardInstanceId) && IsGood(f.Slots[s].Position, c));
            while (open.Count > 0)
            {
                int slot = open.OrderBy(scarcity).ThenBy(s => s).First();
                var best = BestFor(f.Slots[slot].Position, pool, used, goodOnly: true);
                if (best == null) break;
                plan.Starters[slot] = best.Card.CardInstanceId; used.Add(best.Card.CardInstanceId); open.Remove(slot);
            }
            // 2. tur: pozisyon dışı (aynı grup).
            foreach (var slot in open.ToList())
            {
                var best = BestFor(f.Slots[slot].Position, pool, used, goodOnly: false);
                if (best == null) continue;
                plan.Starters[slot] = best.Card.CardInstanceId; used.Add(best.Card.CardInstanceId); open.Remove(slot);
            }

            var result = new AutoPickResult { Plan = plan };
            result.UnfilledSlots.AddRange(open);

            // Yedekler: 1 kaleci (varsa) + en iyi diğer kartlar.
            var rest = pool.Where(c => !used.Contains(c.Card.CardInstanceId)).OrderByDescending(c => c.Def.Overall).ThenBy(c => c.Card.CardInstanceId).ToList();
            var gk = rest.FirstOrDefault(c => c.Player.PrimaryPosition == Position.GK);
            if (gk != null) { plan.Bench.Add(gk.Card.CardInstanceId); rest.Remove(gk); }
            foreach (var c in rest) { if (plan.Bench.Count >= SquadPlan.MaxBench) break; plan.Bench.Add(c.Card.CardInstanceId); }

            // Roller: kaptan = en yüksek GEN'li saha oyuncusu; duran toplar slot sırasıyla ilk uygun.
            AssignRoles(plan, inv, cat);
            return result;
        }

        static void AssignRoles(SquadPlan plan, Inventory inv, ContentCatalog cat)
        {
            int bestSlot = -1, bestOvr = -1;
            for (int i = 0; i < 11; i++)
            {
                var ci = inv.Get(plan.Starters[i]); if (ci == null) continue;
                var d = cat.GetCard(ci.CardDefinitionId); var p = d == null ? null : cat.GetPlayer(d.PlayerId);
                if (p == null || p.PrimaryPosition == Position.GK) continue;
                if (d.Overall > bestOvr) { bestOvr = d.Overall; bestSlot = i; }
            }
            plan.CaptainSlot = bestSlot;
            plan.PenaltyTakerSlot = BestBy(plan, inv, cat, p => p.Attributes.Shooting);
            plan.FreeKickTakerSlot = BestBy(plan, inv, cat, p => p.Attributes.Passing + p.Attributes.Shooting);
            plan.CornerTakerSlot = BestBy(plan, inv, cat, p => p.Attributes.Passing);
        }

        static int BestBy(SquadPlan plan, Inventory inv, ContentCatalog cat, Func<PlayerDefinition, int> score)
        {
            int best = -1, bestScore = int.MinValue;
            for (int i = 0; i < 11; i++)
            {
                var ci = inv.Get(plan.Starters[i]); if (ci == null) continue;
                var d = cat.GetCard(ci.CardDefinitionId); var p = d == null ? null : cat.GetPlayer(d.PlayerId);
                if (p == null || p.PrimaryPosition == Position.GK) continue;
                int sc = score(p);
                if (sc > bestScore) { bestScore = sc; best = i; }
            }
            return best;
        }

        class Candidate { public CardInstance Card; public CardDefinition Def; public PlayerDefinition Player; }

        static bool IsGood(Position slot, Candidate c)
        {
            var fit = PositionFit.Evaluate(slot, c.Player);
            return fit == Fit.Exact || fit == Fit.Alternate;
        }

        static Candidate BestFor(Position slot, List<Candidate> pool, HashSet<string> used, bool goodOnly)
        {
            Candidate best = null; int bestScore = int.MinValue;
            foreach (var c in pool)
            {
                if (used.Contains(c.Card.CardInstanceId)) continue;
                var fit = PositionFit.Evaluate(slot, c.Player);
                if (fit == Fit.Invalid) continue;
                if (goodOnly && fit == Fit.OutOfPosition) continue;
                int score = PositionFit.EffectiveOverall(c.Def.Overall, fit) * 10 + (fit == Fit.Exact ? 1 : 0);
                if (score > bestScore || (score == bestScore && string.CompareOrdinal(c.Card.CardInstanceId, best.Card.CardInstanceId) < 0))
                { best = c; bestScore = score; }
            }
            return best;
        }
    }
}
