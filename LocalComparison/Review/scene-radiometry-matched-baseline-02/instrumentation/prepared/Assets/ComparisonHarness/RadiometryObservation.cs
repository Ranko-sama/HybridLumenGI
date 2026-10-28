// Test-project-only positional receipts. No radiance is written into solver targets.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

public static class RadiometryObservation
{
    [Serializable] public class Target
    {
        public string id,kind; public int lane,logicalFrame,giFrame,entry=-1,stableId,revision;
        public uint generation; public Vector3 position,normal,geometricNormal;
    }
    [Serializable] class Rows {public Target[] targets;}
    [Serializable] class Receipt {public int logicalFrame,lane,giFrame;public uint entry;public Vector4 status,parameters;}
    static readonly Dictionary<int,Target[]> receivers=new Dictionary<int,Target[]>();
    static uint U(byte[] b,int offset)=>BitConverter.ToUInt32(b,offset);
    static float F(byte[] b,int offset)=>BitConverter.ToSingle(b,offset);
    static Vector3 V(byte[] b,int offset)=>new Vector3(F(b,offset),F(b,offset+4),F(b,offset+8));
    static Vector4 V4(byte[] b,int offset)=>new Vector4(F(b,offset),F(b,offset+4),F(b,offset+8),F(b,offset+12));
    static bool Finite(float v)=>!float.IsNaN(v)&&!float.IsInfinity(v);
    static void Validate(Target t)
    {
        foreach(float v in new[]{t.position.x,t.position.y,t.position.z,t.normal.x,t.normal.y,t.normal.z,t.geometricNormal.x,t.geometricNormal.y,t.geometricNormal.z})
            if(!Finite(v))throw new Exception("Nonfinite radiometry target");
        if(Mathf.Abs(t.normal.magnitude-1)>.002f||Mathf.Abs(t.geometricNormal.magnitude-1)>.002f)throw new Exception("Invalid radiometry normal");
    }
    public static void Receivers(string directory,int logical,int giFrame,byte[] bytes)
    {
        var targets=new Target[4];
        for(int lane=0;lane<4;lane++){
            int start=lane*256*128;int count=(int)U(bytes,start+4);int found=-1;
            for(int i=1;i<count;i++)if(U(bytes,start+i*128)==10){if(found!=-1)throw new Exception("Ambiguous GCV10 receiver");found=start+i*128;}
            if(found<0||F(bytes,found+16+16+12)!=1)throw new Exception("Receiver geometry coverage missing");
            var t=new Target{id="gi-"+lane,kind="gi",lane=lane,logicalFrame=logical,giFrame=giFrame,
                position=V(bytes,found+16),normal=V(bytes,found+32),geometricNormal=V(bytes,found+48)};
            Validate(t);targets[lane]=t;
        }
        receivers.Add(logical,targets);
        File.WriteAllText(Path.Combine(directory,"receivers-"+logical.ToString("D4")+".json"),JsonUtility.ToJson(new Rows{targets=targets},true));
    }
    public static void RequireReceivers(int logical)
    {if(!receivers.ContainsKey(logical)||receivers[logical].Length!=4)throw new Exception("Receiver completion missing at "+logical);}
    public static void LightweightCache(string directory,int logical,int giFrame,byte[] bytes)
    {
        for(int lane=0;lane<2;lane++){
            int offset=lane*320;
            File.AppendAllText(Path.Combine(directory,"cache-update-receipts.jsonl"),JsonUtility.ToJson(new Receipt{
                logicalFrame=logical,lane=lane,giFrame=giFrame,entry=U(bytes,offset+288),status=V4(bytes,offset+256),parameters=V4(bytes,offset+272)})+"\n");
        }
    }
    static Vector3 Oct(float x,float y)
    {
        // Independent decoding of the recorded geometric normal representation.
        var v=new Vector3(x,y,1-Mathf.Abs(x)-Mathf.Abs(y));
        if(v.z<0){float oldX=v.x;v.x=(1-Mathf.Abs(v.y))*(oldX>=0?1:-1);v.y=(1-Mathf.Abs(oldX))*(v.y>=0?1:-1);}
        return v.normalized;
    }
    public static void Targets(string directory,SceneLightoffTap.Selection[] selected,byte[] bytes,int giFrame)
    {
        RequireReceivers(119);
        var targets=new List<Target>();
        foreach(var p in selected){int offset=p.lane*320;
            var t=new Target{id="cache-"+p.lane,kind="cache",lane=p.lane,logicalFrame=119,giFrame=giFrame,entry=p.entry,stableId=p.stableId,revision=p.revision,generation=p.generation,
                position=V(bytes,offset+112),normal=V(bytes,offset+128),geometricNormal=Oct(F(bytes,offset+124),F(bytes,offset+140))};
            Validate(t);targets.Add(t);
        }
        targets.AddRange(receivers[119]);
        File.WriteAllText(Path.Combine(directory,"reference-targets.json"),JsonUtility.ToJson(new Rows{targets=targets.ToArray()},true));
    }
}
