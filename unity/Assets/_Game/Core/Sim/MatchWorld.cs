using System;
using System.Collections.Generic;
using System.Linq;
using Fenerbahce.Core.Match;

namespace Fenerbahce.Core.Sim
{
    public enum AgentRole { Def, Mid, Att }

    /// <summary>Takım dizilişi/ayarı. Slotlar normalize: x 0=kendi kale → 1=rakip kale, y 0=sol → 1=sağ (hücum yönüne bakarken).</summary>
    public class TeamSetup
    {
        public string Name = "Takım";
        public List<SimStats> Outfield = new List<SimStats>();
        public List<Vec2> Slots = new List<Vec2>();
        public SimStats Keeper = SimStats.Generic(70f, "Kaleci");
        /// <summary>0..1 baskı yüksekliği (PROTOTİP taktik; T. Direktör/T088 ile bağlanacak).</summary>
        public float Pressing = 0.6f;

        /// <summary>5 kişilik (1 kaleci + 4 saha) deneme dizilişi: 2 defans, 1 orta, 1 forvet.</summary>
        public static TeamSetup Small5(string name, float level)
        {
            var t = new TeamSetup { Name = name, Keeper = SimStats.Generic(level, name + " Kaleci") };
            t.Slots.Add(new Vec2(0.26f, 0.22f)); t.Slots.Add(new Vec2(0.26f, 0.78f));
            t.Slots.Add(new Vec2(0.52f, 0.50f)); t.Slots.Add(new Vec2(0.78f, 0.50f));
            for (int i = 0; i < t.Slots.Count; i++) t.Outfield.Add(SimStats.Generic(level, name + " " + (i + 1)));
            return t;
        }
    }

    public class MatchWorldConfig
    {
        public PitchSpec Pitch = new PitchSpec { HalfLength = 30f, HalfWidth = 19f, GoalHalfWidth = 3.0f, GoalHeight = 2.2f, PenaltyAreaDepth = 9f, PenaltyAreaHalfWidth = 11f };
        public int Seed = 1;
        /// <summary>Gerçek saniye cinsinden devre süresi.</summary>
        public float HalfSeconds = 120f;
        public int Halves = 1;
        public TeamSetup Home = TeamSetup.Small5("Kanarya", 70f);
        public TeamSetup Away = TeamSetup.Small5("Rakip", 70f);
        /// <summary>Ev sahibi (insan) takımın kontrol ettiği oyuncu yoksa tüm oyuncular yapay zekâdır (AI-vs-AI testi).</summary>
        public bool HumanControlsHome = true;
        public bool AutoDefend;
        /// <summary>Devre arası ve maç sonu bekleme süresi (sunum için: banner/ ekran geçişi).</summary>
        public float BreakSeconds = 3f;
    }

    public class Agent
    {
        public PlayerBody Body;
        public int Team;
        public int Index;
        public Vec2 HomeNorm;
        public AgentRole Role;
        public float TackleCooldown;
        public float ThinkTimer;
        public float HoldTime;
        public int Id { get { return Body.Id; } }
        public string Name { get { return Body.Stats.DisplayName; } }
    }

    /// <summary>
    /// İki takımlı maç dünyası (T041/T042 temeli). Saf C#, deterministik. Aynı kod 5v5 ve 11v11 içindir (slot sayısına göre).
    /// Yapay zekâ: sahip takım destek koşusu yapar, rakip takım 1. savunmacıyla baskı yapar, 2. savunmacı örter,
    /// diğerleri dizilişe döner ve pas kanalı kapatır. İnsan oyuncu bir ajanı kontrol eder; DEĞİŞTİR, 2. DEF, OTO. (otomatik savunma) desteklenir.
    /// KURALLAR (faul, ofsayt, tam korner/taç) T044 kapsamındadır; burada yeniden başlatmalar basitleştirilmiştir.
    /// </summary>
    public class MatchWorld
    {
        public const int HomeKeeperId = 100, AwayKeeperId = 200;

        public readonly MatchWorldConfig Config;
        public readonly PitchSpec Pitch;
        public readonly BallBody Ball = new BallBody();
        public readonly MatchStateMachine Machine;
        public readonly MatchLog Log = new MatchLog();
        public readonly List<Agent> Agents = new List<Agent>();
        public readonly GoalkeeperAI[] Keepers = new GoalkeeperAI[2];
        public readonly float[] PossessionSeconds = new float[2];
        public readonly List<FieldEvent> Events = new List<FieldEvent>();

        public int ControlledId { get; private set; } = -1;
        public bool AutoDefend { get; private set; }
        public float Time { get; private set; }

        readonly SimRandom _rng;
        readonly TeamSetup[] _setup = new TeamSetup[2];
        readonly int[] _dir = { 1, -1 };
        readonly int[] _first = { -1, -1 }, _second = { -1, -1 }, _chaser = { -1, -1 };
        int _forcedSecondId = -1; float _forcedSecondTimer;
        int _lastTouchTeam = -1; string _lastToucher = "";
        bool _lastKickPass; int _lastKickTeam = -1, _passerId = -1, _receiverId = -1;
        int _kickingTeam;
        // yeniden başlatma
        bool _restartPending; Vec2 _restartSpot; int _restartTeam; float _restartTimer; bool _restartKeeper; bool _restartCorner;
        int _goalsThisHalf;
        bool _ended; float _hold;

        public MatchWorld(MatchWorldConfig cfg)
        {
            Config = cfg; Pitch = cfg.Pitch; _rng = new SimRandom(cfg.Seed);
            _setup[0] = cfg.Home; _setup[1] = cfg.Away;
            AutoDefend = cfg.AutoDefend;
            for (int t = 0; t < 2; t++)
            {
                var su = _setup[t];
                if (su.Outfield.Count != su.Slots.Count) throw new ArgumentException("Outfield ve Slots sayısı eşit olmalı: " + su.Name);
                for (int i = 0; i < su.Outfield.Count; i++)
                {
                    var hn = su.Slots[i];
                    var ag = new Agent
                    {
                        Team = t, Index = i, HomeNorm = hn,
                        Role = hn.X < 0.35f ? AgentRole.Def : (hn.X < 0.62f ? AgentRole.Mid : AgentRole.Att),
                        Body = new PlayerBody((t == 0 ? 1 : 21) + i, t == 0, su.Outfield[i], Vec2.Zero),
                    };
                    Agents.Add(ag);
                }
                Keepers[t] = new GoalkeeperAI(t == 0 ? HomeKeeperId : AwayKeeperId, su.Keeper, Pitch, _rng, t == 0 ? -1 : +1);
            }
            Machine = new MatchStateMachine(cfg.HalfSeconds, cfg.Halves);
            Machine.PhaseChanged += OnPhaseChanged;
            Machine.Begin(true);
        }

        // ---------------- sorgular ----------------
        public Agent AgentById(int id) { for (int i = 0; i < Agents.Count; i++) if (Agents[i].Id == id) return Agents[i]; return null; }
        public Agent Controlled { get { return AgentById(ControlledId); } }
        public Agent Carrier { get { return Ball.IsControlled ? AgentById(Ball.OwnerId) : null; } }
        public int TeamOfKeeperId(int id) { return id == HomeKeeperId ? 0 : (id == AwayKeeperId ? 1 : -1); }

        /// <summary>Topa sahip takım: 0/1; kimse yoksa -1. Kaleci elindeyken kalecinin takımı.</summary>
        public int PossessingTeam
        {
            get
            {
                if (!Ball.IsControlled) return -1;
                var a = AgentById(Ball.OwnerId); if (a != null) return a.Team;
                return TeamOfKeeperId(Ball.OwnerId);
            }
        }

        /// <summary>Ev sahibi (insan) takım açısından sahiplik.</summary>
        public BallOwnership Ownership
        {
            get { int t = PossessingTeam; return t == 0 ? BallOwnership.Ours : (t == 1 ? BallOwnership.Theirs : BallOwnership.Loose); }
        }

        public bool ControlledInOwnHalf { get { var c = Controlled; return c != null && c.Body.Pos.X * _dir[0] < 0f; } }
        public IReadOnlyList<HudButton> Hud { get { return HudLayout.ButtonsFor(Ownership, Machine.Phase, ControlledInOwnHalf, true); } }
        public float RemainingSeconds { get { return Math.Max(0f, Machine.PeriodEnd - Machine.ElapsedInHalf); } }
        /// <summary>Son golün metni: "Ad  34'" (kendi kalesine atılan için "(k.k.)" adın içindedir).</summary>
        public string LastGoalText
        {
            get
            {
                for (int i = Log.Events.Count - 1; i >= 0; i--)
                    if (Log.Events[i].Type == MatchEventType.Goal) return Log.Events[i].Actor + "  " + Log.Events[i].Minute + "'";
                return "";
            }
        }
        public int FirstDefender(int team) { return _first[team]; }
        public int SecondDefender(int team) { return _second[team]; }
        public int ForcedSecondDefenderId { get { return _forcedSecondTimer > 0 ? _forcedSecondId : -1; } }

        Vec2 OwnGoal(int team) { return new Vec2(-_dir[team] * Pitch.HalfLength, 0f); }
        Vec2 OppGoal(int team) { return new Vec2(_dir[team] * Pitch.HalfLength, 0f); }
        float Len { get { return Pitch.HalfLength * 2f; } }

        Vec2 HomeWorld(Agent a, float xShiftNorm = 0f, float maxX = 0.95f)
        {
            float xn = Math.Min(maxX, Math.Max(0.04f, a.HomeNorm.X + xShiftNorm));
            return NormToWorld(a.Team, xn, a.HomeNorm.Y);
        }

        Vec2 NormToWorld(int team, float xn, float yn)
        {
            int d = _dir[team];
            float x = d > 0 ? -Pitch.HalfLength + xn * Len : Pitch.HalfLength - xn * Len;
            float y = d * (0.5f - yn) * 2f * Pitch.HalfWidth;
            return new Vec2(x, y);
        }

        void Raise(FieldEventType t, int value = 0, Vec2 pos = default(Vec2)) { Events.Add(new FieldEvent { Type = t, Time = Time, Value = value, Pos = pos }); }
        public void DrainEvents(List<FieldEvent> into) { into.AddRange(Events); Events.Clear(); }

        // ---------------- başlangıç/santra ----------------
        void OnPhaseChanged(MatchPhase from, MatchPhase to)
        {
            Raise(FieldEventType.PhaseChanged, (int)to);
            if (to == MatchPhase.Kickoff) ResetToKickoff(_kickingTeam);
        }

        void ResetToKickoff(int kickingTeam)
        {
            _restartPending = false; _forcedSecondTimer = 0; _receiverId = -1;
            foreach (var a in Agents)
            {
                float xn = Math.Min(a.HomeNorm.X, 0.47f);
                a.Body.Pos = NormToWorld(a.Team, xn, a.HomeNorm.Y); a.Body.Vel = Vec2.Zero;
                a.Body.Facing = new Vec2(_dir[a.Team], 0); a.Body.Action = PlayerAction.None; a.Body.ActionTimer = 0;
                a.TackleCooldown = 0.8f; a.HoldTime = 0; a.ThinkTimer = 0.1f + 0.2f * _rng.Next01();
            }
            foreach (var k in Keepers) k.ResetPosition();
            // santra vuruşunu yapan: kickingTeam'in en ileri oyuncusu merkezde
            var taker = Agents.Where(a => a.Team == kickingTeam).OrderByDescending(a => a.HomeNorm.X).First();
            taker.Body.Pos = new Vec2(-_dir[kickingTeam] * 0.8f, 0f);
            Ball.Pos = Vec2.Zero; Ball.PrevPos = Vec2.Zero; Ball.Vel = Vec2.Zero; Ball.Z = 0; Ball.VZ = 0;
            GiveBall(taker);
            if (Config.HumanControlsHome && ControlledId < 0)
                ControlledId = Agents.Where(a => a.Team == 0).OrderByDescending(a => a.HomeNorm.X).First().Id;
        }

        /// <summary>Topu doğrudan bir oyuncuya verir (testler, serbest vuruş/taç kurulumu için).</summary>
        public void GiveBallTo(Agent a) { GiveBall(a); }

        void GiveBall(Agent a)
        {
            Ball.Take(a.Id); Ball.Pos = a.Body.Pos + a.Body.Facing * 0.62f; Ball.PrevPos = Ball.Pos;
            _lastTouchTeam = a.Team; _lastToucher = a.Name;
            if (a.Team == 0 && Config.HumanControlsHome) ControlledId = a.Id;
        }

        // ---------------- ana adım ----------------
        public void Step(float dt, PlayerInput input)
        {
            if (dt <= 0f) return;
            if (dt > 0.1f) dt = 0.1f;
            Time += dt;
            Machine.Tick(dt);
            if (Machine.Phase == MatchPhase.Replay) Machine.SkipReplay(); // tekrar T047'de; şimdilik atlanır
            var phase = Machine.Phase;
            if (phase == MatchPhase.Live) StepLive(dt, input);
            else if (phase == MatchPhase.GoalCelebration || phase == MatchPhase.Replay) StepDead(dt);
            if (Machine.Phase == MatchPhase.HalfTime)
            {
                _hold += dt;
                if (_hold >= Config.BreakSeconds) { _hold = 0f; _goalsThisHalf = 0; Machine.StartSecondHalf(); }
            }
            else if (Machine.Phase == MatchPhase.FullTime)
            {
                if (!_ended) { _ended = true; Raise(FieldEventType.SessionEnded, Machine.ScoreHome); }
                _hold += dt;
                if (_hold >= Config.BreakSeconds) { _hold = 0f; Machine.ShowResult(); }
            }
            else _hold = 0f;
        }

        void StepDead(float dt)
        {
            foreach (var a in Agents) a.Body.Step(dt, Vec2.Zero, false, false);
            if (!Ball.IsControlled) { Ball.StepFree(dt); ClampNet(); }
        }

        void ClampNet()
        {
            float maxX = Pitch.HalfLength + Pitch.GoalDepth - 0.3f;
            if (Math.Abs(Ball.Pos.X) > maxX) { Ball.Pos.X = Math.Sign(Ball.Pos.X) * maxX; Ball.Vel.X = 0; }
            if (Math.Abs(Ball.Pos.Y) > Pitch.GoalHalfWidth - 0.2f && Math.Abs(Ball.Pos.X) > Pitch.HalfLength)
            { Ball.Pos.Y = Math.Sign(Ball.Pos.Y) * (Pitch.GoalHalfWidth - 0.2f); Ball.Vel.Y = 0; }
        }

        void StepLive(float dt, PlayerInput input)
        {
            if (_forcedSecondTimer > 0) _forcedSecondTimer -= dt;
            if (_restartPending) { StepRestart(dt); }
            HandleHumanCommands(input);
            var carrier = Carrier;
            int poss = PossessingTeam;
            AssignRoles(poss, carrier);

            // insan komutları (top bizdeyse pas/şut vb.)
            var ctl = Controlled;
            if (ctl != null && !_restartPending)
            {
                if (carrier != null && carrier.Id == ctl.Id && ctl.Body.Action == PlayerAction.None)
                {
                    if (input.Shoot) HumanShoot(ctl, input);
                    else if (input.Clear) DoClear(ctl);
                    else if (input.Pass) HumanPass(ctl, input, false);
                    else if (input.ThroughPass) HumanPass(ctl, input, true);
                    else if (input.SkillDirection != 0) DoSkill(ctl, input.SkillDirection);
                }
                else if (!(poss == 0) && ctl.Body.Action == PlayerAction.None)
                {
                    if (input.Slide)
                    {
                        var dir = input.Move.Length > 0.3f ? input.Move.Normalized : ctl.Body.Facing;
                        ctl.Body.StartSlide(dir);
                    }
                    else if (input.Tackle) TryTackle(ctl, 0.10f, 1.8f);
                }
            }

            // hareket
            carrier = Carrier;
            foreach (var a in Agents)
            {
                Vec2 mv; bool sprint;
                bool human = ctl != null && a.Id == ctl.Id;
                bool auto = human && AutoDefend && PossessingTeam != 0;
                if (human && !auto) { mv = input.Move; sprint = input.Sprint; }
                else DecideMove(a, carrier, out mv, out sprint);
                bool has = Ball.IsControlled && Ball.OwnerId == a.Id;
                a.Body.Step(dt, mv, sprint, has);
                if (a.TackleCooldown > 0) a.TackleCooldown -= dt;
            }

            // kaleciler
            for (int t = 0; t < 2; t++)
            {
                var k = Keepers[t];
                var outcome = k.Step(dt, Ball);
                if (outcome != GkOutcome.None)
                {
                    Log.Add(MatchEventType.Save, t, k.Stats.DisplayName, Machine.DisplayMinute);
                    Raise(FieldEventType.Save, outcome == GkOutcome.Catch ? 1 : 0, k.Pos);
                    _lastTouchTeam = t; _lastToucher = k.Stats.DisplayName; _lastKickPass = false;
                }
                if (k.State == GkState.Recovering && Ball.IsControlled && Ball.OwnerId == k.Id) KeeperDistribute(t);
            }

            // top
            if (Ball.IsControlled)
            {
                var c = Carrier; if (c != null) CarryBall(c, dt);
            }
            else if (!_restartPending)
            {
                Ball.StepFree(dt);
                TryPickup();
            }
            else { Ball.Vel = Vec2.Zero; }

            AutoTackles();
            ResolveSlide();
            var cc = Carrier; int pt = PossessingTeam;
            if (pt >= 0) PossessionSeconds[pt] += dt;
            if (cc != null) cc.HoldTime += dt;
            CheckBoundaries();
            if (Ball.IsControlled && Ball.OwnerId != _passerId) { /* sahiplik değişti */ }
        }

        // ---------------- insan komutları ----------------
        void HandleHumanCommands(PlayerInput input)
        {
            if (input.ToggleAutoDefend) AutoDefend = !AutoDefend;
            if (input.Switch) SwitchPlayer(input.Move);
            if (input.CallSecondDefender) CallSecondDefender();
        }

        /// <summary>DEĞİŞTİR: topa en yakın (joystick yönü varsa o yöndeki en yakın) takım arkadaşına geç.</summary>
        public void SwitchPlayer(Vec2 stick)
        {
            var cur = Controlled; Vec2 refPos = Ball.Pos;
            Agent best = null; float bestScore = float.MaxValue;
            foreach (var a in Agents)
            {
                if (a.Team != 0 || (cur != null && a.Id == cur.Id)) continue;
                float d = Vec2.Distance(a.Body.Pos, refPos);
                float score = d;
                if (stick.Length > 0.4f)
                {
                    var rel = a.Body.Pos - (cur != null ? cur.Body.Pos : refPos);
                    float ang = Math.Abs(Vec2.SignedAngleDeg(stick, rel));
                    if (ang > 70f) continue;
                    score = d + ang * 0.1f;
                }
                if (score < bestScore) { bestScore = score; best = a; }
            }
            if (best != null) ControlledId = best.Id;
        }

        /// <summary>
        /// 2. DEF: birinci savunmacıdan sonra topa en yakın (insanın kontrol etmediği) takım arkadaşını 4 sn boyunca
        /// doğrudan baskıya çağırır. Normalde 2. savunmacı örtü yapar (taşıyıcı ile kale arasında); çağrılınca baskı yapar.
        /// </summary>
        public void CallSecondDefender()
        {
            var carrier = Carrier; if (carrier == null || carrier.Team == 0) return;
            var cand = Agents.Where(a => a.Team == 0 && !IsHumanDriven(a))
                             .OrderBy(a => Vec2.Distance(a.Body.Pos, carrier.Body.Pos)).ToList();
            if (cand.Count == 0) return;
            var pick = cand.Count > 1 ? cand[1] : cand[0];
            _forcedSecondId = pick.Id; _forcedSecondTimer = 4f;
        }

        // ---------------- roller ----------------
        void AssignRoles(int poss, Agent carrier)
        {
            for (int t = 0; t < 2; t++)
            {
                _first[t] = _second[t] = _chaser[t] = -1;
                var cand = Agents.Where(a => a.Team == t && !IsHumanDriven(a)).ToList();
                if (poss >= 0 && poss != t && carrier != null)
                {
                    cand.Sort((x, y) => Vec2.Distance(x.Body.Pos, carrier.Body.Pos).CompareTo(Vec2.Distance(y.Body.Pos, carrier.Body.Pos)));
                    if (cand.Count > 0) _first[t] = cand[0].Id;
                    if (t == 0 && ForcedSecondDefenderId >= 0 && cand.Any(c => c.Id == ForcedSecondDefenderId && c.Id != _first[t])) _second[t] = ForcedSecondDefenderId;
                    else if (cand.Count > 1) _second[t] = cand[1].Id;
                }
                else if (poss < 0 && !_restartPending)
                {
                    Agent best = null; float bt = float.MaxValue;
                    foreach (var a in cand)
                    {
                        float tt = Vec2.Distance(a.Body.Pos, Ball.Pos + Ball.Vel * 0.3f) / Math.Max(4f, a.Body.MaxSpeed(true, false));
                        if (a.Id == _receiverId) tt -= 0.35f;
                        if (tt < bt) { bt = tt; best = a; }
                    }
                    if (best != null) _chaser[t] = best.Id;
                }
            }
        }

        bool IsHumanDriven(Agent a)
        {
            if (!Config.HumanControlsHome || a.Id != ControlledId) return false;
            return !(AutoDefend && PossessingTeam != 0);
        }

        // ---------------- hareket kararı ----------------
        void DecideMove(Agent a, Agent carrier, out Vec2 mv, out bool sprint)
        {
            sprint = false; int poss = PossessingTeam;
            if (_restartPending) { mv = Seek(a, HoldPosition(a), 2f, out sprint); return; }
            if (carrier != null && carrier.Id == a.Id) { CarrierAI(a, out mv, out sprint); return; }
            if (poss == a.Team) { AttackOffBall(a, carrier, out mv, out sprint); return; }
            if (poss >= 0) { DefendAI(a, carrier, out mv, out sprint); return; }
            // serbest top
            if (_chaser[a.Team] == a.Id)
            {
                float d = Vec2.Distance(a.Body.Pos, Ball.Pos);
                var tgt = Ball.Pos + Ball.Vel * Math.Min(0.9f, d / 8f);
                mv = Seek(a, tgt, 1f, out sprint); sprint = a.Body.Stamina > 0.15f; return;
            }
            mv = Seek(a, ShapePosition(a, 0f), 3f, out sprint);
        }

        Vec2 HoldPosition(Agent a) { return a.Body.Pos; }

        Vec2 Seek(Agent a, Vec2 target, float arrive, out bool sprint)
        {
            var rel = target - a.Body.Pos; float d = rel.Length;
            sprint = d > 11f && a.Body.Stamina > 0.35f;
            if (d < 0.25f) return Vec2.Zero;
            float f = Math.Min(1f, d / Math.Max(0.5f, arrive));
            var mv = rel / d * f;
            // takım arkadaşlarından ayrışma: top başında yığılmayı önler
            var sep = Separation(a, 3.6f);
            mv = mv + sep * 1.1f;
            return Vec2.ClampMagnitude(mv, 1f);
        }

        Vec2 Separation(Agent a, float radius)
        {
            Vec2 s = Vec2.Zero;
            foreach (var m in Agents)
            {
                if (m.Team != a.Team || m.Id == a.Id) continue;
                var r = a.Body.Pos - m.Body.Pos; float d = r.Length;
                if (d < radius && d > 1e-3f) s = s + r / d * ((radius - d) / radius);
            }
            return s;
        }

        /// <summary>Topsuz oyuncunun dizilişteki yeri: topa doğru bir miktar kayar; savunmada geri çekilir.</summary>
        Vec2 ShapePosition(Agent a, float attackShift)
        {
            var home = HomeWorld(a, attackShift);
            var toBall = Ball.Pos - home;
            float pull = a.Role == AgentRole.Def ? 0.14f : (a.Role == AgentRole.Mid ? 0.22f : 0.18f);
            var p = home + toBall * pull;
            // kendi yarı sahada savunmacıyı topun gerisinde tut
            return ClampToPitch(p);
        }

        Vec2 ClampToPitch(Vec2 p)
        {
            p.X = MathUtil.Clamp(p.X, -Pitch.HalfLength + 1f, Pitch.HalfLength - 1f);
            p.Y = MathUtil.Clamp(p.Y, -Pitch.HalfWidth + 1f, Pitch.HalfWidth - 1f);
            return p;
        }

        void AttackOffBall(Agent a, Agent carrier, out Vec2 mv, out bool sprint)
        {
            int d = _dir[a.Team];
            var refPos = carrier != null ? carrier.Body.Pos : Ball.Pos;
            float progress = MathUtil.Clamp01((refPos.X * d + Pitch.HalfLength) / Len);
            float shift = (a.Role == AgentRole.Att ? 0.30f : (a.Role == AgentRole.Mid ? 0.20f : 0.08f)) * (0.4f + 0.6f * progress);
            var target = ShapePosition(a, shift);
            if (carrier != null && a.Role != AgentRole.Def)
            {
                // destek koşusu: taşıyıcıya en yakın iki hücum/orta oyuncudan biriysen açık bir noktaya koş
                var mates = Agents.Where(m => m.Team == a.Team && m.Id != carrier.Id && m.Role != AgentRole.Def)
                                  .OrderBy(m => Vec2.Distance(m.Body.Pos, carrier.Body.Pos)).Take(2).ToList();
                int idx = mates.FindIndex(m => m.Id == a.Id);
                if (idx >= 0)
                {
                    float side = (idx == 0 ? 1f : -1f) * (a.Index % 2 == 0 ? 1f : -1f);
                    var run = carrier.Body.Pos + new Vec2(d * 8f, side * 7f);
                    // rakipten uzak dur
                    var near = NearestOpponent(a.Team, run);
                    if (near != null && Vec2.Distance(near.Body.Pos, run) < 4f) run = run + (run - near.Body.Pos).Normalized * 3f;
                    target = ClampToPitch(target * 0.35f + run * 0.65f);
                }
            }
            mv = Seek(a, target, 3f, out sprint);
        }

        void DefendAI(Agent a, Agent carrier, out Vec2 mv, out bool sprint)
        {
            int t = a.Team; var cpos = carrier != null ? carrier.Body.Pos : Ball.Pos;
            if (_first[t] == a.Id)
            {
                var tgt = cpos + (carrier != null ? carrier.Body.Vel * 0.3f : Vec2.Zero);
                mv = Seek(a, tgt, 1.2f, out sprint); sprint = Vec2.Distance(a.Body.Pos, cpos) > 4.5f && a.Body.Stamina > 0.2f; return;
            }
            if (_second[t] == a.Id && a.Team == 0 && a.Id == ForcedSecondDefenderId)
            {
                // 2. DEF çağrısı: örtü yerine doğrudan baskı
                var tgt = cpos + (carrier != null ? carrier.Body.Vel * 0.3f : Vec2.Zero);
                mv = Seek(a, tgt, 1.2f, out sprint); sprint = Vec2.Distance(a.Body.Pos, cpos) > 3.5f && a.Body.Stamina > 0.2f; return;
            }
            if (_second[t] == a.Id)
            {
                // örtü: topla kendi kalesi arasında, birinci savunmacının gerisinde
                var og = OwnGoal(t); var toGoal = (og - cpos).Normalized;
                var tgt = cpos + toGoal * 5.5f + new Vec2(0, (a.Index % 2 == 0 ? 1f : -1f) * 2.0f);
                mv = Seek(a, ClampToPitch(tgt), 2f, out sprint); sprint = Vec2.Distance(a.Body.Pos, tgt) > 8f; return;
            }
            // pas kanalı kapatma: topa en yakın tehlikeli rakip alıcıyı seç
            var recv = ThreatenedReceiver(a, cpos);
            if (recv != null)
            {
                var lane = (cpos - recv.Body.Pos); float ld = lane.Length;
                var tgt = recv.Body.Pos + (ld > 1e-3f ? lane / ld : Vec2.Zero) * Math.Min(3.0f, ld * 0.35f);
                // kaleye doğru bir miktar kay (kaleyle alıcı arasında dur)
                tgt = tgt + (OwnGoal(t) - recv.Body.Pos).Normalized * 1.2f;
                mv = Seek(a, ClampToPitch(tgt), 2.5f, out sprint); return;
            }
            // dizilişe dön: kendi yarı sahaya doğru geri çekilmiş şekil
            var shape = ShapePosition(a, -0.10f * (0.5f + 0.5f * Pressing(t)));
            mv = Seek(a, shape, 3f, out sprint);
        }

        float Pressing(int t) { return _setup[t].Pressing; }

        Agent ThreatenedReceiver(Agent a, Vec2 cpos)
        {
            // Her savunmacı, kendisine en yakın ve henüz başkasınca işaretlenmemiş rakip alıcıyı seçer (basit atama).
            Agent best = null; float bd = float.MaxValue;
            foreach (var o in Agents)
            {
                if (o.Team == a.Team) continue;
                if (Ball.IsControlled && o.Id == Ball.OwnerId) continue;
                if (Vec2.Distance(o.Body.Pos, cpos) > Len * 0.55f) continue;
                float d = Vec2.Distance(o.Body.Pos, a.Body.Pos);
                // daha yakın bir takım arkadaşı varsa o işaretlesin
                bool taken = false;
                foreach (var m in Agents)
                {
                    if (m.Team != a.Team || m.Id == a.Id || m.Id == _first[a.Team] || m.Id == _second[a.Team]) continue;
                    if (Vec2.Distance(o.Body.Pos, m.Body.Pos) < d - 0.5f) { taken = true; break; }
                }
                if (taken) continue;
                if (d < bd) { bd = d; best = o; }
            }
            return best;
        }

        Agent NearestOpponent(int team, Vec2 pos)
        {
            Agent best = null; float bd = float.MaxValue;
            foreach (var o in Agents) { if (o.Team == team) continue; float d = Vec2.Distance(o.Body.Pos, pos); if (d < bd) { bd = d; best = o; } }
            return best;
        }

        // ---------------- top taşıyıcı yapay zekâsı ----------------
        void CarrierAI(Agent a, out Vec2 mv, out bool sprint)
        {
            int t = a.Team; int d = _dir[t]; var pos = a.Body.Pos; var oppGoal = OppGoal(t);
            a.ThinkTimer -= 0.0166f;
            var nearOpp = NearestOpponent(t, pos);
            float dOpp = nearOpp == null ? 99f : Vec2.Distance(nearOpp.Body.Pos, pos);
            bool pressure = dOpp < 3.2f;
            if (a.ThinkTimer <= 0f)
            {
                a.ThinkTimer = 0.22f + 0.2f * _rng.Next01();
                float distGoal = Vec2.Distance(pos, oppGoal);
                float range = Math.Min(30f, 0.46f * Len);
                if (distGoal < range && GoalLaneOpen(a))
                {
                    float p = (1f - distGoal / range) * 0.55f + 0.08f;
                    if (_rng.Next01() < p) { AIShoot(a); mv = Vec2.Zero; sprint = false; return; }
                }
                bool ownThird = pos.X * d < -Pitch.HalfLength * 0.30f;
                if (ownThird && pressure && _rng.Next01() < 0.55f) { DoClear(a); mv = Vec2.Zero; sprint = false; return; }
                Agent best; float score; BestPassTarget(a, out best, out score);
                if (best != null && (pressure || a.HoldTime > 1.4f || score > 0.62f))
                {
                    if (pressure || score > 0.3f) { AIPass(a, best); mv = Vec2.Zero; sprint = false; return; }
                }
            }
            // top sürme: rakip kaleye, rakipten kaçınarak
            var dir = (oppGoal - pos).Normalized;
            if (nearOpp != null && dOpp < 6f)
            {
                var away = (pos - nearOpp.Body.Pos).Normalized;
                dir = (dir + away * 0.9f).Normalized;
            }
            // saha kenarlarından uzak dur
            if (Math.Abs(pos.Y) > Pitch.HalfWidth - 3f) dir = (dir + new Vec2(0, -Math.Sign(pos.Y) * 0.8f)).Normalized;
            mv = dir * 0.92f; sprint = dOpp > 8f && a.Body.Stamina > 0.45f;
        }

        bool GoalLaneOpen(Agent a)
        {
            var g = OppGoal(a.Team); var p = a.Body.Pos;
            foreach (var o in Agents) { if (o.Team == a.Team) continue; if (DistToSegment(o.Body.Pos, p, g) < 1.6f && Vec2.Distance(o.Body.Pos, p) < Vec2.Distance(p, g)) return false; }
            return true;
        }

        static float DistToSegment(Vec2 pt, Vec2 a, Vec2 b)
        {
            var ab = b - a; float l2 = ab.SqrLength; if (l2 < 1e-6f) return Vec2.Distance(pt, a);
            float t = MathUtil.Clamp01(Vec2.Dot(pt - a, ab) / l2);
            return Vec2.Distance(pt, a + ab * t);
        }

        void BestPassTarget(Agent a, out Agent best, out float bestScore)
        {
            best = null; bestScore = -99f; int d = _dir[a.Team];
            foreach (var m in Agents)
            {
                if (m.Team != a.Team || m.Id == a.Id) continue;
                var rel = m.Body.Pos - a.Body.Pos; float dist = rel.Length; if (dist < 4f || dist > 34f) continue;
                float forward = rel.X * d / dist;                       // -1..1
                var near = NearestOpponent(a.Team, m.Body.Pos);
                float open = near == null ? 1f : MathUtil.Clamp01(Vec2.Distance(near.Body.Pos, m.Body.Pos) / 8f);
                bool blocked = false;
                foreach (var o in Agents) { if (o.Team == a.Team) continue; if (DistToSegment(o.Body.Pos, a.Body.Pos, m.Body.Pos) < 1.7f) { blocked = true; break; } }
                if (blocked) continue;
                float dscore = 1f - Math.Abs(dist - 14f) / 30f;
                float score = 0.42f * (forward + 1f) * 0.5f + 0.38f * open + 0.20f * dscore;
                if (score > bestScore) { bestScore = score; best = m; }
            }
        }

        // ---------------- vuruşlar ----------------
        void RegisterKick(Agent a, bool pass, int receiverId)
        {
            _lastTouchTeam = a.Team; _lastToucher = a.Name; _lastKickPass = pass; _lastKickTeam = a.Team; _passerId = a.Id; _receiverId = receiverId;
        }

        void AIPass(Agent a, Agent target)
        {
            var tp = target.Body.Pos + target.Body.Vel * 0.5f;
            var rel = tp - a.Body.Pos;
            float speed = BallPhysics.SpeedForDistance(rel.Length * 1.12f, 30f);
            float sigma = MathUtil.Lerp(5.5f, 1.2f, a.Body.Stats.Passing / 99f) * (1f + (1f - a.Body.Stamina) * 0.6f);
            var dir = rel.Normalized.Rotated(_rng.NextSigned() * sigma * 1.7f * MathUtil.Deg2Rad);
            Ball.Kick(dir * speed, 0f, a.Id, 0.35f);
            RegisterKick(a, true, target.Id);
            Log.Add(MatchEventType.Pass, a.Team, a.Name, Machine.DisplayMinute);
            a.HoldTime = 0;
        }

        void AIShoot(Agent a)
        {
            var g = OppGoal(a.Team);
            float aimY = (_rng.Next01() < 0.5f ? -1f : 1f) * Pitch.GoalHalfWidth * (0.35f + 0.5f * _rng.Next01());
            var dir = (new Vec2(g.X, aimY) - a.Body.Pos).Normalized;
            Shoot(a, dir, 0.55f + 0.4f * _rng.Next01());
        }

        void Shoot(Agent a, Vec2 dir, float power)
        {
            float sh = a.Body.Stats.Shooting / 99f;
            float speed = MathUtil.Lerp(14f, 32f, power) * (0.9f + 0.1f * sh);
            float sigma = MathUtil.Lerp(9f, 2f, sh) * (0.5f + power * 0.9f) * (a.Body.Speed > 7f ? 1.25f : 1f);
            dir = dir.Rotated(_rng.NextSigned() * sigma * 1.7f * MathUtil.Deg2Rad);
            float vz = MathUtil.Lerp(0.3f, 4.2f, power) * (0.5f + 0.8f * _rng.Next01());
            Ball.Kick(dir * speed, vz, a.Id, 0.35f);
            RegisterKick(a, false, -1);
            Log.Add(MatchEventType.Shot, a.Team, a.Name, Machine.DisplayMinute);
            bool onTarget = EstimateOnTarget(a.Team);
            if (onTarget) { Log.Add(MatchEventType.ShotOnTarget, a.Team, a.Name, Machine.DisplayMinute); Raise(FieldEventType.ShotOnTarget, a.Team, Ball.Pos); }
            else Raise(FieldEventType.ShotOffTarget, a.Team, Ball.Pos);
            a.HoldTime = 0;
        }

        bool EstimateOnTarget(int team)
        {
            int d = _dir[team]; if (Ball.Vel.X * d <= 0.5f) return false;
            float t = (d * Pitch.HalfLength - Ball.Pos.X) / Ball.Vel.X;
            float y = Ball.Pos.Y + Ball.Vel.Y * t;
            float z = Ball.Z + Ball.VZ * t - 0.5f * BallPhysics.Gravity * t * t;
            return Math.Abs(y) < Pitch.GoalHalfWidth && z > 0f && z < Pitch.GoalHeight;
        }

        /// <summary>UZAKLAŞTIR: topu rakip yarı sahaya, kenara doğru uzağa vurur (G37).</summary>
        public void DoClear(Agent a)
        {
            int d = _dir[a.Team];
            float side = a.Body.Pos.Y >= 0 ? 1f : -1f;
            var dir = new Vec2(d, side * 0.55f).Normalized;
            Ball.Kick(dir * 24f, 4f, a.Id, 0.45f);
            RegisterKick(a, false, -1);
            a.HoldTime = 0;
        }

        void HumanPass(Agent a, PlayerInput input, bool through)
        {
            var aim = input.Move.Length > 0.3f ? input.Move.Normalized : a.Body.Facing;
            var mates = Agents.Where(m => m.Team == a.Team && m.Id != a.Id).ToList();
            var cands = mates.Select(m => m.Body.Pos).ToList();
            int idx = PassTargeting.Pick(a.Body.Pos, aim, cands);
            float power = MathUtil.Clamp01(input.Power);
            Vec2 dir; float speed;
            Agent target = idx >= 0 ? mates[idx] : null;
            if (target != null)
            {
                var tp = target.Body.Pos + target.Body.Vel * (through ? 1.0f : 0.5f) + (through ? new Vec2(_dir[a.Team] * 3f, 0) : Vec2.Zero);
                var rel = tp - a.Body.Pos; dir = rel.Normalized;
                speed = BallPhysics.SpeedForDistance(rel.Length * 1.12f, 30f) * (0.88f + 0.24f * power);
            }
            else { dir = aim; speed = MathUtil.Lerp(9f, 26f, power); }
            if (through) speed *= 1.12f;
            float sigma = MathUtil.Lerp(5.5f, 1.2f, a.Body.Stats.Passing / 99f) * (1f + (1f - a.Body.Stamina) * 0.6f) * (power > 0.85f ? 1.25f : 1f);
            dir = dir.Rotated(_rng.NextSigned() * sigma * 1.7f * MathUtil.Deg2Rad);
            Ball.Kick(dir * speed, through ? 2.2f : 0f, a.Id, 0.35f);
            RegisterKick(a, true, target != null ? target.Id : -1);
            Log.Add(MatchEventType.Pass, a.Team, a.Name, Machine.DisplayMinute);
        }

        void HumanShoot(Agent a, PlayerInput input)
        {
            float power = MathUtil.Clamp(input.Power, 0.2f, 1f);
            var g = OppGoal(a.Team); var toGoal = (g - a.Body.Pos).Normalized;
            var dir = input.Move.Length > 0.3f ? input.Move.Normalized : toGoal;
            if (Math.Abs(Vec2.SignedAngleDeg(toGoal, dir)) < 30f) dir = (dir * 0.6f + toGoal * 0.4f).Normalized;
            Shoot(a, dir, power);
        }

        void DoSkill(Agent a, int direction)
        {
            var sm = Fenerbahce.Core.Domain.SkillMoves.Get(Fenerbahce.Core.Domain.SkillMoves.DirectionChange);
            if (a.Body.SkillCooldown > 0f || a.Body.Stats.SkillStars < sm.MinSkillStars) return;
            float ang = -Math.Sign(direction) * 70f * MathUtil.Deg2Rad;
            var nf = a.Body.Facing.Rotated(ang);
            a.Body.Facing = nf; a.Body.Vel = nf * Math.Max(a.Body.Speed, 5f) * 1.05f;
            a.Body.Action = PlayerAction.Skill; a.Body.ActionTimer = sm.ContactTimeSeconds + sm.RecoverySeconds; a.Body.SkillCooldown = sm.CooldownSeconds;
            Ball.Pos = a.Body.Pos + nf * 0.62f;
            Raise(FieldEventType.SkillPerformed, direction, a.Body.Pos);
        }

        void KeeperDistribute(int team)
        {
            var k = Keepers[team];
            Agent best = null; float bs = -99f;
            foreach (var m in Agents)
            {
                if (m.Team != team) continue;
                var near = NearestOpponent(team, m.Body.Pos);
                float open = near == null ? 1f : MathUtil.Clamp01(Vec2.Distance(near.Body.Pos, m.Body.Pos) / 8f);
                float score = open - Math.Abs(Vec2.Distance(m.Body.Pos, k.Pos) - 14f) / 40f;
                if (score > bs) { bs = score; best = m; }
            }
            if (best != null) { k.Distribute(Ball, best.Body.Pos); _receiverId = best.Id; _lastKickPass = true; _lastKickTeam = team; _passerId = k.Id; }
            else k.Distribute(Ball, OppGoal(team));
        }

        // ---------------- sahiplik/çelme ----------------
        void CarryBall(Agent a, float dt)
        {
            var carry = a.Body.Pos + a.Body.Facing * 0.62f;
            Ball.PrevPos = Ball.Pos;
            Ball.Pos = Vec2.MoveTowards(Ball.Pos, carry, (30f + a.Body.Speed * 1.5f) * dt);
            Ball.Vel = a.Body.Vel; Ball.Z = 0; Ball.VZ = 0;
        }

        void TryPickup()
        {
            if (Ball.Z > 0.9f || Ball.Vel.Length > 18f) return;
            Agent best = null; float bd = 0.9f;
            foreach (var a in Agents)
            {
                if (Ball.LockedId == a.Id && Ball.LockTimer > 0f) continue;
                if (a.Body.Action == PlayerAction.Sliding || a.Body.Action == PlayerAction.Recovering) continue;
                float d = Vec2.Distance(a.Body.Pos, Ball.Pos);
                if (d < bd) { bd = d; best = a; }
            }
            if (best != null) TakeBall(best);
        }

        void TakeBall(Agent a)
        {
            bool completed = _lastKickPass && _lastKickTeam == a.Team && a.Id != _passerId && _passerId < HomeKeeperId + 1000;
            Ball.Take(a.Id);
            if (completed) Log.Add(MatchEventType.PassCompleted, a.Team, a.Name, Machine.DisplayMinute);
            _lastKickPass = false; _receiverId = -1;
            _lastTouchTeam = a.Team; _lastToucher = a.Name; a.HoldTime = 0;
            if (a.Team == 0 && Config.HumanControlsHome) ControlledId = a.Id; // kontrol topu izler
        }

        void AutoTackles()
        {
            var c = Carrier; if (c == null) return;
            foreach (var o in Agents)
            {
                if (o.Team == c.Team || o.TackleCooldown > 0f) continue;
                if (Vec2.Distance(o.Body.Pos, Ball.Pos) > 1.1f) continue;
                bool human = Config.HumanControlsHome && o.Id == ControlledId;
                if (human && !AutoDefend) continue; // insan yalnız komutla çeler
                TryTackle(o, 0f, 1.1f);
                break;
            }
        }

        bool TryTackle(Agent t, float bonus, float range)
        {
            var c = Carrier; if (c == null || c.Team == t.Team) return false;
            if (t.TackleCooldown > 0f) return false;
            if (Vec2.Distance(t.Body.Pos, c.Body.Pos) > range) return false;
            t.TackleCooldown = 1.0f;
            float p = 0.28f + 0.4f * (Pressing(t.Team) - 0.5f) + 0.3f * (t.Body.Stats.Defending - c.Body.Stats.Dribbling) / 99f + bonus;
            if (c.Body.Action == PlayerAction.Skill) p -= 0.25f;
            if (c.Body.Speed > 7f) p -= 0.05f;
            p = MathUtil.Clamp(p, 0.05f, 0.85f);
            if (_rng.Next01() < p)
            {
                TakeBall(t);
                Raise(t.Team == 0 ? FieldEventType.TackleWon : FieldEventType.BallLost, t.Team, t.Body.Pos);
                return true;
            }
            Raise(FieldEventType.TackleMissed, t.Team, t.Body.Pos);
            return false;
        }

        void ResolveSlide()
        {
            foreach (var s in Agents)
            {
                if (s.Body.Action != PlayerAction.Sliding) continue;
                var c = Carrier;
                if (c == null || c.Team == s.Team) continue;
                var rel = c.Body.Pos - s.Body.Pos;
                if (rel.Length < 1.5f && Vec2.Dot(s.Body.SlideDir, rel.Normalized) > 0.2f && s.TackleCooldown <= 0f)
                {
                    s.TackleCooldown = 1.0f;
                    float p = MathUtil.Clamp(0.55f + 0.35f * (s.Body.Stats.Defending - c.Body.Stats.Dribbling) / 99f, 0.3f, 0.9f);
                    if (_rng.Next01() < p)
                    {
                        Ball.SetFree(c.Body.Pos + s.Body.SlideDir * 0.4f, s.Body.SlideDir * 5f);
                        Ball.LastTouchId = s.Id; Ball.LockedId = c.Id; Ball.LockTimer = 0.8f;
                        _lastTouchTeam = s.Team; _lastToucher = s.Name; _lastKickPass = false;
                        Raise(FieldEventType.TackleWon, s.Team, c.Body.Pos);
                    }
                    else Raise(FieldEventType.TackleMissed, s.Team, s.Body.Pos);
                }
            }
        }

        // ---------------- sınırlar / gol / yeniden başlatma ----------------
        void CheckBoundaries()
        {
            if (Ball.IsControlled || _restartPending) return;
            float L = Pitch.HalfLength;
            // gol çizgisi geçişi
            foreach (int side in new[] { 1, -1 })
            {
                bool crossed = side > 0 ? (Ball.PrevPos.X < L && Ball.Pos.X >= L) : (Ball.PrevPos.X > -L && Ball.Pos.X <= -L);
                if (!crossed) continue;
                float t = (side * L - Ball.PrevPos.X) / (Math.Abs(Ball.Pos.X - Ball.PrevPos.X) < 1e-5f ? 1e-5f : (Ball.Pos.X - Ball.PrevPos.X));
                float yc = Ball.PrevPos.Y + t * (Ball.Pos.Y - Ball.PrevPos.Y);
                float zc = Ball.PrevZ + t * (Ball.Z - Ball.PrevZ);
                float gw = Pitch.GoalHalfWidth, bar = Pitch.GoalHeight;
                bool post = (Math.Abs(Math.Abs(yc) - gw) < 0.12f && zc < bar + 0.1f) || (Math.Abs(yc) < gw + 0.1f && Math.Abs(zc - bar) < 0.12f);
                if (post)
                {
                    Ball.Vel = new Vec2(-side * Math.Abs(Ball.Vel.X) * 0.5f, Ball.Vel.Y * 0.8f);
                    Ball.Pos = new Vec2(side * (L - 0.25f), Ball.Pos.Y);
                    Raise(FieldEventType.PostHit, 0, Ball.Pos); return;
                }
                if (Math.Abs(yc) < gw && zc < bar)
                {
                    int scorer = side > 0 ? 0 : 1; // +X kalesine giren gol Home'un
                    if (Machine.RegisterGoal(scorer == 0))
                    {
                        Log.Add(MatchEventType.Goal, scorer, _lastTouchTeam == scorer ? _lastToucher : _lastToucher + " (k.k.)", Machine.DisplayMinute);
                        _kickingTeam = 1 - scorer; _goalsThisHalf++;
                        Machine.StoppageSeconds = Math.Min(20f, 4f * _goalsThisHalf);
                        Raise(FieldEventType.GoalScored, scorer, new Vec2(side * L, yc));
                    }
                    return;
                }
                // çizgi dışı: kale vuruşu veya korner
                int defTeam = side > 0 ? 1 : 0;
                if (_lastTouchTeam == defTeam) StartRestart(new Vec2(side * (L - 0.6f), Math.Sign(Ball.Pos.Y == 0 ? 1 : Ball.Pos.Y) * (Pitch.HalfWidth - 0.6f)), 1 - defTeam, false, true);
                else StartRestart(new Vec2(side * (L - 5.5f), 0f), defTeam, true, false);
                Raise(FieldEventType.BallOut, 0, Ball.Pos);
                return;
            }
            if (Math.Abs(Ball.Pos.Y) > Pitch.HalfWidth)
            {
                int team = _lastTouchTeam == 0 ? 1 : 0; // taç: son dokunmanın rakibi
                StartRestart(new Vec2(MathUtil.Clamp(Ball.Pos.X, -L + 1f, L - 1f), Math.Sign(Ball.Pos.Y) * (Pitch.HalfWidth - 0.4f)), team, false, false);
                Raise(FieldEventType.BallOut, 0, Ball.Pos);
            }
        }

        void StartRestart(Vec2 spot, int team, bool keeperTakes, bool corner)
        {
            _restartPending = true; _restartSpot = spot; _restartTeam = team; _restartTimer = 1.0f; _restartKeeper = keeperTakes; _restartCorner = corner;
            Ball.SetFree(spot, Vec2.Zero);
            if (corner) Log.Add(MatchEventType.Corner, team, "", Machine.DisplayMinute);
        }

        void StepRestart(float dt)
        {
            _restartTimer -= dt;
            Ball.Pos = _restartSpot; Ball.Vel = Vec2.Zero;
            if (_restartTimer > 0f) return;
            _restartPending = false;
            if (_restartKeeper)
            {
                var k = Keepers[_restartTeam]; k.Hold(Ball, 0.8f); _lastTouchTeam = _restartTeam; return;
            }
            var taker = Agents.Where(a => a.Team == _restartTeam).OrderBy(a => Vec2.Distance(a.Body.Pos, _restartSpot)).First();
            taker.Body.Pos = _restartSpot + (new Vec2(0, 0) - _restartSpot).Normalized * 0.7f; taker.Body.Vel = Vec2.Zero;
            taker.Body.Facing = (Vec2.Zero - _restartSpot).Normalized;
            GiveBall(taker);
        }

        // ---------------- sonuç ----------------
        /// <summary>Faul/ofsayt T044'e kadar üretilmez → RulesStatsAvailable=false (0 değil "veri yok").</summary>
        public MatchResult BuildResult() { return MatchResultBuilder.Build(Log, PossessionSeconds[0], PossessionSeconds[1], false); }
    }
}
