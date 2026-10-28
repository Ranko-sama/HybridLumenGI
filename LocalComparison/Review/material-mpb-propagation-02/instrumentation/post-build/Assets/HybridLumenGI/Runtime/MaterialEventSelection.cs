// Pure selection contract shared by the live observer and saved-input check.
using System;
namespace HybridLumenGI
{
    public static class MaterialEventSelection
    {
        public static readonly string[] ScreenRoles={"target-slot0","control"};
        public const int ScreenMask=3,TraceMask=11; // screen lanes0/1; lane2 inactive; cache lane3
        static uint U(byte[] data,int p)=>BitConverter.ToUInt32(data,p);
        static float F(byte[] data,int p)=>BitConverter.ToSingle(data,p);
        static bool Finite(float v)=>!float.IsNaN(v)&&!float.IsInfinity(v);
        public static bool MatchesSource(byte[] data,int p,uint low,uint high)=>
            U(data,p)==low&&U(data,p+4)==high&&U(data,p+8)>0&&U(data,p+12)==1;
        public static int FindInterior(byte[] identity,byte[] geometry,int width,int height,uint low,uint high,
            double centerX,double centerY,out int candidateCount)
        {
            if(identity.Length!=width*height*16||geometry.Length!=identity.Length)throw new ArgumentException("Selection payload size");
            int best=-1;double distance=double.PositiveInfinity;candidateCount=0;
            for(int y=1;y<height-1;y++)for(int x=1;x<width-1;x++)
            {
                int center=(y*width+x)*16;
                if(!MatchesSource(identity,center,low,high))continue;
                uint primitive=U(identity,center+8);bool valid=true;
                for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++)
                {
                    int p=((y+dy)*width+x+dx)*16;
                    if(!MatchesSource(identity,p,low,high)||U(identity,p+8)!=primitive||!Finite(F(geometry,p+12))||
                        F(geometry,p+12)<=1e-6||F(geometry,p+12)>1||!Finite(F(geometry,p+8))||F(geometry,p+8)<1)valid=false;
                }
                if(!valid)continue;candidateCount++;
                double d=Math.Pow((x+.5)/width-centerX,2)+Math.Pow((y+.5)/height-centerY,2);
                if(d>=distance)continue;distance=d;best=y*width+x;
            }
            return best;
        }
    }
}
