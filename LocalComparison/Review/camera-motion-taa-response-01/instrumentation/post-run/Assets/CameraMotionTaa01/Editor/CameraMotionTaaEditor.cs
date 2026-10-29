// One-shot Editor entry for a finite, prospectively specified raw-transport reference.
#if UNITY_EDITOR
using System;
using System.IO;
using System.Reflection;
using HybridLumenGI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[InitializeOnLoad]
public static class CameraMotionTaaEditor
{
    const string Root="Assets/CameraMotionTaa01",Generated=Root+"/Generated",Key="CameraMotionTaa01.";
    [Serializable] sealed class RestoreState {public SceneSetup[] scenes;public string qualityPipeline;public bool qualityWasNull,restoreEmptyScene;}
    [Serializable] sealed class EditorReceipt {public string status,error,output;public bool restored;}
    static CameraMotionTaaEditor(){EditorApplication.playModeStateChanged+=StateChanged;}
    static string Arg(string key){var args=Environment.GetCommandLineArgs();int index=Array.IndexOf(args,key);return index>=0&&index+1<args.Length?args[index+1]:null;}
    static void Require(bool value,string message){if(!value)throw new InvalidOperationException(message);}
    static void StateChanged(PlayModeStateChange state)
    {if(state==PlayModeStateChange.EnteredEditMode&&SessionState.GetBool(Key+"active",false))EditorApplication.delayCall+=Complete;}
    static void Restore()
    {
        var state=JsonUtility.FromJson<RestoreState>(SessionState.GetString(Key+"restore",""));
        QualitySettings.renderPipeline=state.qualityWasNull?null:AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(state.qualityPipeline);
        Require(state.qualityWasNull||QualitySettings.renderPipeline!=null,"Original quality pipeline missing");
        // A batch Editor may start without a loaded scene. Unity cannot restore an empty setup.
        if(state.restoreEmptyScene)EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
        else EditorSceneManager.RestoreSceneManagerSetup(state.scenes);
    }
    static void Complete()
    {
        string output=SessionState.GetString(Key+"output","");var receipt=new EditorReceipt{status="failed",output=output};
        try
        {
            string path=Path.Combine(output,"scene-result.json");Require(File.Exists(path),"Play returned without a scene receipt");
            var scene=JsonUtility.FromJson<CameraMotionTaaScene.Result>(File.ReadAllText(path));
            Require(scene.status=="collected"&&scene.readbacksDrained,"Scene capture failed: "+scene.error);receipt.status="collected";
        }
        catch(Exception error){receipt.error=error.ToString();}
        finally
        {
            try{Restore();receipt.restored=true;}catch(Exception error){receipt.status="failed";receipt.error=(receipt.error??"")+"\nRestore: "+error;}
            SessionState.SetBool(Key+"active",false);
            File.WriteAllText(Path.Combine(output,"editor-result.json"),JsonUtility.ToJson(receipt,true));
        }
        EditorApplication.Exit(receipt.status=="collected"&&receipt.restored?0:1);
    }
    public static void Run()
    {
        string output=Arg("-cameraMotionTaaOutput");
        Require(!string.IsNullOrEmpty(output)&&Path.IsPathRooted(output)&&!Directory.Exists(output)&&!File.Exists(output),"New absolute -cameraMotionTaaOutput is required");
        Require(!EditorApplication.isPlayingOrWillChangePlaymode&&!SessionState.GetBool(Key+"active",false),"An Editor Play run is already active");
        Require(!AssetDatabase.IsValidFolder(Generated)&&!Directory.Exists(Generated),"Generated reference assets already exist");
        Require(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&QualitySettings.activeColorSpace==ColorSpace.Linear,"Launch this Editor with DX12 and existing Linear project settings");
        var original=GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;Require(original!=null,"Existing URP pipeline required");
        var setup=EditorSceneManager.GetSceneManagerSetup();bool restoreEmpty=setup.Length==0;
        int sceneCount=UnityEngine.SceneManagement.SceneManager.sceneCount,unnamedScenes=0;
        for(int i=0;i<sceneCount;i++)
        {
            var existing=UnityEngine.SceneManagement.SceneManager.GetSceneAt(i);
            Require(!existing.isDirty,"Save existing dirty scenes before this isolated run");
            if(string.IsNullOrEmpty(existing.path))
            {
                Require(existing.isLoaded&&existing.rootCount==0,"Unnamed scenes must be empty and contain no user objects");unnamedScenes++;
            }
        }
        if(restoreEmpty||unnamedScenes>0)
        {
            Require(sceneCount==0||(sceneCount==1&&unnamedScenes==1),"Only a missing scene or one clean empty unnamed scene can use empty-scene restoration");
            restoreEmpty=true;
        }
        else
        {
            int loaded=0,active=0;
            foreach(var existing in setup){Require(!string.IsNullOrEmpty(existing.path),"Saved scene path missing");if(existing.isLoaded)loaded++;if(existing.isActive){Require(existing.isLoaded,"Original active scene is not loaded");active++;}}
            Require(loaded>0&&active==1,"Original scene setup is not restorable");
        }
        Directory.CreateDirectory(output);
        SessionState.SetString(Key+"output",output);SessionState.SetString(Key+"restore",JsonUtility.ToJson(new RestoreState{scenes=setup,restoreEmptyScene=restoreEmpty,qualityPipeline=AssetDatabase.GetAssetPath(QualitySettings.renderPipeline),qualityWasNull=QualitySettings.renderPipeline==null}));
        try
        {
            if(!AssetDatabase.IsValidFolder(Root))AssetDatabase.CreateFolder("Assets","CameraMotionTaa01");AssetDatabase.CreateFolder(Root,"Generated");
            var pipeline=UnityEngine.Object.Instantiate(original);pipeline.name="CameraMotionTaaPipeline";
            var sourceSettings=new SerializedObject(original);var renderers=sourceSettings.FindProperty("m_RendererDataList");int defaultIndex=sourceSettings.FindProperty("m_DefaultRendererIndex").intValue;
            var sourceRenderer=renderers.GetArrayElementAtIndex(defaultIndex).objectReferenceValue as UniversalRendererData;Require(sourceRenderer!=null,"Default renderer must be UniversalRendererData");
            var renderer=UnityEngine.Object.Instantiate(sourceRenderer);renderer.name="CameraMotionTaaRenderer";renderer.rendererFeatures.Clear();renderer.renderingMode=RenderingMode.Forward;
            AssetDatabase.CreateAsset(renderer,Generated+"/Renderer.asset");
            var feature=ScriptableObject.CreateInstance<HybridLumenGIRendererFeature>();feature.name="CameraMotionTaaGI";
            var settings=new HybridLumenGIRendererFeature.Settings{resolutionScale=1,raysPerPixel=8,screenSteps=0,traceDistance=20,rayBias=.03f,
                residentProxies=32,nearDistance=30,farDistance=30,proxyUploadsPerFrame=32,globalSdfEnabled=false,
                cachePatchesPerFrame=256,cachePatchGrid=1,cacheRaysPerFace=1,guidedSamplingWeight=0,emissiveSamplingWeight=0,maxEmissiveProposals=0,maxAreaEmitterTriangles=0,
                surfaceTileResolution=32,residentSurfaceCards=32,surfaceCapturesPerFrame=24,surfaceDrawsPerFrame=256,bounceFeedback=0,maxLights=1,spatialLightSelection=false,
                environmentRadiance=Color.black,environmentCubemap=null,indirectIntensity=1,radianceClamp=0,temporalAccumulation=true,maxHistory=32,filterIterations=0,
                receiverSourceTracking=true,receiverObjectHistory=true,includeSceneView=false,preferHardwareTracing=true,exactSoftwareTracing=true,
                measureGpuCost=false,adaptiveGpuBudget=false,targetGpuMilliseconds=0,composition=HybridLumenGIRendererFeature.CompositionMode.Additive,debugView=HybridLumenGIRendererFeature.DebugView.IndirectOnly};
            typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(feature,settings);
            AssetDatabase.AddObjectToAsset(feature,renderer);renderer.rendererFeatures.Add(feature);feature.SetActive(true);EditorUtility.SetDirty(feature);EditorUtility.SetDirty(renderer);
            pipeline.supportsHDR=true;pipeline.msaaSampleCount=1;pipeline.renderScale=1;pipeline.supportsCameraDepthTexture=true;
            AssetDatabase.CreateAsset(pipeline,Generated+"/Pipeline.asset");var pipelineSettings=new SerializedObject(pipeline);var list=pipelineSettings.FindProperty("m_RendererDataList");list.arraySize=1;list.GetArrayElementAtIndex(0).objectReferenceValue=renderer;pipelineSettings.FindProperty("m_DefaultRendererIndex").intValue=0;pipelineSettings.ApplyModifiedPropertiesWithoutUndo();
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            var shader=Shader.Find("Universal Render Pipeline/Lit");Require(shader!=null,"URP Lit shader missing");
            var material=new Material(shader){name="CameraMotionTaaWhiteMetallic0"};material.SetColor("_BaseColor",Color.white);material.SetFloat("_WorkflowMode",1);material.SetFloat("_Metallic",0);material.SetFloat("_Smoothness",0);material.SetFloat("_OcclusionStrength",1);material.SetColor("_EmissionColor",Color.black);
            foreach(string texture in new[]{"_BaseMap","_BumpMap","_EmissionMap","_OcclusionMap","_MetallicGlossMap","_SpecGlossMap"})material.SetTexture(texture,null);
            foreach(string keyword in new[]{"_EMISSION","_NORMALMAP","_METALLICSPECGLOSSMAP","_OCCLUSIONMAP","_SPECULAR_SETUP","_ALPHATEST_ON"})material.DisableKeyword(keyword);
            AssetDatabase.CreateAsset(material,Generated+"/Material.mat");
            var wall=Surface("ReferenceWall",new[]{new Vector3(0,0,-2),new Vector3(0,2,-2),new Vector3(0,2,2),new Vector3(0,0,2)},Vector3.right,material);
            var floor=Surface("ReferenceFloor",new[]{new Vector3(0,0,-3),new Vector3(0,0,3),new Vector3(5,0,3),new Vector3(5,0,-3)},Vector3.up,material);
            var panel=Surface("FixedBlackPanel",new[]{new Vector3(.4f,0,-.2f),new Vector3(.4f,1.8f,-.2f),new Vector3(1.8f,1.8f,-.2f),new Vector3(1.8f,0,-.2f)},Vector3.back,material);
            var light=new GameObject("WhiteDirectionalToPositiveX").AddComponent<Light>();light.type=LightType.Directional;light.transform.rotation=new Quaternion(.5f,-.5f,-.5f,.5f);light.color=Color.white;light.intensity=1;light.useColorTemperature=false;light.shadows=LightShadows.None;light.lightmapBakeType=LightmapBakeType.Realtime;
            var camera=new GameObject("CameraMotionTaaCamera").AddComponent<Camera>();camera.enabled=false;camera.transform.position=new Vector3(3,3,-3);camera.transform.LookAt(new Vector3(1,.4f,0));camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;camera.nearClipPlane=.05f;camera.farClipPlane=30;camera.fieldOfView=50;camera.aspect=(float)CameraMotionTaaScene.Width/CameraMotionTaaScene.Height;camera.allowHDR=true;camera.allowMSAA=false;camera.allowDynamicResolution=false;
            var additional=camera.GetUniversalAdditionalCameraData();additional.renderType=CameraRenderType.Base;additional.renderPostProcessing=true;additional.antialiasing=AntialiasingMode.TemporalAntiAliasing;additional.antialiasingQuality=AntialiasingQuality.High;additional.taaSettings.jitterScale=1;additional.taaSettings.quality=TemporalAAQuality.High;additional.requiresDepthOption=CameraOverrideOption.On;additional.requiresColorOption=CameraOverrideOption.On;additional.SetRenderer(0);
            var host=new GameObject("CameraMotionTaaHost").AddComponent<CameraMotionTaaScene>();host.targetCamera=camera;host.feature=feature;host.wall=wall;host.floor=floor;host.panel=panel;host.sourceLight=light;host.outputDirectory=output;
            Require(EditorSceneManager.SaveScene(scene,Generated+"/FiniteWall.unity"),"Scene save failed");AssetDatabase.SaveAssets();
            QualitySettings.renderPipeline=pipeline;SessionState.SetBool(Key+"active",true);
            File.WriteAllText(Path.Combine(output,"editor-prepared.json"),JsonUtility.ToJson(new EditorReceipt{status="prepared",output=output},true));
            EditorApplication.EnterPlaymode();
        }
        catch(Exception error)
        {
            var receipt=new EditorReceipt{status="failed",output=output,error=error.ToString()};
            try{Restore();receipt.restored=true;}catch(Exception restoreError){receipt.error+="\nRestore: "+restoreError;}
            SessionState.SetBool(Key+"active",false);File.WriteAllText(Path.Combine(output,"editor-result.json"),JsonUtility.ToJson(receipt,true));throw;
        }
    }
    static MeshRenderer Surface(string name,Vector3[] vertices,Vector3 normal,Material material)
    {
        var mesh=new Mesh{name=name+"Mesh"};mesh.vertices=vertices;mesh.normals=new[]{normal,normal,normal,normal};mesh.uv=new[]{Vector2.zero,Vector2.up,Vector2.one,Vector2.right};mesh.triangles=new[]{0,1,2,0,2,3};mesh.RecalculateTangents();mesh.RecalculateBounds();AssetDatabase.CreateAsset(mesh,Generated+"/"+name+"Mesh.asset");
        var charts=HybridLumenGISurfaceCharts.Bake(mesh,new HybridLumenGISurfaceCharts.BakeSettings(),out var report);Require(report.validTriangles==2&&report.degenerateTriangles==0&&!report.capacityExceeded,"Plane chart bake failed");
        var capture=HybridLumenGISurfaceCharts.CreateCaptureMesh(mesh,charts);var chartAsset=ScriptableObject.CreateInstance<HybridLumenGISurfaceCharts>();chartAsset.name=name+"Charts";chartAsset.SetBakedData(mesh,capture,charts);AssetDatabase.CreateAsset(chartAsset,Generated+"/"+name+"Charts.asset");AssetDatabase.AddObjectToAsset(capture,chartAsset);Require(chartAsset.IsValid,"Plane chart validation failed");
        var owner=new GameObject(name);owner.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=owner.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;renderer.lightProbeUsage=LightProbeUsage.Off;renderer.reflectionProbeUsage=ReflectionProbeUsage.Off;
        var proxy=owner.AddComponent<HybridLumenGIProxy>();proxy.SetSources(renderer,null);proxy.SetSurfaceCharts(chartAsset);return renderer;
    }
}
#endif
