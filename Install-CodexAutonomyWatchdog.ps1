[CmdletBinding()]
param()

$watchdogLauncherPath = Join-Path $PSScriptRoot 'Run-CodexAutonomyWatchdog.vbs'
$taskName = 'Elite Horizon Codex Autonomy Watchdog'
if (-not (Test-Path -LiteralPath $watchdogLauncherPath)) {
    throw ('Watchdog launcher was not found: {0}' -f $watchdogLauncherPath)
}
$recurringTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\wscript.exe" -Argument ('"{0}"' -f $watchdogLauncherPath)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($recurringTrigger, $logonTrigger) -Principal $principal -Settings $settings -Description 'Safely relaunches Codex only after an armed autonomous run loses the Codex desktop process unexpectedly.' -Force | Out-Null
Write-Output ('Installed scheduled task: {0}' -f $taskName)
