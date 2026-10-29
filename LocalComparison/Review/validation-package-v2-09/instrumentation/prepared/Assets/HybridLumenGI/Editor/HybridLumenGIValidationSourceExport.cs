#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.PackageManager;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using Object = UnityEngine.Object;
using Data = HybridLumenGI.HybridLumenGIValidationSourceData;
using State = HybridLumenGI.HybridLumenGIValidationSourceState;

namespace HybridLumenGI.Editor
{
    /// <summary>Exports the live scene and byte-bearing asset dependencies without saving or altering the scene.</summary>
    [InitializeOnLoad]
    public static class HybridLumenGIValidationSourceExport
    {
        static HybridLumenGIValidationSourceExport() { State.EditorExporter = Export; }

        public static State.FileLink Export(Scene scene, Camera camera, HybridLumenGIRendererFeature feature, string runDirectory)
        {
            if (!scene.IsValid() || !scene.isLoaded || !camera || camera.gameObject.scene != scene)
                throw new InvalidOperationException("Export requires the capture camera's actual loaded scene.");
            string directory = Path.GetFullPath(runDirectory); Directory.CreateDirectory(directory);
            var selected = new SortedDictionary<string, SortedSet<string>>(StringComparer.Ordinal);
            var provenance = new SortedDictionary<string, SortedSet<string>>(StringComparer.Ordinal);
            var objects = new HashSet<Object>();
            var unsupported = new SortedSet<string>(StringComparer.Ordinal);
            var exclusions = new SortedDictionary<string, Data.ArchiveExclusion>(StringComparer.Ordinal);
            Action<Object, string> origin = (value, role) =>
            {
                if (!value) return;
                objects.Add(value); string path = AssetDatabase.GetAssetPath(value);
                if (!string.IsNullOrEmpty(path)) Select(provenance, path, role);
            };
            Action<Object, string> observe = (value, role) =>
            {
                origin(value, role);
                if (!(value is Mesh || value is Material || value is Texture || value is Shader || value is LightProbes)) return;
                string path = AssetDatabase.GetAssetPath(value);
                if (!string.IsNullOrEmpty(path)) Select(selected, path, role);
            };
            var snapshot = Data.Capture(scene, camera, directory, observe, feature);
            foreach (string reason in snapshot.unsupported) unsupported.Add(reason);
            origin(feature, "gi-renderer-feature-asset-provenance");
            origin(GraphicsSettings.currentRenderPipeline, "mixed-render-pipeline-asset-provenance");

            // Include live references, not only the last saved scene file. This covers dirty materials,
            // slot property-block textures (observed above), mesh/chart assets, and baked-source references.
            for (int index = 0; index < SceneManager.sceneCount; ++index)
            {
                var loaded = SceneManager.GetSceneAt(index); if (!loaded.isLoaded) continue;
                // Capture() includes all loaded scenes. The active-scene properties
                // would miss another scene's baked inputs or read an unrelated one.
                var lightingData = Lightmapping.GetLightingDataAssetForScene(loaded);
                origin(lightingData, "unity-baked-lighting-data");
                origin(Lightmapping.GetLightingSettingsForScene(loaded), "unity-lighting-settings");
                if (lightingData) unsupported.Add("lighting-data-asset-decoding-not-implemented");
                if (!string.IsNullOrEmpty(loaded.path)) Select(provenance, loaded.path, "source-export-origin-saved-scene");
                foreach (var root in loaded.GetRootGameObjects())
                    foreach (var component in root.GetComponentsInChildren<Component>(true))
                        if (component) CollectObjectReferences(component, origin);
            }
            foreach (var value in objects.ToArray()) CollectObjectReferences(value, origin);

            string[] roots = selected.Keys.Where(p => p.StartsWith("Assets/", StringComparison.Ordinal) || p.StartsWith("Packages/", StringComparison.Ordinal)).ToArray();
            foreach (string path in AssetDatabase.GetDependencies(roots, true)) Select(selected, path, "transitive-asset-dependency");
            string[] originRoots = provenance.Keys.Where(p => p.StartsWith("Assets/", StringComparison.Ordinal) || p.StartsWith("Packages/", StringComparison.Ordinal)).ToArray();
            foreach (string path in AssetDatabase.GetDependencies(originRoots, true)) Select(provenance, path, "source-export-origin-transitive-dependency");
            foreach (string path in new[] { "ProjectSettings/ProjectSettings.asset", "ProjectSettings/GraphicsSettings.asset",
                "ProjectSettings/QualitySettings.asset", "ProjectSettings/EditorBuildSettings.asset", "Packages/manifest.json", "Packages/packages-lock.json" })
                Select(provenance, path, "source-export-origin-project-configuration");
            Select(selected, "Packages/com.unity.render-pipelines.universal/Runtime/UniversalAdditionalLightData.cs", "urp-missing-light-component-defaults-source");

            // AssetDatabase shader dependencies vary by importer version. Archive the installed URP/Core
            // shader/library source set as a bounded explicit supplement to their dependency selection.
            foreach (string path in AssetDatabase.GetAllAssetPaths())
            {
                if (!(path.StartsWith("Packages/com.unity.render-pipelines.universal/", StringComparison.Ordinal) ||
                    path.StartsWith("Packages/com.unity.render-pipelines.core/", StringComparison.Ordinal) ||
                    path.StartsWith("Packages/com.unity.render-pipelines.universal-config/", StringComparison.Ordinal))) continue;
                string extension = Path.GetExtension(path);
                if (extension == ".hlsl" || extension == ".shader" || extension == ".compute" || extension == ".cs" || path.EndsWith("/package.json", StringComparison.Ordinal))
                    Select(selected, path, "installed-render-pipeline-shader-source");
            }
            // A material/mesh may be embedded in a scene or renderer asset. Its live typed values
            // remain physical inputs, but the mixed serialized container must not bind product code.
            foreach (string path in selected.Keys.ToArray())
            {
                if (!IsPhysicalFile(path, out bool mixed))
                {
                    foreach (string role in selected[path]) Select(provenance, path, "source-export-origin-" + role);
                    selected.Remove(path);
                    if (mixed) unsupported.Add("mixed-physical-asset-separation-unavailable:" + path);
                }
            }
            foreach (string path in selected.Keys.ToArray())
            {
                if (AssetDatabase.IsValidFolder(path))
                {
                    exclusions[path] = new Data.ArchiveExclusion { path = path, reason = "AssetDatabase confirms a directory, not a byte-bearing asset." };
                    selected.Remove(path); continue;
                }
                string resolved = ResolveProjectAsset(path);
                if (!File.Exists(resolved))
                {
                    bool knownBuiltInMesh = (path == "Library/unity default resources" || path == "Resources/unity_builtin_extra") &&
                        objects.Any(o => o is Mesh && AssetDatabase.GetAssetPath(o) == path);
                    string reason = knownBuiltInMesh
                        ? "Built-in mesh: actual readable vertex, normal, tangent, color, UV and submesh arrays are in the live snapshot. Unreadable instances are explicitly unsupported."
                        : "No byte-bearing file could be resolved; source interpretation is unsupported.";
                    exclusions[path] = new Data.ArchiveExclusion { path = path, reason = reason };
                    if (!knownBuiltInMesh) unsupported.Add("unarchivable-source-asset:" + path);
                    selected.Remove(path); continue;
                }
                if (File.Exists(resolved + ".meta")) Select(selected, path + ".meta", "asset-guid-and-importer-metadata");
            }

            var archived = new Dictionary<string, Data.Asset>(StringComparer.Ordinal);
            var originArtifacts = new Dictionary<string, Data.ProvenanceArtifact>(StringComparer.Ordinal);
            foreach (var asset in snapshot.assets) Merge(archived, asset);
            var originalBytes = new List<Tuple<string, string>>();
            foreach (var row in selected)
            {
                string resolved = ResolveProjectAsset(row.Key);
                if (!File.Exists(resolved)) throw new FileNotFoundException("Selected source dependency disappeared.", row.Key);
                byte[] bytes = File.ReadAllBytes(resolved);
                var asset = Data.ArchiveBytes(directory, bytes, row.Value.First());
                asset.originalPaths = new[] { row.Key }; asset.roles = row.Value.ToArray(); Merge(archived, asset);
                originalBytes.Add(Tuple.Create(resolved, asset.sha256));
            }
            foreach (string path in provenance.Keys.ToArray())
            {
                string resolved = ResolveProjectAsset(path);
                if (AssetDatabase.IsValidFolder(path) || !File.Exists(resolved)) continue;
                if (File.Exists(resolved + ".meta")) Select(provenance, path + ".meta", "source-export-origin-metadata");
            }
            foreach (var row in provenance)
            {
                string resolved = ResolveProjectAsset(row.Key);
                if (AssetDatabase.IsValidFolder(row.Key) || !File.Exists(resolved)) continue;
                byte[] bytes = File.ReadAllBytes(resolved);
                var asset = Data.ArchiveBytes(directory, bytes, "source-export-origin");
                // A provenance entry never adds roles or paths to the physical source asset record.
                originArtifacts[asset.path] = new Data.ProvenanceArtifact { file = asset.path, sha256 = asset.sha256,
                    role = "source-export-origin:" + row.Key };
                originalBytes.Add(Tuple.Create(resolved, asset.sha256));
            }
            // Re-read original files after copying. A package never certifies a mid-export edit as one snapshot.
            foreach (var row in originalBytes)
                if (!File.Exists(row.Item1) || Data.Hash(File.ReadAllBytes(row.Item1)) != row.Item2)
                    throw new IOException("Source bytes changed during export: " + row.Item1);
            var after = Data.Capture(scene, camera, directory, feature: feature);
            if (JsonUtility.ToJson(snapshot) != JsonUtility.ToJson(after))
                throw new InvalidOperationException("Live physical inputs changed during source export.");

            var document = new Data.SourceDocument { sceneId = Data.SceneKey(scene), geometry = snapshot.geometry, materials = snapshot.materials,
                lights = snapshot.lights, environment = snapshot.environment, rendering = snapshot.rendering,
                assets = archived.Values.OrderBy(a => a.path, StringComparer.Ordinal).ToArray(), unsupported = unsupported.ToArray(),
                archiveExclusions = exclusions.Values.ToArray() };
            State.FileLink result = Data.WriteJson(directory, "source.json", document);
            Data.WriteJson(directory, "source-provenance.json", new Data.ProvenanceDocument {
                artifacts = originArtifacts.Values.OrderBy(x => x.file, StringComparer.Ordinal).ToArray() });
            Data.VerifyProvenance(directory);
            Data.VerifyPackage(directory, result); return result;
        }

        static bool IsPhysicalFile(string path, out bool mixed)
        {
            mixed = false;
            if (path.EndsWith(".unity", StringComparison.Ordinal)) return false;
            if (path.StartsWith("Packages/com.unity.render-pipelines.", StringComparison.Ordinal)) return true;
            string extension = Path.GetExtension(path);
            if (extension == ".cs" || extension == ".dll" || extension == ".asmdef" || extension == ".asmref") return false;
            if ((extension == ".shader" || extension == ".hlsl" || extension == ".compute") &&
                (path.Contains("/HybridLumenGI/") || path.Contains("/ComparisonHarness/"))) return false;
            if (extension != ".asset" && extension != ".prefab") return true;
            var assets = AssetDatabase.LoadAllAssetsAtPath(path);
            bool renderConfiguration = assets.Any(x => x is RenderPipelineAsset || x is UnityEngine.Rendering.Universal.ScriptableRendererData || x is UnityEngine.Rendering.Universal.ScriptableRendererFeature);
            bool approximation = assets.Any(x => x is HybridLumenGIMeshSdf || x is HybridLumenGISurfaceCharts);
            if (renderConfiguration || approximation) return false;
            mixed = assets.Any(x => x && !(x is Mesh || x is Material || x is Texture || x is Shader || x is LightProbes));
            return !mixed;
        }

        static void CollectObjectReferences(Object value, Action<Object, string> observe)
        {
            if (!value) return;
            var serialized = new SerializedObject(value); var property = serialized.GetIterator();
            while (property.Next(true))
            {
                // The validation target is an output, not a sampled physical texture source.
                if (value is Camera && property.propertyPath == "m_TargetTexture") continue;
                if (property.propertyType == SerializedPropertyType.ObjectReference && property.objectReferenceValue)
                    observe(property.objectReferenceValue, "serialized-live-object-reference");
            }
        }
        static void Select(SortedDictionary<string, SortedSet<string>> selected, string path, string role)
        {
            path = path.Replace('\\', '/');
            if (!selected.TryGetValue(path, out var roles)) selected[path] = roles = new SortedSet<string>(StringComparer.Ordinal);
            roles.Add(role);
        }
        static void Merge(Dictionary<string, Data.Asset> assets, Data.Asset next)
        {
            if (!assets.TryGetValue(next.path, out var current)) { assets.Add(next.path, next); return; }
            if (current.sha256 != next.sha256 || current.bytes != next.bytes) throw new InvalidDataException("Content-addressed asset collision.");
            current.originalPaths = current.originalPaths.Concat(next.originalPaths).Distinct(StringComparer.Ordinal).OrderBy(x => x, StringComparer.Ordinal).ToArray();
            current.roles = current.roles.Concat(next.roles).Distinct(StringComparer.Ordinal).OrderBy(x => x, StringComparer.Ordinal).ToArray();
            current.role = current.roles[0];
        }
        static string ResolveProjectAsset(string path)
        {
            string project = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
            if (path == "Packages/manifest.json" || path == "Packages/packages-lock.json") return Path.Combine(project, path);
            if (path.StartsWith("Packages/", StringComparison.Ordinal))
            {
                string assetPath = path.EndsWith(".meta", StringComparison.Ordinal) ? path.Substring(0, path.Length - 5) : path;
                var package = UnityEditor.PackageManager.PackageInfo.FindForAssetPath(assetPath);
                if (package != null)
                {
                    string prefix = "Packages/" + package.name + "/";
                    if (path.StartsWith(prefix, StringComparison.Ordinal)) return Path.Combine(package.resolvedPath, path.Substring(prefix.Length));
                }
            }
            return Path.GetFullPath(Path.Combine(project, path));
        }
    }
}
#endif
