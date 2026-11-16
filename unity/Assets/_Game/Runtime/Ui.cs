using System;
using UnityEngine;
using UnityEngine.UI;
using Fenerbahce.Core.Design;

namespace Fenerbahce.Runtime
{
    /// <summary>
    /// Kodla UI kurmak için yardımcılar (T009). Renkler/boşluklar DesignTokens'tan gelir (tek kaynak).
    /// Sprite/prefab bağımlılığı yoktur: yuvarlak köşe ve daire sprite'ları çalışma anında üretilir.
    /// </summary>
    public static class Ui
    {
        public static Color C(string hex)
        {
            Color c; ColorUtility.TryParseHtmlString(hex, out c); return c;
        }

        public static Color Navy { get { return C(DesignTokens.Navy); } }
        public static Color Yellow { get { return C(DesignTokens.Yellow); } }
        public static Color TextLight { get { return C(DesignTokens.TextLight); } }
        public static Color Surface { get { return C(DesignTokens.Surface); } }
        public static Color SurfaceRaised { get { return C(DesignTokens.SurfaceRaised); } }
        public static Color Muted { get { return C(DesignTokens.TextMuted); } }
        public static Color Danger { get { return C(DesignTokens.Danger); } }
        public static Color Success { get { return C(DesignTokens.Success); } }
        public static Color Locked { get { return C(DesignTokens.Locked); } }

        static Font _font;
        public static Font Font
        {
            get
            {
                if (_font != null) return _font;
                try { _font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); } catch (Exception) { }
                if (_font == null) { try { _font = Resources.GetBuiltinResource<Font>("Arial.ttf"); } catch (Exception) { } }
                if (_font == null) _font = Font.CreateDynamicFontFromOSFont("Arial", 24);
                return _font;
            }
        }

        // ---------- sprite üretimi ----------
        static Sprite _rounded, _circle, _white;

        public static Sprite Rounded
        {
            get { if (_rounded == null) _rounded = MakeRounded(64, DesignTokens.Radius); return _rounded; }
        }

        public static Sprite Circle
        {
            get { if (_circle == null) _circle = MakeRounded(64, 32, false); return _circle; }
        }

        public static Sprite White
        {
            get
            {
                if (_white == null)
                {
                    var t = new Texture2D(4, 4, TextureFormat.RGBA32, false);
                    var px = new Color[16]; for (int i = 0; i < 16; i++) px[i] = Color.white;
                    t.SetPixels(px); t.Apply(); t.filterMode = FilterMode.Bilinear;
                    _white = Sprite.Create(t, new Rect(0, 0, 4, 4), new Vector2(0.5f, 0.5f), 100f);
                }
                return _white;
            }
        }

        static Sprite MakeRounded(int size, float radius, bool sliced = true)
        {
            var t = new Texture2D(size, size, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp };
            var px = new Color32[size * size];
            float r = Mathf.Min(radius, size / 2f);
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float cx = Mathf.Clamp(x + 0.5f, r, size - r), cy = Mathf.Clamp(y + 0.5f, r, size - r);
                    float d = Mathf.Sqrt((x + 0.5f - cx) * (x + 0.5f - cx) + (y + 0.5f - cy) * (y + 0.5f - cy));
                    float a = Mathf.Clamp01(r - d + 0.5f);
                    px[y * size + x] = new Color32(255, 255, 255, (byte)(a * 255f));
                }
            t.SetPixels32(px); t.Apply();
            var border = sliced ? new Vector4(r, r, r, r) : Vector4.zero;
            return Sprite.Create(t, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100f, 0, SpriteMeshType.FullRect, border);
        }

        // ---------- yapı taşları ----------
        public static RectTransform NewRect(string name, Transform parent)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            return (RectTransform)go.transform;
        }

        public static void Stretch(RectTransform rt, float l = 0, float t = 0, float r = 0, float b = 0)
        {
            rt.anchorMin = Vector2.zero; rt.anchorMax = Vector2.one;
            rt.offsetMin = new Vector2(l, b); rt.offsetMax = new Vector2(-r, -t);
        }

        /// <summary>Üst-sol köşeye göre konum/boyut (Y aşağı pozitif).</summary>
        public static void PlaceTopLeft(RectTransform rt, float x, float y, float w, float h)
        {
            rt.anchorMin = rt.anchorMax = new Vector2(0, 1); rt.pivot = new Vector2(0, 1);
            rt.anchoredPosition = new Vector2(x, -y); rt.sizeDelta = new Vector2(w, h);
        }

        public static void Anchor(RectTransform rt, Vector2 anchor, Vector2 pos, Vector2 size)
        {
            rt.anchorMin = rt.anchorMax = anchor; rt.pivot = anchor;
            rt.anchoredPosition = pos; rt.sizeDelta = size;
        }

        public static Image Panel(Transform parent, string name, Color color, bool rounded = true, bool raycast = false)
        {
            var rt = NewRect(name, parent);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = color; img.raycastTarget = raycast;
            if (rounded) { img.sprite = Rounded; img.type = Image.Type.Sliced; } else img.sprite = White;
            return img;
        }

        public static Text Label(Transform parent, string text, int size, Color color, TextAnchor align = TextAnchor.MiddleLeft, FontStyle style = FontStyle.Normal, string name = "Text")
        {
            var rt = NewRect(name, parent);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = Font; t.text = text; t.fontSize = size; t.color = color; t.alignment = align; t.fontStyle = style;
            t.horizontalOverflow = HorizontalWrapMode.Wrap; t.verticalOverflow = VerticalWrapMode.Truncate;
            t.raycastTarget = false; t.supportRichText = false;
            return t;
        }

        /// <summary>Tek satır, taşarsa küçülen metin (uzun Türkçe isimler taşmaz).</summary>
        public static Text FitLabel(Transform parent, string text, int maxSize, Color color, TextAnchor align = TextAnchor.MiddleCenter, FontStyle style = FontStyle.Bold, string name = "Fit")
        {
            var t = Label(parent, text, maxSize, color, align, style, name);
            t.resizeTextForBestFit = true; t.resizeTextMinSize = Mathf.Max(8, maxSize / 3); t.resizeTextMaxSize = maxSize;
            t.horizontalOverflow = HorizontalWrapMode.Wrap; t.verticalOverflow = VerticalWrapMode.Truncate;
            return t;
        }

        public static Button MakeButton(Transform parent, string label, Color bg, Color fg, Action onClick, string name = "Button", int fontSize = 0)
        {
            var img = Panel(parent, name, bg, true, true);
            var btn = img.gameObject.AddComponent<Button>();
            btn.targetGraphic = img;
            var colors = btn.colors;
            colors.normalColor = Color.white; colors.highlightedColor = new Color(1f, 1f, 1f, 0.95f);
            colors.pressedColor = new Color(0.75f, 0.75f, 0.75f, 1f); colors.disabledColor = new Color(0.5f, 0.5f, 0.5f, 0.6f);
            colors.fadeDuration = 0.05f;
            btn.colors = colors;
            var t = FitLabel(img.transform, label, fontSize > 0 ? fontSize : DesignTokens.FontButton, fg);
            Stretch(t.rectTransform, 8, 4, 8, 4);
            if (onClick != null) btn.onClick.AddListener(() => onClick());
            return btn;
        }

        public static Button PrimaryButton(Transform parent, string label, Action onClick, int fontSize = 0)
        {
            return MakeButton(parent, label, Yellow, Navy, onClick, "Primary_" + label, fontSize);
        }

        public static Button SecondaryButton(Transform parent, string label, Action onClick, int fontSize = 0)
        {
            return MakeButton(parent, label, SurfaceRaised, TextLight, onClick, "Secondary_" + label, fontSize);
        }

        public static void SetButtonLabel(Button b, string label) { var t = b.GetComponentInChildren<Text>(); if (t != null) t.text = label; }

        public static void SetEnabledLook(Button b, bool enabled)
        {
            b.interactable = enabled;
        }

        public static ScrollRect Scroll(Transform parent, string name, bool vertical, out RectTransform content)
        {
            var rt = NewRect(name, parent);
            var img = rt.gameObject.AddComponent<Image>(); img.color = new Color(0, 0, 0, 0.001f);
            var sr = rt.gameObject.AddComponent<ScrollRect>();
            rt.gameObject.AddComponent<RectMask2D>();
            var vp = NewRect("Content", rt);
            sr.content = vp; sr.horizontal = !vertical; sr.vertical = vertical; sr.movementType = ScrollRect.MovementType.Elastic;
            sr.scrollSensitivity = 30f; sr.inertia = true;
            if (vertical)
            {
                vp.anchorMin = new Vector2(0, 1); vp.anchorMax = new Vector2(1, 1); vp.pivot = new Vector2(0.5f, 1);
                vp.offsetMin = new Vector2(0, 0); vp.offsetMax = new Vector2(0, 0);
            }
            else
            {
                vp.anchorMin = new Vector2(0, 0); vp.anchorMax = new Vector2(0, 1); vp.pivot = new Vector2(0, 0.5f);
                vp.offsetMin = new Vector2(0, 0); vp.offsetMax = new Vector2(0, 0);
            }
            content = vp;
            return sr;
        }

        public static HorizontalLayoutGroup HRow(Transform parent, string name, float spacing, TextAnchor align = TextAnchor.MiddleLeft, bool expand = false)
        {
            var rt = NewRect(name, parent);
            var h = rt.gameObject.AddComponent<HorizontalLayoutGroup>();
            h.spacing = spacing; h.childAlignment = align;
            h.childControlWidth = true; h.childControlHeight = true; h.childForceExpandWidth = expand; h.childForceExpandHeight = expand;
            return h;
        }

        public static VerticalLayoutGroup VCol(Transform parent, string name, float spacing, TextAnchor align = TextAnchor.UpperLeft, bool expand = false)
        {
            var rt = NewRect(name, parent);
            var v = rt.gameObject.AddComponent<VerticalLayoutGroup>();
            v.spacing = spacing; v.childAlignment = align;
            v.childControlWidth = true; v.childControlHeight = true; v.childForceExpandWidth = expand; v.childForceExpandHeight = expand;
            return v;
        }

        public static LayoutElement Size(GameObject go, float w = -1, float h = -1, float flexW = -1, float flexH = -1)
        {
            var le = go.GetComponent<LayoutElement>() ?? go.AddComponent<LayoutElement>();
            if (w >= 0) le.preferredWidth = w; if (h >= 0) le.preferredHeight = h;
            if (w >= 0) le.minWidth = w; if (h >= 0) le.minHeight = h;
            if (flexW >= 0) le.flexibleWidth = flexW; if (flexH >= 0) le.flexibleHeight = flexH;
            return le;
        }

        public static void Pad(LayoutGroup g, int l, int t, int r, int b) { g.padding = new RectOffset(l, r, t, b); }

        public static void FitContent(RectTransform content, bool vertical = true)
        {
            var f = content.gameObject.AddComponent<ContentSizeFitter>();
            f.verticalFit = vertical ? ContentSizeFitter.FitMode.PreferredSize : ContentSizeFitter.FitMode.Unconstrained;
            f.horizontalFit = vertical ? ContentSizeFitter.FitMode.Unconstrained : ContentSizeFitter.FitMode.PreferredSize;
        }

        public static void Clear(Transform t)
        {
            for (int i = t.childCount - 1; i >= 0; i--) UnityEngine.Object.Destroy(t.GetChild(i).gameObject);
        }
    }

    /// <summary>Çentik/kenar boşlukları için güvenli alan (T016). Her kare değil, değişince günceller.</summary>
    public class SafeAreaFitter : MonoBehaviour
    {
        Rect _last; Vector2Int _lastScreen;
        RectTransform _rt;

        void Awake() { _rt = (RectTransform)transform; Apply(); }
        void Update() { if (_last != UnityEngine.Screen.safeArea || _lastScreen.x != UnityEngine.Screen.width || _lastScreen.y != UnityEngine.Screen.height) Apply(); }

        void Apply()
        {
            var sa = UnityEngine.Screen.safeArea;
            _last = sa; _lastScreen = new Vector2Int(UnityEngine.Screen.width, UnityEngine.Screen.height);
            if (UnityEngine.Screen.width <= 0 || UnityEngine.Screen.height <= 0) return;
            var min = sa.position; var max = sa.position + sa.size;
            _rt.anchorMin = new Vector2(min.x / UnityEngine.Screen.width, min.y / UnityEngine.Screen.height);
            _rt.anchorMax = new Vector2(max.x / UnityEngine.Screen.width, max.y / UnityEngine.Screen.height);
            _rt.offsetMin = Vector2.zero; _rt.offsetMax = Vector2.zero;
        }
    }
}
