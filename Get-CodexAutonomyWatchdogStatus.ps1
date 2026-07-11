[CmdletBinding()]
param(
    [ValidateRange(1, 100)]
    [int]$RecentEvents = 12
)

. (Join-Path $PSScriptRoot 'CodexAutonomyWatchdog.Common.ps1')

$stateMutex = Enter-WatchdogStateLock
try {
    $state = Get-WatchdogState
    $task = Get-ScheduledTask -TaskName 'Elite Horizon Codex Autonomy Watchdog' -ErrorAction SilentlyContinue
    $taskInfo = if ($null -ne $task) { Get-ScheduledTaskInfo -TaskName $task.TaskName } else { $null }

    [pscustomobject]@{
        armed = if ($null -eq $state) { $false } else { [bool]$state.autonomyActive }
        manualStopRequested = if ($null -eq $state) { $true } else { [bool]$state.manualStopRequested }
        threadId = if ($null -eq $state) { $null } else { $state.threadId }
        restartAttempts = if ($null -eq $state) { 0 } else { $state.restartAttempts }
        recoveryExhausted = if ($null -eq $state) { $false } else { [bool]$state.recoveryExhausted }
        taskState = if ($null -eq $task) { 'missing' } else { [string]$task.State }
        taskLastResult = if ($null -eq $taskInfo) { $null } else { $taskInfo.LastTaskResult }
        taskNextRun = if ($null -eq $taskInfo) { $null } else { $taskInfo.NextRunTime }
    } | ConvertTo-Json -Depth 4

    if (Test-Path -LiteralPath $script:EventLogPath) {
        Get-Content -LiteralPath $script:EventLogPath -Tail $RecentEvents
    }
} finally {
    Exit-WatchdogStateLock -Mutex $stateMutex
}
