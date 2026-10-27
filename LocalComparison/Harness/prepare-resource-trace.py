"""Archive and install/restore attribution-only test-project callbacks."""
import argparse,hashlib,json,shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('action',choices=['install','restore']);p.add_argument('--candidate',action='store_true');p.add_argument('--withdrawal',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[2];project=Path('I:/Unity test/Project/Assets');out=root/('LocalComparison/Review/resource-shutdown-01b/instrumentation' if a.withdrawal else 'LocalComparison/Review/resource-shutdown-01/instrumentation-candidate' if a.candidate else 'LocalComparison/Review/resource-shutdown-01/instrumentation');out.mkdir(parents=True,exist_ok=True)
files={'retirement':project/'HybridLumenGI/Runtime/HybridLumenGIResourceRetirement.cs','feature':project/'HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs','capture':project/'ComparisonHarness/ComparisonCapture.cs'}
sha=lambda b:hashlib.sha256(b).hexdigest()
if a.action=='install':
    changes={
      'retirement':[
       ('owned.Add(new Owned{destroy=destroyOwned,ticket=ticket,prerequisite=prerequisite});','owned.Add(new Owned{destroy=destroyOwned,ticket=ticket,prerequisite=prerequisite});\n            global::ResourceShutdownTrace.Record("enqueue",ticket,destroyOwned,prerequisite);'),
       ('            PollOwned();','            global::ResourceShutdownTrace.Record("end-context-before-poll",null);\n            PollOwned();'),
       ('foreach(var ticket in pending){ticket.fence=fence;ticket.submitted=true;}','foreach(var ticket in pending){ticket.fence=fence;ticket.submitted=true;global::ResourceShutdownTrace.Record("submitted",ticket);}'),
       ('var item=owned[i];if(item.failed || !item.ticket.IsComplete)continue;','var item=owned[i];global::ResourceShutdownTrace.Record("poll",item.ticket,item.destroy,item.prerequisite);if(item.failed || !item.ticket.IsComplete)continue;'),
       ('try{item.destroy();owned.RemoveAt(i);}','try{global::ResourceShutdownTrace.Record("destroy-begin",item.ticket,item.destroy,item.prerequisite);item.destroy();owned.RemoveAt(i);global::ResourceShutdownTrace.Record("destroy-returned",item.ticket);}'),
       ('catch(Exception error){item.failed=true;Debug.LogException(error);}','catch(Exception error){item.failed=true;global::ResourceShutdownTrace.Record("destroy-failed",item.ticket);Debug.LogException(error);}')],
      'feature':[('protected override void Dispose(bool disposing) { pass?.Dispose(); pass=null; CoreUtils.Destroy(composite); }','protected override void Dispose(bool disposing) { global::ResourceShutdownTrace.Mark("feature-dispose-before");pass?.Dispose(); pass=null; CoreUtils.Destroy(composite);global::ResourceShutdownTrace.Mark("feature-dispose-after"); }')],
      'capture':[('        if (!quitWhenComplete) return;','        global::ResourceShutdownTrace.Mark("capture-finish-before-exit");\n        if (!quitWhenComplete) return;')]}
    if a.candidate or a.withdrawal:
        changes['retirement'][1]=('contextEnded=true; // Only a subsequent IdleUpdate may certify outside this event.', 'contextEnded=true; // Only a subsequent IdleUpdate may certify outside this event.\n            global::ResourceShutdownTrace.Record("end-context-before-poll",null);')
        changes['retirement'][2]=('foreach(var ticket in batch){ticket.fence=fence;ticket.submitted=true;pending.Remove(ticket);}', 'foreach(var ticket in batch){ticket.fence=fence;ticket.submitted=true;pending.Remove(ticket);global::ResourceShutdownTrace.Record("submitted",ticket);}')
    if a.withdrawal:
        changes['feature']=[
          ('            oldPass?.StopAdmission();','            oldPass?.StopAdmission();\n            global::ResourceShutdownTrace.Mark("feature-withdraw-detached");'),
          ('            HybridLumenGIResourceRetirement.UnregisterShutdownOwner(WithdrawForShutdown);','            global::ResourceShutdownTrace.Mark("feature-dispose-enter");\n            HybridLumenGIResourceRetirement.UnregisterShutdownOwner(WithdrawForShutdown);')]
        changes['retirement'].extend([
          ('                withdrawing=true;', '                global::ResourceShutdownTrace.Mark("shutdown-admission-closed");\n                withdrawing=true;'),
          ('            DrainShutdown();\n        }', '            DrainShutdown();\n            global::ResourceShutdownTrace.Mark("shutdown-drain-returned");\n        }')])
    m={}
    for label,path in files.items():
        data=path.read_bytes();backup=out/(label+'.original.cs.txt');assert not backup.exists() or backup.read_bytes()==data,'Already instrumented/modified'
        backup.write_bytes(data);s=data.decode('utf-8');nl='\r\n' if b'\r\n' in data else '\n'
        for old,new in changes[label]:
            expected=2 if (a.candidate or a.withdrawal) and old.startswith('foreach(var ticket in batch)') else 1
            assert s.count(old)==expected,(label,old,s.count(old));s=s.replace(old,new.replace('\n',nl))
        instrumented=s.encode('utf-8');path.write_bytes(instrumented);(out/(label+'.instrumented.cs.txt')).write_bytes(instrumented)
        m[label]={'path':str(path),'originalSha256':sha(data),'instrumentedSha256':sha(instrumented)}
    helper=root/'LocalComparison/Harness/ResourceShutdownTrace.cs';shutil.copy2(helper,project/'ComparisonHarness/ResourceShutdownTrace.cs');m['helperSha256']=sha(helper.read_bytes());(out/'helper.executed.cs.txt').write_bytes(helper.read_bytes());(out/'manifest.json').write_text(json.dumps(m,indent=2))
else:
    m=json.loads((out/'manifest.json').read_text())
    for label,path in files.items():
        assert sha(path.read_bytes())==m[label]['instrumentedSha256'],str(path)
        data=(out/(label+'.original.cs.txt')).read_bytes();assert sha(data)==m[label]['originalSha256'];path.write_bytes(data)
print(json.dumps({'action':a.action,'files':list(files),'timingChanged':False}))
