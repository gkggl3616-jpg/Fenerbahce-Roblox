using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Design;

namespace Fenerbahce.Runtime
{
    public abstract class GameScreen
    {
        public string Id { get; protected set; }
        public RectTransform Root { get; private set; }
        protected GameApp App { get; private set; }
        public virtual bool IsTab { get { return true; } }

        public void Init(GameApp app, RectTransform parent)
        {
            App = app;
            Root = Ui.NewRect("Screen_" + Id, parent);
            Ui.Stretch(Root);
            Build();
            Root.gameObject.SetActive(false);
        }

        protected abstract void Build();
        public virtual void OnShow() { }
        public virtual bool HandleBack() { return false; }
    }

    /// <summary>Ekran geçmişi (T010): her ana akıştan geri dönülebilir. Sekmeler köke taşır.</summary>
    public class ScreenManager
    {
        readonly GameApp _app;
        readonly Dictionary<string, GameScreen> _screens = new Dictionary<string, GameScreen>();
        readonly List<string> _stack = new List<string>();

        public ScreenManager(GameApp app) { _app = app; }

        public int Depth { get { return _stack.Count; } }
        public string CurrentId { get { return _stack.Count == 0 ? null : _stack[_stack.Count - 1]; } }
        public GameScreen Current { get { return CurrentId == null ? null : _screens[CurrentId]; } }

        public void Register(GameScreen s) { s.Init(_app, _app.Content); _screens[s.Id] = s; }

        public bool CurrentHandlesBack() { return Current != null && Current.HandleBack(); }

        /// <summary>Alt gezinti sekmesi: geçmiş [home, id] olur (home'dan başka sekme için).</summary>
        public void GoRoot(string id)
        {
            _stack.Clear();
            if (id != ScreenIds.Home) _stack.Add(ScreenIds.Home);
            _stack.Add(id);
            Show(id);
        }

        public void Push(string id)
        {
            if (CurrentId == id) return;
            _stack.Add(id); Show(id);
        }

        public void Back()
        {
            if (_stack.Count <= 1) return;
            _stack.RemoveAt(_stack.Count - 1);
            Show(_stack[_stack.Count - 1]);
        }

        void Show(string id)
        {
            foreach (var kv in _screens) kv.Value.Root.gameObject.SetActive(kv.Key == id);
            var s = _screens[id];
            _app.SetChromeVisible(true, true);
            s.OnShow();
            _app.RefreshChrome();
        }
    }

    /// <summary>Üst bar: geri, profil/seviye/XP, coin ve jeton, ayarlar (G02).</summary>
    public class TopBar
    {
        readonly GameApp _app;
        Text _name, _level, _coin, _token;
        Image _xp; Button _back;

        public TopBar(GameApp app, RectTransform root)
        {
            _app = app;
            var bg = Ui.Panel(root, "Bg", Ui.Surface, false); Ui.Stretch(bg.rectTransform);
            var line = Ui.Panel(root, "Line", Ui.Yellow, false); line.rectTransform.anchorMin = new Vector2(0, 0); line.rectTransform.anchorMax = new Vector2(1, 0); line.rectTransform.offsetMin = Vector2.zero; line.rectTransform.offsetMax = new Vector2(0, 4);

            _back = Ui.SecondaryButton(root, "< GERİ", () => { if (!_app.Nav.CurrentHandlesBack()) _app.Nav.Back(); }, 26);
            Ui.PlaceTopLeft((RectTransform)_back.transform, 16, 12, 150, 72);

            _name = Ui.FitLabel(root, "", 30, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold, "Name"); Ui.PlaceTopLeft(_name.rectTransform, 190, 8, 380, 44);
            _level = Ui.Label(root, "", 22, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold, "Level"); Ui.PlaceTopLeft(_level.rectTransform, 190, 52, 90, 32);
            var xpBg = Ui.Panel(root, "XpBg", new Color(1, 1, 1, 0.12f), true); Ui.PlaceTopLeft(xpBg.rectTransform, 284, 62, 280, 14);
            _xp = Ui.Panel(xpBg.transform, "XpFill", Ui.Yellow, true); _xp.rectTransform.anchorMin = Vector2.zero; _xp.rectTransform.anchorMax = new Vector2(0, 1); _xp.rectTransform.offsetMin = _xp.rectTransform.offsetMax = Vector2.zero;

            var settings = Ui.SecondaryButton(root, "AYARLAR", () => _app.Nav.Push(ScreenIds.Settings), 24);
            var sr = (RectTransform)settings.transform; sr.anchorMin = sr.anchorMax = new Vector2(1, 1); sr.pivot = new Vector2(1, 1); sr.anchoredPosition = new Vector2(-16, -12); sr.sizeDelta = new Vector2(190, 72);

            var coinBox = Ui.Panel(root, "CoinBox", Ui.SurfaceRaised, true);
            coinBox.rectTransform.anchorMin = coinBox.rectTransform.anchorMax = new Vector2(1, 1); coinBox.rectTransform.pivot = new Vector2(1, 1); coinBox.rectTransform.anchoredPosition = new Vector2(-226, -16); coinBox.rectTransform.sizeDelta = new Vector2(280, 64);
            var cIcon = Ui.Panel(coinBox.transform, "Icon", Ui.Yellow, false); cIcon.sprite = Ui.Circle; cIcon.type = Image.Type.Simple;
            cIcon.rectTransform.anchorMin = cIcon.rectTransform.anchorMax = new Vector2(0, 0.5f); cIcon.rectTransform.pivot = new Vector2(0, 0.5f); cIcon.rectTransform.anchoredPosition = new Vector2(14, 0); cIcon.rectTransform.sizeDelta = new Vector2(34, 34);
            _coin = Ui.FitLabel(coinBox.transform, "", 30, Ui.TextLight, TextAnchor.MiddleRight, FontStyle.Bold, "Coin"); Ui.Stretch(_coin.rectTransform, 56, 4, 16, 4);

            var tokBox = Ui.Panel(root, "TokenBox", Ui.SurfaceRaised, true);
            tokBox.rectTransform.anchorMin = tokBox.rectTransform.anchorMax = new Vector2(1, 1); tokBox.rectTransform.pivot = new Vector2(1, 1); tokBox.rectTransform.anchoredPosition = new Vector2(-526, -16); tokBox.rectTransform.sizeDelta = new Vector2(220, 64);
            var tl = Ui.Label(tokBox.transform, "JETON", 18, Ui.Muted, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.Stretch(tl.rectTransform, 16, 0, 90, 0);
            _token = Ui.FitLabel(tokBox.transform, "", 30, Ui.Yellow, TextAnchor.MiddleRight, FontStyle.Bold, "Token"); Ui.Stretch(_token.rectTransform, 90, 4, 16, 4);
        }

        public void Refresh()
        {
            var p = _app.Profile; if (p == null) return;
            _name.text = p.DisplayName;
            _level.text = "SEV " + Fenerbahce.Core.Economy.Progression.Level(p.Xp);
            var fill = Fenerbahce.Core.Economy.Progression.Progress(p.Xp);
            _xp.rectTransform.anchorMax = new Vector2(Mathf.Clamp01(fill), 1);
            _coin.text = p.Wallet.Get(Fenerbahce.Core.Economy.Currency.Coin).ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("tr-TR"));
            _token.text = p.Wallet.Get(Fenerbahce.Core.Economy.Currency.Token).ToString();
            _back.gameObject.SetActive(_app.Nav != null && _app.Nav.Depth > 1);
        }
    }

    /// <summary>Alt gezinti + gerçek duruma bağlı rozetler (T012).</summary>
    public class BottomNav
    {
        readonly GameApp _app;
        readonly Dictionary<string, Image> _tabs = new Dictionary<string, Image>();
        readonly Dictionary<string, GameObject> _badges = new Dictionary<string, GameObject>();

        static readonly string[][] Tabs =
        {
            new[] { ScreenIds.Home, "ANA MERKEZ" }, new[] { ScreenIds.Club, "KULÜP" }, new[] { ScreenIds.Play, "OYNA" },
            new[] { ScreenIds.Events, "ETKİNLİK" }, new[] { ScreenIds.Store, "MAĞAZA" },
        };

        public BottomNav(GameApp app, RectTransform root)
        {
            _app = app;
            var bg = Ui.Panel(root, "Bg", Ui.Surface, false); Ui.Stretch(bg.rectTransform);
            var row = Ui.HRow(root, "Row", 12, TextAnchor.MiddleCenter, true);
            Ui.Stretch((RectTransform)row.transform, 24, 10, 24, 10);
            foreach (var t in Tabs)
            {
                string id = t[0];
                var b = Ui.MakeButton(row.transform, t[1], Ui.SurfaceRaised, Ui.TextLight, () => _app.Nav.GoRoot(id), "Tab_" + id, 28);
                _tabs[id] = b.GetComponent<Image>();
                var badge = Ui.Panel(b.transform, "Badge", Ui.Danger, false); badge.sprite = Ui.Circle; badge.type = Image.Type.Simple;
                badge.rectTransform.anchorMin = badge.rectTransform.anchorMax = new Vector2(1, 1); badge.rectTransform.pivot = new Vector2(1, 1);
                badge.rectTransform.anchoredPosition = new Vector2(-6, -6); badge.rectTransform.sizeDelta = new Vector2(30, 30);
                var bt = Ui.Label(badge.transform, "!", 22, Color.white, TextAnchor.MiddleCenter, FontStyle.Bold); Ui.Stretch(bt.rectTransform);
                badge.gameObject.SetActive(false); _badges[id] = badge.gameObject;
            }
        }

        public void Refresh()
        {
            string cur = _app.Nav == null ? null : _app.Nav.CurrentId;
            foreach (var kv in _tabs)
            {
                bool on = kv.Key == cur;
                kv.Value.color = on ? Ui.Yellow : Ui.SurfaceRaised;
                var txt = kv.Value.GetComponentInChildren<Text>();
                if (txt != null) txt.color = on ? Ui.Navy : Ui.TextLight;
            }
            // Rozet yalnızca gerçek durumdan: kadroda doğrulama hatası varsa Kulüp'te.
            if (_app.Profile != null) _badges[ScreenIds.Club].SetActive(_app.SquadErrorCount() > 0);
        }
    }
}
