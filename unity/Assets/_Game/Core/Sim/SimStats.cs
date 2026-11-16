using Fenerbahce.Core.Domain;

namespace Fenerbahce.Core.Sim
{
    /// <summary>Simülasyonun kullandığı sade nitelik kümesi (kart/katalog bağımlılığı olmadan botlar için de kullanılır).</summary>
    public class SimStats
    {
        public float Pace = 70, Shooting = 70, Passing = 70, Dribbling = 70, Defending = 70, Physical = 70, Goalkeeping = 70;
        public float Stamina = 80;
        public int SkillStars = 2;
        public string DisplayName = "Oyuncu";

        public static SimStats From(PlayerDefinition p, int cardOverall)
        {
            var a = p.Attributes;
            return new SimStats
            {
                Pace = a.Pace, Shooting = a.Shooting, Passing = a.Passing, Dribbling = a.Dribbling,
                Defending = a.Defending, Physical = a.Physical, Goalkeeping = a.Goalkeeping,
                Stamina = p.Stamina, SkillStars = p.SkillStars, DisplayName = p.DisplayName,
            };
        }

        public static SimStats Generic(float level, string name)
        {
            return new SimStats { Pace = level, Shooting = level, Passing = level, Dribbling = level, Defending = level, Physical = level, Goalkeeping = level, Stamina = 80, SkillStars = 1, DisplayName = name };
        }
    }
}
