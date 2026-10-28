$ErrorActionPreference='Stop'
$taskRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$saved=Join-Path $taskRoot 'LocalComparison/Review/scene-lightoff-chain-01/run/20261028-025041-7bd5177131a44762818963a6f19c445b/lightoff-schedule-0000.json'
$env:HLGI_PATCH_MAP_SAVED=$saved
$program=@'
using System;
using System.IO;
using System.Linq;
using System.Text.Json;
static class Program
{
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    static void Main()
    {
        using var json=JsonDocument.Parse(File.ReadAllText(Environment.GetEnvironmentVariable("HLGI_PATCH_MAP_SAVED")));
        var rules=JsonSerializer.Deserialize<LightoffPatchMap.Identity[]>(json.RootElement.GetProperty("patches").GetRawText(),new JsonSerializerOptions{IncludeFields=true});
        var aliases=LightoffPatchMap.Build(rules);
        Require(aliases.aliases.SequenceEqual(new[]{0,0,1,1}),"Saved aliases differ");
        Require(aliases.representatives.Select(i=>rules[i].entry).SequenceEqual(new[]{21,26}),"Saved unique addresses differ");
        var distinct=new[]{rules[0],rules[2]};Require(LightoffPatchMap.Build(distinct).aliases.SequenceEqual(new[]{0,1}),"Distinct identities merged");
        var absent=(LightoffPatchMap.Identity[])rules.Clone();absent[1].entry=-1;
        Require(LightoffPatchMap.Build(absent).aliases.SequenceEqual(new[]{0,-1,1,1}),"Unmapped rule invented a patch");
        var changed=rules[0];changed.revision++;Require(!LightoffPatchMap.Same(rules[0],changed),"Revision change hidden");
        bool rejected=false;try{LightoffPatchMap.Build(new[]{rules[0],changed});}catch(ArgumentException){rejected=true;}
        Require(rejected,"Different identities shared one address");
        changed.entry=22;Require(LightoffPatchMap.Build(new[]{rules[0],changed}).representatives.Length==2,"Changed identity merged after reassignment");
        Console.WriteLine("PASS: actual mapping class; saved [21,21,26,26] -> [21,26], aliases [0,0,1,1]; distinct, unmapped and identity-change controls. Offline only; no GPU execution claim.");
    }
}
'@
try {
    & (Join-Path $taskRoot 'Tests/Invoke-CSharpHarness.ps1') -Name lightoff-patch-map -Sources @{
        'LightoffPatchMap.cs'=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'LightoffPatchMap.cs'))
        'Program.cs'=$program
    }
} finally { Remove-Item Env:HLGI_PATCH_MAP_SAVED -ErrorAction SilentlyContinue }
