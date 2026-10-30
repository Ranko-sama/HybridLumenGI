"""Describe the existing software and single DXR cost windows; no acceptance claim."""
import json
from pathlib import Path

here = Path(__file__).resolve().parent
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
dxr = read(here / 'result.json')
software = read(here.parent / 'release83-local-baseline-01/result.json')
assert dxr['native']['completeMeasurement'], 'Do not compare an incomplete DXR window'
assert software['native']['completeMeasurement']
dxr_dir = Path(dxr['native']['runDirectory'])
software_dir = Path(software['native']['runDirectory'])
before = read(software_dir / 'settings-measure.json')
after = read(dxr_dir / 'settings-measure.json')
settings_differences = {k: dict(software=before.get(k), dxr=after.get(k)) for k in before.keys() | after.keys() if before.get(k) != after.get(k)}
meta = read(dxr_dir / 'run.json')
frames = [json.loads(line) for line in (dxr_dir / 'frames.jsonl').read_text(encoding='utf-8-sig').splitlines() if line.strip()]
window = [r for r in frames if meta['sourceStart'] <= r['engineFrame'] <= meta['sourceEnd']]
report = dict(settingsDifferences=settings_differences, onlyRequestedBackendChanged=set(settings_differences) == {'preferHardwareTracing'},
              softwareWindow=software['native']['window'], dxrWindow=dxr['native']['window'],
              actualHardwareFrames=sum(r['hardware'] for r in window), softwareFrames=sum(r['exactSoftware'] for r in window),
              hardwareMeshes=sorted({r['meshes'] for r in window}), hardwareFallbacks=sorted({r['unrepresented'] for r in window}),
              materialUnknown=sorted({r['materialUnknown'] for r in window}),
              hardwareCountsMeaning='Existing backend counts, not proof of each ray using exact DXR geometry.',
              performance={}, memory={}, productionAcceptance=False,
              scope='Observed existing-backend cost/memory tradeoff; not an equal-image speedup, default selection or displayed FPS result.')
for name in dxr['native']['intervalStatistics']:
    a, b = software['native']['intervalStatistics'][name], dxr['native']['intervalStatistics'][name]
    report['performance'][name] = dict(software=a, dxr=b, observedMedianChangePercent=(b['medianMs']/a['medianMs']-1)*100)
for key in ('localSampledPeakMiB', 'nonlocalSampledPeakMiB'):
    report['memory'][key] = dict(software=software['processMemory'][key], dxr=dxr['processMemory'][key])
report['callbackCadence'] = dict(software=software['callbackCadence'], dxr=dxr['callbackCadence'], interpretation='Not Present or displayed FPS.')
with (here / 'comparison.json').open('x', encoding='utf-8') as f:
    json.dump(report, f, ensure_ascii=False, indent=2, allow_nan=False)
print(json.dumps(report, ensure_ascii=False, indent=2))
