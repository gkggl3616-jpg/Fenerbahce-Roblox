using System;

namespace Fenerbahce.Core.Sim
{
    public enum DefState { Hold, Chase, Carry }

    /// <summary>Rakip saha oyuncusu: top taşıyıcıya baskı yapar, çelme dener, top kapınca taşır ve bir süre sonra uzaklaştırır.</summary>
    public class DefenderBot
    {
        public PlayerBody Body;
        public DefState State = DefState.Hold;
        public float TackleCooldown;
        public float CarryTimer;
        public Vec2 Home;
        public float Level;

        public DefenderBot(PlayerBody body, Vec2 home, float level)
        {
            Body = body; Home = home; Level = level;
        }

        /// <summary>Hareket girdisini üretir (joystick benzeri); fiziği PlayerBody.Step uygular.</summary>
        public Vec2 Decide(float dt, BallBody ball, PlayerBody target, bool defenderHasBall)
        {
            if (TackleCooldown > 0) TackleCooldown -= dt;
            Vec2 goal;
            if (defenderHasBall)
            {
                State = DefState.Carry;
                CarryTimer += dt;
                goal = new Vec2(-30f, Body.Pos.Y * 0.5f); // kendi yarı sahasına doğru taşı
            }
            else
            {
                CarryTimer = 0f;
                bool ballNear = Vec2.Distance(ball.Pos, Body.Pos) < 28f || Vec2.Distance(target.Pos, Body.Pos) < 26f;
                if (ballNear)
                {
                    State = DefState.Chase;
                    if (ball.IsControlled && ball.OwnerId == target.Id)
                        goal = target.Pos + target.Vel * 0.35f; // top taşıyıcıyı kes
                    else
                        goal = ball.Pos + ball.Vel * 0.25f;     // serbest top
                }
                else { State = DefState.Hold; goal = Home; }
            }
            var rel = goal - Body.Pos;
            float d = rel.Length;
            if (d < 0.4f) return Vec2.Zero;
            // Level, azami hız çarpanı gibi çalışır (joystick büyüklüğü).
            return rel / d * Math.Min(1f, Level);
        }

        public bool ShouldClear { get { return State == DefState.Carry && CarryTimer > 5f; } }
    }
}
