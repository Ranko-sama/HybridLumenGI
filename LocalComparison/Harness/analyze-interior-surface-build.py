"""Reuse source/build verification; no physical image oracle."""
import argparse,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness'
PACKAGE=ROOT/'LocalComparison/Review/interior-surface-cache-chain-01';BUILD=Path('I:/Unity test/Comparison/Builds/InteriorSurface39')
spec=importlib.util.spec_from_file_location('existing',H/'analyze-material-event.py');existing=importlib.util.module_from_spec(spec);spec.loader.exec_module(existing)
existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products']);a=p.parse_args()
    ok=existing.build() if a.action=='build' else existing.smoke.verify_products()
    raise SystemExit(0 if ok else 1)
