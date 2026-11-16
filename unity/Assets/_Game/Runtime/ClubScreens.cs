using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Squad;

namespace Fenerbahce.Runtime
{
    /// <summary>Kulüp merkezi + kadro (T013, T034–T037): 11 slot, yedekler, diziliş, otomatik kur, mevki uygunluğu, kayıt.</summary>
    public class ClubScreen : GameScreen
    {
        int _selectedSlot = -1;
        RectTransform _pitch, _bench, _right, _list;
        Text _summary, _issues;
        string _message = "";

        public ClubScreen() { Id = ScreenIds.Club; }

        protected override void Build()
        {
            var title = Ui.Label(Root, "KULÜP — KADRO", DesignTokens.FontTitle, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(title.rectTransform, 24, 4, 700, 56);
            _pitch = Ui.NewRect("Pitch", Root); Ui.PlaceTopLeft(_pitch, 24, 62, 1180, 620);
            _bench = Ui.NewRect("Bench", Root); Ui.PlaceTopLeft(_bench, 24, 692, 1180, 150);
            _right = Ui.NewRect("Right", Root); Ui.PlaceTopLeft(_right, 1224, 4, 650, 840);
        }

        public override void OnShow() { Render(); }

        SquadPlan Plan { get { return App.Profile.ActiveSquad; } }

        void Commit(string msg = "")
        {
            _message = msg; App.Save(); App.RefreshChrome(); Render();
        }

        void Render()
        {
            var plan = Plan; var inv = App.Profile.Inventory; var cat = App.Catalog;
            Ui.Clear(_pitch); Ui.Clear(_bench); Ui.Clear(_right);
            if (plan == null) { var e = Ui.Label(_pitch, "Aktif kadro yok.", 30, Ui.Danger); Ui.Stretch(e.rectTransform); return; }
            var f = Formations.Get(plan.FormationId);

            // ----- saha -----
            var grass = Ui.Panel(_pitch, "Grass", Ui.C(DesignTokens.Pitch), true); Ui.Stretch(grass.rectTransform);
            var mid = Ui.Panel(grass.transform, "Mid", new Color(1, 1, 1, 0.25f), false); mid.rectTransform.anchorMin = new Vector2(0.5f, 0); mid.rectTransform.anchorMax = new Vector2(0.5f, 1); mid.rectTransform.offsetMin = new Vector2(-2, 0); mid.rectTransform.offsetMax = new Vector2(2, 0);
            var circle = Ui.Panel(grass.transform, "Circle", new Color(1, 1, 1, 0.12f), false); circle.sprite = Ui.Circle; circle.type = Image.Type.Simple; Ui.Anchor(circle.rectTransform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(170, 170)); circle.rectTransform.pivot = new Vector2(0.5f, 0.5f);
            float cw = 112, ch = 150;
            for (int i = 0; i < 11; i++)
            {
                int slot = i; var sd = f.Slots[i];
                var id = plan.Starters[i];
                RectTransform rt;
                if (id != null)
                {
                    var ci = inv.Get(id); var d = cat.GetCard(ci.CardDefinitionId); var pl = cat.GetPlayer(d.PlayerId);
                    var fit = PositionFit.Evaluate(sd.Position, pl);
                    rt = CardView.Create(_pitch, pl, d, cw, ch, new CardView.Options { Instance = ci, Fit = fit == Fit.Exact || fit == Fit.Alternate ? (Fit?)null : fit, Selected = _selectedSlot == i, ShowCountry = false });
                }
                else
                {
                    var empty = Ui.Panel(_pitch, "Empty" + i, new Color(1, 1, 1, _selectedSlot == i ? 0.35f : 0.16f), true, true);
                    rt = empty.rectTransform; rt.sizeDelta = new Vector2(cw, ch);
                    var l = Ui.FitLabel(empty.transform, sd.Position.ToString() + "\nBOŞ", 26, Ui.TextLight); Ui.Stretch(l.rectTransform);
                }
                rt.anchorMin = rt.anchorMax = new Vector2(0, 1); rt.pivot = new Vector2(0, 1);
                float px = sd.X * (1180 - cw - 16) + 8, py = sd.Y * (620 - ch - 16) + 8;
                rt.anchoredPosition = new Vector2(px, -py);
                var le = rt.GetComponent<LayoutElement>(); if (le != null) UnityEngine.Object.Destroy(le);
                var btn = rt.gameObject.GetComponent<Button>() ?? rt.gameObject.AddComponent<Button>();
                btn.targetGraphic = rt.GetComponent<Image>();
                btn.onClick.AddListener(() => { _selectedSlot = _selectedSlot == slot ? -1 : slot; _message = ""; Render(); });
                // slot mevki etiketi (kartın altına)
                var tag = Ui.Panel(_pitch, "SlotTag" + i, new Color(0, 0, 0, 0.55f), true);
                tag.rectTransform.anchorMin = tag.rectTransform.anchorMax = new Vector2(0, 1); tag.rectTransform.pivot = new Vector2(0, 1);
                tag.rectTransform.anchoredPosition = new Vector2(px, -(py + ch + 2)); tag.rectTransform.sizeDelta = new Vector2(cw, 22);
                var tl = Ui.FitLabel(tag.transform, sd.Position.ToString(), 18, i == _selectedSlot ? Ui.Yellow : Ui.TextLight); Ui.Stretch(tl.rectTransform);
            }

            // ----- yedekler -----
            var bb = Ui.Panel(_bench, "BenchBg", Ui.Surface, true); Ui.Stretch(bb.rectTransform);
            var bl = Ui.Label(bb.transform, "YEDEKLER (" + plan.Bench.Count + "/" + SquadPlan.MaxBench + ")", 20, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(bl.rectTransform, 14, 4, 400, 28);
            for (int i = 0; i < plan.Bench.Count; i++)
            {
                var id = plan.Bench[i]; var ci = inv.Get(id); if (ci == null) continue;
                var d = cat.GetCard(ci.CardDefinitionId); var pl = cat.GetPlayer(d.PlayerId);
                var rt = CardView.Create(_bench, pl, d, 92, 118, new CardView.Options { Instance = ci, ShowCountry = false });
                rt.anchorMin = rt.anchorMax = new Vector2(0, 1); rt.pivot = new Vector2(0, 1); rt.anchoredPosition = new Vector2(14 + i * 100, -30);
                var le = rt.GetComponent<LayoutElement>(); if (le != null) UnityEngine.Object.Destroy(le);
                var btn = rt.gameObject.AddComponent<Button>(); btn.targetGraphic = rt.GetComponent<Image>();
                string bid = id;
                btn.onClick.AddListener(() => OnBenchTap(bid));
            }

            // ----- sağ panel -----
            var rb = Ui.Panel(_right, "RightBg", Ui.Surface, true); Ui.Stretch(rb.rectTransform);
            var fl = Ui.Label(rb.transform, "DİZİLİŞ", 20, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(fl.rectTransform, 20, 10, 200, 28);
            for (int i = 0; i < Formations.All.Count; i++)
            {
                var fd = Formations.All[i]; bool on = fd.FormationId == plan.FormationId;
                var b = Ui.MakeButton(rb.transform, fd.DisplayName, on ? Ui.Yellow : Ui.SurfaceRaised, on ? Ui.Navy : Ui.TextLight, () => ChangeFormation(fd.FormationId), "F" + fd.FormationId, 26);
                Ui.PlaceTopLeft((RectTransform)b.transform, 20 + i * 200, 42, 188, 66);
            }
            var auto = Ui.PrimaryButton(rb.transform, "OTOMATİK KUR", AutoBuild, 30); Ui.PlaceTopLeft((RectTransform)auto.transform, 20, 120, 300, 70);
            var coll = Ui.SecondaryButton(rb.transform, "KOLEKSİYON", () => App.Nav.Push(ScreenIds.Collection), 30); Ui.PlaceTopLeft((RectTransform)coll.transform, 330, 120, 300, 70);

            var sum = SquadService.Summarize(plan, inv, cat);
            _summary = Ui.Label(rb.transform, "", 26, Ui.TextLight, TextAnchor.UpperLeft); Ui.PlaceTopLeft(_summary.rectTransform, 20, 200, 610, 110);
            _summary.text = "TAKIM GEN  " + sum.Overall + "     Değer  " + sum.Value.ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("tr-TR")) +
                            "\nDolu slot " + sum.FilledSlots + "/11     Pozisyon dışı " + sum.OutOfPositionCount +
                            "\n" + RoleText(plan);

            var issues = SquadService.Validate(plan, inv, cat, true);
            int errs = issues.Count(x => x.IsError), warns = issues.Count - errs;
            _issues = Ui.Label(rb.transform, "", 22, errs > 0 ? Ui.Danger : (warns > 0 ? Ui.Yellow : Ui.Success), TextAnchor.UpperLeft); Ui.PlaceTopLeft(_issues.rectTransform, 20, 310, 610, 74);
            _issues.text = errs > 0 ? "Sorun: " + issues.First(x => x.IsError).Message + (errs > 1 ? " (+" + (errs - 1) + ")" : "")
                         : warns > 0 ? "Uyarı: " + issues.First().Message : "Kadro geçerli ve maça hazır.";
            if (!string.IsNullOrEmpty(_message)) _issues.text = _message + "\n" + _issues.text;

            // aday listesi
            var hl = Ui.Label(rb.transform, _selectedSlot < 0 ? "Bir slot seç → adaylar burada" : "SLOT " + f.Slots[_selectedSlot].Position + " İÇİN KARTLAR", 22, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(hl.rectTransform, 20, 390, 610, 30);
            var holder = Ui.NewRect("ListHolder", rb.transform); Ui.PlaceTopLeft(holder, 12, 424, 626, 404);
            var sr = Ui.Scroll(holder, "Scroll", true, out _list); Ui.Stretch((RectTransform)sr.transform);
            var vl = _list.gameObject.AddComponent<VerticalLayoutGroup>(); vl.spacing = 8; vl.childControlWidth = true; vl.childControlHeight = true; vl.childForceExpandHeight = false; vl.padding = new RectOffset(8, 8, 4, 4);
            Ui.FitContent(_list);
            if (_selectedSlot >= 0) BuildCandidates(f.Slots[_selectedSlot], plan);
        }

        string RoleText(SquadPlan plan)
        {
            Func<int, string> nm = s =>
            {
                if (s < 0 || plan.Starters[s] == null) return "—";
                var ci = App.Profile.Inventory.Get(plan.Starters[s]); if (ci == null) return "—";
                return App.Catalog.GetPlayer(App.Catalog.GetCard(ci.CardDefinitionId).PlayerId).DisplayName;
            };
            return "Kaptan: " + nm(plan.CaptainSlot) + "   Penaltı: " + nm(plan.PenaltyTakerSlot);
        }

        void BuildCandidates(SlotDefinition slot, SquadPlan plan)
        {
            var inv = App.Profile.Inventory; var cat = App.Catalog;
            var rows = new List<KeyValuePair<CardInstance, int>>();
            foreach (var ci in inv.Cards)
            {
                if (ci.ListedOnMarket) continue;
                var d = cat.GetCard(ci.CardDefinitionId); var pl = cat.GetPlayer(d.PlayerId);
                var fit = PositionFit.Evaluate(slot.Position, pl);
                int rank = fit == Fit.Exact ? 3 : fit == Fit.Alternate ? 2 : fit == Fit.OutOfPosition ? 1 : 0;
                rows.Add(new KeyValuePair<CardInstance, int>(ci, rank * 1000 + d.Overall));
            }
            foreach (var kv in rows.OrderByDescending(r => r.Value).Take(40))
            {
                var ci = kv.Key; var d = cat.GetCard(ci.CardDefinitionId); var pl = cat.GetPlayer(d.PlayerId);
                var fit = PositionFit.Evaluate(slot.Position, pl);
                var row = Ui.Panel(_list, "C_" + pl.PlayerId, fit == Fit.Invalid ? Ui.C(DesignTokens.NavyLight) : Ui.SurfaceRaised, true, true); Ui.Size(row.gameObject, -1, 84);
                var nameL = Ui.FitLabel(row.transform, pl.DisplayName, 28, fit == Fit.Invalid ? Ui.Muted : Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.Stretch(nameL.rectTransform, 16, 6, 300, 38);
                nameL.rectTransform.anchorMin = new Vector2(0, 0.45f); nameL.rectTransform.offsetMin = new Vector2(16, 0); nameL.rectTransform.offsetMax = new Vector2(-250, -4);
                string where = plan.Starters.Contains(ci.CardInstanceId) ? "İLK 11" : plan.Bench.Contains(ci.CardInstanceId) ? "YEDEK" : "";
                var sub = Ui.Label(row.transform, pl.PrimaryPosition + (pl.AlternatePositions.Count > 0 ? " / " + string.Join("/", pl.AlternatePositions.Select(x => x.ToString()).ToArray()) : "") + (where != "" ? "   •   " + where : ""), 20, Ui.Muted, TextAnchor.MiddleLeft);
                sub.rectTransform.anchorMin = Vector2.zero; sub.rectTransform.anchorMax = new Vector2(1, 0.45f); sub.rectTransform.offsetMin = new Vector2(16, 4); sub.rectTransform.offsetMax = new Vector2(-250, 0);
                var gen = Ui.FitLabel(row.transform, d.Overall.ToString(), 40, Ui.Yellow, TextAnchor.MiddleRight, FontStyle.Bold); gen.rectTransform.anchorMin = new Vector2(1, 0); gen.rectTransform.anchorMax = new Vector2(1, 1); gen.rectTransform.pivot = new Vector2(1, 0.5f); gen.rectTransform.sizeDelta = new Vector2(90, 0); gen.rectTransform.anchoredPosition = new Vector2(-16, 0);
                string fitText = fit == Fit.Exact ? "UYGUN" : fit == Fit.Alternate ? "ALT. MEVKİ" : fit == Fit.OutOfPosition ? "POZ. DIŞI" : "OYNAYAMAZ";
                var fc = fit == Fit.Invalid ? Ui.Danger : fit == Fit.OutOfPosition ? Ui.C(DesignTokens.YellowPressed) : Ui.Success;
                var ft = Ui.Panel(row.transform, "Fit", fc, true); ft.rectTransform.anchorMin = ft.rectTransform.anchorMax = new Vector2(1, 0.5f); ft.rectTransform.pivot = new Vector2(1, 0.5f); ft.rectTransform.anchoredPosition = new Vector2(-116, 0); ft.rectTransform.sizeDelta = new Vector2(124, 44);
                var fl = Ui.FitLabel(ft.transform, fitText, 18, Ui.Navy); Ui.Stretch(fl.rectTransform, 4, 2, 4, 2);
                var btn = row.gameObject.AddComponent<Button>(); btn.targetGraphic = row;
                string cid = ci.CardInstanceId; int sIdx = slot.Index; Fit f2 = fit;
                btn.onClick.AddListener(() =>
                {
                    if (f2 == Fit.Invalid) { App.Modal.Info("Bu mevkide oynayamaz", pl.DisplayName + " (" + pl.PrimaryPosition + ") " + slot.Position + " mevkisinde oynatılamaz."); return; }
                    SquadService.Place(Plan, sIdx, cid);
                    Commit();
                });
            }
        }

        void OnBenchTap(string benchCardId)
        {
            if (_selectedSlot < 0) { _message = "Önce sahadan değiştirilecek slotu seç."; Render(); return; }
            var plan = Plan; var f = Formations.Get(plan.FormationId);
            var ci = App.Profile.Inventory.Get(benchCardId); var d = App.Catalog.GetCard(ci.CardDefinitionId); var pl = App.Catalog.GetPlayer(d.PlayerId);
            if (PositionFit.Evaluate(f.Slots[_selectedSlot].Position, pl) == Fit.Invalid)
            { App.Modal.Info("Bu mevkide oynayamaz", pl.DisplayName + " (" + pl.PrimaryPosition + ") " + f.Slots[_selectedSlot].Position + " mevkisinde oynatılamaz."); return; }
            SquadService.SwapWithBench(plan, _selectedSlot, benchCardId);
            Commit("Oyuncu değişikliği yapıldı.");
        }

        void ChangeFormation(string id)
        {
            if (id == Plan.FormationId) return;
            var r = AutoPicker.Pick(id, App.Profile.Inventory, App.Catalog, null, Plan.SquadId, Plan.Name);
            var idx = App.Profile.Squads.IndexOf(Plan); App.Profile.Squads[idx] = r.Plan;
            _selectedSlot = -1;
            Commit(r.IsComplete ? "Diziliş " + id + " olarak değişti; kadro otomatik kuruldu." : "Diziliş değişti; " + r.UnfilledSlots.Count + " slot doldurulamadı.");
        }

        void AutoBuild()
        {
            var pinned = new Dictionary<int, string>();
            var r = AutoPicker.Pick(Plan.FormationId, App.Profile.Inventory, App.Catalog, pinned, Plan.SquadId, Plan.Name);
            var idx = App.Profile.Squads.IndexOf(Plan); App.Profile.Squads[idx] = r.Plan;
            _selectedSlot = -1;
            Commit(r.IsComplete ? "Kadro otomatik kuruldu." : "Otomatik kurulumda " + r.UnfilledSlots.Count + " slot boş kaldı (uygun kart yok).");
        }
    }

    // =====================================================================================
    /// <summary>Koleksiyon + 100 oyunculuk katalog (T039, T040 kısmen): arama, grup filtresi, GEN sıralama, detay, kilitleme.</summary>
    public class CollectionScreen : GameScreen
    {
        bool _catalogTab;
        int _group = -1; // -1 hepsi
        string _query = "";
        RectTransform _grid, _detail;
        InputField _input;
        Text _count;

        public CollectionScreen() { Id = ScreenIds.Collection; }
        public override bool IsTab { get { return false; } }

        protected override void Build()
        {
            var title = Ui.Label(Root, "KOLEKSİYON", DesignTokens.FontTitle, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(title.rectTransform, 24, 4, 500, 56);
            _count = Ui.Label(Root, "", 24, Ui.Muted, TextAnchor.MiddleRight); Ui.PlaceTopLeft(_count.rectTransform, 1100, 10, 760, 44);

            // arama kutusu
            var sb = Ui.Panel(Root, "Search", Ui.Surface, true, true); Ui.PlaceTopLeft(sb.rectTransform, 24, 66, 520, 66);
            _input = sb.gameObject.AddComponent<InputField>();
            var txt = Ui.Label(sb.transform, "", 28, Ui.TextLight, TextAnchor.MiddleLeft); Ui.Stretch(txt.rectTransform, 16, 4, 16, 4); txt.supportRichText = false;
            var ph = Ui.Label(sb.transform, "İsim ara (ör. gokhan)", 26, Ui.Muted, TextAnchor.MiddleLeft); Ui.Stretch(ph.rectTransform, 16, 4, 16, 4); ph.fontStyle = FontStyle.Italic;
            _input.textComponent = txt; _input.placeholder = ph; _input.lineType = InputField.LineType.SingleLine;
            _input.onValueChanged.AddListener(v => { _query = v; Render(); });

            // grup filtreleri + sekmeler
            string[] gl = { "HEPSİ", "KL", "DEF", "ORTA", "FORV" };
            for (int i = 0; i < gl.Length; i++)
            {
                int g = i - 1;
                var b = Ui.MakeButton(Root, gl[i], Ui.SurfaceRaised, Ui.TextLight, () => { _group = g; Render(); }, "G" + i, 24);
                Ui.PlaceTopLeft((RectTransform)b.transform, 564 + i * 124, 66, 116, 66);
            }
            var tab1 = Ui.MakeButton(Root, "SAHİP OLDUKLARIM", Ui.Yellow, Ui.Navy, () => { _catalogTab = false; Render(); }, "TabOwned", 24); Ui.PlaceTopLeft((RectTransform)tab1.transform, 1200, 66, 330, 66);
            var tab2 = Ui.MakeButton(Root, "KATALOG (100)", Ui.SurfaceRaised, Ui.TextLight, () => { _catalogTab = true; Render(); }, "TabCat", 24); Ui.PlaceTopLeft((RectTransform)tab2.transform, 1540, 66, 320, 66);

            var holder = Ui.NewRect("GridHolder", Root); Ui.PlaceTopLeft(holder, 24, 144, 1840, 700);
            var sr = Ui.Scroll(holder, "Scroll", true, out _grid); Ui.Stretch((RectTransform)sr.transform);
            var gl2 = _grid.gameObject.AddComponent<GridLayoutGroup>(); gl2.cellSize = new Vector2(212, 288); gl2.spacing = new Vector2(16, 16); gl2.padding = new RectOffset(4, 4, 4, 24);
            Ui.FitContent(_grid);

            _detail = Ui.NewRect("Detail", Root); Ui.Stretch(_detail); _detail.gameObject.SetActive(false);
        }

        public override bool HandleBack() { if (_detail.gameObject.activeSelf) { _detail.gameObject.SetActive(false); return true; } return false; }
        public override void OnShow() { _detail.gameObject.SetActive(false); Render(); }

        static bool GroupMatch(int g, PositionGroup pg) { return g < 0 || (int)pg == g; }

        void Render()
        {
            Ui.Clear(_grid);
            var cat = App.Catalog; var inv = App.Profile.Inventory;
            int shown = 0;
            if (!_catalogTab)
            {
                var rows = inv.Cards.Select(ci => new { ci, d = cat.GetCard(ci.CardDefinitionId) }).Select(x => new { x.ci, x.d, p = cat.GetPlayer(x.d.PlayerId) })
                    .Where(x => GroupMatch(_group, x.p.PositionGroup) && TextFold.Matches(x.p.DisplayName, _query))
                    .OrderByDescending(x => x.d.Overall).ThenBy(x => x.p.DisplayName).ToList();
                foreach (var x in rows)
                {
                    var rt = CardView.Create(_grid, x.p, x.d, 212, 288, new CardView.Options { Instance = x.ci });
                    var btn = rt.gameObject.AddComponent<Button>(); btn.targetGraphic = rt.GetComponent<Image>();
                    var ci = x.ci; var d = x.d; var p = x.p;
                    btn.onClick.AddListener(() => ShowDetail(p, d, ci));
                    shown++;
                }
                _count.text = shown + " / " + inv.Cards.Count + " kart";
                if (shown == 0) EmptyState(inv.Cards.Count == 0 ? "Henüz kartın yok." : "Aramana uyan kart yok.");
            }
            else
            {
                var owned = new HashSet<string>(inv.Cards.Select(c => cat.GetCard(c.CardDefinitionId).PlayerId));
                var rows = cat.Players.Where(p => GroupMatch(_group, p.PositionGroup) && TextFold.Matches(p.DisplayName, _query)).OrderByDescending(p => p.BaseOverall).ThenBy(p => p.DisplayName).ToList();
                foreach (var p in rows)
                {
                    var d = cat.GetCard(p.PlayerId + "_BASE_V1");
                    var rt = CardView.Create(_grid, p, d, 212, 288, new CardView.Options { Dimmed = !owned.Contains(p.PlayerId) });
                    var btn = rt.gameObject.AddComponent<Button>(); btn.targetGraphic = rt.GetComponent<Image>();
                    var pp = p; var dd = d;
                    btn.onClick.AddListener(() => ShowDetail(pp, dd, null));
                    shown++;
                }
                _count.text = shown + " / " + cat.UniquePlayerCount + " futbolcu  •  " + owned.Count + " sahip";
                if (shown == 0) EmptyState("Aramana uyan futbolcu yok.");
            }
        }

        void EmptyState(string msg)
        {
            var t = Ui.Label(_grid, msg, 30, Ui.Muted, TextAnchor.MiddleCenter);
            t.rectTransform.sizeDelta = new Vector2(1000, 120);
        }

        void ShowDetail(PlayerDefinition p, CardDefinition d, CardInstance ci)
        {
            Ui.Clear(_detail); _detail.gameObject.SetActive(true);
            var dim = Ui.Panel(_detail, "Dim", new Color(0, 0, 0, 0.8f), false, true); Ui.Stretch(dim.rectTransform);
            var box = Ui.Panel(_detail, "Box", Ui.Surface, true, true); Ui.Stretch(box.rectTransform, 140, 30, 140, 30);
            var card = CardView.Create(box.transform, p, d, 420, 570, new CardView.Options { Instance = ci });
            card.anchorMin = card.anchorMax = new Vector2(0, 0.5f); card.pivot = new Vector2(0, 0.5f); card.anchoredPosition = new Vector2(40, 0);
            var le = card.GetComponent<LayoutElement>(); if (le != null) UnityEngine.Object.Destroy(le);

            var name = Ui.FitLabel(box.transform, p.DisplayName, 50, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(name.rectTransform, 500, 30, 980, 70);
            string alts = p.AlternatePositions.Count > 0 ? "  (alt: " + string.Join(", ", p.AlternatePositions.Select(x => x.ToString()).ToArray()) + ")" : "";
            var meta = Ui.Label(box.transform, p.NationalityLabel + "   •   " + p.PrimaryPosition + alts + "   •   " + (p.PreferredFoot == PreferredFoot.Left ? "Sol ayak" : "Sağ ayak") + "   •   Beceri " + p.SkillStars + "★   •   Dayanıklılık " + p.Stamina, 26, Ui.Muted, TextAnchor.MiddleLeft);
            Ui.PlaceTopLeft(meta.rectTransform, 500, 104, 980, 40);
            var a = p.Attributes;
            string[] names = p.PositionGroup == PositionGroup.GK ? new[] { "KURTARIŞ", "PAS", "FİZİK" } : new[] { "HIZ", "ŞUT", "PAS", "DRİBLİNG", "DEFANS", "FİZİK" };
            int[] vals = p.PositionGroup == PositionGroup.GK ? new[] { a.Goalkeeping, a.Passing, a.Physical } : new[] { a.Pace, a.Shooting, a.Passing, a.Dribbling, a.Defending, a.Physical };
            for (int i = 0; i < names.Length; i++)
            {
                var l = Ui.Label(box.transform, names[i], 24, Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(l.rectTransform, 500, 170 + i * 56, 200, 44);
                var bar = Ui.Panel(box.transform, "Bar" + i, new Color(1, 1, 1, 0.1f), true); Ui.PlaceTopLeft(bar.rectTransform, 710, 180 + i * 56, 560, 24);
                var fill = Ui.Panel(bar.transform, "Fill", vals[i] >= 85 ? Ui.Success : vals[i] >= 70 ? Ui.Yellow : Ui.C(DesignTokens.YellowPressed), true);
                fill.rectTransform.anchorMin = Vector2.zero; fill.rectTransform.anchorMax = new Vector2(Mathf.Clamp01(vals[i] / 99f), 1); fill.rectTransform.offsetMin = fill.rectTransform.offsetMax = Vector2.zero;
                var v = Ui.Label(box.transform, vals[i].ToString(), 26, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold); Ui.PlaceTopLeft(v.rectTransform, 1290, 170 + i * 56, 100, 44);
            }
            var st = Ui.Label(box.transform, "Nitelikler prototip denge değeridir (gerçek reyting değil). Portre: " + (p.Portrait.CanShowRealPortrait ? "teslim edildi" : "teslim edilmedi — siluet gösteriliyor (T091)") + ". İzin: " + p.Portrait.UsageRightsStatus + ".", 20, Ui.Muted, TextAnchor.UpperLeft);
            Ui.PlaceTopLeft(st.rectTransform, 500, 520, 980, 70);

            if (ci != null)
            {
                var lk = Ui.MakeButton(box.transform, ci.Locked ? "KİLİDİ AÇ" : "KİLİTLE", ci.Locked ? Ui.Yellow : Ui.SurfaceRaised, ci.Locked ? Ui.Navy : Ui.TextLight, () =>
                {
                    App.Economy.SetLocked(ci.CardInstanceId, !ci.Locked); App.Save(); ShowDetail(p, d, ci); Render();
                }, "LockBtn", 30);
                Ui.PlaceTopLeft((RectTransform)lk.transform, 500, 600, 340, 84);
                var inSq = App.Profile.ActiveSquad != null && SquadService.IsAssigned(App.Profile.ActiveSquad, ci.CardInstanceId);
                var info = Ui.Label(box.transform, (ci.Locked ? "Kilitli: takas/antrenmanda harcanamaz.  " : "") + (inSq ? "Kadroda." : "") + (ci.Tradable ? "" : "  Satılamaz."), 22, Ui.Muted, TextAnchor.MiddleLeft);
                Ui.PlaceTopLeft(info.rectTransform, 860, 604, 620, 80);
            }
            else
            {
                var no = Ui.Label(box.transform, "Bu futbolcuya sahip değilsin.", 28, Ui.Muted, TextAnchor.MiddleLeft); Ui.PlaceTopLeft(no.rectTransform, 500, 610, 800, 60);
            }
            var close = Ui.PrimaryButton(box.transform, "KAPAT", () => _detail.gameObject.SetActive(false), 32);
            var cr = (RectTransform)close.transform; cr.anchorMin = cr.anchorMax = new Vector2(1, 0); cr.pivot = new Vector2(1, 0); cr.anchoredPosition = new Vector2(-40, 32); cr.sizeDelta = new Vector2(280, 90);
        }
    }
}
