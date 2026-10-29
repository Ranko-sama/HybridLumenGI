"""Reuse the exact independent seven-stage sample audit with release-build provenance."""
import importlib.util
import json
from pathlib import Path
import sys
import traceback
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease74')
NATIVE=Path('I:/Unity test/Comparison/LocalRelease74Verification')
original=P.parent/'unified-sample-02/verify_run.py'
spec=importlib.util.spec_from_file_location('seven_stage_audit',original)
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
audit.P=P;audit.NATIVE=NATIVE

class ReleaseAudit(audit.Audit):
    def source(self):
        manifest=self.load(P/'instrumentation/manifest.json')
        report=self.load(P/'build-report.json')
        audit.require(self.load(P/'build-analysis.json')['passed'],'Build qualification failed')
        audit.require(self.load(P/'build-exit.json')['exitCode']==0,'Build process failed')
        audit.require(self.load(P/'restoration.json')['passed'],'Project restoration failed')
        native=self.load(P/'native-exit.json');audit.require(native['exitCode']==0 and not native['watchdogTerminated'],'Player did not exit normally')
        audit.require(report['result']=='Succeeded' and report['restored'] and report['inputsUnchanged'] and
                      report['sourceUnchanged'] and report['ordinaryCameraEnabled'] and report['verificationHostDisabled'],'Ordinary release source or mode failed')
        inputs={r['path']:r['sha256'] for r in report['inputs']}
        for name,digest in manifest['productSourceSha256'].items():
            self.hashed(ROOT/name,digest);self.hashed(audit.PROJECT/'Assets/HybridLumenGI'/name,digest)
            audit.require(inputs['Assets/HybridLumenGI/'+name]==digest,'Built product differs')
        for row in manifest['files']:
            self.hashed(P/'instrumentation'/row['prepared'],row['sha256'])
            audit.require(inputs[row['path']]==row['sha256'],'Built harness differs')
        products=self.load(P/'build-products.json')
        audit.require(set(products)=={p.relative_to(BUILD).as_posix() for p in BUILD.rglob('*') if p.is_file()},'Build artifact set changed')
        for name,digest in products.items():self.hashed(BUILD/name,digest)
        for row in report['products']:self.hashed(Path(row['path']),row['sha256'])
        audit.require(report['sourceBeforeSha256']==report['sourceAfterSha256'],'Authoring scene changed')
        return dict(sourceManifestSha256=audit.digest(self.read(P/'instrumentation/manifest.json')),
                    authoring=dict(variantScene=report['scene']),ordinaryInteractive=True,
                    scope='Source-matched Release/None executable; finite mode uses the same built scene and product')

if __name__=='__main__':
    output=P/'run-verification-first.json';audit.require(not output.exists(),'Preserve first analysis')
    checker=ReleaseAudit()
    try:result=checker.run()
    except Exception:result=dict(passed=False,error=traceback.format_exc(),context=checker.context)
    with output.open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('inputSha256','images')}))
    sys.exit(0 if result['passed'] else 1)
