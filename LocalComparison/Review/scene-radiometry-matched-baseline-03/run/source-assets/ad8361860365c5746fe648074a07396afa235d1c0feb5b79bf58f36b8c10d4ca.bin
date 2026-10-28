using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;

public static class SceneLightoffEditor
{
    [Serializable] class MaterialSource {public string owner,material,shader;public int slot;public bool emissionKeyword,propertyBlock;public Color emission;public string emissionTexture;public Color proxyEmission;public float proxyIntensity;}
    [Serializable] class Sources {public string scope;public MaterialSource[] materials;public Color ambient;public float ambientIntensity,reflectionIntensity;public bool skybox,fog;public string featureJson;}
    static string Arg(string name){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,name);return i>=0&&i+1<a.Length?a[i+1]:"";}
    public static void Play()
    {
        if(Arg("-thinWallConfig")!="C"||Array.IndexOf(Environment.GetCommandLineArgs(),"-sceneLightoffProbe")<0||
            Array.IndexOf(Environment.GetCommandLineArgs(),"-gatherCacheProbe")<0||Array.IndexOf(Environment.GetCommandLineArgs(),"-thinWallProbe")>=0)
            throw new Exception("Fixed C light-off and gather observers required, legacy probe forbidden");
        ThinWallEditor.Prepare();
        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        capture.totalFrames=360;capture.label="scene-lightoff-chain-01-C";capture.quitWhenComplete=true;
        if(capture.lights.Count(l=>l.enabled)!=1||!capture.lights.Single(l=>l.enabled).name.Equals("Behind thin wall"))throw new Exception("Expected unique existing C point light");
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        EditorUtility.SetDirty(capture);EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);AssetDatabase.SaveAssets();
        string output=Arg("-comparisonOutput");Directory.CreateDirectory(output);
        var materials=UnityEngine.Object.FindObjectsByType<HybridLumenGIProxy>(FindObjectsSortMode.InstanceID).SelectMany(proxy=>
            proxy.SourceRenderer.sharedMaterials.Select((material,slot)=>new MaterialSource{owner=proxy.name,slot=slot,material=material.name,shader=material.shader.name,
                emissionKeyword=material.IsKeywordEnabled("_EMISSION"),propertyBlock=proxy.SourceRenderer.HasPropertyBlock(),
                emission=material.HasProperty("_EmissionColor")?material.GetColor("_EmissionColor"):Color.clear,
                emissionTexture=material.HasProperty("_EmissionMap")&&material.GetTexture("_EmissionMap")?material.GetTexture("_EmissionMap").name:"none",
                proxyEmission=proxy.EmissionOverride,proxyIntensity=proxy.EmissionIntensity})).ToArray();
        // Per-frame actual emission/proposal counts are recorded separately; this is an input inventory.
        var source=new Sources{scope="Single real C-scene light removal; emission/environment inventory, not a zero-source assertion",materials=materials,
            ambient=RenderSettings.ambientLight,ambientIntensity=RenderSettings.ambientIntensity,reflectionIntensity=RenderSettings.reflectionIntensity,
            skybox=RenderSettings.skybox!=null,fog=RenderSettings.fog,featureJson=JsonUtility.ToJson(capture.feature,true)};
        File.WriteAllText(Path.Combine(output,"source-inventory.json"),JsonUtility.ToJson(source,true));
        string archive=Path.Combine(output,"executed-assets");Directory.CreateDirectory(archive);
        string[] paths={"Assets/Comparison/Renderer.asset","Assets/Comparison/Pipeline.asset","Assets/ComparisonScene/Run/Validation.unity","Assets/ThinWallProbe/Static.unity","ProjectSettings/EditorBuildSettings.asset","ProjectSettings/GraphicsSettings.asset","ProjectSettings/QualitySettings.asset","ProjectSettings/ProjectSettings.asset"};
        foreach(string path in paths){if(!File.Exists(path))throw new Exception("Missing executed asset "+path);File.Copy(path,Path.Combine(archive,path.Replace('/','_')),false);}
        File.WriteAllText(Path.Combine(output,"executed-assets.json"),"["+string.Join(",",paths.Select(p=>"\""+p+"\""))+"]");
        File.Move(Path.Combine(output,"scene-contract.json"),Path.Combine(output,"base-C-contract.json"));
        Debug.Log("SCENE_LIGHTOFF_PREPARED C / 360 logical frames / real Light off at120 / source and executed assets archived");
        EditorApplication.EnterPlaymode();
    }
}
