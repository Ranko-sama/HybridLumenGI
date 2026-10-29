# Finite cache feedback input capture, revision 02

This is a new observation package after native 01 failed Unity's per-kernel
eight-UAV limit. The first run completed only 32 black frames and never enabled
the light. Its failure and frozen reference directory remain unchanged. Its
invalid observation buffers are not used as color evidence.

The change is confined to collection and source mapping. `CSReferenceMetadata`
now writes eight outputs; `CSReferenceChanges` separately writes the unchanged
change-region buffer. Cache/gather rays, row formats, filenames, source settings,
fixed 32-black-plus-two-lit schedule, mathematics and numerical acceptance are
unchanged. The extra kernel executes at the same before-update boundary.

These files are copied byte for byte from the frozen original reference:

- `finite_reference.py`, `atlas_support.py`, `numeric_reference.py` and
  `screen_input_qualification.py`;
- `source-contract.json`, `numeric-contract.json`;
- the three mathematical/input test files.

`generate_native_sampler.py` compiles all five entries with DXC `cs_6_0 -O3` and
records actual assembly resource bindings. Required UAV counts are respectively
8, 1, 1, 1 and 1 for metadata, changes, cache inputs, atlas and gather inputs.
`#pragma use_dxc` remains explicit, but does not override Unity's UAV limit.

The comparator changes only the expected compile count/UAV qualification and
allows a staged harness file's `source` field to identify its actual repository
source, e.g. `CacheFeedbackFiniteTap02.cs` staged under the original Tap filename.
It still closes all frozen sources and pure geometry inputs, writes independent
expectations, and only then opens separate cache/raw observations. All floating
point/storage and conditional DXR localization limits are inherited unchanged.

Preparation evidence is in `preparation-summary.json`, `validation.log`, and
`generated/manifest.json`. The original reference README describes the source
geometry, input ABI, Jacobi history and scattering-order interpretation.

After parent-owned freeze, install and native execution:

```powershell
& 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -B LocalComparison/Reference/CacheFeedbackFinite02/compare_native.py --native-outputdir <absolute-native-output> --package LocalComparison/Review/cache-feedback-finite-02
```

A numerical pass remains conditional finite current-input feedback consistency:
at most two cache scattering events, three in raw gather, and four after visible
receiver reflectance. It is not default multibounce or portable DXR precision
certification. No GPU execution is performed by this reference preparation lane.
