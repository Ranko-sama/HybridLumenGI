"""Same feature's final second batch; frozen kernels, baseline product untouched."""
import argparse,importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'prepare-temporal-subpixel.py')
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
first=fixture.PACKAGE
fixture.PACKAGE=fixture.ROOT/'LocalComparison/Review/temporal-subpixel-history-02'
fixture.OUT=fixture.PACKAGE/'instrumentation';fixture.base.OUT=fixture.OUT
fixture.BASELINE=first/'baseline/HybridLumenGIKernels.hlsl'
fixture.CANDIDATE=first/'candidate-kernel.hlsl'
fixture.DEPLOY_CANDIDATE=False
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);a=p.parse_args()
    (fixture.base.install if a.action=='install' else getattr(fixture,a.action))()
