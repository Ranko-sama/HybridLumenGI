using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace HybridLumenGI.Editor
{
    /// <summary>Creates a separate test asset without replacing the current scene.</summary>
    public static class HybridLumenGIValidationScene
    {
        [MenuItem("Tools/Hybrid Lumen GI/Create Validation Scene Assets")]
        private static void CreateScene()
        {
            try { CreateSceneAssets(); }
            catch (Exception error) { Debug.LogException(error); }
        }

        /// <summary>Creates the original validation scene in a fresh Run. Null means cancellation.</summary>
        public static string CreateSceneAssets(string rootPath = "Assets/HybridLumenGIValidation")
        {
            Shader lit = Shader.Find("Universal Render Pipeline/Lit");
            if (lit == null) throw new InvalidOperationException("Hybrid Lumen GI requires the URP Lit shader to create the validation scene.");
            bool restoreEmptyScene = false;
            for (int i = 0; i < SceneManager.sceneCount; i++)
            {
                Scene loaded = SceneManager.GetSceneAt(i);
                if (!string.IsNullOrEmpty(loaded.path)) continue;
                if (SceneManager.sceneCount != 1 || loaded.isDirty || loaded.rootCount != 0)
                    throw new InvalidOperationException("Save the unnamed scene before generating validation assets.");
                restoreEmptyScene = true;
            }

            if (string.IsNullOrEmpty(rootPath) || !rootPath.StartsWith("Assets/", StringComparison.Ordinal) || rootPath.IndexOf('\\') >= 0)
                throw new ArgumentException("Validation root must be a project-relative Assets/... folder using forward slashes.", nameof(rootPath));
            foreach (string part in rootPath.Split('/'))
                if (part.Length == 0 || part == "." || part == ".." || part.IndexOf(':') >= 0)
                    throw new ArgumentException("Validation root cannot contain empty, relative or drive path segments.", nameof(rootPath));
            int separator = rootPath.LastIndexOf('/'); string parent = rootPath.Substring(0, separator);
            if (!AssetDatabase.IsValidFolder(parent)) throw new ArgumentException("Validation root's parent must already exist: " + parent, nameof(rootPath));
            if (!AssetDatabase.IsValidFolder(rootPath))
            {
                if (string.IsNullOrEmpty(AssetDatabase.CreateFolder(parent, rootPath.Substring(separator + 1))) || !AssetDatabase.IsValidFolder(rootPath))
                    throw new InvalidOperationException("Could not create validation root " + rootPath);
            }
            string folder = AssetDatabase.GenerateUniqueAssetPath(rootPath + "/Run");
            if (string.IsNullOrEmpty(AssetDatabase.CreateFolder(rootPath, folder.Substring(rootPath.Length + 1))) || !AssetDatabase.IsValidFolder(folder))
                throw new InvalidOperationException("Could not create unique validation Run " + folder);
            Scene previous = SceneManager.GetActiveScene();
            Scene scene = default;
            bool complete = false;
            try
            {
                scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, restoreEmptyScene ? NewSceneMode.Single : NewSceneMode.Additive);
                SceneManager.SetActiveScene(scene);
                RenderSettings.ambientMode = AmbientMode.Flat;
                RenderSettings.ambientLight = Color.black;
                RenderSettings.ambientIntensity = 0f;
                RenderSettings.reflectionIntensity = 0f;
                RenderSettings.skybox = null;
                RenderSettings.fog = false;
                var root = new GameObject("Hybrid Lumen GI Validation");
                SceneManager.MoveGameObjectToScene(root, scene);
                Material white = MaterialAsset(lit, folder, "White", new Color(0.75f, 0.75f, 0.75f));
                Material red = MaterialAsset(lit, folder, "Red", new Color(0.75f, 0.04f, 0.03f));
                Material green = MaterialAsset(lit, folder, "Green", new Color(0.03f, 0.6f, 0.06f));
                Material metal = MaterialAsset(lit, folder, "Metal", new Color(0.75f, 0.75f, 0.75f), 1f);
                Material black = MaterialAsset(lit, folder, "Black", Color.black);
                Material emitter = MaterialAsset(lit, folder, "Emitter", Color.white);
                emitter.EnableKeyword("_EMISSION");
                emitter.SetColor("_EmissionColor", new Color(5f, 3f, 1.5f));
                // URP's material validation derives _EMISSION from AnyEmissive.
                // None silently disables it on import, even after EnableKeyword.
                // This scene has no baked lighting; retain the realtime emission
                // flag so the intended emitter actually reaches Lit and GI.
                emitter.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
                EditorUtility.SetDirty(emitter);

                Box(root.transform, "Floor", new Vector3(0f, -0.15f, 0f), new Vector3(8f, 0.3f, 8f), white);
                Box(root.transform, "Red wall", new Vector3(-4f, 2f, 0f), new Vector3(0.3f, 4f, 8f), red);
                Box(root.transform, "Green wall", new Vector3(4f, 2f, 0f), new Vector3(0.3f, 4f, 8f), green);
                Box(root.transform, "Back wall", new Vector3(0f, 2f, 4f), new Vector3(8f, 4f, 0.3f), white);
                Box(root.transform, "Roof back half", new Vector3(0f, 4f, 2f), new Vector3(8f, 0.3f, 4f), white);
                Box(root.transform, "White receiver", new Vector3(-2.2f, 0.65f, 1.3f), new Vector3(1.2f, 1.3f, 1.2f), white);
                Box(root.transform, "Metal zero diffuse receiver", new Vector3(0f, 0.65f, 1.3f), new Vector3(1.2f, 1.3f, 1.2f), metal);
                Box(root.transform, "Black zero diffuse receiver", new Vector3(2.2f, 0.65f, 1.3f), new Vector3(1.2f, 1.3f, 1.2f), black);
                Box(root.transform, "Emissive source", new Vector3(-3.75f, 1.8f, 2.5f), new Vector3(0.15f, 1f, 1f), emitter);
                GameObject door = Box(root.transform, "Moving occluder", new Vector3(-1.1f, 1.4f, -0.8f), new Vector3(1.8f, 2.8f, 0.25f), white);
                var motion = door.AddComponent<HybridLumenGIValidationMotion>();

                Box(root.transform, "Thin-wall floor", new Vector3(8f, -0.15f, 0f), new Vector3(6f, 0.3f, 6f), white);
                Box(root.transform, "Thin wall 3cm", new Vector3(8f, 1.5f, 0.5f), new Vector3(6f, 3f, 0.03f), white);
                Box(root.transform, "Thin-wall receiver", new Vector3(8f, 0.6f, -0.5f), new Vector3(1f, 1.2f, 1f), white);

                // Sealed ordinary reflective room: black materials would hide leaks.
                Box(root.transform, "Sealed room floor", new Vector3(16f, -0.15f, 0f), new Vector3(8.3f, 0.3f, 8.3f), white);
                Box(root.transform, "Sealed room roof", new Vector3(16f, 4.15f, 0f), new Vector3(8.3f, 0.3f, 8.3f), white);
                Box(root.transform, "Sealed room left", new Vector3(12f, 2f, 0f), new Vector3(0.3f, 4.3f, 8.3f), white);
                Box(root.transform, "Sealed room right", new Vector3(20f, 2f, 0f), new Vector3(0.3f, 4.3f, 8.3f), white);
                Box(root.transform, "Sealed room front", new Vector3(16f, 2f, -4f), new Vector3(8.3f, 4.3f, 0.3f), white);
                Box(root.transform, "Sealed room back", new Vector3(16f, 2f, 4f), new Vector3(8.3f, 4.3f, 0.3f), white);
                Box(root.transform, "Sealed room gray receiver", new Vector3(16f, 0.7f, 1f), new Vector3(1.4f, 1.4f, 1.4f), white);

                Light sun = LightObject(root.transform, "Directional", LightType.Directional, new Vector3(0, 5, -2), Color.white, 1.2f);
                sun.transform.rotation = Quaternion.Euler(50f, -25f, 0f);
                Light point = LightObject(root.transform, "Point (toggle for invalidation)", LightType.Point, new Vector3(-2.4f, 2.8f, 2f), new Color(1f, 0.75f, 0.5f), 7f);
                point.range = 8f;
                Light spot = LightObject(root.transform, "Spot (toggle for invalidation)", LightType.Spot, new Vector3(2.3f, 3.5f, 0.5f), new Color(0.5f, 0.7f, 1f), 12f);
                spot.range = 9f;
                spot.spotAngle = 55f;
                spot.innerSpotAngle = 35f;
                spot.transform.rotation = Quaternion.Euler(80f, 0f, 0f);
                Light thinLight = LightObject(root.transform, "Behind thin wall", LightType.Point, new Vector3(8f, 2f, 2f), Color.white, 12f);
                thinLight.range = 5f;
                Light outsideLight = LightObject(root.transform, "Outside sealed room only", LightType.Point, new Vector3(10.7f, 2f, 0f), Color.white, 20f);
                outsideLight.range = 10f;

                var cameraObject = new GameObject("Validation Camera");
                cameraObject.transform.SetParent(root.transform, false);
                Camera camera = cameraObject.AddComponent<Camera>();
                cameraObject.tag = "MainCamera";
                camera.transform.position = new Vector3(0f, 2.5f, -7.5f);
                camera.transform.rotation = Quaternion.LookRotation(new Vector3(0f, 1.6f, 1.2f) - camera.transform.position);
                camera.allowHDR = true;
                camera.allowMSAA = false;
                camera.nearClipPlane = 0.1f;
                camera.farClipPlane = 100f;
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = Color.black;
                UniversalAdditionalCameraData cameraData = camera.GetUniversalAdditionalCameraData();
                cameraData.requiresColorTexture = true;
                cameraData.requiresDepthTexture = true;
                cameraData.renderPostProcessing = false;
                Transform colorView = View(root.transform, "Color view", camera.transform.position, new Vector3(0f, 1.6f, 1.2f));
                Transform thinView = View(root.transform, "Thin-wall view", new Vector3(8f, 1.7f, -3f), new Vector3(8f, 1.4f, 0.5f));
                Transform blackView = View(root.transform, "Sealed-room view", new Vector3(16f, 1.7f, -2.5f), new Vector3(16f, 1.3f, 1f));
                var features = Resources.FindObjectsOfTypeAll<HybridLumenGIRendererFeature>();
                HybridLumenGIRendererFeature selectedFeature = features.Length == 1 ? features[0] : null;
                root.AddComponent<HybridLumenGIValidationSequence>().Configure(camera, motion,
                    new[] { sun, point, spot, thinLight, outsideLight }, colorView, thinView, blackView, selectedFeature);
                int bakedMeshes = BakeAndBind(root, folder);
                string scenePath = folder + "/Validation.unity";
                EditorSceneManager.MarkSceneDirty(scene);
                if (!EditorSceneManager.SaveScene(scene, scenePath)) throw new InvalidOperationException("Could not save " + scenePath);
                AssetDatabase.SaveAssets();
                Debug.Log("Created " + scenePath + ". Open this scene alone; assign the camera's actual HybridLumenGIRendererFeature on Validation Sequence. " +
                    "Baked and bound 32-cubed Mesh Distance Field / Surface Charts assets for " + bakedMeshes + " unique source mesh(es). " +
                    "Configure mode/backend in the renderer asset, then enter Play for 720 logical frames. " +
                    "See Documentation/ValidationSequence.md: no reference images or Unity acceptance results are supplied.");
                Selection.activeObject = AssetDatabase.LoadAssetAtPath<SceneAsset>(scenePath);
                complete = true;
                return scenePath;
            }
            catch (OperationCanceledException)
            {
                Debug.Log("Hybrid Lumen GI validation scene bake cancelled; this new Run is discarded.");
                return null;
            }
            finally
            {
                EditorUtility.ClearProgressBar();
                try
                {
                    if (restoreEmptyScene) EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                    else if (previous.IsValid() && previous.isLoaded) SceneManager.SetActiveScene(previous);
                }
                finally
                {
                    try { if (scene.IsValid() && scene.isLoaded) EditorSceneManager.CloseScene(scene, true); }
                    finally
                    {
                        // This path is the fresh GenerateUniqueAssetPath folder created
                        // above. Existing Runs and the user's previous scene are untouched.
                        if (!complete && AssetDatabase.IsValidFolder(folder) && !AssetDatabase.DeleteAsset(folder))
                            Debug.LogError("Could not remove failed validation assets at " + folder + "; generation did not complete.");
                    }
                }
            }
        }

        private sealed class BakedMesh
        {
            internal HybridLumenGIMeshSdf sdf;
            internal HybridLumenGISurfaceCharts charts;
        }

        private static int BakeAndBind(GameObject root, string folder)
        {
            var proxies = root.GetComponentsInChildren<HybridLumenGIProxy>(true);
            var baked = new Dictionary<Mesh, BakedMesh>();
            if (proxies.Length == 0) throw new InvalidOperationException("The generated scene has no mesh proxies.");
            foreach (var proxy in proxies)
            {
                Mesh mesh = proxy.SourceMesh;
                if (!(proxy.SourceRenderer is MeshRenderer) || mesh == null || !mesh.isReadable)
                    throw new InvalidOperationException("Generated validation proxy needs a readable static mesh: " + proxy.name);
                if (!baked.ContainsKey(mesh)) baked.Add(mesh, BakeMesh(mesh, folder, baked.Count));
            }
            // No proxy receives half of a pair, nor any binding before every source
            // bake succeeds. The scene is saved only after the complete binding pass.
            AssetDatabase.SaveAssets();
            foreach (var proxy in proxies)
            {
                Mesh mesh = proxy.SourceMesh; BakedMesh pair = baked[mesh];
                if (!pair.sdf.IsValid || !pair.sdf.MatchesSource(mesh) || !pair.charts.IsValid || !pair.charts.MatchesSource(mesh))
                    throw new InvalidOperationException("Generated bake no longer matches " + mesh.name);
                proxy.SetMeshSdf(pair.sdf); proxy.SetSurfaceCharts(pair.charts);
                if (proxy.MeshSdf != pair.sdf || proxy.SurfaceCharts != pair.charts)
                    throw new InvalidOperationException("Generated proxy did not retain both bake bindings: " + proxy.name);
                EditorUtility.SetDirty(proxy);
            }
            return baked.Count;
        }

        private static BakedMesh BakeMesh(Mesh mesh, string folder, int index)
        {
            const int resolution = 32;
            Texture3D texture = null; Mesh capture = null;
            HybridLumenGIMeshSdf sdf = null; HybridLumenGISurfaceCharts chartsAsset = null;
            try
            {
                string geometry = HybridLumenGIMeshSdf.ComputeGeometryFingerprint(mesh);
                float[] distances = HybridLumenGIMeshSdfBaker.Bake(mesh, resolution,
                    (done, total) => ContinueBake("Hybrid GI: validation SDF", mesh.name, done, total), out Bounds bounds, out bool closed);
                if (distances == null) throw new OperationCanceledException();
                if (!closed) throw new InvalidOperationException("Generated validation box mesh must be watertight: " + mesh.name);
                var charts = HybridLumenGISurfaceCharts.Bake(mesh, new HybridLumenGISurfaceCharts.BakeSettings(), out var report,
                    (done, total) => ContinueBake("Hybrid GI: validation surface charts", mesh.name, done, total));
                if (charts.Length == 0 || report.nonTriangleSubmeshes != 0)
                    throw new InvalidOperationException("Generated mesh has no complete triangle chart surface: " + mesh.name);
                capture = HybridLumenGISurfaceCharts.CreateCaptureMesh(mesh, charts);
                texture = new Texture3D(resolution, resolution, resolution, TextureFormat.RFloat, false)
                { name = mesh.name + "_Distance", wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
                texture.SetPixelData(distances, 0); texture.Apply(false, false);
                sdf = ScriptableObject.CreateInstance<HybridLumenGIMeshSdf>();
                sdf.SetBakedData(mesh, texture, bounds, resolution, closed, geometry);
                chartsAsset = ScriptableObject.CreateInstance<HybridLumenGISurfaceCharts>();
                chartsAsset.SetBakedData(mesh, capture, charts);
                string prefix = folder + "/Mesh-" + index.ToString("D3");
                AssetDatabase.CreateAsset(sdf, prefix + "-SDF.asset");
                AssetDatabase.AddObjectToAsset(texture, sdf);
                AssetDatabase.CreateAsset(chartsAsset, prefix + "-SurfaceCharts.asset");
                AssetDatabase.AddObjectToAsset(capture, chartsAsset);
                return new BakedMesh { sdf = sdf, charts = chartsAsset };
            }
            finally
            {
                // Persisted objects belong to the unique Run transaction. If any later
                // step fails, its entire folder is removed after the temporary scene closes.
                if (texture != null && !EditorUtility.IsPersistent(texture)) UnityEngine.Object.DestroyImmediate(texture);
                if (capture != null && !EditorUtility.IsPersistent(capture)) UnityEngine.Object.DestroyImmediate(capture);
                if (sdf != null && !EditorUtility.IsPersistent(sdf)) UnityEngine.Object.DestroyImmediate(sdf);
                if (chartsAsset != null && !EditorUtility.IsPersistent(chartsAsset)) UnityEngine.Object.DestroyImmediate(chartsAsset);
            }
        }

        private static bool ContinueBake(string title, string mesh, int done, int total)
        { return Application.isBatchMode || !EditorUtility.DisplayCancelableProgressBar(title, mesh + ": " + (done + 1) + "/" + total, (float)done / Mathf.Max(1, total)); }

        private static Transform View(Transform parent, string name, Vector3 position, Vector3 lookAt)
        {
            var go = new GameObject(name);
            SceneManager.MoveGameObjectToScene(go, parent.gameObject.scene);
            go.transform.SetParent(parent, false);
            go.transform.position = position;
            go.transform.rotation = Quaternion.LookRotation(lookAt - position);
            return go.transform;
        }

        private static Material MaterialAsset(Shader shader, string folder, string name, Color color, float metallic = 0f)
        {
            var material = new Material(shader) { name = name };
            material.SetColor("_BaseColor", color);
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", 0.35f);
            AssetDatabase.CreateAsset(material, folder + "/" + name + ".mat");
            return material;
        }

        private static GameObject Box(Transform parent, string name, Vector3 center, Vector3 size, Material material)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            SceneManager.MoveGameObjectToScene(go, parent.gameObject.scene);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = center;
            go.transform.localScale = size;
            Renderer renderer = go.GetComponent<Renderer>();
            renderer.sharedMaterial = material;
            renderer.lightProbeUsage = LightProbeUsage.Off;
            renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
            go.AddComponent<HybridLumenGIProxy>().SetSources(renderer, go.GetComponent<Collider>());
            return go;
        }

        private static Light LightObject(Transform parent, string name, LightType type, Vector3 position, Color color, float intensity)
        {
            var go = new GameObject(name);
            SceneManager.MoveGameObjectToScene(go, parent.gameObject.scene);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = position;
            Light light = go.AddComponent<Light>();
            light.type = type;
            light.color = color;
            light.intensity = intensity;
            light.shadows = LightShadows.Soft;
            light.lightmapBakeType = LightmapBakeType.Realtime;
            return light;
        }
    }
}
