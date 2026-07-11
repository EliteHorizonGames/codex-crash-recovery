[CmdletBinding()]
param(
    [string]$WorkspacePath = (Get-Location).Path,
    [string]$Label = 'Codex goal'
)

$resolvedWorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath -ErrorAction Stop).Path
& (Join-Path $PSScriptRoot 'Start-CodexAutonomyRun.ps1') `
    -UseMostRecentSession `
    -WorkspacePath $resolvedWorkspacePath `
    -Label $Label

Write-Output 'Codex Crash Recovery is armed for the most recent Codex task.'
