Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:WatchdogRoot = $PSScriptRoot
$script:StatePath = Join-Path $script:WatchdogRoot 'state.json'
$script:LogPath = Join-Path $script:WatchdogRoot 'watchdog.log'
$script:EventLogPath = Join-Path $script:WatchdogRoot 'watchdog.events.jsonl'
$script:MaxLogBytes = 1048576
$script:StateMutexName = 'Local\EliteHorizonCodexAutonomyWatchdogState'

function Enter-WatchdogStateLock {
    $mutex = New-Object System.Threading.Mutex($false, $script:StateMutexName)
    try {
        if (-not $mutex.WaitOne([TimeSpan]::FromSeconds(5))) {
            throw 'Timed out waiting for the Codex autonomy watchdog state lock.'
        }
    } catch [System.Threading.AbandonedMutexException] {
        # The previous owner exited unexpectedly; this process now owns the lock.
        Write-Verbose 'Recovered an abandoned Codex autonomy watchdog state lock.'
    }

    $mutex
}

function Exit-WatchdogStateLock {
    param(
        [Parameter(Mandatory)]
        [System.Threading.Mutex]$Mutex
    )

    try {
        $Mutex.ReleaseMutex()
    } finally {
        $Mutex.Dispose()
    }
}

function Get-WatchdogTimestamp {
    (Get-Date).ToUniversalTime().ToString('o')
}

function Write-WatchdogLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('info', 'warning', 'error')]
        [string]$Level = 'info'
    )

    try {
        foreach ($path in @($script:LogPath, $script:EventLogPath)) {
            if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -ge $script:MaxLogBytes) {
                Move-Item -LiteralPath $path -Destination ('{0}.previous' -f $path) -Force
            }
        }

        $timestamp = Get-WatchdogTimestamp
        $line = ('{0} [{1}] {2}' -f (Get-Date).ToString('dd.MM.yyyy HH:mm:ss'), $Level.ToUpperInvariant(), $Message)
        Add-Content -LiteralPath $script:LogPath -Value $line
        [pscustomobject]@{
            at = $timestamp
            level = $Level
            message = $Message
        } | ConvertTo-Json -Compress | Add-Content -LiteralPath $script:EventLogPath
    } catch {
        # Logging must never stop recovery or overwrite the original operational failure.
        Write-Verbose ('Watchdog logging failed: {0}' -f $_.Exception.Message)
    }
}

function Get-WatchdogState {
    if (-not (Test-Path -LiteralPath $script:StatePath)) {
        return $null
    }

    try {
        Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    } catch {
        $backupPath = Join-Path $script:WatchdogRoot 'state.previous.json'
        if (-not (Test-Path -LiteralPath $backupPath)) {
            throw
        }

        Write-WatchdogLog 'Primary state file was unreadable; using the rolling backup state.'
        Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
    }
}

function Save-WatchdogState {
    param(
        [Parameter(Mandatory)]
        [psobject]$State
    )

    $temporaryPath = Join-Path $script:WatchdogRoot ('state.{0}.tmp' -f [guid]::NewGuid().ToString('N'))
    try {
        $json = $State | ConvertTo-Json -Depth 8
        $utf8WithoutBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8WithoutBom)
        if (Test-Path -LiteralPath $script:StatePath) {
            $backupPath = Join-Path $script:WatchdogRoot 'state.previous.json'
            [System.IO.File]::Replace($temporaryPath, $script:StatePath, $backupPath)
        } else {
            [System.IO.File]::Move($temporaryPath, $script:StatePath)
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Add-WatchdogEvent {
    param(
        [Parameter(Mandatory)]
        [psobject]$State,
        [Parameter(Mandatory)]
        [string]$Kind,
        [Parameter(Mandatory)]
        [string]$Message
    )

    $watchdogEvent = [pscustomobject]@{
        at = Get-WatchdogTimestamp
        kind = $Kind
        message = $Message
    }

    $events = @($State.events) + $watchdogEvent
    $State.events = @($events | Select-Object -Last 30)
}

function Get-CodexDesktopProcess {
    $package = Get-AppxPackage -Name OpenAI.Codex -ErrorAction Stop
    $manifest = $package | Get-AppxPackageManifest
    $relativeExecutable = $manifest.Package.Applications.Application.Executable.Replace('/', [string][System.IO.Path]::DirectorySeparatorChar)
    $executablePath = Join-Path $package.InstallLocation $relativeExecutable
    $processName = [System.IO.Path]::GetFileNameWithoutExtension($executablePath)

    @(
        Get-Process -Name $processName -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Path -eq $executablePath
            }
    )
}

function Test-CodexDesktopReady {
    @(
        Get-CodexDesktopProcess |
            Where-Object { $_.MainWindowHandle -ne 0 }
    ).Count -gt 0
}

function Wait-CodexDesktopReady {
    param(
        [int]$TimeoutSeconds = 25
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-CodexDesktopReady) {
            return $true
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    $false
}

function Get-MostRecentCodexThreadId {
    $candidateFiles = @()
    foreach ($offset in 0..2) {
        $candidateDate = (Get-Date).AddDays(-$offset)
        $sessionDirectory = Join-Path $env:USERPROFILE ('.codex\sessions\{0:yyyy}\{0:MM}\{0:dd}' -f $candidateDate)
        if (Test-Path -LiteralPath $sessionDirectory) {
            $candidateFiles += Get-ChildItem -LiteralPath $sessionDirectory -Filter 'rollout-*.jsonl' -File
        }
    }

    $latestFile = $candidateFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $latestFile) {
        throw 'No recent Codex rollout session was found in the bounded three-day lookup.'
    }

    $regexMatch = [regex]::Match($latestFile.Name, '(?<threadId>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $regexMatch.Success) {
        throw ('The most recent Codex rollout filename does not contain a thread UUID: {0}' -f $latestFile.Name)
    }

    [guid]$regexMatch.Groups['threadId'].Value
}

function Get-CodexDesktopAppId {
    $application = Get-StartApps |
        Where-Object { $_.AppID -like 'OpenAI.Codex_*!App' } |
        Select-Object -First 1

    if ($null -eq $application) {
        throw 'Could not locate the installed OpenAI.Codex Start Menu application.'
    }

    $application.AppID
}

function Start-CodexDesktop {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $applicationId = Get-CodexDesktopAppId
    if ($PSCmdlet.ShouldProcess('Codex Desktop', 'Start')) {
        Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList "shell:AppsFolder\$applicationId" | Out-Null
    }
}

function Open-CodexThread {
    param(
        [Parameter(Mandatory)]
        [guid]$ThreadId
    )

    Start-Process -FilePath ('codex://threads/{0}' -f $ThreadId.Guid) | Out-Null
}
