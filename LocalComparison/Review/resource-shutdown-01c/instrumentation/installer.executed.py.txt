"""Install one bounded resource trace. Observe existing reads, never add completion queries."""
import argparse,hashlib,json,shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('action',choices=['install','restore']);a=p.parse_args()
root=Path(__file__).resolve().parents[2];assets=Path('I:/Unity test/Project/Assets');out=root/'LocalComparison/Review/resource-shutdown-01c/instrumentation';out.mkdir(parents=True,exist_ok=True)
files={'retirement':assets/'HybridLumenGI/Runtime/HybridLumenGIResourceRetirement.cs','capture':assets/'ComparisonHarness/ComparisonCapture.cs'}
sha=lambda b:hashlib.sha256(b).hexdigest()
if a.action=='install':
    changes={'retirement':[
      ('get{if(!submitted || submissionUnknown)return false;try{return fence.passed;}catch(Exception){return false;}}',
       'get{if(!submitted || submissionUnknown){global::RetirementProgressTrace.Record("fence-ineligible",this);return false;}try{bool value=fence.passed;global::RetirementProgressTrace.Record("fence-read",this,value?"passed":"not-passed");return value;}catch(Exception error){global::RetirementProgressTrace.Record("fence-query-error",this,"unknown",error.GetType().Name);return false;}}'),
      ('pending.Add(ticket);owned.Add(new Owned{destroy=destroyOwned,ticket=ticket,prerequisite=prerequisite});',
       'pending.Add(ticket);owned.Add(new Owned{destroy=destroyOwned,ticket=ticket,prerequisite=prerequisite});\n            global::RetirementProgressTrace.Record("enqueue",ticket,null,null,destroyOwned,prerequisite);'),
      ('shuttingDown=true;shutdownDeadline=Stopwatch.GetTimestamp()+Stopwatch.Frequency*ShutdownMilliseconds/1000;',
       'shuttingDown=true;shutdownDeadline=Stopwatch.GetTimestamp()+Stopwatch.Frequency*ShutdownMilliseconds/1000;\n                global::RetirementProgressTrace.Record("shutdown-closed");'),
      ('if(owned.Count==0 && pending.Count==0){ReportOtherOwners();return;}',
       'if(owned.Count==0 && pending.Count==0){global::RetirementProgressTrace.Record("drain-empty");ReportOtherOwners();return;}'),
      ('if(!outsideRenderLoop || UnknownSubmissionCount!=0 || FailedCount!=0 || !CanProgressWithoutMainLoop() ||\n                        !SystemInfo.supportsGraphicsFence || Stopwatch.GetTimestamp()>=shutdownDeadline)break;',
       '''if(!outsideRenderLoop){global::RetirementProgressTrace.Record("drain-stop-outside");break;}
                    if(UnknownSubmissionCount!=0){global::RetirementProgressTrace.Record("drain-stop-unknown");break;}
                    if(FailedCount!=0){global::RetirementProgressTrace.Record("drain-stop-failed");break;}
                    if(!CanProgressWithoutMainLoop()){global::RetirementProgressTrace.Record("drain-stop-no-progress");break;}
                    if(!SystemInfo.supportsGraphicsFence){global::RetirementProgressTrace.Record("drain-stop-no-fence-support");break;}
                    if(Stopwatch.GetTimestamp()>=shutdownDeadline){global::RetirementProgressTrace.Record("drain-stop-deadline");break;}'''),
      ('try{if(item.prerequisite==null || item.prerequisite.IsComplete)return true;}\n                catch(Exception){ }',
       'try{bool ready=item.prerequisite==null || item.prerequisite.IsComplete;global::RetirementProgressTrace.Record("progress-prerequisite",item.ticket,ready?"ready":"not-ready",null,null,item.prerequisite);if(ready)return true;}\n                catch(Exception error){global::RetirementProgressTrace.Record("progress-prerequisite-error",item.ticket,"unknown",error.GetType().Name,null,item.prerequisite);}'),
      ('foreach(var ticket in batch){ticket.fence=fence;ticket.submitted=true;pending.Remove(ticket);}',
       'foreach(var ticket in batch){ticket.fence=fence;ticket.submitted=true;pending.Remove(ticket);global::RetirementProgressTrace.Record("submitted",ticket,null,outsideRenderLoop?"idle":"context");}'),
      ('bool ready=false;try{ready=item.prerequisite==null || item.prerequisite.IsComplete;}catch(Exception){ }',
       'bool ready=false;try{ready=item.prerequisite==null || item.prerequisite.IsComplete;global::RetirementProgressTrace.Record("destroy-prerequisite",item.ticket,ready?"ready":"not-ready",null,null,item.prerequisite);}catch(Exception error){global::RetirementProgressTrace.Record("destroy-prerequisite-error",item.ticket,"unknown",error.GetType().Name,null,item.prerequisite);}'),
      ('try{item.destroy();owned.RemoveAt(i);}',
       'try{global::RetirementProgressTrace.Record("destroy-begin",item.ticket,null,null,item.destroy,item.prerequisite);item.destroy();owned.RemoveAt(i);global::RetirementProgressTrace.Record("destroy-returned",item.ticket);}'),
      ('catch(Exception error){item.failed=true;Debug.LogException(error);}',
       'catch(Exception error){item.failed=true;global::RetirementProgressTrace.Record("destroy-failed",item.ticket);Debug.LogException(error);}')],
      'capture':[('        if (!quitWhenComplete) return;','        global::RetirementProgressTrace.Record("capture-finish-before-exit");\n        if (!quitWhenComplete) return;')]}
    prepared={};manifest={}
    for key,path in files.items():
        original=path.read_bytes();backup=out/(key+'.original.cs.txt');assert not backup.exists() or backup.read_bytes()==original,('Already instrumented/changed',path)
        if key=='retirement':assert original==(root/'Runtime/HybridLumenGIResourceRetirement.cs').read_bytes(),'Deployment differs'
        text=original.decode('utf-8').replace('\r\n','\n');nl='\r\n' if b'\r\n' in original else '\n'
        for old,new in changes[key]:
            expected=2 if old.startswith('foreach(var ticket in batch)') else 1
            assert text.count(old)==expected,(key,old[:80],text.count(old));text=text.replace(old,new)
        instrumented=text.replace('\n',nl).encode('utf-8');prepared[key]=(original,instrumented);manifest[key]={'path':str(path),'originalSha256':sha(original),'instrumentedSha256':sha(instrumented)}
    for key,(original,instrumented) in prepared.items():
        (out/(key+'.original.cs.txt')).write_bytes(original);(out/(key+'.instrumented.cs.txt')).write_bytes(instrumented);files[key].write_bytes(instrumented)
    for name,destination in {'RetirementProgressTrace.cs':'ComparisonHarness/RetirementProgressTrace.cs','ResourceProgressEntry.cs':'ComparisonHarness/Editor/ResourceProgressEntry.cs','ThinWallEditor.cs':'ComparisonHarness/Editor/ThinWallEditor.cs'}.items():
        source=root/'LocalComparison/Harness'/name;target=assets/destination;shutil.copy2(source,target);(out/(name+'.executed.txt')).write_bytes(source.read_bytes());manifest[name]={'path':str(target),'sha256':sha(source.read_bytes())}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (out/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
else:
    manifest=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    for key,path in files.items():
        assert sha(path.read_bytes())==manifest[key]['instrumentedSha256'],('Restore mismatch',path)
        original=(out/(key+'.original.cs.txt')).read_bytes();assert sha(original)==manifest[key]['originalSha256'];path.write_bytes(original)
print(json.dumps({'action':a.action,'files':list(files),'additionalCompletionQueries':0}))
