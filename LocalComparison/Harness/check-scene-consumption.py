"""Check only the new consumption decoder against already-reviewed saved A events."""
import importlib.util,json
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[2];source=Path(__file__).with_name('analyze-scene-lightoff.py')
spec=importlib.util.spec_from_file_location('scene_analysis',source);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
prior=root/'LocalComparison/Review/gather-cache-visibility-01';directory=prior/'A/20261028-003039-1dfa0103552e4566b52f2c733517f692'
reference=json.loads((prior/'analysis.json').read_text(encoding='utf-8'));analysis=module.Analysis(directory);checked=0
for pixel in reference['pixels']:
 frame=pixel['frame'];lane=pixel['lane'];data=np.fromfile(directory/f'gather-{frame:04d}-events.bin',dtype='<u4').reshape(4,256,32);floats=data.view('<f4').astype(float)
 count=int(data[lane,0,1]);events=[{'code':int(data[lane,i,0]),'context':int(data[lane,i,2]),'call':int(data[lane,i,3]),'f':floats[lane,i,4:].reshape(7,4),'u':data[lane,i,4:].reshape(7,4)} for i in range(1,count)]
 got=analysis.consumption(events,int(events[-1]['u'][1,0]),events[-1]['f'][0],{'patches':[]},{'frame':frame,'lane':lane})
 assert [v['call'] for v in got]==pixel['consumedCalls'],(frame,lane,got,pixel['consumedCalls'])
 checked+=1
assert not analysis.fail,analysis.fail
print(json.dumps({'passed':True,'savedPixelStreams':checked,'consumedCalls':analysis.count['final-radiance-cache-consumed'],'scope':'New offline decoder matches prior reviewed actual-consumption call identities. No new GPU execution, C geometry result or broadened physical claim.'}))
