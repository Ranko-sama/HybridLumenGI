using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace HybridLumenGI
{
    /// <summary>Source-only validation state. No product radiance, hit or history is read.</summary>
    public static class HybridLumenGIValidationSourceState
    {
        [Serializable] public sealed class FileLink { public string file, sha256; }

        [Serializable] public sealed class CameraDescriptor
        {
            public string matrixOrder = "row-major", rowOrder = "top-to-bottom", uvOrigin = "top-left";
            public string clipDepth = "zero-to-one", pixelCenter = "half-integer";
            public float[] view, projection, jitter;
            public int[] viewport;
            public bool reversedZ;

            // The caller supplies the actual URP camera inputs at the claimed render.
            // This is not an observation of the shader's UNITY_MATRIX_VP global.
            public static CameraDescriptor FromMatrices(Matrix4x4 view, Matrix4x4 projection,
                Vector2 jitter, int width, int height, bool? reversedZ = null, string clipDepth = "zero-to-one")
            {
                var result = new CameraDescriptor { view = HybridLumenGIValidationSourceData.Matrix(view),
                    projection = HybridLumenGIValidationSourceData.Matrix(projection), jitter = new[] { jitter.x, jitter.y },
                    viewport = new[] { 0, 0, width, height }, reversedZ = reversedZ ?? SystemInfo.usesReversedZBuffer,
                    clipDepth = clipDepth };
                result.Validate(); return result;
            }

            public void Validate()
            {
                if (matrixOrder != "row-major" || rowOrder != "top-to-bottom" || uvOrigin != "top-left" ||
                    pixelCenter != "half-integer" || (clipDepth != "zero-to-one" && clipDepth != "minus-one-to-one") ||
                    viewport == null || viewport.Length != 4 || viewport[0] != 0 || viewport[1] != 0 || viewport[2] <= 0 || viewport[3] <= 0)
                    throw new InvalidDataException("Validation camera requires a full viewport and explicit pixel/clip conventions.");
                HybridLumenGIValidationSourceData.Finite(view, 16, "camera.view");
                HybridLumenGIValidationSourceData.Finite(projection, 16, "camera.projection");
                HybridLumenGIValidationSourceData.Finite(jitter, 2, "camera.jitter");
            }
        }

        // Registered by the Editor assembly. Runtime never references that assembly.
        public static Func<Scene, Camera, HybridLumenGIRendererFeature, string, FileLink> EditorExporter;

        public sealed class PendingFrame
        {
            internal Session owner;
            internal FrameState state;
            internal bool written;
            public int LogicalFrame => state.logicalFrame;
        }
        [Serializable] internal sealed class FrameState
        {
            public string schema = "hlgi-validation-frame-state-v2";
            public int logicalFrame;
            public string sourceSha256;
            public CameraDescriptor camera;
            public HybridLumenGIValidationSourceData.Snapshot dynamicState;
            public string[] unsupported;
        }

        public sealed class Session
        {
            readonly string directory;
            readonly Camera camera;
            readonly HybridLumenGIRendererFeature feature;
            readonly FileLink source;
            readonly string[] sourceUnsupported;
            readonly HashSet<string> sourceAssetHashes = new HashSet<string>(StringComparer.Ordinal);
            public string[] Unsupported { get; private set; }
            public string SourceStatus => Unsupported.Length == 0 ? "captured" : "unsupported-source";
            public FileLink Source => new FileLink { file = source.file, sha256 = source.sha256 };

            internal Session(string runDirectory, FileLink sourceLink, Camera targetCamera, HybridLumenGIRendererFeature feature)
            {
                if (!targetCamera) throw new ArgumentNullException(nameof(targetCamera));
                directory = Path.GetFullPath(runDirectory); camera = targetCamera; this.feature = feature;
                var document = HybridLumenGIValidationSourceData.VerifyPackage(directory, sourceLink);
                source = new FileLink { file = sourceLink.file, sha256 = sourceLink.sha256 };
                sourceUnsupported = document.unsupported ?? Array.Empty<string>();
                Unsupported = (string[])sourceUnsupported.Clone();
                foreach (var asset in document.assets) sourceAssetHashes.Add(asset.sha256);
                if (document.sceneId != HybridLumenGIValidationSourceData.SceneKey(camera.gameObject.scene))
                    throw new InvalidDataException("Source scene identity differs from the capture camera scene.");
            }

            public PendingFrame CaptureBeforeRender(int logicalFrame)
            {
                if (logicalFrame < 0) throw new ArgumentOutOfRangeException(nameof(logicalFrame));
                var snapshot = HybridLumenGIValidationSourceData.Capture(camera.gameObject.scene, camera, directory, feature: feature);
                var unsupported = new SortedSet<string>(sourceUnsupported, StringComparer.Ordinal);
                foreach (string reason in snapshot.unsupported) unsupported.Add(reason);
                foreach (var asset in snapshot.assets)
                    if (!sourceAssetHashes.Contains(asset.sha256))
                        unsupported.Add("dynamic-texture-bytes-outside-static-source:" + asset.path);
                Unsupported = new List<string>(unsupported).ToArray();
                // Deeply owned snapshot arrays: no live Material, Transform, or Camera references are serialized.
                return new PendingFrame { owner = this, state = new FrameState { logicalFrame = logicalFrame,
                    sourceSha256 = source.sha256, dynamicState = snapshot, unsupported = (string[])Unsupported.Clone() } };
            }

            public FileLink WriteFrame(PendingFrame pending, CameraDescriptor actualCamera)
            {
                if (pending == null || pending.owner != this || pending.written) throw new InvalidOperationException("Foreign or already written source state.");
                if (actualCamera == null) throw new ArgumentNullException(nameof(actualCamera));
                actualCamera.Validate();
                var after = HybridLumenGIValidationSourceData.Capture(camera.gameObject.scene, camera, directory, feature: feature);
                if (JsonUtility.ToJson(after) != JsonUtility.ToJson(pending.state.dynamicState))
                    throw new InvalidOperationException("Physical source inputs changed between pre-render capture and render completion.");
                // Clone rather than retain the caller's mutable descriptor arrays.
                pending.state.camera = JsonUtility.FromJson<CameraDescriptor>(JsonUtility.ToJson(actualCamera));
                var result = HybridLumenGIValidationSourceData.WriteJson(directory,
                    "states/frame-" + pending.state.logicalFrame.ToString("D4") + ".json", pending.state);
                pending.written = true; return result;
            }
        }

        public static Session Begin(string runDirectory, FileLink source, Camera camera, HybridLumenGIRendererFeature feature)
            => new Session(runDirectory, source, camera, feature);

        /// <summary>Explicit Player path: copy an existing, verified source package; never invent one from the Player.</summary>
        public static FileLink CopySourcePackage(string packageDirectory, FileLink source, string runDirectory)
        {
            var document = HybridLumenGIValidationSourceData.VerifyPackage(packageDirectory, source);
            var provenance = HybridLumenGIValidationSourceData.VerifyProvenance(packageDirectory, out var provenanceIndex);
            foreach (var asset in document.assets)
                HybridLumenGIValidationSourceData.CopyVerified(packageDirectory, runDirectory, asset.path, asset.sha256);
            HybridLumenGIValidationSourceData.CopyVerified(packageDirectory, runDirectory, source.file, source.sha256);
            foreach (var artifact in provenance.artifacts)
                HybridLumenGIValidationSourceData.CopyVerified(packageDirectory, runDirectory, artifact.file, artifact.sha256);
            HybridLumenGIValidationSourceData.CopyVerified(packageDirectory, runDirectory, provenanceIndex.file, provenanceIndex.sha256);
            HybridLumenGIValidationSourceData.VerifyPackage(runDirectory, source);
            HybridLumenGIValidationSourceData.VerifyProvenance(runDirectory);
            return new FileLink { file = source.file, sha256 = source.sha256 };
        }
    }
}
