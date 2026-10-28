"""Reuse the original full oracle, also require the new plan's automatic exit."""
import argparse,importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'analyze-screen-receive-shadows.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
fixture.PACKAGE=fixture.ROOT/'LocalComparison/Review/screen-receive-shadows-02';fixture.BUILD=Path('I:/Unity test/Comparison/Builds/ScreenReceiveShadows33')
fixture.existing.PACKAGE=fixture.PACKAGE;fixture.existing.BUILD=fixture.BUILD;fixture.smoke.PACKAGE=fixture.PACKAGE;fixture.smoke.BUILD=fixture.BUILD
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run']);a=p.parse_args()
    ok=fixture.existing.build() if a.action=='build' else fixture.smoke.verify_products() if a.action=='products' else fixture.run()
    if a.action=='run':
        manual=(fixture.PACKAGE/'native-window/window-close.json').exists();report=fixture.load(fixture.PACKAGE/'native-window/analysis.json')
        report['automaticExitRequired']=True;report['manualWindowClose']=manual
        if manual:report['captureConsumptionVerified']=False;report['failure']='New plan requires automatic exit; manual window close cannot pass'
        fixture.save(fixture.PACKAGE/'native-window/analysis.json',report);ok=ok and not manual
    raise SystemExit(0 if ok else 1)
