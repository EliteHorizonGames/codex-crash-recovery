[CmdletBinding()]
param(
    [string]$Reason = 'manual Stream Deck resume'
)

. (Join-Path $PSScriptRoot 'CodexAutonomyWatchdog.Common.ps1')
$stateMutex = Enter-WatchdogStateLock
try {

$state = Get-WatchdogState
if ($null -eq $state -or [string]::IsNullOrWhiteSpace([string]$state.threadId) -or [string]::IsNullOrWhiteSpace([string]$state.workspacePath)) {
    throw 'No remembered autonomous Codex run is available to resume.'
}

foreach ($property in @{
        healthyObservations = 0
        nextRecoveryAt = $null
        recoveryExhausted = $false
    }.GetEnumerator()) {
    if ($null -eq $state.PSObject.Properties[$property.Key]) {
        $state | Add-Member -NotePropertyName $property.Key -NotePropertyValue $property.Value
    }
}

$state.autonomyActive = $true
$state.manualStopRequested = $false
$state.missingObservations = 0
$state.healthyObservations = 0
$state.restartAttempts = 0
$state.nextRecoveryAt = $null
$state.recoveryExhausted = $false
$state.lastHeartbeatAt = Get-WatchdogTimestamp
if ($null -eq $state.PSObject.Properties['stoppedAt']) {
    $state | Add-Member -NotePropertyName stoppedAt -NotePropertyValue $null
}
$state.stoppedAt = $null
Add-WatchdogEvent -State $state -Kind 'manual-resume' -Message $Reason
Save-WatchdogState -State $state
Write-WatchdogLog ('Manual resume recorded for thread {0}: {1}' -f $state.threadId, $Reason)
} finally {
    Exit-WatchdogStateLock -Mutex $stateMutex
}
