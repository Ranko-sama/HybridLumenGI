"""The same fixture's one bounded material-preparation correction; no product changes."""
import argparse,importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'prepare-screen-receive-shadows.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
fixture.PACKAGE=fixture.ROOT/'LocalComparison/Review/screen-receive-shadows-02';fixture.OUT=fixture.PACKAGE/'instrumentation'
fixture.fixture.PACKAGE=fixture.PACKAGE;fixture.fixture.OUT=fixture.OUT
fixture.fixture.base.PACKAGE=fixture.PACKAGE;fixture.fixture.base.OUT=fixture.OUT
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);a=p.parse_args()
    (fixture.prepare if a.action=='prepare' else getattr(fixture.fixture.base,a.action))()
