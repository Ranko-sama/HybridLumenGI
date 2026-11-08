using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Stopwatch = System.Diagnostics.Stopwatch;

namespace HybridLumenGI
{
    /// <summary>
    /// All-camera retirement gate. Mesh/material resources may be read by ordinary URP rendering
    /// after GI. Detachment is followed by a final-context fence, or by an immediate queue
    /// fence at a proven idle boundary. Unknown submission is retained; time is never proof.
    /// </summary>
    public static class HybridLumenGIResourceRetirement
    {
        // Resolving a camera's Renderer can recreate a Feature and change registrations.
        // Replace the set on registration changes so an in-progress query can finish safely.
        private static HashSet<Func<HybridLumenGIProxy,bool>> consumers=new HashSet<Func<HybridLumenGIProxy,bool>>();
        private static readonly List<Ticket> pending=new List<Ticket>();
        private static readonly List<Owned> owned=new List<Owned>();
        private static readonly HashSet<Action> shutdownOwners=new HashSet<Action>();
        private static bool registered, outsideRenderLoop, contextEnded=true, shuttingDown, withdrawing, draining, polling, submissionUncertain;
        private static bool unavailableRepresentationScanPending, demandRepresentationScanPending;
        private static int lastRepresentationContextFrame = -1;
        private static long shutdownDeadline;
        private static int failedWithdrawals;
        private const int ShutdownMilliseconds=5000;
        private sealed class Ticket : HybridLumenGIAssetPageStreaming.ICompletion
        {
            internal GraphicsFence fence;
            internal bool submitted, requiresContext, submissionUnknown, awaitDetachedPassIdle;
            public bool IsComplete
            {
                get{if(!submitted || submissionUnknown)return false;try{return fence.passed;}catch(Exception){return false;}}
            }
        }
        private sealed class Owned
        {internal Action destroy;internal Ticket ticket;internal HybridLumenGIAssetPageStreaming.ICompletion prerequisite;internal bool failed;}
        public static void Register(Func<HybridLumenGIProxy,bool> requiresRepresentation)
        {
            if (requiresRepresentation == null) throw new ArgumentNullException(nameof(requiresRepresentation));
            if (!consumers.Contains(requiresRepresentation))
                consumers = new HashSet<Func<HybridLumenGIProxy,bool>>(consumers) { requiresRepresentation };
            EnsureRegistered();
        }
        public static void Unregister(Func<HybridLumenGIProxy,bool> requiresRepresentation)
        {
            if (requiresRepresentation == null || !consumers.Contains(requiresRepresentation)) return;
            var next = new HashSet<Func<HybridLumenGIProxy,bool>>(consumers);
            next.Remove(requiresRepresentation);
            consumers = next;
        }
        public static int PendingCount=>pending.Count;
        public static int OwnedCount=>owned.Count;
        public static bool AdmissionClosed=>shuttingDown;
        public static int FailedWithdrawalCount=>failedWithdrawals;
        internal static void RegisterShutdownOwner(Action withdraw)
        {if(withdraw==null)throw new ArgumentNullException(nameof(withdraw));shutdownOwners.Add(withdraw);EnsureRegistered();}
        internal static void UnregisterShutdownOwner(Action withdraw){if(withdraw!=null)shutdownOwners.Remove(withdraw);}
        public static int FailedCount {get{int n=0;foreach(var item in owned)if(item.failed)n++;return n;}}
        public static bool SubmissionUncertain=>submissionUncertain;
        public static int UnknownSubmissionCount {get{int n=0;foreach(var ticket in pending)if(ticket.submissionUnknown)n++;return n;}}
        internal static void RequestUnavailableRepresentationRetirement()
        {
            unavailableRepresentationScanPending = true;
        }
        internal static void RequestDemandRepresentationRetirement()
        {
            demandRepresentationScanPending = true;
        }
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void InitializeRuntime()
        {
            // No list/accounting reset: disabled domain reload may retain genuine owners.
            shuttingDown=false;shutdownDeadline=0;EnsureRegistered();
            HybridLumenGIResourceRetirementPump.EnsureExists();
        }
#if UNITY_EDITOR
        [UnityEditor.InitializeOnLoadMethod]
        private static void InitializeEditor()=>EnsureRegistered();
        private static void PlayModeChanged(UnityEditor.PlayModeStateChange state)
        {
            if(state==UnityEditor.PlayModeStateChange.ExitingPlayMode)BeginShutdown();
            // EnteredEditMode is still old-session teardown. Only new Play initialization
            // reopens admission; it does not discard old ownership or submission uncertainty.
        }
#endif
        public static void EnsureRegistered()
        {
            if(registered)return;registered=true;
            // Installed before the first context, not lazily at the first retirement.
            RenderPipelineManager.beginContextRendering+=BeginContext;
            RenderPipelineManager.endContextRendering+=EndContext;
            Application.quitting+=BeginShutdown;
#if UNITY_EDITOR
            UnityEditor.EditorApplication.update+=IdleUpdate;
            UnityEditor.EditorApplication.quitting+=BeginShutdown;
            UnityEditor.EditorApplication.playModeStateChanged+=PlayModeChanged;
            UnityEditor.AssemblyReloadEvents.beforeAssemblyReload+=BeginShutdown;
#endif
        }
        private static void BeginContext(ScriptableRenderContext context,List<Camera> cameras)
        {outsideRenderLoop=false;contextEnded=false;}
        /// <summary>Only real early-update or root PlayerLoop tail boundaries may call this.</summary>
        internal static void IdleUpdate() => IdleUpdate(atFrameEnd: false);
        internal static void IdleUpdate(bool atFrameEnd)
        {
            EnsureRegistered();
            // EndContext alone is not an outside certificate: other listeners may still run.
            if(contextEnded && !submissionUncertain)outsideRenderLoop=true;
            if(outsideRenderLoop)
            {
                // Ordinary demand already gets checked at EndContext in rendering frames.
                bool scanDemand = atFrameEnd && demandRepresentationScanPending && lastRepresentationContextFrame != Time.frameCount;
                if ((unavailableRepresentationScanPending || scanDemand) && SystemInfo.supportsGraphicsFence)
                    QueueRepresentationRetirements(requiresContext: false, includeDemand: scanDemand);
                foreach(var ticket in pending)
                    if(ticket.awaitDetachedPassIdle && !ticket.submissionUnknown)
                    {ticket.awaitDetachedPassIdle=false;ticket.requiresContext=false;}
            }
            PollOwned();
            if(outsideRenderLoop)SubmitImmediate();
            PollOwned();
            PollOtherOwners();
        }
        private static void BeginShutdown()
        {
            if(!shuttingDown)
            {
                shuttingDown=true;shutdownDeadline=Stopwatch.GetTimestamp()+Stopwatch.Frequency*ShutdownMilliseconds/1000;
                LogShutdown("begin");
                // Close admission before withdrawing any owner. Each callback detaches and
                // hands off storage; actual destruction still requires its own completion.
                withdrawing=true;
                try
                {
                    foreach(var withdraw in new List<Action>(shutdownOwners))
                    {try{withdraw();}catch(Exception error){failedWithdrawals++;Debug.LogException(error);}}
                    HybridLumenGIRayTexturePool.ClearReusable();
                }
                finally{withdrawing=false;}
                LogShutdown("owners withdrawn");
            }
            DrainShutdown();
        }
        private static void DrainShutdown()
        {
            if(draining || polling || withdrawing)return;draining=true;
            try
            {
                do
                {
                    PollOwned();if(outsideRenderLoop)SubmitImmediate();PollOwned();
                    bool cancelledWorkerRunning=PollOtherOwners();
                    if(owned.Count==0 && pending.Count==0)
                    {
                        // Only the cancelled CPU bake can finish here without a Unity update.
                        while(cancelledWorkerRunning && Stopwatch.GetTimestamp()<shutdownDeadline)
                        {
                            System.Threading.Thread.Sleep(1);
                            cancelledWorkerRunning=HybridLumenGIDeformedMesh.PollShutdownWork();
                        }
                        LogShutdown("generic drain complete");ReportOtherOwners();return;
                    }
                    if(!outsideRenderLoop || UnknownSubmissionCount!=0 || FailedCount!=0 || !CanProgressWithoutMainLoop() ||
                        !SystemInfo.supportsGraphicsFence || Stopwatch.GetTimestamp()>=shutdownDeadline)break;
                    System.Threading.Thread.Sleep(1); // Time limits waiting; it never proves completion.
                }while(true);
                Debug.LogWarning("HybridLumenGI retained unresolved retirement resources: owned="+owned.Count+
                    ", pending="+pending.Count+", unknownSubmission="+UnknownSubmissionCount+", failed="+FailedCount+
                    ", failedWithdrawals="+failedWithdrawals+", outsideRenderLoop="+outsideRenderLoop+". No completion was assumed.");
                ReportOtherOwners();
            }
            finally{draining=false;}
        }
        private static bool CanProgressWithoutMainLoop()
        {
            // Both waiting for a submitted fence and destroying a newly completed owner
            // can progress. Do not reread the fence here: it may complete after PollOwned,
            // and that transition must not strand its still-queued destroy callback.
            // Callback-dependent prerequisites remain nonblocking and retain ownership.
            foreach(var item in owned)
            {
                if(item.failed || !item.ticket.submitted || item.ticket.submissionUnknown)continue;
                try{if(item.prerequisite==null || item.prerequisite.IsComplete)return true;}
                catch(Exception){ }
            }
            // A completed parent can enqueue children during PollOwned. They still need
            // their own fence, and an eligible idle submission can make real progress.
            foreach(var ticket in pending)
                if(!ticket.requiresContext && !ticket.submissionUnknown)return true;
            return false;
        }
        private static bool PollOtherOwners()
        {
            HybridLumenGIHitMaterialPass.PollRetired();
            // Cancelled jobs from an older session remain owned across a new Play session.
            return HybridLumenGIDeformedMesh.PollShutdownWork();
        }
        private static void ReportOtherOwners()
        {
            if(HybridLumenGIHitMaterialBatch.TotalAllocatedBytes==0 && HybridLumenGIDeformedMesh.ReservedBytes==0 && failedWithdrawals==0)return;
            Debug.LogWarning("HybridLumenGI separate owners remain after generic drain: materialAndArenaBytes="+
                HybridLumenGIHitMaterialBatch.TotalAllocatedBytes+", arenaBytes="+HybridLumenGIRayTexturePool.TotalAllocatedBytes+
                ", deformationBytes="+HybridLumenGIDeformedMesh.ReservedBytes+", deformationJobs="+HybridLumenGIDeformedMesh.PendingWorkerCount+
                ", deformationCleanupFailed="+HybridLumenGIDeformedMesh.FailedCleanupCount+", failedWithdrawals="+failedWithdrawals+". Callback-dependent work was not waited on synchronously.");
        }
        [System.Diagnostics.Conditional("DEVELOPMENT_BUILD")]
        [System.Diagnostics.Conditional("UNITY_EDITOR")]
        private static void LogShutdown(string stage)
        {
            if(!shuttingDown)return;
            Debug.Log("HybridLumenGI shutdown "+stage+": outside="+outsideRenderLoop+", contextEnded="+contextEnded+
                ", owned="+owned.Count+", pending="+pending.Count+", unknown="+UnknownSubmissionCount+
                ", failed="+FailedCount+", failedWithdrawals="+failedWithdrawals+
                ", materialBytes="+HybridLumenGIHitMaterialBatch.TotalAllocatedBytes+
                ", arenaBytes="+HybridLumenGIRayTexturePool.TotalAllocatedBytes+
                ", deformationBytes="+HybridLumenGIDeformedMesh.ReservedBytes+
                ", deformationJobs="+HybridLumenGIDeformedMesh.PendingWorkerCount+
                ", deformationCleanupFailed="+HybridLumenGIDeformedMesh.FailedCleanupCount);
        }
        /// <summary>Call after atomically replacing/detaching the owned object from all new readers.</summary>
        public static void Retire(Action destroyOwned,HybridLumenGIAssetPageStreaming.ICompletion prerequisite=null)
            =>Enqueue(destroyOwned,prerequisite,false);
        /// <summary>
        /// Only for an entire renderer pass atomically detached with StopAdmission. Recorded
        /// URP graph callbacks execute synchronously within their context; retaining the pass
        /// through a subsequent real idle boundary covers their final submission. This boundary
        /// authorizes a fresh fence, never destruction or promotion of ordinary tail tickets.
        /// </summary>
        internal static void RetireDetachedPass(Action destroyOwned)
            =>Enqueue(destroyOwned,null,true);
        private static void Enqueue(Action destroyOwned,HybridLumenGIAssetPageStreaming.ICompletion prerequisite,bool detachedPass)
        {
            if(destroyOwned==null)throw new ArgumentNullException(nameof(destroyOwned));
            EnsureRegistered();var ticket=new Ticket{requiresContext=!outsideRenderLoop,submissionUnknown=submissionUncertain};
            ticket.awaitDetachedPassIdle=detachedPass && !outsideRenderLoop;
            pending.Add(ticket);owned.Add(new Owned{destroy=destroyOwned,ticket=ticket,prerequisite=prerequisite});
            if(shuttingDown)DrainShutdown();
        }
        private static void QueueRepresentationRetirements(bool requiresContext, bool includeDemand)
        {
            unavailableRepresentationScanPending = false;
            if (includeDemand) demandRepresentationScanPending = false;
            var representations=HybridLumenGIStreamedRepresentation.Active;
            for(int i=0;i<representations.Count;i++)
            {
                var representation=representations[i];
                if(ReferenceEquals(representation,null) || !representation.WantsUnload)continue;
                if (!includeDemand && !representation.IsUnavailable) continue;
                var proxy=representation.Proxy;
                bool required=false;
                if(!representation.IsUnavailable && proxy!=null && proxy.isActiveAndEnabled)
                {
                    var queries = consumers;
                    foreach(var query in queries)
                    {
                        try{if(query(proxy)){required=true;break;}}
                        catch(Exception){required=true;break;}
                    }
                    // A new consumer gets a chance to answer before any detachment.
                    required |= !ReferenceEquals(queries, consumers);
                }
                if (!required)
                {
                    var ticket = new Ticket { requiresContext = requiresContext };
                    if (representation.ReportUnloadSafe(representation.Generation, ticket))
                    {
                        pending.Add(ticket);
                        continue;
                    }
                }
                // The last consumer can leave later, with no further demand edge or context.
                if (representation.WantsUnload)
                {
                    if (representation.IsUnavailable) unavailableRepresentationScanPending = true;
                    else demandRepresentationScanPending = true;
                }
            }
        }
        private static void EndContext(ScriptableRenderContext context,List<Camera> cameras)
        {
            contextEnded=true; // Only a subsequent IdleUpdate may certify outside this event.
            PollOwned();
            lastRepresentationContextFrame = Time.frameCount;
            QueueRepresentationRetirements(requiresContext: true, includeDemand: true);
            if(pending.Count==0 || !SystemInfo.supportsGraphicsFence || submissionUncertain)return;
            var batch=new List<Ticket>();foreach(var ticket in pending)if(!ticket.submissionUnknown && !ticket.awaitDetachedPassIdle)batch.Add(ticket);
            if(batch.Count==0)return;
            var command=CommandBufferPool.Get("HybridLumenGI final-context resource retirement");
            try
            {
                GraphicsFence fence=command.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation,SynchronisationStageFlags.AllGPUOperations);
                context.ExecuteCommandBuffer(command);context.Submit();
                // Another context's later fence cannot repair an unknown earlier submission.
                foreach(var ticket in batch){ticket.fence=fence;ticket.submitted=true;pending.Remove(ticket);}
            }
            catch(Exception){MarkSubmissionUnknown();}
            finally{CommandBufferPool.Release(command);}
        }
        private static void SubmitImmediate()
        {
            if(!outsideRenderLoop || pending.Count==0 || !SystemInfo.supportsGraphicsFence || submissionUncertain)return;
            var batch=new List<Ticket>();foreach(var ticket in pending)if(!ticket.requiresContext)batch.Add(ticket);
            if(batch.Count==0)return;
            var command=CommandBufferPool.Get("HybridLumenGI idle resource retirement");
            try
            {
                var fence=command.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation,SynchronisationStageFlags.AllGPUOperations);
                Graphics.ExecuteCommandBuffer(command);
                foreach(var ticket in batch){ticket.fence=fence;ticket.submitted=true;pending.Remove(ticket);}
                LogShutdown("idle fence submitted");
            }
            catch(Exception){MarkSubmissionUnknown();}
            finally{CommandBufferPool.Release(command);}
        }
        private static void MarkSubmissionUnknown()
        {
            // The failed context may also have read still-live resources retired later.
            // Without per-reader provenance, neither a new context nor an idle fence repairs it.
            submissionUncertain=true;outsideRenderLoop=false;
            foreach(var ticket in pending)ticket.submissionUnknown=true;
        }
        private static void PollOwned()
        {
            if(polling)return;polling=true;
            try
            {
                for(int i=owned.Count-1;i>=0;i--)
                {
                    var item=owned[i];if(item.failed || !item.ticket.IsComplete)continue;
                    bool ready=false;try{ready=item.prerequisite==null || item.prerequisite.IsComplete;}catch(Exception){ }
                    if(!ready)continue;
                    try{item.destroy();owned.RemoveAt(i);LogShutdown("completed owner destroyed");}
                    catch(Exception error){item.failed=true;Debug.LogException(error);}
                }
            }
            finally{polling=false;}
        }
    }
}
