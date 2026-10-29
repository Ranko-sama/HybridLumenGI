using System;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace HybridLumenGI
{
    /// <summary>Owned two-bone door source for the ordinary sample, not a general rig builder.</summary>
    internal sealed class HybridLumenGIUnifiedSampleSkin : IDisposable
    {
        private const float MaximumBend = 20f;
        private GameObject ownedRoot;
        private Mesh ownedMesh;
        private Transform upperBone;
        private bool disposed;

        internal SkinnedMeshRenderer Renderer { get; private set; }

        internal HybridLumenGIUnifiedSampleSkin(MeshRenderer source, Mesh originalMesh)
        {
            if (!source || !originalMesh || !originalMesh.isReadable)
                throw new ArgumentException("The sample skin requires an existing renderer and readable door mesh.");
            Vector3[] vertices = originalMesh.vertices;
            if (vertices.Length == 0) throw new ArgumentException("The door mesh has no vertices.");
            var bounds = new Bounds(vertices[0], Vector3.zero);
            foreach (Vector3 position in vertices)
            {
                if (!Finite(position.x) || !Finite(position.y) || !Finite(position.z))
                    throw new ArgumentException("The door mesh contains nonfinite positions.");
                bounds.Encapsulate(position);
            }
            float height = bounds.size.y;
            float radius = new Vector2(bounds.extents.x, bounds.extents.y).magnitude;
            if (!Finite(height) || height <= 1e-6f || !Finite(radius))
                throw new ArgumentException("The door mesh needs finite, nonzero local Y extent.");

            try
            {
                ownedRoot = OwnedObject("Unified sample skinned door", source.transform, source.gameObject.layer);
                ownedRoot.SetActive(false);
                Renderer = ownedRoot.AddComponent<SkinnedMeshRenderer>();
                Renderer.hideFlags = HideFlags.HideAndDontSave;
                Renderer.enabled = false;
                ownedMesh = Object.Instantiate(originalMesh);
                ownedMesh.name = "Unified sample two-bone mesh";
                ownedMesh.hideFlags = HideFlags.HideAndDontSave;

                Transform lowerBone = OwnedObject("Lower bone", ownedRoot.transform, source.gameObject.layer).transform;
                lowerBone.localPosition = new Vector3(bounds.center.x, bounds.min.y, bounds.center.z);
                upperBone = OwnedObject("Upper bone", lowerBone, source.gameObject.layer).transform;
                upperBone.localPosition = new Vector3(0, height * .5f, 0);
                var bones = new[] { lowerBone, upperBone };
                ownedMesh.bindposes = new[]
                {
                    lowerBone.worldToLocalMatrix * ownedRoot.transform.localToWorldMatrix,
                    upperBone.worldToLocalMatrix * ownedRoot.transform.localToWorldMatrix
                };
                var weights = new BoneWeight[vertices.Length];
                for (int i = 0; i < vertices.Length; i++)
                {
                    float upperWeight = Mathf.Clamp01((vertices[i].y - bounds.min.y) / height);
                    bool upperFirst = upperWeight > .5f;
                    weights[i] = new BoneWeight
                    {
                        boneIndex0 = upperFirst ? 1 : 0, weight0 = upperFirst ? upperWeight : 1 - upperWeight,
                        boneIndex1 = upperFirst ? 0 : 1, weight1 = upperFirst ? 1 - upperWeight : upperWeight
                    };
                }
                ownedMesh.boneWeights = weights;
                ownedMesh.bounds = bounds;
                Renderer.sharedMesh = ownedMesh;
                Renderer.bones = bones;
                // Keep the root-bone and renderer coordinate spaces identical for bounds.
                Renderer.rootBone = ownedRoot.transform;
                Renderer.quality = SkinQuality.Bone2;
                Renderer.updateWhenOffscreen = true;
                Renderer.skinnedMotionVectors = true;

                CopyRenderer(source, Renderer);
                // Each weighted point lies between its rest point and its Z-rotated
                // point about the upper joint. This displacement bound covers +/-20
                // degrees in X/Y; Z is unchanged. Include a small rounding margin.
                float padding = 2 * radius * Mathf.Sin(MaximumBend * .5f * Mathf.Deg2Rad) + .001f;
                var margin = new Vector3(padding, padding, .001f);
                var animatedBounds = new Bounds();
                animatedBounds.SetMinMax(bounds.min - margin, bounds.max + margin);
                Renderer.localBounds = animatedBounds;
                ownedRoot.SetActive(true); // Renderer remains disabled until its caller switches sources.
            }
            catch
            {
                Dispose();
                throw;
            }
        }

        private static GameObject OwnedObject(string name, Transform parent, int layer)
        {
            var value = new GameObject(name) { hideFlags = HideFlags.HideAndDontSave, layer = layer };
            try { value.transform.SetParent(parent, false); return value; }
            catch { CoreUtils.Destroy(value); throw; } // No renderer or mesh has been attached yet.
        }

        private static void CopyRenderer(MeshRenderer source, SkinnedMeshRenderer target)
        {
            Material[] materials = source.sharedMaterials;
            target.sharedMaterials = materials; // Borrow material assets; never instantiate or destroy them.
            target.shadowCastingMode = source.shadowCastingMode;
            target.receiveShadows = source.receiveShadows;
            target.renderingLayerMask = source.renderingLayerMask;
            target.rendererPriority = source.rendererPriority;
            target.motionVectorGenerationMode = source.motionVectorGenerationMode;
            target.allowOcclusionWhenDynamic = source.allowOcclusionWhenDynamic;
            target.forceRenderingOff = source.forceRenderingOff;
            target.lightProbeUsage = source.lightProbeUsage;
            target.reflectionProbeUsage = source.reflectionProbeUsage;
            target.probeAnchor = source.probeAnchor;
            target.lightProbeProxyVolumeOverride = source.lightProbeProxyVolumeOverride;
            target.lightmapIndex = source.lightmapIndex;
            target.lightmapScaleOffset = source.lightmapScaleOffset;
            target.realtimeLightmapIndex = source.realtimeLightmapIndex;
            target.realtimeLightmapScaleOffset = source.realtimeLightmapScaleOffset;
            target.sortingLayerID = source.sortingLayerID;
            target.sortingOrder = source.sortingOrder;

            var block = new MaterialPropertyBlock();
            source.GetPropertyBlock(block);
            target.SetPropertyBlock(block.isEmpty ? null : block);
            for (int i = 0; i < materials.Length; i++)
            {
                block.Clear();
                source.GetPropertyBlock(block, i);
                target.SetPropertyBlock(block.isEmpty ? null : block, i);
            }
        }

        internal void SetBend(float degrees)
        {
            if (disposed) return;
            if (!Finite(degrees)) throw new ArgumentOutOfRangeException(nameof(degrees));
            upperBone.localRotation = Quaternion.AngleAxis(Mathf.Clamp(degrees, -MaximumBend, MaximumBend), Vector3.forward);
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            if (Renderer) Renderer.enabled = false;
            if (ownedRoot) ownedRoot.SetActive(false);
            GameObject root = ownedRoot;
            Mesh mesh = ownedMesh;
            Renderer = null; upperBone = null; ownedRoot = null; ownedMesh = null;
            if (!root && !mesh) return;
            // The caller withdraws the Proxy/deformation source before disposal.
            // Recorded readers retain both owned resources through the existing fence.
            HybridLumenGIResourceRetirement.Retire(() =>
            {
                if (root) CoreUtils.Destroy(root);
                if (mesh) CoreUtils.Destroy(mesh);
            });
        }

        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
    }
}
