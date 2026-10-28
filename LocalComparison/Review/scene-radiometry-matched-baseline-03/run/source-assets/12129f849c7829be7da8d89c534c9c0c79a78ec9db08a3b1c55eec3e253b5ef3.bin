using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;

// Finite integration checks layered on the existing capture runner.
public static class RuntimeAuditEditor
{
    const string Folder="Assets/RuntimeAudit";
    static string Arg(string key,string fallback){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,key);return i>=0&&i+1<a.Length?a[i+1]:fallback;}
    static Material MaterialAsset(string name,Color color)
    {
        string path=Folder+"/"+name+".mat";var m=AssetDatabase.LoadAssetAtPath<Material>(path);
        if(!m){m=new Material(Shader.Find("Universal Render Pipeline/Lit"));AssetDatabase.CreateAsset(m,path);}
        m.SetColor("_BaseColor",color);m.SetFloat("_Smoothness",.3f);return m;
    }
    static Texture2D TextureAsset(string name,bool normal,bool alpha)
    {
        string path=Folder+"/"+name+".png";
        if(!File.Exists(path))
        {
            var t=new Texture2D(32,32,TextureFormat.RGBA32,false,true);
            for(int y=0;y<32;y++)for(int x=0;x<32;x++)
            {
                bool odd=(x/8+y/8)%2==0;
                t.SetPixel(x,y,normal?(odd?new Color(.8f,.5f,.9f):new Color(.2f,.5f,.9f)):
                    new Color(odd?1:.06f,odd?.08f:.9f,.04f,alpha&&!odd?0:1));
            }
            t.Apply();File.WriteAllBytes(path,t.EncodeToPNG());UnityEngine.Object.DestroyImmediate(t);
            AssetDatabase.ImportAsset(path);
            var importer=(TextureImporter)AssetImporter.GetAtPath(path);
            importer.textureType=normal?TextureImporterType.NormalMap:TextureImporterType.Default;
            importer.sRGBTexture=!normal;importer.mipmapEnabled=true;importer.isReadable=true;
            importer.textureCompression=TextureImporterCompression.Uncompressed;importer.alphaSource=TextureImporterAlphaSource.FromInput;
            importer.SaveAndReimport();
        }
        return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
    }
    static void Bake(HybridLumenGIProxy proxy,Mesh mesh,string name)
    {
        string sp=Folder+"/"+name+"-SDF.asset",cp=Folder+"/"+name+"-Charts.asset";
        var sdf=AssetDatabase.LoadAssetAtPath<HybridLumenGIMeshSdf>(sp);
        if(!sdf)
        {
            var data=HybridLumenGIMeshSdfBaker.Bake(mesh,16,null,out var bounds,out var closed);
            var texture=new Texture3D(16,16,16,TextureFormat.RFloat,false){name="SDF",wrapMode=TextureWrapMode.Clamp};
            texture.SetPixelData(data,0);texture.Apply(false,false);
            sdf=ScriptableObject.CreateInstance<HybridLumenGIMeshSdf>();sdf.SetBakedData(mesh,texture,bounds,16,closed);
            AssetDatabase.CreateAsset(sdf,sp);AssetDatabase.AddObjectToAsset(texture,sdf);
        }
        var charts=AssetDatabase.LoadAssetAtPath<HybridLumenGISurfaceCharts>(cp);
        if(!charts)
        {
            var cs=HybridLumenGISurfaceCharts.Bake(mesh,new HybridLumenGISurfaceCharts.BakeSettings(),out var report);
            var capture=HybridLumenGISurfaceCharts.CreateCaptureMesh(mesh,cs);
            charts=ScriptableObject.CreateInstance<HybridLumenGISurfaceCharts>();charts.SetBakedData(mesh,capture,cs);
            AssetDatabase.CreateAsset(charts,cp);AssetDatabase.AddObjectToAsset(capture,charts);
        }
        proxy.SetMeshSdf(sdf);proxy.SetSurfaceCharts(charts);
    }
    public static void Prepare()
    {
        ComparisonRunnerEditor.Prepare();Directory.CreateDirectory(Folder);AssetDatabase.Refresh();
        var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        EditorSceneManager.SaveScene(scene,Folder+"/Functional.unity");
        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        var feature=(HybridLumenGIRendererFeature)capture.feature;
        var so=new SerializedObject(feature);
        so.FindProperty("settings.receiverObjectHistory").boolValue=true;
        so.FindProperty("settings.receiverSourceTracking").boolValue=true;
        so.FindProperty("settings.nearDistance").floatValue=8f; // exercise the existing near/far boundary
        so.FindProperty("settings.composition").enumValueIndex=int.Parse(Arg("-auditComposition","0"));
        so.FindProperty("settings.indirectIntensity").floatValue=float.Parse(Arg("-auditIntensity","1"),System.Globalization.CultureInfo.InvariantCulture);
        so.ApplyModifiedPropertiesWithoutUndo();EditorUtility.SetDirty(feature);
        var emission=MaterialAsset("EnabledEmitter",Color.white);
        emission.SetColor("_EmissionColor",new Color(5,3,1.5f));emission.globalIlluminationFlags=MaterialGlobalIlluminationFlags.RealtimeEmissive;
        emission.EnableKeyword("_EMISSION");EditorUtility.SetDirty(emission);
        GameObject.Find("Emissive source").GetComponent<Renderer>().sharedMaterial=emission;
        var checker=MaterialAsset("Checker",Color.white);checker.SetTexture("_BaseMap",TextureAsset("Checker",false,false));
        checker.SetTextureScale("_BaseMap",new Vector2(2,1));
        var normal=MaterialAsset("NormalMapped",new Color(.15f,.7f,.8f));normal.SetTexture("_BumpMap",TextureAsset("Normal",true,false));normal.EnableKeyword("_NORMALMAP");
        var alpha=MaterialAsset("Cutout",Color.white);alpha.SetTexture("_BaseMap",TextureAsset("Cutout",false,true));
        alpha.SetFloat("_AlphaClip",1);alpha.SetFloat("_Cutoff",.5f);alpha.SetOverrideTag("RenderType","TransparentCutout");
        alpha.renderQueue=(int)RenderQueue.AlphaTest;alpha.EnableKeyword("_ALPHATEST_ON");
        foreach(var m in new[]{checker,normal,alpha})EditorUtility.SetDirty(m);
        var receiver=GameObject.Find("White receiver");var filter=receiver.GetComponent<MeshFilter>();
        var multi=AssetDatabase.LoadAssetAtPath<Mesh>(Folder+"/MultiSubmesh.asset");
        if(!multi)
        {
            multi=UnityEngine.Object.Instantiate(filter.sharedMesh);multi.name="Two material cube";var triangles=multi.triangles;
            multi.subMeshCount=2;multi.SetTriangles(triangles.Take(18).ToArray(),0);multi.SetTriangles(triangles.Skip(18).ToArray(),1);
            AssetDatabase.CreateAsset(multi,Folder+"/MultiSubmesh.asset");
        }
        filter.sharedMesh=multi;receiver.GetComponent<Renderer>().sharedMaterials=new[]{checker,normal};Bake(receiver.GetComponent<HybridLumenGIProxy>(),multi,"Multi");
        GameObject.Find("Green wall").GetComponent<Renderer>().sharedMaterial=normal;
        var cutout=GameObject.CreatePrimitive(PrimitiveType.Cube);cutout.name="Audit alpha occluder";cutout.transform.SetParent(capture.transform,false);
        cutout.transform.position=new Vector3(-3.25f,1.8f,2.5f);cutout.transform.localScale=new Vector3(.05f,1.2f,1.3f);
        cutout.GetComponent<Renderer>().sharedMaterial=alpha;var ap=cutout.AddComponent<HybridLumenGIProxy>();ap.SetSources(cutout.GetComponent<Renderer>(),cutout.GetComponent<Collider>());ComparisonRunnerEditor.AssignBakedSources(ap);
        var deform=GameObject.CreatePrimitive(PrimitiveType.Cube);deform.name="Audit deforming occluder";deform.transform.SetParent(capture.transform,false);
        deform.transform.position=new Vector3(1.4f,1.4f,-.7f);deform.transform.localScale=new Vector3(1.3f,2.8f,.22f);
        deform.GetComponent<Renderer>().sharedMaterial=checker;var dp=deform.AddComponent<HybridLumenGIProxy>();dp.SetSources(deform.GetComponent<Renderer>(),deform.GetComponent<Collider>());
        var deformed=deform.AddComponent<HybridLumenGIDeformedMesh>();deformed.sdfResolution=16;deformed.updateIntervalFrames=12;
        var probe=capture.gameObject.AddComponent<RuntimeAuditProbe>();probe.capture=capture;probe.deformation=deformed;probe.mutableRenderer=receiver.GetComponent<Renderer>();probe.emitter=emission;
        capture.label="functional-"+Arg("-comparisonMode","final")+"-composition"+Arg("-auditComposition","0");
        if(Arg("-auditAmbient","0")=="1")
        {
            RenderSettings.ambientMode=AmbientMode.Flat;RenderSettings.ambientLight=new Color(.15f,.2f,.3f);RenderSettings.ambientIntensity=1;
            var sh=new SphericalHarmonicsL2();sh.AddAmbientLight(RenderSettings.ambientLight);RenderSettings.ambientProbe=sh;
        }
        // Deliberate material changes are renderer MPBs, leaving the authored assets frozen.
        AssetDatabase.SaveAssets();AssetDatabase.Refresh();
        if(!emission.IsKeywordEnabled("_EMISSION"))throw new Exception("Emitter keyword failed to survive validation");
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);
        EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(Folder+"/Functional.unity",true)};
        Debug.Log("RUNTIME_AUDIT_PREPARED inlineRT="+SystemInfo.supportsInlineRayTracing+" emission="+emission.IsKeywordEnabled("_EMISSION"));
    }
    public static void Play(){Prepare();EditorApplication.EnterPlaymode();}
    public static void Build()
    {
        Prepare();var path=Arg("-comparisonBuild","I:/Unity test/Comparison/Builds/RuntimeCandidate/HybridLumenGITest.exe");
        EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(Folder+"/Functional.unity",true),new EditorBuildSettingsScene(Folder+"/Streaming.unity",true)};
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        var report=BuildPipeline.BuildPlayer(EditorBuildSettings.scenes.Select(s=>s.path).ToArray(),path,BuildTarget.StandaloneWindows64,BuildOptions.Development);
        File.WriteAllText(Path.ChangeExtension(path,"build.txt"),report.summary.result+"\n"+report.summary.totalSize);
        if(report.summary.result!=UnityEditor.Build.Reporting.BuildResult.Succeeded)throw new Exception("Audit Player build failed");
    }
}
