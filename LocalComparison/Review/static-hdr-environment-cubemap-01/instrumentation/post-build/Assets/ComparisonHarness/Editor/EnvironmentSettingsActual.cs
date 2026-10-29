using System;
using System.IO;
using HybridLumenGI;
using UnityEngine;
public static class EnvironmentSettingsActual
{
    sealed class Scene { public int calls;public void InvalidateReadiness(){calls++;} }
    sealed class Readiness { public int calls;public void Invalidate(){calls++;} }
    sealed class State { public int lastSettingsHash,epoch=1,history;public Scene scene=new Scene();public Readiness readiness=new Readiness();public void InvalidateScreenHistory(){history++;} }
    [Serializable] sealed class Row {public string label,serialized;public int hash,epoch,history,scene,readiness;}
    [Serializable] sealed class Receipt {public Row[] rows;public bool passed;}
    static void Actual(HybridLumenGIRendererFeature.Settings s,State state)
    {
                string serializedSettings=JsonUtility.ToJson(s);
                int settingsHash=serializedSettings.GetHashCode();
                if(settingsHash!=state.lastSettingsHash)
                {
                    state.lastSettingsHash=settingsHash;state.epoch=state.epoch%8000000+1;state.InvalidateScreenHistory();
                    state.scene.InvalidateReadiness();state.readiness.Invalidate();
                }

    }
    public static bool Check(Cubemap a,Cubemap b,string folder)
    {
        var s=new HybridLumenGIRendererFeature.Settings();var state=new State();var rows=new Row[5];
        var sources=new Cubemap[]{null,a,a,b,null};var labels=new[]{"null","A","same-A","B","clear"};var counts=new[]{1,2,2,3,4};bool passed=true;
        for(int i=0;i<sources.Length;i++)
        {
            s.environmentCubemap=sources[i];string serialized=JsonUtility.ToJson(s);
            if(i==0)state.lastSettingsHash=serialized.GetHashCode()^1;
            Actual(s,state);rows[i]=new Row{label=labels[i],serialized=serialized,hash=serialized.GetHashCode(),epoch=state.epoch,history=state.history,scene=state.scene.calls,readiness=state.readiness.calls};
            passed &= state.epoch==counts[i]+1 && state.history==counts[i] && state.scene.calls==counts[i] && state.readiness.calls==counts[i];
        }
        passed &= rows[0].serialized==rows[4].serialized && rows[1].serialized==rows[2].serialized && rows[0].serialized!=rows[1].serialized && rows[1].serialized!=rows[3].serialized && rows[3].serialized!=rows[4].serialized;
        File.WriteAllText(Path.Combine(folder,"settings.json"),JsonUtility.ToJson(new Receipt{rows=rows,passed=passed},true));return passed;
    }
}
