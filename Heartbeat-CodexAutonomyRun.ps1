[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [guid]$ThreadId,
    [string]$Note = 'atomic progress'
)

. (Join-Path $PSScriptRoot 'CodexAutonomyWatchdog.Common.ps1')
$stateMutex = Enter-WatchdogStateLock
try {

$state = Get-WatchdogState
if ($null -eq $state -or -not $state.autonomyActive) {
    throw 'No autonomous Codex run is armed.'
}

if ($state.threadId -ne $ThreadId.Guid) {
    throw 'The supplied thread ID does not match the armed autonomous run.'
}

$state.lastHeartbeatAt = Get-WatchdogTimestamp
Add-WatchdogEvent -State $state -Kind 'heartbeat' -Message $Note
Save-WatchdogState -State $state
Write-WatchdogLog ('Heartbeat recorded for thread {0}: {1}' -f $ThreadId.Guid, $Note)
} finally {
    Exit-WatchdogStateLock -Mutex $stateMutex
}
