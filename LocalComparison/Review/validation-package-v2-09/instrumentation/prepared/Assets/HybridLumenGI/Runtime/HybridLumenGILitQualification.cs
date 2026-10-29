using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Conservative native diffuse qualification from shared ordinary Renderer
    /// discovery. No Proxy requirement; does not validate BRG, procedural draws or keyword parity.</summary>
    public sealed class HybridLumenGILitQualification
    {
        private readonly HybridLumenGIReceiverDiscovery discovery=new HybridLumenGIReceiverDiscovery();
        public int ScannedRenderers { get; private set; }
        public int CandidateRenderers { get; private set; }
        public int CheckedMaterials { get; private set; }

        /// <summary>Compatibility entry. Feature uses the snapshot overload to scan once.</summary>
        public bool Validate(Camera camera,LayerMask selectedLayers,out string reason)=>
            Validate(discovery.Scan(camera,selectedLayers),out reason);

        /// <summary>No source reads/mutation. Identity restrictions (LOD, static batching,
        /// additional streams) do not themselves invalidate native Lit RendererList capture.</summary>
        public bool Validate(HybridLumenGIReceiverDiscovery.Snapshot snapshot,out string reason)
        {
            ScannedRenderers=snapshot!=null?snapshot.ScannedRenderers:0;
            CandidateRenderers=snapshot!=null?snapshot.CandidateRenderers:0;
            CheckedMaterials=snapshot!=null?snapshot.CheckedMaterials:0;
            reason=snapshot!=null?snapshot.NativeDiffuseReason:"Receiver discovery snapshot is missing.";
            return snapshot!=null&&snapshot.NativeDiffuseCompatible;
        }
    }
}
