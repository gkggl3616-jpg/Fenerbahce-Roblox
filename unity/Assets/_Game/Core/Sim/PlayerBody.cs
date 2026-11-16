using System;

namespace Fenerbahce.Core.Sim
{
    public enum PlayerAction { None, Sliding, Recovering, Skill, Stunned }

    /// <summary>Saha oyuncusu hareketi: ivmelenme, azami hız, dönüş, stamina (T023).</summary>
    public class PlayerBody
    {
        public int Id;
        public bool IsOurs;
        public SimStats Stats;
        public Vec2 Pos;
        public Vec2 Vel;
        public Vec2 Facing = new Vec2(1, 0);
        public float Stamina = 1f;
        public PlayerAction Action = PlayerAction.None;
        public float ActionTimer;
        public float SkillCooldown;
        public Vec2 SlideDir;

        public PlayerBody(int id, bool ours, SimStats stats, Vec2 pos)
        {
            Id = id; IsOurs = ours; Stats = stats; Pos = pos;
        }

        public float Speed { get { return Vel.Length; } }

        public float MaxSpeed(bool sprinting, bool hasBall)
        {
            float v = MathUtil.Lerp(5.8f, 9.0f, Stats.Pace / 99f);
            if (sprinting) v *= 1.30f;
            if (hasBall) v *= MathUtil.Lerp(0.90f, 0.97f, Stats.Dribbling / 99f);
            if (Stamina < 0.25f) v *= MathUtil.Lerp(0.82f, 1f, Stamina / 0.25f);
            return v;
        }

        /// <param name="move">Joystick vektörü, büyüklük 0..1.</param>
        public void Step(float dt, Vec2 move, bool sprintRequested, bool hasBall)
        {
            if (SkillCooldown > 0) SkillCooldown = Math.Max(0, SkillCooldown - dt);
            if (Action != PlayerAction.None)
            {
                ActionTimer -= dt;
                if (ActionTimer <= 0f)
                {
                    if (Action == PlayerAction.Sliding) { Action = PlayerAction.Recovering; ActionTimer = 0.6f; }
                    else { Action = PlayerAction.None; ActionTimer = 0f; }
                }
            }

            if (Action == PlayerAction.Sliding)
            {
                // Kayma: sabit yönde, sürtünmeyle yavaşlayan hareket.
                Vel = Vel * (1f - 2.2f * dt);
                Pos = Pos + Vel * dt;
                return;
            }

            float mag = MathUtil.Clamp(move.Length, 0f, 1f);
            Vec2 dir = mag > 0.001f ? move / move.Length : Vec2.Zero;
            bool locked = Action == PlayerAction.Recovering || Action == PlayerAction.Stunned;
            if (locked) { dir = Vec2.Zero; mag = 0; }
            bool sprinting = sprintRequested && Stamina > 0.04f && mag > 0.3f && !locked;

            float vmax = MaxSpeed(sprinting, hasBall);
            Vec2 desired = dir * (vmax * mag);
            float accel = mag > 0.001f ? MathUtil.Lerp(9f, 14f, Stats.Pace / 99f) : 16f;
            if (Action == PlayerAction.Skill) accel *= 0.6f;

            if (mag > 0.2f)
            {
                float turn = MathUtil.Lerp(8f, 12f, Stats.Dribbling / 99f) / (1f + Speed / 14f);
                Facing = Vec2.RotateToward(Facing, dir, turn * dt);
            }
            else if (Speed > 1.0f) Facing = Vec2.RotateToward(Facing, Vel.Normalized, 6f * dt);

            // Vel, istenen hıza ivmeyle yaklaşır; ters yöne dönüş doğal olarak yavaşlama gerektirir (keskin dönüş cezası).
            Vel = Vec2.MoveTowards(Vel, desired, accel * dt);
            Pos = Pos + Vel * dt;

            if (sprinting && Speed > 3f)
                Stamina -= (0.14f - 0.05f * (Stats.Stamina / 99f)) * dt;
            else
                Stamina += (Speed < 1f ? 0.10f : 0.045f) * dt;
            Stamina = MathUtil.Clamp01(Stamina);
        }

        public void StartSlide(Vec2 dir)
        {
            Action = PlayerAction.Sliding; ActionTimer = 0.45f; SlideDir = dir.Normalized;
            Facing = SlideDir;
            Vel = SlideDir * Math.Max(Speed * 1.05f, 8.5f);
        }
    }
}
