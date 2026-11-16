using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Match;
using Fenerbahce.Core.Sim;

namespace Fenerbahce.Runtime
{
    /// <summary>Sanal joystick (G34). Her parmak ayrı işaretçidir; düğmelerle aynı anda çalışır (çoklu dokunma).</summary>
    public class VirtualJoystick : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        public Vector2 Value;         // -1..1 ham değer
        public bool Active { get { return _id != Unset; } }
        RectTransform _area, _base, _knob;
        const int Unset = -9999;
        int _id = Unset;
        Vector2 _center;
        public float Radius = 120f;

        public void Setup(RectTransform area, RectTransform baseRt, RectTransform knob) { _area = area; _base = baseRt; _knob = knob; Hide(); }

        void Hide() { if (_base != null) _base.gameObject.SetActive(true); Place(_defaultCenter()); Value = Vector2.zero; if (_knob != null) _knob.anchoredPosition = Vector2.zero; }
        Vector2 _defaultCenter() { return new Vector2(220f, 220f); }
        void Place(Vector2 c) { _center = c; if (_base != null) { _base.anchorMin = _base.anchorMax = Vector2.zero; _base.pivot = new Vector2(0.5f, 0.5f); _base.anchoredPosition = c; } }

        bool ToLocal(PointerEventData e, out Vector2 local)
        {
            return RectTransformUtility.ScreenPointToLocalPointInRectangle(_area, e.position, e.pressEventCamera, out local);
        }

        public void OnPointerDown(PointerEventData e)
        {
            if (_id != Unset) return;
            Vector2 local; if (!ToLocal(e, out local)) return;
            _id = e.pointerId;
            // alan sol-alt köşe pivotlu → local zaten alt-sol referanslı; kenarlardan taşmasın
            local.x = Mathf.Clamp(local.x - _area.rect.xMin, Radius, _area.rect.width - Radius);
            local.y = Mathf.Clamp(local.y - _area.rect.yMin, Radius, _area.rect.height - Radius);
            Place(local); Value = Vector2.zero; if (_knob != null) _knob.anchoredPosition = Vector2.zero;
        }

        public void OnDrag(PointerEventData e)
        {
            if (e.pointerId != _id) return;
            Vector2 local; if (!ToLocal(e, out local)) return;
            local -= new Vector2(_area.rect.xMin, _area.rect.yMin);
            var d = local - _center;
            if (d.magnitude > Radius) d = d.normalized * Radius;
            Value = d / Radius;
            if (_knob != null) _knob.anchoredPosition = d;
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (e.pointerId != _id) return;
            _id = Unset; Hide();
        }

        void OnDisable() { _id = Unset; Value = Vector2.zero; }
    }

    /// <summary>Basılı tutma/bırakma ve kaydırma algılayan düğme. Tek parmak sahipliği: ikinci parmak aynı düğmeyi bozmaz.</summary>
    public class HoldButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IDragHandler
    {
        public bool Pressed { get; private set; }
        public float Held { get; private set; }
        public Action OnDown;
        public Action<float, Vector2> OnUp;   // basılı süre, kaydırma (ekran pikseli)
        const int Unset = -9999;
        int _id = Unset;
        Vector2 _start, _last;

        public void OnPointerDown(PointerEventData e)
        {
            if (_id != Unset) return;
            _id = e.pointerId; Pressed = true; Held = 0f; _start = _last = e.position;
            if (OnDown != null) OnDown();
        }
        public void OnDrag(PointerEventData e) { if (e.pointerId == _id) _last = e.position; }
        public void OnPointerUp(PointerEventData e)
        {
            if (e.pointerId != _id) return;
            _id = Unset; Pressed = false;
            if (OnUp != null) OnUp(Held, e.position - _start);
        }
        void Update() { if (Pressed) Held += Time.unscaledDeltaTime; }
        void OnDisable() { _id = Unset; Pressed = false; Held = 0f; }
    }

    /// <summary>Maç içi arayüz: joystick, bağlamsal düğmeler, skor/süre, mini harita, oyuncu etiketi, duraklatma.</summary>
    public class FieldHud : MonoBehaviour
    {
        public VirtualJoystick Joystick;
        public bool SprintHeld { get { return _sprint != null && _sprint.Pressed; } }
        public Action<float> OnPass, OnThrough, OnShoot;
        public Action<int> OnSkill;
        public Action OnSlide, OnPause;

        ControlField _sim; FieldWorld _world; ProfileSettings _settings; string _playerName;
        Canvas _canvas;
        HoldButton _pass, _through, _shoot, _sprint, _skill, _slide;
        RectTransform _buttonsRoot;
        Text _score, _clock, _banner, _hint, _nameTag, _ownership;
        Image _powerBar; RectTransform _powerRoot, _stamina; Image _staminaFill;
        RectTransform _mini; readonly Dictionary<string, RectTransform> _dots = new Dictionary<string, RectTransform>();
        RectTransform _pauseRoot;
        float _bannerTimer, _hintTimer = 7f;
        BallOwnership _lastOwnership = (BallOwnership)(-1); MatchPhase _lastPhase = (MatchPhase)(-1);
        string _scorer = "";
        public bool Paused { get; private set; }

        const float Unit = 1f;

        public void Build(ControlField sim, FieldWorld world, ProfileSettings settings, string playerName)
        {
            _sim = sim; _world = world; _settings = settings; _playerName = playerName;
            var cgo = new GameObject("HudCanvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            cgo.transform.SetParent(transform, false);
            _canvas = cgo.GetComponent<Canvas>(); _canvas.renderMode = RenderMode.ScreenSpaceOverlay; _canvas.sortingOrder = 20;
            var sc = cgo.GetComponent<CanvasScaler>(); sc.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            sc.referenceResolution = new Vector2(DesignTokens.ReferenceResolution[0], DesignTokens.ReferenceResolution[1]); sc.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight; sc.matchWidthOrHeight = 0.5f;
            var safe = Ui.NewRect("Safe", cgo.transform); Ui.Stretch(safe); safe.gameObject.AddComponent<SafeAreaFitter>();

            BuildJoystick(safe);
            BuildButtons(safe);
            BuildTop(safe);
            BuildMiniMap(safe);

            _nameTag = Ui.FitLabel(cgo.transform, _playerName, 30, Ui.Yellow, TextAnchor.MiddleCenter, FontStyle.Bold, "NameTag");
            var nt = _nameTag.rectTransform; nt.anchorMin = nt.anchorMax = Vector2.zero; nt.pivot = new Vector2(0.5f, 0); nt.sizeDelta = new Vector2(360, 44);
            var shadow = _nameTag.gameObject.AddComponent<Shadow>(); shadow.effectColor = new Color(0, 0, 0, 0.9f); shadow.effectDistance = new Vector2(2, -2);

            _banner = Ui.FitLabel(safe, "", 140, Ui.Yellow, TextAnchor.MiddleCenter, FontStyle.Bold, "Banner");
            var br = _banner.rectTransform; br.anchorMin = br.anchorMax = new Vector2(0.5f, 0.62f); br.pivot = new Vector2(0.5f, 0.5f); br.sizeDelta = new Vector2(1500, 220);
            var bs = _banner.gameObject.AddComponent<Shadow>(); bs.effectColor = new Color(0, 0, 0, 0.9f); bs.effectDistance = new Vector2(4, -4);
            _hint = Ui.Label(safe, "Joystick: koş  |  PAS / ŞUT: basılı tut = güç  |  BECERİ: sağa-sola kaydır  |  Top rakipteyse KAY", 26, Ui.TextLight, TextAnchor.MiddleCenter);
            var hr = _hint.rectTransform; hr.anchorMin = hr.anchorMax = new Vector2(0.5f, 0); hr.pivot = new Vector2(0.5f, 0); hr.anchoredPosition = new Vector2(0, 12); hr.sizeDelta = new Vector2(1500, 40);
            var hs = _hint.gameObject.AddComponent<Shadow>(); hs.effectColor = new Color(0, 0, 0, 0.9f); hs.effectDistance = new Vector2(2, -2);
            BuildPause(cgo.transform);
        }

        void BuildJoystick(RectTransform safe)
        {
            var area = Ui.NewRect("JoyArea", safe);
            area.anchorMin = Vector2.zero; area.anchorMax = new Vector2(0.45f, 0.62f); area.offsetMin = area.offsetMax = Vector2.zero; area.pivot = new Vector2(0, 0);
            var ai = area.gameObject.AddComponent<Image>(); ai.color = new Color(0, 0, 0, 0.001f); ai.raycastTarget = true;
            var baseImg = Ui.Panel(area, "JoyBase", new Color(1, 1, 1, 0.16f), false); baseImg.sprite = Ui.Circle; baseImg.type = Image.Type.Simple; baseImg.raycastTarget = false; baseImg.rectTransform.sizeDelta = new Vector2(240, 240);
            var knob = Ui.Panel(baseImg.transform, "Knob", new Color(1f, 0.84f, 0f, 0.8f), false); knob.sprite = Ui.Circle; knob.type = Image.Type.Simple; knob.raycastTarget = false;
            knob.rectTransform.anchorMin = knob.rectTransform.anchorMax = new Vector2(0.5f, 0.5f); knob.rectTransform.pivot = new Vector2(0.5f, 0.5f); knob.rectTransform.sizeDelta = new Vector2(110, 110);
            Joystick = area.gameObject.AddComponent<VirtualJoystick>();
            Joystick.Setup(area, baseImg.rectTransform, knob.rectTransform);
        }

        HoldButton MakeBtn(Transform parent, string label, Vector2 pos, float size, Color bg, Color fg)
        {
            float s = size * _settings.ButtonScale;
            var img = Ui.Panel(parent, "Btn_" + label, bg, false, true); img.sprite = Ui.Circle; img.type = Image.Type.Simple;
            var rt = img.rectTransform; rt.anchorMin = rt.anchorMax = new Vector2(1, 0); rt.pivot = new Vector2(0.5f, 0.5f); rt.anchoredPosition = pos; rt.sizeDelta = new Vector2(s, s);
            var t = Ui.FitLabel(img.transform, label, Mathf.RoundToInt(s * 0.22f), fg, TextAnchor.MiddleCenter, FontStyle.Bold); Ui.Stretch(t.rectTransform, 6, 6, 6, 6);
            return img.gameObject.AddComponent<HoldButton>();
        }

        void BuildButtons(RectTransform safe)
        {
            _buttonsRoot = Ui.NewRect("Buttons", safe); Ui.Stretch(_buttonsRoot);
            var y = Ui.Yellow; var n = Ui.Navy; var s = new Color(0.07f, 0.16f, 0.32f, 0.9f); var w = Ui.TextLight;
            float k = Mathf.Max(0.8f, _settings.ButtonScale);
            _shoot = MakeBtn(_buttonsRoot, "ŞUT", new Vector2(-190, 200) * k, 190, y, n);
            _pass = MakeBtn(_buttonsRoot, "PAS", new Vector2(-430, 140) * k, 168, s, w);
            _through = MakeBtn(_buttonsRoot, "ARA", new Vector2(-330, 380) * k, 140, s, w);
            _skill = MakeBtn(_buttonsRoot, "BECERİ", new Vector2(-110, 420) * k, 140, s, w);
            _sprint = MakeBtn(_buttonsRoot, "SPRİNT", new Vector2(-620, 300) * k, 150, s, w);
            _slide = MakeBtn(_buttonsRoot, "KAY", new Vector2(-190, 200) * k, 190, Ui.Danger, w);

            _pass.OnUp = (held, d) => { if (OnPass != null) OnPass(ChargeCurve.Power(held)); };
            _through.OnUp = (held, d) => { if (OnThrough != null) OnThrough(ChargeCurve.Power(held)); };
            _shoot.OnUp = (held, d) => { if (OnShoot != null) OnShoot(ChargeCurve.Power(held)); };
            _skill.OnUp = (held, d) =>
            {
                // Kaydırma: sol/sağ yön. Dokunuş: joystick yönüne göre (sol/sağ taraf) çalım.
                float thr = 40f; int dir = 0;
                if (Mathf.Abs(d.x) > thr) dir = d.x < 0 ? -1 : 1;
                else
                {
                    var f = _sim.Player.Facing; var m = new Fenerbahce.Core.Sim.Vec2(Joystick.Value.x, Joystick.Value.y);
                    float cross = f.X * m.Y - f.Y * m.X; // + = joystick oyuncunun solunda
                    dir = Mathf.Abs(cross) > 0.15f ? (cross > 0 ? -1 : 1) : -1;
                }
                if (OnSkill != null) OnSkill(dir);
            };
            _slide.OnDown = () => { if (OnSlide != null) OnSlide(); };
        }

        void BuildTop(RectTransform safe)
        {
            var bar = Ui.Panel(safe, "ScoreBar", new Color(0.03f, 0.1f, 0.22f, 0.88f), true);
            bar.rectTransform.anchorMin = bar.rectTransform.anchorMax = new Vector2(0.5f, 1); bar.rectTransform.pivot = new Vector2(0.5f, 1); bar.rectTransform.anchoredPosition = new Vector2(0, -12); bar.rectTransform.sizeDelta = new Vector2(620, 84);
            _score = Ui.FitLabel(bar.transform, "KANARYA  0 - 0  RAKİP", 38, Ui.TextLight, TextAnchor.MiddleCenter, FontStyle.Bold); _score.rectTransform.anchorMin = Vector2.zero; _score.rectTransform.anchorMax = new Vector2(1, 1); _score.rectTransform.offsetMin = new Vector2(10, 30); _score.rectTransform.offsetMax = new Vector2(-10, -4);
            _clock = Ui.FitLabel(bar.transform, "2:00", 28, Ui.Yellow, TextAnchor.MiddleCenter, FontStyle.Bold); _clock.rectTransform.anchorMin = Vector2.zero; _clock.rectTransform.anchorMax = new Vector2(1, 0); _clock.rectTransform.offsetMin = new Vector2(10, 2); _clock.rectTransform.offsetMax = new Vector2(-10, 34);

            var p = Ui.MakeButton(safe, "II", Ui.SurfaceRaised, Ui.TextLight, () => { if (OnPause != null) OnPause(); }, "Pause", 40);
            var pr = (RectTransform)p.transform; pr.anchorMin = pr.anchorMax = new Vector2(1, 1); pr.pivot = new Vector2(1, 1); pr.anchoredPosition = new Vector2(-16, -12); pr.sizeDelta = new Vector2(96, 84);

            // stamina + sahiplik etiketi (sol üst)
            var sb = Ui.Panel(safe, "StaminaBg", new Color(0, 0, 0, 0.5f), true); sb.rectTransform.anchorMin = sb.rectTransform.anchorMax = new Vector2(0, 1); sb.rectTransform.pivot = new Vector2(0, 1); sb.rectTransform.anchoredPosition = new Vector2(16, -16); sb.rectTransform.sizeDelta = new Vector2(300, 26);
            _stamina = sb.rectTransform;
            _staminaFill = Ui.Panel(sb.transform, "Fill", Ui.Success, true); _staminaFill.rectTransform.anchorMin = Vector2.zero; _staminaFill.rectTransform.anchorMax = Vector2.one; _staminaFill.rectTransform.offsetMin = new Vector2(3, 3); _staminaFill.rectTransform.offsetMax = new Vector2(-3, -3);
            var sl = Ui.Label(safe, "DAYANIKLILIK", 18, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold); sl.rectTransform.anchorMin = sl.rectTransform.anchorMax = new Vector2(0, 1); sl.rectTransform.pivot = new Vector2(0, 1); sl.rectTransform.anchoredPosition = new Vector2(16, -46); sl.rectTransform.sizeDelta = new Vector2(300, 24);
            _ownership = Ui.Label(safe, "", 26, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); _ownership.rectTransform.anchorMin = _ownership.rectTransform.anchorMax = new Vector2(0, 1); _ownership.rectTransform.pivot = new Vector2(0, 1); _ownership.rectTransform.anchoredPosition = new Vector2(16, -76); _ownership.rectTransform.sizeDelta = new Vector2(400, 36);

            // güç çubuğu (şut/pas basılıyken)
            _powerRoot = Ui.Panel(safe, "PowerBg", new Color(0, 0, 0, 0.55f), true).rectTransform;
            _powerRoot.anchorMin = _powerRoot.anchorMax = new Vector2(1, 0); _powerRoot.pivot = new Vector2(1, 0); _powerRoot.anchoredPosition = new Vector2(-60, 560); _powerRoot.sizeDelta = new Vector2(34, 260);
            _powerBar = Ui.Panel(_powerRoot, "PowerFill", Ui.Yellow, true); _powerBar.rectTransform.anchorMin = Vector2.zero; _powerBar.rectTransform.anchorMax = new Vector2(1, 0); _powerBar.rectTransform.offsetMin = new Vector2(4, 4); _powerBar.rectTransform.offsetMax = new Vector2(-4, 4);
            _powerRoot.gameObject.SetActive(false);
        }

        void BuildMiniMap(RectTransform safe)
        {
            var bg = Ui.Panel(safe, "MiniMap", new Color(0.05f, 0.35f, 0.15f, 0.72f), true);
            bg.rectTransform.anchorMin = bg.rectTransform.anchorMax = new Vector2(0.5f, 0); bg.rectTransform.pivot = new Vector2(0.5f, 0); bg.rectTransform.anchoredPosition = new Vector2(0, 62); bg.rectTransform.sizeDelta = new Vector2(330, 214);
            _mini = bg.rectTransform;
            var mid = Ui.Panel(_mini, "Mid", new Color(1, 1, 1, 0.4f), false); mid.rectTransform.anchorMin = new Vector2(0.5f, 0); mid.rectTransform.anchorMax = new Vector2(0.5f, 1); mid.rectTransform.offsetMin = new Vector2(-1, 4); mid.rectTransform.offsetMax = new Vector2(1, -4);
            AddDot("player", Ui.Yellow, 16); AddDot("defender", Ui.Danger, 14); AddDot("keeper", Ui.Success, 14); AddDot("ball", Color.white, 10);
            for (int i = 0; i < _sim.Config.PassTargets.Count; i++) AddDot("t" + i, new Color(0.3f, 0.85f, 1f, 0.9f), 10);
        }

        void AddDot(string key, Color c, float size)
        {
            var d = Ui.Panel(_mini, "Dot_" + key, c, false); d.sprite = Ui.Circle; d.type = Image.Type.Simple;
            d.rectTransform.anchorMin = d.rectTransform.anchorMax = Vector2.zero; d.rectTransform.pivot = new Vector2(0.5f, 0.5f); d.rectTransform.sizeDelta = new Vector2(size, size);
            _dots[key] = d.rectTransform;
        }

        void BuildPause(Transform canvasRoot)
        {
            _pauseRoot = Ui.NewRect("Pause", canvasRoot); Ui.Stretch(_pauseRoot);
            var dim = Ui.Panel(_pauseRoot, "Dim", new Color(0, 0, 0, 0.75f), false, true); Ui.Stretch(dim.rectTransform);
            var box = Ui.Panel(_pauseRoot, "Box", Ui.Surface, true, true); Ui.Anchor(box.rectTransform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(760, 560)); box.rectTransform.pivot = new Vector2(0.5f, 0.5f);
            var t = Ui.FitLabel(box.transform, "DURAKLATILDI", 56, Ui.Yellow, TextAnchor.MiddleCenter, FontStyle.Bold); t.rectTransform.anchorMin = new Vector2(0, 1); t.rectTransform.anchorMax = new Vector2(1, 1); t.rectTransform.pivot = new Vector2(0.5f, 1); t.rectTransform.offsetMin = new Vector2(20, -130); t.rectTransform.offsetMax = new Vector2(-20, -30);
            var col = Ui.VCol(box.transform, "Col", 20, TextAnchor.UpperCenter, false); Ui.Stretch((RectTransform)col.transform, 60, 150, 60, 40);
            var a = Ui.PrimaryButton(col.transform, "DEVAM", () => SetPaused(false), 40); Ui.Size(a.gameObject, -1, 96);
            var b = Ui.SecondaryButton(col.transform, "BİTİR VE ÖDÜLÜ AL", () => { SetPaused(false); if (OnFinish != null) OnFinish(); }, 34); Ui.Size(b.gameObject, -1, 96);
            var c = Ui.MakeButton(col.transform, "ÇIKIŞ (ÖDÜLSÜZ)", Ui.Danger, Ui.TextLight, () => { SetPaused(false); if (OnQuit != null) OnQuit(); }, "Quit", 34); Ui.Size(c.gameObject, -1, 96);
            _pauseRoot.gameObject.SetActive(false);
        }

        public Action OnFinish, OnQuit;
        public void SetPaused(bool p) { Paused = p; _pauseRoot.gameObject.SetActive(p); }

        public void Banner(string text, float seconds, Color? color = null)
        {
            _banner.text = text; _banner.color = color ?? Ui.Yellow; _bannerTimer = seconds;
        }

        public void SetScorer(string name) { _scorer = name; }

        // ---------- her kare ----------
        void Update()
        {
            if (_sim == null) return;
            var own = _sim.Ownership; var phase = _sim.Machine.Phase;
            bool live = phase == MatchPhase.Live;
            if (own != _lastOwnership || phase != _lastPhase) { ApplyButtonSet(own, phase); _lastOwnership = own; _lastPhase = phase; }

            _score.text = "KANARYA  " + _sim.Machine.ScoreHome + " - " + _sim.Machine.ScoreAway + "  RAKİP";
            int rem = Mathf.CeilToInt(_sim.RemainingSeconds);
            _clock.text = (rem / 60) + ":" + (rem % 60).ToString("00") + (live ? "" : "   " + PhaseLabel(phase));
            _staminaFill.rectTransform.anchorMax = new Vector2(Mathf.Clamp01(_sim.Player.Stamina), 1f);
            _staminaFill.color = _sim.Player.Stamina > 0.35f ? Ui.Success : Ui.Danger;
            _ownership.text = own == BallOwnership.Ours ? "TOP BİZDE" : own == BallOwnership.Theirs ? "TOP RAKİPTE" : "SERBEST TOP";
            _ownership.color = own == BallOwnership.Ours ? Ui.Success : own == BallOwnership.Theirs ? Ui.Danger : Ui.Yellow;

            if (_bannerTimer > 0) { _bannerTimer -= Time.unscaledDeltaTime; if (_bannerTimer <= 0) _banner.text = ""; }
            if (_hintTimer > 0) { _hintTimer -= Time.unscaledDeltaTime; if (_hintTimer <= 0) _hint.gameObject.SetActive(false); }

            // güç çubuğu
            HoldButton charging = _shoot.Pressed ? _shoot : _pass.Pressed ? _pass : _through.Pressed ? _through : null;
            _powerRoot.gameObject.SetActive(charging != null && own == BallOwnership.Ours);
            if (charging != null) _powerBar.rectTransform.anchorMax = new Vector2(1f, ChargeCurve.Power(charging.Held));

            // oyuncu adı etiketi (T029)
            var sp = _world.WorldToScreen(new Vector3(_sim.Player.Pos.X, 2.4f, _sim.Player.Pos.Y));
            var scale = _canvas.scaleFactor <= 0f ? 1f : _canvas.scaleFactor;
            _nameTag.rectTransform.anchoredPosition = sp / scale;

            UpdateMiniMap();
        }

        static string PhaseLabel(MatchPhase p)
        {
            switch (p)
            {
                case MatchPhase.Kickoff: return "SANTRA";
                case MatchPhase.GoalCelebration: return "GOL";
                case MatchPhase.FullTime: case MatchPhase.Result: return "BİTTİ";
                default: return "";
            }
        }

        void ApplyButtonSet(BallOwnership own, MatchPhase phase)
        {
            var set = HudLayout.ButtonsFor(own, phase);
            Show(_pass, set.Contains(HudButton.Pass)); Show(_through, set.Contains(HudButton.ThroughPass));
            Show(_shoot, set.Contains(HudButton.Shoot)); Show(_sprint, set.Contains(HudButton.Sprint));
            Show(_skill, set.Contains(HudButton.Skill)); Show(_slide, set.Contains(HudButton.Slide));
            var lbl = _slide.GetComponentInChildren<Text>(); if (lbl != null) lbl.text = HudLayout.Label(HudButton.Slide, own);
        }

        static void Show(HoldButton b, bool on) { b.gameObject.SetActive(on); }

        void UpdateMiniMap()
        {
            var p = _sim.Pitch; float w = _mini.rect.width, h = _mini.rect.height;
            Func<Fenerbahce.Core.Sim.Vec2, Vector2> map = v => new Vector2((v.X / (p.HalfLength * 2) + 0.5f) * w, (v.Y / (p.HalfWidth * 2) + 0.5f) * h);
            _dots["player"].anchoredPosition = map(_sim.Player.Pos);
            _dots["defender"].gameObject.SetActive(_sim.Config.DefenderEnabled); _dots["defender"].anchoredPosition = map(_sim.Defender.Pos);
            _dots["keeper"].anchoredPosition = map(_sim.Keeper.Pos);
            _dots["ball"].anchoredPosition = map(_sim.Ball.Pos);
            for (int i = 0; i < _sim.Config.PassTargets.Count; i++) _dots["t" + i].anchoredPosition = map(_sim.Config.PassTargets[i]);
        }

        public string ScorerForBanner { get { return _scorer; } }
    }
}
