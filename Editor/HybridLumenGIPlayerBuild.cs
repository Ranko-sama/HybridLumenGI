using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace HybridLumenGI.Editor
{
    /// <summary>Batch entry for ordinary saved scenes. Uses the caller's project settings and scene order.</summary>
    public static class HybridLumenGIPlayerBuild
    {
        [Serializable] private sealed class Result
        {
            public string status = "Failed", unity, target = "StandaloneWindows64", configuration = "Release";
            public string output, actualOptions, error;
            public string[] scenes;
            public int errors, warnings;
            public ulong bytes;
        }

        /// <summary>Unity -executeMethod HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build</summary>
        public static void Build()
        {
            var result = new Result { unity = Application.unityVersion };
            string reportPath = null;
            try
            {
                string[] args = Environment.GetCommandLineArgs();
                var scenes = new List<string>(); string directory = null;
                for (int i = 0; i < args.Length; i++)
                {
                    if (args[i] != "-hlgiScene" && args[i] != "-hlgiOutput") continue;
                    string key = args[i];
                    Require(i + 1 < args.Length && !args[i + 1].StartsWith("-", StringComparison.Ordinal), "Missing value for " + key);
                    string value = args[++i];
                    if (key == "-hlgiScene") scenes.Add(value.Replace('\\', '/'));
                    else { Require(directory == null, "Pass -hlgiOutput once."); directory = value; }
                }
                Require(scenes.Count > 0 && scenes.Distinct(StringComparer.Ordinal).Count() == scenes.Count,
                    "Pass one or more distinct -hlgiScene Assets/path.unity arguments in build order.");
                foreach (string scene in scenes)
                    Require(scene.StartsWith("Assets/", StringComparison.Ordinal) && !scene.Split('/').Any(part => part == ".." || part == ".") &&
                        AssetDatabase.LoadAssetAtPath<SceneAsset>(scene) != null, "Saved project scene required: " + scene);
                Require(!string.IsNullOrWhiteSpace(directory), "Pass a new -hlgiOutput directory.");
                directory = Path.GetFullPath(directory);
                Require(!Directory.Exists(directory) && !File.Exists(directory), "Output already exists; keep it and choose a new directory.");
                string project = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
                foreach (string imported in new[] { "Assets", "Packages", "Library", "ProjectSettings" })
                {
                    string forbidden = Path.Combine(project, imported);
                    Require(!directory.Equals(forbidden, StringComparison.OrdinalIgnoreCase) &&
                        !directory.StartsWith(forbidden + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase),
                        "Keep Player output outside imported assets, packages and project state.");
                }
                Require(!EditorApplication.isPlayingOrWillChangePlaymode, "Build outside Play mode.");
                Require(EditorUserBuildSettings.activeBuildTarget == BuildTarget.StandaloneWindows64,
                    "Select Windows x64 or launch Unity with -buildTarget StandaloneWindows64.");
                Require(PlayerSettings.GetScriptingBackend(NamedBuildTarget.Standalone) == ScriptingImplementation.Mono2x,
                    "The current supported local build uses Mono. Configure it in Player Settings.");
                Require(PlayerSettings.colorSpace == ColorSpace.Linear && GraphicsSettings.currentRenderPipeline is UniversalRenderPipelineAsset,
                    "Configure Linear color and the project's URP pipeline before building.");
                Require(!PlayerSettings.GetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64) &&
                    PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64).SequenceEqual(new[] { GraphicsDeviceType.Direct3D12 }),
                    "Configure Direct3D12 as the explicit Windows graphics API before building.");
                result.scenes = scenes.ToArray();
                result.output = Path.Combine(directory, "HybridLumenGIPlayer.exe");
                Directory.CreateDirectory(directory);
                reportPath = Path.Combine(directory, "build-result.json");
                BuildReport report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
                {
                    scenes = result.scenes, locationPathName = result.output,
                    target = BuildTarget.StandaloneWindows64, options = BuildOptions.None
                });
                result.actualOptions = report.summary.options.ToString();
                result.errors = (int)report.summary.totalErrors; result.warnings = (int)report.summary.totalWarnings;
                result.bytes = report.summary.totalSize;
                Require(report.summary.result == BuildResult.Succeeded && report.summary.totalErrors == 0,
                    "Player build did not succeed: " + report.summary.result);
                result.status = "Succeeded";
            }
            catch (Exception error)
            {
                result.error = error.Message;
                // A thrown executeMethod failure makes batch Unity return failure to its caller.
                throw;
            }
            finally
            {
                string json = JsonUtility.ToJson(result, true);
                if (reportPath != null) File.WriteAllText(reportPath, json);
                Debug.Log("HLGI_PLAYER_BUILD_RESULT " + JsonUtility.ToJson(result));
                // Preserve partial output on failure. Do not modify or replace the caller's scenes/settings.
            }
        }

        private static void Require(bool condition, string message)
        { if (!condition) throw new BuildFailedException(message); }
    }
}
