"""One bounded actual-CSTrace observer. No workspace Runtime edits."""
import argparse, hashlib, json, shutil, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
assets=Path('I:/Unity test/Project/Assets')
out=root/'LocalComparison/Review/gather-cache-visibility-01/instrumentation'
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);args=p.parse_args()
paths={
 'feature':assets/'HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs',
 'transport':assets/'HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl',
 'kernels':assets/'HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl',
 'wrapper':assets/'HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIExactSoftware.compute',
 'capture':assets/'ComparisonHarness/ComparisonCapture.cs'}
asset_paths=['Comparison/Renderer.asset','Comparison/Pipeline.asset','ComparisonScene/Run/Validation.unity','ThinWallProbe/Static.unity']
if args.action=='restore':
 m=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
 for key,path in paths.items():
  assert sha(path.read_bytes())==m['files'][key]['instrumentedSha256'],('Changed instrumented file',path)
  path.write_bytes((out/(key+'.original.txt')).read_bytes())
 for i,name in enumerate(asset_paths): (assets/name).write_bytes((out/f'asset-{i}.original.txt').read_bytes())
 print('Original source and test assets restored');raise SystemExit

def replace(s,old,new):
 assert s.count(old)==1,(old[:100],s.count(old))
 return s.replace(old,new)
def transport(s):
 s=replace(s,'#define HLGI_TRANSPORT_INCLUDED','#define HLGI_TRANSPORT_INCLUDED\n#include "GatherTraceWriter.hlsl"')
 start=s.index('bool HLGICachedSurface(');end=s.index('bool HLGICachedSample(',start);b=s[start:end]
 b=replace(b,'    result=(HLGICacheEntry)0;','    GCCALL();\n    result=(HLGICacheEntry)0;')
 b=replace(b,'    float2 uv;', '''    GCV(100,float4(position,_HLGI_RayBias),float4(geometricNormal,0),float4(shadingNormal,0),p.identity,
        asfloat(uint4(surface.cardIndex,surface.generation,surface.ownerSlot,_HLGI_Epoch)),float4(surface.position,0),float4(surface.normal,0));
    float2 uv;''')
 b=replace(b,'if(!HLGISurfaceCardUv(surface.cardIndex,position,uv)) return false;',
    'if(!HLGISurfaceCardUv(surface.cardIndex,position,uv)) { GCU(120,uint4(0,1,0,0));return false; }')
 b=replace(b,'    float2 fraction=frac(patchPosition); float totalWeight=0;',
    '    float2 fraction=frac(patchPosition); float totalWeight=0;\n    GCV(101,float4(uv,fraction),float4(baseCell,_HLGI_CacheGrid,0),0,0,0,0,0);')
 b=replace(b,'if(any(cell<0)||any(cell>=_HLGI_CacheGrid)) continue;',
    'if(any(cell<0)||any(cell>=_HLGI_CacheGrid)) { GCU(114,uint4(tap,1,0,0));continue; }')
 b=replace(b,'        HLGICacheEntry e=_HLGI_CacheRead[entry];', '''        HLGICacheEntry e=_HLGI_CacheRead[entry];
        GCV(110,e.irradiance,e.tag,e.anchor,e.normal,e.guide,asfloat(uint4(entry,tap,cell)),0);''')
 b=replace(b,'if(any(e.tag.xyz != float3(p.identity.xy,_HLGI_Epoch)) || !HLGIHasCacheMeasurement(e.irradiance,e.guide)) continue;',
    'if(any(e.tag.xyz != float3(p.identity.xy,_HLGI_Epoch)) || !HLGIHasCacheMeasurement(e.irradiance,e.guide)) { GCU(114,uint4(tap,2,0,0));continue; }')
 b=replace(b,'if(e.tag.w!=(float)surface.generation) continue;',
    'if(e.tag.w!=(float)surface.generation) { GCU(114,uint4(tap,3,0,0));continue; }')
 b=replace(b,'        // Shading normals compare lighting orientation;',
    '        GCV(111,float4(delta,0),float4(anchorGeometricNormal,0),0,0,0,0,0);\n        // Shading normals compare lighting orientation;')
 b=replace(b,'abs(dot(delta,anchorGeometricNormal))>max(_HLGI_RayBias*2,0.03)) continue;',
    'abs(dot(delta,anchorGeometricNormal))>max(_HLGI_RayBias*2,0.03)) { GCU(114,uint4(tap,4,0,0));continue; }')
 b=replace(b,'        if(separation>0.0002)',
    '        GCV(112,float4(visibilityOrigin,separation),float4(visibilityTarget,separation-0.0001),asfloat(uint4(tap,separation>0.0002,0,0)),0,0,0,0);\n        if(separation>0.0002)')
 b=replace(b,'''            if(TraceSceneVisibilityHit(visibilityOrigin,connection/separation,separation-0.0001,
                HLGIPointQueryFootprint(),float4(position,1),blocker)) continue;''',
    '''            float3 gcVisibilityDirection=connection/separation;
            GCV(116,float4(gcVisibilityDirection,separation-0.0001),0,0,0,0,0,0);
            bool gcBlocked=TraceSceneVisibilityHit(visibilityOrigin,gcVisibilityDirection,separation-0.0001,
                HLGIPointQueryFootprint(),float4(position,1),blocker);
            GCH(113,gcBlocked,blocker);
            if(gcBlocked) { GCU(114,uint4(tap,5,0,0));continue; }''')
 b=replace(b,'        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;',
    '        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;\n        GCV(115,float4(weight,totalWeight,tap,0),result.irradiance,result.guide,0,0,0,0);\n        GCU(114,uint4(tap,6,0,0));')
 b=replace(b,'if(totalWeight<=1e-5) return false;',
    'if(totalWeight<=1e-5) { GCV(121,result.irradiance,result.guide,float4(totalWeight,0,0,0),0,0,0,0);GCU(120,uint4(0,2,0,0));return false; }')
 b=replace(b,'    return true;',
    '    GCV(121,result.irradiance,result.guide,float4(totalWeight,0,0,0),0,0,0,0);GCU(120,uint4(1,0,0,0));\n    return true;')
 s=s[:start]+b+s[end:]
 # Returning endpoint: material and direct light are the actual evaluated values.
 s=replace(s,'    float3 value=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(direct+ao*_HLGI_BounceFeedback*max(cached.irradiance.rgb,0));',
 '''    float3 value=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(direct+ao*_HLGI_BounceFeedback*max(cached.irradiance.rgb,0));
    GCV(50,float4(diffuse,ao),float4(emission,emissionWeight),float4(direct,_HLGI_BounceFeedback),cached.irradiance,
        float4(value,confidence),float4(shadingNormal,materialResolved),float4(biasNormal,receivesShadows));''')
 return s

def kernels(s):
 start=s.index('bool TraceScreen(');end=s.index('[numthreads(8,8,1)]\nvoid CSTrace',start);b=s[start:end]
 b=b.replace('return false;','{ GCU(33,uint4(0,0,0,0));return false; }')
 b=replace(b,'                    distanceHit=surfaceT;',
 '''                    distanceHit=surfaceT;
                    GCV(30,float4(p,surfaceT),float4(n,hasGeometry),float4(biasNormal,worldMatch),diffuse,emission,float4(direct,directKnown),float4(uv,0,0));
                    if(worldMatch){GCH(31,true,match);}''')
 b=replace(b,'if(!directKnown) { known=false;return true; }',
    'if(!directKnown) { known=false;GCU(33,uint4(1,0,0,0));return true; }')
 # Extract only the returned value, retaining the same multiplication/addition order.
 b=replace(b,'                        radiance+=diffuse.rgb*materialAO*_HLGI_BounceFeedback*CachedIrradiance(match,n);',
 '''                        float3 gcCached=CachedIrradiance(match,n);
                        radiance+=diffuse.rgb*materialAO*_HLGI_BounceFeedback*gcCached;
                        GCV(32,float4(gcCached,materialAO),float4(radiance,_HLGI_BounceFeedback),0,0,0,0,0);''')
 b=replace(b,'                    known=all(isfinite(radiance));return true;',
    '                    known=all(isfinite(radiance));GCV(34,float4(radiance,known),0,0,0,0,0,0);GCU(33,uint4(1,known,0,0));return true;')
 s=s[:start]+b+s[end:]
 start=s.index('void CSTrace(');end=s.index('[numthreads(8,8,1)]',start);b=s[start:end]
 b=replace(b,'    uint2 fullPixel=', '    GCSTART(id.xy);GCCTX(1u);\n    uint2 fullPixel=')
 b=replace(b,'_HLGI_MaterialOut[id.xy]=0; return;', '_HLGI_MaterialOut[id.xy]=0; GCFINISH(float4(0,0,0,0),0u);return;')
 b=replace(b,'    _HLGI_GeometryOut[id.xy]=HLGIPackScreenGeometry(n,geometricNormal,hasGeometry,depth);',
 '''    _HLGI_GeometryOut[id.xy]=HLGIPackScreenGeometry(n,geometricNormal,hasGeometry,depth);
    GCV(10,float4(p,depth),float4(n,hasGeometry),float4(geometricNormal,0),material,receiverCache.guide,
        float4(_HLGI_Rays,_HLGI_RayBias,_HLGI_BounceFeedback,_HLGI_GuideWeight),float4(_HLGI_AreaEmitterCount,_HLGI_NativeComposition,_HLGI_RadianceClamp,0));''')
 b=replace(b,'        float sampleWeight;', '        GCCTX(100u+r*10u);\n        float sampleWeight;')
 b=replace(b,'        if(!all(isfinite(dir)))',
    '        GCV(20,float4(origin,sampleWeight),float4(dir,_HLGI_MaxDistance),0,0,0,0,0);\n        if(!all(isfinite(dir)))')
 b=replace(b,'        float3 incoming=0; float screenT;bool screenKnown;',
    '        if(sampleWeight>0){GCH(21,worldHit,hit);}\n        float3 incoming=0; float screenT;bool screenKnown;')
 b=replace(b,'            sampleConfidence=screenKnown?1:0;',
    '            { sampleConfidence=screenKnown?1:0;GCU(23,uint4(1,0,0,0)); }')
 b=replace(b,'        else if(worldHit)\n        {',
    '        else if(worldHit)\n        {\n            GCCTX(101u+r*10u);GCU(23,uint4(2,0,0,0));')
 b=replace(b,'else if(sampleWeight>0) { incoming=_HLGI_Environment.rgb;sampleConfidence=0.25; }',
    'else if(sampleWeight>0) { incoming=_HLGI_Environment.rgb;sampleConfidence=0.25;GCU(23,uint4(3,0,0,0)); }\n        else { GCU(23,uint4(4,0,0,0)); }')
 b=replace(b,'        if(!HLGIHasRadianceMeasurement(float4(incoming,sampleConfidence)) ||',
    '        GCV(24,float4(incoming,sampleConfidence),float4(sum,sampleWeight),0,0,0,0,0);\n        if(!HLGIHasRadianceMeasurement(float4(incoming,sampleConfidence)) ||')
 b=replace(b,'        HLGIAreaSample lightSample;',
    '        GCV(25,float4(sum,confidence),0,0,0,0,0,0);\n        GCCTX(102u+r*10u);\n        HLGIAreaSample lightSample;')
 b=replace(b,'        if(lightStatus==HLGI_AREA_UNKNOWN)',
    '        GCU(40,uint4(lightStatus,0,0,0));\n        if(lightStatus==HLGI_AREA_SAMPLE){GCV(44,float4(lightSample.position,lightSample.distance),float4(lightSample.direction,lightSample.pdf),0,0,0,0,0);}\n        if(lightStatus==HLGI_AREA_UNKNOWN)')
 b=replace(b,'            float3 screenValue;float lightScreenT;bool lightScreenKnown;',
    '            GCV(41,float4(lightValue,lightKnown),0,0,0,0,0,0);GCH(45,lightWorldHit,lightHit);\n            float3 screenValue;float lightScreenT;bool lightScreenKnown;')
 b=replace(b,'                lightValue=0;lightKnown=lightScreenKnown;',
    '                lightValue=0;lightKnown=lightScreenKnown;GCU(42,uint4(1,lightScreenKnown,0,0));')
 b=replace(b,'            if(!lightKnown || !HLGIAccumulateRadianceSample(lightValue,1,1,sum)) { estimateKnown=false;break; }',
    '            GCV(43,float4(lightValue,lightKnown),float4(sum,0),0,0,0,0,0);\n            if(!lightKnown || !HLGIAccumulateRadianceSample(lightValue,1,1,sum)) { estimateKnown=false;break; }\n            GCV(46,float4(sum,0),0,0,0,0,0,0);')
 b=replace(b,'        confidence+=sampleConfidence;',
    '        confidence+=sampleConfidence;GCV(26,float4(sum,confidence),0,0,0,0,0,0);')
 b=replace(b,'    _HLGI_Output[id.xy]=estimateKnown?float4(sum/max(_HLGI_Rays,1),confidence/max(_HLGI_Rays,1)):float4(0,0,0,-1);',
    '    float4 gcRaw=estimateKnown?float4(sum/max(_HLGI_Rays,1),confidence/max(_HLGI_Rays,1)):float4(0,0,0,-1);\n    _HLGI_Output[id.xy]=gcRaw;GCFINISH(gcRaw,estimateKnown?1u:2u);')
 return s[:start]+b+s[end:]

def feature(s):
 s=replace(s,'                    Copy(work,data);',
    '                    Copy(work,data);\n                    if(global::GatherCacheTap.Enabled)builder.UseBuffer(graph.ImportBuffer(global::GatherCacheTap.Records),AccessFlags.ReadWrite);')
 s=replace(s,'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);',
 '''                if(global::GatherCacheTap.Enabled)global::GatherCacheTap.Begin(cmd,c,trace,state.camera,d.frame,state.exactSoftwareGeometry);
                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);
                if(global::GatherCacheTap.Enabled)global::GatherCacheTap.Read(cmd,((RTHandle)d.raw).rt,state,state.camera,d.frame,d.invVP);''')
 return s

out.mkdir(parents=True,exist_ok=True)
prepared={};manifest={'baseline':subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip(),'files':{},'productSourceSha256':{}}
assert manifest['baseline'].startswith('1647a88'),'Frozen baseline changed'
for source in (root/'Runtime').rglob('*'):
 if source.suffix not in ['.cs','.hlsl','.shader','.compute']:continue
 deployed=assets/'HybridLumenGI'/source.relative_to(root)
 assert source.read_bytes()==deployed.read_bytes(),('Deployment mismatch',source)
 manifest['productSourceSha256'][str(source.relative_to(root))]=sha(source.read_bytes())
for key,path in paths.items():
 original=path.read_bytes();text=original.decode('utf-8').replace('\r\n','\n')
 if key=='transport':text=transport(text)
 elif key=='kernels':text=kernels(text)
 elif key=='feature':text=feature(text)
 elif key=='wrapper':text=replace(text,'#pragma kernel CSTrace','#pragma kernel CSTrace HLGI_GATHER_AUDIT')
 else:text=replace(text,'            if (pending) { readback.WaitForCompletion();',
    '            try { GatherCacheTap.Finish(collected); } catch(Exception error) { Fail("Gather observer close: "+error); }\n            if (pending) { readback.WaitForCompletion();')
 data=text.replace('\n','\r\n' if b'\r\n' in original else '\n').encode('utf-8')
 prepared[key]=(original,data)
 manifest['files'][key]={'path':str(path),'originalSha256':sha(original),'instrumentedSha256':sha(data)}
for key,(original,data) in prepared.items():
 backup=out/(key+'.original.txt');assert not backup.exists() or backup.read_bytes()==original
 backup.write_bytes(original);(out/(key+'.instrumented.txt')).write_bytes(data)
 if args.action=='install':paths[key].write_bytes(data)
for i,name in enumerate(asset_paths):
 backup=out/f'asset-{i}.original.txt'
 assert not backup.exists() or backup.read_bytes()==(assets/name).read_bytes()
 backup.write_bytes((assets/name).read_bytes())
for name,destination in {'GatherTraceWriter.hlsl':'HybridLumenGI/Runtime/Resources/HybridLumenGI/GatherTraceWriter.hlsl','GatherCacheTap.cs':'ComparisonHarness/GatherCacheTap.cs','GatherCacheEditor.cs':'ComparisonHarness/Editor/GatherCacheEditor.cs'}.items():
 source=root/'LocalComparison/Harness'/name
 if not source.exists():assert args.action=='prepare';continue
 manifest['files'][name]={'path':str(assets/destination),'sha256':sha(source.read_bytes())}
 (out/(name+'.executed.txt')).write_bytes(source.read_bytes())
 if args.action=='install':shutil.copy2(source,assets/destination)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps({'action':args.action,'productFiles':len(prepared),'runtimeEdits':False}))
