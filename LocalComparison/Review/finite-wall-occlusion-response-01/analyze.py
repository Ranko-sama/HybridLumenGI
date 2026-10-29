"""Prospective finite occluder analysis. Physical expectations precede RGB decode."""
import argparse,json,math,struct,sys
from pathlib import Path
import source_math as model
old=model.old;q=model.qualification;I=model.I
require=old.require;known=old.known;load=old.load;sha=old.sha
CONTEXT={}
def pose_dict(matrix,x):return model.matrix_x([matrix[f'e{r}{c}'] for c in range(4) for r in range(4)],x)
def authored_source(package,source):
    # Unchanged wall/floor/light/settings plus all product, harness and analyzer
    # dependency hashes; the original function does not inspect any GPU RGB.
    receipt=old.source_closure(package,source);s=source['panel']
    expected=[[0,-.1,-2.1],[0,2.1,-2.1],[0,2.1,2.1],[0,-.1,2.1]]
    require([[old.f32(v) for v in old.vec(row)] for row in s['vertices']]==[[old.f32(v) for v in row] for row in expected],'Authored panel vertices differ')
    require(s['triangles']==[0,1,2,0,2,3] and [old.vec(n) for n in s['normals']]==[[1,0,0]]*4,'Panel source winding/normal differs')
    require(pose_dict(s['localToWorld'],20) and old.vec(s['shaderLinearBaseColor'],'xyzw')==[0,0,0,1],'Initial panel source differs')
    require(s['shader']=='Universal Render Pipeline/Lit' and s['metallic']==0 and s['occlusionStrength']==1,'Panel material differs')
    require(old.vec(s['proxyTint'],'rgb')==[1,1,1] and old.vec(s['materialEmission'],'rgb')==old.vec(s['proxyEmission'],'rgb')==[0,0,0],'Panel tint/emission differs')
    require(not any(s[k] for k in ('normalMap','baseMap','emissionMap','occlusionMap','emissionKeyword')),'Panel is not an untextured black source')
    require(source['settings']['nearDistance']==source['settings']['farDistance']==30,'Initial three-owner residency differs')
    require(load(package/'contract-freeze.json')['contractSha256']==sha(package/'contract.txt'),'Original prospective contract changed')
    return receipt
def dirty_panel_bounds(regions):
    results=[]
    for x in (20,.25):
        found=False
        for r in regions:
            if r[3]<1:continue
            if r[0]<=x<=r[4] and r[1]<=old.f32(-.1) and r[5]>=old.f32(2.1) and r[2]<=old.f32(-2.1) and r[6]>=old.f32(2.1):found=True
        require(found,'Actual geometry changes omit old/current panel bounds at x='+str(x));results.append(x)
    return results
def classify_uncovered(report,frame,center,reason):
    report['uncovered'].append(dict(frame=frame,id=center,reason=reason))
def prove_clip(receipt,pixel,node):
    p=q.floor_position(pixel,node['geometry'],receipt)
    w=q.dot([I(receipt['previousVP'][3+4*c]) for c in range(4)],p+[I(1)])
    q.need(w.low>0,'previous clip.w is not proven positive')
def analyze(package):
    native=package/'native';upper=old.bounds()[:12]
    report=dict(passed=False,upperBounds=upper,checks=0,unknown=[],uncovered=[],frames=[],positiveKnownSamples=[0,0],
                expectedZeroFrom='authored ordinary Transform plus independent plane visibility; observed old GPU pose does not exempt known stale raw')
    source=load(native/'scene-inputs.json');report['sourceClosure']=authored_source(package,source)
    selected=load(native/'selection.json');centers=selected['selection'];coordinates=[(p['x'],p['y']) for p in selected['coordinates']];index={p:i for i,p in enumerate(coordinates)}
    require(len(centers)==27 and len(index)==len(coordinates) and selected['rowVectors']==10 and selected['controlVectors']==3,'Compact selection ABI differs')
    result=load(native/'scene-result.json');require(result['status']=='collected' and result['readbacksDrained'],'Native sequence failed')
    require(all(result[n]==56 for n in ('requests','cameraBegins','cameraEnds','contextBegins','contextEnds')),'56 complete callback sequences required')
    require(result['previewCaptures']==3 and result['enterEventApplied'] and result['leaveEventApplied'],'Fixed events/previews missing')
    events={n:load(native/name) for n,name in ((32,'enter-event.json'),(44,'leave-event.json'))}
    for logical,event in events.items():
        require(event['beforeLogicalFrame']==logical and event['lightEnabled'],'Ordinary Transform event receipt differs')
        require(pose_dict(event['before'],20 if logical==32 else .25) and pose_dict(event['after'],.25 if logical==32 else 20),'Transform event endpoints differ')
        require(event['revisionBefore']==event['revisionAfter'],'Event manually advanced the proxy revision')
    responses={phase:{c['id']:dict(firstKnown=None,firstPositive=None,unknownCount=0,endpointKnown=False,sampledWallDirections=0) for c in centers} for phase in ('distant','covered','restored')}
    prior_engine=None;first_vp=None;global_zero=True;previous_geometry_version=None
    for logical in range(56):
        CONTEXT.clear();CONTEXT['logicalFrame']=logical
        phase='distant' if logical<32 else 'covered' if logical<44 else 'restored';offset=logical if logical<32 else logical-32 if logical<44 else logical-44
        stem=native/f'frame-{logical:03d}';r=load(stem.with_suffix('.json'))
        require(r['complete'] and not r.get('error') and r['logicalFrame']==logical and r['phase']==phase and r['lightCount']==1,'Frame receipt incomplete or phase/light changed')
        require(prior_engine is None or r['engineFrame']==prior_engine+1,'Nonconsecutive engine frames');prior_engine=r['engineFrame']
        if logical in events:require(events[logical]['engineFrame']==r['engineFrame'],'Event missed its actual render')
        if first_vp is None:first_vp=r['vp']
        require(r['vp']==first_vp,'Frozen camera VP changed')
        panel=model.qualify_geometry(r,stem.with_suffix('.instances').read_bytes(),stem.with_suffix('.poses').read_bytes(),stem.with_suffix('.triangles').read_bytes(),logical)
        if not panel['current']:classify_uncovered(report,logical,'source','GPU panel pose/generation lags current authored Transform; physical known-raw checks still apply')
        if logical in events and panel['current']:require(r['geometryVersion']>previous_geometry_version,'Pose changed without prepared geometry generation advancing')
        previous_geometry_version=r['geometryVersion']
        data=stem.with_suffix('.bin').read_bytes();controls,input_values=q.decode_inputs(data,len(coordinates));inputs=dict(zip(coordinates,input_values))
        require(controls[2]==(640,360,640,360) and controls[1][0]==old.f32(.08) and controls[1][1]==32 and controls[1][3]==r['workFrame'],'Actual temporal controls differ')
        require(bool(controls[0][0])==r['historyValid'] and bool(controls[1][2])==r['hasMotion'],'Control/receipt validity mismatch')
        change_data=stem.with_suffix('.changes').read_bytes();require(len(change_data)==r['changeCount']*48 and controls[0][3]==r['changeCount'],'Change buffer ABI differs')
        regions=list(struct.iter_unpack('<12f',change_data));require(all(old.finite(region) for region in regions),'Nonfinite change inputs')
        if logical in events:dirty_panel_bounds(regions)
        # These input-only source expectations are formed before numeric RGB decode.
        try:direction_groups={g['id']:g for g in model.qualify_directions(stem.with_suffix('.directions').read_bytes(),r,centers)}
        except (AssertionError,ArithmeticError,ValueError,model.Uncovered) as error:
            direction_groups={};classify_uncovered(report,logical,'sampler','Input direction/source proof unavailable: '+str(error))
        geometry_proofs={};response_qualifications={};support_proofs={}
        for center in centers:
            pixel=(center['x'],center['y']);node=inputs[pixel]
            try:
                pos=q.floor_position(pixel,node['geometry'],r);q.normals(node['geometry'])
                geometry_proofs[center['id']]=old.change_at(pos,controls[0],regions)
                if logical>=32 and logical<=44:
                    prove_clip(r,pixel,node)
                    response_qualifications[center['id']]=q.qualify_one(pixel,{coordinates[i] for i in center['rows']},inputs,r,controls,source['settings'],32 if logical in events else 64+offset)
                if phase=='covered':
                    for dy in (-1,0,1):
                        for dx in (-1,0,1):
                            p=(pixel[0]+dx,pixel[1]+dy);n=inputs[p]
                            # support_block consumes only geometry at row5.
                            model.support_block(p,[None]*5+[n['geometry']],r)
                    support_proofs[center['id']]=True
            except (AssertionError,ArithmeticError,ValueError,model.Uncovered) as error:
                classify_uncovered(report,logical,center['id'],'Independent geometry/support unavailable: '+str(error))
        values=list(struct.iter_unpack('<4f',data));nodes=[values[3+i*10:3+(i+1)*10] for i in range(len(coordinates))]
        if phase=='covered' and not all(known(n[0]) and n[0][:3]==(0,0,0) for n in nodes):global_zero=False
        frame=dict(logical=logical,phase=phase,workFrame=r['workFrame'],panel=panel,geometryVersion=r['geometryVersion'],transformUpdates=r['transformUpdates'],sceneRebuilds=r['sceneRebuilds'],known=0,unknown=0,wallDirections=0,qualifiedResponses=0,historyAgeMin=math.inf,historyAgeMax=0,maxHistoryRGB=0)
        for center in centers:
            id=center['id'];pixel=(center['x'],center['y']);CONTEXT.update(id=id,pixel=pixel)
            raw,hist,mom=nodes[index[pixel]][:3];CONTEXT.update(rawRGBA=list(raw),historyRGBA=list(hist),historyAge=mom[2],gpuPanel=panel);require(old.finite(raw+hist+mom),'Nonfinite measured radiance/history')
            frame['historyAgeMin']=min(frame['historyAgeMin'],mom[2]);frame['historyAgeMax']=max(frame['historyAgeMax'],mom[2]);frame['maxHistoryRGB']=max(frame['maxHistoryRGB'],*hist[:3])
            response=responses[phase][id];group=direction_groups.get(id);floor_proved=id in geometry_proofs
            if group:
                frame['wallDirections']+=group['wallDirections'];response['sampledWallDirections']+=group['wallDirections']
                require(group['depth']==nodes[index[pixel]][5][3],'Sampler and actual gather receiver depth differ')
            if known(raw):
                frame['known']+=1
                if response['firstKnown'] is None:response['firstKnown']=offset
                if logical in (31,43,55):response['endpointKnown']=True
                if max(raw[:3])>0:
                    if response['firstPositive'] is None:response['firstPositive']=offset
                    if phase!='covered':report['positiveKnownSamples'][0 if phase=='distant' else 1]+=1
                if floor_proved and group:
                    model.physical_raw(raw,phase=='covered')
                else:classify_uncovered(report,logical,id,'Known raw physical comparison lacks qualified receiver/direction inputs')
            else:
                frame['unknown']+=1;response['unknownCount']+=1;report['unknown'].append(dict(frame=logical,id=id,confidence=raw[3]))
                if logical in (31,43,55):classify_uncovered(report,logical,id,'Phase endpoint current is unknown')
            if logical==31 and (not known(hist) or mom[2]<=2):classify_uncovered(report,logical,id,'No established warmup history age>2')
            if logical in events and floor_proved:
                hard,reactive=geometry_proofs[id];require(not hard and reactive,'Panel Transform omitted predicted floor reactive influence or produced hard crossing')
            proof=response_qualifications.get(id)
            if logical>=32 and logical<=44:
                if not proof or not proof['qualified']:classify_uncovered(report,logical,id,'History response unavailable: '+(proof.get('reason','input geometry') if proof else 'input geometry'))
                else:
                    frame['qualifiedResponses']+=1
                    if logical in events:require(mom[2]==2,'Admitted reactive history was not shortened to2')
            if phase=='covered' and proof and proof['qualified']:
                closed=global_zero and support_proofs.get(id,False)
                for dy in (-1,0,1):
                    for dx in (-1,0,1):
                        neighbor=nodes[index[(pixel[0]+dx,pixel[1]+dy)]][0]
                        closed&=known(neighbor) and neighbor[:3]==(0,0,0)
                if not closed:classify_uncovered(report,logical,id,'Black-current support premise unavailable; no decay claim')
                else:
                    if offset>0:
                        for p in proof['support']:
                            old_history,old_mom=nodes[index[tuple(p)]][3:5]
                            require(min(old_history[:3])>=0 and max(old_history[:3])<=upper[offset-1],'Previous support exceeds independent black-response envelope')
                            require(old_mom[2]<=offset+1,'Previous history exceeds reactive horizon')
                    require(min(hist[:3])>=0 and max(hist[:3])<=upper[offset],'History exceeds independent black-response envelope')
                    require(0<mom[2]<=offset+2,'Covered history age exceeds reactive horizon')
            report['checks']+=1
        frame['sha256']={ext:sha(stem.with_suffix(ext)) for ext in ('.json','.bin','.changes','.directions','.instances','.poses','.triangles')};report['frames'].append(frame)
    for phase in ('distant','restored'):
        for id,value in responses[phase].items():
            if value['firstPositive'] is None:classify_uncovered(report,55,id,phase+' has no positive source consumption within its fixed budget')
    for id,value in responses['covered'].items():
        if value['sampledWallDirections']==0:classify_uncovered(report,43,id,'No sampled wall-intersecting input direction during the covered phase')
    report['currentResponse']=responses;report['passed']=not report['uncovered'] and all(report['positiveKnownSamples'])
    report['scope']='Current authored rigid occluder visibility and finite floor response; uploaded geometry and counters are not per-ray hit evidence'
    return report
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    require(not args.output.exists(),'Preserve first analysis output')
    try:report=analyze(args.package)
    except Exception as error:report=dict(passed=False,error=str(error),context=CONTEXT,upperBounds=old.bounds()[:12])
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:report.get(k) for k in ('passed','checks','error')}));sys.exit(0 if report['passed'] else 1)
