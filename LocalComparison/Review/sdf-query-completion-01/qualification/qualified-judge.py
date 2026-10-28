def judge(data, fixture, stage_name, baseline, flags):
    names = [c['name'] for c in fixture['cases']]
    assert len(data) == len(names)*96, 'Output ABI differs'
    rows = []
    for i, name in enumerate(names):
        values = struct.unpack_from('<4I4f4I4f4I4f', data, i*96)
        rows.append(dict(name=name,query=values[:4],distancePosition=values[4:8],consumers=values[8:12],radiance=values[12:16],extra=values[16:20],cache=values[20:24]))
    r = {v['name']:v for v in rows}
    assert r['definite_hit']['query'][0] == 1 and r['definite_hit']['consumers'][1] == 1, 'Definite hit control'
    assert r['complete_interval_miss']['query'][0] == 0 and r['complete_interval_miss']['consumers'][1] == 1, 'Complete interval miss control'
    if stage_name == 'baseline':
        e = r['exhausted']; assert e['query'][0] == 0 and e['consumers'] == (0,1,0,1) and e['radiance'][:3] == (2,3,4), 'Legal counterexample not established; stop'
        assert e['extra'][3] == 1 and e['cache'][0:3] == (1,1,1), 'Original numeric acceptance not observed'
    else:
        assert flags != 0, 'Candidate unresolved state missing'
        unknown = ['exhausted','farther_known_after_sdf','farther_known_before_sdf','near_segment_unresolved','far_segment_unresolved','screen_after_interval','screen_at_interval_bound']
        for name in unknown:
            v = r[name]
            assert v['query'][0] == 1 and v['query'][1]&flags and v['query'][3] == 0, name+' lost unresolved query'
            assert v['consumers'] == (1,0,1,0) and v['extra'][3] == 0, name+' converted unknown into a measurement'
            assert not v['query'][1] & (2|4|8|16|32|64|128|256|1024), name+' fabricated surface identity'
            assert abs(v['distancePosition'][0]-fixture['domainInterval'][0]) < 2e-5, name+' did not use conservative interval bound'
            assert v['distancePosition'][1:] == (0,0,0), name+' fabricated a position'
        for name in ['nearer_known_after_sdf','nearer_known_before_sdf']:
            assert r[name]['query'][2] == 1 and r[name]['query'][3] == 1 and r[name]['consumers'][3] == 1, name+' lost nearer proven hit'
        s = r['screen_before_interval']; assert s['query'][1]&flags and s['consumers'][3] == 1 and s['radiance'][:3] == (7,8,9), 'Proven closer screen sample rejected'
        assert r['exhausted']['cache'] == (0,0,0,0), 'Unknown cache connection was reweighted or became valid zero bounce'
        prior = {v['name']:v for v in baseline['rows']}
        for name in ['definite_hit','complete_interval_miss','nearer_known_after_sdf','nearer_known_before_sdf']:
            for key in ['query','distancePosition','consumers','radiance','extra']:
                if name in ('nearer_known_after_sdf','nearer_known_before_sdf') and key=='extra':
                    assert prior[name][key][:2]==[0,0], name+' baseline independent SDF did not miss'
                    assert tuple(r[name][key][:2])==(1,1|512|flags), name+' independent SDF did not become unresolved'
                    assert list(r[name][key][2:])==prior[name][key][2:], name+' changed scene representation/cache commit'
                else:
                    assert list(r[name][key]) == prior[name][key], name+' changed proven control '+key
    return rows
