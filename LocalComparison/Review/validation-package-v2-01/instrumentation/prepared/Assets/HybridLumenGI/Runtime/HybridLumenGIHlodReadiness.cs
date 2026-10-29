using System.Collections.Generic;

namespace HybridLumenGI
{
    /// <summary>Identity/revision receipts whose GPU completion and generation checks are owned by the caller.</summary>
    public sealed class HybridLumenGIHlodReadiness
    {
        private struct Receipt { public int revision; public bool geometry, material, lighting; }
        private readonly Dictionary<int, Receipt> receipts = new Dictionary<int, Receipt>();
        public void Report(int stableId, int revision, bool geometry, bool material, bool lighting)
        {
            receipts[stableId] = new Receipt { revision = revision, geometry = geometry, material = material, lighting = lighting };
        }
        public bool IsReady(int stableId, int revision) => receipts.TryGetValue(stableId, out Receipt receipt) &&
            receipt.revision == revision && receipt.geometry && receipt.material && receipt.lighting;
        public void Invalidate(int stableId) => receipts.Remove(stableId);
        public void Clear() => receipts.Clear();
    }
}
