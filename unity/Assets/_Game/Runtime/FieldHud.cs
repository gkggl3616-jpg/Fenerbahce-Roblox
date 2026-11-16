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

    /// <summary>
    /// Maç içi arayüz: joystick, bağlamsal düğmeler (referans galerideki hücum/savunma setleri, G35–G37), skor/saat,
    /// mini harita, oyuncu etiketi, duraklatma. Kaynak <see cref="FieldSource"/>'tur (tek futbolcu sahası veya 5v5 maç).
    /// </summary>
    public class FieldHud : MonoBehaviour
    {
        public VirtualJoystick Joystick;
        public bool SprintHeld { get { return (_sprintSkill != null && _sprintSkill.Pressed) || (_sprintTackle != null && _sprintTackle.Pressed); } }
        public Action<float> OnPass, OnThrough, OnShoot;
        public Action<int> OnSkill;
        public Action OnClear, OnTackle, OnSwitch, OnSecondDef, OnAutoToggle, OnSlide, OnPause, OnFinish, OnQuit;

        /// <summary>Kısa dokunuş eşiği: "SPRİNT VE ..." düğmelerinde bundan kısa basış eylem, uzun basış sprint sayılır.</summary>
        public const float TapSeconds = 0.22f;

        FieldSource _src; FieldWorld _world; ProfileSettings _settings;
        Canvas _canvas;
        HoldButton _pass, _through, _shoot, _sprintSkill, _sprintTackle, _slide, _second, _switch, _auto;
        Text _shootLabel; Image _autoBg;
        RectTransform _buttonsRoot;
        Text _score, _clock, _banner, _hint, _nameTag, _ownership;
        Image _powerBar; RectTransform _powerRoot, _stamina; Image _staminaFill;
        RectTransform _mini; readonly List<RectTransform> _dots = new List<RectTransform>(); readonly List<Image> _dotImgs = new List<Image>();
        readonly List<MiniDot> _dotData = new List<MiniDot>();
        RectTransform _pauseRoot;
        float _bannerTimer, _hintTimer = 8f;
        int _lastMask = -1; bool _lastAuto; bool _clearMode;
        public bool Paused { get; private set; }

        public void Build(FieldSource src, FieldWorld world, ProfileSettings settings)
        {
            _src = src; _world = world; _settings = settings;
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

            _nameTag = Ui.FitLabel(cgo.transform, _src.ControlledName, 30, Ui.Yellow, TextAnchor.MiddleCenter, FontStyle.Bold, "NameTag");
            var nt = _nameTag.rectTransform; nt.anchorMin = nt.anchorMax = Vector2.zero; nt.pivot = new Vector2(0.5f, 0); nt.sizeDelta = new Vector2(360, 44);
            var shadow = _nameTag.gameObject.AddComponent<Shadow>(); shadow.effectColor = new Color(0, 0, 0, 0.9f); shadow.effectDistance = new Vector2(2, -2);

            _banner = Ui.FitLabel(safe, "", 140, Ui.Yellow, TextAnchor.MiddleCenter, FontStyle.Bold, "Banner");
            var br = _banner.rectTransform; br.anchorMin = br.anchorMax = new Vector2(0.5f, 0.62f); br.pivot = new Vector2(0.5f, 0.5f); br.sizeDelta = new Vector2(1500, 220);
            var bs = _banner.gameObject.AddComponent<Shadow>(); bs.effectColor = new Color(0, 0, 0, 0.9f); bs.effectDistance = new Vector2(4, -4);
            bool team = _src.Bodies.Count > 2;
            _hint = Ui.Label(safe, team
                ? "Joystick: koş  |  PAS/ŞUT: basılı tut = güç  |  SPRİNT VE BECERİ: basılı tut = sprint, dokun/kaydır = çalım  |  Top rakipteyse DEĞİŞTİR, 2. DEF, KAY, OTO."
                : "Joystick: koş  |  PAS / ŞUT: basılı tut = güç  |  SPRİNT VE BECERİ: basılı tut = sprint, dokun/kaydır = çalım  |  Top rakipteyse KAY", 24, Ui.TextLight, TextAnchor.MiddleCenter);
            var hr = _hint.rectTransform; hr.anchorMin = hr.anchorMax = new Vector2(0.5f, 0); hr.pivot = new Vector2(0.5f, 0); hr.anchoredPosition = new Vector2(0, 12); hr.sizeDelta = new Vector2(1700, 40);
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

        HoldButton MakeBtn(Transform parent, string label, Vector2 pos, float size, Color bg, Color fg, bool left, out Text labelText)
        {
            float s = size * _settings.ButtonScale;
            var img = Ui.Panel(parent, "Btn_" + label.Replace("\n", " "), bg, false, true); img.sprite = Ui.Circle; img.type = Image.Type.Simple;
            var rt = img.rectTransform; rt.anchorMin = rt.anchorMax = left ? new Vector2(0, 0) : new Vector2(1, 0); rt.pivot = new Vector2(0.5f, 0.5f); rt.anchoredPosition = pos; rt.sizeDelta = new Vector2(s, s);
            bool two = label.IndexOf('\n') >= 0;
            labelText = Ui.FitLabel(img.transform, label, Mathf.RoundToInt(s * (two ? 0.17f : 0.22f)), fg, TextAnchor.MiddleCenter, FontStyle.Bold); Ui.Stretch(labelText.rectTransform, 8, 8, 8, 8);
            return img.gameObject.AddComponent<HoldButton>();
        }

        HoldButton MakeBtn(Transform parent, string label, Vector2 pos, float size, Color bg, Color fg, bool left = false)
        {
            Text t; return MakeBtn(parent, label, pos, size, bg, fg, left, out t);
        }

        void BuildButtons(RectTransform safe)
        {
            _buttonsRoot = Ui.NewRect("Buttons", safe); Ui.Stretch(_buttonsRoot);
            var y = Ui.Yellow; var n = Ui.Navy; var s = new Color(0.07f, 0.16f, 0.32f, 0.9f); var w = Ui.TextLight;
            float k = Mathf.Max(0.8f, _settings.ButtonScale);
            // Yerleşim referans galeriye göre: sağ altta büyük "SPRİNT VE ...", üstünde ŞUT/KAY, solunda PAS/DEĞİŞTİR, ARA/2. DEF köşede.
            _sprintSkill = MakeBtn(_buttonsRoot, "SPRİNT\nVE BECERİ", new Vector2(-170, 175) * k, 250, y, n);
            _sprintTackle = MakeBtn(_buttonsRoot, "SPRİNT\nVE MÜDAHALE", new Vector2(-170, 175) * k, 250, y, n);
            _shoot = MakeBtn(_buttonsRoot, "ŞUT", new Vector2(-170, 440) * k, 170, s, w, false, out _shootLabel);
            _slide = MakeBtn(_buttonsRoot, "KAY", new Vector2(-170, 440) * k, 170, Ui.Danger, w);
            _pass = MakeBtn(_buttonsRoot, "PAS", new Vector2(-450, 170) * k, 175, s, w);
            _switch = MakeBtn(_buttonsRoot, "DEĞİŞTİR", new Vector2(-450, 170) * k, 175, s, w);
            _through = MakeBtn(_buttonsRoot, "ARA", new Vector2(-420, 420) * k, 140, s, w);
            _second = MakeBtn(_buttonsRoot, "2. DEF", new Vector2(-420, 420) * k, 140, s, w);
            _auto = MakeBtn(_buttonsRoot, "OTO.", new Vector2(110, 720) * k, 120, s, w, true);
            _autoBg = _auto.GetComponent<Image>();

            _pass.OnUp = (held, d) => { if (OnPass != null) OnPass(ChargeCurve.Power(held)); };
            _through.OnUp = (held, d) => { if (OnThrough != null) OnThrough(ChargeCurve.Power(held)); };
            _shoot.OnUp = (held, d) =>
            {
                if (_clearMode) { if (OnClear != null) OnClear(); }
                else if (OnShoot != null) OnShoot(ChargeCurve.Power(held));
            };
            // SPRİNT VE BECERİ: basılı tut = sprint; kısa dokunuş veya kaydırma = çalım (kaydırma sol/sağ yön verir).
            _sprintSkill.OnUp = (held, d) =>
            {
                float thr = 40f; int dir = 0; bool swipe = Mathf.Abs(d.x) > thr;
                if (!swipe && held > TapSeconds) return; // uzun basış sadece sprint idi
                if (swipe) dir = d.x < 0 ? -1 : 1;
                else
                {
                    var c = _src.Controlled; var f = c != null ? c.Facing : new Fenerbahce.Core.Sim.Vec2(1, 0);
                    var m = new Fenerbahce.Core.Sim.Vec2(Joystick.Value.x, Joystick.Value.y);
                    float cross = f.X * m.Y - f.Y * m.X; // + = joystick oyuncunun solunda
                    dir = Mathf.Abs(cross) > 0.15f ? (cross > 0 ? -1 : 1) : -1;
                }
                if (OnSkill != null) OnSkill(dir);
            };
            // SPRİNT VE MÜDAHALE: basılı tut = sprint; kısa dokunuş = ayakta müdahale.
            _sprintTackle.OnUp = (held, d) => { if (held <= TapSeconds && OnTackle != null) OnTackle(); };
            _slide.OnDown = () => { if (OnSlide != null) OnSlide(); };
            _switch.OnDown = () => { if (OnSwitch != null) OnSwitch(); };
            _second.OnDown = () => { if (OnSecondDef != null) OnSecondDef(); };
            _auto.OnDown = () => { if (OnAutoToggle != null) OnAutoToggle(); };
        }

        void BuildTop(RectTransform safe)
        {
            var bar = Ui.Panel(safe, "ScoreBar", new Color(0.03f, 0.1f, 0.22f, 0.88f), true);
            bar.rectTransform.anchorMin = bar.rectTransform.anchorMax = new Vector2(0.5f, 1); bar.rectTransform.pivot = new Vector2(0.5f, 1); bar.rectTransform.anchoredPosition = new Vector2(0, -12); bar.rectTransform.sizeDelta = new Vector2(620, 84);
            _score = Ui.FitLabel(bar.transform, _src.HomeName + "  0 - 0  " + _src.AwayName, 38, Ui.TextLight, TextAnchor.MiddleCenter, FontStyle.Bold); _score.rectTransform.anchorMin = Vector2.zero; _score.rectTransform.anchorMax = new Vector2(1, 1); _score.rectTransform.offsetMin = new Vector2(10, 30); _score.rectTransform.offsetMax = new Vector2(-10, -4);
            _clock = Ui.FitLabel(bar.transform, "0:00", 28, Ui.Yellow, TextAnchor.MiddleCenter, FontStyle.Bold); _clock.rectTransform.anchorMin = Vector2.zero; _clock.rectTransform.anchorMax = new Vector2(1, 0); _clock.rectTransform.offsetMin = new Vector2(10, 2); _clock.rectTransform.offsetMax = new Vector2(-10, 34);

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
            _powerRoot.anchorMin = _powerRoot.anchorMax = new Vector2(1, 0); _powerRoot.pivot = new Vector2(1, 0); _powerRoot.anchoredPosition = new Vector2(-60, 620); _powerRoot.sizeDelta = new Vector2(34, 260);
            _powerBar = Ui.Panel(_powerRoot, "PowerFill", Ui.Yellow, true); _powerBar.rectTransform.anchorMin = Vector2.zero; _powerBar.rectTransform.anchorMax = new Vector2(1, 0); _powerBar.rectTransform.offsetMin = new Vector2(4, 4); _powerBar.rectTransform.offsetMax = new Vector2(-4, 4);
            _powerRoot.gameObject.SetActive(false);
        }

        void BuildMiniMap(RectTransform safe)
        {
            var bg = Ui.Panel(safe, "MiniMap", new Color(0.05f, 0.35f, 0.15f, 0.72f), true);
            bg.rectTransform.anchorMin = bg.rectTransform.anchorMax = new Vector2(0.5f, 0); bg.rectTransform.pivot = new Vector2(0.5f, 0); bg.rectTransform.anchoredPosition = new Vector2(0, 62); bg.rectTransform.sizeDelta = new Vector2(330, 214);
            _mini = bg.rectTransform;
            var mid = Ui.Panel(_mini, "Mid", new Color(1, 1, 1, 0.4f), false); mid.rectTransform.anchorMin = new Vector2(0.5f, 0); mid.rectTransform.anchorMax = new Vector2(0.5f, 1); mid.rectTransform.offsetMin = new Vector2(-1, 4); mid.rectTransform.offsetMax = new Vector2(1, -4);
        }

        RectTransform DotAt(int i)
        {
            while (_dots.Count <= i)
            {
                var d = Ui.Panel(_mini, "Dot" + _dots.Count, Color.white, false); d.sprite = Ui.Circle; d.type = Image.Type.Simple; d.raycastTarget = false;
                d.rectTransform.anchorMin = d.rectTransform.anchorMax = Vector2.zero; d.rectTransform.pivot = new Vector2(0.5f, 0.5f);
                _dots.Add(d.rectTransform); _dotImgs.Add(d);
            }
            return _dots[i];
        }

        static void StyleDot(DotKind kind, out Color c, out float size)
        {
            switch (kind)
            {
                case DotKind.Controlled: c = Ui.Yellow; size = 18; break;
                case DotKind.Mate: c = new Color(1f, 0.84f, 0f, 0.7f); size = 13; break;
                case DotKind.Opponent: c = Ui.Danger; size = 14; break;
                case DotKind.KeeperHome: c = Ui.Success; size = 14; break;
                case DotKind.KeeperAway: c = new Color(0.95f, 0.55f, 0.15f); size = 14; break;
                case DotKind.Ball: c = Color.white; size = 10; break;
                default: c = new Color(0.3f, 0.85f, 1f, 0.9f); size = 10; break;
            }
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

        public void SetPaused(bool p) { Paused = p; _pauseRoot.gameObject.SetActive(p); }

        public void Banner(string text, float seconds, Color? color = null)
        {
            _banner.text = text; _banner.color = color ?? Ui.Yellow; _bannerTimer = seconds;
        }

        // ---------- her kare ----------
        void Update()
        {
            if (_src == null) return;
            var phase = _src.Machine.Phase; var own = _src.Ownership;
            bool live = phase == MatchPhase.Live;
            var set = _src.Buttons;
            int mask = 0; for (int i = 0; i < set.Count; i++) mask |= 1 << (int)set[i];
            if (mask != _lastMask || _src.AutoDefend != _lastAuto) { ApplyButtonSet(set); _lastMask = mask; _lastAuto = _src.AutoDefend; }

            _score.text = _src.HomeName + "  " + _src.Machine.ScoreHome + " - " + _src.Machine.ScoreAway + "  " + _src.AwayName;
            _clock.text = _src.ClockText + (live ? "" : "   " + PhaseLabel(phase));
            var ctl = _src.Controlled; float stam = ctl != null ? ctl.Stamina : 1f;
            _staminaFill.rectTransform.anchorMax = new Vector2(Mathf.Clamp01(stam), 1f);
            _staminaFill.color = stam > 0.35f ? Ui.Success : Ui.Danger;
            _ownership.text = own == BallOwnership.Ours ? "TOP BİZDE" : own == BallOwnership.Theirs ? "TOP RAKİPTE" : "SERBEST TOP";
            _ownership.color = own == BallOwnership.Ours ? Ui.Success : own == BallOwnership.Theirs ? Ui.Danger : Ui.Yellow;

            if (_bannerTimer > 0) { _bannerTimer -= Time.unscaledDeltaTime; if (_bannerTimer <= 0) _banner.text = ""; }
            if (_hintTimer > 0) { _hintTimer -= Time.unscaledDeltaTime; if (_hintTimer <= 0) _hint.gameObject.SetActive(false); }

            // güç çubuğu
            HoldButton charging = (_shoot.Pressed && !_clearMode) ? _shoot : _pass.Pressed ? _pass : _through.Pressed ? _through : null;
            _powerRoot.gameObject.SetActive(charging != null && own == BallOwnership.Ours);
            if (charging != null) _powerBar.rectTransform.anchorMax = new Vector2(1f, ChargeCurve.Power(charging.Held));

            // oyuncu adı etiketi (T029): kontrol edilen oyuncunun üstünde
            if (ctl != null)
            {
                _nameTag.text = _src.ControlledName;
                var sp = _world.WorldToScreen(new Vector3(ctl.Pos.X, 2.4f, ctl.Pos.Y));
                var scale = _canvas.scaleFactor <= 0f ? 1f : _canvas.scaleFactor;
                _nameTag.rectTransform.anchoredPosition = sp / scale;
            }

            UpdateMiniMap();
        }

        static string PhaseLabel(MatchPhase p)
        {
            switch (p)
            {
                case MatchPhase.Kickoff: return "SANTRA";
                case MatchPhase.GoalCelebration: case MatchPhase.Replay: return "GOL";
                case MatchPhase.HalfTime: return "DEVRE ARASI";
                case MatchPhase.FullTime: case MatchPhase.Result: return "BİTTİ";
                default: return "";
            }
        }

        void ApplyButtonSet(IReadOnlyList<HudButton> set)
        {
            Show(_pass, set.Contains(HudButton.Pass)); Show(_through, set.Contains(HudButton.ThroughPass));
            _clearMode = set.Contains(HudButton.Clear);
            Show(_shoot, set.Contains(HudButton.Shoot) || _clearMode);
            if (_shootLabel != null) _shootLabel.text = HudLayout.Label(_clearMode ? HudButton.Clear : HudButton.Shoot, BallOwnership.Ours);
            Show(_sprintSkill, set.Contains(HudButton.SprintSkill)); Show(_sprintTackle, set.Contains(HudButton.SprintTackle));
            Show(_slide, set.Contains(HudButton.Slide)); Show(_second, set.Contains(HudButton.SecondDefender));
            Show(_switch, set.Contains(HudButton.Switch)); Show(_auto, set.Contains(HudButton.AutoDefend));
            // OTO. açıkken sarı (etkin) görünür
            if (_autoBg != null) _autoBg.color = _src.AutoDefend ? Ui.Yellow : new Color(0.07f, 0.16f, 0.32f, 0.9f);
            var al = _auto.GetComponentInChildren<Text>(); if (al != null) al.color = _src.AutoDefend ? Ui.Navy : Ui.TextLight;
        }

        static void Show(HoldButton b, bool on) { b.gameObject.SetActive(on); }

        void UpdateMiniMap()
        {
            var p = _src.Pitch; float w = _mini.rect.width, h = _mini.rect.height;
            _src.FillDots(_dotData);
            for (int i = 0; i < _dotData.Count; i++)
            {
                var rt = DotAt(i); rt.gameObject.SetActive(true);
                Color c; float size; StyleDot(_dotData[i].Kind, out c, out size);
                _dotImgs[i].color = c; rt.sizeDelta = new Vector2(size, size);
                var v = _dotData[i].Pos;
                rt.anchoredPosition = new Vector2((v.X / (p.HalfLength * 2) + 0.5f) * w, (v.Y / (p.HalfWidth * 2) + 0.5f) * h);
            }
            for (int i = _dotData.Count; i < _dots.Count; i++) _dots[i].gameObject.SetActive(false);
        }
    }
}
