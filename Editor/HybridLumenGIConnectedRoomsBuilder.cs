using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace HybridLumenGI.Editor
{
    public static class HybridLumenGIConnectedRoomsBuilder
    {
        [MenuItem("Tools/Hybrid Lumen GI/Create Connected Rooms Copy of Unified Sample")]
        private static void CreateFromActiveScene()
        {
            string path = CreateCopy(SceneManager.GetActiveScene());
            Selection.activeObject = AssetDatabase.LoadAssetAtPath<SceneAsset>(path);
            Debug.Log("Open " + path + " and enter Play. F3 shows the adjoining room. O opens or closes its door.");
        }

        /// <summary>Extend the open end of the standard validation color room in a new, independently saved scene.</summary>
        public static string CreateCopy(Scene source)
        {
            if (Application.isPlaying || !source.IsValid() || !source.isLoaded || source.isDirty ||
                string.IsNullOrEmpty(source.path) || !source.path.StartsWith("Assets/", StringComparison.Ordinal))
                throw new InvalidOperationException("Open the saved, clean standard unified sample before creating a rooms copy.");
            string folder = source.path.Substring(0, source.path.LastIndexOf('/'));
            string path = AssetDatabase.GenerateUniqueAssetPath(folder + "/ConnectedRooms.unity");
            var previous = SceneManager.GetActiveScene();
            Scene copy = default;
            bool saved = false, complete = false;
            try
            {
                if (!EditorSceneManager.SaveScene(source, path, true)) throw new IOException("Could not create a scene copy.");
                saved = true;
                copy = EditorSceneManager.OpenScene(path, OpenSceneMode.Additive);
                SceneManager.SetActiveScene(copy);
                var roots = copy.GetRootGameObjects();
                var controls = roots.SelectMany(r => r.GetComponentsInChildren<HybridLumenGIUnifiedSampleInteraction>(true)).SingleOrDefault();
                if (!controls || controls.HasConnectedRooms) throw new InvalidOperationException("Expected one standard unified sample without a rooms extension.");
                var proxies = roots.SelectMany(r => r.GetComponentsInChildren<HybridLumenGIProxy>(true)).ToArray();
                var floor = proxies.SingleOrDefault(p => p.name == "Floor");
                var emitter = proxies.SingleOrDefault(p => p.name == "Emissive source");
                if (!floor || !floor.SourceRenderer || !floor.SourceRenderer.sharedMaterial || !floor.SourceMesh ||
                    !floor.MeshSdf || floor.MeshSdf.SourceMesh != floor.SourceMesh || !floor.SurfaceCharts || floor.SurfaceCharts.SourceMesh != floor.SourceMesh ||
                    (floor.transform.lossyScale - new Vector3(8, .3f, 8)).sqrMagnitude > .0001f ||
                    !emitter || !emitter.SourceRenderer || !emitter.SourceRenderer.sharedMaterial || !emitter.SourceRenderer.sharedMaterial.IsKeywordEnabled("_EMISSION"))
                    throw new InvalidOperationException("Use the standard color room with its baked 8-by-8 Floor and Emissive source outside the streamed group.");

                var room = new GameObject("Connected rooms");
                room.SetActive(false);
                room.transform.SetPositionAndRotation(floor.transform.TransformPoint(0, .5f, 0), floor.transform.rotation);
                var neutral = floor.SourceRenderer.sharedMaterial;
                GameObject Box(string name, Vector3 center, Vector3 size, Material material)
                {
                    var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
                    go.transform.SetParent(room.transform, false);
                    if (go.GetComponent<MeshFilter>().sharedMesh != floor.SourceMesh)
                        throw new InvalidOperationException("The room extension shares the standard baked Cube mesh.");
                    go.name = name;
                    go.layer = floor.gameObject.layer;
                    go.transform.localPosition = center;
                    go.transform.localScale = size;
                    var renderer = go.GetComponent<MeshRenderer>();
                    renderer.sharedMaterial = material;
                    renderer.renderingLayerMask = floor.SourceRenderer.renderingLayerMask;
                    renderer.lightProbeUsage = floor.SourceRenderer.lightProbeUsage;
                    renderer.reflectionProbeUsage = floor.SourceRenderer.reflectionProbeUsage;
                    var proxy = go.AddComponent<HybridLumenGIProxy>();
                    proxy.SetSources(renderer, go.GetComponent<Collider>());
                    proxy.SetMeshSdf(floor.MeshSdf);
                    proxy.SetSurfaceCharts(floor.SurfaceCharts);
                    return go;
                }

                Box("Entry floor", new Vector3(0, -.15f, -7), new Vector3(8, .3f, 6), neutral);
                Box("Entry ceiling", new Vector3(0, 4, -7), new Vector3(8.3f, .3f, 6), neutral);
                Box("Source room ceiling", new Vector3(0, 4, -2), new Vector3(8.3f, .3f, 4), neutral);
                Box("Entry left", new Vector3(-4, 2, -7), new Vector3(.3f, 4.3f, 6), neutral);
                Box("Entry right", new Vector3(4, 2, -7), new Vector3(.3f, 4.3f, 6), neutral);
                Box("Entry end wall", new Vector3(0, 2, -10), new Vector3(8.3f, 4.3f, .3f), neutral);
                Box("Partition left", new Vector3(-2.5f, 2, -4), new Vector3(3, 4, .2f), neutral);
                Box("Partition right", new Vector3(2.5f, 2, -4), new Vector3(3, 4, .2f), neutral);
                Box("Doorway lintel", new Vector3(0, 3.4f, -4), new Vector3(2, 1.2f, .2f), neutral);
                var door = Box("Sliding partition door", new Vector3(0, 1.45f, -3.8f), new Vector3(2.18f, 2.92f, .18f), neutral);
                Box("Source room warm panel", new Vector3(0, 1.55f, -2.5f), new Vector3(2.3f, 2.3f, .12f), emitter.SourceRenderer.sharedMaterial);
                controls.ConfigureConnectedRooms(room, door.AddComponent<HybridLumenGIValidationMotion>());
                EditorSceneManager.MarkSceneDirty(copy);
                if (!EditorSceneManager.SaveScene(copy)) throw new IOException("Could not save the connected rooms.");
                complete = true;
                return path;
            }
            finally
            {
                if (copy.IsValid() && copy.isLoaded) EditorSceneManager.CloseScene(copy, true);
                if (previous.IsValid() && previous.isLoaded) SceneManager.SetActiveScene(previous);
                if (saved && !complete) AssetDatabase.DeleteAsset(path);
            }
        }
    }
}
