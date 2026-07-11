[CmdletBinding()]
param(
    [string]$Reason = 'manual Stream Deck stop'
)

. (Join-Path $PSScriptRoot 'CodexAutonomyWatchdog.Common.ps1')
$stateMutex = Enter-WatchdogStateLock
try {

$state = Get-WatchdogState
if ($null -eq $state) {
    $state = [pscustomobject]@{
        schemaVersion = 1
        autonomyActive = $false
        manualStopRequested = $true
        threadId = $null
        workspacePath = $null
        label = $null
        startedAt = $null
        lastHeartbeatAt = $null
        lastAppObservedAt = $null
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
}

$state.autonomyActive = $false
$state.manualStopRequested = $true
$state.missingObservations = 0
if ($null -eq $state.PSObject.Properties['stoppedAt']) {
    $state | Add-Member -NotePropertyName stoppedAt -NotePropertyValue $null
}
$state.stoppedAt = Get-WatchdogTimestamp
Add-WatchdogEvent -State $state -Kind 'manual-stop' -Message $Reason
Save-WatchdogState -State $state
Write-WatchdogLog ('Manual stop recorded: {0}' -f $Reason)
} finally {
    Exit-WatchdogStateLock -Mutex $stateMutex
}
