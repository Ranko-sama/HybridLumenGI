using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace HybridLumenGI.Editor
{
    /// <summary>Creates a separate test asset without replacing the current scene.</summary>
    public static class ComparisonSceneBuilder
    {
        
        public static void CreateScene()
        {
            Shader lit = Shader.Find("Universal Render Pipeline/Lit");
            if (lit == null)
            {
                Debug.LogError("Hybrid Lumen GI requires the URP Lit shader to create the validation scene.");
                return;
            }

            const string rootPath = "Assets/ComparisonScene";
            if (!AssetDatabase.IsValidFolder(rootPath)) AssetDatabase.CreateFolder("Assets", "ComparisonScene");
            string folder = AssetDatabase.GenerateUniqueAssetPath(rootPath + "/Run");
            AssetDatabase.CreateFolder(rootPath, folder.Substring(rootPath.Length + 1));
            Scene previous = SceneManager.GetActiveScene();
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            try
            {
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
                emitter.globalIlluminationFlags = MaterialGlobalIlluminationFlags.None;

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
                // Door movement is driven by the shared comparison component.

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
                var capture = root.AddComponent<ComparisonCapture>();
                capture.camera = camera; capture.door = door.transform;
                capture.lights = new[] { sun, point, spot, thinLight, outsideLight };
                capture.colorView = colorView; capture.thinView = thinView; capture.blackView = blackView;
                capture.feature = selectedFeature;
                RenderSettings.sun = sun;
                string scenePath = folder + "/Validation.unity";
                EditorSceneManager.MarkSceneDirty(scene);
                if (!EditorSceneManager.SaveScene(scene, scenePath)) throw new InvalidOperationException("Could not save " + scenePath);
                AssetDatabase.SaveAssets();
                Debug.Log("Created " + scenePath + ". Open this scene alone; assign the camera's actual HybridLumenGIRendererFeature on Validation Sequence. " +
                    "Shared old/new comparison geometry. " +
                    "See Documentation/ValidationSequence.md: no reference images or Unity acceptance results are supplied.");
                Selection.activeObject = AssetDatabase.LoadAssetAtPath<SceneAsset>(scenePath);
            }
            finally
            {
                if (previous.IsValid() && previous.isLoaded) SceneManager.SetActiveScene(previous);
                if (scene.IsValid() && scene.isLoaded) EditorSceneManager.CloseScene(scene, true);
            }
        }

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
            var proxy = go.AddComponent<HybridLumenGIProxy>(); proxy.SetSources(renderer, go.GetComponent<Collider>()); ComparisonRunnerEditor.AssignBakedSources(proxy);
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
