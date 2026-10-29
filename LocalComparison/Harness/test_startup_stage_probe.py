"""CPU-only patch/deployment safety checks. Never launch Unity or a Player."""
import importlib.util
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('startup_patch',HERE/'prepare-startup-stage-probe.py')
patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)
FEATURE=patch.ROOT/'Runtime/HybridLumenGIRendererFeature.cs'
HOST=patch.ROOT/'LocalComparison/Review/current-local-release-71/source/LocalReleaseBootstrap.cs'


class Patches(unittest.TestCase):
    def test_exact_newlines_double_patch_and_unknown_source(self):
        for path, function in ((FEATURE,patch.patch_feature),(HOST,patch.patch_host)):
            data=path.read_bytes();changed=function(data)
            self.assertNotEqual(data,changed)
            if b'\r\n' in data:self.assertEqual(changed.count(b'\r\n'),changed.count(b'\n'))
            else:self.assertNotIn(b'\r',changed)
            crlf=data.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')
            self.assertEqual(function(crlf).count(b'\r\n'),function(crlf).count(b'\n'))
            with self.assertRaises(ValueError):function(changed)
            with self.assertRaises(ValueError):function(data.replace(b'RenderPipeline.SubmitRenderRequest',b'Unknown.Submit',1) if path==HOST else data.replace(b'state.Ensure(w,h,identityEnabled)',b'state.OtherEnsure(w,h,identityEnabled)',1))

    def test_all_three_finite_hosts_are_supported(self):
        for name in ('FiniteWallDynamicScene.cs','FiniteWallOcclusionScene.cs','CacheFeedbackFiniteScene.cs'):
            changed=patch.patch_host((HERE/name).read_bytes())
            self.assertIn(b'StartupStageProbe.Submit(targetCamera,request)',changed)
            self.assertIn(b'StartupStageProbe.Stop(targetCamera)',changed)

    def fixture(self,folder):
        project=folder/'project';out=folder/'overlay'
        for source in (patch.ROOT/'Runtime').rglob('*'):
            if source.suffix in ('.compute','.hlsl','.shader'):
                target=project/'Assets/HybridLumenGI'/source.relative_to(patch.ROOT)
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
        host_rel='Assets/Test/LocalReleaseBootstrap.cs'
        for rel,source in ((patch.FEATURE_REL,FEATURE),(host_rel,HOST)):
            target=project/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
        return SimpleNamespace(out=out,project=project,feature_source=FEATURE,host_source=HOST,
            feature_sha256=patch.sha(FEATURE),host_sha256=patch.sha(HOST),host_target=host_rel)

    def test_restore_and_shader_identity_guard(self):
        with tempfile.TemporaryDirectory(prefix='hlgi-startup-overlay-test-') as folder:
            args=self.fixture(Path(folder));patch.prepare(args)
            shader=next((args.project/'Assets/HybridLumenGI').rglob('*.compute'));original=shader.read_bytes()
            shader.write_bytes(original+b'\n// unexpected\n')
            with self.assertRaises(ValueError):patch.deploy(args)
            self.assertEqual((args.project/patch.FEATURE_REL).read_bytes(),FEATURE.read_bytes())
            shader.write_bytes(original);patch.deploy(args)
            meta=Path(str(args.project/patch.PROBE_REL)+'.meta');meta.write_bytes(b'owned-generated-meta')
            patch.deploy(args,restore=True)
            self.assertEqual((args.project/patch.FEATURE_REL).read_bytes(),FEATURE.read_bytes())
            self.assertEqual((args.project/args.host_target).read_bytes(),HOST.read_bytes())
            self.assertFalse((args.project/patch.PROBE_REL).exists());self.assertFalse(meta.exists())
            self.assertEqual((args.out/'post-run'/(patch.PROBE_REL+'.meta')).read_bytes(),b'owned-generated-meta')
            self.assertEqual(shader.read_bytes(),original)

    def test_external_edit_blocks_restore_before_any_mutation(self):
        with tempfile.TemporaryDirectory(prefix='hlgi-startup-overlay-test-') as folder:
            args=self.fixture(Path(folder));patch.prepare(args);patch.deploy(args)
            feature=args.project/patch.FEATURE_REL;before=feature.read_bytes()
            host=args.project/args.host_target;host.write_bytes(host.read_bytes()+b'\n// unrelated work\n')
            with self.assertRaises(ValueError):patch.deploy(args,restore=True)
            self.assertEqual(feature.read_bytes(),before)
            self.assertTrue((args.project/patch.PROBE_REL).exists())

    def test_input_hash_and_target_escape_rejected(self):
        with tempfile.TemporaryDirectory(prefix='hlgi-startup-overlay-test-') as folder:
            args=self.fixture(Path(folder));args.feature_sha256='0'*64
            with self.assertRaises(ValueError):patch.prepare(args)
            self.assertFalse(args.out.exists())
        for path in ('../outside.cs','C:/outside.cs','Assets/../../outside.cs'):
            with self.assertRaises(ValueError):patch.safe_relative(path)


if __name__=='__main__':unittest.main()
