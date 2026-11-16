using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Fenerbahce.EditorTools
{
    /// <summary>
    /// Komut satırı / CI Android APK derlemesi (GameCI unity-builder `buildMethod`).
    /// Sahne ve PlayerSettings kodla üretilir: elle yazılmış sahne/ayar YAML'ı yoktur.
    /// DURUM: Unity bu geliştirme ortamında bulunmadığı için bu betik DERLENMEDİ ve ÇALIŞTIRILMADI;
    /// ilk doğrulama GitHub Actions'taki Unity derlemesidir (bkz. docs/ANDROID_APK_WORKFLOW.md).
    /// </summary>
    public static class BuildScript
    {
        public const string ScenePath = "Assets/_Game/Scenes/Boot.unity";
        public const string ProductName = "Kanarya Futbol";           // çalışma adı, kesin ürün adı değildir
        public const string PackageId = "com.kanaryafutbol.game";     // varsayım; yayın öncesi sabitlenecek (DECISIONS D-004)

        [MenuItem("Kanarya/Sahneyi ve ayarları hazırla")]
        public static void PrepareMenu() { Prepare(); Debug.Log("[Build] Sahne ve ayarlar hazır."); }

        [MenuItem("Kanarya/Android APK derle")]
        public static void BuildAndroidMenu() { BuildAndroid(); }

        /// <summary>-executeMethod Fenerbahce.EditorTools.BuildScript.BuildAndroid</summary>
        public static void BuildAndroid()
        {
            try
            {
                Prepare();
                string output = ResolveOutputPath();
                Directory.CreateDirectory(Path.GetDirectoryName(output) ?? ".");

                var options = new BuildPlayerOptions
                {
                    scenes = new[] { ScenePath },
                    locationPathName = output,
                    target = BuildTarget.Android,
                    targetGroup = BuildTargetGroup.Android,
                    options = Environment.GetEnvironmentVariable("FB_DEV_BUILD") == "1" ? BuildOptions.Development : BuildOptions.None,
                };

                Debug.Log("[Build] Başlıyor → " + output);
                BuildReport report = BuildPipeline.BuildPlayer(options);
                var s = report.summary;
                Debug.Log("[Build] Sonuç=" + s.result + " boyut=" + s.totalSize + " bayt, süre=" + s.totalTime + ", hata=" + s.totalErrors + ", uyarı=" + s.totalWarnings);
                if (s.result != BuildResult.Succeeded) { EditorApplication.Exit(1); return; }
                if (!File.Exists(output)) { Debug.LogError("[Build] APK dosyası bulunamadı: " + output); EditorApplication.Exit(2); return; }
                Debug.Log("[Build] APK hazır: " + output);
                EditorApplication.Exit(0);
            }
            catch (Exception e)
            {
                Debug.LogError("[Build] İstisna: " + e);
                EditorApplication.Exit(3);
            }
        }

        /// <summary>Sahne + Player ayarları. Tekrar çağrılması güvenlidir (idempotent).</summary>
        public static void Prepare()
        {
            EnsureScene();
            ConfigurePlayer();
            AssetDatabase.SaveAssets();
        }

        static void EnsureScene()
        {
            if (!File.Exists(ScenePath))
            {
                var dir = Path.GetDirectoryName(ScenePath);
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                if (!EditorSceneManager.SaveScene(scene, ScenePath)) throw new Exception("Sahne kaydedilemedi: " + ScenePath);
                AssetDatabase.Refresh();
                Debug.Log("[Build] Boş açılış sahnesi üretildi: " + ScenePath + " (oyun GameApp ile kendini kurar)");
            }
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        }

        static void ConfigurePlayer()
        {
            PlayerSettings.companyName = "KanaryaFutbol";
            PlayerSettings.productName = ProductName;
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, PackageId);
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel24;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3 });
            PlayerSettings.SetManagedStrippingLevel(BuildTargetGroup.Android, ManagedStrippingLevel.Low);
            EditorUserBuildSettings.buildAppBundle = false;               // APK (AAB değil)
            EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;

            // CI'nin gönderdiği sürüm bilgileri (GameCI: -buildVersion / -androidVersionCode)
            string version = Arg("-buildVersion");
            if (!string.IsNullOrEmpty(version)) PlayerSettings.bundleVersion = version;
            int code;
            if (int.TryParse(Arg("-androidVersionCode"), out code) && code > 0) PlayerSettings.Android.bundleVersionCode = code;
        }

        static string ResolveOutputPath()
        {
            string p = Arg("-customBuildPath");
            if (!string.IsNullOrEmpty(p))
            {
                // GameCI klasör verebilir (…/Android) veya dosya (…/Android/Ad.apk)
                if (!p.EndsWith(".apk", StringComparison.OrdinalIgnoreCase)) p = Path.Combine(p, "KanaryaFutbol.apk");
                return p;
            }
            return Path.Combine("Builds", "Android", "KanaryaFutbol.apk");
        }

        static string Arg(string name)
        {
            var a = Environment.GetCommandLineArgs();
            for (int i = 0; i < a.Length - 1; i++) if (a[i] == name) return a[i + 1];
            return null;
        }
    }
}
