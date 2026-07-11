[CmdletBinding()]
param(
    [string]$DestinationPath = (Join-Path $HOME '.codex\autonomy-watchdog'),
    [switch]$InstallScheduledTask
)

$sourcePath = $PSScriptRoot
$destinationPath = [System.IO.Path]::GetFullPath($DestinationPath)
$sourceFiles = @(
    'CodexAutonomyWatchdog.Common.ps1', 'Get-CodexAutonomyWatchdogStatus.ps1',
    'Heartbeat-CodexAutonomyRun.ps1', 'Install-CodexAutonomyWatchdog.ps1',
    'Install-StreamDeckStopButton.ps1', 'Resume-CodexAutonomyRun.ps1',
    'Run-CodexAutonomyWatchdog.vbs', 'Start-CodexAutonomyRun.ps1',
    'Stop-CodexAutonomyRun.ps1', 'StreamDeck-Resume-CodexAutonomy.vbs',
    'StreamDeck-Stop-CodexAutonomy.vbs', 'Watch-CodexAutonomy.ps1'
)

New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
foreach ($fileName in $sourceFiles) {
    Copy-Item -LiteralPath (Join-Path $sourcePath $fileName) -Destination (Join-Path $destinationPath $fileName) -Force
}

if ($InstallScheduledTask) {
    & (Join-Path $destinationPath 'Install-CodexAutonomyWatchdog.ps1')
}

Write-Output ('Installed Codex Crash Recovery files to: {0}' -f $destinationPath)
