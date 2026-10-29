# Same-render composition report

This read-only tool describes `cameraBeforeHLGI`, `cameraAfterHLGI` and `filteredD`
from a validation v2 candidate. It also computes **after minus before on the same
frame and mutually valid camera pixels**. That difference is a diagnostic of the
actual composition increment, not an independent physical reference or a quality
or performance result. The before image is not direct lighting alone; the after
image precedes later URP transparent and post-processing passes.

Use Python with NumPy. Pillow is optional and only needed for requested previews.

```powershell
python describe_composition.py --candidate 'I:/captures/native-run' --output 'I:/reports/composition-run'
python describe_composition.py --candidate 'I:/captures/native-run/capture/run-id/candidate.json' --output 'I:/reports/composition-preview' --exposure-stops 0
python describe_composition.py --self-test
```

A directory input must contain exactly one `candidate.json`; ambiguous input is
rejected. Output must be a new directory. The tool never overwrites an existing
report or changes raw files. Invalid input produces `failure.json` in the newly
created directory and exit 1; partial previews are retained if an error occurs.
Exit 0 means the descriptive report was generated, **not** that rendering passed.

The tool checks the manifest, physical source, all declared source assets and
provenance, frame-state identity/camera, support artifacts, raw images and masks by
SHA256. Artifact paths must remain within the manifest directory, including after
symlink resolution. The final report records these hashes and the script hash.
Missing selected frames/signals remain visible. Source unsupported reasons and
the original capture status are retained without being converted into a defect.

Outputs:

- `composition.json`: per-frame mean/min/max linear RGB, maximum component,
  luminance statistics, negative/zero counts, total and valid pixel counts,
  nonfinite counts, and the signed camera difference. Each signal retains raw and
  validity hashes. The difference is computed in float64 from stored float32.
- `index.html`: readable tables and any available previews, with a link to JSON.
- Optional PNGs: before, after, native-resolution filteredD, positive difference
  RGB, and negative difference magnitude RGB. The same explicitly chosen exposure
  is used throughout: `max(0,linear) * 2^stops`, fixed Reinhard `x/(1+x)`, then sRGB.
  There is no automatic exposure or image-based normalization. Negative values
  remain in numeric statistics and the separate negative-difference image.
  Invalid/excluded pixels appear magenta. Declared bottom-to-top images are flipped
  for display only; raw data and numeric indexing remain unchanged.

Every mask-zero pixel and every nonfinite pixel is counted. Signal statistics use
mask-one pixels with all four components finite; difference statistics use the
intersection of those sets. No excluded pixel is silently promoted to black or
valid. If Pillow is unavailable, the numeric/HTML report still succeeds and records
why no PNGs were generated. No product threshold or physical reference is supplied.
