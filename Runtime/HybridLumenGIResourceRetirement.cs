using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// All-camera retirement gate. Mesh/material resources may be read by ordinary URP rendering
    /// after GI, so the completion fence is submitted at endContextRendering after detachment.
    /// An unsupported/failed fence remains pending; elapsed frames never prove completion.
    /// </summary>
    public static class HybridLumenGIResourceRetirement
    {
        private static readonly HashSet<Func<HybridLumenGIProxy,bool>> consumers=new HashSet<Func<HybridLumenGIProxy,bool>>();
        private static readonly List<Ticket> pending=new List<Ticket>();
        private static readonly List<Owned> owned=new List<Owned>();
        private static bool registered;
        private sealed class Ticket : HybridLumenGIAssetPageStreaming.ICompletion
        {
            internal GraphicsFence fence;
            internal bool submitted;
            public bool IsComplete
            {
                get{if(!submitted)return false;try{return fence.passed;}catch(Exception){return false;}}
            }
        }
        private sealed class Owned
        {internal Action destroy;internal Ticket ticket;internal HybridLumenGIAssetPageStreaming.ICompletion prerequisite;internal bool failed;}
        public static void Register(Func<HybridLumenGIProxy,bool> requiresRepresentation)
        {if(requiresRepresentation==null)throw new ArgumentNullException(nameof(requiresRepresentation));consumers.Add(requiresRepresentation);EnsureRegistered();}
        public static void Unregister(Func<HybridLumenGIProxy,bool> requiresRepresentation)
        {if(requiresRepresentation!=null)consumers.Remove(requiresRepresentation);}
        public static void EnsureRegistered()
        {if(registered)return;RenderPipelineManager.endContextRendering+=EndContext;registered=true;}
        /// <summary>Call after atomically replacing/detaching the owned object from all new readers.</summary>
        public static void Retire(Action destroyOwned,HybridLumenGIAssetPageStreaming.ICompletion prerequisite=null)
        {
            if(destroyOwned==null)throw new ArgumentNullException(nameof(destroyOwned));
            EnsureRegistered();var ticket=new Ticket();pending.Add(ticket);owned.Add(new Owned{destroy=destroyOwned,ticket=ticket,prerequisite=prerequisite});
        }
        private static void EndContext(ScriptableRenderContext context,List<Camera> cameras)
        {
            PollOwned();
            var representations=HybridLumenGIStreamedRepresentation.Active;
            for(int i=0;i<representations.Count;i++)
            {
                var representation=representations[i];
                if(ReferenceEquals(representation,null) || !representation.WantsUnload)continue;
                var proxy=representation.Proxy;
                bool required=false;
                if(!representation.IsUnavailable && proxy!=null && proxy.isActiveAndEnabled)
                {
                    foreach(var query in consumers)
                    {
                        try{if(query(proxy)){required=true;break;}}
                        catch(Exception){required=true;break;}
                    }
                }
                if(required)continue;
                var ticket=new Ticket();
                if(representation.ReportUnloadSafe(representation.Generation,ticket))pending.Add(ticket);
            }
            if(pending.Count==0 || !SystemInfo.supportsGraphicsFence)return;
            var command=CommandBufferPool.Get("HybridLumenGI final-context resource retirement");
            try
            {
                GraphicsFence fence=command.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation,SynchronisationStageFlags.AllGPUOperations);
                context.ExecuteCommandBuffer(command);context.Submit();
                // Assign only after successful submission. If submit failed after enqueuing work,
                // next context records a fresh fence covering it; nothing is prematurely freed.
                foreach(var ticket in pending){ticket.fence=fence;ticket.submitted=true;}
                pending.Clear();
            }
            catch(Exception){ /* Keep every ticket pending and retry on the next rendered context. */ }
            finally{CommandBufferPool.Release(command);}
        }
        private static void PollOwned()
        {
            for(int i=owned.Count-1;i>=0;i--)
            {
                var item=owned[i];if(item.failed || !item.ticket.IsComplete)continue;
                bool ready=false;try{ready=item.prerequisite==null || item.prerequisite.IsComplete;}catch(Exception){ }
                if(!ready)continue;
                try{item.destroy();owned.RemoveAt(i);}
                catch(Exception error){item.failed=true;Debug.LogException(error);}
            }
        }
    }
}
