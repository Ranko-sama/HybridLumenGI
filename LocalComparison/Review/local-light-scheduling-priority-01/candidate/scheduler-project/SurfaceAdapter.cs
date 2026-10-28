namespace HybridLumenGI
{
    // Surface mapping adapter; the real scheduler and scene residency source execute unchanged.
    public sealed class HybridLumenGISurfaceCache
    {
        public int[] CardOwners;public bool[] ReadyMask;public readonly uint[] Generations,Layouts;public uint AtlasGeneration=1;
        public int CardCount=>CardOwners.Length;
        public HybridLumenGISurfaceCache(int[] owners,int slots)
        {CardOwners=owners;ReadyMask=Enumerable.Repeat(true,owners.Length).ToArray();Generations=Enumerable.Repeat(1u,owners.Length).ToArray();Layouts=Enumerable.Repeat(1u,slots).ToArray();}
        public uint GetGeneration(int card)=>Generations[card];
        public uint GetLayoutGeneration(int slot)=>Layouts[slot];
    }
}
