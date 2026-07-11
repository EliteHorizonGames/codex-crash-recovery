[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'CodexAutonomyWatchdog.Common.ps1')
$stateMutex = Enter-WatchdogStateLock
try {

$state = Get-WatchdogState
if ($null -eq $state -or -not $state.autonomyActive -or $state.manualStopRequested) {
    return
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

if ($state.recoveryExhausted) {
    return
}

$desktopReady = Test-CodexDesktopReady
if ($desktopReady) {
    $state.missingObservations = 0
    $state.healthyObservations = [int]$state.healthyObservations + 1
    $state.lastAppObservedAt = Get-WatchdogTimestamp
    if ($state.healthyObservations -ge 3 -and [int]$state.restartAttempts -gt 0) {
        $state.restartAttempts = 0
        $state.nextRecoveryAt = $null
        Add-WatchdogEvent -State $state -Kind 'recovery-confirmed' -Message 'Codex remained healthy for three checks; retry state reset.'
        Write-WatchdogLog 'Codex remained healthy for three checks; retry state reset.'
    }
    Save-WatchdogState -State $state
    return
}

$state.healthyObservations = 0
$state.missingObservations = [int]$state.missingObservations + 1
if ($state.missingObservations -lt 2) {
    Add-WatchdogEvent -State $state -Kind 'missing-observation' -Message 'Codex desktop process was not observed; waiting for confirmation.'
    Save-WatchdogState -State $state
    Write-WatchdogLog 'Codex desktop process missing once; waiting for the next scheduled check.'
    return
}

$nextRecovery = if ([string]::IsNullOrWhiteSpace([string]$state.nextRecoveryAt)) { $null } else { [datetime]$state.nextRecoveryAt }
if ($null -ne $nextRecovery -and (Get-Date).ToUniversalTime() -lt $nextRecovery.ToUniversalTime()) {
    Save-WatchdogState -State $state
    return
}

if ([int]$state.restartAttempts -ge 8) {
    $state.recoveryExhausted = $true
    Add-WatchdogEvent -State $state -Kind 'recovery-exhausted' -Message 'Codex remained absent after eight recovery launches; use RESUME AUTO to retry after investigating.'
    Save-WatchdogState -State $state
    Write-WatchdogLog 'Automatic recovery paused after eight failed launches.'
    return
}

try {
    Start-CodexDesktop
    if (-not (Wait-CodexDesktopReady)) {
        throw 'Codex did not expose a desktop window within 25 seconds of the recovery launch.'
    }
    Open-CodexThread -ThreadId ([guid]$state.threadId)
    $state.restartAttempts = [int]$state.restartAttempts + 1
    $state.lastRecoveryAt = Get-WatchdogTimestamp
    $retryDelaysMinutes = @(1, 2, 5, 10, 15, 20, 30, 30)
    $delayMinutes = $retryDelaysMinutes[[int]$state.restartAttempts - 1]
    $state.nextRecoveryAt = (Get-Date).ToUniversalTime().AddMinutes($delayMinutes).ToString('o')
    $state.missingObservations = 0
    Add-WatchdogEvent -State $state -Kind 'recovery-launch' -Message ('Recovery {0}/8 launched Codex and requested thread {1}; next retry no sooner than {2} minute(s). No prompt was sent.' -f $state.restartAttempts, $state.threadId, $delayMinutes)
    Save-WatchdogState -State $state
    Write-WatchdogLog ('Recovery launch {0}/8: Codex opened and thread requested; retry delay {1} minute(s).' -f $state.restartAttempts, $delayMinutes)
} catch {
    $state.restartAttempts = [int]$state.restartAttempts + 1
    $retryDelaysMinutes = @(1, 2, 5, 10, 15, 20, 30, 30)
    $delayMinutes = $retryDelaysMinutes[[int]$state.restartAttempts - 1]
    $state.lastRecoveryAt = Get-WatchdogTimestamp
    $state.nextRecoveryAt = (Get-Date).ToUniversalTime().AddMinutes($delayMinutes).ToString('o')
    Add-WatchdogEvent -State $state -Kind 'recovery-error' -Message $_.Exception.Message
    Save-WatchdogState -State $state
    Write-WatchdogLog ('Recovery launch {0}/8 failed; retry delay {1} minute(s): {2}' -f $state.restartAttempts, $delayMinutes, $_.Exception.Message)
    throw
}
} finally {
    Exit-WatchdogStateLock -Mutex $stateMutex
}
