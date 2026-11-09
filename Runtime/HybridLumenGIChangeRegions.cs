using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>Local geometry/lighting change domains. Identity changes remain a separate hard rejection.</summary>
    public sealed class HybridLumenGIChangeRegions : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct Region { public Vector4 minimum, maximum, receiver; }
        private const int Capacity = 1088; // Up to two events with two bounds per slot, plus 64 light domains.
        private readonly Region[] regions = new Region[Capacity];
        private readonly Renderer[] receiverSources = new Renderer[Capacity];
        private readonly Dictionary<Bounds,int> byBounds = new Dictionary<Bounds,int>();
        private ComputeBuffer buffer;
        private int count;
        private float globalReactive, globalGeometryChange;
        private bool hasLocalGeometryChange, hasDisjointPoseChange;
        public int Count => count;
        public long AllocatedBytes => buffer==null?0:Capacity*48L;

        public void Begin(HybridLumenGIScene scene, float influenceRadius,Func<int,int,Renderer> receiverForChange=null)
        {
            Array.Clear(receiverSources,0,receiverSources.Length);
            count = 0; globalReactive = globalGeometryChange = 0;byBounds.Clear();
            hasLocalGeometryChange = hasDisjointPoseChange = false;
            foreach (var change in scene.DirtyRegions)
            {
                // Receiver/shadow policy alone changes light transport, not geometry.
                // Preserve hard rejection when a policy change accompanies real geometry.
                const HybridLumenGIScene.ChangeKind hard = HybridLumenGIScene.ChangeKind.Transform |
                    HybridLumenGIScene.ChangeKind.Topology | HybridLumenGIScene.ChangeKind.Manual | HybridLumenGIScene.ChangeKind.Material;
                bool geometry = change.Kind == 0 || (change.Kind & hard) != 0 ||
                    ((change.Kind & HybridLumenGIScene.ChangeKind.Representation) == 0 &&
                     (change.Kind & (HybridLumenGIScene.ChangeKind.Added | HybridLumenGIScene.ChangeKind.Removed)) != 0);
                // A proven same-primitive rigid correspondence may survive a pure
                // pose change. Topology/material/manual/representation edits cannot
                // borrow that exemption. World-cache queries still reject both kinds.
                var poseFlags=HybridLumenGIScene.ChangeKind.Transform|HybridLumenGIScene.ChangeKind.Lighting;
                bool poseOnly=(change.Kind & HybridLumenGIScene.ChangeKind.Transform)!=0 && (change.Kind & ~poseFlags)==0;
                bool disjointPose = poseOnly && change.HasPrevious && change.HasCurrent && change.DisjointSourcePose;
                hasDisjointPoseChange |= disjointPose;
                float kind=geometry?(poseOnly?1:2):0;
                Renderer receiver=null;
                if(poseOnly && receiverForChange!=null)
                    try { receiver=receiverForChange(change.Slot,change.StableId); } catch { /* Unknown ownership remains hard. */ }
                if (change.HasPrevious) AddKind(change.PreviousBounds, kind, influenceRadius, receiver, disjointPose);
                if (change.HasCurrent) AddKind(change.CurrentBounds, kind, influenceRadius, receiver, disjointPose);
            }
        }
        public void Add(Bounds bounds, bool geometry, float influenceRadius = 0)
        { AddKind(bounds,geometry?2:0,influenceRadius,null); }
        public void AddTransform(Bounds bounds,float influenceRadius=0,Renderer receiver=null)
        { AddKind(bounds,1,influenceRadius,receiver); }
        private void AddKind(Bounds bounds,float kind,float influenceRadius,Renderer receiver,bool disjointPose=false)
        {
            hasLocalGeometryChange |= kind > 0.5f;
            if (byBounds.TryGetValue(bounds,out int existing))
            {
                Region prior=regions[existing];
                if(kind>0)
                {
                    if(prior.minimum.w==0) receiverSources[existing]=receiver;
                    else if(kind>=2 || prior.minimum.w>=2 || !ReferenceEquals(receiverSources[existing],receiver))
                        receiverSources[existing]=null;
                    prior.receiver.x = 0; // Geometry merges can change the resolved receiver.
                }
                prior.minimum.w=Mathf.Max(prior.minimum.w,kind);
                if (disjointPose) prior.receiver.y = 1;
                prior.maximum.w=Mathf.Max(prior.maximum.w,Mathf.Max(0,influenceRadius));
                regions[existing]=prior;return;
            }
            if (count == regions.Length) { globalReactive = globalGeometryChange = 1; return; }
            Vector3 lo = bounds.min, hi = bounds.max;
            byBounds.Add(bounds,count);
            receiverSources[count]=kind==1?receiver:null;
            regions[count++] = new Region
            {
                minimum = new Vector4(lo.x, lo.y, lo.z, kind),
                maximum = new Vector4(hi.x, hi.y, hi.z, Mathf.Max(0, influenceRadius)),
                receiver = new Vector4(0, disjointPose ? 1 : 0, 0, 0)
            };
        }
        public void ResolveReceiverGroups(Func<Renderer,uint> resolve)
        {
            for(int i=0;i<count;i++)
            {
                uint group=0;
                if(regions[i].minimum.w==1 && !ReferenceEquals(receiverSources[i],null) && resolve!=null)
                    try { group=resolve(receiverSources[i]); } catch { /* Never infer an owner after failure. */ }
                // Float storage is exact for the bounded current-frame row group.
                regions[i].receiver.x = group <= 16384 ? group : 0;
            }
        }
        public void MarkGlobalLightingChange() { globalReactive = 1; }
        public void Upload()
        {
            EnsureBuffer();
            if (count > 0) buffer.SetData(regions, 0, 0, count);
        }
        internal void RecordUpload(CommandBuffer command)
        {
            EnsureBuffer();
            if (count > 0) command.SetBufferData(buffer, regions, 0, 0, count);
        }
        private void EnsureBuffer()
        {
            if (buffer == null) buffer = new ComputeBuffer(Capacity, 48) { name = "HLGI local changes" };
        }
        public void Bind(CommandBuffer cmd, ComputeShader shader, int kernel)
        {
            cmd.SetComputeBufferParam(shader, kernel, "_HLGI_ChangeRegions", buffer);
            cmd.SetComputeIntParam(shader, "_HLGI_ChangeCount", count);
            cmd.SetComputeFloatParam(shader, "_HLGI_GlobalReactive", globalReactive);
            cmd.SetComputeFloatParam(shader, "_HLGI_GlobalGeometryChange", globalGeometryChange);
            cmd.SetComputeIntParam(shader, "_HLGI_HasLocalGeometryChange", hasLocalGeometryChange ? 1 : 0);
            cmd.SetComputeIntParam(shader, "_HLGI_HasDisjointPoseChange", hasDisjointPoseChange ? 1 : 0);
        }
        public void Dispose() { buffer?.Release(); buffer = null; }
    }
}
