using System;
using System.Collections.Generic;
using Fenerbahce.Core.Domain;

namespace Fenerbahce.Core.Squad
{
    public class SlotDefinition
    {
        public int Index { get; set; }
        public Position Position { get; set; }
        /// <summary>0 = kendi kalesi, 1 = rakip kale.</summary>
        public float X { get; set; }
        /// <summary>0 = sol kenar, 1 = sağ kenar (kendi kalesinden rakibe bakarken).</summary>
        public float Y { get; set; }
    }

    public class FormationDefinition
    {
        public string FormationId { get; set; }
        public string DisplayName { get; set; }
        public IReadOnlyList<SlotDefinition> Slots { get; set; }
    }

    /// <summary>Başlangıç dizilişleri (G09): 4-4-2, 4-3-3, 4-2-3-1. Diğerleri genişleme (TODO).</summary>
    public static class Formations
    {
        public const string F442 = "4-4-2";
        public const string F433 = "4-3-3";
        public const string F4231 = "4-2-3-1";

        static FormationDefinition Make(string id, params object[][] rows)
        {
            var slots = new List<SlotDefinition>();
            foreach (var r in rows)
                slots.Add(new SlotDefinition { Index = slots.Count, Position = (Position)r[0], X = (float)r[1], Y = (float)r[2] });
            if (slots.Count != 11) throw new InvalidOperationException(id + " 11 slot içermiyor");
            return new FormationDefinition { FormationId = id, DisplayName = id, Slots = slots };
        }

        static object[] S(Position p, float x, float y) { return new object[] { p, x, y }; }

        public static readonly FormationDefinition Formation442 = Make(F442,
            S(Position.GK, .05f, .5f),
            S(Position.LB, .22f, .12f), S(Position.CB, .20f, .37f), S(Position.CB, .20f, .63f), S(Position.RB, .22f, .88f),
            S(Position.LM, .50f, .10f), S(Position.CM, .46f, .38f), S(Position.CM, .46f, .62f), S(Position.RM, .50f, .90f),
            S(Position.ST, .78f, .38f), S(Position.ST, .78f, .62f));

        public static readonly FormationDefinition Formation433 = Make(F433,
            S(Position.GK, .05f, .5f),
            S(Position.LB, .22f, .12f), S(Position.CB, .20f, .37f), S(Position.CB, .20f, .63f), S(Position.RB, .22f, .88f),
            S(Position.CM, .46f, .30f), S(Position.CM, .42f, .50f), S(Position.CM, .46f, .70f),
            S(Position.LW, .76f, .14f), S(Position.ST, .82f, .50f), S(Position.RW, .76f, .86f));

        public static readonly FormationDefinition Formation4231 = Make(F4231,
            S(Position.GK, .05f, .5f),
            S(Position.LB, .22f, .12f), S(Position.CB, .20f, .37f), S(Position.CB, .20f, .63f), S(Position.RB, .22f, .88f),
            S(Position.CDM, .38f, .38f), S(Position.CDM, .38f, .62f),
            S(Position.LM, .64f, .14f), S(Position.CAM, .62f, .50f), S(Position.RM, .64f, .86f),
            S(Position.ST, .82f, .50f));

        public static readonly IReadOnlyList<FormationDefinition> All = new List<FormationDefinition> { Formation442, Formation433, Formation4231 };

        public static FormationDefinition Get(string id)
        {
            foreach (var f in All) if (f.FormationId == id) return f;
            return null;
        }
    }
}
