"""Post-run local platform restriction correction; preserves actual build input."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'LocalComparison/Review/gpu-cost-baseline-01/native'
p=Path('I:/Unity test/Project/Assets/Plugins/x86_64/HybridLumenGIGpuTiming.dll.meta')
before=p.read_bytes();assert before==(OUT/'PluginImporter.meta').read_bytes()
text=before.decode('utf-8')
for platform in ['Linux64','OSXUniversal']:
    old=f'    {platform}:\n      enabled: 1\n';new=f'    {platform}:\n      enabled: 0\n'
    assert text.count(old)==1; text=text.replace(old,new)
after=text.encode('utf-8');p.write_bytes(after);(OUT/'PluginImporter.local-corrected.meta').write_bytes(after)
report={'actualBuiltImporter':'PluginImporter.meta','actualBuildExclusivePlatforms':False,'actualWindowsX64InclusionValid':True,
        'localCorrection':'Only Linux64 and OSXUniversal enabled flags changed 1 to 0 after the sole build/run; no binary or Windows flags changed; no additional build/run.',
        'beforeSha256':hashlib.sha256(before).hexdigest(),'afterSha256':hashlib.sha256(after).hexdigest(),
        'builderCorrectedForFutureUse':True,'unityReimportNotRerun':True}
(OUT/'importer-correction.json').write_bytes((json.dumps(report,indent=2)+'\n').encode('utf-8'));print(json.dumps(report))
