using System;

namespace Fenerbahce.Core.Sim
{
    /// <summary>Saf C# 2B vektör. Saha düzlemi: X = saha uzunluğu (hücum yönü +X), Y = saha genişliği. Birim: metre.</summary>
    public struct Vec2
    {
        public float X, Y;
        public Vec2(float x, float y) { X = x; Y = y; }
        public static readonly Vec2 Zero = new Vec2(0, 0);

        public static Vec2 operator +(Vec2 a, Vec2 b) { return new Vec2(a.X + b.X, a.Y + b.Y); }
        public static Vec2 operator -(Vec2 a, Vec2 b) { return new Vec2(a.X - b.X, a.Y - b.Y); }
        public static Vec2 operator -(Vec2 a) { return new Vec2(-a.X, -a.Y); }
        public static Vec2 operator *(Vec2 a, float s) { return new Vec2(a.X * s, a.Y * s); }
        public static Vec2 operator *(float s, Vec2 a) { return new Vec2(a.X * s, a.Y * s); }
        public static Vec2 operator /(Vec2 a, float s) { return new Vec2(a.X / s, a.Y / s); }

        public float SqrLength { get { return X * X + Y * Y; } }
        public float Length { get { return (float)Math.Sqrt(X * X + Y * Y); } }
        public Vec2 Normalized { get { float l = Length; return l > 1e-6f ? new Vec2(X / l, Y / l) : Zero; } }

        public static float Dot(Vec2 a, Vec2 b) { return a.X * b.X + a.Y * b.Y; }
        public static float Cross(Vec2 a, Vec2 b) { return a.X * b.Y - a.Y * b.X; }
        public static float Distance(Vec2 a, Vec2 b) { return (a - b).Length; }

        public Vec2 Rotated(float rad)
        {
            float c = (float)Math.Cos(rad), s = (float)Math.Sin(rad);
            return new Vec2(X * c - Y * s, X * s + Y * c);
        }

        public static Vec2 FromAngle(float rad) { return new Vec2((float)Math.Cos(rad), (float)Math.Sin(rad)); }
        public float Angle() { return (float)Math.Atan2(Y, X); }

        public static Vec2 ClampMagnitude(Vec2 v, float max)
        {
            float l = v.Length; return l > max && l > 1e-6f ? v * (max / l) : v;
        }

        public static Vec2 MoveTowards(Vec2 cur, Vec2 target, float maxDelta)
        {
            var d = target - cur; float l = d.Length;
            if (l <= maxDelta || l < 1e-6f) return target;
            return cur + d * (maxDelta / l);
        }

        /// <summary>İşaretli açı farkı (derece) a→b, -180..180.</summary>
        public static float SignedAngleDeg(Vec2 a, Vec2 b)
        {
            float ang = (float)Math.Atan2(Cross(a, b), Dot(a, b));
            return ang * 180f / (float)Math.PI;
        }

        /// <summary>from yönünü to yönüne en fazla maxRad kadar döndürür.</summary>
        public static Vec2 RotateToward(Vec2 from, Vec2 to, float maxRad)
        {
            if (from.SqrLength < 1e-8f) return to.Normalized;
            if (to.SqrLength < 1e-8f) return from.Normalized;
            float ang = (float)Math.Atan2(Cross(from, to), Dot(from, to));
            if (Math.Abs(ang) <= maxRad) return to.Normalized;
            return from.Rotated(ang > 0 ? maxRad : -maxRad).Normalized;
        }

        public override string ToString() { return "(" + X.ToString("0.00") + "," + Y.ToString("0.00") + ")"; }
    }

    public static class MathUtil
    {
        public static float Clamp(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
        public static float Clamp01(float v) { return Clamp(v, 0f, 1f); }
        public static float Lerp(float a, float b, float t) { return a + (b - a) * Clamp01(t); }
        public static float Deg2Rad { get { return (float)Math.PI / 180f; } }
    }

    /// <summary>Deterministik xorshift32. Aynı tohum → aynı sonuç (testlerde ve tekrarlarda gerekli).</summary>
    public class SimRandom
    {
        uint _s;
        public SimRandom(int seed) { _s = seed == 0 ? 0x9E3779B9u : (uint)seed; }
        public uint NextUInt() { _s ^= _s << 13; _s ^= _s >> 17; _s ^= _s << 5; return _s; }
        public float Next01() { return (NextUInt() & 0xFFFFFF) / (float)0x1000000; }
        /// <summary>-1..1 üçgensel dağılım (0 civarı yoğun).</summary>
        public float NextSigned() { return Next01() - Next01(); }
    }
}
