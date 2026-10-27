param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
# Compile actual source classes with the shared SDK pin/offline/timeout runner.
# Only Unity math/resource APIs and scene fixtures are substituted.
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'sdf-representation' -Sources @{
    'SdfAtlas.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGISdfAtlas.cs'))
    'MeshSdf.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGIMeshSdf.cs'))
    'MeshSource.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGIMeshSource.cs'))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneSdfAtlas/UnityStubs.cs.txt'))
    'Program.cs' = "using System;`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneSdfAtlas/Program.cs.txt'))
}
