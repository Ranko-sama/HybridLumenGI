// Test-project Editor entry: build the existing functional scene without regeneration.
using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

public static class CurrentPlayerBuild
{
    // Insert inside CurrentPlayerBuild. Call after the existing capture/probe check,
    // before collecting build dependencies: SetupCurrentRelease67Cube(capture, receiptPath).
    // receiptPath must be a new absolute package path. Reuses this class's Hash(byte[]).
    // The caller backs up Renderer.asset/.meta before calling and restores them in
    // its build finally, removing only this newly created Cube asset/.meta there.
    // This method does not restore, destroy, rebuild the scene, or change lighting.
    const string Release67RendererPath="Assets/Comparison/Renderer.asset";
    const string Release67RendererGuid="1346d23e59037cd489d53c8e5b594ba4";
    const long Release67FeatureLocalId=5043623260922118210L;
    const string Release67CubePath="Assets/Comparison/CurrentRelease67Environment.asset";
    [Serializable] sealed class Release67FileChange
    {
        public string path,guidBefore,guidAfter,sha256Before,sha256After;
        public bool existsBefore,existsAfter;
        public long bytesBefore,bytesAfter;
    }
    [Serializable] sealed class Release67CubeReceipt
    {
        public string status,error,unity,featureType,featureAssetPath,featureGuid,cubeAssetPath,cubeGuid;
        public long featureLocalId,cubeLocalId;
        public string purpose="Fixed synthetic incident-radiance example for current Feature integration; not a physical sky reference";
        public string lifetime="Persistent build dependency; Feature borrows immutable asset; caller restores temporary project inputs after build";
        public string[] faceOrder;
        public Color[] faceValues;
        public string format,graphicsFormat,filterMode,wrapMode;
        public int width,height,mipCount;
        public bool linear,allStoredTexelsMatch,bindingDependencyPresent,originalEnvironmentWasNull;
        public Release67FileChange[] files;
    }
    static string Release67AssetPath(string path)
    {return path.EndsWith(".meta",StringComparison.Ordinal)?path.Substring(0,path.Length-5):path;}
    static Release67FileChange Release67Before(string path)
    {
        bool exists=File.Exists(path);byte[] bytes=exists?File.ReadAllBytes(path):null;
        return new Release67FileChange{path=path,existsBefore=exists,bytesBefore=exists?bytes.LongLength:0,
            sha256Before=exists?Hash(bytes):null,guidBefore=AssetDatabase.AssetPathToGUID(Release67AssetPath(path))};
    }
    static void Release67SaveReceipt(string path,Release67CubeReceipt r)
    {
        foreach(var f in r.files)
        {
            f.existsAfter=File.Exists(f.path);byte[] bytes=f.existsAfter?File.ReadAllBytes(f.path):null;
            f.bytesAfter=f.existsAfter?bytes.LongLength:0;f.sha256After=f.existsAfter?Hash(bytes):null;
            f.guidAfter=AssetDatabase.AssetPathToGUID(Release67AssetPath(f.path));
        }
        File.WriteAllText(path,JsonUtility.ToJson(r,true));
    }
    static void SetupCurrentRelease67Cube(ComparisonCapture capture,string receiptPath)
    {
        if(!Path.IsPathRooted(receiptPath)||File.Exists(receiptPath)||Directory.Exists(receiptPath))
            throw new Exception("Release67 Cube receipt must be a new absolute file path");
        if(!capture||!capture.feature||capture.feature.GetType()!=typeof(HybridLumenGI.HybridLumenGIRendererFeature))
            throw new Exception("Release67 requires the actual HybridLumenGI Feature");
        var feature=(HybridLumenGI.HybridLumenGIRendererFeature)capture.feature;
        string featureGuid;long featureLocalId;
        if(AssetDatabase.GetAssetPath(feature)!=Release67RendererPath||
            !AssetDatabase.TryGetGUIDAndLocalFileIdentifier(feature,out featureGuid,out featureLocalId)||
            featureGuid!=Release67RendererGuid||featureLocalId!=Release67FeatureLocalId)
            throw new Exception("Release67 capture Feature asset identity differs from frozen Renderer");
        if(!File.Exists(Release67RendererPath)||!File.Exists(Release67RendererPath+".meta")||
            !AssetDatabase.IsValidFolder("Assets/Comparison"))
            throw new Exception("Release67 existing Renderer asset/meta or parent folder is missing");
        if(File.Exists(Release67CubePath)||File.Exists(Release67CubePath+".meta")||
            Directory.Exists(Release67CubePath)||AssetDatabase.LoadMainAssetAtPath(Release67CubePath)||
            !string.IsNullOrEmpty(AssetDatabase.AssetPathToGUID(Release67CubePath,AssetPathToGUIDOptions.OnlyExistingAssets)))
            throw new Exception("Release67 Cube asset path must be absent; do not replace an existing input");
        var settingsField=typeof(HybridLumenGI.HybridLumenGIRendererFeature).GetField("settings",
            System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
        var settings=settingsField==null?null:settingsField.GetValue(feature) as HybridLumenGI.HybridLumenGIRendererFeature.Settings;
        if(settings==null||settings.environmentCubemap!=null)
            throw new Exception("Release67 requires existing settings with the frozen null Cube input");
        var faces=new[]{CubemapFace.PositiveX,CubemapFace.NegativeX,CubemapFace.PositiveY,
            CubemapFace.NegativeY,CubemapFace.PositiveZ,CubemapFace.NegativeZ};
        // Exact Faces values/order from LocalComparison/Harness/StaticEnvironmentCubeEditor.cs.
        var values=new[]{new Color(1,.125f,.25f,1),new Color(.5f,2,.25f,1),new Color(.5f,.25f,3,1),
            new Color(4,.25f,.5f,1),new Color(.25f,5,.5f,1),new Color(.25f,.5f,6,1)};
        var r=new Release67CubeReceipt{status="validated-before-create",unity=Application.unityVersion,
            featureType=feature.GetType().FullName,featureAssetPath=Release67RendererPath,
            featureGuid=featureGuid,featureLocalId=featureLocalId,cubeAssetPath=Release67CubePath,
            originalEnvironmentWasNull=true,faceOrder=faces.Select(f=>f.ToString()).ToArray(),
            faceValues=values,files=new[]{Release67Before(Release67RendererPath),
                Release67Before(Release67RendererPath+".meta"),Release67Before(Release67CubePath),Release67Before(Release67CubePath+".meta")}};
        Directory.CreateDirectory(Path.GetDirectoryName(receiptPath));Release67SaveReceipt(receiptPath,r);
        try
        {
            var cube=new Cubemap(2,TextureFormat.RGBAFloat,false){name="CurrentRelease67Environment",
                filterMode=FilterMode.Bilinear,wrapMode=TextureWrapMode.Clamp};
            for(int i=0;i<faces.Length;i++)cube.SetPixels(new[]{values[i],values[i],values[i],values[i]},faces[i],0);
            cube.Apply(false,false);
            r.format=cube.format.ToString();r.graphicsFormat=cube.graphicsFormat.ToString();
            r.linear=!UnityEngine.Experimental.Rendering.GraphicsFormatUtility.IsSRGBFormat(cube.graphicsFormat);
            r.width=cube.width;r.height=cube.height;r.mipCount=cube.mipmapCount;
            r.filterMode=cube.filterMode.ToString();r.wrapMode=cube.wrapMode.ToString();
            r.allStoredTexelsMatch=Enumerable.Range(0,faces.Length).All(i=>cube.GetPixels(faces[i],0).All(p=>
                p.r==values[i].r&&p.g==values[i].g&&p.b==values[i].b&&p.a==values[i].a));
            if(cube.format!=TextureFormat.RGBAFloat||!r.linear||r.width!=2||r.height!=2||r.mipCount!=1||!r.allStoredTexelsMatch)
                throw new Exception("Release67 Cube differs from the frozen linear RGBAFloat input");
            AssetDatabase.CreateAsset(cube,Release67CubePath);AssetDatabase.SaveAssetIfDirty(cube);
            if(!AssetDatabase.TryGetGUIDAndLocalFileIdentifier(cube,out r.cubeGuid,out r.cubeLocalId)||string.IsNullOrEmpty(r.cubeGuid))
                throw new Exception("Release67 Cube was not saved as a persistent asset");
            r.status="cube-saved-before-binding";Release67SaveReceipt(receiptPath,r);
            settings.environmentCubemap=cube;EditorUtility.SetDirty(feature);AssetDatabase.SaveAssetIfDirty(feature);
            r.bindingDependencyPresent=AssetDatabase.GetDependencies(Release67RendererPath,false).Contains(Release67CubePath);
            if(settings.environmentCubemap!=cube||!r.bindingDependencyPresent||
                !File.Exists(Release67CubePath)||!File.Exists(Release67CubePath+".meta"))
                throw new Exception("Release67 Cube binding was not saved into actual Renderer dependencies");
            r.status="saved-and-bound";Release67SaveReceipt(receiptPath,r);
        }
        catch(Exception e)
        {r.status="failed";r.error=e.ToString();Release67SaveReceipt(receiptPath,r);throw;}
    }

    const string ScenePath="Assets/RuntimeAudit/Functional.unity";
    [Serializable] class Input {public string path,sha256;public long bytes;}
    [Serializable] class Receipt
    {
        public string scene=ScenePath,unity,output,result,executableSha256,configuration,requestedOptions,actualOptions;
        public string inputScope="Existing readable project dependencies, Runtime and harness sources plus project settings/package lock; not a physical radiometry source archive";
        public string[] dependencyRoots,dependenciesWithoutProjectFile;
        public ulong totalBytes;public int errors,warnings;public Input[] inputs;
    }
    static string Arg(string key)
    {var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,key);return i>=0&&i+1<a.Length?a[i+1]:"";}
    static string Hash(byte[] bytes)
    {using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
    public static void Build()
    {
        string output=Arg("-currentPlayerOutput"),receipt=Arg("-currentPlayerReceipt"),configuration=Arg("-currentPlayerConfiguration");
        if(string.IsNullOrEmpty(configuration))configuration="Development";
        if(configuration!="Development"&&configuration!="Release")throw new Exception("Explicit Development or Release configuration required");
        BuildOptions options=configuration=="Release"?BuildOptions.None:BuildOptions.Development;
        if(!Path.IsPathRooted(output)||!Path.IsPathRooted(receipt)||File.Exists(output)||File.Exists(receipt))throw new Exception("New explicit build output and receipt required");
        if(PlayerSettings.colorSpace!=ColorSpace.Linear||PlayerSettings.GetScriptingBackend(NamedBuildTarget.Standalone)!=ScriptingImplementation.Mono2x||
            !PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64).SequenceEqual(new[]{GraphicsDeviceType.Direct3D12}))
            throw new Exception("Existing build settings differ from frozen Windows Mono / DX12 / Linear contract");
        EditorSceneManager.OpenScene(ScenePath,OpenSceneMode.Single);
        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        if(!capture||!capture.feature||!UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>())throw new Exception("Existing functional scene/probe missing");
        SetupCurrentRelease67Cube(capture,@"C:/Users/Administrator/Desktop/test/HybridLumenGI/LocalComparison/Review/continuous-deformation-usage-01/build-correction/cube-setup-receipt.json");
        var projectSettings=new[]{"ProjectSettings/GraphicsSettings.asset","ProjectSettings/QualitySettings.asset"};
        var settingsAssets=projectSettings.SelectMany(p=>Regex.Matches(File.ReadAllText(p),@"guid: ([0-9a-f]{32})").Cast<Match>())
            .Select(m=>AssetDatabase.GUIDToAssetPath(m.Groups[1].Value)).Where(p=>!string.IsNullOrEmpty(p));
        string pipeline=AssetDatabase.GetAssetPath(GraphicsSettings.currentRenderPipeline);
        if(string.IsNullOrEmpty(pipeline))throw new Exception("Actual render pipeline asset missing");
        var roots=settingsAssets.Concat(new[]{ScenePath,pipeline}).Distinct().ToArray();
        var dependencies=AssetDatabase.GetDependencies(roots,true);
        var readable=dependencies.Where(File.Exists).ToArray();
        var paths=readable.Concat(readable.Select(p=>p+".meta").Where(File.Exists))
            .Concat(Directory.GetFiles("Assets/HybridLumenGI/Runtime","*",SearchOption.AllDirectories))
            .Concat(Directory.GetFiles("Assets/HybridLumenGI/Editor","*",SearchOption.AllDirectories))
            .Concat(Directory.GetFiles("Assets/ComparisonHarness","*",SearchOption.AllDirectories))
            .Concat(new[]{"Packages/manifest.json","Packages/packages-lock.json","ProjectSettings/ProjectSettings.asset","ProjectSettings/GraphicsSettings.asset","ProjectSettings/QualitySettings.asset"})
            .Select(p=>p.Replace('\\','/')).Distinct().OrderBy(p=>p,StringComparer.Ordinal).ToArray();
        var inputs=paths.Select(p=>{var bytes=File.ReadAllBytes(p);return new Input{path=p,sha256=Hash(bytes),bytes=bytes.LongLength};}).ToArray();
        Directory.CreateDirectory(Path.GetDirectoryName(output));Directory.CreateDirectory(Path.GetDirectoryName(receipt));
        var r=new Receipt{unity=Application.unityVersion,output=output,result="started",inputs=inputs,configuration=configuration,requestedOptions=options.ToString(),
            dependencyRoots=roots,dependenciesWithoutProjectFile=dependencies.Where(p=>!File.Exists(p)).ToArray()};
        File.WriteAllText(receipt,JsonUtility.ToJson(r,true));
        var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions{scenes=new[]{ScenePath},locationPathName=output,
            target=BuildTarget.StandaloneWindows64,options=options});
        r.actualOptions=report.summary.options.ToString();
        r.result=report.summary.result.ToString();r.errors=(int)report.summary.totalErrors;r.warnings=(int)report.summary.totalWarnings;
        r.totalBytes=report.summary.totalSize;r.executableSha256=File.Exists(output)?Hash(File.ReadAllBytes(output)):null;
        File.WriteAllText(receipt,JsonUtility.ToJson(r,true));
        if(inputs.Any(i=>!File.Exists(i.path)||Hash(File.ReadAllBytes(i.path))!=i.sha256))throw new Exception("Build source changed; retain result but reject source matching");
        if(report.summary.result!=BuildResult.Succeeded||report.summary.totalErrors!=0||report.summary.options!=options)throw new Exception("Current-source Player build failed or options changed");
        Debug.Log("CURRENT_PLAYER_BUILD_SUCCEEDED "+output);
    }
}
