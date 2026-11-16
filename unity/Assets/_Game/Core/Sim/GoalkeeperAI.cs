using System;

namespace Fenerbahce.Core.Sim
{
    public enum GkState { Ready, Reacting, Diving, Beaten, Holding, Recovering }
    public enum GkOutcome { None, Catch, Parry }

    /// <summary>
    /// İlk kaleci davranışı (T025): konumlanma, şut algılama + tepki gecikmesi, dalış/kurtarış, tutma veya çelme.
    /// Sign=+1: +X kalesini, Sign=-1: -X kalesini savunur (iki takımlı maç için). Değerler PROTOTİP'tir.
    /// </summary>
    public class GoalkeeperAI
    {
        public SimStats Stats;
        public Vec2 Pos;
        public Vec2 Facing = new Vec2(-1, 0);
        public GkState State = GkState.Ready;
        public float Timer;
        public float DiveTargetY;
        public float DiveSpeed;
        public bool DiveCommitted;
        public int Id;
        /// <summary>+1: +X kalesini savunur; -1: -X kalesini savunur.</summary>
        public readonly int Sign;

        int _rolledKick = -1;
        readonly PitchSpec _pitch;
        readonly SimRandom _rng;
        /// <summary>Kale çizgisinin İŞARETSİZ x değeri (yerel çerçeve: savunulan kale her zaman +X).</summary>
        public float GoalLineX { get { return _pitch.HalfLength; } }

        public GoalkeeperAI(int id, SimStats stats, PitchSpec pitch, SimRandom rng, int sign = 1)
        {
            Id = id; Stats = stats; _pitch = pitch; _rng = rng; Sign = sign >= 0 ? 1 : -1;
            Facing = new Vec2(-Sign, 0);
            Pos = new Vec2(Sign * (_pitch.HalfLength - 1.0f), 0f);
        }

        public void ResetPosition() { Pos = new Vec2(Sign * (_pitch.HalfLength - 1.0f), 0f); State = GkState.Ready; Timer = 0; DiveCommitted = false; }

        float Skill { get { return Stats.Goalkeeping / 99f; } }

        public GkOutcome Step(float dt, BallBody ball)
        {
            GkOutcome outcome = GkOutcome.None;
            Timer -= dt;

            if (State == GkState.Holding)
            {
                ball.Pos = Pos + new Vec2(-0.5f * Sign, 0);
                ball.Vel = Vec2.Zero; ball.Mode = BallMode.Controlled; ball.OwnerId = Id;
                if (Timer <= 0f) State = GkState.Recovering;
                return GkOutcome.None;
            }
            if (State == GkState.Recovering && Timer <= 0f) State = GkState.Ready;

            // Şut algılama
            if (State == GkState.Ready && !ball.IsControlled)
            {
                float toward = ball.Vel.X * Sign;
                if (toward > 6f)
                {
                    float tCross = (GoalLineX - ball.Pos.X * Sign) / toward;
                    if (tCross > 0.05f && tCross < 1.8f)
                    {
                        float yCross = ball.Pos.Y + ball.Vel.Y * tCross;
                        float zCross = ball.Z + ball.VZ * tCross - 0.5f * BallPhysics.Gravity * tCross * tCross;
                        if (Math.Abs(yCross) < _pitch.GoalHalfWidth + 1.2f && zCross < _pitch.GoalHeight + 0.6f)
                        {
                            State = GkState.Reacting;
                            Timer = MathUtil.Lerp(0.45f, 0.28f, Skill) + _rng.Next01() * 0.06f;
                            DiveTargetY = yCross;
                            DiveCommitted = false;
                        }
                    }
                }
            }

            if (State == GkState.Reacting && Timer <= 0f)
            {
                float reach = MathUtil.Lerp(2.4f, 3.8f, Skill);
                float dy = DiveTargetY - Pos.Y;
                if (Math.Abs(dy) <= reach)
                {
                    State = GkState.Diving; DiveCommitted = true;
                    DiveSpeed = 6.5f + 4.5f * Skill; // m/s yanal dalış hızı: mesafe uzadıkça dalış süresi uzar
                    Timer = Math.Abs(dy) / DiveSpeed + 0.25f;
                }
                else { State = GkState.Beaten; Timer = 0.8f; DiveSpeed = 4f; }
            }

            if (State == GkState.Diving || State == GkState.Beaten)
            {
                float dir = Math.Sign(DiveTargetY - Pos.Y);
                float step = DiveSpeed * dt;
                if (Math.Abs(DiveTargetY - Pos.Y) <= step) Pos.Y = DiveTargetY; else Pos.Y += dir * step;
                if (Timer <= 0f) { State = GkState.Recovering; Timer = 0.8f; }
            }
            else if (State == GkState.Ready || State == GkState.Recovering)
            {
                // Konumlanma: top-kale merkezi doğrultusunda, topa mesafeye göre öne çık.
                var goalCenter = new Vec2(Sign * GoalLineX, 0f);
                var rel = ball.Pos - goalCenter;
                float dist = rel.Length;
                var dirToBall = dist > 1e-3f ? rel / dist : new Vec2(-Sign, 0);
                float offset = Math.Min(5.0f, 0.9f + dist * 0.07f);
                var desired = goalCenter + dirToBall * offset;
                desired.Y = MathUtil.Clamp(desired.Y, -(_pitch.GoalHalfWidth - 0.4f), _pitch.GoalHalfWidth - 0.4f);
                desired.X = Sign * Math.Min(desired.X * Sign, GoalLineX - 0.6f);
                float speed = MathUtil.Lerp(4.2f, 5.8f, Skill);
                Pos = Vec2.MoveTowards(Pos, desired, speed * dt);
            }

            // Kurtarış: top kaleci düzlemini geçerken
            if (!ball.IsControlled && ball.PrevPos.X * Sign < Pos.X * Sign + 0.3f && ball.Pos.X * Sign >= Pos.X * Sign - 0.3f && ball.Vel.X * Sign > 1f)
            {
                float dy = Math.Abs(ball.Pos.Y - Pos.Y);
                float reachY = 0.60f + 0.30f * Skill + (State == GkState.Diving ? 0.40f : 0f);
                float reachZ = 2.3f + (State == GkState.Diving ? 0.35f : 0f);
                if (dy <= reachY && ball.Z <= reachZ && _rolledKick != ball.KickSeq)
                {
                    _rolledKick = ball.KickSeq;
                    float speed = ball.Vel.Length;
                    // Fiziksel erişim yetmez: hız, açıklık ve kaleci becerisine göre kurtarış başarı şansı (PROTOTİP formül).
                    float pSave = 0.92f - 0.011f * Math.Max(0f, speed - 18f) - 0.25f * (dy / reachY) + 0.25f * (Skill - 0.5f);
                    if (_rng.Next01() > MathUtil.Clamp(pSave, 0.15f, 0.97f))
                    {
                        State = GkState.Beaten; Timer = 0.6f; DiveSpeed = 3f;
                        return GkOutcome.None;
                    }
                    float catchLimit = (15f + 8f * Skill) * (State == GkState.Diving ? 0.75f : 1f);
                    if (speed <= catchLimit)
                    {
                        ball.Take(Id);
                        State = GkState.Holding; Timer = 1.0f; outcome = GkOutcome.Catch;
                    }
                    else
                    {
                        float side = ball.Pos.Y >= Pos.Y ? 1f : -1f;
                        ball.Vel = new Vec2(-Sign * Math.Max(4f, speed * 0.30f), side * (3f + 4f * _rng.Next01()));
                        ball.VZ = 1.5f + 2f * _rng.Next01();
                        ball.Pos = new Vec2(Pos.X - 0.35f * Sign, ball.Pos.Y);
                        ball.LastTouchId = Id;
                        ball.LockedId = Id; ball.LockTimer = 0.4f;
                        State = GkState.Recovering; Timer = 0.7f; outcome = GkOutcome.Parry;
                    }
                }
            }
            return outcome;
        }

        /// <summary>Tutulan topu oyuna sokar (kısa yuvarlama pas).</summary>
        public void Distribute(BallBody ball, Vec2 toward)
        {
            var dir = (toward - Pos).Normalized;
            if (dir.SqrLength < 1e-4f) dir = new Vec2(-Sign, 0);
            ball.SetFree(Pos + dir * 0.7f, dir * 11f);
            ball.LastTouchId = Id; ball.LockedId = Id; ball.LockTimer = 0.5f;
            State = GkState.Recovering; Timer = 0.6f;
        }

        /// <summary>Kale vuruşu/yeniden başlatma: kaleci topu tutar, bir süre sonra oyuna sokar.</summary>
        public void Hold(BallBody ball, float seconds)
        {
            Pos = new Vec2(Sign * (_pitch.HalfLength - 1.0f), 0f);
            ball.Take(Id); ball.Pos = Pos + new Vec2(-0.5f * Sign, 0); ball.Vel = Vec2.Zero;
            State = GkState.Holding; Timer = seconds;
        }

        public bool IsHolding { get { return State == GkState.Holding && Timer <= 0.05f; } }
    }
}
