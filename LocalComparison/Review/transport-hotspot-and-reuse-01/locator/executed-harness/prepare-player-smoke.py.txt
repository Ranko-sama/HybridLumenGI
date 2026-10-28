"""Narrow test-player wiring; no scene regeneration or lighting changes."""
import argparse,hashlib,json,subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/current-player-shutdown-01'
OUT=PACKAGE/'instrumentation'
H=ROOT/'LocalComparison/Harness'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def replace(text,old,new):
    assert text.count(old)==1,(old[:80],text.count(old))
    return text.replace(old,new)

def prepare():
    assert not (OUT/'installed.json').exists(),'Unique build installation already used'
    product={p.as_posix():sha(p) for top in ['Runtime','Editor'] for p in Path(top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items()),'Deployment is not current source'
    changed={}
    entry=PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs'
    text=entry.read_text(encoding='utf-8')
    text=replace(text,'        if(Application.isEditor)return;','''        if(Application.isEditor)return;
        if(Array.IndexOf(Environment.GetCommandLineArgs(),"-auditSmoke")>=0 &&
            (Arg("-auditFrames","")!="120" || Arg("-auditScene","functional")!="functional" ||
             (Arg("-comparisonMode","final")!="final"&&Arg("-comparisonMode","final")!="hardware")))
        {
            var invalidCapture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();if(invalidCapture)invalidCapture.enabled=false;
            Debug.LogError("Invalid bounded Player smoke arguments");Application.Quit(1);return;
        }''')
    text=replace(text,'        capture.totalFrames=720;','''        bool smoke=Array.IndexOf(Environment.GetCommandLineArgs(),"-auditSmoke")>=0;
        capture.totalFrames=smoke?120:720;
        if(smoke)capture.quitWhenComplete=true;''')
    changed[entry]=text.encode('utf-8')
    capture=PROJECT/'Assets/ComparisonHarness/ComparisonCapture.cs'
    text=capture.read_text(encoding='utf-8')
    text=replace(text,'    void Finish(bool collected)', '''    public bool AuditOpen=>running && !closing;
    public event Action AuditClosing;
    public bool AuditReceipt(int frame,int engine)=>AuditOpen && receipt && logicalFrame==frame && lastEngine==engine;
    void Finish(bool collected)''')
    text=replace(text,'running = false; RenderPipelineManager.endCameraRendering -= Rendered;',
        'running = false; try{AuditClosing?.Invoke();}catch(Exception e){Fail("Probe close: "+e);} RenderPipelineManager.endCameraRendering -= Rendered;')
    changed[capture]=text.encode('utf-8')
    probe=PROJECT/'Assets/ComparisonHarness/RuntimeAuditProbe.cs'
    text=probe.read_text(encoding='utf-8')
    text=replace(text,'public bool hasSnapshot,emissionEnabled,inlineRT;public string deformationStatus,areaReason;',
        'public bool hasSnapshot,emissionEnabled,inlineRT;public string deformationStatus,areaReason,momentsFormat0,momentsFormat1;')
    text=replace(text,'                var identity=(RTHandle[])Field(state,"receiverIdentity");',
        '                row.momentsFormat0=moments[0].rt.graphicsFormat.ToString();row.momentsFormat1=moments[1].rt.graphicsFormat.ToString();\n                var identity=(RTHandle[])Field(state,"receiverIdentity");')
    text=replace(text,'    void Start()', '''    readonly System.Collections.Generic.HashSet<int> acceptedFrames=new System.Collections.Generic.HashSet<int>();
    bool probeClosed;
    [Serializable] class Payload {public string field,file,sha256,format;public int frame,engineFrame,giFrame,readIndex,width,height;}
    static void WriteNew(string path,byte[] bytes)
    {using(var stream=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.Read))stream.Write(bytes,0,bytes.Length);}
    void CloseProbe(){if(probeClosed)return;probeClosed=true;RenderPipelineManager.endCameraRendering-=Rendered;writer?.Dispose();writer=null;}
    void Start()''')
    text=replace(text,'        RenderPipelineManager.endCameraRendering+=Rendered;',
        '        capture.AuditClosing+=CloseProbe;\n        RenderPipelineManager.endCameraRendering+=Rendered;')
    text=replace(text,'    void Update()\n    {','    void Update()\n    {\n        if(!capture.AuditOpen)return;')
    text=replace(text,'        if(camera!=capture.camera)return;',
        '        if(camera!=capture.camera || !capture.AuditOpen || probeClosed)return;')
    text=replace(text,'        if(writer==null)writer=new StreamWriter(Path.Combine(directory,"functional.jsonl")){AutoFlush=true};', '''        if(!capture.AuditReceipt(f,Time.frameCount))throw new Exception("Probe lacks matching capture receipt");
        if(!acceptedFrames.Add(f))throw new Exception("Duplicate open probe receipt");
        if(writer==null)writer=new StreamWriter(new FileStream(Path.Combine(directory,"functional.jsonl"),FileMode.CreateNew,FileAccess.Write,FileShare.Read)){AutoFlush=true};
        float[] savedMoments=null;''')
    text=replace(text,'        public int frame,publishedFrame,geometryRevision,areaTriangles,materialSources,emissiveSources,validIdentityPixels;',
        '        public int frame,engineFrame,giFrame,readIndex,publishedFrame,geometryRevision,areaTriangles,materialSources,emissiveSources,validIdentityPixels;')
    text=replace(text,'        var row=new Row {frame=f,publishedFrame=',
        '        var row=new Row {frame=f,engineFrame=Time.frameCount,publishedFrame=')
    text=replace(text,'            if(!ReferenceEquals(Field(state,"camera"),camera))continue;',
        '            if(!ReferenceEquals(Field(state,"camera"),camera))continue;\n            row.giFrame=(int)Field(state,"frame");row.readIndex=(int)Field(state,"readIndex");')
    text=replace(text,'                    File.WriteAllBytes(Path.Combine(directory,"denoise-"+f.ToString("D4")+"-"+field+".rgba32f"),request.GetData<byte>().ToArray());', '''                    byte[] bytes=request.GetData<byte>().ToArray();string filename="denoise-"+f.ToString("D4")+"-"+field+".rgba32f";
                    WriteNew(Path.Combine(directory,filename),bytes);
                    if(field=="moments"){savedMoments=new float[bytes.Length/4];Buffer.BlockCopy(bytes,0,savedMoments,0,bytes.Length);}
                    string hash;using(var digest=System.Security.Cryptography.SHA256.Create())hash=BitConverter.ToString(digest.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();
                    var payload=new Payload{field=field,file=filename,sha256=hash,format=texture.graphicsFormat.ToString(),frame=f,engineFrame=Time.frameCount,giFrame=row.giFrame,readIndex=currentRead,width=texture.width,height=texture.height};
                    WriteNew(Path.Combine(directory,filename+".json"),System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(payload)));''')
    text=replace(text,'                    var req=AsyncGPUReadback.Request(moments[read].rt,0,TextureFormat.RGBAFloat);req.WaitForCompletion();\n                    if(req.hasError)throw new Exception("History readback failed");var data=req.GetData<float>();int valid=0;', '''                    var data=savedMoments;
                    if(data==null){var req=AsyncGPUReadback.Request(moments[read].rt,0,TextureFormat.RGBAFloat);req.WaitForCompletion();
                        if(req.hasError)throw new Exception("History readback failed");data=req.GetData<float>().ToArray();}
                    int valid=0;''')
    text=replace(text,'File.WriteAllBytes(Path.Combine(directory,"atlas-"+pair.Item1+".rgba32f"),req.GetData<byte>().ToArray());',
        'WriteNew(Path.Combine(directory,"atlas-"+pair.Item1+".rgba32f"),req.GetData<byte>().ToArray());')
    text=replace(text,'    void OnDestroy(){RenderPipelineManager.endCameraRendering-=Rendered;writer?.Dispose();}',
        '    void OnDestroy(){capture.AuditClosing-=CloseProbe;CloseProbe();}')
    changed[probe]=text.encode('utf-8')
    for source,destination in [('CurrentPlayerBuild.cs','Editor/CurrentPlayerBuild.cs')]:
        changed[PROJECT/'Assets/ComparisonHarness'/destination]=(H/source).read_bytes()
    OUT.mkdir(parents=True,exist_ok=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
              'scene':'Assets/RuntimeAudit/Functional.unity','scope':'single build; one visible software120frame smoke; no hardware or scene regeneration',
              'files':[],'newMetadata':[]}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,
                                  'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        meta=Path(str(path)+'.meta')
        if not meta.exists():manifest['newMetadata'].append(meta.relative_to(PROJECT).as_posix())
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'preparedFiles':len(changed),'productSourceCount':len(product),'testWiringAltersProductRuntime':False,'sceneRegenerated':False}))

def install():
    assert not (OUT/'installed.json').exists(),'Build installation cannot be repeated'
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    for f in m['files']:
        p=PROJECT/f['path'];assert (sha(p) if p.exists() else None)==f['originalSha256'],f['path']
        assert sha(OUT/f['prepared'])==f['sha256']
    (OUT/'installed.json').write_text('{"uniqueBuildInstallation":true}',encoding='utf-8')
    for f in m['files']:
        p=PROJECT/f['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((OUT/f['prepared']).read_bytes())
    print('Unique current-source test Player wiring installed')

def restore():
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'));rows=[]
    for f in m['files']:
        p=(PROJECT/f['path']).resolve();assert p.is_relative_to(PROJECT.resolve())
        if p.exists():
            dest=OUT/'post-build'/f['path'];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(p.read_bytes())
        if f['original'] is None:
            if p.exists():p.unlink()
        else:p.write_bytes((OUT/f['original']).read_bytes())
        rows.append({'path':f['path'],'restored':(sha(p) if p.exists() else None)==f['originalSha256']})
    for rel in m['newMetadata']:
        p=(PROJECT/rel).resolve();assert p.is_relative_to(PROJECT.resolve())
        if p.exists():
            dest=OUT/'post-build'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(p.read_bytes());p.unlink()
    matched=all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in m['productSourceSha256'].items())
    (OUT/'restoration.json').write_text(json.dumps({'files':rows,'currentProductRestored':matched},indent=2),encoding='utf-8')
    assert all(r['restored'] for r in rows) and matched
    print('All deployed test wiring and current product source restored')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);a=p.parse_args();globals()[a.action]()
