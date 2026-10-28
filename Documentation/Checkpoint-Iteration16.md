# Iteration16 — C-prospective-01 matched source/product/CPU reference

## Current checkpoint (2026-10-28 after the unique native attempt)

Iteration16 is complete as a retained real first failure, not successful radiometry.
Package: LocalComparison/Review/scene-radiometry-matched-baseline-01. HEAD remains
31afcd5; new sources/evidence are uncommitted pending actualPro16 review.

Unity PID30572 exited1 BEFORE Play at SceneRadiometryExport.Resolve called with
Packages/manifest.json. Build produced a partial real20mesh/6material source JSON,
then dependency archiving failed because project package configuration is not a
PackageInfo asset. No source-freeze, no target frames, no new captures, no sixpoint
CPU integration. All42 tracked deployed files and96Runtime source hashes restored;
new metadata archived then removed; no Unity process remains. Native session38896
completed exit1. Do not make a second native attempt in this package.

Candidate exporter fix classifies exactly manifest.json/packages-lock.json as
project-owned paths before package lookup. Actual extracted Resolve compiled/run
outside Unity passed finite existing-manifest/package-root/inner-file/unknown-package
checks. Candidate has NOT been installed or native validated. Preserve actual failing
prepared/executed source in instrumentation and pre-native-inputs.json.

New implementation files: SceneRadiometryExport.cs, RadiometryObservation.cs,
prepare-radiometry.py, preflight-radiometry.py, radiometry-reference.py,
compare-radiometry.py, test-radiometry-reference.py, test-radiometry-paths.py,
run-radiometry.ps1 under LocalComparison/Harness. Read package contract/result/summary
and both Astra reviews. Preflight02 C# passed after two API type fixes; math02–05
passed after decimal expected-value typo and review-driven source-normal/winding
corrections; HLSL hashes reuse prior successful DXC preflight; Python parse passed.
Path-probe01 had a GBK stdout/BOM printing failure before execution; UTF8-fixed02
passed. ALL test/build failures and successes plus native log/restoration were
recorded to c2c iteration16.

Guard /root/astra_guard idle after result review. It confirmed exporter bug, not GI;
minimal candidate repair and non-Unity path probe were its finite follow-up. No more
fixtures requested. Await actualPro16 next package before any new native process.

ActualPro16 completed and is archived in this package's
gpt6-pro-review-and-next-plan.txt. REVIEW_DECISION RETAIN: commit this failure and
minimal path repair, then NEXT_PACKAGE scene-radiometry-matched-baseline-02 with
one NEW120frame process. Before it wire shared native_log_check.scan into acceptance
and place source/receipts/native/restoration checks BEFORE CPU invocation. Reuse
math/path/HLSL evidence; only changed C# integration may need one compilation.
On valid source/targets immediately run fixed sixpoint integration even if its
strict uncertainty remains too wide. No extra configuration or sampling. See full
actualPro16 plan. Continue the original development loop after local commit.
No remote push, no full-plan completion claim. Earlier real360frame/9PNG+HDR remains
valid bounded evidence with original failed startup qualification. Latest user
question about real Unity/screenshots was answered; it did not cancel development.

## Original package design (retained for context)

Starting main31afcd5 (Pro15 approved sourcegap); prior05d6220 (Pro14 qualified cache response). ActualPro15 full plan: LocalComparison/Review/scene-radiometry-reference-01/gpt6-pro-review-and-next-plan.txt. Session c2c_a702 /16/PLAN/EXECUTING. User's full original autonomous localdevelopment→actualGPT6Pro review loop continues. GPT6AstraMax guard /root/astra_guard idle after designreview; reuse at implementation/nativeprep/result keynodes. No iteration16 files implemented beyond this checkpoint yet. ZERO iteration16 Unity/native/CPU solver runs.

Plan: prepare complete exporter+solver+comparator interfaces/contract BEFORE unique native run. New C-prospective-01 = frozen chain02 Static.unity structure + explicit current-only six.mat/.meta candidates from iteration15 snapshot. Do NOT call ThinWallEditor.Prepare/ComparisonRunnerEditor or recreate scene. One Unity process max120 targetlogical frames static on: warmup0–103, gate103 sources/backend/coverage (notbrightness), observation104–119, finalPNG/HDR104/119. Complete sourceexport in sameprocess after import, freeze executed bytes/effective values, check actualstate/dependencies at windowstart andfinal119; changesfail ratherthanrollmanifest. Restore original deployed bytes/assets afterward. No secondnativeattempt, noextra360/backend/budget/seedmatrix.

All120lightweight source/frame/buffer/selectedpatch/update receipts. Full old/new/cacheestimatecommit and4gather+raw/history/filtered104–119 only. Six solver targets = actualnew119 anchors+receivers, independenttriangle/material/facingcorrespondence beforeintegration. Old21/26/InstanceIDs notcorrect-by-definition; oldtargetjsonrulesonly, oldRGB notpaired. Minimal103coverage receipt allowed, notextendedqualitysampling. ExistingSceneLightoffTap/GatherCacheTap/pureASTinstrument functions canreuseABI/alias/readback safety, notoldinstaller main/assertions. Important capture Update: existingfinalframe Finish(true) EARLY RETURN occurs before oldGate119 insertion point, so newFinal119 MUST run beforeFinish andbeforestaterestore. Gate103 must wait submittedGPUreadbacks in normalUpdate aftertargetcamerareceipt, validate thenadvance104; do notwaitinsideEndCamera/graph orsimplyreturnacrossengframes causingduplicate103renders.

IndependentCPU: six targets×8independentbatches×4096paths×max64diffusevertices, fixedseeds/uncertaintycontractbeforeGPUdifference. Rawgeometry+materialsource+lockedURP constants only; productresults readlaterbycomparator. Triangleintersectiondouble andscale-relativeoffset; noproductBVH/SDF/cache/screen/guide/bias. C=E_indirect/pi, directdseparate, cosinePDFcancel means meanendpointLo (no targetrho). Metalworkflowrho=albedoLinear*.96*(1-metallic), _SPECULAR_SETUP keywordalternate; emissionkeywordactual. Source+interpretedvaluesbothsaved. ActualURP17.0.4 local sources verified: Library/PackageCache/com.unity.render-pipelines.universal@947f725e83ac/{ShaderLibrary/BRDF.hlsl,Lighting.hlsl,RealtimeLights.hlsl,SurfaceInput.hlsl,Shaders/LitInput.hlsl}. kDielectricSpec .04/.96; directLighting alreadyusesURPrelativeunits,noextraPI. Unitymanual Colorproperties suppliedsRGB→linear shader; Float/Vector defaultnotconverted: https://docs.unity3d.com/6000.0/Documentation/Manual/SL-PropertiesInPrograms.html (read). PBRTprimary diffuse andpathtracer pages read: https://pbr-book.org/4ed/Reflection_Models/Diffuse_Reflection and https://pbr-book.org/4ed/Light_Transport_I_Surface_Reflection/A_Better_Path_Tracer. Do notcopywholeprimarysources; independentmath.

Astra designreview: derive stricttail fromsource maxrho r<1 andboundedsource+positivepointlight-to-surface distance. Conservative r^64*Lmax maybewide (.96^64≈.073); lastsmallbounce isnotbound. Separatefinite64estimate/statisticalbatchdispersion frominfinitebouncequalification. Noautomaticextra paths. Product120notsteady/noGPUCIfromcorrelated16frames. Report historicalSourceClosurefalse, prospectiveSourceClosure,targetSurfaceCorrespondenceVerified,productObservationValid,referenceEstimateQualified,comparisonConclusive,nativeExitAccepted separately. Earlierexceptional1MiBscratchunresolved evenifnewcleanexit.

Environment: I:/Unity test/Project; deployment Runtime matchesc50ec78 (HEADRuntimeidentical), noUnityrunning. Launcher I:/Unity test/Start-Unity.ps1 (Batch hidden, returnsnativeexit; default-force-d3d12). Python C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe. Current helpers stale/inert unlessflags; beforeinstall backupallchangedfiles including6materialsmeta, frozen8assets, sourcehelpers. Preservebothsuccess/failurelogs andc2crecord outputs. Existingchain02 manifest96Runtimechecks etc; sourceinventory20meshes/20materialrows, current6matsalltexturefilesnull/keywordempty, Emittercolor5/3/1.5 but _EMISSIONoff. Actualmesharrays requirednotjustCube name. Existinggather-geometry A lacksradiometricmaterial data, notsufficientnewsource.

Browserbindings agent/iab/c2cTab persist in tools.mcp__node_repl__js. Same savedProchat, noresponsepending, Pro15saved. Doctord436f7green, no repair. NeverpastefilebodiesintoChatGPT; controlunder1KB, Proreadsconnector. User permitsbeyonddefault12iterations. Noautoendwhenpackagecomplete; continuefullplan. Lastuserquestion aboutactualUnity/screenshots answeredwithreal360frames9PNG/HDR,119/359images,remaininglimits. That statusquestion didnotcanceldevelopment.
