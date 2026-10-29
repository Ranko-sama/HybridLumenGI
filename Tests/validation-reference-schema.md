# Validation v2 independent reference adapter

`compare-validation-reference.mjs` compares source-matched, unexposed linear RGB
against an independently produced reference. It does not render a reference or
certify a source exporter, physical model, Unity run, backend, performance budget,
or production quality. Existing v1 capture files and frozen Review evidence are
unchanged. The v1 same-HLGI-run comparator remains separate.

```powershell
node Tests/compare-validation-reference.mjs --candidate C:/run/candidate.json
node Tests/compare-validation-reference.mjs --candidate C:/run/candidate.json --reference C:/reference/reference.json
node Tests/compare-validation-reference.mjs --candidate C:/run/candidate.json --reference C:/reference/reference.json --rmse 0.001 --max-error 0.01
node Tests/test-validation-reference.mjs
```

The numeric CLI values above illustrate syntax, **not recommended acceptance
thresholds**. There are no defaults. An optional `--output new-result.json` creates
a new file exclusively and refuses to overwrite an existing report.

The importable API is:

```js
import { compareValidationReference, ValidationError } from './compare-validation-reference.mjs';
const report = compareValidationReference(candidateManifestPath, referenceManifestPath,
  { thresholds: { rmse: chosenRmse, maxError: chosenMaxError } });
// referenceManifestPath may be null; options may be omitted.
```

The API returns a report for incomplete coverage or quality results. Invalid input
throws `ValidationError` with `code`; filesystem errors may also throw. The CLI
turns either into an `invalid-input` JSON report and exit 1.

## Common manifest

Candidate and reference use `schema: "hlgi-validation-reference-v2"` and
`kind: "candidate"` or `"reference"` respectively. Required fields:

| Field | Contract |
| --- | --- |
| `status` | `complete` or `incomplete`. Incomplete needs a nonempty `reasons` string array. Collection completion is separate from reference qualification and coverage. |
| `source` | `{file, sha256}` referencing the scene-source JSON below. |
| `sequence` | `{id, version, totalLogicalFrames}`; nonempty ID and positive integer version/count. Exact equality between candidate and reference. |
| `selection` | `{logicalFrames, signalIds}`; a nonempty, unique, sorted integer frame list within the sequence and nonempty unique signal ID list. Exact equality between both manifests. This is the predeclared comparison request, never selected from image values. |
| `signals` | Unique signal definitions below; must include every requested ID. Other diagnostic signals may be declared without being selected. |
| `frames` | Unique records for selected logical frames. Missing selected frames or signals are reported as uncovered, never skipped into success. No HLGI counters, engine frames or 720 reference receipts are required. |
| `provenance` | Optional list of `{file, sha256, role}` for product/tool source, build/runtime receipts, settings or provenance evidence. All are hash-checked; they are not physical reference inputs. |

`sha256` is exactly 64 lowercase hex characters. Every artifact path uses forward
slashes and is relative to the **directory containing its manifest**, including
`source.assets[].path` when the source JSON resides in a subdirectory. Absolute
paths, drive/ADS syntax, backslashes, empty/dot/parent path components and symlink
escapes are refused. File lengths and SHA256 are checked from actual bytes.

Extra metadata may be retained. Only declared artifact descriptors are traversed;
putting a filename in an arbitrary extra field does not verify its bytes.

## Physical source and frame state

The source file has:

```text
schema: "hlgi-validation-source-v2"
sceneId: stable authored scene identifier
coordinateSystem: "Unity-left-handed-y-up"
lengthUnit: "metre"
geometry: []
materials: []
lights: []
environment: {}
rendering: {}
assets: [{path, sha256, role}, ...]
unsupported: []
```

The exporter owns the typed contents of geometry/material/light records. It must
preserve actual mesh/submesh arrays and transforms, material inputs/keywords and
texture references, effective property-block provenance, light inputs, environment,
baked-lighting inputs, masks and relevant physical rendering conventions. Mesh,
material and texture bytes can be archived as `source/assets/<sha256>.bin`;
AssetDatabase GUIDs/names are additional identifiers, not content identities.
There is no old object/material-count, single-light or no-emission assumption.

`assets[].role` is a nonempty explanatory string; paths must be unique ignoring
case. Optional `originalPath`, `guid`, `localId`, `bytes` and typed source metadata
may be retained. Every declared asset is hash-checked. An input that cannot be
fully represented must be explained in `unsupported` (nonempty strings); this
blocks physical comparison with `unsupported-source`. Do not omit it to get a
passing reference. The adapter verifies byte correspondence, not the completeness
or physical interpretation of an arbitrary exporter; reference qualification must
audit those premises independently.

Each frame record is:

```text
logicalFrame: integer
state: {file, sha256}
camera: CameraDescriptor
samples: [Sample, ...]
support: [{file, sha256, role}, ...]  // optional, hash-checked
```

`state.file` is an independently serialized JSON document:

```text
schema: "hlgi-validation-frame-state-v2"
logicalFrame: integer
sourceSha256: hash of the common source JSON
camera: the exact CameraDescriptor in the frame record
dynamicState: { ... actual source-object/material/light/environment state ... }
unsupported: []
```

Its bytes/hash must match between candidate and reference. Use a stable exporter
serialization and copy the frozen physical input artifact to the reference
producer; do not reconstruct approximately equal matrices from a different engine.
Engine frame counters, run IDs and timing belong in receipts/provenance, outside
the cross-run physical state. State unsupported reasons also block physical
comparison. The adapter does not silently ignore input changes between captures.

`frame.support` binds product observations such as geometry/depth/material/native
diffuse buffers. They need no independent physical reference and must not be used
to manufacture expected radiance. Keep them separate from source-only state.

### CameraDescriptor

Required fields are:

```text
matrixOrder: "row-major"
view: [16 finite numbers]
projection: [16 finite numbers]
viewport: [integer x, integer y, positive integer width, positive integer height]
jitter: [2 finite numbers]
rowOrder: "top-to-bottom" | "bottom-to-top"
uvOrigin: "top-left" | "bottom-left"
clipDepth: "zero-to-one" | "minus-one-to-one"
reversedZ: boolean
pixelCenter: "half-integer"
```

View/projection must describe the actual captured rendering inputs, including
jitter where used. This is not permission to substitute a CPU nonjittered camera
matrix. Matrices and conventions are compared exactly. `GPU` alone is not a row
order. Normalize an independent reference explicitly before constructing its
manifest; this adapter performs no flip, crop, exposure, tonemap or resampling.

## Signals and sample layout

A signal definition is:

```json
{
  "id": "cameraAfterHLGI",
  "stage": "after-hlgi-composite-before-transparents",
  "quantity": "camera-radiance",
  "units": "scene-linear-radiance",
  "domain": "camera-pixel",
  "comparison": "physical-reference",
  "colorSpace": "linear-srgb",
  "exposure": 1,
  "alpha": "not-compared",
  "fog": "applied",
  "contributions": ["direct", "emission", "hlgi-indirect-diffuse", "native-reflection"]
}
```

This example is illustrative: the actual composition mode, environment, baked GI,
fog and supported contributors must be recorded correctly. The complete signal
definition must match the reference. `contributions` is a sorted unique nonempty
string array. Supported quantities are `camera-radiance`,
`indirect-irradiance-over-pi`, `outgoing-indirect-diffuse-radiance`, and
`native-diffuse-radiance`; units are `scene-linear-radiance`. Unknown quantities or
units remain unsupported, rather than being interpreted as equivalent RGB.

Use `stage: "before-hlgi-composite-after-skybox"` for cameraBeforeHLGI,
`"after-hlgi-composite-before-transparents"` for cameraAfterHLGI, and
`"before-hlgi-composite-after-filter"` for filteredD. A Sequence end-camera target needs its own
distinct stage. CameraBeforeHLGI is not "direct": it may include native diffuse
GI, specular, emission and fog. filteredD is E/pi before receiver reflectance/AO
and final composition. CameraAfterHLGI precedes later URP transparent/post passes.

`domain` is `camera-pixel` or `gi-grid`. Camera-pixel data must cover the complete
camera viewport; GI-grid dimensions must match the reference. `comparison` may
instead be `diagnostic-only`. A selected diagnostic signal or `composition-delta`
always reports unsupported: `after-before` is not an independent physical
reference. Unselected diagnostic/support data does not require a reference.

An available sample is:

```text
signalId: declared signal ID
status: "available"
width, height: positive integers, each <= 16384
format: "rgba32f-le"
rowOrder: same explicit row order as frame.camera
data: {file, sha256}
validity: {file, sha256, format:"uint8", basis:...}
```

Raw data is tightly packed little-endian RGBA float32, width*height*16 bytes. The
mask has exactly width*height bytes: 1 means measured/available, 0 means uncovered.
Allowed mask bases are `all-pixels`, `measurement-state`, and
`declared-reference-domain`. `all-pixels` must contain only 1. Mask-zero pixels are
never silently removed from acceptance: any zero forces incomplete coverage.
Known pixels require finite RGBA; RGB is scored and alpha is not. Unknown payload
bits are not decoded. RGB sign, black, or image brightness must not select coverage.

A missing/unsupported sample can instead declare
`status: "unsupported" | "uncovered"` with nonempty `reasons`. Duplicate frame or
signal records are invalid; omitted selected rows remain explicitly uncovered.

## Independent reference qualification

Reference manifests additionally require:

```text
reference: {
  method: "analytic" | "independent-numerical-integration" | "independent-path-tracing",
  independence: {
    inputs: "source-only",
    usesCandidateRadiance: false,
    usesProductTransport: false
  },
  evidence: [{file, sha256}, ...]
}
```

Candidate-derived difference images, product debug output and copied product
lighting evaluations cannot satisfy this contract. Their declarations produce
`unsupported-reference`. Evidence is required and hash-checked, but its scientific
validity is not inferred from a boolean or a hash.

Each available reference sample has either:

```text
qualification: {status:"unqualified", reasons:[...]}
```

or an independently reviewed, source-bound qualification:

```text
qualification: {
  status:"qualified",
  errorBound:{type:"absolute-per-component", maxRgb: nonnegative finite number},
  evidence:[{file, sha256}, ...]
}
```

The bound must cover reference integration/truncation, numeric and stored-image
error for every compared RGB component. This version does not accept a batch
standard error or an ordinary statistical confidence interval as an absolute
bound. A stochastic estimator without the required qualified bound stays
unqualified. No reference implementation or certificate is supplied by these tools.

## Metrics, thresholds and results

The arithmetic is the legacy comparator's linear RGB RMSE and maximum absolute
channel error. Metrics on a partly covered pair are labeled
`mutually-valid-pixels-only` and are descriptive: the pair cannot pass or fail a
full-image threshold until coverage is complete. Means do not turn correlated
frames into independent samples. No temporal convergence/ghosting score is inferred.

An optional candidate `thresholds: {rmse, maxError}` supplies one or both explicit
nonnegative finite limits. CLI limits may supply absent limits, but conflicting
CLI/manifest values are rejected. There is no automatic threshold derived from
observed outputs or reference uncertainty.

For either error metric m and qualified component bound e, the true error interval
is bounded by `[max(0,m-e), m+e]`. All declared upper bounds must meet their limits
to pass; a lower bound exceeding a limit fails; an overlapping interval remains
`uncertain-with-reference-bound`. Reference uncertainty is not added to the
permitted product error.

| Exit | Result | Meaning |
| --- | --- | --- |
| 0 | `within-declared-thresholds`, passed true | Both collections complete; every selected pair/pixel is covered with qualified reference and all supplied thresholds satisfied. Conditional evidence only. |
| 1 | `outside-thresholds`, passed false | At least one fully covered pair has a reference-bound lower error above a supplied limit. Other incomplete rows remain in the report. |
| 1 | `invalid-input`, passed null | Hash/path/schema/source/state/camera/signal/layout/finite-value failure. This is not a product-rendering defect. |
| 2 | `incomplete`, passed null | Reference missing/unqualified/unsupported, signal/source unsupported, pixels/rows missing, incomplete collection, no explicit threshold, or reference uncertainty straddles a limit. |

All requested rows are returned. Uncovered labels are not rendering bugs. Even an
exit-0 comparison does not complete G1–G5, certify unsupported materials or establish
performance. CPU tests use explicitly synthetic two-frame inputs only and create
no new Unity fixture or physical reference.
