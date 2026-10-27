# Keep native stderr as diagnostic data: Windows PowerShell otherwise turns it
# into a terminating NativeCommandError when the suite uses ErrorAction=Stop.
function Invoke-HLGIOfflineCheck {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Executable,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory=$true)][string]$LogDirectory
    )
    $started = [DateTime]::UtcNow
    $logPath = Join-Path $LogDirectory ($Name + ".log")
    $exitCode = -1
    $output = ""
    $previousPreference = $ErrorActionPreference
    try {
        $command = Get-Command -Name $Executable -CommandType Application -ErrorAction Stop | Select-Object -First 1
        $ErrorActionPreference = "Continue"
        $output = (& $command.Source @Arguments 2>&1 | Out-String -Width 4096)
        $exitCode = $global:LASTEXITCODE
    } catch {
        $output += ($_ | Out-String -Width 4096)
        $exitCode = -1
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    Set-Content -LiteralPath $logPath -Value $output -Encoding utf8
    [pscustomobject]@{
        name=$Name; exitCode=$exitCode; log=$logPath; output=$output
        startedUtc=$started.ToString("o"); completedUtc=[DateTime]::UtcNow.ToString("o")
    }
}
