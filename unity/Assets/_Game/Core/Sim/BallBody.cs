namespace Fenerbahce.Core.Sim
{
    public enum BallMode { Free, Controlled, InFlight }

    /// <summary>Top durumları: serbest / kontrol ediliyor / havada (T021). Sahiplik OwnerId ile izlenir.</summary>
    public class BallBody
    {
        public Vec2 Pos;
        public float Z;
        public Vec2 Vel;
        public float VZ;
        public BallMode Mode = BallMode.Free;
        public int OwnerId = -1;
        public int LastTouchId = -1;
        /// <summary>Her vuruş/serbest bırakmada artar; kaleci aynı şuta ikinci kez zar atmasın diye kullanılır.</summary>
        public int KickSeq;
        /// <summary>Bu kimlikli oyuncu LockTimer bitene kadar topu alamaz (pasın hemen geri alınmasını önler).</summary>
        public int LockedId = -1;
        public float LockTimer;

        public Vec2 PrevPos;
        public float PrevZ;

        public bool IsControlled { get { return Mode == BallMode.Controlled; } }

        public void SetFree(Vec2 pos, Vec2 vel)
        {
            Pos = pos; Vel = vel; Z = 0; VZ = 0; Mode = BallMode.Free; OwnerId = -1; KickSeq++;
        }

        public void Take(int ownerId)
        {
            Mode = BallMode.Controlled; OwnerId = ownerId; LastTouchId = ownerId; Z = 0; VZ = 0;
        }

        /// <summary>Serbest/havadaki topu bir adım ilerletir. Kontrol edilen topu çağıran taraf yönetir.</summary>
        public void StepFree(float dt)
        {
            PrevPos = Pos; PrevZ = Z;
            if (LockTimer > 0) { LockTimer -= dt; if (LockTimer <= 0) { LockedId = -1; LockTimer = 0; } }

            if (Z > 0f || VZ != 0f)
            {
                VZ -= BallPhysics.Gravity * dt;
                Z += VZ * dt;
                if (Z <= 0f)
                {
                    Z = 0f;
                    if (VZ < -1.5f) { VZ = -VZ * BallPhysics.Restitution; Vel = Vel * 0.92f; }
                    else VZ = 0f;
                }
            }
            float speed = Vel.Length;
            if (Z <= 0.02f && VZ == 0f)
            {
                float decel = BallPhysics.RollDecelConst + BallPhysics.RollDecelProp * speed;
                float ns = speed - decel * dt; if (ns < 0f) ns = 0f;
                Vel = speed > 1e-5f ? Vel * (ns / speed) : Vec2.Zero;
            }
            else Vel = Vel * (1f - BallPhysics.AirDrag * dt);
            Pos = Pos + Vel * dt;
            Mode = (Z > 0.3f || VZ > 0.5f) ? BallMode.InFlight : BallMode.Free;
            OwnerId = -1;
        }

        public void Kick(Vec2 vel, float vz, int kickerId, float lockSeconds)
        {
            KickSeq++;
            Vel = vel; VZ = vz; if (vz > 0) Z = System.Math.Max(Z, 0.05f);
            Mode = vz > 0.5f ? BallMode.InFlight : BallMode.Free;
            LastTouchId = kickerId; OwnerId = -1;
            LockedId = kickerId; LockTimer = lockSeconds;
        }
    }
}
