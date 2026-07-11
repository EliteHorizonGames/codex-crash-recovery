[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'Stop-CodexAutonomyRun.ps1')
Write-Output 'Codex Crash Recovery is unarmed. It will not reopen Codex until armed again.'
