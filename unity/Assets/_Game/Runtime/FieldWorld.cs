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
        FieldSource _src;
        Camera _cam;
        Material _template;
        GameObject _ball, _ballShadow;
        readonly List<PlayerView> _views = new List<PlayerView>();
        readonly List<PlayerView> _keeperViews = new List<PlayerView>();
        Transform _marker;
        readonly List<Transform> _targetRings = new List<Transform>();
        readonly List<SpriteRenderer> _targetRenderers = new List<SpriteRenderer>();
        Vector3 _camVel; Vector3 _focus;

        public Camera Cam { get { return _cam; } }

        class PlayerView
        {
            public Transform Root, Body; public Renderer BodyR, ShortsR; public float Phase;
        }

        public void Build(FieldSource src)
        {
            _src = src;
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

            // Forma: bizim takım sarı-lacivert, rakip beyaz-kırmızı; kaleciler yeşil/turuncu. (Gerçek forma/lisans T011/D-?? ile gelir.)
            for (int i = 0; i < _src.Bodies.Count; i++)
            {
                bool ours = _src.BodyTeams[i] == 0;
                _views.Add(ours ? MakePlayer("Oyuncu" + i, Ui.C(DesignTokens.Yellow), Ui.C(DesignTokens.Navy))
                                : MakePlayer("Rakip" + i, new Color(0.9f, 0.9f, 0.95f), new Color(0.75f, 0.1f, 0.12f)));
            }
            foreach (var k in _src.Keepers)
                _keeperViews.Add(k.Sign < 0 ? MakePlayer("Kaleci (bizim)", new Color(0.18f, 0.8f, 0.45f), new Color(0.1f, 0.3f, 0.2f))
                                            : MakePlayer("Kaleci (rakip)", new Color(0.95f, 0.55f, 0.15f), new Color(0.3f, 0.2f, 0.1f)));

            var mk = Disc("ActiveMarker", new Color(1f, 0.84f, 0f, 0.5f), 1.7f); _marker = mk.transform;
            foreach (var t in _src.Targets)
            {
                var ring = Disc("TargetRing", new Color(0.3f, 0.85f, 1f, 0.55f), _src.TargetRadius * 2f);
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
            var p = _src.Pitch; int ppm = 8;
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
            var p = _src.Pitch;
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
            var p = _src.Pitch;
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
            if (_src == null) return;
            for (int i = 0; i < _views.Count; i++)
            {
                bool active = _src.BodyActive(i);
                _views[i].Root.gameObject.SetActive(active);
                if (active) SyncPlayer(_views[i], _src.Bodies[i], _src.Bodies[i].Action == PlayerAction.Sliding);
            }
            // kaleciler: dalışta yana yatar; kendi kalesinden dışarı bakar
            for (int i = 0; i < _keeperViews.Count; i++)
            {
                var k = _src.Keepers[i]; var v = _keeperViews[i];
                v.Root.position = new Vector3(k.Pos.X, 0f, k.Pos.Y);
                v.Root.rotation = Quaternion.LookRotation(new Vector3(-k.Sign, 0, 0));
                bool diving = k.State == GkState.Diving;
                float side = Mathf.Sign(k.DiveTargetY - k.Pos.Y) * k.Sign;
                v.Body.localRotation = Quaternion.Euler(0, 0, diving ? -side * 68f : 0f);
                v.Body.localPosition = diving ? new Vector3(0, 0.6f, 0) : Vector3.zero;
            }

            var b = _src.Ball;
            _ball.transform.position = new Vector3(b.Pos.X, 0.17f + b.Z, b.Pos.Y);
            _ball.transform.Rotate(new Vector3(b.Vel.Y, 0, -b.Vel.X) * (Time.deltaTime * 60f), Space.World);
            _ballShadow.transform.position = new Vector3(b.Pos.X, 0.04f, b.Pos.Y);
            float sc = Mathf.Max(0.5f, 1.2f - b.Z * 0.12f) * 0.34f;
            _ballShadow.transform.localScale = new Vector3(sc * 1.56f, sc * 1.56f, 1f);

            // Aktif oyuncu işareti
            var c = _src.Controlled;
            if (c != null) _marker.position = new Vector3(c.Pos.X, 0.05f, c.Pos.Y);

            // Hedef halkaları: seçili olan parlak, isabet olunca yeşil flaş
            for (int i = 0; i < _targetRenderers.Count; i++)
            {
                Color col = new Color(0.3f, 0.85f, 1f, 0.45f);
                if (_src.SelectedTarget == i) col = new Color(1f, 1f, 1f, 0.9f);
                if (_src.TargetFlash(i) > 0f) col = new Color(0.2f, 1f, 0.4f, 0.9f);
                _targetRenderers[i].color = col;
            }
            UpdateCamera();
        }

        // ---------- kamera (yayın açısı, T028) ----------
        Vector3 FocusPoint()
        {
            var p = _src.Pitch;
            var c = _src.Controlled; var bl = _src.Ball.Pos;
            var pl = c != null ? c.Pos : bl; var pv = c != null ? c.Vel : Fenerbahce.Core.Sim.Vec2.Zero;
            // Takım maçında kamera topa daha çok bağlanır (oyun 5v5 akıyor); tek futbolcu sahasında oyuncuya.
            float toBall = _src.Bodies.Count > 2 ? 0.55f : 0.35f;
            var f = Vector2.Lerp(new Vector2(pl.X, pl.Y), new Vector2(bl.X, bl.Y), toBall);
            f.x = Mathf.Clamp(f.x + pv.X * 0.35f, -p.HalfLength + 14f, p.HalfLength - 14f);
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
