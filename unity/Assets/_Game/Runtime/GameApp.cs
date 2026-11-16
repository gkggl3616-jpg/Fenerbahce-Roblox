using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using Fenerbahce.Core.Catalog;
using Fenerbahce.Core.Design;
using Fenerbahce.Core.Economy;
using Fenerbahce.Core.Persistence;
using Fenerbahce.Core.Squad;

namespace Fenerbahce.Runtime
{
    /// <summary>
    /// Uygulama kökü: içerik yükleme → profil yükleme/oluşturma → ekranlar. Sahne bağımsızdır;
    /// RuntimeInitializeOnLoadMethod ile herhangi bir (boş) sahnede kendini kurar.
    /// </summary>
    public class GameApp : MonoBehaviour
    {
        public static GameApp I { get; private set; }

        public ContentCatalog Catalog { get; private set; }
        public ProfileState Profile { get; private set; }
        public EconomyService Economy { get; private set; }
        public List<Campaign> Campaigns { get; private set; }
        public ScreenManager Nav { get; private set; }
        public ModalHost Modal { get; private set; }
        public RectTransform Content { get; private set; }
        public Canvas MenuCanvas { get { return _canvas; } }
        public Camera MenuCamera { get { return _menuCam; } }
        public FieldController Field { get; private set; }

        ProfileRepository _repo;
        string _profilePath;
        Canvas _canvas;
        Camera _menuCam;
        RectTransform _safe, _chromeTop, _chromeBottom, _errorLayer;
        TopBar _top; BottomNav _bottom;
        bool _booted;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Bootstrap()
        {
            if (I != null) return;
            var go = new GameObject("Game");
            go.AddComponent<GameApp>();
        }

        void Awake()
        {
            I = this;
            DontDestroyOnLoad(gameObject);
            Input.multiTouchEnabled = true;
            UnityEngine.Screen.sleepTimeout = SleepTimeout.NeverSleep;
            UnityEngine.Screen.orientation = ScreenOrientation.AutoRotation;
            UnityEngine.Screen.autorotateToLandscapeLeft = UnityEngine.Screen.autorotateToLandscapeRight = true;
            UnityEngine.Screen.autorotateToPortrait = UnityEngine.Screen.autorotateToPortraitUpsideDown = false;
            _profilePath = Path.Combine(Application.persistentDataPath, "profile.json");
            _repo = new ProfileRepository(new FileStorage(_profilePath));
        }

        void Start()
        {
            BuildShell();
            Boot();
        }

        // ---------------- kabuk (canvas, kamera, event system) ----------------
        void BuildShell()
        {
            var camGo = new GameObject("MenuCamera");
            camGo.transform.SetParent(transform, false);
            _menuCam = camGo.AddComponent<Camera>();
            _menuCam.clearFlags = CameraClearFlags.SolidColor; _menuCam.backgroundColor = Ui.Navy; _menuCam.cullingMask = 0; _menuCam.depth = -10;

            if (FindObjectOfType<EventSystem>() == null)
            {
                var es = new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
                es.transform.SetParent(transform, false);
            }

            var cgo = new GameObject("MenuCanvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            cgo.transform.SetParent(transform, false);
            _canvas = cgo.GetComponent<Canvas>(); _canvas.renderMode = RenderMode.ScreenSpaceOverlay; _canvas.sortingOrder = 0;
            var sc = cgo.GetComponent<CanvasScaler>();
            sc.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            sc.referenceResolution = new Vector2(DesignTokens.ReferenceResolution[0], DesignTokens.ReferenceResolution[1]);
            sc.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight; sc.matchWidthOrHeight = 0.5f;

            var bg = Ui.Panel(cgo.transform, "Background", Ui.Navy, false); Ui.Stretch(bg.rectTransform);
            _safe = Ui.NewRect("SafeArea", cgo.transform); Ui.Stretch(_safe); _safe.gameObject.AddComponent<SafeAreaFitter>();

            Content = Ui.NewRect("Content", _safe); Ui.Stretch(Content, 0, 100, 0, 104);
            _chromeTop = Ui.NewRect("TopBar", _safe);
            _chromeTop.anchorMin = new Vector2(0, 1); _chromeTop.anchorMax = new Vector2(1, 1); _chromeTop.pivot = new Vector2(0.5f, 1);
            _chromeTop.offsetMin = new Vector2(0, -96); _chromeTop.offsetMax = Vector2.zero;
            _chromeBottom = Ui.NewRect("BottomNav", _safe);
            _chromeBottom.anchorMin = new Vector2(0, 0); _chromeBottom.anchorMax = new Vector2(1, 0); _chromeBottom.pivot = new Vector2(0.5f, 0);
            _chromeBottom.offsetMin = Vector2.zero; _chromeBottom.offsetMax = new Vector2(0, 100);

            var modalLayer = Ui.NewRect("ModalLayer", cgo.transform); Ui.Stretch(modalLayer);
            Modal = new ModalHost(modalLayer);
            _errorLayer = Ui.NewRect("ErrorLayer", cgo.transform); Ui.Stretch(_errorLayer);
            _errorLayer.gameObject.SetActive(false);
        }

        // ---------------- açılış ----------------
        public void Boot()
        {
            _errorLayer.gameObject.SetActive(false);
            try
            {
                LoadContent();
                LoadProfile();
                ApplySettings();
                BuildScreens();
                _booted = true;
                Nav.GoRoot(ScreenIds.Home);
            }
            catch (Exception e)
            {
                Debug.LogError("[Boot] " + e);
                ShowBootError(e);
            }
        }

        void LoadContent()
        {
            var p = Resources.Load<TextAsset>("Content/players.v1");
            var c = Resources.Load<TextAsset>("Content/cards.v1");
            var k = Resources.Load<TextAsset>("Content/campaigns.v1");
            if (p == null || c == null || k == null) throw new InvalidOperationException("İçerik dosyaları bulunamadı (Resources/Content).");
            Catalog = ContentCatalog.Load(p.text, c.text);
            var report = CatalogValidator.Validate(Catalog);
            if (!report.IsValid) throw new InvalidOperationException("Katalog doğrulaması başarısız:\n" + string.Join("\n", report.Errors.Take(5).ToArray()));
            Campaigns = CampaignCatalog.Load(k.text);
            var cerr = CampaignCatalog.Validate(Campaigns);
            if (cerr.Count > 0) throw new InvalidOperationException("Kampanya verisi hatalı: " + cerr[0]);
        }

        void LoadProfile()
        {
            bool created;
            Profile = _repo.LoadOrCreate(Catalog, out created);
            Economy = new EconomyService(Profile, Catalog);
            if (created) Debug.Log("[Profil] yeni profil + başlangıç paketi verildi: " + _profilePath);
        }

        public void ApplySettings()
        {
            var s = Profile.Settings;
            QualitySettings.vSyncCount = 0;
            Application.targetFrameRate = s.GraphicsQuality == 1 ? 30 : 60;
        }

        void BuildScreens()
        {
            if (Nav != null) { Ui.Clear(Content); Ui.Clear(_chromeTop); Ui.Clear(_chromeBottom); }
            Nav = new ScreenManager(this);
            _top = new TopBar(this, _chromeTop);
            _bottom = new BottomNav(this, _chromeBottom);
            Nav.Register(new HomeScreen());
            Nav.Register(new ClubScreen());
            Nav.Register(new CollectionScreen());
            Nav.Register(new PlayScreen());
            Nav.Register(new ComingSoonScreen(ScreenIds.Events, "ETKİNLİKLER VE GÖREVLER", "Etkinlik haritası, günlük/haftalık görevler ve Sezon Bileti henüz uygulanmadı.",
                new[] { "T059 Etkinlik tanımı ve takvim", "T060 Düğüm/önkoşul haritası", "T061 Pas/şut/skill eğitimleri", "T062–T063 Görevler ve ödül alma", "T070–T071 Sezon Bileti", "T090 Beş Fenerbahçe temalı etkinlik" }));
            Nav.Register(new ComingSoonScreen(ScreenIds.Store, "MAĞAZA, PAKET VE TAKAS", "Teklifler, paket açılışı, takas ve transfer pazarı henüz uygulanmadı. Gerçek ekonomi sunucu gerektirir.",
                new[] { "T065 Mağaza kataloğu ve limitler", "T066–T069 Drop table, atomik satın alma, paket açılışı", "T072–T073 Takas", "T077–T080 Transfer pazarı", "T049–T050 Sunucu: kimlik, cüzdan, ledger" }));
            Nav.Register(new SettingsScreen());
            Nav.Register(new ResultScreen());
        }

        void ShowBootError(Exception e)
        {
            Ui.Clear(_errorLayer);
            _errorLayer.gameObject.SetActive(true);
            var bg = Ui.Panel(_errorLayer, "ErrBg", Ui.Navy, false, true); Ui.Stretch(bg.rectTransform);
            var box = Ui.Panel(_errorLayer, "ErrBox", Ui.Surface, true, true);
            Ui.Anchor(box.rectTransform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(1100, 640)); box.rectTransform.pivot = new Vector2(0.5f, 0.5f);
            var t = Ui.Label(box.transform, "BİR SORUN OLDU", DesignTokens.FontTitle, Ui.Yellow, TextAnchor.UpperLeft, FontStyle.Bold);
            t.rectTransform.anchorMin = new Vector2(0, 1); t.rectTransform.anchorMax = new Vector2(1, 1); t.rectTransform.pivot = new Vector2(0.5f, 1);
            t.rectTransform.offsetMin = new Vector2(40, -110); t.rectTransform.offsetMax = new Vector2(-40, -30);
            var m = Ui.Label(box.transform, e.Message, DesignTokens.FontBody, Ui.TextLight, TextAnchor.UpperLeft);
            Ui.Stretch(m.rectTransform, 40, 120, 40, 200);
            var row = Ui.HRow(box.transform, "Row", 24, TextAnchor.MiddleRight);
            var rr = (RectTransform)row.transform; rr.anchorMin = new Vector2(0, 0); rr.anchorMax = new Vector2(1, 0); rr.pivot = new Vector2(0.5f, 0);
            rr.offsetMin = new Vector2(40, 30); rr.offsetMax = new Vector2(-40, 130);
            var reset = Ui.SecondaryButton(row.transform, "KAYDI YEDEKLE VE SIFIRLA", () => { BackupAndResetSave(); Boot(); }); Ui.Size(reset.gameObject, 420, 90);
            var retry = Ui.PrimaryButton(row.transform, "TEKRAR DENE", Boot); Ui.Size(retry.gameObject, 300, 90);
        }

        // ---------------- kayıt ----------------
        public void Save()
        {
            if (!_booted || Profile == null) return;
            try { _repo.Save(Profile); }
            catch (Exception e) { Debug.LogError("[Kayıt] yazılamadı: " + e.Message); }
        }

        public void BackupAndResetSave()
        {
            try
            {
                if (File.Exists(_profilePath)) File.Copy(_profilePath, _profilePath + ".bak." + DateTime.UtcNow.ToString("yyyyMMddHHmmss"), true);
                if (File.Exists(_profilePath)) File.Delete(_profilePath);
            }
            catch (Exception e) { Debug.LogError("[Kayıt] sıfırlanamadı: " + e.Message); }
        }

        void OnApplicationPause(bool paused) { if (paused) Save(); }
        void OnApplicationQuit() { Save(); }

        // ---------------- yardımcılar ----------------
        public void RefreshChrome()
        {
            if (_top != null) _top.Refresh();
            if (_bottom != null) _bottom.Refresh();
        }

        public void SetChromeVisible(bool top, bool bottom)
        {
            _chromeTop.gameObject.SetActive(top); _chromeBottom.gameObject.SetActive(bottom);
            Ui.Stretch(Content, 0, top ? 100 : 0, 0, bottom ? 104 : 0);
        }

        public int SquadErrorCount()
        {
            var sq = Profile.ActiveSquad;
            if (sq == null) return 1;
            return SquadService.Validate(sq, Profile.Inventory, Catalog, true).Count(i => i.IsError);
        }

        // ---------------- saha ----------------
        public void StartField(FieldController.Options options)
        {
            if (Field != null) return;
            _canvas.gameObject.SetActive(false);
            _menuCam.enabled = false;
            var go = new GameObject("Field");
            Field = go.AddComponent<FieldController>();
            Field.Begin(this, options);
        }

        public void EndField(FieldController.Summary summary)
        {
            if (Field != null) { Destroy(Field.gameObject); Field = null; }
            _canvas.gameObject.SetActive(true);
            _menuCam.enabled = true;
            Save();
            RefreshChrome();
            if (summary != null) { ResultScreen.Pending = summary; Nav.Push("result"); }
            else Nav.Back();
        }

        void Update()
        {
            // Android geri tuşu = Escape
            if (_booted && Field == null && Input.GetKeyDown(KeyCode.Escape))
            {
                if (Modal.IsOpen) Modal.Close();
                else if (!Nav.CurrentHandlesBack()) Nav.Back();
            }
        }
    }
}
