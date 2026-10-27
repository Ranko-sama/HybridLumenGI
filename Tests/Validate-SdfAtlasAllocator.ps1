param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$taskDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-sdf-atlas-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $taskDirectory | Out-Null
$atlas = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGISdfAtlas.cs") -Raw
$start = $atlas.IndexOf("        private bool Allocate(")
$end = $atlas.IndexOf("        private static bool Equal(", $start)
if ($start -lt 0 -or $end -le $start) { throw "Atlas allocator methods not found; update test extraction." }
$methods = $atlas.Substring($start, $end - $start).Replace("private bool Allocate", "public bool Allocate").Replace("private void Free", "public void Free")
$source = @'
using System;
using System.Collections.Generic;
class AtlasAllocator
{
    private struct FreeRange
    {
        public int begin, count;
        public FreeRange(int start, int length) { begin = start; count = length; }
    }
    private readonly List<FreeRange> freeRanges = new List<FreeRange>();
    public AtlasAllocator(int count) { freeRanges.Add(new FreeRange(0, count)); }
'@ + $methods + "`n}"
Set-Content -LiteralPath (Join-Path $taskDirectory "AtlasAllocator.cs") -Value $source -Encoding utf8
$program = @'
using System;
using System.Collections.Generic;
const int capacity = 1024;
var allocator = new AtlasAllocator(capacity);
var live = new List<(int offset, int count)>();
var occupied = new bool[capacity];
var random = new Random(53017);
int successes = 0, evictions = 0;
for (int iteration = 0; iteration < 10000; iteration++)
{
    if (live.Count > 0 && random.NextDouble() < 0.45)
    {
        int index = random.Next(live.Count);
        var range = live[index];
        allocator.Free(range.offset, range.count);
        live.RemoveAt(index);
        for (int p = range.offset; p < range.offset + range.count; p++) occupied[p] = false;
        evictions++;
    }
    else
    {
        int count = random.Next(1, 96);
        if (!allocator.Allocate(count, out int offset)) continue;
        if (offset < 0 || offset + count > capacity) throw new Exception("Atlas range escaped capacity.");
        for (int p = offset; p < offset + count; p++)
        {
            if (occupied[p]) throw new Exception("Two resident SDF volumes overlap.");
            occupied[p] = true;
        }
        live.Add((offset, count));
        successes++;
    }
}
foreach (var range in live) allocator.Free(range.offset, range.count);
if (!allocator.Allocate(capacity, out int whole) || whole != 0)
    throw new Exception("Freed ranges did not coalesce back to the full atlas.");
if (allocator.Allocate(1, out _)) throw new Exception("An exhausted atlas accepted an extra voxel.");
Console.WriteLine($"Current-source SDF atlas allocator passed: {successes} placements, {evictions} evictions, no overlap/out-of-bounds, full coalescence. GPU/Unity execution not tested.");
'@
Set-Content -LiteralPath (Join-Path $taskDirectory "Program.cs") -Value $program -Encoding utf8
Set-Content -LiteralPath (Join-Path $taskDirectory "Check.csproj") -Encoding utf8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $taskDirectory "Check.csproj") --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw "SDF atlas allocator validation failed." }
