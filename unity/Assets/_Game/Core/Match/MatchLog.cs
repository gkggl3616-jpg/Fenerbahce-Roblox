using System.Collections.Generic;
using System.Linq;

namespace Fenerbahce.Core.Match
{
    public enum MatchEventType { Goal, Shot, ShotOnTarget, Save, Pass, PassCompleted, Foul, Offside, Corner, YellowCard, RedCard }

    /// <summary>Maçta olan tek bir olay. İstatistikler YALNIZ bu kayıttan türetilir (T048).</summary>
    public class MatchEvent
    {
        public int Seq { get; set; }
        public MatchEventType Type { get; set; }
        /// <summary>0 = ev sahibi (oyuncu), 1 = rakip.</summary>
        public int Team { get; set; }
        public string Actor { get; set; }
        /// <summary>Ekranda gösterilen maç dakikası (0-90).</summary>
        public int Minute { get; set; }
    }

    public class MatchLog
    {
        readonly List<MatchEvent> _events = new List<MatchEvent>();
        public IReadOnlyList<MatchEvent> Events { get { return _events; } }

        public MatchEvent Add(MatchEventType type, int team, string actor, int minute)
        {
            var e = new MatchEvent { Seq = _events.Count + 1, Type = type, Team = team, Actor = actor, Minute = minute };
            _events.Add(e);
            return e;
        }
    }

    public class TeamStats
    {
        public int Shots, ShotsOnTarget, Saves, Passes, PassesCompleted, Fouls, Offsides, Corners, YellowCards, RedCards;
        public float PossessionSeconds;
        /// <summary>0..100; tamamlanan/denenen. Hiç pas yoksa -1 (gösterilmez).</summary>
        public int PassAccuracyPercent { get { return Passes == 0 ? -1 : (int)System.Math.Round(100.0 * PassesCompleted / Passes); } }
    }

    public class ScorerEntry
    {
        public int Team { get; set; }
        public string Name { get; set; }
        public int Minute { get; set; }
    }

    public class MatchResult
    {
        public int ScoreHome { get; set; }
        public int ScoreAway { get; set; }
        public List<ScorerEntry> Scorers { get; set; } = new List<ScorerEntry>();
        public TeamStats Home { get; set; } = new TeamStats();
        public TeamStats Away { get; set; } = new TeamStats();
        /// <summary>İki takımın topa sahip olma yüzdesi; toplam süre 0 ise ikisi de -1 (veri yok).</summary>
        public int HomePossessionPercent { get; set; } = -1;
        public int AwayPossessionPercent { get; set; } = -1;
        /// <summary>false ise faul/ofsayt/korner/kart bu modda üretilmez (T044); ekranda "—" gösterilir, 0 sayılmaz.</summary>
        public bool RulesStatsAvailable { get; set; }
    }

    public static class MatchResultBuilder
    {
        public static MatchResult Build(MatchLog log, float homePossessionSeconds, float awayPossessionSeconds, bool rulesStatsAvailable)
        {
            var r = new MatchResult { RulesStatsAvailable = rulesStatsAvailable };
            r.Home.PossessionSeconds = homePossessionSeconds; r.Away.PossessionSeconds = awayPossessionSeconds;
            foreach (var e in log.Events)
            {
                var t = e.Team == 0 ? r.Home : r.Away;
                switch (e.Type)
                {
                    case MatchEventType.Goal:
                        if (e.Team == 0) r.ScoreHome++; else r.ScoreAway++;
                        r.Scorers.Add(new ScorerEntry { Team = e.Team, Name = e.Actor, Minute = e.Minute });
                        break;
                    case MatchEventType.Shot: t.Shots++; break;
                    case MatchEventType.ShotOnTarget: t.ShotsOnTarget++; break;
                    case MatchEventType.Save: t.Saves++; break;
                    case MatchEventType.Pass: t.Passes++; break;
                    case MatchEventType.PassCompleted: t.PassesCompleted++; break;
                    case MatchEventType.Foul: t.Fouls++; break;
                    case MatchEventType.Offside: t.Offsides++; break;
                    case MatchEventType.Corner: t.Corners++; break;
                    case MatchEventType.YellowCard: t.YellowCards++; break;
                    case MatchEventType.RedCard: t.RedCards++; break;
                }
            }
            r.Scorers = r.Scorers.OrderBy(s => s.Minute).ToList();
            float total = homePossessionSeconds + awayPossessionSeconds;
            if (total > 0.0001f)
            {
                r.HomePossessionPercent = (int)System.Math.Round(100.0 * homePossessionSeconds / total);
                r.AwayPossessionPercent = 100 - r.HomePossessionPercent;
            }
            return r;
        }
    }
}
