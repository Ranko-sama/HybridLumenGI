# Release71 explicit-request finite integration

Execution completed: build/source/Cube restoration passed; 120 explicit requests and all camera/context callbacks matched; Final HDR verified; native exit 0. First render wait was 99.2426217 seconds. See native-explicit/analysis.json. Ordinary interactive keys and automatic hidden rendering remain unverified by this run.

This package keeps Release69 ordinary startup/example wiring and the exact 112 current product sources already verified by Release70. It adds a temporary Bootstrap flag, `-localReleaseExplicitRequest`, legal only with `-localReleaseFinalImage120` and batch mode. The default ordinary branch is unchanged. Release70's two zero-camera failures remain in their original package.

The finite path disables automatic target-camera rendering and submits one `RenderPipeline.StandardRequest` per engine Update. Each request must produce exactly one target-camera begin/end and context begin/end. The existing 120-frame, startup, GI readiness and Final HDR requirements remain. Frame 120 is captured after the explicit request returns, before the next engine frame. This verifies a bounded explicit-request Player integration; it does not revalidate OS keys, ordinary automatic rendering, scene-motion quality or default multi-bounce accuracy.

`prepare.py prepare` only creates local staging/backups and verifies the restored Unity project. `prepare.py preflight` compiles the two managed assemblies without launching Unity. Both completed with 8 staged files and 112 matched product files. No native temporal contract is repeated.

Execution order for the coordinating agent:

1. Run `build.ps1` once. It installs the temporary harness, calls only `CurrentPlayerBuild.Build`, saves logs, and restores harness/Cube inputs in `finally`.
2. Run `prepare.py build` to verify the build, exact source inventory, restored inputs and Cube binding.
3. Run `run.ps1` once. It verifies build products and uses a hidden process with batch mode, Final120 and the explicit-request flag. Receipts go to the fresh `native-explicit` directory.
4. Run `qualify_run.py` to check the retained request/camera/context counts, source/build identities, diagnostics and finite Final HDR files. View the image separately; finite data validation is not visual or physical acceptance.

The output is the new `I:/Unity test/Comparison/Builds/LocalRelease71`; existing Release69/70 outputs are not replaced. Only the coordinating agent runs Unity or the Player. This package's preparation and offline preflight do not launch either.
