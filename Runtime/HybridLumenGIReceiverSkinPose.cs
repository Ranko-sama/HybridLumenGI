using System;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>
    /// Main-thread snapshot of an ordinary SkinnedMeshRenderer's renderer-local
    /// bone pose. Exact equality qualifies an unchanged pose within these supported
    /// inputs; it is not general deformation reprojection or a vertex snapshot.
    /// External GPU vertex writes/custom deformation are outside this contract.
    /// Mesh contents (including bind poses/weights) and materials remain subject
    /// to the receiver registry's separate source validation.
    /// </summary>
    internal sealed class HybridLumenGIReceiverSkinPose
    {
        private readonly SkinnedMeshRenderer renderer;
        private readonly Mesh mesh;
        private readonly Transform rootBone;
        private readonly Transform[] bones;
        private readonly Matrix4x4[] rendererLocalBones;
        private readonly SkinQuality quality;
        private readonly SkinWeights skinWeights;

        // Logical retained pose matrices/references, not managed/native peak memory.
        internal long LogicalBytes => 128L + bones.Length * (64L + IntPtr.Size);

        private HybridLumenGIReceiverSkinPose(SkinnedMeshRenderer renderer, Mesh mesh,
            Transform rootBone, Transform[] bones, Matrix4x4[] rendererLocalBones,
            SkinQuality quality, SkinWeights skinWeights)
        {
            this.renderer = renderer; this.mesh = mesh; this.rootBone = rootBone;
            this.bones = bones; this.rendererLocalBones = rendererLocalBones;
            this.quality = quality; this.skinWeights = skinWeights;
        }

        internal static bool TryCapture(SkinnedMeshRenderer renderer, Mesh mesh,
            Matrix4x4 rendererLocalToWorld, out HybridLumenGIReceiverSkinPose pose)
        {
            pose = null;
            try
            {
                if (renderer == null || mesh == null || !ReferenceEquals(renderer.sharedMesh, mesh) ||
                    // Cloth is an optional built-in module. A name lookup keeps this
                    // conservative rejection without requiring that module to compile.
                    !mesh.isReadable || mesh.blendShapeCount != 0 || renderer.GetComponent("Cloth") != null ||
                    !ValidTransform(rendererLocalToWorld)) return false;
                Matrix4x4 worldToRenderer = rendererLocalToWorld.inverse;
                if (!Finite(worldToRenderer)) return false;
                Transform root = renderer.rootBone;
                if (root == null) return false;
                SkinQuality quality = renderer.quality;
                SkinWeights weights = QualitySettings.skinWeights;
                if (!Enum.IsDefined(typeof(SkinQuality), quality) || !Enum.IsDefined(typeof(SkinWeights), weights)) return false;
                // bones is the array returned by this getter, retained privately;
                // no vertex arrays, BakeMesh, or previous deformed geometry are read.
                Transform[] bones = renderer.bones;
                if (bones == null || bones.Length == 0 || bones.Length != mesh.bindposeCount) return false;
                var localBones = new Matrix4x4[bones.Length];
                for (int i = 0; i < bones.Length; i++)
                {
                    if (bones[i] == null) return false;
                    Matrix4x4 boneToWorld = bones[i].localToWorldMatrix;
                    if (!ValidTransform(boneToWorld)) return false;
                    Matrix4x4 relative = worldToRenderer * boneToWorld;
                    if (!ValidTransform(relative)) return false;
                    localBones[i] = relative;
                }
                pose = new HybridLumenGIReceiverSkinPose(renderer, mesh, root, bones, localBones, quality, weights);
                return true;
            }
            catch (Exception)
            {
                // A destroyed/unreadable source cannot authorize history reuse.
                return false;
            }
        }

        internal bool SamePose(HybridLumenGIReceiverSkinPose other)
        {
            if (other == null || !ReferenceEquals(renderer, other.renderer) || !ReferenceEquals(mesh, other.mesh) ||
                !ReferenceEquals(rootBone, other.rootBone) || quality != other.quality || skinWeights != other.skinWeights ||
                bones.Length != other.bones.Length) return false;
            for (int i = 0; i < bones.Length; i++)
            {
                if (!ReferenceEquals(bones[i], other.bones[i])) return false;
                // Matrix4x4's == is approximate. Do not let a small real pose
                // change pass the unchanged-pose gate through that operator.
                for (int element = 0; element < 16; element++)
                    if (rendererLocalBones[i][element] != other.rendererLocalBones[i][element]) return false;
            }
            // Absolute renderer motion is handled by the existing object-history
            // transform. Only the relative skin pose is compared here.
            return true;
        }

        private static bool ValidTransform(Matrix4x4 value)
        {
            if (!Finite(value)) return false;
            float determinant = value.determinant;
            return !float.IsNaN(determinant) && !float.IsInfinity(determinant) && determinant != 0;
        }
        private static bool Finite(Matrix4x4 value)
        {
            for (int i = 0; i < 16; i++)
                if (float.IsNaN(value[i]) || float.IsInfinity(value[i])) return false;
            return true;
        }
    }
}
