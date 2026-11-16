using System.Collections.Generic;
using UnityEngine;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Sim;

namespace Fenerbahce.Runtime
{
    /// <summary>
    /// ControlField durumunu 3B olarak çizer (yalnızca sunum). Sim X → dünya X, sim Y → dünya Z.
    /// Yalnız yerleşik primitive/materyal kullanır (shader kırpma sorunu yok); ilk sürümde ortak rigli model yerine kapsül gövde.
    /// </summary>
    public class FieldWorld : MonoBehaviour
    {
        ControlField _sim;
        Camera _cam;
        Material _template;
        GameObject _ball, _ballShadow;
        PlayerView _player, _defender, _keeper;
        Transform _marker;
        readonly List<Transform> _targetRings = new List<Transform>();
        readonly List<SpriteRenderer> _targetRenderers = new List<SpriteRenderer>();
        Vector3 _camVel; Vector3 _focus;

        public Camera Cam { get { return _cam; } }

        class PlayerView
        {
            public Transform Root, Body; public Renderer BodyR, ShortsR; public float Phase;
        }

        public void Build(ControlField sim)
        {
            _sim = sim;
            var probe = GameObject.CreatePrimitive(PrimitiveType.Cube);
            _template = probe.GetComponent<Renderer>().sharedMaterial;
            Destroy(probe);

            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.62f, 0.66f, 0.74f);
            var lightGo = new GameObject("Sun"); lightGo.transform.SetParent(transform, false);
            var l = lightGo.AddComponent<Light>(); l.type = LightType.Directional; l.intensity = 1.05f; l.color = new Color(1f, 0.98f, 0.92f);
            lightGo.transform.rotation = Quaternion.Euler(52f, -30f, 0f);

            var camGo = new GameObject("FieldCamera"); camGo.transform.SetParent(transform, false);
            _cam = camGo.AddComponent<Camera>(); _cam.fieldOfView = 36f; _cam.nearClipPlane = 0.5f; _cam.farClipPlane = 400f;
            _cam.clearFlags = CameraClearFlags.SolidColor; _cam.backgroundColor = Ui.C(DesignTokens.Navy); _cam.depth = 0;
            camGo.AddComponent<AudioListener>();

            BuildPitch(); BuildGoals(); BuildStands();

            _ball = Prim(PrimitiveType.Sphere, "Ball", Color.white, new Vector3(0.34f, 0.34f, 0.34f));
            _ballShadow = Disc("BallShadow", new Color(0, 0, 0, 0.45f), 0.5f);

            _player = MakePlayer("Oyuncu", Ui.C(DesignTokens.Yellow), Ui.C(DesignTokens.Navy));
            _defender = MakePlayer("Rakip", new Color(0.9f, 0.9f, 0.95f), new Color(0.75f, 0.1f, 0.12f));
            _keeper = MakePlayer("Kaleci", new Color(0.18f, 0.8f, 0.45f), new Color(0.1f, 0.3f, 0.2f));

            var mk = Disc("ActiveMarker", new Color(1f, 0.84f, 0f, 0.5f), 1.7f); _marker = mk.transform;
            foreach (var t in _sim.Config.PassTargets)
            {
                var ring = Disc("TargetRing", new Color(0.3f, 0.85f, 1f, 0.55f), _sim.Config.PassTargetRadius * 2f);
                ring.transform.position = new Vector3(t.X, 0.03f, t.Y);
                _targetRings.Add(ring.transform); _targetRenderers.Add(ring.GetComponent<SpriteRenderer>());
            }
            SnapCamera();
        }

        // ---------- yapı ----------
        Material Mat(Color c) { var m = new Material(_template); m.color = c; return m; }

        GameObject Prim(PrimitiveType type, string name, Color c, Vector3 scale, Transform parent = null)
        {
            var go = GameObject.CreatePrimitive(type); go.name = name;
            var col = go.GetComponent<Collider>(); if (col != null) Destroy(col);
            go.transform.SetParent(parent != null ? parent : transform, false);
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = Mat(c);
            return go;
        }

        GameObject Disc(string name, Color c, float diameter)
        {
            var go = new GameObject(name); go.transform.SetParent(transform, false);
            var sr = go.AddComponent<SpriteRenderer>(); sr.sprite = Ui.Circle; sr.color = c; sr.sortingOrder = 1;
            go.transform.rotation = Quaternion.Euler(90f, 0f, 0f);
            float sc = diameter / 0.64f; // 64 px daire sprite'ı, 100 PPU → 0.64 m
            go.transform.localScale = new Vector3(sc, sc, 1f);
            return go;
        }

        void BuildPitch()
        {
            var p = _sim.Pitch; int ppm = 8;
            int w = Mathf.RoundToInt((p.HalfLength * 2 + 16) * ppm), h = Mathf.RoundToInt((p.HalfWidth * 2 + 12) * ppm);
            var tex = new Texture2D(w, h, TextureFormat.RGB24, true) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear, anisoLevel = 4 };
            var px = new Color32[w * h];
            Color32 a = new Color32(46, 125, 50, 255), b = new Color32(56, 142, 60, 255), line = new Color32(235, 240, 235, 255), outside = new Color32(30, 90, 40, 255);
            float cx = w / 2f, cy = h / 2f;
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    float mx = (x - cx) / ppm, my = (y - cy) / ppm;
                    bool inside = Mathf.Abs(mx) <= p.HalfLength && Mathf.Abs(my) <= p.HalfWidth;
                    Color32 c = inside ? ((Mathf.FloorToInt((mx + p.HalfLength) / 7.5f) % 2 == 0) ? a : b) : outside;
                    px[y * w + x] = c;
                }
            System.Action<float, float, float, float> rect = (x0, y0, x1, y1) =>
            {
                for (int y = Mathf.Max(0, Mathf.RoundToInt(cy + y0 * ppm)); y <= Mathf.Min(h - 1, Mathf.RoundToInt(cy + y1 * ppm)); y++)
                    for (int x = Mathf.Max(0, Mathf.RoundToInt(cx + x0 * ppm)); x <= Mathf.Min(w - 1, Mathf.RoundToInt(cx + x1 * ppm)); x++) px[y * w + x] = line;
            };
            float t = 0.12f;
            rect(-p.HalfLength, -p.HalfWidth, p.HalfLength, -p.HalfWidth + t); rect(-p.HalfLength, p.HalfWidth - t, p.HalfLength, p.HalfWidth);
            rect(-p.HalfLength, -p.HalfWidth, -p.HalfLength + t, p.HalfWidth); rect(p.HalfLength - t, -p.HalfWidth, p.HalfLength, p.HalfWidth);
            rect(-t / 2, -p.HalfWidth, t / 2, p.HalfWidth);
            foreach (int s in new[] { -1, 1 })
            {
                float ax = s * p.HalfLength, ad = s * (p.HalfLength - p.PenaltyAreaDepth);
                rect(Mathf.Min(ax, ad), -p.PenaltyAreaHalfWidth, Mathf.Max(ax, ad), -p.PenaltyAreaHalfWidth + t);
                rect(Mathf.Min(ax, ad), p.PenaltyAreaHalfWidth - t, Mathf.Max(ax, ad), p.PenaltyAreaHalfWidth);
                rect(ad - t / 2, -p.PenaltyAreaHalfWidth, ad + t / 2, p.PenaltyAreaHalfWidth);
            }
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    float mx = (x - cx) / ppm, my = (y - cy) / ppm;
                    float d = Mathf.Sqrt(mx * mx + my * my);
                    if (Mathf.Abs(d - 9.15f) < 0.09f || d < 0.25f) px[y * w + x] = line;
                }
            tex.SetPixels32(px); tex.Apply(true);
            var quad = GameObject.CreatePrimitive(PrimitiveType.Quad); quad.name = "Pitch";
            var col = quad.GetComponent<Collider>(); if (col != null) Destroy(col);
            quad.transform.SetParent(transform, false);
            quad.transform.rotation = Quaternion.Euler(90f, 0f, 0f);
            quad.transform.localScale = new Vector3(p.HalfLength * 2 + 16, p.HalfWidth * 2 + 12, 1f);
            var m = Mat(Color.white); m.mainTexture = tex; m.SetFloat("_Glossiness", 0f);
            quad.GetComponent<Renderer>().sharedMaterial = m;
        }

        void BuildGoals()
        {
            var p = _sim.Pitch;
            foreach (int s in new[] { -1, 1 })
            {
                float x = s * p.HalfLength; var white = Color.white;
                Prim(PrimitiveType.Cylinder, "PostL", white, new Vector3(0.14f, p.GoalHeight / 2f, 0.14f)).transform.position = new Vector3(x, p.GoalHeight / 2f, -p.GoalHalfWidth);
                Prim(PrimitiveType.Cylinder, "PostR", white, new Vector3(0.14f, p.GoalHeight / 2f, 0.14f)).transform.position = new Vector3(x, p.GoalHeight / 2f, p.GoalHalfWidth);
                var bar = Prim(PrimitiveType.Cylinder, "Bar", white, new Vector3(0.14f, p.GoalHalfWidth, 0.14f)); bar.transform.position = new Vector3(x, p.GoalHeight, 0); bar.transform.rotation = Quaternion.Euler(90f, 0, 0);
                var back = Prim(PrimitiveType.Cube, "Net", new Color(1, 1, 1, 1), new Vector3(0.05f, p.GoalHeight, p.GoalHalfWidth * 2)); back.transform.position = new Vector3(x + s * p.GoalDepth, p.GoalHeight / 2f, 0);
                back.GetComponent<Renderer>().sharedMaterial.color = new Color(0.8f, 0.85f, 0.9f);
            }
        }

        void BuildStands()
        {
            var p = _sim.Pitch;
            var navy = Ui.C(DesignTokens.NavyLight); var yellow = Ui.C(DesignTokens.Yellow);
            float zOff = p.HalfWidth + 9f;
            foreach (int s in new[] { -1, 1 })
            {
                var st = Prim(PrimitiveType.Cube, "Stand", navy, new Vector3(p.HalfLength * 2 + 30, 9f, 6f)); st.transform.position = new Vector3(0, 4.5f, s * (zOff + 3f));
                var band = Prim(PrimitiveType.Cube, "Band", yellow, new Vector3(p.HalfLength * 2 + 30, 0.8f, 0.3f)); band.transform.position = new Vector3(0, 2.2f, s * (zOff - 0.2f));
                var edge = Prim(PrimitiveType.Cube, "Ad", Ui.C(DesignTokens.Surface), new Vector3(p.HalfLength * 2 + 16, 0.9f, 0.2f)); edge.transform.position = new Vector3(0, 0.45f, s * (p.HalfWidth + 1.6f));
            }
            foreach (int s in new[] { -1, 1 })
            {
                var end = Prim(PrimitiveType.Cube, "EndStand", navy, new Vector3(6f, 8f, p.HalfWidth * 2 + 24)); end.transform.position = new Vector3(s * (p.HalfLength + 12f), 4f, 0);
            }
        }

        PlayerView MakePlayer(string name, Color kit, Color shorts)
        {
            var root = new GameObject(name).transform; root.SetParent(transform, false);
            var body = new GameObject("Body").transform; body.SetParent(root, false);
            var torso = Prim(PrimitiveType.Capsule, "Torso", kit, new Vector3(0.62f, 0.55f, 0.5f), body); torso.transform.localPosition = new Vector3(0, 1.15f, 0);
            var sh = Prim(PrimitiveType.Cylinder, "Shorts", shorts, new Vector3(0.62f, 0.28f, 0.52f), body); sh.transform.localPosition = new Vector3(0, 0.72f, 0);
            var legs = Prim(PrimitiveType.Cylinder, "Legs", new Color(0.92f, 0.92f, 0.92f), new Vector3(0.36f, 0.34f, 0.36f), body); legs.transform.localPosition = new Vector3(0, 0.34f, 0);
            var head = Prim(PrimitiveType.Sphere, "Head", new Color(0.93f, 0.76f, 0.62f), new Vector3(0.36f, 0.38f, 0.36f), body); head.transform.localPosition = new Vector3(0, 1.82f, 0);
            var nose = Prim(PrimitiveType.Cube, "Front", shorts, new Vector3(0.18f, 0.12f, 0.3f), body); nose.transform.localPosition = new Vector3(0, 1.3f, 0.3f);
            var shadow = Disc("Shadow", new Color(0, 0, 0, 0.4f), 1.1f); shadow.transform.SetParent(root, false); shadow.transform.localPosition = new Vector3(0, 0.02f, 0);
            return new PlayerView { Root = root, Body = body, BodyR = torso.GetComponent<Renderer>(), ShortsR = sh.GetComponent<Renderer>() };
        }

        // ---------- senkron ----------
        void SyncPlayer(PlayerView v, PlayerBody b, bool sliding)
        {
            v.Root.position = new Vector3(b.Pos.X, 0f, b.Pos.Y);
            if (b.Facing.SqrLength > 0.01f) v.Root.rotation = Quaternion.Slerp(v.Root.rotation, Quaternion.LookRotation(new Vector3(b.Facing.X, 0, b.Facing.Y)), 0.35f);
            float spd = b.Speed;
            v.Phase += spd * Time.deltaTime * 1.6f;
            float bob = Mathf.Abs(Mathf.Sin(v.Phase)) * Mathf.Clamp01(spd / 8f) * 0.08f;
            v.Body.localPosition = new Vector3(0, bob, 0);
            float lean = Mathf.Clamp(spd / 10f, 0f, 1f) * 10f;
            if (b.Action == PlayerAction.Sliding) v.Body.localRotation = Quaternion.Euler(-78f, 0, 0) * Quaternion.identity;
            else if (b.Action == PlayerAction.Skill) v.Body.localRotation = Quaternion.Euler(lean, 0, Mathf.Sin(Time.time * 30f) * 8f);
            else v.Body.localRotation = Quaternion.Euler(lean, 0, 0);
            if (b.Action == PlayerAction.Sliding) v.Body.localPosition = new Vector3(0, 0.3f, 0);
        }

        public void Sync(Vector2 worldFocusBias)
        {
            if (_sim == null) return;
            SyncPlayer(_player, _sim.Player, _sim.Player.Action == PlayerAction.Sliding);
            SyncPlayer(_defender, _sim.Defender, _sim.Defender.Action == PlayerAction.Sliding);
            _defender.Root.gameObject.SetActive(_sim.Config.DefenderEnabled);
            // kaleci: dalışta yana yatar
            _keeper.Root.position = new Vector3(_sim.Keeper.Pos.X, 0f, _sim.Keeper.Pos.Y);
            _keeper.Root.rotation = Quaternion.LookRotation(new Vector3(-1, 0, 0));
            bool diving = _sim.Keeper.State == GkState.Diving;
            float side = Mathf.Sign(_sim.Keeper.DiveTargetY - _sim.Keeper.Pos.Y);
            _keeper.Body.localRotation = Quaternion.Euler(0, 0, diving ? -side * 68f : 0f);
            _keeper.Body.localPosition = diving ? new Vector3(0, 0.6f, 0) : Vector3.zero;

            var b = _sim.Ball;
            _ball.transform.position = new Vector3(b.Pos.X, 0.17f + b.Z, b.Pos.Y);
            _ball.transform.Rotate(new Vector3(b.Vel.Y, 0, -b.Vel.X) * (Time.deltaTime * 60f), Space.World);
            _ballShadow.transform.position = new Vector3(b.Pos.X, 0.04f, b.Pos.Y);
            float sc = Mathf.Max(0.5f, 1.2f - b.Z * 0.12f) * 0.34f;
            _ballShadow.transform.localScale = new Vector3(sc * 1.56f, sc * 1.56f, 1f);

            // Aktif oyuncu işareti
            _marker.position = new Vector3(_sim.Player.Pos.X, 0.05f, _sim.Player.Pos.Y);

            // Hedef halkaları: seçili olan parlak, isabet olunca yeşil flaş
            for (int i = 0; i < _targetRenderers.Count; i++)
            {
                Color c = new Color(0.3f, 0.85f, 1f, 0.45f);
                if (_sim.SelectedTarget == i) c = new Color(1f, 1f, 1f, 0.9f);
                if (_sim.TargetFlash[i] > 0f) c = new Color(0.2f, 1f, 0.4f, 0.9f);
                _targetRenderers[i].color = c;
            }
            UpdateCamera();
        }

        // ---------- kamera (yayın açısı, T028) ----------
        Vector3 FocusPoint()
        {
            var p = _sim.Pitch;
            var pl = _sim.Player.Pos; var bl = _sim.Ball.Pos;
            var f = Vector2.Lerp(new Vector2(pl.X, pl.Y), new Vector2(bl.X, bl.Y), 0.35f);
            f.x = Mathf.Clamp(f.x + _sim.Player.Vel.X * 0.35f, -p.HalfLength + 14f, p.HalfLength - 6f);
            f.y = Mathf.Clamp(f.y * 0.6f, -p.HalfWidth * 0.45f, p.HalfWidth * 0.45f);
            return new Vector3(f.x, 0, f.y);
        }

        void SnapCamera()
        {
            _focus = FocusPoint();
            _cam.transform.position = _focus + new Vector3(0, 21f, -27f);
            _cam.transform.LookAt(_focus + new Vector3(0, 0, 3f));
        }

        void UpdateCamera()
        {
            var target = FocusPoint();
            _focus = Vector3.SmoothDamp(_focus, target, ref _camVel, 0.22f, 60f, Time.deltaTime);
            // Üst üste yaklaşık 16:9 için mesafe; dar ekranlarda biraz geri çek.
            float aspect = Mathf.Max(1.2f, (float)UnityEngine.Screen.width / Mathf.Max(1, UnityEngine.Screen.height));
            float back = aspect < 1.7f ? 1.15f : 1f;
            var pos = _focus + new Vector3(0, 21f, -27f) * back;
            _cam.transform.position = pos;
            _cam.transform.LookAt(_focus + new Vector3(0, 0, 3f));
        }

        public Vector2 WorldToScreen(Vector3 world)
        {
            var sp = _cam.WorldToScreenPoint(world);
            return new Vector2(sp.x, sp.y);
        }
    }
}
