using System;
using System.IO;
using System.Runtime.CompilerServices;
using UnityEngine;

namespace HybridLumenGI
{
    // Temporary observer. Weak keys assign identities without extending native resource lifetime.
    internal static class PageWithdrawalTap
    {
        private sealed class Token { internal int value; }
        private static readonly ConditionalWeakTable<object,Token> ids=new ConditionalWeakTable<object,Token>();
        private static int next,sequence;
        internal static int Tick;
        internal static string DirectoryPath,Failure;
        internal static bool Active;
        internal static int Id(object value)=>ReferenceEquals(value,null)?0:ids.GetValue(value,_=>new Token{value=++next}).value;
        [Serializable] internal sealed class Page
        {
            public string id,phase,error;public uint generation;public int operation,bundle,asset,refs,pins;
            public bool requested,wanted,bundleReserved,residentReserved;public long retryAt;public string[] dependencies;
        }
        [Serializable] internal sealed class Row
        {
            public int sequence,tick,engine,operation,native,assetId;public string stage,page,error;
            public bool done;public Page state;public Page[] pages;public long bundleBytes,residentBytes,ioBytes,ioStarted,uploadStarted;
            public int operations,starts,retiring,blocked;
        }
        internal static Page Describe(HybridLumenGIAssetPageStreaming.State s)=>new Page{id=s.Id,phase=s.Status.ToString(),generation=s.Generation,
            operation=Id(s.operation),bundle=Id(s.bundle),asset=Id(s.asset),refs=s.referenceCount,pins=s.releasePins,requested=s.requested,wanted=s.Wanted,
            bundleReserved=s.bundleReserved,residentReserved=s.residentReserved,retryAt=s.retryAt,error=s.LastError,dependencies=s.definition.dependencies};
        internal static void Write(Row row)
        {
            if(!Active)return;
            try{row.sequence=++sequence;row.tick=Tick;row.engine=Time.frameCount;File.AppendAllText(Path.Combine(DirectoryPath,"events.jsonl"),JsonUtility.ToJson(row)+"\n");}
            catch(Exception e){Failure=e.ToString();}
        }
        internal static void Snapshot(string stage,HybridLumenGIAssetPageStreaming s)
        {
            if(!Active)return;
            try
            {
                var pages=new Page[s.States.Count];for(int i=0;i<pages.Length;i++)pages[i]=Describe(s.States[i]);
                Write(new Row{stage=stage,pages=pages,bundleBytes=s.BundleBytes,residentBytes=s.ResidentBytes,ioBytes=s.IoBytesInFlight,
                    ioStarted=s.IoBytesStarted,uploadStarted=s.UploadBytesStarted,operations=s.ActiveOperations,starts=s.OperationsStarted,
                    retiring=s.RetiringLeases,blocked=s.BudgetBlocked});
            }catch(Exception e){Failure=e.ToString();}
        }
        internal static void PageEvent(string stage,HybridLumenGIAssetPageStreaming.State s,bool done=false,string error=null,object result=null)
        {
            if(!Active)return;
            try{Write(new Row{stage=stage,page=s.Id,state=Describe(s),operation=Id(s.operation),done=done,error=error,assetId=Id(result)});}
            catch(Exception e){Failure=e.ToString();}
        }
        internal static T Start<T>(T operation,object native,HybridLumenGIAssetPageStreaming.Definition def,string stage) where T:class
        {
            if(Active)try{Write(new Row{stage=stage,page=def.id,operation=Id(operation),native=Id(native)});}catch(Exception e){Failure=e.ToString();}
            return operation;
        }
        internal static void ReleaseCall(string stage,object operation,object native,UnityEngine.Object asset)
        {
            if(Active)try{Write(new Row{stage=stage,operation=Id(operation),native=Id(native),assetId=Id(asset)});}catch(Exception e){Failure=e.ToString();}
        }
    }
}
