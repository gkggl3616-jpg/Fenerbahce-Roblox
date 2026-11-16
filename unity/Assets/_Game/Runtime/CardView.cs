using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Domain;
using Fenerbahce.Core.Squad;

namespace Fenerbahce.Runtime
{
    /// <summary>Portre yükleyici (T019): gerçek portre yalnız teslim + izin doğrulanmışsa; aksi halde AYNI boyutta siluet.</summary>
    public static class PortraitLibrary
    {
        static readonly Dictionary<string, Texture2D> Cache = new Dictionary<string, Texture2D>();

        public static Texture2D TryGet(PlayerDefinition p)
        {
            if (p.Portrait == null || !p.Portrait.CanShowRealPortrait) return null;
            Texture2D t;
            if (Cache.TryGetValue(p.PlayerId, out t)) return t;
            t = Resources.Load<Texture2D>(p.Portrait.Path);
            Cache[p.PlayerId] = t; // null da önbelleğe alınır → her karede yeniden yüklenmez
            return t;
        }
    }

    /// <summary>Oyuncu kartı bileşeni. Çerçeve (nadirlik) ve portre bağımsızdır (T020).</summary>
    public static class CardView
    {
        public static string FrameHex(Rarity r)
        {
            switch (r)
            {
                case Rarity.Legend: return DesignTokens.FrameLegend;
                case Rarity.Special: return DesignTokens.FrameSpecial;
                default: return DesignTokens.FrameBase;
            }
        }

        public class Options
        {
            public CardInstance Instance;
            public Fit? Fit;
            public bool Selected;
            public bool Dimmed;
            public bool ShowCountry = true;
        }

        public static RectTransform Create(Transform parent, PlayerDefinition p, CardDefinition d, float w, float h, Options o = null)
        {
            o = o ?? new Options();
            var rootImg = Ui.Panel(parent, "Card_" + p.PlayerId, Ui.C(FrameHex(d.Rarity)), true, true);
            var root = rootImg.rectTransform; root.sizeDelta = new Vector2(w, h);
            Ui.Size(root.gameObject, w, h);
            if (o.Selected) rootImg.color = Ui.TextLight;
            if (o.Fit.HasValue && o.Fit.Value == Fenerbahce.Core.Squad.Fit.OutOfPosition) rootImg.color = Ui.C(DesignTokens.YellowPressed);
            if (o.Fit.HasValue && o.Fit.Value == Fenerbahce.Core.Squad.Fit.Invalid) rootImg.color = Ui.Danger;

            float m = Mathf.Max(3f, w * 0.035f);
            var inner = Ui.Panel(root, "Inner", d.Rarity == Rarity.Base ? Ui.C(DesignTokens.NavyLight) : Ui.Navy, true);
            Ui.Stretch(inner.rectTransform, m, m, m, m);

            // Portre alanı: üst ~62%
            var portrait = Ui.NewRect("Portrait", inner.transform);
            portrait.anchorMin = new Vector2(0.06f, 0.30f); portrait.anchorMax = new Vector2(0.94f, 0.80f);
            portrait.offsetMin = portrait.offsetMax = Vector2.zero;
            var tex = PortraitLibrary.TryGet(p);
            if (tex != null)
            {
                var raw = portrait.gameObject.AddComponent<RawImage>(); raw.texture = tex; raw.raycastTarget = false;
                float aspect = (w * 0.88f) / (h * 0.50f);
                var uv = PortraitCrop.Compute(aspect, p.Portrait.FocalX, p.Portrait.FocalY);
                raw.uvRect = new Rect(uv.X, uv.Y, uv.W, uv.H);
            }
            else BuildSilhouette(portrait, d.Rarity);

            // GEN + mevki (sol üst)
            var gen = Ui.FitLabel(inner.transform, d.Overall.ToString(), Mathf.RoundToInt(h * 0.16f), Ui.TextLight, TextAnchor.MiddleLeft, FontStyle.Bold, "GEN");
            gen.rectTransform.anchorMin = new Vector2(0.06f, 0.80f); gen.rectTransform.anchorMax = new Vector2(0.50f, 0.99f); gen.rectTransform.offsetMin = gen.rectTransform.offsetMax = Vector2.zero;
            var pos = Ui.FitLabel(inner.transform, p.PrimaryPosition.ToString(), Mathf.RoundToInt(h * 0.09f), Ui.Yellow, TextAnchor.MiddleRight, FontStyle.Bold, "POS");
            pos.rectTransform.anchorMin = new Vector2(0.50f, 0.82f); pos.rectTransform.anchorMax = new Vector2(0.94f, 0.98f); pos.rectTransform.offsetMin = pos.rectTransform.offsetMax = Vector2.zero;

            // İsim (taşmaz: küçülür, en fazla 2 satır)
            var name = Ui.FitLabel(inner.transform, p.DisplayName, Mathf.RoundToInt(h * 0.085f), Ui.TextLight, TextAnchor.MiddleCenter, FontStyle.Bold, "Name");
            name.rectTransform.anchorMin = new Vector2(0.04f, 0.10f); name.rectTransform.anchorMax = new Vector2(0.96f, 0.30f); name.rectTransform.offsetMin = name.rectTransform.offsetMax = Vector2.zero;

            if (o.ShowCountry)
            {
                var c = Ui.FitLabel(inner.transform, p.NationalityLabel, Mathf.RoundToInt(h * 0.065f), Ui.Muted, TextAnchor.MiddleCenter, FontStyle.Normal, "Country");
                c.rectTransform.anchorMin = new Vector2(0.04f, 0.01f); c.rectTransform.anchorMax = new Vector2(0.96f, 0.11f); c.rectTransform.offsetMin = c.rectTransform.offsetMax = Vector2.zero;
            }

            if (o.Instance != null && o.Instance.Locked)
            {
                var lk = Ui.FitLabel(inner.transform, "KİLİT", Mathf.RoundToInt(h * 0.06f), Ui.Navy, TextAnchor.MiddleCenter, FontStyle.Bold, "Lock");
                var bg = Ui.Panel(inner.transform, "LockBg", Ui.Yellow, true);
                bg.rectTransform.anchorMin = new Vector2(0.62f, 0.62f); bg.rectTransform.anchorMax = new Vector2(0.96f, 0.72f); bg.rectTransform.offsetMin = bg.rectTransform.offsetMax = Vector2.zero;
                lk.transform.SetParent(bg.transform, false); Ui.Stretch(lk.rectTransform);
            }
            if (o.Dimmed)
            {
                var dim = Ui.Panel(root, "Dim", new Color(0.02f, 0.05f, 0.1f, 0.62f), true);
                Ui.Stretch(dim.rectTransform);
            }
            return root;
        }

        /// <summary>Özgün genel siluet: eksik portrede aynı alanı doldurur.</summary>
        public static void BuildSilhouette(RectTransform area, Rarity rarity)
        {
            var tint = rarity == Rarity.Base ? Ui.C(DesignTokens.Locked) : (rarity == Rarity.Special ? Ui.C(DesignTokens.YellowPressed) : Ui.C(DesignTokens.FrameLegend));
            var bg = Ui.Panel(area, "SilBg", new Color(1f, 1f, 1f, 0.06f), true); Ui.Stretch(bg.rectTransform);
            var body = Ui.Panel(area, "SilBody", tint, true);
            body.rectTransform.anchorMin = new Vector2(0.22f, 0f); body.rectTransform.anchorMax = new Vector2(0.78f, 0.52f); body.rectTransform.offsetMin = body.rectTransform.offsetMax = Vector2.zero;
            var head = Ui.Panel(area, "SilHead", tint, false); head.sprite = Ui.Circle; head.type = Image.Type.Simple;
            head.rectTransform.anchorMin = new Vector2(0.34f, 0.50f); head.rectTransform.anchorMax = new Vector2(0.66f, 0.92f); head.rectTransform.offsetMin = head.rectTransform.offsetMax = Vector2.zero;
            head.preserveAspect = true;
        }
    }

    /// <summary>Basit modal (onay/bilgi).</summary>
    public class ModalHost
    {
        readonly RectTransform _layer;
        GameObject _current;
        public ModalHost(RectTransform layer) { _layer = layer; }
        public bool IsOpen { get { return _current != null; } }

        public void Close() { if (_current != null) Object.Destroy(_current); _current = null; }

        public void Show(string title, string body, params KeyValuePair<string, System.Action>[] buttons)
        {
            Close();
            var dim = Ui.Panel(_layer, "Modal", new Color(0, 0, 0, 0.7f), false, true);
            Ui.Stretch(dim.rectTransform); _current = dim.gameObject;
            var box = Ui.Panel(dim.transform, "Box", Ui.Surface, true, true);
            Ui.Anchor(box.rectTransform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(900, 520));
            box.rectTransform.pivot = new Vector2(0.5f, 0.5f);
            var outline = Ui.Panel(box.transform, "Border", Ui.Yellow, true); outline.raycastTarget = false;
            Ui.Stretch(outline.rectTransform); outline.transform.SetAsFirstSibling();
            var inner = Ui.Panel(box.transform, "Inner", Ui.Surface, true); inner.raycastTarget = false; Ui.Stretch(inner.rectTransform, 4, 4, 4, 4);
            inner.transform.SetSiblingIndex(1);
            var t = Ui.FitLabel(box.transform, title, DesignTokens.FontTitle, Ui.Yellow, TextAnchor.MiddleLeft, FontStyle.Bold, "Title");
            t.rectTransform.anchorMin = new Vector2(0, 1); t.rectTransform.anchorMax = new Vector2(1, 1); t.rectTransform.pivot = new Vector2(0.5f, 1);
            t.rectTransform.offsetMin = new Vector2(40, -110); t.rectTransform.offsetMax = new Vector2(-40, -30);
            var b = Ui.Label(box.transform, body, DesignTokens.FontBody, Ui.TextLight, TextAnchor.UpperLeft, FontStyle.Normal, "Body");
            b.rectTransform.anchorMin = Vector2.zero; b.rectTransform.anchorMax = Vector2.one;
            b.rectTransform.offsetMin = new Vector2(40, 130); b.rectTransform.offsetMax = new Vector2(-40, -120);
            var row = Ui.HRow(box.transform, "Buttons", 24, TextAnchor.MiddleRight, false);
            row.padding = new RectOffset(0, 0, 0, 0);
            var rr = (RectTransform)row.transform; rr.anchorMin = new Vector2(0, 0); rr.anchorMax = new Vector2(1, 0); rr.pivot = new Vector2(0.5f, 0);
            rr.offsetMin = new Vector2(40, 30); rr.offsetMax = new Vector2(-40, 120);
            for (int i = 0; i < buttons.Length; i++)
            {
                var cb = buttons[i].Value;
                var btn = i == buttons.Length - 1 ? Ui.PrimaryButton(row.transform, buttons[i].Key, () => { Close(); if (cb != null) cb(); })
                                                   : Ui.SecondaryButton(row.transform, buttons[i].Key, () => { Close(); if (cb != null) cb(); });
                Ui.Size(btn.gameObject, 280, 84);
            }
        }

        public void Info(string title, string body) { Show(title, body, new KeyValuePair<string, System.Action>("TAMAM", null)); }

        public void Confirm(string title, string body, string okLabel, System.Action onOk)
        {
            Show(title, body, new KeyValuePair<string, System.Action>("VAZGEÇ", null), new KeyValuePair<string, System.Action>(okLabel, onOk));
        }
    }
}
