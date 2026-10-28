"""New attempt paths only; all native fixture code and assertions are reused."""
import argparse,importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'prepare-world-light-relevance.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
fixture.PACKAGE=fixture.ROOT/'LocalComparison/Review/world-light-relevance-02';fixture.OUT=fixture.PACKAGE/'instrumentation'
fixture.base.PACKAGE=fixture.PACKAGE;fixture.base.OUT=fixture.OUT
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);a=p.parse_args()
    if a.action=='prepare':
        fixture.prepare();(fixture.OUT/'path-wrapper.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    else:getattr(fixture.base,a.action)()
