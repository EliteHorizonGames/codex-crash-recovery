[CmdletBinding()]
param()

$root = Split-Path -Parent $PSScriptRoot
$requiredFiles = @('QuickStart-CodexCrashRecovery.ps1', 'Install-CodexCrashRecovery.ps1', 'Install-StreamDeckStopButton.ps1', 'Arm-CodexCrashRecovery.ps1', 'Unarm-CodexCrashRecovery.ps1')
$scriptFiles = Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File
$failed = $false

foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $requiredFile) -PathType Leaf)) {
        $failed = $true
        Write-Error ('Required public entry point is missing: {0}' -f $requiredFile)
    }
}

foreach ($scriptFile in $scriptFiles) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failed = $true
        Write-Error ('Parse failed: {0}' -f $scriptFile.Name)
        $errors | ForEach-Object { Write-Error $_.Message }
    } else {
        Write-Output ('PARSE_PASS {0}' -f $scriptFile.Name)
    }
}

$hardcodedUserPath = rg -n --glob '*.ps1' --glob '*.vbs' 'C:\\Users\\Premium' $root
if ($LASTEXITCODE -eq 0) {
    $failed = $true
    Write-Error 'A machine-specific user path was found in publishable source.'
    $hardcodedUserPath
} elseif ($LASTEXITCODE -eq 1) {
    Write-Output 'PORTABILITY_SCAN_PASS'
} else {
    exit $LASTEXITCODE
}

if ($failed) {
    exit 1
}
