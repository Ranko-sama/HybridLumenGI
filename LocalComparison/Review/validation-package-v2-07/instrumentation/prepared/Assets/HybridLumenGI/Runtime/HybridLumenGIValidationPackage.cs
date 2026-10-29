using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Source-matched validation export; never creates a reference or quality verdict.</summary>
    public sealed class HybridLumenGIValidationPackage
    {
        [Serializable] private sealed class Artifact
        { public string file, sha256, role; }
        [Serializable] private sealed class SourceProvenance
        { public Artifact[] artifacts; }
        [Serializable] private sealed class FeatureEnvelope
        { public HybridLumenGIRendererFeature.Settings settings; }
        [Serializable] private sealed class Sequence
        { public string id = "HybridLumenGIValidationSequence"; public int version = 1, totalLogicalFrames = HybridLumenGIValidationSequence.TotalFrames; }
        [Serializable] private sealed class Selection
        { public int[] logicalFrames; public string[] signalIds = { "cameraAfterHLGI" }; }
        [Serializable] private sealed class Signal
        {
            public string id, stage, quantity, domain, comparison;
            public string units = "scene-linear-radiance", colorSpace = "linear-srgb", alpha = "not-compared", fog;
            public float exposure = 1;
            public string[] contributions;
        }
        [Serializable] private sealed class Frame
        {
            public int logicalFrame;
            public HybridLumenGIValidationSourceState.FileLink state;
            public HybridLumenGIValidationSourceState.CameraDescriptor camera;
            public HybridLumenGIValidationCapture.Sample[] samples;
            public Artifact[] support;
        }
        [Serializable] private sealed class Manifest
        {
            public string schema = "hlgi-validation-reference-v2", kind = "candidate", status = "incomplete";
            public string[] reasons;
            public HybridLumenGIValidationSourceState.FileLink source;
            public Sequence sequence = new Sequence();
            public Selection selection;
            public Signal[] signals;
            public Frame[] frames;
            public Artifact[] provenance;
            public string referenceStatus = "reference-required";
            public string limitation = "Same-render HLGI composite boundaries, not endCamera output. Data completeness is not physical-reference qualification, quality acceptance or performance evidence.";
        }
        private sealed class Entry
        {
            internal HybridLumenGIValidationSourceState.PendingFrame pendingSource;
            internal HybridLumenGIValidationSourceState.FileLink state;
            internal HybridLumenGIValidationCapture.Ticket ticket;
        }

        private readonly string directory;
        private readonly Manifest manifest;
        private readonly HybridLumenGIValidationSourceState.Session source;
        private readonly HybridLumenGIValidationCapture.Session capture;
        private readonly List<Artifact> sourceProvenance;
        private readonly Dictionary<int, Entry> entries = new Dictionary<int, Entry>();
        private bool closing, completedSequence, runBound, changed = true;
        private string closeReason;
        public string Failure { get; private set; }
        public bool IsDrained => capture.IsDrained;

        public HybridLumenGIValidationPackage(Camera camera, HybridLumenGIRendererFeature feature,
            string runDirectory, int captureEvery, string existingSourcePackage = "")
        {
            directory = Path.GetFullPath(runDirectory);
            var settings = JsonUtility.FromJson<FeatureEnvelope>(JsonUtility.ToJson(feature)).settings;
            if (settings == null || settings.debugView != HybridLumenGIRendererFeature.DebugView.Final || !feature.isActive)
                throw new InvalidOperationException("Reference export requires an active Feature in Final view.");
            HybridLumenGIValidationSourceState.FileLink link;
            if (!string.IsNullOrWhiteSpace(existingSourcePackage))
                link = ImportSource(existingSourcePackage, directory);
            else if (HybridLumenGIValidationSourceState.EditorExporter != null)
                link = HybridLumenGIValidationSourceState.EditorExporter(camera.gameObject.scene, camera, feature, directory);
            else
                link = ImportSource(existingSourcePackage, directory);
            source = HybridLumenGIValidationSourceState.Begin(directory, link, camera, feature);
            sourceProvenance = ReadSourceProvenance();
            var selected = new List<int>();
            for (int i = 0; i < HybridLumenGIValidationSequence.TotalFrames; i++)
                if (HybridLumenGIValidationSequence.IsCaptureFrame(i, captureEvery)) selected.Add(i);
            bool fog = RenderSettings.fog;
            manifest = new Manifest
            {
                source = link, selection = new Selection { logicalFrames = selected.ToArray() },
                signals = new[]
                {
                    CameraSignal("cameraBeforeHLGI", "before-hlgi-composite-after-skybox", fog, false),
                    CameraSignal("cameraAfterHLGI", "after-hlgi-composite-before-transparents", fog, true),
                    new Signal { id = "filteredD", stage = "before-hlgi-composite-after-filter", quantity = "indirect-irradiance-over-pi",
                        domain = "gi-grid", comparison = "physical-reference", fog = "not-applied", contributions = new[] { "indirect-diffuse-incident" } }
                },
                provenance = InitialProvenance()
            };
            capture = HybridLumenGIValidationCapture.Begin(camera, feature, directory, 2, 256L * 1024 * 1024);
            capture.Changed += OnChanged;
            Poll();
        }

        private static Signal CameraSignal(string id, string stage, bool fog, bool after)
        {
            return new Signal { id = id, stage = stage, quantity = "camera-radiance", domain = "camera-pixel", comparison = "physical-reference",
                fog = fog ? "applied" : "not-applied", contributions = after ?
                    new[] { "camera-opaque-lighting", "hybrid-composite-delta", "sky-background" } :
                    new[] { "camera-opaque-lighting", "sky-background" } };
        }

        public void RequestFrame(int logicalFrame, int engineFrame)
        {
            if (closing) throw new InvalidOperationException("Validation package is closed.");
            if (Array.IndexOf(manifest.selection.logicalFrames, logicalFrame) < 0) return;
            if (entries.ContainsKey(logicalFrame)) throw new InvalidOperationException("Repeated validation source frame.");
            var pending = source.CaptureBeforeRender(logicalFrame);
            entries.Add(logicalFrame, new Entry { pendingSource = pending, ticket = capture.Request(logicalFrame, engineFrame) });
            changed = true;
        }

        public void EndCamera(int logicalFrame, int engineFrame)
        {
            if (entries.TryGetValue(logicalFrame, out var entry) && entry.state == null && entry.ticket.Camera != null)
                entry.state = source.WriteFrame(entry.pendingSource, entry.ticket.Camera);
            capture.EndCamera(engineFrame);
            changed = true;
            Poll();
        }

        public void Advance(int engineFrame)
        { if (!closing) capture.ExpireBefore(engineFrame); Poll(); }

        public void Close(bool complete, string reason)
        {
            if (closing) return;
            closing = true; completedSequence = complete; closeReason = reason;
            if (complete) capture.Seal(); else capture.Close(reason);
            changed = true; Poll();
        }

        public void BindRunArtifacts(bool accepted)
        {
            if (!closing) return;
            runBound = true;
            completedSequence &= accepted;
            var artifacts = new List<Artifact>(sourceProvenance);
            foreach (string file in new[] { "feature.json", "run.json", "frames.jsonl", "unity-log.jsonl" })
            {
                string path = Path.Combine(directory, file);
                if (File.Exists(path)) artifacts.Add(Link(path, "fixed-sequence-" + file));
            }
            manifest.provenance = artifacts.ToArray();
            changed = true; Poll();
        }

        private void OnChanged() { changed = true; Poll(); }

        public void Poll()
        {
            if (!changed) return;
            changed = false;
            try
            {
                var frames = new List<Frame>();
                var reasons = new List<string>();
                if (!closing) reasons.Add("The fixed sequence is still running.");
                else if (!completedSequence) reasons.Add(string.IsNullOrEmpty(closeReason) ? "Sequence did not complete." : closeReason);
                if (closing && !runBound) reasons.Add("The final fixed-sequence receipt is pending.");
                if (source.Unsupported.Length != 0) reasons.AddRange(source.Unsupported);
                foreach (int logical in manifest.selection.logicalFrames)
                {
                    if (!entries.TryGetValue(logical, out var entry)) { reasons.Add("Missing selected frame " + logical); continue; }
                    var ticket = entry.ticket;
                    if (entry.state == null || ticket.Camera == null) { reasons.Add("Missing source/camera claim for frame " + logical); continue; }
                    if (!ticket.IsComplete) { reasons.Add("Readback pending for frame " + logical); continue; }
                    if (!ticket.Succeeded) reasons.Add("Capture failed at frame " + logical + ": " + ticket.Failure);
                    var support = new List<Artifact>();
                    foreach (var item in ticket.Result.support)
                    {
                        if (!string.IsNullOrEmpty(item.file)) support.Add(new Artifact { file = item.file, sha256 = item.sha256, role = item.role });
                        if (item.validity != null && !string.IsNullOrEmpty(item.validity.file))
                            support.Add(new Artifact { file = item.validity.file, sha256 = item.validity.sha256, role = item.role + "-validity" });
                    }
                    support.Add(Link(ticket.ReceiptPath, "same-render-capture-and-composite-inputs"));
                    frames.Add(new Frame { logicalFrame = logical, state = entry.state, camera = ticket.Camera,
                        samples = ticket.Result.samples, support = support.ToArray() });
                }
                if (capture.RetainedBytes != 0) reasons.Add("Owned GPU capture storage has not drained.");
                manifest.status = reasons.Count == 0 ? "complete" : "incomplete";
                manifest.reasons = reasons.ToArray(); manifest.frames = frames.ToArray();
                File.WriteAllText(Path.Combine(directory, "candidate.json"), JsonUtility.ToJson(manifest, true), new UTF8Encoding(false));
                if (closing && capture.IsDrained) capture.Changed -= OnChanged;
            }
            catch (Exception error) { Failure = error.Message; }
        }

        private Artifact Link(string absolutePath, string role)
        {
            string relative = absolutePath.Substring(directory.TrimEnd(Path.DirectorySeparatorChar).Length + 1).Replace('\\', '/');
            return new Artifact { file = relative, sha256 = Hash(File.ReadAllBytes(absolutePath)), role = role };
        }

        private Artifact[] InitialProvenance()
        {
            var artifacts = new List<Artifact>(sourceProvenance);
            artifacts.Add(Link(Path.Combine(directory, "feature.json"), "serialized-product-settings"));
            return artifacts.ToArray();
        }

        private List<Artifact> ReadSourceProvenance()
        {
            string path = Path.Combine(directory, "source-provenance.json");
            var export = JsonUtility.FromJson<SourceProvenance>(File.ReadAllText(path));
            if (export == null || export.artifacts == null)
                throw new InvalidDataException("Source export provenance is missing its artifact list.");
            var artifacts = new List<Artifact> { Link(path, "source-export-origin-index") };
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "source-provenance.json" };
            foreach (var item in export.artifacts)
            {
                if (item == null || string.IsNullOrWhiteSpace(item.file) || string.IsNullOrWhiteSpace(item.role) ||
                    item.file.Contains("\\") || item.file.Contains(":") || item.file.StartsWith("/") || !names.Add(item.file))
                    throw new InvalidDataException("Invalid or repeated source provenance artifact.");
                foreach (string segment in item.file.Split('/'))
                    if (string.IsNullOrEmpty(segment) || segment == "." || segment == "..")
                        throw new InvalidDataException("Unsafe source provenance artifact path.");
                var verified = Link(HybridLumenGIValidationSourceData.Resolve(directory, item.file), "source-export-origin:" + item.role);
                if (!string.Equals(verified.sha256, item.sha256, StringComparison.Ordinal))
                    throw new InvalidDataException("Source provenance hash mismatch: " + item.file);
                artifacts.Add(verified);
            }
            return artifacts;
        }

        private static string Hash(byte[] bytes)
        { using (var hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant(); }

        private static HybridLumenGIValidationSourceState.FileLink ImportSource(string sourceDirectory, string destination)
        {
            if (string.IsNullOrWhiteSpace(sourceDirectory)) throw new InvalidOperationException("A Player needs an explicitly exported source package for reference export.");
            string root = Path.GetFullPath(sourceDirectory), sourceFile = "source.json";
            var link = new HybridLumenGIValidationSourceState.FileLink { file = sourceFile, sha256 = Hash(File.ReadAllBytes(Path.Combine(root, sourceFile))) };
            return HybridLumenGIValidationSourceState.CopySourcePackage(root, link, destination);
        }
    }
}
