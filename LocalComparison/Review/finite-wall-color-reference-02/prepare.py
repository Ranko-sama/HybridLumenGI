"""Same finite reference contract after two confirmed observer/setup fixes."""
import importlib.util
import sys
from pathlib import Path
P=Path(__file__).resolve().parent
path=P.parent/'finite-wall-color-reference-01/prepare.py'
spec=importlib.util.spec_from_file_location('finite_wall_source',path)
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.P=P;base.OUT=P/'instrumentation'
if __name__=='__main__':
    assert sys.argv[1] in ('prepare','preflight','install','restore')
    getattr(base,sys.argv[1])()
