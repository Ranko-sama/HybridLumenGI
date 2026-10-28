using System;using System.IO;using System.Linq;using System.Security.Cryptography;
namespace UnityEditor.PackageManager {public class PackageInfo{
 public string name="com.unity.render-pipelines.core",resolvedPath="I:/Unity test/Project/Library/PackageCache/com.unity.render-pipelines.core@8d821d79e4bc";
 public static PackageInfo FindForAssetPath(string path){return path.StartsWith("Packages/com.unity.render-pipelines.core/")?new PackageInfo():null;}
}}
class Program{
 static string output;
     [Serializable] public class FileInput {public string path,sha256,archive; public long bytes;}
     static string Hash(byte[] bytes){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
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

 static void Main(string[] args){
  output=args[0];
  string path="Packages/com.unity.render-pipelines.core/Editor/Settings/PropertyDrawers/RenderPipelineGraphicsSettingsContainerPropertyDrawer.cs.meta";
  var row=Archive(path);byte[] original=File.ReadAllBytes(Resolve(path));string target=Path.Combine(output,row.archive);byte[] stored=File.ReadAllBytes(target);
  if(row.path!=path||row.bytes!=original.LongLength||Hash(stored)!=row.sha256||!stored.SequenceEqual(original)||target.Length>=260)throw new Exception("Actual Mono archive receipt mismatch");
  File.WriteAllText(Path.Combine(output,"receipt.json"),"{\"passed\":true,\"targetLength\":"+target.Length+",\"bytes\":"+row.bytes+",\"sha256\":\""+row.sha256+"\"}");
  Console.WriteLine("PASS actual exporter Archive via Mono IO: failed-source asset copied/read back, full original path retained, bytes/hash match; target length="+target.Length+"; no Unity process");
 }
}
