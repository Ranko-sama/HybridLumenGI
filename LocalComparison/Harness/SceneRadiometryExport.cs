// Test-project-only source export. Never invokes the scene generator or GI material evaluators.
#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class SceneRadiometryExport
{
    [Serializable] public class ColorInput { public Color srgb,linear; public ColorInput(Color value){srgb=value;linear=value.linear;} }
    [Serializable] public class MaterialInput
    {
        public string key,name,shader,path; public string[] keywords; public ColorInput baseColor,specularColor; public Color emissionRaw;
        public string emissionEncoding="HDR source retained raw; inactive in this baseline",baseMapDefault="Unassigned stock URP Lit white";
        public float metallic,workflow,smoothness,occlusionStrength,cutoff,surface,alphaClip; public int cull;
        public bool specularSetup,emissionEnabled,receiveShadows; public Color diffuseLinear,effectiveEmission;
        public TextureInput[] textures;
    }
    [Serializable] public class TextureInput { public string property,name,path,key; public bool assigned; public int width,height; }
    [Serializable] public class SubmeshInput {public int index; public string material,topology; public int[] indices;}
    [Serializable] public class MeshInput
    {
        public string key,name,meshKey,meshPath,meshName; public Matrix4x4 localToWorld;
        public Vector3[] vertices,normals; public Vector2[] uv; public SubmeshInput[] submeshes;
        public int layer,shadowCastingMode; public uint renderingLayers; public bool receiveShadows,propertyBlock;
        public string proxySourceRenderer; public ColorInput proxyAlbedoTint,proxyEmissionOverride; public float proxyEmissionIntensity;
    }
    [Serializable] public class LightInput
    {
        public string key,name,type,bakeType,cookie; public bool enabled,useTemperature,customShadowLayers;
        public ColorInput color; public Color temperatureRGB; public float intensity,range,temperature,shadowStrength;
        public Vector3 position,direction; public int cullingMask,shadows; public uint renderingLayers,shadowLayers;
    }
    [Serializable] public class SceneInput
    {
        public string baseline="C-prospective-01",unity,scene,featureSettings,ambientMode;
        public bool linear,lightLayers,lightsUseLinearIntensity,lightsUseColorTemperature,skybox,fog;
        public ColorInput ambient,environment; public float ambientIntensity,reflectionIntensity;
        public Vector3 cameraPosition,doorPosition; public Quaternion cameraRotation;
        public Matrix4x4 view,projection; public float fieldOfView,aspect,nearPlane,farPlane;
        public int cameraMask; public MeshInput[] meshes; public MaterialInput[] materials; public LightInput[] lights;
    }
    [Serializable] public class FileInput {public string path,sha256,archive; public long bytes;}
    [Serializable] class Exclusion {public string path,reason;}
    [Serializable] class DependencySelection {public string[] selected;public Exclusion[] exclusions;}
    [Serializable] class Freeze {public string baseline="C-prospective-01",sourceSha256;public bool historicalSourceClosure=false;public FileInput[] files;public Exclusion[] exclusions;}
    [Serializable] class Check {public int logicalFrame;public string sourceSha256;public bool sameSource,sameDependencyBytes;}
    static ComparisonCapture capture;
    static string output,sourceHash;
    static FileInput[] frozenFiles;
    static readonly List<Exclusion> dependencyExclusions=new List<Exclusion>();
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static string Arg(string key){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,key);return i>=0&&i+1<a.Length?a[i+1]:"";}
    static string Hash(byte[] bytes){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
    static void Json(string path,object value)=>File.WriteAllText(path,JsonUtility.ToJson(value,true),new UTF8Encoding(false));
    static string Key(UnityEngine.Object value)
    {
        if(!value)return "none";
        if(AssetDatabase.TryGetGUIDAndLocalFileIdentifier(value,out string guid,out long local))return guid+":"+local;
        return GlobalObjectId.GetGlobalObjectIdSlow(value).ToString();
    }
    static string Hierarchy(Transform transform)=>transform.parent?Hierarchy(transform.parent)+"/"+transform.name:transform.name;
    static float Scalar(Material m,string key,float fallback)=>m.HasProperty(key)?m.GetFloat(key):fallback;
    static Color Colour(Material m,string key,Color fallback)=>m.HasProperty(key)?m.GetColor(key):fallback;
    static string Resolve(string path)
    {
        // These are project-owned package configuration files, not assets inside
        // a package. PackageInfo.FindForAssetPath intentionally cannot resolve them.
        if(path=="Packages/manifest.json"||path=="Packages/packages-lock.json")return Path.GetFullPath(path);
        if(path.StartsWith("Packages/",StringComparison.Ordinal)){
            var package=UnityEditor.PackageManager.PackageInfo.FindForAssetPath(path);
            if(package==null)throw new Exception("Unresolved package input: "+path);
            string prefix="Packages/"+package.name;
            return path==prefix?package.resolvedPath:Path.Combine(package.resolvedPath,path.Substring(prefix.Length+1));
        }
        return Path.GetFullPath(path);
    }
    static MaterialInput Material(Material m)
    {
        if(!m||m.shader.name!="Universal Render Pipeline/Lit")throw new Exception("Reference supports stock URP Lit only");
        var row=new MaterialInput{key=Key(m),name=m.name,path=AssetDatabase.GetAssetPath(m),shader=m.shader.name,keywords=m.shaderKeywords.OrderBy(x=>x,StringComparer.Ordinal).ToArray(),
            baseColor=new ColorInput(Colour(m,"_BaseColor",Color.white)),specularColor=new ColorInput(Colour(m,"_SpecColor",Color.black)),
            emissionRaw=Colour(m,"_EmissionColor",Color.black),metallic=Scalar(m,"_Metallic",0),workflow=Scalar(m,"_WorkflowMode",1),
            smoothness=Scalar(m,"_Smoothness",.5f),occlusionStrength=Scalar(m,"_OcclusionStrength",1),cutoff=Scalar(m,"_Cutoff",.5f),
            surface=Scalar(m,"_Surface",0),alphaClip=Scalar(m,"_AlphaClip",0),cull=(int)Scalar(m,"_Cull",2),
            specularSetup=m.IsKeywordEnabled("_SPECULAR_SETUP"),emissionEnabled=m.IsKeywordEnabled("_EMISSION"),receiveShadows=!m.IsKeywordEnabled("_RECEIVE_SHADOWS_OFF")};
        row.textures=m.GetTexturePropertyNames().OrderBy(x=>x,StringComparer.Ordinal).Select(property=>{
            var texture=m.GetTexture(property);return new TextureInput{property=property,assigned=texture!=null,name=texture?texture.name:"none",path=texture?AssetDatabase.GetAssetPath(texture):"",key=Key(texture),width=texture?texture.width:0,height=texture?texture.height:0};
        }).ToArray();
        // The finite reference intentionally has no texture/alpha/normal-map approximation.
        if(row.surface!=0||row.alphaClip!=0||m.IsKeywordEnabled("_ALPHATEST_ON")||row.textures.Any(t=>t.assigned)||
            m.IsKeywordEnabled("_METALLICSPECGLOSSMAP")||m.IsKeywordEnabled("_OCCLUSIONMAP")||m.IsKeywordEnabled("_NORMALMAP")||m.IsKeywordEnabled("_PARALLAXMAP")||m.IsKeywordEnabled("_DETAIL_MULX2")||m.IsKeywordEnabled("_DETAIL_SCALED")||
            m.IsKeywordEnabled("_CLEARCOAT")||m.IsKeywordEnabled("_CLEARCOATMAP"))throw new Exception("Unsupported radiometry material source: "+m.name);
        float reflectance=row.specularSetup?1-Mathf.Max(row.specularColor.linear.r,Mathf.Max(row.specularColor.linear.g,row.specularColor.linear.b)):.96f*(1-row.metallic);
        row.diffuseLinear=row.baseColor.linear*reflectance;row.diffuseLinear.a=1;
        // All candidate materials have _EMISSION disabled. Do not guess HDR picker conventions if import changes it.
        if(row.emissionEnabled)throw new Exception("Active emission needs an explicit HDR source contract; stop this bounded baseline");
        row.effectiveEmission=Color.black;
        return row;
    }
    static SceneInput Build()
    {
        var scene=capture.gameObject.scene;
        var roots=scene.GetRootGameObjects();
        if(roots.SelectMany(o=>o.GetComponentsInChildren<SkinnedMeshRenderer>(true)).Any(r=>r.enabled&&r.gameObject.activeInHierarchy))throw new Exception("Unsupported deforming source");
        var renderers=roots.SelectMany(o=>o.GetComponentsInChildren<MeshRenderer>(true)).Where(r=>r.enabled&&r.gameObject.activeInHierarchy).OrderBy(r=>Hierarchy(r.transform),StringComparer.Ordinal).ToArray();
        var materials=renderers.SelectMany(r=>r.sharedMaterials).Distinct().Select(Material).OrderBy(m=>m.key,StringComparer.Ordinal).ToArray();
        if(renderers.Length!=20||materials.Length!=6)throw new Exception("Frozen scene object/material selection changed");
        var meshes=renderers.Select(r=>{
            var filter=r.GetComponent<MeshFilter>();var mesh=filter?filter.sharedMesh:null;
            if(!mesh||r.HasPropertyBlock()||mesh.normals.Length!=mesh.vertexCount)throw new Exception("Unsupported mesh/property-block source: "+r.name);
            var mats=r.sharedMaterials;if(mats.Length!=mesh.subMeshCount)throw new Exception("Submesh/material cardinality unsupported");
            var proxy=r.GetComponent<HybridLumenGI.HybridLumenGIProxy>();
            if(!proxy||proxy.SourceRenderer!=r||proxy.AlbedoTint!=Color.white||proxy.EmissionOverride.maxColorComponent!=0)
                throw new Exception("Non-neutral or missing proxy source: "+r.name);
            return new MeshInput{key=Hierarchy(r.transform),name=r.name,meshKey=Key(mesh),meshPath=AssetDatabase.GetAssetPath(mesh),meshName=mesh.name,
                proxySourceRenderer=Hierarchy(proxy.SourceRenderer.transform),proxyAlbedoTint=new ColorInput(proxy.AlbedoTint),
                proxyEmissionOverride=new ColorInput(proxy.EmissionOverride),proxyEmissionIntensity=proxy.EmissionIntensity,
                localToWorld=r.localToWorldMatrix,vertices=mesh.vertices,normals=mesh.normals,uv=mesh.uv,layer=r.gameObject.layer,renderingLayers=r.renderingLayerMask,
                shadowCastingMode=(int)r.shadowCastingMode,receiveShadows=r.receiveShadows,propertyBlock=r.HasPropertyBlock(),
                submeshes=Enumerable.Range(0,mesh.subMeshCount).Select(i=>new SubmeshInput{index=i,material=Key(mats[i]),topology=mesh.GetTopology(i).ToString(),indices=mesh.GetIndices(i)}).ToArray()};
        }).ToArray();
        var lights=roots.SelectMany(o=>o.GetComponentsInChildren<Light>(true)).OrderBy(l=>Hierarchy(l.transform),StringComparer.Ordinal).Select(l=>{
            var extra=l.GetComponent<UniversalAdditionalLightData>();return new LightInput{key=Hierarchy(l.transform),name=l.name,type=l.type.ToString(),bakeType=l.lightmapBakeType.ToString(),
                enabled=l.isActiveAndEnabled,cookie=l.cookie?Key(l.cookie):"none",color=new ColorInput(l.color),intensity=l.intensity,range=l.range,position=l.transform.position,direction=l.transform.forward,
                useTemperature=l.useColorTemperature,temperature=l.colorTemperature,temperatureRGB=Mathf.CorrelatedColorTemperatureToRGB(l.colorTemperature),
                shadows=(int)l.shadows,shadowStrength=l.shadowStrength,cullingMask=l.cullingMask,renderingLayers=extra?extra.renderingLayers:1u,
                shadowLayers=unchecked((uint)l.renderingLayerMask),customShadowLayers=extra&&extra.customShadowLayers};
        }).ToArray();
        if(lights.Count(l=>l.enabled)!=1||lights.Single(l=>l.enabled).name!="Behind thin wall"||lights.Single(l=>l.enabled).type!="Point")throw new Exception("Unique static C point source required");
        if(lights.Single(l=>l.enabled).cookie!="none"||lights.Single(l=>l.enabled).bakeType!="Realtime")throw new Exception("Unsupported cookie/baked source");
        var settings=capture.feature.GetType().GetField("settings",Fields).GetValue(capture.feature);
        var environment=(Color)settings.GetType().GetField("environmentRadiance",Fields).GetValue(settings);
        var camera=capture.camera;var pipeline=GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
        if(!pipeline||RenderSettings.skybox||RenderSettings.fog||RenderSettings.ambientIntensity!=0||RenderSettings.reflectionIntensity!=0||environment.maxColorComponent!=0)
            throw new Exception("Unsupported ambient/environment source in this fixed C baseline");
        return new SceneInput{unity=Application.unityVersion,scene=scene.path,linear=QualitySettings.activeColorSpace==ColorSpace.Linear,
            lightLayers=pipeline.useRenderingLayers,lightsUseLinearIntensity=GraphicsSettings.lightsUseLinearIntensity,lightsUseColorTemperature=GraphicsSettings.lightsUseColorTemperature,
            skybox=RenderSettings.skybox!=null,fog=RenderSettings.fog,ambientMode=RenderSettings.ambientMode.ToString(),ambient=new ColorInput(RenderSettings.ambientLight),environment=new ColorInput(environment),
            ambientIntensity=RenderSettings.ambientIntensity,reflectionIntensity=RenderSettings.reflectionIntensity,cameraPosition=camera.transform.position,cameraRotation=camera.transform.rotation,
            doorPosition=capture.door.localPosition,view=camera.worldToCameraMatrix,projection=camera.projectionMatrix,fieldOfView=camera.fieldOfView,aspect=camera.aspect,
            nearPlane=camera.nearClipPlane,farPlane=camera.farClipPlane,cameraMask=camera.cullingMask,featureSettings=JsonUtility.ToJson(settings),meshes=meshes,materials=materials,lights=lights};
    }
    static string[] Dependencies(SceneInput source)
    {
        var paths=new HashSet<string>(AssetDatabase.GetDependencies(new[]{capture.gameObject.scene.path,AssetDatabase.GetAssetPath(capture.feature),AssetDatabase.GetAssetPath(GraphicsSettings.currentRenderPipeline)},true),StringComparer.Ordinal);
        foreach(string path in new[]{"ProjectSettings/ProjectSettings.asset","ProjectSettings/GraphicsSettings.asset","ProjectSettings/QualitySettings.asset","Packages/manifest.json","Packages/packages-lock.json"})paths.Add(path);
        foreach(string path in AssetDatabase.GetAllAssetPaths())if((path.StartsWith("Assets/HybridLumenGI/Runtime/",StringComparison.Ordinal)||path.StartsWith("Assets/ComparisonHarness/",StringComparison.Ordinal)||
            path.StartsWith("Packages/com.unity.render-pipelines.universal/",StringComparison.Ordinal)||path.StartsWith("Packages/com.unity.render-pipelines.core/",StringComparison.Ordinal))&&
            new[]{".hlsl",".shader",".compute",".cs","package.json","LICENSE.md"}.Any(s=>path.EndsWith(s,StringComparison.Ordinal)))paths.Add(path);
        dependencyExclusions.Clear();
        foreach(string path in paths.ToArray()){
            if(AssetDatabase.IsValidFolder(path)){
                paths.Remove(path);dependencyExclusions.Add(new Exclusion{path=path,reason="Unity AssetDatabase confirms a directory, not a byte-bearing file"});
            }else if(path=="Library/unity default resources"&&source.meshes.Any(m=>m.meshPath==path)){
                // This exact path is observed in the real exported built-in Cube
                // meshes; their vertex/normal/UV/index data is captured explicitly.
                paths.Remove(path);dependencyExclusions.Add(new Exclusion{path=path,reason="Observed Unity built-in mesh resource; actual mesh arrays exported in reference-scene.json"});
            }
        }
        Json(Path.Combine(output,"dependency-selection.json"),new DependencySelection{selected=paths.OrderBy(p=>p,StringComparer.Ordinal).ToArray(),exclusions=dependencyExclusions.ToArray()});
        foreach(string path in paths.ToArray()){
            if(!File.Exists(Resolve(path)))throw new Exception("Missing selected source dependency: "+path);
            if(File.Exists(Resolve(path)+".meta"))paths.Add(path+".meta");
        }
        return paths.OrderBy(p=>p,StringComparer.Ordinal).ToArray();
    }
    static FileInput Archive(string path)
    {
        byte[] bytes=File.ReadAllBytes(Resolve(path));string digest=Hash(bytes);
        // Keep the original asset path in the manifest. A content-addressed name
        // avoids the Windows/Mono path limit under a deep evidence directory.
        string archive="source-assets/"+digest+".bin";string destination=Path.Combine(output,archive);
        Directory.CreateDirectory(Path.GetDirectoryName(destination));
        if(File.Exists(destination)){
            if(!File.ReadAllBytes(destination).SequenceEqual(bytes))throw new Exception("Archive content collision: "+path);
        }else File.WriteAllBytes(destination,bytes);
        return new FileInput{path=path,sha256=digest,bytes=bytes.LongLength,archive=archive};
    }
    public static void Play()
    {
        output=Arg("-comparisonOutput");string scene=Arg("-radiometryScene");
        if(!Path.IsPathRooted(output)||scene!="Assets/RadiometryBaseline/Static.unity")throw new Exception("Explicit prospective scene/output required");
        Directory.CreateDirectory(output);
        EditorSceneManager.OpenScene(scene,OpenSceneMode.Single);
        capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();if(!capture)throw new Exception("Frozen capture missing");
        capture.totalFrames=120;capture.quitWhenComplete=true;capture.label="C-prospective-01";capture.outputRoot=output;capture.colorView=capture.thinView;capture.camera.aspect=640f/360;
        capture.camera.transform.SetPositionAndRotation(capture.thinView.position,capture.thinView.rotation);
        // No scene/material generator, source mutation, saving of the scene, or separate export process.
        var source=Build();if(!source.linear)throw new Exception("Linear source required");
        string json=JsonUtility.ToJson(source,true);sourceHash=Hash(Encoding.UTF8.GetBytes(json));
        File.WriteAllText(Path.Combine(output,"reference-scene.json"),json,new UTF8Encoding(false));
        frozenFiles=Dependencies(source).Select(Archive).ToArray();
        Json(Path.Combine(output,"source-freeze.json"),new Freeze{sourceSha256=sourceHash,files=frozenFiles,exclusions=dependencyExclusions.ToArray()});
        Debug.Log("RADIOMETRY_SOURCE_FROZEN C-prospective-01 / static120 / no historical source recertification");
        EditorApplication.EnterPlaymode();
    }
    public static void CheckSources(int logicalFrame)
    {
        if(!capture)capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        if(string.IsNullOrEmpty(output))output=Arg("-comparisonOutput");
        // Domain reload is allowed: restore only the immutable pre-Play receipt, never a new baseline.
        if(frozenFiles==null){var receipt=JsonUtility.FromJson<Freeze>(File.ReadAllText(Path.Combine(output,"source-freeze.json")));frozenFiles=receipt.files;sourceHash=receipt.sourceSha256;}
        string json=JsonUtility.ToJson(Build(),true);string actual=Hash(Encoding.UTF8.GetBytes(json));
        bool files=frozenFiles.All(f=>File.Exists(Resolve(f.path))&&Hash(File.ReadAllBytes(Resolve(f.path)))==f.sha256);
        Json(Path.Combine(output,"source-check-"+logicalFrame.ToString("D4")+".json"),new Check{logicalFrame=logicalFrame,sourceSha256=actual,sameSource=actual==sourceHash,sameDependencyBytes=files});
        if(actual!=sourceHash)File.WriteAllText(Path.Combine(output,"source-changed-"+logicalFrame.ToString("D4")+".json"),json,new UTF8Encoding(false));
        if(!files||actual!=sourceHash)throw new Exception("Prospective source changed after freeze; pairing rejected");
    }
}
#endif
