// Dependency substitutes only; complete production light collector is compiled unchanged.
// The fake object finder/component registry does not validate native Unity discovery/lifetime.
using System;
using System.Collections.Generic;
namespace UnityEngine
{
    public enum FindObjectsInactive { Exclude, Include }
    public enum FindObjectsSortMode { None, InstanceID }
    public enum LightType { Directional, Point, Spot, Area }
    public enum LightShadows { None, Hard, Soft }
    public enum LightmapBakeType { Realtime, Mixed, Baked }
    public enum ColorSpace { Gamma, Linear }
    public class Object
    {
        public static Light[] Found=Array.Empty<Light>(); public static int Scans;
        public static T[] FindObjectsByType<T>(FindObjectsInactive inactive,FindObjectsSortMode mode) where T:class
        {
            if(inactive!=FindObjectsInactive.Include || mode!=FindObjectsSortMode.InstanceID) throw new Exception("Discovery contract");
            Scans++; return (T[])(object)Found.Clone();
        }
    }
    public class Light:Object
    {
        public bool isActiveAndEnabled=true,useColorTemperature;
        public LightmapBakeType lightmapBakeType; public LightType type=LightType.Point;
        public struct BakingOutput { public LightmapBakeType lightmapBakeType; }
        public BakingOutput bakingOutput=>new BakingOutput{lightmapBakeType=lightmapBakeType};
        public float intensity=1,range=10,spotAngle=60,innerSpotAngle=30,shadowStrength=1,colorTemperature=6500;
        public int cullingMask=-1; public uint renderingLayerMask=1;
        public LightShadows shadows=LightShadows.Hard; public Color color=Color.white;
        public Transform transform=new(); public object additional;
        public T GetComponent<T>() where T:class => additional as T;
    }
    public class Transform { public Vector3 position; public Vector3 forward=new(0,0,1); }
    public struct Vector3
    {
        public float x,y,z; public Vector3(float x,float y,float z){this.x=x;this.y=y;this.z=z;}
        public static Vector3 zero=>new(); public static Vector3 operator -(Vector3 v)=>new(-v.x,-v.y,-v.z);
        public float this[int i]{get=>i==0?x:i==1?y:z;set{if(i==0)x=value;else if(i==1)y=value;else z=value;}}
        public static Vector3 Min(Vector3 a,Vector3 b)=>new(MathF.Min(a.x,b.x),MathF.Min(a.y,b.y),MathF.Min(a.z,b.z));
        public static Vector3 Max(Vector3 a,Vector3 b)=>new(MathF.Max(a.x,b.x),MathF.Max(a.y,b.y),MathF.Max(a.z,b.z));
    }
    public struct Matrix4x4
    {
        public float m00,m01,m02,m03,m10,m11,m12,m13,m20,m21,m22,m23,m30,m31,m32,m33;
        public static Matrix4x4 identity=>new(){m00=1,m11=1,m22=1,m33=1};
        public float this[int row,int column]{get=>this[column*4+row];set=>this[column*4+row]=value;}
        public float this[int i]
        {
            get=>i switch{0=>m00,1=>m10,2=>m20,3=>m30,4=>m01,5=>m11,6=>m21,7=>m31,8=>m02,9=>m12,10=>m22,11=>m32,12=>m03,13=>m13,14=>m23,_=>m33};
            set{switch(i){case 0:m00=value;break;case 1:m10=value;break;case 2:m20=value;break;case 3:m30=value;break;
                case 4:m01=value;break;case 5:m11=value;break;case 6:m21=value;break;case 7:m31=value;break;
                case 8:m02=value;break;case 9:m12=value;break;case 10:m22=value;break;case 11:m32=value;break;
                case 12:m03=value;break;case 13:m13=value;break;case 14:m23=value;break;default:m33=value;break;}}
        }
    }
    public struct Vector4:IEquatable<Vector4>
    {
        public float x,y,z,w; public Vector4(float x,float y,float z,float w){this.x=x;this.y=y;this.z=z;this.w=w;}
        public bool Equals(Vector4 v)=>x==v.x&&y==v.y&&z==v.z&&w==v.w;
        public override bool Equals(object v)=>v is Vector4 other&&Equals(other);
        // Stable across harness processes for before/after table-hash comparison;
        // this is a controlled adapter hash, not Unity's native hash implementation.
        public override int GetHashCode(){unchecked{return ((x.GetHashCode()*397^y.GetHashCode())*397^z.GetHashCode())*397^w.GetHashCode();}}
    }
    public struct Color
    {
        public float r,g,b,a; public Color(float r,float g,float b,float a=1){this.r=r;this.g=g;this.b=b;this.a=a;}
        public static Color white=>new(1,1,1);
        static float Linear(float x)=>x<=0.04045f?x/12.92f:MathF.Pow((x+.055f)/1.055f,2.4f);
        public Color linear=>new(Linear(r),Linear(g),Linear(b),a);
        public static Color operator *(Color c,float v)=>new(c.r*v,c.g*v,c.b*v,c.a*v);
        public static Color operator *(Color c,Color v)=>new(c.r*v.r,c.g*v.g,c.b*v.b,c.a*v.a);
        public static implicit operator Vector4(Color c)=>new(c.r,c.g,c.b,c.a);
    }
    public static class QualitySettings { public static ColorSpace activeColorSpace=ColorSpace.Linear; }
    public static class Mathf
    {
        public const float Deg2Rad=MathF.PI/180;
        public static float Cos(float x)=>MathF.Cos(x); public static float Max(float a,float b)=>MathF.Max(a,b);
        public static float Clamp01(float x)=>Math.Clamp(x,0,1);
        public static Color CorrelatedColorTemperatureToRGB(float x)=>new(.9f,.8f,.7f);
    }
    public struct RenderingLayerMask { public static uint DefinedMask=uint.MaxValue; public static uint GetDefinedRenderingLayersCombinedMaskValue()=>DefinedMask; }
}
namespace UnityEngine.Rendering
{
    public static class GraphicsSettings
    {
        public static bool lightsUseColorTemperature; public static object GlobalSettings=new();
        public static object GetSettingsForRenderPipeline(Type type)=>GlobalSettings;
    }
}
namespace UnityEngine.Rendering.Universal
{
    public sealed class UniversalAdditionalLightData
    { public uint renderingLayers=1,shadowRenderingLayers=1; public bool customShadowLayers; }
    public sealed class UniversalRenderPipeline { }
}
