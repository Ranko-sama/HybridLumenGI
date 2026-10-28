using System;
namespace UnityEngine
{
    public partial struct Vector3
    {
        public float x,y,z;
        public Vector3(float x,float y,float z) { this.x=x; this.y=y; this.z=z; }
        public float this[int i] => i==0?x:i==1?y:z;
        public static Vector3 zero => new(0,0,0);
        public static Vector3 one => new(1,1,1);
        public float sqrMagnitude => x*x+y*y+z*z;
        public float magnitude => MathF.Sqrt(sqrMagnitude);
        public Vector3 normalized => this/magnitude;
        public static Vector3 operator +(Vector3 a,Vector3 b)=>new(a.x+b.x,a.y+b.y,a.z+b.z);
        public static Vector3 operator -(Vector3 a,Vector3 b)=>new(a.x-b.x,a.y-b.y,a.z-b.z);
        public static Vector3 operator *(Vector3 a,float b)=>new(a.x*b,a.y*b,a.z*b);
        public static Vector3 operator /(Vector3 a,float b)=>new(a.x/b,a.y/b,a.z/b);
        public static Vector3 Min(Vector3 a,Vector3 b)=>new(MathF.Min(a.x,b.x),MathF.Min(a.y,b.y),MathF.Min(a.z,b.z));
        public static Vector3 Max(Vector3 a,Vector3 b)=>new(MathF.Max(a.x,b.x),MathF.Max(a.y,b.y),MathF.Max(a.z,b.z));
        public override string ToString()=>$"({x},{y},{z})";
    }
    public partial struct Bounds
    {
        public Vector3 center,size;
        public Bounds(Vector3 center,Vector3 size) { this.center=center; this.size=size; }
        public Vector3 extents { get=>size*.5f; set=>size=value*2; }
        public Vector3 min => center-extents;
        public Vector3 max => center+extents;
        public void Encapsulate(Vector3 p) { Vector3 a=Vector3.Min(min,p),b=Vector3.Max(max,p); center=(a+b)*.5f;size=b-a; }
        public void Encapsulate(Bounds b) { Encapsulate(b.min); Encapsulate(b.max); }
    }
    public static partial class Mathf
    {
        public static float Max(float a,float b)=>MathF.Max(a,b);
        public static float Min(float a,float b)=>MathF.Min(a,b);
        public static int Max(int a,int b)=>Math.Max(a,b);
        public static float Abs(float x)=>MathF.Abs(x);
    }
    public enum ComputeBufferType { Structured }
    public sealed class ComputeBuffer
    {
        public string name;
        public readonly int count,stride;
        public object[] Data;
        public bool Released;
        public readonly System.Collections.Generic.List<(int source,int destination,int count)> Uploads=new();
        public ComputeBuffer(int count,int stride,ComputeBufferType type) {this.count=count;this.stride=stride;Data=new object[count];}
        public void Release() {Released=true;}
        public void SetData(Array data) {SetData(data,0,0,data.Length);}
        public void SetData(Array data,int managedBufferStartIndex,int computeBufferStartIndex,int count)
        {
            if(Released||managedBufferStartIndex<0||computeBufferStartIndex<0||count<0||managedBufferStartIndex+count>data.Length||computeBufferStartIndex+count>this.count)throw new InvalidOperationException("Invalid recording buffer upload");
            for(int i=0;i<count;i++)Data[computeBufferStartIndex+i]=data.GetValue(managedBufferStartIndex+i);
            Uploads.Add((managedBufferStartIndex,computeBufferStartIndex,count));
        }
    }
    public class ComputeShader { }
    public static class Shader { public static int PropertyToID(string name)=>name.GetHashCode(); }
}
namespace UnityEngine.Rendering
{
    public enum ShadowCastingMode { Off=0, On=1, TwoSided=2, ShadowsOnly=3 }
    public class CommandBuffer
    {
        public void SetComputeBufferParam(UnityEngine.ComputeShader compute,int kernel,int id,UnityEngine.ComputeBuffer buffer) { }
        public void SetComputeIntParam(UnityEngine.ComputeShader compute,int id,int value) { }
    }
}
