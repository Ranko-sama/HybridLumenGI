"""Interpret only the recorded original winning paths; never adds transport queries."""
import struct

def inspect_paths(folder,frames,selection):
    def u(data,p):return list(struct.unpack_from('<4I',data,p))
    def f(data,p):return list(struct.unpack_from('<4f',data,p))
    result={'scope':'Two selected receiver pixels and one selected cache lane only; no inference about unobserved scene paths',
        'targetEvaluations':[],'qualifiedTargetPaths':[],'cacheSurfaceInputs':[],'inactiveTraceLanes':[2]}
    for logical in [*range(159,176),191,223,255]:
        frame=frames[logical];upload=next(v for v in frame['uploads'] if v['role']=='target-slot0')
        target=u(bytes(upload['binding32']),16);blob=(folder/f'material-{logical:04d}-actual-paths.bin').read_bytes()
        assert len(blob)==4*256*128
        for lane in [0,1,3]:
            start=lane*256*128;header=u(blob,start);label=u(blob,start+16);count=header[1]
            assert header[2:]==[1,0] and label==[logical,frame['gi'],lane,0x47434131] and 2<=count<=256,'Trace receipt'
            records=[]
            for index in range(1,count):
                p=start+index*128;meta=u(blob,p);assert meta[1]==index
                records.append({'code':meta[0],'context':meta[2],'call':meta[3],
                    'u':[u(blob,p+16+j*16) for j in range(7)],'f':[f(blob,p+16+j*16) for j in range(7)]})
            terminal=records[-1];assert terminal['code']==1
            terminal_known=terminal['u'][1][0]==1 and terminal['f'][0][3]>0
            role='cache' if lane==3 else selection['points'][lane]['role']
            if lane==3:
                for rec in records:
                    if rec['code']!=301:continue
                    owner,generation,card_index,_=rec['u'][0]
                    card=next((c for c in frame['cardsAfter'] if c['index']==card_index),None)
                    result['cacheSurfaceInputs'].append({'logical':logical,'selectedCacheIndex':selection['cacheIndex'],
                        'ownerSlot':owner,'generation':generation,'cardIndex':card_index,'cardIdentity':card,
                        'surfaceDiffuse':rec['f'][2],'surfaceEmission':rec['f'][3],'updateMask':frame['selectedCacheMask']})
            for hit in records:
                if hit['code'] not in [200,31] or hit['u'][0][0]!=1:continue
                a,b=hit['u'][:2]
                if [a[2],a[3],b[0],b[1]]!=target:continue
                context=hit['context'];same=[r for r in records if r['context']==context]
                path={'logical':logical,'lane':lane,'receiverRole':role,'context':context,'call':hit['call'],
                    'targetBindingSource':target,'primitive':b[2],'hardwareInstance':b[3],'terminalKnown':terminal_known}
                qualified=False;value=None;weight=0
                if hit['code']==200:
                    evaluated=next((r for r in same if r['code']==202 and r['call']==hit['call']),None)
                    material=next((r for r in same if r['code']==201 and r['call']==hit['call']),None)
                    path['kind']='proxy';path['radianceEvaluationCompleted']=evaluated is not None
                    if material:path['materialDiffuse']=material['f'][0];path['materialEmission']=material['f'][1]
                    if evaluated:
                        value=evaluated['f'][1][:3];path['radiance']=value
                        if lane==3:
                            incoming=next((r for r in same if r['code']==311 and r['call']==hit['call']),None)
                            commits=[r for r in records if r['code']==312]
                            weight=incoming['f'][1][3] if incoming else 0
                            qualified=bool(incoming and weight>0 and incoming['f'][0][3]>0 and commits and commits[-1]['f'][0][3]>0 and terminal_known)
                        else:
                            incoming=next((r for r in same if r['code']==24 and r['call']==hit['call']),None)
                            winner=any(r['code']==23 and r['u'][0][0]==2 for r in same)
                            weight=incoming['f'][1][3] if incoming else 0
                            qualified=bool(winner and incoming and weight>0 and incoming['f'][0][3]>0 and terminal_known)
                else:
                    path['kind']='screen-world-matched'
                    incoming=next((r for r in same if r['code']==24),None)
                    evaluated=next((r for r in same if r['code']==34 and r['f'][0][3]>0),None)
                    material=next((r for r in same if r['code']==30),None)
                    if material:path['materialDiffuse']=material['f'][3]
                    weight=incoming['f'][1][3] if incoming else 0
                    if evaluated:value=evaluated['f'][0][:3];path['radiance']=value
                    qualified=bool(evaluated and incoming and weight>0 and incoming['f'][0][3]>0 and terminal_known and
                        any(r['code']==23 and r['u'][0][0]==1 for r in same))
                path['sampleWeight']=weight;path['qualifiedWinningPath']=qualified
                path['nonzeroRadiance']=bool(value is not None and any(abs(v)>0 for v in value))
                result['targetEvaluations'].append(path)
                if qualified:result['qualifiedTargetPaths'].append(path)
    result['status']='covered-selected-paths' if result['qualifiedTargetPaths'] else 'uncovered-selected-paths'
    result['nonzeroQualifiedPaths']=sum(p['nonzeroRadiance'] for p in result['qualifiedTargetPaths'])
    result['postEventQualifiedPaths']=sum(p['logical']>=160 for p in result['qualifiedTargetPaths'])
    return result
