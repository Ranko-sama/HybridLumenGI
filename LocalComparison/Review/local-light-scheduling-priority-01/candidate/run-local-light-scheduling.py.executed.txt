"""Finite real light-event construction and actual scheduler source comparison."""
import argparse, importlib.util, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';R=ROOT/'Runtime'
OUT=ROOT/'LocalComparison/Review/local-light-scheduling-priority-01'
spec=importlib.util.spec_from_file_location('prior',H/'run-screen-receive-shadows-source.py');prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
sha=prior.sha;extract=prior.extract
PROJECT='<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'

def execute(folder,name,project,args,commands):
    cmd=['dotnet','run','--project',str(project),'--configuration','Release','--verbosity','quiet','--']+list(map(str,args))
    r=subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace')
    (folder/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
    commands.append(dict(name=name,arguments=cmd,exitCode=r.returncode))
    (folder/'commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
    assert r.returncode==0,(name,r.returncode,r.stdout,r.stderr)

def main(stage):
    folder=OUT/stage;folder.mkdir(exist_ok=False);source=folder/'source';source.mkdir()
    for p in [Path(__file__),H/'LocalLightEvents.cs.txt',H/'LocalLightScheduling.cs.txt',H/'run-screen-receive-shadows-source.py',ROOT/'Documentation/Checkpoint-Iteration48.md']:
        (folder/(p.name+'.executed.txt')).write_bytes(p.read_bytes())
    for name in ['HybridLumenGIScene','HybridLumenGISceneBvh','HybridLumenGICacheScheduler','HybridLumenGIHlodReadiness','HybridLumenGIRendererFeature','HybridLumenGILights','HybridLumenGILightRelevance']:
        (source/(name+'.cs.txt')).write_bytes((R/(name+'.cs')).read_bytes())
    commands=[]
    eventFile=folder/'events.json'
    if stage=='baseline':
        eventProject=folder/'event-project';eventProject.mkdir()
        for name in ['HybridLumenGILights','HybridLumenGILightRelevance']:(eventProject/(name+'.cs')).write_bytes((source/(name+'.cs.txt')).read_bytes())
        (eventProject/'UnityStubs.cs').write_bytes((ROOT/'Tests/StandaloneLighting/UnityStubs.cs.txt').read_bytes())
        (eventProject/'Program.cs').write_bytes((H/'LocalLightEvents.cs.txt').read_bytes())
        (eventProject/'Events.csproj').write_text(PROJECT,encoding='utf-8')
        execute(folder,'actual-light-events',eventProject/'Events.csproj',[eventFile],commands)
    else:
        for name in ['run-local-light-scheduling.py','LocalLightEvents.cs.txt','LocalLightScheduling.cs.txt','run-screen-receive-shadows-source.py']:
            assert (folder/(name+'.executed.txt')).read_bytes()==(OUT/'baseline'/(name+'.executed.txt')).read_bytes()
        eventFile.write_bytes((OUT/'baseline/events.json').read_bytes())
        assert json.loads((OUT/'baseline/result.json').read_text())['passed']
    project=folder/'scheduler-project';project.mkdir()
    for name in ['HybridLumenGIScene','HybridLumenGISceneBvh','HybridLumenGICacheScheduler','HybridLumenGIHlodReadiness']:(project/(name+'.cs')).write_bytes((source/(name+'.cs.txt')).read_bytes())
    for name in ['UnityStubs','SceneDependencies']:(project/(name+'.cs')).write_bytes((ROOT/('Tests/StandaloneBvh/'+name+'.cs.txt')).read_bytes())
    surface=(ROOT/'Tests/StandaloneBvh/SchedulerProgram.cs.txt').read_text(encoding='utf-8')
    (project/'SurfaceAdapter.cs').write_text(surface[surface.index('namespace HybridLumenGI'):],encoding='utf-8')
    data=extract((source/'HybridLumenGILights.cs.txt').read_text(encoding='utf-8'),r'^\s*public struct Data :')
    (project/'ActualLightData.cs').write_text('using UnityEngine; namespace HybridLumenGI { public class HybridLumenGILights {\n'+data+'\n}}',encoding='utf-8')
    method=extract((source/'HybridLumenGIRendererFeature.cs.txt').read_text(encoding='utf-8'),r'^\s*private void AddLightChange\(')
    (project/'ActualFeatureRange.cs').write_text('using UnityEngine; using HybridLumenGI; public partial class FeatureContext {\n'+method+'\n}',encoding='utf-8')
    (project/'Program.cs').write_bytes((H/'LocalLightScheduling.cs.txt').read_bytes())
    (project/'Scheduling.csproj').write_text(PROJECT,encoding='utf-8')
    manifests=[dict(path=str(p.relative_to(folder)),sha256=sha(p)) for p in folder.rglob('*') if p.is_file() and (p.suffix in ['.cs','.txt','.csproj'] or p.name=='events.json') and 'obj' not in p.parts and 'bin' not in p.parts]
    (folder/'source-manifest.json').write_text(json.dumps(manifests,indent=2),encoding='utf-8')
    execute(folder,'actual-scheduler',project/'Scheduling.csproj',[stage,eventFile,folder/'result.json'],commands)
    result=json.loads((folder/'result.json').read_text())
    result.update(inputSha256=sha(eventFile),compiledSchedulerSha256=sha(project/'HybridLumenGICacheScheduler.cs'),actualRangeMethodSha256=sha(project/'ActualFeatureRange.cs'),commands=commands,unityExecuted=False,
                  scope='Actual unchanged light collector once; actual Scene/Scheduler and extracted AddLightChange. Explicit existing Unity/surface adapters and GPU change-domain call recorder; not Unity/RenderGraph/GPU runtime.')
    (folder/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['rows','commands']}))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['baseline','candidate']);main(parser.parse_args().stage)
