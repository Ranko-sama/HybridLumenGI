using System;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Conservative finite evaluation domain, not an importance estimate.</summary>
    public static class HybridLumenGILightRelevance
    {
        // Binary32 unit roundoff, not System.Single.Epsilon (the smallest subnormal).
        private const double UnitRoundoff = 1.0 / 16777216.0;
        public readonly struct Domain
        {
            public readonly Vector3 Minimum, Maximum;
            public readonly bool IsValid;
            private Domain(Vector3 minimum, Vector3 maximum)
            { Minimum=minimum;Maximum=maximum;IsValid=true; }
            public static bool TryCreate(Vector3 minimum,Vector3 maximum,out Domain result)
            {
                result=default;
                if(!Finite(minimum) || !Finite(maximum) || minimum.x>maximum.x || minimum.y>maximum.y || minimum.z>maximum.z) return false;
                result=new Domain(minimum,maximum);return true;
            }
            public bool TryInclude(Vector3 minimum,Vector3 maximum,out Domain result)
            {
                // Feature deliberately passes the receiver as out. Do not clear it
                // before reading its fields; readonly structs can still alias out.
                if(!IsValid || !TryCreate(minimum,maximum,out _)) { result=default;return false; }
                return TryCreate(Vector3.Min(Minimum,minimum),Vector3.Max(Maximum,maximum),out result);
            }
        }

        /// <summary>
        /// DX12 clip box: XY in [-1,1], Z in [0,1]. Use the EXACT frozen inverse
        /// uploaded to transport. Fixed homogeneous intervals cover all pixels,
        /// including jitter/Y flip. Loose bounds are intentional; unknown stays unknown.
        /// Caller separately qualifies ordinary finite non-XR camera configuration.
        /// </summary>
        public static bool TryScreenDomain(Matrix4x4 inverseGpuVP,out Domain domain)
        {
            domain=default;
            // Four multiply/add terms need at most seven rounded operations. 16u
            // also covers the double bookkeeping; XY expansion covers UV->clip math.
            double xy=1+8*UnitRoundoff;
            RowInterval(inverseGpuVP,3,xy,out double wlo,out double whi);
            if(!Finite(wlo) || !Finite(whi) || wlo<=0 || whi>float.MaxValue/4.0) return false;
            Vector3 minimum=default,maximum=default;
            for(int row=0;row<3;row++)
            {
                RowInterval(inverseGpuVP,row,xy,out double lo,out double hi);
                if(!Finite(lo) || !Finite(hi) || Math.Max(Math.Abs(lo),Math.Abs(hi))>float.MaxValue/4.0) return false;
                double a=Math.Min(lo/wlo,lo/whi),b=Math.Max(hi/wlo,hi/whi);
                // Cover the shader divide and final binary32 endpoint conversion.
                double margin=(Math.Max(Math.Abs(a),Math.Abs(b))+1)*64*UnitRoundoff;
                a-=margin;b+=margin;
                if(!Finite(a) || !Finite(b) || Math.Max(Math.Abs(a),Math.Abs(b))>float.MaxValue/4.0) return false;
                minimum[row]=(float)a;maximum[row]=(float)b;
            }
            return Domain.TryCreate(minimum,maximum,out domain);
        }
        private static void RowInterval(Matrix4x4 matrix,int row,double xy,out double lo,out double hi)
        {
            double x=matrix[row,0],y=matrix[row,1],z=matrix[row,2],w=matrix[row,3];
            double extent=(Math.Abs(x)+Math.Abs(y))*xy;
            double error=(extent+Math.Abs(z)+Math.Abs(w)+1)*16*UnitRoundoff;
            lo=w-extent+Math.Min(0,z)-error;hi=w+extent+Math.Max(0,z)+error;
        }
        public static bool StandardMatrixMatches(Matrix4x4 actual,Matrix4x4 expected)
        {
            for(int i=0;i<16;i++)
                if(!Finite(actual[i]) || !Finite(expected[i]) ||
                    Math.Abs((double)actual[i]-expected[i])>8*UnitRoundoff*Math.Max(1,Math.Abs((double)expected[i]))) return false;
            return true;
        }

        public static bool DefinitelyOutside(HybridLumenGILights.Data light,Domain domain)
        {
            if(!domain.IsValid || !Finite(light.positionType.w) || light.positionType.w<0.5f) return false;
            Vector3 position=new Vector3(light.positionType.x,light.positionType.y,light.positionType.z);
            float range=light.directionRange.w,rangeSquared=range*range;
            if(!Finite(position) || !Finite(range) || range<=0 || !Finite(rangeSquared)) return false;
            double nearestSquared=0,farthestSquared=0,scale=Math.Max(1,range);
            for(int axis=0;axis<3;axis++)
            {
                double p=position[axis],lo=domain.Minimum[axis],hi=domain.Maximum[axis];
                double nearest=Math.Max(Math.Max(lo-p,p-hi),0);
                double farthest=Math.Max(Math.Abs(lo-p),Math.Abs(hi-p));
                nearestSquared+=nearest*nearest;farthestSquared+=farthest*farthest;
                scale=Math.Max(scale,Math.Max(Math.Abs(p),Math.Max(Math.Abs(lo),Math.Abs(hi))));
            }
            // Do not remove a candidate whose original shader math may be nonfinite.
            if(!Finite(farthestSquared) || farthestSquared>float.MaxValue/4.0) return false;
            // DirectIrradiance uses max(float(range*range),1e-4). 64u times the
            // coordinate/radius scale covers subtraction, three-term dot and factor
            // rounding. Equality and this numerical boundary band remain candidates.
            double radius=Math.Sqrt(Math.Max((double)rangeSquared,(double)0.0001f))+64*UnitRoundoff*scale;
            return nearestSquared>radius*radius;
        }
        private static bool Finite(Vector3 value)=>Finite(value.x)&&Finite(value.y)&&Finite(value.z);
        private static bool Finite(double value)=>!double.IsNaN(value)&&!double.IsInfinity(value);
    }
}
