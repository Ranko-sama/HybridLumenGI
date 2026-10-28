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
