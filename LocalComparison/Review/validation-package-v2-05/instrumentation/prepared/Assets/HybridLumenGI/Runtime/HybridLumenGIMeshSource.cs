using System.Runtime.CompilerServices;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>
    /// Shared, main-thread invalidation versions for the actual Mesh reference.
    /// This observes explicit notifications, not vertex/index buffer contents.
    /// A same-count/bounds edit requires NotifyGeometryChanged (or Proxy.MarkDirty),
    /// unless its consumer independently verifies the complete source contents.
    /// </summary>
    public static class HybridLumenGIMeshSource
    {
        /// <summary>
        /// Immutable opaque identity. Compare by ReferenceEquals; there is no numeric
        /// counter to wrap, and a retired version is never published again. A retained
        /// version does not retain its Mesh. This is not a serialized or GPU identity.
        /// </summary>
        public sealed class Version
        {
            internal Version() { }
        }

        private sealed class Source
        {
            internal Version current = new Version();
        }
        private static readonly ConditionalWeakTable<Mesh, Source> Sources = new ConditionalWeakTable<Mesh, Source>();
        private static readonly ConditionalWeakTable<Mesh, Source>.CreateValueCallback Factory = CreateSource;

        /// <summary>
        /// Main-thread O(1) lookup without reading Mesh buffers, counts or bounds.
        /// Null/destroyed meshes have no version. Unity instance IDs and object
        /// equality are never used to associate two live Mesh references.
        /// </summary>
        public static Version GetVersion(Mesh mesh)
        {
            if (mesh == null) return null;
            return Sources.GetValue(mesh, Factory).current;
        }

        /// <summary>
        /// Call on the main thread after source vertex/index/layout/attribute edits.
        /// Every consumer of this Mesh sees the replacement version on its next
        /// lookup. This does not visit proxies or hash/rebuild any geometry.
        /// </summary>
        public static Version NotifyGeometryChanged(Mesh mesh)
        {
            if (mesh == null) return null;
            Source source = Sources.GetValue(mesh, Factory);
            source.current = new Version();
            return source.current;
        }

        private static Source CreateSource(Mesh mesh) => new Source();
    }
}
