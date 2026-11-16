using System;
using System.Collections.Generic;
using Fenerbahce.Core.Match;

namespace Fenerbahce.Core.Sim
{
    /// <summary>
    /// İlk oynanabilir top-kontrol sahası (T021–T027, T031, T043 kısmen): 1 oyuncu + top + kaleci + isteğe bağlı rakip savunmacı.
    /// Tamamen deterministik saf C#; Unity yalnızca bu durumu çizer ve girdiyi besler.
    /// Bu bir TAM MAÇ DEĞİLDİR: 11v11, faul, ofsayt, korner vb. F3 (T041–T048) kapsamındadır.
    /// </summary>
    public class ControlField
    {
        public const int PlayerId = 1, DefenderId = 2, KeeperId = 3;

        public readonly ControlFieldConfig Config;
        public readonly PitchSpec Pitch;
        public readonly BallBody Ball = new BallBody();
        public readonly PlayerBody Player;
        public readonly PlayerBody Defender;
        public readonly DefenderBot DefenderAI;
        public readonly GoalkeeperAI Keeper;
        public readonly MatchStateMachine Machine;
        public readonly FieldStats Stats = new FieldStats();
        public readonly float[] TargetFlash;
        public int SelectedTarget { get; private set; } = -1;
        public float Time { get; private set; }

        readonly SimRandom _rng;
        readonly List<FieldEvent> _events = new List<FieldEvent>();
        int _passId, _countedPassId = -1;
        bool _lastKickWasPass;
        float _outTimer;
        bool _slideResolved;
        bool _sessionEndRaised;

        public ControlField(ControlFieldConfig cfg, SimStats attacker, SimStats keeper)
        {
            Config = cfg; Pitch = cfg.Pitch; _rng = new SimRandom(cfg.Seed);
            Player = new PlayerBody(PlayerId, true, attacker, new Vec2(12, 0));
            var defStats = SimStats.Generic(60f + 25f * cfg.DefenderLevel, "Rakip Savunmacı");
            Defender = new PlayerBody(DefenderId, false, defStats, new Vec2(30, 6)) { Facing = new Vec2(-1, 0) };
            DefenderAI = new DefenderBot(Defender, new Vec2(30, 0), cfg.DefenderLevel);
            Keeper = new GoalkeeperAI(KeeperId, keeper, Pitch, _rng);
            TargetFlash = new float[cfg.PassTargets.Count];
            Machine = new MatchStateMachine(cfg.SessionSeconds, 1);
            Machine.PhaseChanged += OnPhaseChanged;
            Machine.Begin(true);
        }

        // ---------- dışa açık durum ----------
        public BallOwnership Ownership
        {
            get
            {
                if (Ball.IsControlled) return Ball.OwnerId == PlayerId ? BallOwnership.Ours : BallOwnership.Theirs;
                return BallOwnership.Loose;
            }
        }

        public IReadOnlyList<HudButton> Hud { get { return HudLayout.ButtonsFor(Ownership, Machine.Phase); } }
        public float RemainingSeconds { get { return Math.Max(0f, Machine.HalfLengthSeconds - Machine.ElapsedInHalf); } }
        public bool HasBall { get { return Ball.IsControlled && Ball.OwnerId == PlayerId; } }

        public void DrainEvents(List<FieldEvent> into) { into.AddRange(_events); _events.Clear(); }

        void Raise(FieldEventType t, int value = 0, Vec2 pos = default(Vec2))
        {
            _events.Add(new FieldEvent { Type = t, Time = Time, Value = value, Pos = pos });
        }

        void OnPhaseChanged(MatchPhase from, MatchPhase to)
        {
            Raise(FieldEventType.PhaseChanged, (int)to);
            if (to == MatchPhase.Kickoff) ResetToKickoff();
        }

        // ---------- sıfırlama ----------
        void ResetToKickoff()
        {
            Player.Pos = new Vec2(12, 0); Player.Vel = Vec2.Zero; Player.Facing = new Vec2(1, 0);
            Player.Action = PlayerAction.None; Player.ActionTimer = 0;
            if (Time < 0.01f) Player.Stamina = 1f;
            Defender.Pos = new Vec2(30, 6); Defender.Vel = Vec2.Zero; Defender.Facing = new Vec2(-1, 0);
            Defender.Action = PlayerAction.None; DefenderAI.TackleCooldown = 1.5f; DefenderAI.CarryTimer = 0;
            Keeper.ResetPosition();
            Ball.Pos = Player.Pos + Player.Facing * 0.62f; Ball.PrevPos = Ball.Pos; Ball.Vel = Vec2.Zero; Ball.Z = 0; Ball.VZ = 0;
            Ball.Take(PlayerId);
            _outTimer = 0; _slideResolved = false;
        }

        void ReturnBallToPlayer()
        {
            Ball.Pos = Player.Pos + Player.Facing * 0.62f; Ball.PrevPos = Ball.Pos; Ball.Vel = Vec2.Zero;
            Ball.Take(PlayerId);
            _outTimer = 0;
        }

        // ---------- ana adım ----------
        public void Step(float dt, PlayerInput input)
        {
            if (dt <= 0f) return;
            if (dt > 0.1f) dt = 0.1f; // büyük kare atlamalarında fizik patlamasını önle
            Time += dt;
            for (int i = 0; i < TargetFlash.Length; i++) if (TargetFlash[i] > 0) TargetFlash[i] -= dt;

            Machine.Tick(dt);
            // Tekrar sistemi T047 kapsamındadır; uygulanana kadar tekrar durumu atlanır (sahte tekrar gösterilmez).
            if (Machine.Phase == MatchPhase.Replay) Machine.SkipReplay();
            var phase = Machine.Phase;

            if (phase == MatchPhase.Live) StepLive(dt, input);
            else if (phase == MatchPhase.GoalCelebration || phase == MatchPhase.Replay) StepDead(dt);

            if (Machine.Phase == MatchPhase.FullTime)
            {
                if (!_sessionEndRaised) { _sessionEndRaised = true; Raise(FieldEventType.SessionEnded, Stats.Goals); }
                Machine.ShowResult();
            }
        }

        void StepDead(float dt)
        {
            Player.Step(dt, Vec2.Zero, false, false);
            Defender.Step(dt, Vec2.Zero, false, false);
            if (!Ball.IsControlled) { Ball.StepFree(dt); ClampNet(); }
        }

        void ClampNet()
        {
            float maxX = Pitch.HalfLength + Pitch.GoalDepth - 0.3f;
            if (Ball.Pos.X > maxX) { Ball.Pos.X = maxX; Ball.Vel.X = 0; }
            if (Math.Abs(Ball.Pos.Y) > Pitch.GoalHalfWidth - 0.2f && Ball.Pos.X > Pitch.HalfLength)
            { Ball.Pos.Y = Math.Sign(Ball.Pos.Y) * (Pitch.GoalHalfWidth - 0.2f); Ball.Vel.Y = 0; }
        }

        void StepLive(float dt, PlayerInput input)
        {
            bool hasBall = HasBall;
            var aim = input.Move.Length > 0.3f ? input.Move.Normalized : Player.Facing;
            SelectedTarget = hasBall ? PassTargeting.Pick(Player.Pos, aim, Config.PassTargets) : -1;

            // --- oyuncu komutları ---
            if (hasBall && Player.Action == PlayerAction.None)
            {
                if (input.Shoot) DoShoot(input);
                else if (input.Pass) DoPass(input, false);
                else if (input.ThroughPass) DoPass(input, true);
                else if (input.SkillDirection != 0) DoSkill(input.SkillDirection);
            }
            else if (!hasBall && input.Slide && Player.Action == PlayerAction.None)
            {
                var dir = input.Move.Length > 0.3f ? input.Move.Normalized : Player.Facing;
                Player.StartSlide(dir); _slideResolved = false;
            }
            hasBall = HasBall;

            Player.Step(dt, input.Move, input.Sprint, hasBall);

            // --- rakip savunmacı ---
            bool defHasBall = Ball.IsControlled && Ball.OwnerId == DefenderId;
            if (Config.DefenderEnabled)
            {
                var mv = DefenderAI.Decide(dt, Ball, Player, defHasBall);
                Defender.Step(dt, mv, false, defHasBall);
                if (defHasBall && DefenderAI.ShouldClear) DefenderClear();
                else if (HasBall && DefenderAI.TackleCooldown <= 0f && Vec2.Distance(Defender.Pos, Ball.Pos) < 1.1f) DefenderTackle();
            }
            else Defender.Pos = new Vec2(30, 40); // sahne dışı park

            // --- kaleci ---
            var outcome = Keeper.Step(dt, Ball);
            if (outcome != GkOutcome.None) { Stats.Saves++; Raise(FieldEventType.Save, outcome == GkOutcome.Catch ? 1 : 0, Keeper.Pos); }
            if (Keeper.State == GkState.Recovering && Ball.IsControlled && Ball.OwnerId == KeeperId) Keeper.Distribute(Ball, Player.Pos);

            // --- top ---
            if (Ball.IsControlled)
            {
                if (Ball.OwnerId == PlayerId) CarryBall(Player, dt);
                else if (Ball.OwnerId == DefenderId) CarryBall(Defender, dt);
            }
            else
            {
                Ball.StepFree(dt);
                if (_outTimer > 0f) { _outTimer -= dt; if (_outTimer <= 0f) ReturnBallToPlayer(); }
                else TryPickup();
            }

            ResolveSlide();
            CheckBoundaries();
            CheckTargets();
        }

        void CarryBall(PlayerBody b, float dt)
        {
            var carry = b.Pos + b.Facing * 0.62f;
            Ball.PrevPos = Ball.Pos;
            Ball.Pos = Vec2.MoveTowards(Ball.Pos, carry, (30f + b.Speed * 1.5f) * dt);
            Ball.Vel = b.Vel; Ball.Z = 0; Ball.VZ = 0;
        }

        // ---------- pas / şut / çalım ----------
        void DoPass(PlayerInput input, bool through)
        {
            var aim = input.Move.Length > 0.3f ? input.Move.Normalized : Player.Facing;
            float power = MathUtil.Clamp01(input.Power);
            int ti = SelectedTarget;
            Vec2 dir; float speed; float vz = through ? 2.2f : 0f;
            if (ti >= 0)
            {
                var tp = Config.PassTargets[ti];
                if (through) tp = tp + new Vec2(3f, 0f); // boşluğa pas: hedefin önüne
                var rel = tp - Player.Pos;
                dir = rel.Normalized;
                speed = BallPhysics.SpeedForDistance(rel.Length * 1.15f, 30f) * (0.88f + 0.24f * power);
            }
            else
            {
                dir = aim;
                speed = MathUtil.Lerp(9f, 26f, power);
            }
            if (through) speed *= 1.12f;
            float sigma = MathUtil.Lerp(5.5f, 1.2f, Player.Stats.Passing / 99f) * (1f + (1f - Player.Stamina) * 0.6f) * (power > 0.85f ? 1.25f : 1f);
            dir = dir.Rotated(_rng.NextSigned() * sigma * 1.7f * MathUtil.Deg2Rad);
            Ball.Kick(dir * speed, vz, PlayerId, 0.35f);
            Stats.Passes++; _passId++; _lastKickWasPass = true;
        }

        void DoShoot(PlayerInput input)
        {
            float power = MathUtil.Clamp(input.Power, 0.2f, 1f);
            var goalC = new Vec2(Pitch.HalfLength, 0f);
            var toGoal = (goalC - Player.Pos).Normalized;
            var dir = input.Move.Length > 0.3f ? input.Move.Normalized : toGoal;
            // Hafif nişan yardımı: yön kaleye yakınsa kaleye doğru çek.
            if (Math.Abs(Vec2.SignedAngleDeg(toGoal, dir)) < 30f)
            {
                var ontarget = (new Vec2(goalC.X, MathUtil.Clamp(Player.Pos.Y + dir.Y / Math.Max(0.2f, dir.X) * (goalC.X - Player.Pos.X), -Pitch.GoalHalfWidth * 0.85f, Pitch.GoalHalfWidth * 0.85f)) - Player.Pos).Normalized;
                dir = (dir * 0.6f + ontarget * 0.4f).Normalized;
            }
            float sh = Player.Stats.Shooting / 99f;
            float speed = MathUtil.Lerp(14f, 34f, power) * (0.9f + 0.1f * sh);
            float sigma = MathUtil.Lerp(9f, 2f, sh) * (0.5f + power * 0.9f) * (Player.Speed > 7f ? 1.25f : 1f);
            dir = dir.Rotated(_rng.NextSigned() * sigma * 1.7f * MathUtil.Deg2Rad);
            float vz = MathUtil.Lerp(0.3f, 4.5f, power) * (0.5f + 0.8f * _rng.Next01());
            Ball.Kick(dir * speed, vz, PlayerId, 0.35f);
            Stats.Shots++; _passId++; _lastKickWasPass = false;
            bool onTarget = EstimateOnTarget();
            if (onTarget) { Stats.ShotsOnTarget++; Raise(FieldEventType.ShotOnTarget, 0, Ball.Pos); }
            else Raise(FieldEventType.ShotOffTarget, 0, Ball.Pos);
        }

        bool EstimateOnTarget()
        {
            if (Ball.Vel.X <= 0.5f) return false;
            float t = (Pitch.HalfLength - Ball.Pos.X) / Ball.Vel.X;
            float y = Ball.Pos.Y + Ball.Vel.Y * t;
            float z = Ball.Z + Ball.VZ * t - 0.5f * BallPhysics.Gravity * t * t;
            return Math.Abs(y) < Pitch.GoalHalfWidth && z > 0f && z < Pitch.GoalHeight;
        }

        void DoSkill(int direction)
        {
            var sm = Fenerbahce.Core.Domain.SkillMoves.Get(Fenerbahce.Core.Domain.SkillMoves.DirectionChange);
            if (Player.SkillCooldown > 0f || Player.Stats.SkillStars < sm.MinSkillStars) return;
            float ang = -Math.Sign(direction) * 70f * MathUtil.Deg2Rad; // sol(-1) = CCW (+Y)
            var nf = Player.Facing.Rotated(ang);
            Player.Facing = nf;
            Player.Vel = nf * Math.Max(Player.Speed, 5f) * 1.05f;
            Player.Action = PlayerAction.Skill;
            Player.ActionTimer = sm.ContactTimeSeconds + sm.RecoverySeconds;
            Player.SkillCooldown = sm.CooldownSeconds;
            // Top yan tarafa itilir; taşıma sistemi onu yeni yöne çeker.
            Ball.Pos = Player.Pos + nf * 0.62f + nf.Rotated(-Math.Sign(direction) * 90f * MathUtil.Deg2Rad) * (sm.DistanceMeters * 0.25f);
            Stats.Skills++;
            Raise(FieldEventType.SkillPerformed, direction, Player.Pos);
        }

        // ---------- çelme / kayma ----------
        void DefenderTackle()
        {
            DefenderAI.TackleCooldown = 1.0f;
            float p = 0.28f + 0.4f * (DefenderAI.Level - 0.5f) + 0.3f * (Defender.Stats.Defending - Player.Stats.Dribbling) / 99f;
            if (Player.Action == PlayerAction.Skill) p -= 0.25f;
            if (Player.Speed > 7f) p -= 0.05f;
            p = MathUtil.Clamp(p, 0.05f, 0.85f);
            if (_rng.Next01() < p)
            {
                Ball.Take(DefenderId);
                Stats.BallLosses++;
                Raise(FieldEventType.BallLost, 0, Ball.Pos);
            }
            else Raise(FieldEventType.TackleMissed, 0, Defender.Pos);
        }

        void DefenderClear()
        {
            var dir = new Vec2(0.9f, (_rng.Next01() - 0.5f) * 0.8f).Normalized;
            Ball.SetFree(Defender.Pos + dir * 0.7f, dir * 16f);
            Ball.LastTouchId = DefenderId; Ball.LockedId = DefenderId; Ball.LockTimer = 0.6f;
            DefenderAI.CarryTimer = 0; DefenderAI.State = DefState.Hold;
        }

        void ResolveSlide()
        {
            if (Player.Action != PlayerAction.Sliding || _slideResolved) return;
            if (Ball.IsControlled && Ball.OwnerId == DefenderId)
            {
                var rel = Defender.Pos - Player.Pos;
                if (rel.Length < 1.5f && Vec2.Dot(Player.SlideDir, rel.Normalized) > 0.2f)
                {
                    _slideResolved = true;
                    float p = MathUtil.Clamp(0.55f + 0.35f * (Player.Stats.Defending - Defender.Stats.Dribbling) / 99f, 0.3f, 0.9f);
                    if (_rng.Next01() < p)
                    {
                        Ball.SetFree(Defender.Pos + Player.SlideDir * 0.4f, Player.SlideDir * 5f);
                        Ball.LastTouchId = PlayerId; Ball.LockedId = DefenderId; Ball.LockTimer = 0.8f;
                        Stats.TacklesWon++;
                        Raise(FieldEventType.TackleWon, 0, Defender.Pos);
                    }
                    else { Stats.TacklesMissed++; Raise(FieldEventType.TackleMissed, 1, Player.Pos); }
                }
            }
        }

        // ---------- top sahipliği ----------
        void TryPickup()
        {
            if (Ball.Z > 0.9f || Ball.Vel.Length > 18f) return;
            PlayerBody best = null; float bestD = 0.9f;
            foreach (var b in new[] { Player, Defender })
            {
                if (b == Defender && !Config.DefenderEnabled) continue;
                if (Ball.LockedId == b.Id && Ball.LockTimer > 0f) continue;
                if (b.Action == PlayerAction.Sliding || b.Action == PlayerAction.Recovering) continue;
                float d = Vec2.Distance(b.Pos, Ball.Pos);
                if (d < bestD) { best = b; bestD = d; }
            }
            if (best == null) return;
            Ball.Take(best.Id);
            if (best.Id == PlayerId) Raise(FieldEventType.BallRecovered, 0, Ball.Pos);
        }

        // ---------- sınırlar / gol ----------
        void CheckBoundaries()
        {
            if (Ball.IsControlled || _outTimer > 0f) return;
            float L = Pitch.HalfLength;
            if (Ball.PrevPos.X < L && Ball.Pos.X >= L)
            {
                float t = (L - Ball.PrevPos.X) / Math.Max(1e-5f, Ball.Pos.X - Ball.PrevPos.X);
                float yc = Ball.PrevPos.Y + t * (Ball.Pos.Y - Ball.PrevPos.Y);
                float zc = Ball.PrevZ + t * (Ball.Z - Ball.PrevZ);
                float gw = Pitch.GoalHalfWidth, bar = Pitch.GoalHeight;
                bool postHit = (Math.Abs(Math.Abs(yc) - gw) < 0.12f && zc < bar + 0.1f) || (Math.Abs(yc) < gw + 0.1f && Math.Abs(zc - bar) < 0.12f);
                if (postHit)
                {
                    Ball.Vel = new Vec2(-Math.Abs(Ball.Vel.X) * 0.5f, Ball.Vel.Y * 0.8f);
                    Ball.Pos = new Vec2(L - 0.25f, Ball.Pos.Y);
                    Raise(FieldEventType.PostHit, 0, Ball.Pos);
                    return;
                }
                if (Math.Abs(yc) < gw && zc < bar)
                {
                    if (Machine.RegisterGoal(true))
                    {
                        Stats.Goals++;
                        Raise(FieldEventType.GoalScored, Stats.Goals, new Vec2(L, yc));
                    }
                    return;
                }
                StartOut();
                return;
            }
            if (Math.Abs(Ball.Pos.Y) > Pitch.HalfWidth || Ball.Pos.X < -L || Ball.Pos.X > L) StartOut();
        }

        void StartOut()
        {
            Raise(FieldEventType.BallOut, 0, Ball.Pos);
            Ball.Vel = Vec2.Zero; Ball.VZ = 0; Ball.Z = 0; Ball.Mode = BallMode.Free;
            _outTimer = 1.2f;
        }

        void CheckTargets()
        {
            if (!_lastKickWasPass || _countedPassId == _passId || Ball.IsControlled) return;
            for (int i = 0; i < Config.PassTargets.Count; i++)
            {
                if (Vec2.Distance(Ball.Pos, Config.PassTargets[i]) < Config.PassTargetRadius && Ball.Z < 1.6f)
                {
                    _countedPassId = _passId;
                    Stats.TargetPasses++; TargetFlash[i] = 1.5f;
                    Raise(FieldEventType.PassToTarget, i, Config.PassTargets[i]);
                    return;
                }
            }
        }
    }
}
