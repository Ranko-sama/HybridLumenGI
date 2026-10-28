// Test-only geometry identity mapping. No Unity, radiance, or GPU operations.
using System;
using System.Collections.Generic;

public static class LightoffPatchMap
{
    public struct Identity
    {
        public int entry,card,slot,stableId,revision,cellX,cellY;
        public uint layout,chart,generation;
    }
    public sealed class Mapping {public int[] aliases,representatives;}
    public static bool Same(Identity a,Identity b)=>a.slot==b.slot&&a.stableId==b.stableId&&a.revision==b.revision&&
        a.layout==b.layout&&a.chart==b.chart&&a.generation==b.generation&&a.cellX==b.cellX&&a.cellY==b.cellY;
    public static Mapping Build(Identity[] rules)
    {
        if(rules.Length>4)throw new ArgumentException("Fixed observer capacity is four rules");
        var representatives=new List<int>();var aliases=new int[rules.Length];
        for(int point=0;point<rules.Length;point++)
        {
            aliases[point]=-1;if(rules[point].entry<0)continue;
            for(int unique=0;unique<representatives.Count;unique++)
            {
                var prior=rules[representatives[unique]];
                if(Same(prior,rules[point]))
                {
                    if(prior.entry!=rules[point].entry||prior.card!=rules[point].card)throw new ArgumentException("One identity has inconsistent addresses");
                    aliases[point]=unique;break;
                }
                if(prior.entry==rules[point].entry)throw new ArgumentException("Distinct identities alias one buffer address");
            }
            if(aliases[point]<0){aliases[point]=representatives.Count;representatives.Add(point);}
        }
        return new Mapping{aliases=aliases,representatives=representatives.ToArray()};
    }
}
