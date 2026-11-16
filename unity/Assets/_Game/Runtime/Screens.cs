using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Squad;

namespace Fenerbahce.Runtime
{
    /// <summary>Her kare çağrılan basit sürücü (kampanya döngüsü vb.).</summary>
    public class UiTicker : MonoBehaviour
    {
        public Action Tick;
        void Update() { if (Tick != null) Tick(); }
    }

    // =====================================================================================
    public class HomeScreen : GameScreen
    {
        int _index; float _timer;
        RectTransform _bannerHost, _dots, _featured;
        Text _summary;
        const float AutoSeconds = 5f;

        public HomeScreen() { Id = ScreenIds.Home; }

        protected override void Build()
        {
            _bannerHost = Ui.NewRect("BannerHost", Root);
            Ui.PlaceTopLeft(_bannerHost, 32, 24, 1140, 520);
            _dots = Ui.NewRect("Dots", Root); Ui.PlaceTopLeft(_dots, 32, 556, 1140, 30);

            var play = Ui.PrimaryButton(Root, "OYNA", () => App.Nav.GoRoot(ScreenIds.Play), 54);
            Ui.PlaceTopLeft((RectTransform)play.transform, 32, 610, 560, 150);
            var club = Ui.SecondaryButton(Root, "KULÜP", () => App.Nav.GoRoot(ScreenIds.Club), 54);
            Ui.PlaceTopLeft((RectTransform)club.transform, 612, 610, 560, 150);

            _featured = Ui.NewRect("Featured", Root); Ui.PlaceTopLeft(_featured, 1230, 24, 620, 560);
            var box = Ui.Panel(Root, "SummaryBox", Ui.Surface, true); Ui.PlaceTopLeft(box.rectTransform, 1230, 610, 620, 150);
            _summary = Ui.Label(box.transform, "", 28, Ui.TextLight, TextAnchor.MiddleLeft); Ui.Stretch(_summary.rectTransform, 24, 8, 24, 8);

            var tk = Root.gameObject.AddComponent<UiTicker>();
            tk.Tick = () =>
            {
                if (!Root.gameObject.activeInHierarchy || App.Campaigns == null || App.Campaigns.Count < 2) return;
                _timer += Time.unscaledDeltaTime;
                if (_timer > AutoSeconds) { _timer = 0; _index = (_index + 1) % App.Campaigns.Count; RenderBanner(); }
            };
        }

        public override void OnShow() { _timer = 0; RenderBanner(); RenderFeatured(); }

        void RenderBanner()
        {
            Ui.Clear(_bannerHost); Ui.Clear(_dots);
            var list = App.Campaigns; if (list == null || list.Count == 0) return;
            var c = list[_index % list.Count];
            var accent = Ui.C(c.AccentHex);
            var bg = Ui.Panel(_bannerHost, "Banner", Ui.Surface, true, true); Ui.Stretch(bg.rectTransform);
            var strip = Ui.Panel(bg.transform, "Accent", accent, true); strip.rectTransform.anchorMin = Vector2.zero; strip.rectTransform.anchorMax = new Vector2(0, 1); strip.rectTransform.offsetMin = Vector2.zero; strip.rectTransform.offsetMax = new Vector2(26, 0);
            var title = Ui.FitLabel(bg.transform, c.Title, DesignTokens.FontDisplay, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold, "Title");
            title.rectTransform.anchorMin = new Vector2(0, 1); title.rectTransform.anchorMax = new Vector2(1, 1); title.rectTransform.pivot = new Vector2(0.5f, 1); title.rectTransform.offsetMin = new Vector2(70, -190); title.rectTransform.offsetMax = new Vector2(-40, -60);
            var sub = Ui.Label(bg.transform, c.Subtitle, DesignTokens.FontBody + 4, Ui.Muted, TextAnchor.UpperLeft, FontStyle.Normal, "Sub");
            sub.rectTransform.anchorMin = Vector2.zero; sub.rectTransform.anchorMax = Vector2.one; sub.rectTransform.offsetMin = new Vector2(70, 150); sub.rectTransform.offsetMax = new Vector2(-40, -210);
            if (!c.Implemented)
            {
                var tag = Ui.Panel(bg.transform, "Soon", Ui.C(DesignTokens.Locked), true);
                tag.rectTransform.anchorMin = tag.rectTransform.anchorMax = new Vector2(1, 1); tag.rectTransform.pivot = new Vector2(1, 1); tag.rectTransform.anchoredPosition = new Vector2(-24, -24); tag.rectTransform.sizeDelta = new Vector2(200, 52);
                var tl = Ui.FitLabel(tag.transform, "YAKINDA", 26, Ui.TextLight); Ui.Stretch(tl.rectTransform);
            }
            string target = c.TargetScreen;
            var go = Ui.PrimaryButton(bg.transform, c.Implemented ? "GİT" : "AYRINTI", () => App.Nav.GoRoot(target), 34);
            var gr = (RectTransform)go.transform; gr.anchorMin = gr.anchorMax = new Vector2(0, 0); gr.pivot = new Vector2(0, 0); gr.anchoredPosition = new Vector2(70, 40); gr.sizeDelta = new Vector2(280, 90);
            var tid = Ui.Label(bg.transform, "Görevler: " + c.TaskIds, 20, Ui.Muted, TextAnchor.MiddleRight);
            tid.rectTransform.anchorMin = tid.rectTransform.anchorMax = new Vector2(1, 0); tid.rectTransform.pivot = new Vector2(1, 0); tid.rectTransform.anchoredPosition = new Vector2(-30, 50); tid.rectTransform.sizeDelta = new Vector2(500, 36);

            var row = Ui.HRow(_dots, "DotRow", 12, TextAnchor.MiddleLeft); Ui.Stretch((RectTransform)row.transform);
            for (int i = 0; i < list.Count; i++)
            {
                int idx = i;
                var d = Ui.MakeButton(row.transform, "", i == _index ? Ui.Yellow : Ui.SurfaceRaised, Ui.Navy, () => { _index = idx; _timer = 0; RenderBanner(); }, "Dot" + i, 10);
                Ui.Size(d.gameObject, i == _index ? 60 : 28, 24);
            }
        }

        void RenderFeatured()
        {
            Ui.Clear(_featured);
            var p = App.Profile; var sq = p.ActiveSquad;
            string best = null; int bestOvr = -1;
            if (sq != null)
                foreach (var id in sq.Starters)
                {
                    var ci = p.Inventory.Get(id); if (ci == null) continue;
                    var d = App.Catalog.GetCard(ci.CardDefinitionId);
                    if (d != null && d.Overall > bestOvr) { bestOvr = d.Overall; best = id; }
                }
            if (best != null)
            {
                var ci = p.Inventory.Get(best); var d = App.Catalog.GetCard(ci.CardDefinitionId); var pl = App.Catalog.GetPlayer(d.PlayerId);
                var rt = CardView.Create(_featured, pl, d, 400, 540, new CardView.Options { Instance = ci });
                rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 0.5f); rt.pivot = new Vector2(0.5f, 0.5f); rt.anchoredPosition = Vector2.zero;
                var le = rt.GetComponent<LayoutElement>(); if (le != null) UnityEngine.Object.Destroy(le);
            }
            if (sq != null)
            {
                var s = SquadService.Summarize(sq, p.Inventory, App.Catalog);
                _summary.text = "TAKIM GEN  " + s.Overall + "\nDeğer  " + s.Value.ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("tr-TR")) + "   |   " + sq.FormationId + "\n" + (App.SquadErrorCount() > 0 ? "Kadroda sorun var: Kulüp'ü kontrol et" : "Kadro maça hazır");
            }
        }
    }

    // =====================================================================================
    public class PlayScreen : GameScreen
    {
        int _difficulty = 1;           // 0 kolay, 1 orta, 2 zor
        bool _defender = true;
        int _playerIndex;
        RectTransform _right;
        Button[] _diffBtns;
        Button _defBtn;
        List<string> _candidates = new List<string>();

        public PlayScreen() { Id = ScreenIds.Play; }

        static readonly string[][] Modes =
        {
            new[] { "YAPAY ZEKÂYA KARŞI TAM MAÇ", "T041–T048" },
            new[] { "ÇEVRİMİÇİ TEKE TEK", "T083–T086" },
            new[] { "ARKADAŞA KARŞI", "T081–T082" },
            new[] { "KARŞI ATAK", "T087" },
            new[] { "TEKNİK DİREKTÖR", "T088" },
            new[] { "KUPA / SEZON / LİDERLİK", "T089" },
        };

        protected override void Build()
        {
            var title = Ui.Label(Root, "OYNA", DesignTokens.FontTitle, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(title.rectTransform, 32, 10, 600, 60);
            var left = Ui.VCol(Root, "Modes", 14); Ui.PlaceTopLeft((RectTransform)left.transform, 32, 84, 760, 760);
            var first = Ui.MakeButton(left.transform, "KONTROL SAHASI  —  OYNANABİLİR", Ui.Yellow, Ui.Navy, null, "Mode_Control", 32); Ui.Size(first.gameObject, -1, 100);
            foreach (var m in Modes)
            {
                var row = Ui.Panel(left.transform, "Mode_" + m[0], Ui.Surface, true, true); Ui.Size(row.gameObject, -1, 90);
                var l = Ui.FitLabel(row.transform, m[0], 28, Ui.Muted, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.Stretch(l.rectTransform, 24, 6, 250, 6);
                var tag = Ui.Panel(row.transform, "Tag", Ui.C(DesignTokens.Locked), true);
                tag.rectTransform.anchorMin = tag.rectTransform.anchorMax = new Vector2(1, 0.5f); tag.rectTransform.pivot = new Vector2(1, 0.5f); tag.rectTransform.anchoredPosition = new Vector2(-16, 0); tag.rectTransform.sizeDelta = new Vector2(220, 56);
                var tt = Ui.FitLabel(tag.transform, "YAKINDA " + m[1], 20, Ui.TextLight); Ui.Stretch(tt.rectTransform, 6, 2, 6, 2);
            }

            _right = Ui.NewRect("Right", Root); Ui.PlaceTopLeft(_right, 830, 24, 1030, 760);
        }

        public override void OnShow()
        {
            var p = App.Profile; var sq = p.ActiveSquad;
            _candidates.Clear();
            if (sq != null)
            {
                var f = Formations.Get(sq.FormationId);
                for (int i = 0; i < 11; i++)
                {
                    if (sq.Starters[i] == null || f.Slots[i].Position == Position.GK) continue;
                    _candidates.Add(sq.Starters[i]);
                }
                // en yüksek GEN'li hücum öncelikli sıralama
                _candidates = _candidates.OrderByDescending(id =>
                {
                    var ci = p.Inventory.Get(id); var d = App.Catalog.GetCard(ci.CardDefinitionId); var pl = App.Catalog.GetPlayer(d.PlayerId);
                    return (pl.PositionGroup == PositionGroup.ATT ? 1000 : pl.PositionGroup == PositionGroup.MID ? 500 : 0) + d.Overall;
                }).ToList();
            }
            _playerIndex = Mathf.Clamp(_playerIndex, 0, Math.Max(0, _candidates.Count - 1));
            Render();
        }

        void Render()
        {
            Ui.Clear(_right);
            var box = Ui.Panel(_right, "Box", Ui.Surface, true); Ui.Stretch(box.rectTransform);
            var h = Ui.Label(box.transform, "KONTROL SAHASI", DesignTokens.FontTitle, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(h.rectTransform, 32, 20, 700, 60);
            var info = Ui.Label(box.transform, "Tek futbolcu, top, kaleci ve rakip savunmacı. 2 dakikalık oturum; gol, hedefli pas ve kayma sayılır. Bu tam maç DEĞİLDİR (11v11: T041–T048).", 24, Ui.Muted, TextAnchor.UpperLeft);
            Ui.PlaceTopLeft(info.rectTransform, 32, 86, 960, 100);

            // Futbolcu seçimi
            var pl = Ui.Label(box.transform, "FUTBOLCU", 22, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(pl.rectTransform, 32, 200, 300, 34);
            if (_candidates.Count > 0)
            {
                var ci = App.Profile.Inventory.Get(_candidates[_playerIndex]); var d = App.Catalog.GetCard(ci.CardDefinitionId); var player = App.Catalog.GetPlayer(d.PlayerId);
                var rt = CardView.Create(box.transform, player, d, 210, 285, new CardView.Options { Instance = ci });
                rt.anchorMin = rt.anchorMax = new Vector2(0, 1); rt.pivot = new Vector2(0, 1); rt.anchoredPosition = new Vector2(32, -240);
                var le = rt.GetComponent<LayoutElement>(); if (le != null) UnityEngine.Object.Destroy(le);
                var st = Ui.Label(box.transform, "Hız " + player.Attributes.Pace + "   Şut " + player.Attributes.Shooting + "   Pas " + player.Attributes.Passing + "\nDribling " + player.Attributes.Dribbling + "   Defans " + player.Attributes.Defending + "   Fizik " + player.Attributes.Physical + "\nBeceri yıldızı " + player.SkillStars + "   Dayanıklılık " + player.Stamina, 24, Ui.TextLight, TextAnchor.UpperLeft);
                Ui.PlaceTopLeft(st.rectTransform, 270, 250, 720, 130);
                var sw = Ui.SecondaryButton(box.transform, "FUTBOLCU DEĞİŞTİR", () => { _playerIndex = (_playerIndex + 1) % _candidates.Count; Render(); }, 28);
                Ui.PlaceTopLeft((RectTransform)sw.transform, 270, 400, 420, 84);
            }
            else
            {
                var e = Ui.Label(box.transform, "Kadroda saha oyuncusu yok. Önce Kulüp'ten kadro kur.", 26, Ui.Danger, TextAnchor.MiddleLeft); Ui.PlaceTopLeft(e.rectTransform, 32, 260, 900, 80);
            }

            // Zorluk
            var dl = Ui.Label(box.transform, "ZORLUK (kaleci + savunmacı)", 22, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(dl.rectTransform, 32, 550, 600, 34);
            _diffBtns = new Button[3]; string[] names = { "KOLAY", "ORTA", "ZOR" };
            for (int i = 0; i < 3; i++)
            {
                int idx = i;
                _diffBtns[i] = Ui.MakeButton(box.transform, names[i], i == _difficulty ? Ui.Yellow : Ui.SurfaceRaised, i == _difficulty ? Ui.Navy : Ui.TextLight, () => { _difficulty = idx; Render(); }, "Diff" + i, 28);
                Ui.PlaceTopLeft((RectTransform)_diffBtns[i].transform, 32 + i * 190, 590, 176, 76);
            }
            _defBtn = Ui.MakeButton(box.transform, _defender ? "SAVUNMACI: AÇIK" : "SAVUNMACI: KAPALI", _defender ? Ui.SurfaceRaised : Ui.C(DesignTokens.Locked), Ui.TextLight, () => { _defender = !_defender; Render(); }, "DefToggle", 26);
            Ui.PlaceTopLeft((RectTransform)_defBtn.transform, 620, 590, 370, 76);

            var go = Ui.PrimaryButton(box.transform, "BAŞLA", Begin, 46);
            Ui.PlaceTopLeft((RectTransform)go.transform, 32, 680, 960, 66);
            go.interactable = _candidates.Count > 0;
        }

        void Begin()
        {
            if (_candidates.Count == 0) return;
            var ci = App.Profile.Inventory.Get(_candidates[_playerIndex]);
            var d = App.Catalog.GetCard(ci.CardDefinitionId); var pl = App.Catalog.GetPlayer(d.PlayerId);
            float[] gk = { 52f, 72f, 90f }, defLvl = { 0.62f, 0.78f, 0.92f };
            var opts = new FieldController.Options
            {
                Attacker = Fenerbahce.Core.Sim.SimStats.From(pl, d.Overall),
                AttackerPlayerId = pl.PlayerId,
                KeeperSkill = gk[_difficulty], DefenderLevel = defLvl[_difficulty], DefenderEnabled = _defender,
                Settings = App.Profile.Settings,
                SessionId = Guid.NewGuid().ToString("N"),
                Seed = Environment.TickCount,
            };
            App.StartField(opts);
        }
    }

    // =====================================================================================
    /// <summary>Henüz uygulanmamış modüller için dürüst boş durum: ne olduğunu ve hangi görevlerde olduğunu gösterir.</summary>
    public class ComingSoonScreen : GameScreen
    {
        readonly string _title, _desc; readonly string[] _tasks;
        public ComingSoonScreen(string id, string title, string desc, string[] tasks) { Id = id; _title = title; _desc = desc; _tasks = tasks; }

        protected override void Build()
        {
            var box = Ui.Panel(Root, "Box", Ui.Surface, true); Ui.Stretch(box.rectTransform, 160, 40, 160, 40);
            var t = Ui.FitLabel(box.transform, _title, DesignTokens.FontTitle + 6, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(t.rectTransform, 48, 36, 1300, 70);
            var tag = Ui.Panel(box.transform, "Tag", Ui.C(DesignTokens.Locked), true); Ui.PlaceTopLeft(tag.rectTransform, 48, 120, 260, 54);
            var tl = Ui.FitLabel(tag.transform, "YAKINDA", 28, Ui.TextLight); Ui.Stretch(tl.rectTransform);
            var d = Ui.Label(box.transform, _desc, DesignTokens.FontBody, Ui.TextLight, TextAnchor.UpperLeft); Ui.PlaceTopLeft(d.rectTransform, 48, 196, 1300, 110);
            var hl = Ui.Label(box.transform, "PLANLANAN GÖREVLER", 24, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(hl.rectTransform, 48, 320, 600, 36);
            var list = Ui.Label(box.transform, string.Join("\n", _tasks.Select(x => "•  " + x).ToArray()), 26, Ui.Muted, TextAnchor.UpperLeft); Ui.PlaceTopLeft(list.rectTransform, 48, 366, 1300, 300);
            var b = Ui.PrimaryButton(box.transform, "ANA MERKEZE DÖN", () => App.Nav.GoRoot(ScreenIds.Home), 32);
            var br = (RectTransform)b.transform; br.anchorMin = br.anchorMax = new Vector2(0, 0); br.pivot = new Vector2(0, 0); br.anchoredPosition = new Vector2(48, 36); br.sizeDelta = new Vector2(420, 90);
        }
    }

    // =====================================================================================
    public class SettingsScreen : GameScreen
    {
        RectTransform _col;
        public SettingsScreen() { Id = ScreenIds.Settings; }
        public override bool IsTab { get { return false; } }

        protected override void Build()
        {
            var title = Ui.Label(Root, "AYARLAR", DesignTokens.FontTitle, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(title.rectTransform, 32, 10, 600, 60);
            _col = Ui.NewRect("Col", Root); Ui.PlaceTopLeft(_col, 32, 84, 1500, 800);
        }

        public override void OnShow() { Render(); }

        void Row(Transform parent, ref float y, string label, string value, Action minus, Action plus)
        {
            var r = Ui.Panel(parent, "Row_" + label, Ui.Surface, true); Ui.PlaceTopLeft(r.rectTransform, 0, y, 1500, 84);
            var l = Ui.Label(r.transform, label, 28, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(l.rectTransform, 24, 0, 700, 84);
            if (minus != null) { var m = Ui.SecondaryButton(r.transform, "−", minus, 40); Ui.PlaceTopLeft((RectTransform)m.transform, 960, 8, 90, 68); }
            var v = Ui.FitLabel(r.transform, value, 30, Ui.Yellow, TextAnchor.MiddleCenter); Ui.PlaceTopLeft(v.rectTransform, 1060, 8, 300, 68);
            if (plus != null) { var p = Ui.SecondaryButton(r.transform, "+", plus, 40); Ui.PlaceTopLeft((RectTransform)p.transform, 1370, 8, 110, 68); }
            y += 96;
        }

        void Change(Action a) { a(); App.ApplySettings(); App.Save(); Render(); }

        void Render()
        {
            Ui.Clear(_col);
            var s = App.Profile.Settings; float y = 0;
            Row(_col, ref y, "Joystick hassasiyeti", s.JoystickSensitivity.ToString("0.0"), () => Change(() => s.JoystickSensitivity = Mathf.Max(0.6f, (float)Math.Round(s.JoystickSensitivity - 0.1f, 1))), () => Change(() => s.JoystickSensitivity = Mathf.Min(1.6f, (float)Math.Round(s.JoystickSensitivity + 0.1f, 1))));
            Row(_col, ref y, "Joystick ölü bölge", s.JoystickDeadZone.ToString("0.00"), () => Change(() => s.JoystickDeadZone = Mathf.Max(0.05f, (float)Math.Round(s.JoystickDeadZone - 0.05f, 2))), () => Change(() => s.JoystickDeadZone = Mathf.Min(0.30f, (float)Math.Round(s.JoystickDeadZone + 0.05f, 2))));
            Row(_col, ref y, "Düğme boyutu", s.ButtonScale.ToString("0.0") + "x", () => Change(() => s.ButtonScale = Mathf.Max(0.8f, (float)Math.Round(s.ButtonScale - 0.1f, 1))), () => Change(() => s.ButtonScale = Mathf.Min(1.4f, (float)Math.Round(s.ButtonScale + 0.1f, 1))));
            Row(_col, ref y, "Titreşim (gol/çelme)", s.Vibration ? "AÇIK" : "KAPALI", () => Change(() => s.Vibration = !s.Vibration), () => Change(() => s.Vibration = !s.Vibration));
            string[] q = { "OTOMATİK (60)", "30 FPS", "60 FPS" };
            Row(_col, ref y, "Kare hızı sınırı", q[Mathf.Clamp(s.GraphicsQuality, 0, 2)], () => Change(() => s.GraphicsQuality = (s.GraphicsQuality + 2) % 3), () => Change(() => s.GraphicsQuality = (s.GraphicsQuality + 1) % 3));

            var note = Ui.Label(_col, "Ses ayarları ses sistemi (T093) gelince eklenecek. Dil: Türkçe.", 22, Ui.Muted, TextAnchor.MiddleLeft); Ui.PlaceTopLeft(note.rectTransform, 0, y + 6, 1500, 40);
            y += 60;
            var reset = Ui.MakeButton(_col, "KAYDI SIFIRLA (test için)", Ui.Danger, Ui.TextLight, () =>
                App.Modal.Confirm("Kayıt sıfırlansın mı?", "Kadro, envanter ve cüzdan silinir; başlangıç paketi yeniden verilir. Bu işlem geri alınamaz (dosya .bak olarak yedeklenir).", "SIFIRLA", () => { App.BackupAndResetSave(); App.Boot(); }), "Reset", 30);
            Ui.PlaceTopLeft((RectTransform)reset.transform, 0, y + 20, 520, 84);
            var ver = Ui.Label(_col, "Sürüm " + Application.version + "  |  Kayıt sürümü " + ProfileState.CurrentSchemaVersion + "  |  İçerik " + App.Catalog.PlayersVersion + " (" + App.Catalog.UniquePlayerCount + " futbolcu, " + App.Catalog.Cards.Count + " kart)", 20, Ui.Muted, TextAnchor.MiddleLeft);
            Ui.PlaceTopLeft(ver.rectTransform, 0, y + 120, 1500, 36);
        }
    }

    // =====================================================================================
    public class ResultScreen : GameScreen
    {
        public static FieldController.Summary Pending;
        public ResultScreen() { Id = "result"; }
        public override bool IsTab { get { return false; } }
        RectTransform _box;

        protected override void Build() { _box = Ui.NewRect("Box", Root); Ui.Stretch(_box, 120, 20, 120, 20); }

        public override void OnShow()
        {
            Ui.Clear(_box);
            var s = Pending; if (s == null) { App.Nav.GoRoot(ScreenIds.Home); return; }
            // Ödül sunucu/servis işlemidir: oturum kimliğiyle idempotent; ekrana tekrar girmek yeniden vermez.
            long before = App.Profile.Wallet.Get(Currency.Coin);
            var r = App.Economy.ClaimControlSessionReward(s.SessionId, s.Stats.Goals, s.Stats.TargetPasses, s.Stats.Saves);
            long gained = App.Profile.Wallet.Get(Currency.Coin) - before;
            if (r.Ok && !r.Replayed) App.Save();
            App.RefreshChrome();

            var bg = Ui.Panel(_box, "Bg", Ui.Surface, true); Ui.Stretch(bg.rectTransform);
            var t = Ui.FitLabel(bg.transform, s.Completed ? "OTURUM BİTTİ" : "OTURUM YARIDA KESİLDİ", DesignTokens.FontTitle + 8, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(t.rectTransform, 48, 28, 1300, 70);
            var sc = Ui.Label(bg.transform, s.Stats.Goals + "  GOL", 110, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(sc.rectTransform, 48, 110, 700, 140);
            string stats = "Şut: " + s.Stats.Shots + "   İsabetli: " + s.Stats.ShotsOnTarget + "   Kaleci kurtarışı: " + s.Stats.Saves +
                "\nPas: " + s.Stats.Passes + "   Hedefli pas: " + s.Stats.TargetPasses +
                "\nKazanılan top (kayma): " + s.Stats.TacklesWon + "   Kaybedilen top: " + s.Stats.BallLosses + "   Çalım: " + s.Stats.Skills +
                "\nOynanan süre: " + Mathf.RoundToInt(s.PlayedSeconds) + " sn";
            var st = Ui.Label(bg.transform, stats, 30, Ui.TextLight, TextAnchor.UpperLeft); Ui.PlaceTopLeft(st.rectTransform, 48, 270, 1300, 220);
            var rw = Ui.Panel(bg.transform, "Reward", Ui.SurfaceRaised, true); Ui.PlaceTopLeft(rw.rectTransform, 48, 510, 1000, 120);
            string rtxt = r.Ok ? (gained > 0 ? "KAZANILAN COIN:  +" + gained : "Bu oturumda coin kazanılmadı (gol/hedefli pas yok).") : ("Ödül işlenemedi: " + r.Message);
            if (r.Ok && r.Replayed) rtxt = "Bu oturumun ödülü zaten işlendi.";
            var rl = Ui.FitLabel(rw.transform, rtxt, 36, gained > 0 ? Ui.Yellow : Ui.Muted, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.Stretch(rl.rectTransform, 28, 8, 28, 8);
            var note = Ui.Label(bg.transform, "Not: Bu bir kontrol sahası ödülüdür (prototip, istemci kaynaklı). Gerçek maç/ekonomi ödülü sunucuda doğrulanır (T048–T050).", 20, Ui.Muted, TextAnchor.UpperLeft); Ui.PlaceTopLeft(note.rectTransform, 48, 650, 1300, 60);

            var again = Ui.PrimaryButton(bg.transform, "TEKRAR OYNA", () => { Pending = null; App.Nav.Back(); }, 36);
            var ar = (RectTransform)again.transform; ar.anchorMin = ar.anchorMax = new Vector2(0, 0); ar.pivot = new Vector2(0, 0); ar.anchoredPosition = new Vector2(48, 32); ar.sizeDelta = new Vector2(480, 96);
            var home = Ui.SecondaryButton(bg.transform, "ANA MERKEZ", () => { Pending = null; App.Nav.GoRoot(ScreenIds.Home); }, 36);
            var hr = (RectTransform)home.transform; hr.anchorMin = hr.anchorMax = new Vector2(0, 0); hr.pivot = new Vector2(0, 0); hr.anchoredPosition = new Vector2(560, 32); hr.sizeDelta = new Vector2(420, 96);
        }
    }
}
