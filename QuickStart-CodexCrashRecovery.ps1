[CmdletBinding()]
param(
    [string]$WorkspacePath = (Get-Location).Path,
    [string]$Label = 'Codex goal',
    [switch]$InstallStreamDeck
)

$resolvedWorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath -ErrorAction Stop).Path

Write-Output 'Installing Codex Crash Recovery and its hidden Scheduled Task...'
& (Join-Path $PSScriptRoot 'Install-CodexCrashRecovery.ps1') -InstallScheduledTask

$runtimePath = Join-Path $HOME '.codex\autonomy-watchdog'
Write-Output 'Arming recovery for the most recent Codex task...'
& (Join-Path $runtimePath 'Arm-CodexCrashRecovery.ps1') `
    -WorkspacePath $resolvedWorkspacePath `
    -Label $Label

if ($InstallStreamDeck) {
    & (Join-Path $runtimePath 'Install-StreamDeckStopButton.ps1')
} else {
    Write-Output 'Codex Crash Recovery is ready. Run QuickStart-CodexCrashRecovery.ps1 -InstallStreamDeck to add the optional Stream Deck switch.'
}
