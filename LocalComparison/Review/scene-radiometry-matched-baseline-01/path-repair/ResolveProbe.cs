using System;
using System.IO;
namespace UnityEditor.PackageManager {
    public class PackageInfo {
        public string name="com.unity.render-pipelines.universal",resolvedPath="I:/Unity test/Project/Library/PackageCache/com.unity.render-pipelines.universal@947f725e83ac";
        public static int calls;
        public static PackageInfo FindForAssetPath(string path){calls++;return path=="Packages/com.unity.render-pipelines.universal"||path.StartsWith("Packages/com.unity.render-pipelines.universal/")?new PackageInfo():null;}
    }
}
class Program {
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

    static void Check(bool condition,string message){if(!condition)throw new Exception(message);}
    static void Main(){
        Directory.SetCurrentDirectory("I:/Unity test/Project");
        foreach(string name in new[]{"Packages/manifest.json","Packages/packages-lock.json"})
            Check(Resolve(name)==Path.GetFullPath(name)&&File.Exists(Resolve(name)),"Project-owned manifest path");
        Check(UnityEditor.PackageManager.PackageInfo.calls==0,"Project manifests invoked package lookup");
        var package=new UnityEditor.PackageManager.PackageInfo();
        Check(Resolve("Packages/"+package.name)==package.resolvedPath,"Package root path");
        Check(Resolve("Packages/"+package.name+"/ShaderLibrary/BRDF.hlsl")==Path.Combine(package.resolvedPath,"ShaderLibrary/BRDF.hlsl"),"Package asset path");
        Check(UnityEditor.PackageManager.PackageInfo.calls==2,"Known package resolution count");
        bool failed=false;try{Resolve("Packages/not-installed/file.hlsl");}catch(Exception e){failed=e.Message=="Unresolved package input: Packages/not-installed/file.hlsl";}
        Check(failed&&UnityEditor.PackageManager.PackageInfo.calls==3,"Unknown package must remain failure");
        Console.WriteLine("PASS actual Resolve: two existing project manifests bypass PackageInfo; package root and inner asset resolve; unknown package fails. No Unity process.");
    }
}
