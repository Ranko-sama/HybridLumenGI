param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$sdkLines = @(& dotnet --list-sdks)
if ($LASTEXITCODE -ne 0 -or $sdkLines.Count -eq 0) { throw "Install .NET SDK 8 or newer to run this syntax check." }
$sdkLine = $sdkLines[-1]
if ($sdkLine -notmatch '^([^ ]+) \[(.+)\]$') { throw "Cannot parse dotnet SDK location: $sdkLine" }
$roslyn = Join-Path (Join-Path $Matches[2] $Matches[1]) "Roslyn/bincore"
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-syntax-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$codeAnalysis = [System.Security.SecurityElement]::Escape((Join-Path $roslyn "Microsoft.CodeAnalysis.dll"))
$csharp = [System.Security.SecurityElement]::Escape((Join-Path $roslyn "Microsoft.CodeAnalysis.CSharp.dll"))
$project = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup>
  <ItemGroup>
    <Reference Include="Microsoft.CodeAnalysis"><HintPath>$codeAnalysis</HintPath></Reference>
    <Reference Include="Microsoft.CodeAnalysis.CSharp"><HintPath>$csharp</HintPath></Reference>
  </ItemGroup>
</Project>
"@
Set-Content -LiteralPath (Join-Path $runDirectory "SyntaxCheck.csproj") -Value $project -Encoding UTF8
$program = @'
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
var root = args[0];
int files = 0, errors = 0;
foreach (var folder in new[] { "Runtime", "Editor" })
foreach (var file in Directory.EnumerateFiles(Path.Combine(root, folder), "*.cs", SearchOption.AllDirectories))
{
    files++;
    var tree = CSharpSyntaxTree.ParseText(File.ReadAllText(file), new CSharpParseOptions(LanguageVersion.Latest), file);
    foreach (var diagnostic in tree.GetDiagnostics().Where(d => d.Severity == DiagnosticSeverity.Error))
    {
        Console.Error.WriteLine(diagnostic);
        errors++;
    }
}
Console.WriteLine($"C# syntax: {files} Runtime/Editor files, {errors} syntax errors. This does not resolve Unity APIs or compile shaders.");
return errors == 0 ? 0 : 1;
'@
Set-Content -LiteralPath (Join-Path $runDirectory "Program.cs") -Value $program -Encoding UTF8
& dotnet run --project (Join-Path $runDirectory "SyntaxCheck.csproj") --configuration Release --verbosity quiet -- $SourceRoot
if ($LASTEXITCODE -ne 0) { throw "C# syntax validation failed." }
