"""Reuse the exact native01 acceptance with independent package/build paths."""
import argparse,importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'analyze-world-light-relevance.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
fixture.PACKAGE=fixture.ROOT/'LocalComparison/Review/world-light-relevance-02'
fixture.BUILD=Path('I:/Unity test/Comparison/Builds/WorldLightRelevance31')
fixture.existing.PACKAGE=fixture.PACKAGE;fixture.existing.BUILD=fixture.BUILD
fixture.smoke.PACKAGE=fixture.PACKAGE;fixture.smoke.BUILD=fixture.BUILD
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run']);a=p.parse_args()
    if a.action=='build':ok=fixture.existing.build()
    elif a.action=='products':print(fixture.smoke.verify_products());ok=True
    else:ok=fixture.run()
    raise SystemExit(0 if ok else 1)
