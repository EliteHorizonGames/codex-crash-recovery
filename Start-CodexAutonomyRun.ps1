[CmdletBinding()]
param(
    [guid]$ThreadId,
    [switch]$UseMostRecentSession,
    [switch]$ReplaceActiveRun,
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$WorkspacePath,
    [string]$Label = 'Autonomous Codex run'
)

. (Join-Path $PSScriptRoot 'CodexAutonomyWatchdog.Common.ps1')
$stateMutex = Enter-WatchdogStateLock
try {

if ($UseMostRecentSession) {
    $ThreadId = Get-MostRecentCodexThreadId
} elseif ($ThreadId -eq [guid]::Empty) {
    throw 'Supply -ThreadId or use -UseMostRecentSession.'
}

$existingState = Get-WatchdogState
if ($null -ne $existingState -and $existingState.autonomyActive -and -not $existingState.manualStopRequested -and $existingState.threadId -ne $ThreadId.Guid -and -not $ReplaceActiveRun) {
    throw ('A different autonomous run is already armed for thread {0}. Use -ReplaceActiveRun only after verifying that replacement is intended.' -f $existingState.threadId)
}

$now = Get-WatchdogTimestamp
$state = [pscustomobject]@{
    schemaVersion = 1
    autonomyActive = $true
    manualStopRequested = $false
    threadId = $ThreadId.Guid
    workspacePath = (Resolve-Path -LiteralPath $WorkspacePath).Path
    label = $Label
    startedAt = $now
    lastHeartbeatAt = $now
    lastAppObservedAt = $now
    missingObservations = 0
    healthyObservations = 0
    restartAttempts = 0
    lastRecoveryAt = $null
    nextRecoveryAt = $null
    recoveryExhausted = $false
    stoppedAt = $null
    recoveryMode = 'reopen-thread-only'
    autoPromptResumeEnabled = $false
    events = @()
}

    Add-WatchdogEvent -State $state -Kind 'armed' -Message ('Tracking thread {0}.' -f $ThreadId.Guid)
Save-WatchdogState -State $state
Write-WatchdogLog ('Armed for thread {0} in {1}.' -f $ThreadId.Guid, $state.workspacePath)
} finally {
    Exit-WatchdogStateLock -Mutex $stateMutex
}
