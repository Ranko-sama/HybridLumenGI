"""Single original first-frame failure attribution; no product decision changes."""
import argparse,ast,hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2];project=Path('I:/Unity test/Project');old=root/'LocalComparison/Review/scene-lightoff-chain-01/instrumentation'
p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);p.add_argument('--variant',choices=['baseline','fixed'],default='baseline');a=p.parse_args()
out=root/f'LocalComparison/Review/early-exit-retirement-01/{a.variant}/instrumentation'
sha=lambda data:hashlib.sha256(data).hexdigest()
old_manifest=json.loads((old/'manifest.json').read_text(encoding='utf-8'))
paths={key:Path(item['path']) for key,item in old_manifest['files'].items()}
paths.update(retirement=project/'Assets/HybridLumenGI/Runtime/HybridLumenGIResourceRetirement.cs',hardware=project/'Assets/HybridLumenGI/Runtime/HybridLumenGIHardwareBackend.cs')
helpers={name:Path(item['path']) for name,item in old_manifest['helpers'].items()}
helpers['EarlyExitRetirementTrace.cs']=project/'Assets/ComparisonHarness/EarlyExitRetirementTrace.cs'
if a.action=='restore':
 m=json.loads((out/'manifest.json').read_text(encoding='utf-8'));checks={}
 for key,path in paths.items():
  assert sha(path.read_bytes())==m['files'][key]['instrumentedSha256'],('Source changed',key)
  path.write_bytes((out/(key+'.original.txt')).read_bytes());checks[key]=sha(path.read_bytes())==m['files'][key]['originalSha256']
 for name,path in helpers.items():
  backup=out/(name+'.original-helper.txt')
  if backup.exists():
   assert sha(path.read_bytes())==m['helpers'][name]['sha256'];path.write_bytes(backup.read_bytes());checks[name]=True
 for index,relative in enumerate(m['assets']):
  path=project/relative;path.write_bytes((out/f'asset-{index}.original.txt').read_bytes());checks[relative]=sha(path.read_bytes())==m['assets'][relative]
 (out/'restoration.json').write_text(json.dumps({'passed':all(checks.values()),'checks':checks},indent=2),encoding='utf-8');assert all(checks.values());print('Baseline attribution source/assets restored');raise SystemExit

def replace(text,old,new,count=1):
 assert text.count(old)==count,(old[:100],text.count(old),count);return text.replace(old,new)

def retirement(text):
 # Reuse only the previous trace's literal transformation data, not its installer.
 tree=ast.parse((root/'LocalComparison/Harness/prepare-retirement-progress.py').read_text(encoding='utf-8'))
 assignments=[n for n in ast.walk(tree) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='changes' for t in n.targets)]
 assert len(assignments)==1
 recipes=ast.literal_eval(assignments[0].value)['retirement']
 for prior,replacement in recipes:
  replacement=replacement.replace('global::RetirementProgressTrace','global::EarlyExitRetirementTrace')
  text=replace(text,prior,replacement,2 if prior.startswith('foreach(var ticket in batch)') else 1)
 text=replace(text,'{outsideRenderLoop=false;contextEnded=false;}','{outsideRenderLoop=false;contextEnded=false;global::EarlyExitRetirementTrace.Record("begin-context");}')
 text=replace(text,'            EnsureRegistered();\n            // EndContext alone','            global::EarlyExitRetirementTrace.Record("idle-enter");\n            EnsureRegistered();\n            // EndContext alone')
 text=replace(text,'            if(contextEnded && !submissionUncertain)outsideRenderLoop=true;',
  '            if(contextEnded && !submissionUncertain)outsideRenderLoop=true;\n            global::EarlyExitRetirementTrace.Record("idle-certified-state");')
 text=replace(text,'{try{withdraw();}catch(Exception error){failedWithdrawals++;Debug.LogException(error);}}',
  '{try{global::EarlyExitRetirementTrace.Record("withdraw-begin",destroy:withdraw);withdraw();global::EarlyExitRetirementTrace.Record("withdraw-returned",destroy:withdraw);}catch(Exception error){failedWithdrawals++;Debug.LogException(error);}}')
 # Record only reads actually reached by the original short circuit evaluation.
 text=text.replace('SystemInfo.supportsGraphicsFence','global::EarlyExitRetirementTrace.FenceSupport(SystemInfo.supportsGraphicsFence,"actual-product-guard")')
 text=replace(text,'            contextEnded=true; // Only a subsequent IdleUpdate may certify outside this event.',
  '            global::EarlyExitRetirementTrace.Record("end-context-enter");\n            try {\n            contextEnded=true; // Only a subsequent IdleUpdate may certify outside this event.')
 boundary='''            finally{CommandBufferPool.Release(command);}
        }
        private static void SubmitImmediate()'''
 text=replace(text,boundary,'''            finally{CommandBufferPool.Release(command);}
            }finally{global::EarlyExitRetirementTrace.Record("end-context-return");}
        }
        private static void SubmitImmediate()''')
 condition='!ticket.submissionUnknown' + (' && !ticket.awaitDetachedPassIdle' if a.variant=='fixed' else '')
 text=replace(text,f'            var batch=new List<Ticket>();foreach(var ticket in pending)if({condition})batch.Add(ticket);',
  f'            var batch=new List<Ticket>();foreach(var ticket in pending){{global::EarlyExitRetirementTrace.Record(({condition})?"context-batch":"context-excluded",ticket,detail:ticket.submissionUnknown?"unknown submission":"context eligibility");if({condition})batch.Add(ticket);}}')
 if a.variant=='fixed':
  text=replace(text,'{ticket.awaitDetachedPassIdle=false;ticket.requiresContext=false;}',
   '{ticket.awaitDetachedPassIdle=false;ticket.requiresContext=false;global::EarlyExitRetirementTrace.Record("detached-pass-idle-eligible",ticket);}')
 text=replace(text,'            var batch=new List<Ticket>();foreach(var ticket in pending)if(!ticket.requiresContext)batch.Add(ticket);',
  '            var batch=new List<Ticket>();foreach(var ticket in pending){global::EarlyExitRetirementTrace.Record(ticket.requiresContext?"idle-excluded":"idle-batch",ticket,detail:ticket.requiresContext?"requiresContext":"eligible idle candidate");if(!ticket.requiresContext)batch.Add(ticket);}')
 # The identical original submitted loop occurs once in each method: fixed labels.
 loop='global::EarlyExitRetirementTrace.Record("submitted",ticket,null,outsideRenderLoop?"idle":"context");'
 assert text.count(loop)==2;text=text.replace(loop,'global::EarlyExitRetirementTrace.Record("submitted",ticket,detail:"context");',1)
 text=replace(text,loop,'global::EarlyExitRetirementTrace.Record("submitted",ticket,detail:"idle");')
 text=replace(text,'            if(!outsideRenderLoop || pending.Count==0 || !global::EarlyExitRetirementTrace.FenceSupport',
  '            global::EarlyExitRetirementTrace.Record("idle-submit-enter");\n            if(!outsideRenderLoop || pending.Count==0 || !global::EarlyExitRetirementTrace.FenceSupport')
 text=replace(text,'catch(Exception){MarkSubmissionUnknown();}',
  'catch(Exception error){global::EarlyExitRetirementTrace.Record("submit-exception",detail:error.GetType().Name);MarkSubmissionUnknown();}',2)
 text=replace(text,'                if(item.failed || !item.ticket.submitted || item.ticket.submissionUnknown)continue;',
  '                if(item.failed || !item.ticket.submitted || item.ticket.submissionUnknown){global::EarlyExitRetirementTrace.Record("progress-ineligible",item.ticket,detail:item.failed?"destroy failed":!item.ticket.submitted?"not submitted":"unknown submission");continue;}')
 text=replace(text,'            foreach(var ticket in pending)\n                if(!ticket.requiresContext && !ticket.submissionUnknown)return true;',
  '            foreach(var ticket in pending){global::EarlyExitRetirementTrace.Record("progress-pending",ticket,detail:ticket.requiresContext?"requiresContext":ticket.submissionUnknown?"unknown submission":"eligible");if(!ticket.requiresContext && !ticket.submissionUnknown)return true;}')
 return text

def feature(text):
 text=replace(text,'        public override void Create()\n        {','        public override void Create()\n        {\n            global::EarlyExitRetirementTrace.EnableAllocationStacks();')
 call='RetireDetachedPass' if a.variant=='fixed' else 'Retire'
 text=replace(text,f'            HybridLumenGIResourceRetirement.{call}(()=>{{oldPass?.Dispose();CoreUtils.Destroy(oldComposite);}});',
  f'            global::EarlyExitRetirementTrace.Owner("Feature.WithdrawForShutdown/pass-and-composite");\n            HybridLumenGIResourceRetirement.{call}(()=>{{oldPass?.Dispose();CoreUtils.Destroy(oldComposite);}});')
 return replace(text,'                HybridLumenGIResourceRetirement.Retire(()=>{nodes.Release();leaves.Release();retiredSoftwareBytes-=bytes;});',
  '                global::EarlyExitRetirementTrace.Owner("CameraState.RetireSoftwareBuffers/nodes+leaves",bytes);\n                HybridLumenGIResourceRetirement.Retire(()=>{nodes.Release();leaves.Release();retiredSoftwareBytes-=bytes;});')

def hardware(text):
 text=replace(text,'public HybridLumenGIHardwareBackend(bool softwareOnly=false) { this.softwareOnly=softwareOnly; }',
  'public HybridLumenGIHardwareBackend(bool softwareOnly=false) { global::EarlyExitRetirementTrace.EnableAllocationStacks();this.softwareOnly=softwareOnly; }')
 text=replace(text,'private void RetireAttributeBuffer(ComputeBuffer buffer)','private void RetireAttributeBuffer(ComputeBuffer buffer,string traceName="resized-attribute")')
 text=replace(text,'            HybridLumenGIResourceRetirement.Retire(()=>{buffer.Release();retiredAttributeBytes-=bytes;});',
  '            global::EarlyExitRetirementTrace.Owner("HardwareBackend/"+(softwareOnly?"software":"hardware")+"/"+traceName,bytes);\n            HybridLumenGIResourceRetirement.Retire(()=>{buffer.Release();retiredAttributeBytes-=bytes;});')
 for name in ['Flags','Instances','Normals','Surface','Bindings','Matrices']:
  text=replace(text,f'RetireAttributeBuffer(old{name});',f'RetireAttributeBuffer(old{name},"{name}");')
 return replace(text,'            HybridLumenGIResourceRetirement.Retire(()=>\n            {',
  '            global::EarlyExitRetirementTrace.Owner("HardwareBackend/acceleration-and-reservation");\n            HybridLumenGIResourceRetirement.Retire(()=>\n            {')

def candidate_feature(text):
 text=replace(text,'            pass?.Dispose(); CoreUtils.Destroy(composite);','            WithdrawForShutdown();')
 text=replace(text,'HybridLumenGIResourceRetirement.Retire(()=>{oldPass?.Dispose();CoreUtils.Destroy(oldComposite);});','HybridLumenGIResourceRetirement.RetireDetachedPass(()=>{oldPass?.Dispose();CoreUtils.Destroy(oldComposite);});')
 return replace(text,'            if(HybridLumenGIResourceRetirement.AdmissionClosed){WithdrawForShutdown();return;}\n            pass?.Dispose();pass=null;CoreUtils.Destroy(composite);composite=null;','            WithdrawForShutdown();')

out.mkdir(parents=True,exist_ok=True);assert not (out/'installed.json').exists(),'Do not reinstall this attribution variant'
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip();assert head.startswith('3241b50')
manifest={'baseline':head,'variant':a.variant,'files':{},'helpers':{},'assets':{},'productSourceSha256':{},'originalFailureTrigger':'frozen chain01 duplicate lanes','additionalCompletionQueries':0}
for relative,expected in old_manifest['productSourceSha256'].items():
 assert expected==sha((project/'Assets/HybridLumenGI'/relative).read_bytes()),('Deployment changed',relative)
 actual=sha((root/relative).read_bytes())
 if a.variant=='baseline' or relative.replace('\\','/') not in ['Runtime/HybridLumenGIRendererFeature.cs','Runtime/HybridLumenGIResourceRetirement.cs']:assert actual==expected,relative
 manifest['productSourceSha256'][relative]=actual
prepared={}
for key,path in paths.items():
 original=path.read_bytes();base=(old/(key+'.instrumented.txt')).read_bytes() if key in old_manifest['files'] else original
 text=base.decode('utf-8').replace('\r\n','\n')
 if a.variant=='fixed':
  if key=='retirement':text=(root/'Runtime/HybridLumenGIResourceRetirement.cs').read_text(encoding='utf-8')
  elif key=='feature':
   assert candidate_feature(original.decode('utf-8').replace('\r\n','\n'))==(root/'Runtime/HybridLumenGIRendererFeature.cs').read_text(encoding='utf-8'),'Candidate feature differs from frozen changes'
   text=candidate_feature(text)
 if key=='retirement':text=retirement(text)
 elif key=='feature':text=feature(text)
 elif key=='hardware':text=hardware(text)
 elif key=='capture':
  text=replace(text,'        if (run.errors != 0) { Finish(false); return; }',
   '        if (run.errors != 0) { Finish(false); return; }\n        if(receipt && logicalFrame==0){global::EarlyExitRetirementTrace.Record("first-receipt-cap",detail:"normal observer Finish drains its existing requests; no synthetic observer error");Finish(false);return;}')
  text=replace(text,'        if (!quitWhenComplete) return;','        global::EarlyExitRetirementTrace.Record("capture-finish-before-exit");\n        if (!quitWhenComplete) return;')
 data=text.replace('\n','\r\n' if b'\r\n' in original else '\n').encode('utf-8')
 backup=out/(key+'.original.txt');assert not backup.exists() or backup.read_bytes()==original;backup.write_bytes(original)
 (out/(key+'.instrumented.txt')).write_bytes(data);prepared[path]=data;manifest['files'][key]={'path':str(path),'originalSha256':sha(original),'instrumentedSha256':sha(data)}
for name,path in helpers.items():
 data=(root/'LocalComparison/Harness'/name).read_bytes() if name=='EarlyExitRetirementTrace.cs' else (old/(name+'.executed.txt')).read_bytes()
 if name in ['SceneLightoffTap.cs','GatherCacheTap.cs']:
  text=data.decode('utf-8');text=replace(text,'records=new GraphicsBuffer(',f'global::EarlyExitRetirementTrace.EnableAllocationStacks();global::EarlyExitRetirementTrace.Record("private-observer-allocation",detail:"{name}");records=new GraphicsBuffer(');data=text.encode('utf-8')
 if path.exists():
  backup=out/(name+'.original-helper.txt');assert not backup.exists() or backup.read_bytes()==path.read_bytes();backup.write_bytes(path.read_bytes())
 (out/(name+'.executed.txt')).write_bytes(data);prepared[path]=data;manifest['helpers'][name]={'path':str(path),'sha256':sha(data),'existed':path.exists()}
for index,relative in enumerate(old_manifest['assets']):
 data=(project/relative).read_bytes();backup=out/f'asset-{index}.original.txt';assert not backup.exists() or backup.read_bytes()==data;backup.write_bytes(data);manifest['assets'][relative]=sha(data)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8');(out/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
if a.action=='install':
 for path,data in prepared.items():path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 (out/'installed.json').write_text(json.dumps({'files':len(prepared),'baseline':head}),encoding='utf-8')
print(json.dumps({'action':a.action,'variant':a.variant,'files':len(prepared),'runtimeEdit':a.variant=='fixed','originalFirstFrameFailurePreserved':True}))
