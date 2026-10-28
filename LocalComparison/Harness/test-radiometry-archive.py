"""One real Mono IO check using actual exporter methods and the native-failing asset."""
from pathlib import Path
import hashlib,json,subprocess,sys
sys.stdout.reconfigure(encoding='utf-8')
root=Path(__file__).resolve().parents[2]
source=(root/'LocalComparison/Harness/SceneRadiometryExport.cs').read_text(encoding='utf-8')
hash_method=next(line for line in source.splitlines() if line.strip().startswith('static string Hash(byte[] bytes)'))
file_type=next(line for line in source.splitlines() if '[Serializable] public class FileInput' in line)
resolve=source[source.index('    static string Resolve(string path)'):source.index('    static MaterialInput Material(')]
archive=source[source.index('    static FileInput Archive(string path)'):source.index('    public static void Play()')]
out=root/'LocalComparison/Review/scene-radiometry-matched-baseline-02/archive-repair'
out.mkdir(parents=True,exist_ok=True)
program='''using System;using System.IO;using System.Linq;using System.Security.Cryptography;
namespace UnityEditor.PackageManager {public class PackageInfo{
 public string name="com.unity.render-pipelines.core",resolvedPath="I:/Unity test/Project/Library/PackageCache/com.unity.render-pipelines.core@8d821d79e4bc";
 public static PackageInfo FindForAssetPath(string path){return path.StartsWith("Packages/com.unity.render-pipelines.core/")?new PackageInfo():null;}
}}
class Program{
 static string output;
 FILETYPE
 HASH
 RESOLVE
 ARCHIVE
 static void Main(string[] args){
  output=args[0];
  string path="Packages/com.unity.render-pipelines.core/Editor/Settings/PropertyDrawers/RenderPipelineGraphicsSettingsContainerPropertyDrawer.cs.meta";
  var row=Archive(path);byte[] original=File.ReadAllBytes(Resolve(path));string target=Path.Combine(output,row.archive);byte[] stored=File.ReadAllBytes(target);
  if(row.path!=path||row.bytes!=original.LongLength||Hash(stored)!=row.sha256||!stored.SequenceEqual(original)||target.Length>=260)throw new Exception("Actual Mono archive receipt mismatch");
  File.WriteAllText(Path.Combine(output,"receipt.json"),"{\\"passed\\":true,\\"targetLength\\":"+target.Length+",\\"bytes\\":"+row.bytes+",\\"sha256\\":\\""+row.sha256+"\\"}");
  Console.WriteLine("PASS actual exporter Archive via Mono IO: failed-source asset copied/read back, full original path retained, bytes/hash match; target length="+target.Length+"; no Unity process");
 }
}
'''.replace('FILETYPE',file_type).replace('HASH',hash_method).replace('RESOLVE',resolve).replace('ARCHIVE',archive)
cs=out/'ArchiveProbe.cs';cs.write_text(program,encoding='utf-8');exe=out/'ArchiveProbe.exe'
mono=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data/MonoBleedingEdge/bin/mono.exe')
csc=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data/MonoBleedingEdge/lib/mono/msbuild/Current/bin/Roslyn/csc.exe')
outputs=[]
for command in [[str(mono),str(csc),'/nologo','/out:'+str(exe),str(cs)],[str(mono),str(exe),str(out)]]:
 result=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace');outputs.append(result.stdout+result.stderr)
 (out/'output.log').write_text('\n'.join(outputs),encoding='utf-8');print(outputs[-1],end='')
 if result.returncode:raise SystemExit(result.returncode)
(out/'source-hashes.json').write_text(json.dumps({'exporterSha256':hashlib.sha256(source.encode()).hexdigest(),
 'actualArchiveMethodSha256':hashlib.sha256(archive.encode()).hexdigest(),'UnityStarted':False},indent=2),encoding='utf-8')
